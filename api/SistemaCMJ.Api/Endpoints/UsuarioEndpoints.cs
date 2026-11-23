// =============================================================================
//  SistemaCMJ.Api - Endpoints/UsuarioEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 22/11/2026 (fase 4, conversa 04a)
//  Descrição : Telas "Usuários" (SIS_USUARIO) e "Perfis e permissões"
//              (SIS_PERFIL). A API só repassa: permissão, regras dos dois
//              níveis de administrador e gravação estão nas procedures da 02b
//              (SIS_Usuario_*, SIS_Perfil_*, SIS_Permissao_*).
//              Únicas coisas feitas aqui, porque o banco nunca vê senha:
//                - Reiniciar senha: calcula o PBKDF2 da senha provisória
//                  padrão (parâmetro SENHA_PROVISORIA_PADRAO) e grava pelo
//                  SIS_Usuario_Senha_Gravar (troca obrigatória, desbloqueia,
//                  encerra as sessões);
//                - usuário novo já nasce com a senha provisória (se quem
//                  incluiu tem REDEFINIR_SENHA), em vez de ficar sem senha.
//              Aba Histórico: endpoint geral (HistoricoEndpoints, 04b2).
// =============================================================================
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record UsuarioPedido(int? IdUsuario, string? Login, string? Nome, string? Email, int? IdPerfil, bool Ativo);
public sealed record PerfilPedido(int? IdPerfil, string? Nome, string? Descricao, bool Ativo);
public sealed record PermissoesPedido(JsonElement? Lista);

