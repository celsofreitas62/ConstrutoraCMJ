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
//              /correcoes.sql: arquivo com as correções gravadas, para levar ao
//              servidor da CMJ na instalação (MIG_Caso_Correcao_Exportar).
// =============================================================================
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record CasoPedido(string? Unidade, string? Acao, string? Motivo, JsonElement? Linhas);
public sealed record LotePedido(string? Acao, string? Motivo, JsonElement? Unidades);

public static class MigracaoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/mig/casos", Listar);
        app.MapGet("/api/mig/casos/opcoes", Opcoes);
        app.MapGet("/api/mig/caso", Obter);
        app.MapPost("/api/mig/caso/gravar", Gravar);
        app.MapPost("/api/mig/caso/conferir", Conferir);
        app.MapGet("/api/mig/casos/correcoes.sql", ExportarCorrecoes);
        app.MapPost("/api/mig/casos/lote", GravarLote);
        app.MapPost("/api/mig/casos/conferir-lote", ConferirLote);
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

            // o documento gravado vem primeiro; depois, o lote de destino de uma linha trocada de lote
            var conferencia = await banco.ExecutarAsync("MIG.MIG_Caso_Conferir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Unidade"] = unidade
            }, usuario, http.RequestAborted);
            return Resposta.Ok(conferencia, resultado.Texto("MENSAGEM"));
        });

    private static Task<IResult> Conferir(CasoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
            Resposta.Ok(await ConferirAsync(Banco.Cortar(p.Unidade?.Trim(), 40), http.Usuario(), banco, http.RequestAborted)));

    /// <summary>Ação em lote (ignorar, arquivo morto, desfazer) e conferência dos mesmos documentos.</summary>
    private static Task<IResult> GravarLote(LotePedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var unidades = p.Unidades is { ValueKind: JsonValueKind.Array } lista ? lista.GetRawText() : null;
            var resultado = await banco.ExecutarUmaLinhaAsync("MIG.MIG_Caso_Lote_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Acao"] = Banco.Cortar(p.Acao?.Trim(), 15),
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["UnidadesJson"] = unidades
            }, usuario, http.RequestAborted);
            if (!resultado.Bool("SUCESSO"))
                return Resposta.DeGravacao(resultado);
            return Resposta.Ok(await ConferirLoteAsync(unidades, usuario, banco, http.RequestAborted), resultado.Texto("MENSAGEM"));
        });

    private static Task<IResult> ConferirLote(LotePedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
            Resposta.Ok(await ConferirLoteAsync(p.Unidades is { ValueKind: JsonValueKind.Array } lista ? lista.GetRawText() : null,
                                                http.Usuario(), banco, http.RequestAborted)));

    private static Task<List<Linha>> ConferirLoteAsync(string? unidades, Contexto usuario, Banco banco, CancellationToken ct) =>
        banco.ExecutarAsync("MIG.MIG_Caso_Conferir", new Dictionary<string, object?>
        {
            ["IdUsuario"] = usuario.IdUsuario,
            ["Unidades"] = unidades
        }, usuario, ct);

    private static async Task<Linha> ConferirAsync(string unidade, Contexto usuario, Banco banco, CancellationToken ct)
    {
        var linhas = await banco.ExecutarAsync("MIG.MIG_Caso_Conferir", new Dictionary<string, object?>
        {
            ["IdUsuario"] = usuario.IdUsuario,
            ["Unidade"] = unidade
        }, usuario, ct);
        return linhas.Count > 0 ? linhas[0] : new Linha();
    }

    /// <summary>Arquivo .sql com as correções, para copiar para outro banco (instalação).</summary>
    private static async Task<IResult> ExportarCorrecoes(HttpContext http, Banco banco, ILogger<Program> logger)
    {
        try
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("MIG.MIG_Caso_Correcao_Exportar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario
            }, usuario, http.RequestAborted);
            var texto = string.Join("\r\n", linhas.Select(l => l.Texto("LINHA"))) + "\r\n";
            var bytes = System.Text.Encoding.UTF8.GetPreamble().Concat(System.Text.Encoding.UTF8.GetBytes(texto)).ToArray();
            return Results.File(bytes, "application/sql", "correcoes-casos-migracao-" + DateTime.Now.ToString("yyyy-MM-dd-HHmm") + ".sql");
        }
        catch (Microsoft.Data.SqlClient.SqlException erro) when (erro.Number == 50001)
        {
            return Results.Text(erro.Message, "text/plain; charset=utf-8", statusCode: StatusCodes.Status403Forbidden);
        }
        catch (Exception erro)
        {
            logger.LogError(erro, "Falha ao exportar as correções da migração");
            await banco.RegistrarErroAsync("API GET /api/mig/casos/correcoes.sql", "Exportação", erro);
            return Results.Problem("Não foi possível montar o arquivo das correções.");
        }
    }

    private static JsonElement Json(string texto) =>
        JsonDocument.Parse(texto is { Length: > 0 } ? texto : "[]").RootElement.Clone();
}
