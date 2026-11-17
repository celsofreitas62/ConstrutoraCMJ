// =============================================================================
//  SistemaCMJ.Api - Endpoints/ComunicadoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 17/11/2026 (fase 3c)
//  Descrição : Tela "Comunicados" (SIS_COMUNICADO): boletim semanal da
//              implantação. Permissão, validação e gravação ficam nas
//              procedures SIS_Comunicado_*; a API só repassa.
//              /html devolve o e-mail exatamente como sai, para a tela mostrar
//              numa moldura (iframe) isolada: política própria que só aceita os
//              estilos do e-mail e a logomarca do sistema, sem script nenhum.
// =============================================================================
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record ComunicadoPedido(string? Introducao, JsonElement? Itens);

public static class ComunicadoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/sis/comunicados", Obter);
        app.MapPost("/api/sis/comunicados/{id:int}", Gravar);
        app.MapPost("/api/sis/comunicados/{id:int}/previa", GerarPrevia);
        app.MapGet("/api/sis/comunicados/edicoes/{id:long}/html", EdicaoHtml);
        app.MapPost("/api/sis/comunicados/edicoes/{id:long}/aprovar", Aprovar);
        app.MapPost("/api/sis/comunicados/edicoes/{id:long}/descartar", Descartar);
    }

    private static Task<IResult> Obter(int? id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Comunicado_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdComunicado"] = id
            }, usuario, http.RequestAborted);
            if (linhas.Count == 0)
                return Resposta.Atencao("Nenhum comunicado cadastrado.");
            var linha = linhas[0];
            foreach (var coluna in new[] { "ITENS_JSON", "EDICOES_JSON" })
                linha[coluna] = JsonDocument.Parse(linha.Texto(coluna) is { Length: > 0 } t ? t : "[]").RootElement.Clone();
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Gravar(int id, ComunicadoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var itens = p.Itens is { ValueKind: JsonValueKind.Array } lista ? lista.GetRawText() : "[]";
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Comunicado_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdComunicado"] = id,
                ["Introducao"] = Banco.Cortar(p.Introducao?.Trim(), 1000),
                ["ItensJson"] = itens
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> GerarPrevia(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Comunicado_Previa_Gerar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdComunicado"] = id
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Aprovar(long id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Comunicado_Edicao_Aprovar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdEdicao"] = id
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Descartar(long id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Comunicado_Edicao_Descartar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdEdicao"] = id
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    /// <summary>O HTML do e-mail para a pré-visualização na tela (iframe da mesma origem).</summary>
    private static async Task<IResult> EdicaoHtml(long id, HttpContext http, Banco banco, ILogger<Program> logger)
    {
        try
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Comunicado_Edicao_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdEdicao"] = id
            }, usuario, http.RequestAborted);
            if (linhas.Count == 0)
                return Results.NotFound();

            var html = linhas[0].Texto("CORPO_HTML")
                .Replace("cid:logo_empresa", "/api/sis/comunicados/logo-email", StringComparison.OrdinalIgnoreCase);
            var cabecalhos = http.Response.Headers;
            cabecalhos["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'self'";
            cabecalhos["X-Frame-Options"] = "SAMEORIGIN";
            return Results.Content(html, "text/html; charset=utf-8");
        }
        catch (Microsoft.Data.SqlClient.SqlException erro) when (erro.Number == 50001)
        {
            return Results.StatusCode(StatusCodes.Status403Forbidden);
        }
        catch (Exception erro)
        {
            logger.LogError(erro, "Falha ao mostrar o comunicado {Id}", id);
            await banco.RegistrarErroAsync("API GET /api/sis/comunicados/edicoes/html", "Pré-visualização", erro);
            return Results.Problem("Não foi possível mostrar o comunicado.");
        }
    }

    /// <summary>Logomarca dos e-mails, para a pré-visualização.</summary>
    public static void MapearLogo(WebApplication app) =>
        app.MapGet("/api/sis/comunicados/logo-email", async (HttpContext http, EnvioEmail envio) =>
        {
            var caminho = await envio.CaminhoLogoAsync(http.RequestAborted);
            if (caminho is null) return Results.NotFound();
            var tipo = Path.GetExtension(caminho).ToLowerInvariant() switch { ".png" => "image/png", ".jpg" or ".jpeg" => "image/jpeg", _ => "application/octet-stream" };
            return Results.File(caminho, tipo);
        });
}
