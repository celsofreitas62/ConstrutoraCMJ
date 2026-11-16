// =============================================================================
//  SistemaCMJ.Api - Endpoints/AcessoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Login, sessão, troca de senha e saída.
//              Login em dois passos (procedures da 02b):
//                SIS_Usuario_Login_Obter    -> hash/salt/iterações do login
//                (API confere a senha com PBKDF2)
//                SIS_Usuario_Login_Processar -> conta tentativa, bloqueia,
//                                               abre a sessão, registra no log
// =============================================================================
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record LoginPedido(string? Login, string? Senha);
public sealed record SenhaPedido(string? SenhaAtual, string? NovaSenha, string? Confirmacao);

public static class AcessoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapPost("/api/login", Entrar);
        app.MapPost("/api/logout", Sair);
        app.MapGet("/api/sessao", Sessao);
        app.MapPost("/api/senha", TrocarSenha);
    }

    private static Task<IResult> Entrar(LoginPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var login = (pedido.Login ?? "").Trim().ToLowerInvariant();
            var senha = pedido.Senha ?? "";
            if (login.Length == 0 || senha.Length == 0)
                return Resposta.Atencao("Informe o usuário e a senha.");
            if (login.Length > 100 || senha.Length > 128)
                return Resposta.Atencao("Usuário ou senha inválidos.");

            var dados = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Login_Obter",
                new Dictionary<string, object?> { ["Login"] = login }, null, http.RequestAborted);

            var hash = dados.Bytes("SENHA_HASH");
            var salt = dados.Bytes("SENHA_SALT");
            var iteracoes = dados.Int("SENHA_ITERACOES") ?? 0;
            var conferida = false;
            if (dados.Bool("ENCONTRADO") && hash is { Length: 32 } && salt is { Length: >= 16 }
                && iteracoes >= Seguranca.IteracoesMinimas && dados.Texto("SENHA_ALGORITMO") == Seguranca.Algoritmo)
                conferida = Seguranca.SenhaConfere(senha, salt, iteracoes, hash);
            else
                Seguranca.SimularConferencia(senha, iteracoes);

            var (token, tokenHash) = Seguranca.NovoToken();
            var ip = http.Connection.RemoteIpAddress?.ToString() ?? "";
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Login_Processar",
                new Dictionary<string, object?>
                {
                    ["Login"] = login,
                    ["SenhaConferida"] = conferida,
                    ["TokenHash"] = conferida ? tokenHash : (object)NuloTipado.Binario,
                    ["Ip"] = Banco.Cortar(ip, 45),
                    ["Estacao"] = Banco.Cortar(ip, 128),
                    ["Navegador"] = Banco.Cortar(http.Request.Headers.UserAgent.ToString(), 300)
                }, null, http.RequestAborted);

            if (!resultado.Bool("SUCESSO"))
                return Resposta.Atencao(resultado.Texto("MENSAGEM"));

            http.Response.Cookies.Append(Seguranca.NomeCookie, token, new CookieOptions
            {
                HttpOnly = true,
                Secure = true,
                SameSite = SameSiteMode.Strict,
                Path = "/",
                IsEssential = true
            });
            return Resposta.Ok(new { nome = resultado.Texto("NOME"), trocarSenha = resultado.Bool("TROCAR_SENHA") },
                resultado.Texto("MENSAGEM"));
        });

    private static Task<IResult> Sair(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var tokenHash = Seguranca.HashDoToken(http.Request.Cookies[Seguranca.NomeCookie]);
            if (tokenHash is not null)
                await banco.ExecutarAsync("SIS.SIS_Sessao_Encerrar",
                    new Dictionary<string, object?> { ["TokenHash"] = tokenHash, ["Motivo"] = "LOGOUT" }, null, http.RequestAborted);
            http.Response.Cookies.Delete(Seguranca.NomeCookie);
            return Resposta.Ok();
        });

    private static Task<IResult> Sessao(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var nivel = Convert.ToInt32(await banco.EscalarAsync("SELECT SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);",
                new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario }, http.RequestAborted) ?? 0);
            return Resposta.Ok(new
            {
                login = usuario.Login,
                nome = usuario.Nome,
                trocarSenha = usuario.TrocarSenha,
                nivelAdmin = nivel,
                nivelNome = nivel switch { 2 => "Administrador geral", 1 => "Administrador", _ => "" }
            });
        });

    private static Task<IResult> TrocarSenha(SenhaPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var atual = pedido.SenhaAtual ?? "";
            var nova = pedido.NovaSenha ?? "";

            if (atual.Length == 0)
                return Resposta.Atencao("Informe a senha atual.");
            if (nova != (pedido.Confirmacao ?? ""))
                return Resposta.Atencao("A nova senha e a repetição não estão iguais.");
            if (nova == atual)
                return Resposta.Atencao("A nova senha precisa ser diferente da atual.");
            var recusa = Seguranca.ConferirRegras(nova, await banco.ParametroInteiroAsync("SENHA_TAMANHO_MINIMO", http.RequestAborted));
            if (recusa.Length > 0)
                return Resposta.Atencao(recusa);

            var dados = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Login_Obter",
                new Dictionary<string, object?> { ["Login"] = usuario.Login }, null, http.RequestAborted);
            var hash = dados.Bytes("SENHA_HASH");
            var salt = dados.Bytes("SENHA_SALT");
            var iteracoes = dados.Int("SENHA_ITERACOES") ?? 0;
            if (hash is null || salt is null || iteracoes < Seguranca.IteracoesMinimas
                || !Seguranca.SenhaConfere(atual, salt, iteracoes, hash))
                return Resposta.Atencao("A senha atual não confere.");

            var iteracoesNovas = Math.Max(await banco.ParametroInteiroAsync("SENHA_PBKDF2_ITERACOES", http.RequestAborted), Seguranca.IteracoesMinimas);
            var (novoHash, novoSalt) = Seguranca.NovaSenha(nova, iteracoesNovas);
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Senha_Gravar",
                new Dictionary<string, object?>
                {
                    ["IdUsuario"] = usuario.IdUsuario,
                    ["IdUsuarioAlvo"] = usuario.IdUsuario,
                    ["SenhaHash"] = novoHash,
                    ["SenhaSalt"] = novoSalt,
                    ["Iteracoes"] = iteracoesNovas,
                    ["Algoritmo"] = Seguranca.Algoritmo
                }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });
}
