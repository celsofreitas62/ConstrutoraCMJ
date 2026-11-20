// =============================================================================
//  SistemaCMJ.Api - Infra/SessaoMiddleware.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Roda antes de toda chamada /api:
//                1) POST precisa do cabeçalho "X-CMJ: 1" (as telas sempre
//                   mandam; formulário de outro site não consegue mandar);
//                2) fora das rotas públicas, confere a sessão do cookie em
//                   SIS_Sessao_Validar (inatividade, usuário ativo, bloqueio);
//                3) com TROCAR_SENHA = 1, só deixa trocar a senha, ver a
//                   sessão e sair.
//              20/11/2026 (fase 3d): banco em versão diferente da do
//              programa: só /api/saude responde; o resto recebe o aviso.
//              O usuário conferido fica em HttpContext.Items["contexto"].
// =============================================================================
namespace SistemaCMJ.Api.Infra;

public sealed class SessaoMiddleware(RequestDelegate proximo, ILogger<SessaoMiddleware> logger)
{
    private static readonly string[] RotasPublicas = ["/api/login", "/api/identidade", "/api/saude", "/api/instalacao"];
    private static readonly string[] RotasSemLicenca = ["/api/saude", "/api/identidade", "/api/instalacao"];
    private static readonly string[] RotasDuranteTrocaDeSenha = ["/api/senha", "/api/sessao", "/api/logout"];

    public async Task InvokeAsync(HttpContext http, Banco banco, VersaoBanco versao, LicencaServico licenca)
    {
        var caminho = http.Request.Path.Value ?? "";
        if (!caminho.StartsWith("/api/", StringComparison.OrdinalIgnoreCase))
        {
            await proximo(http);
            return;
        }

        if (!HttpMethods.IsGet(http.Request.Method) && http.Request.Headers["X-CMJ"] != "1")
        {
            http.Response.StatusCode = StatusCodes.Status400BadRequest;
            return;
        }

        if (!caminho.StartsWith("/api/saude", StringComparison.OrdinalIgnoreCase) && !await versao.ConferirAsync(http.RequestAborted))
        {
            await Resposta.Atencao(versao.Mensagem()).ExecuteAsync(http);
            return;
        }

        // Licença inválida: só saúde, identidade (logomarca do login) e primeiro acesso respondem
        if (!RotasSemLicenca.Any(r => caminho.StartsWith(r, StringComparison.OrdinalIgnoreCase)) && !await licenca.ConferirAsync(http.RequestAborted))
        {
            await Resposta.Atencao(licenca.Mensagem()).ExecuteAsync(http);
            return;
        }

        if (RotasPublicas.Any(r => caminho.StartsWith(r, StringComparison.OrdinalIgnoreCase)))
        {
            await proximo(http);
            return;
        }

        var tokenHash = Seguranca.HashDoToken(http.Request.Cookies[Seguranca.NomeCookie]);
        if (tokenHash is null)
        {
            await Resposta.Sessao("Entre no sistema para continuar.").ExecuteAsync(http);
            return;
        }

        Linha sessao;
        try
        {
            sessao = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Sessao_Validar",
                new Dictionary<string, object?> { ["TokenHash"] = tokenHash }, null, http.RequestAborted);
        }
        catch (Exception erro)
        {
            logger.LogError(erro, "Falha ao validar a sessão");
            await banco.RegistrarErroAsync("API SessaoMiddleware", "Validar sessão", erro);
            await Resposta.Erro().ExecuteAsync(http);
            return;
        }

        if (!sessao.Bool("SUCESSO"))
        {
            http.Response.Cookies.Delete(Seguranca.NomeCookie);
            var mensagem = sessao.Texto("MENSAGEM");
            await Resposta.Sessao(mensagem.Length > 0 ? mensagem : "Sua sessão terminou. Entre de novo.").ExecuteAsync(http);
            return;
        }

        var contexto = new Contexto(
            IdUsuario: sessao.Int("ID_USUARIO") ?? 0,
            Login: sessao.Texto("LOGIN"),
            Nome: sessao.Texto("NOME"),
            TrocarSenha: sessao.Bool("TROCAR_SENHA"),
            Estacao: http.Connection.RemoteIpAddress?.ToString() ?? "",
            Origem: Banco.Cortar(http.Request.Headers["X-Tela"].ToString(), 200));

        if (contexto.TrocarSenha && !RotasDuranteTrocaDeSenha.Any(r => caminho.StartsWith(r, StringComparison.OrdinalIgnoreCase)))
        {
            await Resposta.TrocarSenha().ExecuteAsync(http);
            return;
        }

        http.Items["contexto"] = contexto;
        await proximo(http);
    }
}

public static class ContextoHttp
{
    /// <summary>Usuário conferido pelo SessaoMiddleware (sempre existe nas rotas protegidas).</summary>
    public static Contexto Usuario(this HttpContext http) =>
        http.Items["contexto"] as Contexto ?? throw new InvalidOperationException("Rota protegida sem sessão conferida.");
}
