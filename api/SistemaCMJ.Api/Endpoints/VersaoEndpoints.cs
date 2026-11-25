// =============================================================================
//  SistemaCMJ.Api - Endpoints/VersaoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (fase 4, conversa 04c2)
//  Descrição : Versões e "O que há de novo" (pedido P22). A API só repassa:
//              permissão, regras e público das notas estão nas procedures da 04c:
//                aba Notas          SIS_Versao_Nota_Listar (itens GERAL só nível 2)
//                aba Histórico      SIS_Versao_Listar (permissão VER em SIS_VERSOES)
//                aviso pós-login    SIS_Novidades_Obter / SIS_Novidades_Marcar_Vista
// =============================================================================
using System.Globalization;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public static class VersaoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/sis/versoes/notas", NotasListar);
        app.MapGet("/api/sis/versoes/historico", HistoricoListar);
        app.MapGet("/api/sis/novidades", NovidadesObter);
        app.MapPost("/api/sis/novidades/vista", NovidadesMarcarVista);
    }

    private static Task<IResult> NotasListar(string? versao, string? tipo, string? busca, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            return Resposta.Ok(await banco.ExecutarAsync("SIS.SIS_Versao_Nota_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Versao"] = Banco.Cortar(versao?.Trim(), 20) ?? "",
                ["Tipo"] = Banco.Cortar(tipo?.Trim().ToUpperInvariant(), 10) ?? "",
                ["Busca"] = Banco.Cortar(busca?.Trim(), 100) ?? ""
            }, usuario, http.RequestAborted));
        });

    private static Task<IResult> HistoricoListar(string? inicio, string? fim, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerData(inicio, out var dtInicio) || !LerData(fim, out var dtFim))
                return Resposta.Atencao("Data do filtro inválida.");
            return Resposta.Ok(await banco.ExecutarAsync("SIS.SIS_Versao_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["DtInicio"] = dtInicio,
                ["DtFim"] = dtFim
            }, usuario, http.RequestAborted));
        });

    private static Task<IResult> NovidadesObter(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            return Resposta.Ok(await banco.ExecutarAsync("SIS.SIS_Novidades_Obter",
                new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario }, usuario, http.RequestAborted));
        });

    private static Task<IResult> NovidadesMarcarVista(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Novidades_Marcar_Vista",
                new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario }, usuario, http.RequestAborted);
            return r.Bool("SUCESSO") ? Resposta.Ok(null, r.Texto("MENSAGEM")) : Resposta.Atencao(r.Texto("MENSAGEM"));
        });

    private static bool LerData(string? texto, out DateOnly? data)
    {
        data = null;
        if (string.IsNullOrWhiteSpace(texto)) return true;
        if (!DateOnly.TryParseExact(texto.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)) return false;
        data = d;
        return true;
    }
}
