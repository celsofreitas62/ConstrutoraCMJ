// =============================================================================
//  SistemaCMJ.Api - Endpoints/CaixaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 27/11/2026 (etapa 04g2)
//  Descrição : Telas do módulo Bancos: Transferências, Extrato e saldos e
//              Fechamento de caixa. A API só repassa: permissões, regras e
//              travas (trava de datas, caixa e mês fechado, entre empresas,
//              saldo) estão nas procedures.
//                GET  /api/banco/transferencias                    lista
//                POST /api/banco/transferencias/conferir           prévia
//                POST /api/banco/transferencias                    grava
//                POST /api/banco/transferencias/{id}/estornar/conferir
//                POST /api/banco/transferencias/{id}/estornar
//                GET  /api/banco/extrato?idConta=&de=&ate=
//                GET  /api/banco/saldos?data=
//                GET  /api/banco/caixa                             histórico
//                POST /api/banco/caixa/conferir                    prévia
//                POST /api/banco/caixa                             fecha
//                POST /api/banco/caixa/{id}/reabrir/conferir
//                POST /api/banco/caixa/{id}/reabrir
//              Mesmo contrato de avisos da baixa:
//                tipo OK        gravado / prévia sem bloqueio
//                tipo PENDENTE  há aviso a confirmar ou motivo a informar
//                tipo ATENCAO   bloqueio ou dado inválido (dados.avisos)
// =============================================================================
using System.Globalization;
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record TransferenciaPedido(
    string? DtTransferencia,
    int? IdContaOrigem,
    int? IdContaDestino,
    decimal? Valor,
    string? Historico,
    string? Documento,
    string[]? AvisosConfirmados = null,
    string? Motivo = null);

public sealed record TransferenciaEstornoPedido(string? Motivo, string? DtEstorno);

public sealed record CaixaFecharPedido(
    int? IdConta,
    string? DtFechamento,
    decimal? SaldoContado,
    string? Motivo,
    bool? GerarAjuste,
    string? Observacao);

public sealed record CaixaReabrirPedido(string? Motivo);

