// =============================================================================
//  SistemaCMJ.Api - Endpoints/AgendaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 27/11/2026 (etapa 04h1)
//  Descrição : Agenda financeira da tela inicial (P03, P04) e preferências do
//              usuário (P03, P06). A API só repassa: permissões (VER e
//              VER_TOTAIS em FIN_AGENDA, VER em pagar/receber), regras do
//              período e o padrão das preferências estão nas procedures.
//                GET  /api/fin/agenda/resumo?de=&ate=           barra de totais,
//                                                               em atraso, saldos
//                GET  /api/fin/agenda/periodos?de=&ate=&agrupamento=DIA|MES|MESES
//                                                 &mesesGrupo=  calendário
//                GET  /api/fin/agenda/lista?de=&ate=&soAtraso=&tipo=&texto=
//                                                 &pagina=      lista
//                GET  /api/sis/preferencias                     do usuário logado
//                POST /api/sis/preferencias                     grava várias
//              incluiRealizado / saldoAcumulado vazios = preferência do usuário.
// =============================================================================
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record PreferenciaItem(string? Codigo, string? Valor);

public sealed record PreferenciasPedido(PreferenciaItem[]? Preferencias);

public static class AgendaEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/fin/agenda/resumo", Resumo);
        app.MapGet("/api/fin/agenda/periodos", Periodos);
        app.MapGet("/api/fin/agenda/lista", Lista);
        app.MapGet("/api/sis/preferencias", ListarPreferencias);
        app.MapPost("/api/sis/preferencias", GravarPreferencias);
    }

    private static Task<IResult> Resumo(DateOnly? de, DateOnly? ate, int? idEmpresa, bool? incluiRealizado, bool? saldoAcumulado,
                                        HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Agenda_Resumo", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["De"] = de,
                ["Ate"] = ate,
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["IncluiRealizado"] = incluiRealizado,
                ["SaldoAcumulado"] = saldoAcumulado
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Periodos(DateOnly? de, DateOnly? ate, string? agrupamento, int? mesesGrupo, int? idEmpresa,
                                          bool? incluiRealizado, bool? saldoAcumulado,
                                          HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("FIN.FIN_Agenda_Periodos", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["De"] = de,
                ["Ate"] = ate,
                ["Agrupamento"] = Banco.Cortar(string.IsNullOrWhiteSpace(agrupamento) ? "DIA" : agrupamento.Trim().ToUpperInvariant(), 10),
                ["MesesGrupo"] = mesesGrupo,
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["IncluiRealizado"] = incluiRealizado,
                ["SaldoAcumulado"] = saldoAcumulado
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Lista(DateOnly? de, DateOnly? ate, bool? soAtraso, string? tipo, int? idEmpresa, bool? incluiRealizado,
                                       string? texto, int? pagina, int? porPagina,
                                       HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("FIN.FIN_Agenda_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["De"] = de,
                ["Ate"] = ate,
                ["SoAtraso"] = soAtraso == true,
                ["Tipo"] = Banco.Cortar(tipo?.Trim().ToUpperInvariant(), 1),
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["IncluiRealizado"] = incluiRealizado,
                ["Texto"] = Banco.Cortar(texto?.Trim(), 100),
                ["Pagina"] = pagina is > 0 ? pagina : 1,
                ["PorPagina"] = porPagina is > 0 ? porPagina : null
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> ListarPreferencias(string? grupo, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Preferencia_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Grupo"] = Banco.Cortar(grupo?.Trim(), 60)
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> GravarPreferencias(PreferenciasPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var itens = (p.Preferencias ?? [])
                .Select(i => new { codigo = Banco.Cortar(i.Codigo?.Trim().ToUpperInvariant(), 40), valor = Banco.Cortar(i.Valor?.Trim(), 400) })
                .ToArray();
            if (itens.Length == 0)
                return Resposta.Atencao("Nenhuma preferência informada.");
            if (itens.Length > 50)
                return Resposta.Atencao("Preferências demais de uma vez.");
            var linha = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Preferencia_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Preferencias"] = JsonSerializer.Serialize(itens)
            }, usuario, http.RequestAborted);
            return linha.Bool("SUCESSO")
                ? Resposta.Ok(new { qtd = linha.Int("QTD_GRAVADAS") }, linha.Texto("MENSAGEM"))
                : Resposta.Atencao(linha.Texto("MENSAGEM"));
        });
}
