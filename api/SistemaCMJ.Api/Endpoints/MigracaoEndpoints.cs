// =============================================================================
//  SistemaCMJ.Api - Endpoints/MigracaoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 18/11/2026 (etapa 03c2)
//  Descrição : Tela "Casos da migração" (MIG_CASOS): documentos do Access que
//              não se encaixam nas regras da migração, corrigidos linha a
//              linha pelos administradores. Permissão, validação e gravação
//              ficam nas procedures MIG_Caso_*; a API só repassa.
//              Depois de gravar, confere o documento de novo (MIG_Caso_Conferir)
//              e devolve como ele ficou (REGRA, MOTIVO).
//              O schema MIG só existe onde a migração roda; fora dele, a tela
//              nem aparece no menu.
// =============================================================================
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record CasoPedido(string? Unidade, string? Acao, string? Motivo, JsonElement? Linhas);

public static class MigracaoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/mig/casos", Listar);
        app.MapGet("/api/mig/casos/opcoes", Opcoes);
        app.MapGet("/api/mig/caso", Obter);
        app.MapPost("/api/mig/caso/gravar", Gravar);
        app.MapPost("/api/mig/caso/conferir", Conferir);
    }

    private static Task<IResult> Listar(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("MIG.MIG_Caso_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Opcoes(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("MIG.MIG_Caso_Opcoes", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario
            }, usuario, http.RequestAborted);
            var linha = linhas.Count > 0 ? linhas[0] : new Linha();
            foreach (var coluna in new[] { "OBRAS_JSON", "CONTAS_JSON", "PLANOS_JSON", "PESSOAS_JSON" })
                linha[coluna] = Json(linha.Texto(coluna));
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Obter(string? unidade, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("MIG.MIG_Caso_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Unidade"] = Banco.Cortar(unidade?.Trim(), 40)
            }, usuario, http.RequestAborted);
            if (linhas.Count == 0)
                return Resposta.Atencao("Caso não encontrado. Atualize a lista.");
            var linha = linhas[0];
            linha["LINHAS_JSON"] = Json(linha.Texto("LINHAS_JSON"));
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Gravar(CasoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var unidade = Banco.Cortar(p.Unidade?.Trim(), 40);
            var resultado = await banco.ExecutarUmaLinhaAsync("MIG.MIG_Caso_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Unidade"] = unidade,
                ["Acao"] = Banco.Cortar(p.Acao?.Trim(), 15),
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["LinhasJson"] = p.Linhas is { ValueKind: JsonValueKind.Array } lista ? lista.GetRawText() : null
            }, usuario, http.RequestAborted);
            if (!resultado.Bool("SUCESSO"))
                return Resposta.DeGravacao(resultado);

            var conferencia = await ConferirAsync(unidade, usuario, banco, http.RequestAborted);
            return Resposta.Ok(conferencia, resultado.Texto("MENSAGEM"));
        });

    private static Task<IResult> Conferir(CasoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
            Resposta.Ok(await ConferirAsync(Banco.Cortar(p.Unidade?.Trim(), 40), http.Usuario(), banco, http.RequestAborted)));

    private static async Task<Linha> ConferirAsync(string unidade, Contexto usuario, Banco banco, CancellationToken ct)
    {
        var linhas = await banco.ExecutarAsync("MIG.MIG_Caso_Conferir", new Dictionary<string, object?>
        {
            ["IdUsuario"] = usuario.IdUsuario,
            ["Unidade"] = unidade
        }, usuario, ct);
        return linhas.Count > 0 ? linhas[0] : new Linha();
    }

    private static JsonElement Json(string texto) =>
        JsonDocument.Parse(texto is { Length: > 0 } ? texto : "[]").RootElement.Clone();
}