public static class CaixaEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/banco/transferencias", ListarTransferencias);
        app.MapPost("/api/banco/transferencias/conferir", (TransferenciaPedido p, HttpContext h, Banco b, ILogger<Program> l) => GravarTransferencia(p, h, b, l, conferir: true));
        app.MapPost("/api/banco/transferencias", (TransferenciaPedido p, HttpContext h, Banco b, ILogger<Program> l) => GravarTransferencia(p, h, b, l, conferir: false));
        app.MapPost("/api/banco/transferencias/{id:long}/estornar/conferir", (long id, TransferenciaEstornoPedido p, HttpContext h, Banco b, ILogger<Program> l) => EstornarTransferencia(id, p, h, b, l, conferir: true));
        app.MapPost("/api/banco/transferencias/{id:long}/estornar", (long id, TransferenciaEstornoPedido p, HttpContext h, Banco b, ILogger<Program> l) => EstornarTransferencia(id, p, h, b, l, conferir: false));
        app.MapGet("/api/banco/extrato", Extrato);
        app.MapGet("/api/banco/saldos", Saldos);
        app.MapGet("/api/banco/caixa", ListarCaixa);
        app.MapPost("/api/banco/caixa/conferir", (CaixaFecharPedido p, HttpContext h, Banco b, ILogger<Program> l) => FecharCaixa(p, h, b, l, conferir: true));
        app.MapPost("/api/banco/caixa", (CaixaFecharPedido p, HttpContext h, Banco b, ILogger<Program> l) => FecharCaixa(p, h, b, l, conferir: false));
        app.MapPost("/api/banco/caixa/{id:long}/reabrir/conferir", (long id, CaixaReabrirPedido p, HttpContext h, Banco b, ILogger<Program> l) => ReabrirCaixa(id, p, h, b, l, conferir: true));
        app.MapPost("/api/banco/caixa/{id:long}/reabrir", (long id, CaixaReabrirPedido p, HttpContext h, Banco b, ILogger<Program> l) => ReabrirCaixa(id, p, h, b, l, conferir: false));
    }

    // ------------------------------------------------------------- transferências
    private static Task<IResult> ListarTransferencias(DateOnly? de, DateOnly? ate, int? idConta, int? idEmpresa, string? situacao,
                                                      bool? entreEmpresas, string? texto, int? pagina, int? porPagina,
                                                      HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("FIN.FIN_Transferencia_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["DtDe"] = de,
                ["DtAte"] = ate,
                ["IdConta"] = idConta is > 0 ? idConta : null,
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["Situacao"] = Banco.Cortar(situacao?.Trim().ToUpperInvariant(), 10),
                ["EntreEmpresas"] = entreEmpresas == true,
                ["Texto"] = Banco.Cortar(texto?.Trim(), 100),
                ["Pagina"] = pagina is > 0 ? pagina : 1,
                ["PorPagina"] = porPagina is > 0 ? porPagina : null
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> GravarTransferencia(TransferenciaPedido p, HttpContext http, Banco banco, ILogger<Program> logger, bool conferir) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerData(p.DtTransferencia, out var dia))
                return Resposta.Atencao("Data da transferência inválida.");
            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Transferencia_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["DtTransferencia"] = dia,
                ["IdContaOrigem"] = p.IdContaOrigem is > 0 ? p.IdContaOrigem : null,
                ["IdContaDestino"] = p.IdContaDestino is > 0 ? p.IdContaDestino : null,
                ["Valor"] = p.Valor,
                ["Historico"] = Banco.Cortar(p.Historico?.Trim(), 200),
                ["Documento"] = Banco.Cortar(p.Documento?.Trim(), 40),
                ["AvisosConfirmados"] = Banco.Cortar(string.Join(",", (p.AvisosConfirmados ?? []).Select(a => a.Trim().ToUpperInvariant())), 1000),
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["SomenteConferir"] = conferir
            }, usuario, http.RequestAborted);
            return ComAvisos(linha, conferir, new
            {
                id = linha.Long("ID"),
                idLote = linha.Long("ID_LOTE"),
                pendente = linha.Bool("PENDENTE"),
                avisos = ComoJson(linha.Texto("AVISOS"))
            });
        });

    private static Task<IResult> EstornarTransferencia(long id, TransferenciaEstornoPedido p, HttpContext http, Banco banco, ILogger<Program> logger, bool conferir) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerData(p.DtEstorno, out var dia))
                return Resposta.Atencao("Data do estorno inválida.");
            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Transferencia_Estornar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdTransferencia"] = id,
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["DtEstorno"] = dia,
                ["SomenteConferir"] = conferir
            }, usuario, http.RequestAborted);
            return ComAvisos(linha, conferir, new
            {
                id = linha.Long("ID"),
                valor = linha.GetValueOrDefault("VALOR"),
                pendente = linha.Bool("PENDENTE"),
                avisos = ComoJson(linha.Texto("AVISOS"))
            });
        });

    // ------------------------------------------------------------- extrato e saldos
    private static Task<IResult> Extrato(int? idConta, DateOnly? de, DateOnly? ate, bool? ocultarEstornados, string? texto,
                                         HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (idConta is not > 0)
                return Resposta.Atencao("Escolha a conta.");
            var linhas = await banco.ExecutarAsync("BANCO.BANCO_Extrato_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdConta"] = idConta,
                ["DtDe"] = de,
                ["DtAte"] = ate,
                ["OcultarEstornados"] = ocultarEstornados == true,
                ["Texto"] = Banco.Cortar(texto?.Trim(), 100)
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Saldos(DateOnly? data, int? idEmpresa, bool? todas, bool? inativas,
                                        HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("BANCO.BANCO_Saldo_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Data"] = data,
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["Todas"] = todas == true,
                ["IncluirInativas"] = inativas == true
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    // ------------------------------------------------------------- fechamento de caixa
    private static Task<IResult> ListarCaixa(int? idConta, int? idEmpresa, DateOnly? de, DateOnly? ate, string? situacao, bool? soComDiferenca,
                                             HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("BANCO.BANCO_Caixa_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdConta"] = idConta is > 0 ? idConta : null,
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["DtDe"] = de,
                ["DtAte"] = ate,
                ["Situacao"] = Banco.Cortar(situacao?.Trim().ToUpperInvariant(), 10),
                ["SoComDiferenca"] = soComDiferenca == true
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> FecharCaixa(CaixaFecharPedido p, HttpContext http, Banco banco, ILogger<Program> logger, bool conferir) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerData(p.DtFechamento, out var dia))
                return Resposta.Atencao("Data do fechamento inválida.");
            if (p.IdConta is not > 0)
                return Resposta.Atencao("Escolha a conta.");
            var linha = await banco.ExecutarUmaLinhaAsync("BANCO.BANCO_Caixa_Fechar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdConta"] = p.IdConta,
                ["DtFechamento"] = dia,
                ["SaldoContado"] = p.SaldoContado,
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["GerarAjuste"] = p.GerarAjuste == true,
                ["Observacao"] = Banco.Cortar(p.Observacao?.Trim(), 400),
                ["SomenteConferir"] = conferir
            }, usuario, http.RequestAborted);
            return ComAvisos(linha, conferir, new
            {
                id = linha.Long("ID"),
                saldoSistema = linha.GetValueOrDefault("SALDO_SISTEMA"),
                saldoContado = linha.GetValueOrDefault("SALDO_CONTADO"),
                diferenca = linha.GetValueOrDefault("DIFERENCA"),
                dtUltimoFechamento = linha.Texto("DT_ULTIMO_FECHAMENTO"),
                entradas = linha.GetValueOrDefault("ENTRADAS"),
                saidas = linha.GetValueOrDefault("SAIDAS"),
                qtdMovimentos = linha.Long("QTD_MOVIMENTOS"),
                podeAjuste = linha.Bool("PODE_AJUSTE"),
                idMovimentoAjuste = linha.Long("ID_MOVIMENTO_AJUSTE"),
                pendente = linha.Bool("PENDENTE"),
                avisos = ComoJson(linha.Texto("AVISOS"))
            });
        });

    private static Task<IResult> ReabrirCaixa(long id, CaixaReabrirPedido p, HttpContext http, Banco banco, ILogger<Program> logger, bool conferir) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("BANCO.BANCO_Caixa_Reabrir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdCaixaFechamento"] = id,
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["SomenteConferir"] = conferir
            }, usuario, http.RequestAborted);
            return ComAvisos(linha, conferir, new
            {
                id = linha.Long("ID"),
                valorAjuste = linha.GetValueOrDefault("VALOR_AJUSTE"),
                pendente = linha.Bool("PENDENTE"),
                avisos = ComoJson(linha.Texto("AVISOS"))
            });
        });

    // ------------------------------------------------------------- utilidades
    private static bool LerData(string? texto, out DateOnly? data)
    {
        data = null;
        if (string.IsNullOrWhiteSpace(texto))
            return true;
        if (!DateOnly.TryParseExact(texto.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d))
            return false;
        data = d;
        return true;
    }

    private static IResult ComAvisos(Linha linha, bool conferir, object dados)
    {
        var mensagem = linha.Texto("MENSAGEM");
        if (!linha.Bool("SUCESSO"))
            return Results.Json(new { sucesso = false, tipo = linha.Bool("PENDENTE") ? "PENDENTE" : "ATENCAO", mensagem, dados });
        if (conferir && linha.Bool("PENDENTE"))
            return Results.Json(new { sucesso = true, tipo = "PENDENTE", mensagem, dados });
        return Resposta.Ok(dados, mensagem);
    }

    private static JsonElement? ComoJson(string texto)
    {
        if (string.IsNullOrWhiteSpace(texto))
            return null;
        try { return JsonDocument.Parse(texto).RootElement.Clone(); }
        catch (JsonException) { return null; }
    }
}