public static class UsuarioEndpoints
{
    private const string ItemUsuario = "SIS_USUARIO";
    private const string ItemPerfil = "SIS_PERFIL";

    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/sis/usuarios", ListarUsuarios);
        app.MapGet("/api/sis/usuarios/{id:int}", ObterUsuario);
        app.MapPost("/api/sis/usuarios", GravarUsuario);
        app.MapPost("/api/sis/usuarios/{id:int}/reiniciar-senha", ReiniciarSenha);
        app.MapPost("/api/sis/usuarios/{id:int}/desbloquear", Desbloquear);
        app.MapGet("/api/sis/usuarios/{id:int}/permissoes", (int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
            ListarPermissoes(null, id, http, banco, logger));
        app.MapPost("/api/sis/usuarios/{id:int}/permissoes", (int id, PermissoesPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
            GravarPermissoes(null, id, p, http, banco, logger));

        app.MapGet("/api/sis/perfis", ListarPerfis);
        app.MapGet("/api/sis/perfis/{id:int}", ObterPerfil);
        app.MapPost("/api/sis/perfis", GravarPerfil);
        app.MapGet("/api/sis/perfis/{id:int}/permissoes", (int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
            ListarPermissoes(id, null, http, banco, logger));
        app.MapPost("/api/sis/perfis/{id:int}/permissoes", (int id, PermissoesPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
            GravarPermissoes(id, null, p, http, banco, logger));
        app.MapGet("/api/sis/perfis/{id:int}/usuarios", UsuariosDoPerfil);
    }

    // ------------------------------------------------------------------ Usuários

    private static Task<IResult> ListarUsuarios(string? busca, string? situacao, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            situacao = (situacao ?? "ATIVOS").ToUpperInvariant();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Usuario_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Texto"] = Banco.Cortar(busca?.Trim(), 100),
                ["SomenteAtivos"] = situacao == "ATIVOS"
            }, usuario, http.RequestAborted);
            if (situacao == "INATIVOS")
                linhas = linhas.Where(l => !l.Bool("ATIVO")).ToList();
            foreach (var l in linhas)
                l["PROPRIO"] = l.Int("ID_USUARIO") == usuario.IdUsuario;
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> ObterUsuario(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdUsuarioConsulta"] = id
            }, usuario, http.RequestAborted);
            linha["PROPRIO"] = id == usuario.IdUsuario;
            linha["SENHA_PROVISORIA_HORAS"] = await banco.ParametroInteiroAsync("SENHA_PROVISORIA_HORAS", http.RequestAborted);
            return Resposta.Ok(linha);
        });

    private static Task<IResult> GravarUsuario(UsuarioPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (p.IdPerfil is not > 0)
                return Resposta.Atencao("Escolha o perfil do usuário.");

            var incluir = p.IdUsuario is not > 0;
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdUsuarioAlvo"] = incluir ? null : p.IdUsuario,
                ["Login"] = Banco.Cortar(p.Login?.Trim(), 40),
                ["Nome"] = Banco.Cortar(p.Nome?.Trim(), 100),
                ["Email"] = Banco.Cortar(p.Email?.Trim(), 200),
                ["IdPerfil"] = p.IdPerfil,
                ["Ativo"] = p.Ativo
            }, usuario, http.RequestAborted);
            if (!resultado.Bool("SUCESSO"))
                return Resposta.Atencao(resultado.Texto("MENSAGEM"));

            var idGravado = resultado.Int("ID_USUARIO");
            var mensagem = resultado.Texto("MENSAGEM");
            if (incluir && idGravado is > 0)
            {
                var senha = await DefinirProvisoriaAsync(idGravado.Value, usuario, banco, http.RequestAborted);
                mensagem = senha.Bool("SUCESSO")
                    ? "Usuário incluído com a senha provisória padrão. No primeiro acesso ele cria a senha dele."
                    : "Usuário incluído, mas a senha provisória não foi definida: " + senha.Texto("MENSAGEM");
            }
            return Resposta.Ok(new { id = idGravado }, mensagem);
        });

    private static Task<IResult> ReiniciarSenha(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (id == usuario.IdUsuario)
                return Resposta.Atencao("Para trocar a sua própria senha, use \"Trocar senha\" no topo da tela.");
            var resultado = await DefinirProvisoriaAsync(id, usuario, banco, http.RequestAborted);
            if (!resultado.Bool("SUCESSO"))
                return Resposta.Atencao(resultado.Texto("MENSAGEM"));
            var horas = await banco.ParametroInteiroAsync("SENHA_PROVISORIA_HORAS", http.RequestAborted);
            return Resposta.Ok(new { id }, "Senha reiniciada para a senha provisória padrão. O usuário foi desbloqueado, as sessões dele foram encerradas"
                + (horas > 0 ? $" e ele precisa entrar e criar a senha nova em até {horas} horas." : " e ele vai criar a senha nova no próximo acesso."));
        });

    /// <summary>Grava a senha provisória padrão (o banco confere a permissão REDEFINIR_SENHA).</summary>
    private static async Task<Linha> DefinirProvisoriaAsync(int idAlvo, Contexto usuario, Banco banco, CancellationToken ct)
    {
        var provisoria = await banco.ParametroAsync("SENHA_PROVISORIA_PADRAO", ct);
        if (provisoria.Length == 0)
            return new Linha { ["SUCESSO"] = false, ["MENSAGEM"] = "O parâmetro SENHA_PROVISORIA_PADRAO está vazio. Procure o administrador geral." };
        var iteracoes = Math.Max(await banco.ParametroInteiroAsync("SENHA_PBKDF2_ITERACOES", ct), Seguranca.IteracoesMinimas);
        var (hash, salt) = Seguranca.NovaSenha(provisoria, iteracoes);
        return await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Senha_Gravar", new Dictionary<string, object?>
        {
            ["IdUsuario"] = usuario.IdUsuario,
            ["IdUsuarioAlvo"] = idAlvo,
            ["SenhaHash"] = hash,
            ["SenhaSalt"] = salt,
            ["Iteracoes"] = iteracoes,
            ["Algoritmo"] = Seguranca.Algoritmo
        }, usuario, ct);
    }

    private static Task<IResult> Desbloquear(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Usuario_Desbloquear", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdUsuarioAlvo"] = id
            }, usuario, http.RequestAborted);
            return resultado.Bool("SUCESSO") ? Resposta.Ok(new { id }, resultado.Texto("MENSAGEM")) : Resposta.Atencao(resultado.Texto("MENSAGEM"));
        });

    // ------------------------------------------------------------------ Perfis

    private static Task<IResult> ListarPerfis(string? situacao, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            situacao = (situacao ?? "TODOS").ToUpperInvariant();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Perfil_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["SomenteAtivos"] = situacao == "ATIVOS"
            }, usuario, http.RequestAborted);
            if (situacao == "INATIVOS")
                linhas = linhas.Where(l => !l.Bool("ATIVO")).ToList();
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> ObterPerfil(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Perfil_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["SomenteAtivos"] = false
            }, usuario, http.RequestAborted);
            var perfil = linhas.FirstOrDefault(l => l.Int("ID_PERFIL") == id);
            return perfil is null ? Resposta.Atencao("Perfil não encontrado.") : Resposta.Ok(perfil);
        });

    private static Task<IResult> GravarPerfil(PerfilPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Perfil_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdPerfil"] = p.IdPerfil is > 0 ? p.IdPerfil : null,
                ["Nome"] = Banco.Cortar(p.Nome?.Trim(), 60),
                ["Descricao"] = Banco.Cortar(p.Descricao?.Trim(), 400),
                ["Ativo"] = p.Ativo
            }, usuario, http.RequestAborted);
            return resultado.Bool("SUCESSO")
                ? Resposta.Ok(new { id = resultado.Int("ID_PERFIL") }, resultado.Texto("MENSAGEM"))
                : Resposta.Atencao(resultado.Texto("MENSAGEM"));
        });

    private static Task<IResult> UsuariosDoPerfil(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Usuario_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["SomenteAtivos"] = false
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas.Where(l => l.Int("ID_PERFIL") == id).ToList());
        });

    // ------------------------------------------------------------------ Permissões (perfil ou usuário)

    private static Task<IResult> ListarPermissoes(int? idPerfil, int? idUsuarioAlvo, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
            Resposta.Ok(await PermissoesAsync(idPerfil, idUsuarioAlvo, http.Usuario(), banco, http.RequestAborted)));

    private static async Task<List<Linha>> PermissoesAsync(int? idPerfil, int? idUsuarioAlvo, Contexto usuario, Banco banco, CancellationToken ct)
    {
        var linhas = await banco.ExecutarAsync("SIS.SIS_Permissao_Listar", new Dictionary<string, object?>
        {
            ["IdUsuario"] = usuario.IdUsuario,
            ["IdPerfil"] = idPerfil,
            ["IdUsuarioAlvo"] = idUsuarioAlvo
        }, usuario, ct);
        return linhas;
    }

    private static Task<IResult> GravarPermissoes(int? idPerfil, int? idUsuarioAlvo, PermissoesPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (p.Lista is not { ValueKind: JsonValueKind.Array } lista || lista.GetArrayLength() == 0)
                return Resposta.Atencao("Nenhuma alteração para gravar.");
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Permissao_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdPerfil"] = idPerfil,
                ["IdUsuarioAlvo"] = idUsuarioAlvo,
                ["ListaJson"] = lista.GetRawText()
            }, usuario, http.RequestAborted);
            return resultado.Bool("SUCESSO")
                ? Resposta.Ok(new { qtd = resultado.Int("QTD_ALTERADA") }, resultado.Texto("MENSAGEM"))
                : Resposta.Atencao(resultado.Texto("MENSAGEM"));
        });
}
