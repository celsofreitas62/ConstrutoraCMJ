// =============================================================================
//  SistemaCMJ.Api - Endpoints/BaixaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 26/11/2026 (etapa 04g)
//  Descrição : Baixa (pagamento e recebimento) e estorno das parcelas das
//              telas "Contas a pagar" e "Contas a receber". A API só repassa:
//              permissão, cálculo de juros/multa/desconto, regras e travas
//              estão em FIN_Baixa_Preparar / _Gravar / _Estornar.
//                GET  /api/fin/baixas/preparar?parcelas=1,2&data=aaaa-mm-dd
//                POST /api/fin/baixas/conferir     prévia (avisos)
//                POST /api/fin/baixas              grava
//                POST /api/fin/baixas/{id}/estornar/conferir
//                POST /api/fin/baixas/{id}/estornar
//              Mesmo contrato de avisos do lançamento:
//                tipo OK        gravado / prévia sem bloqueio
//                tipo PENDENTE  há aviso a confirmar ou motivo a informar
//                tipo ATENCAO   bloqueio ou dado inválido (dados.avisos)
// =============================================================================
using System.Globalization;
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record BaixaPedido(
    string? DtPagamento,
    int? IdConta,
    string? Forma,
    JsonElement? Itens,
    string? Documento,
    string? Observacao,
    string[]? AvisosConfirmados = null,
    string? Motivo = null);

public sealed record EstornoPedido(string? Motivo, string? DtEstorno);

public static class BaixaEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/fin/baixas/preparar", Preparar);
        app.MapPost("/api/fin/baixas/conferir", (BaixaPedido p, HttpContext h, Banco b, ILogger<Program> l) => Gravar(p, h, b, l, conferir: true));
        app.MapPost("/api/fin/baixas", (BaixaPedido p, HttpContext h, Banco b, ILogger<Program> l) => Gravar(p, h, b, l, conferir: false));
        app.MapPost("/api/fin/baixas/{id:long}/estornar/conferir", (long id, EstornoPedido p, HttpContext h, Banco b, ILogger<Program> l) => Estornar(id, p, h, b, l, conferir: true));
        app.MapPost("/api/fin/baixas/{id:long}/estornar", (long id, EstornoPedido p, HttpContext h, Banco b, ILogger<Program> l) => Estornar(id, p, h, b, l, conferir: false));
    }

    private static Task<IResult> Preparar(string? parcelas, string? data, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerData(data, out var dia))
                return Resposta.Atencao("Data de pagamento inválida.");
            var ids = string.Join(",", (parcelas ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                                                       .Where(t => long.TryParse(t, out var n) && n > 0).Distinct().Take(500));
            if (ids.Length == 0)
                return Resposta.Atencao("Escolha pelo menos uma parcela para baixar.");
            var linhas = await banco.ExecutarAsync("FIN.FIN_Baixa_Preparar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Parcelas"] = ids,
                ["DtPagamento"] = dia
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Gravar(BaixaPedido p, HttpContext http, Banco banco, ILogger<Program> logger, bool conferir) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerData(p.DtPagamento, out var dia))
                return Resposta.Atencao("Data de pagamento inválida.");
            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Baixa_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["DtPagamento"] = dia,
                ["IdConta"] = p.IdConta is > 0 ? p.IdConta : null,
                ["Forma"] = Banco.Cortar(p.Forma?.Trim().ToUpperInvariant(), 12),
                ["Itens"] = p.Itens is { ValueKind: JsonValueKind.Array } lista ? lista.GetRawText() : null,
                ["Documento"] = Banco.Cortar(p.Documento?.Trim(), 40),
                ["Observacao"] = Banco.Cortar(p.Observacao?.Trim(), 400),
                ["AvisosConfirmados"] = Banco.Cortar(string.Join(",", (p.AvisosConfirmados ?? []).Select(a => a.Trim().ToUpperInvariant())), 1000),
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["SomenteConferir"] = conferir
            }, usuario, http.RequestAborted);
            return ComAvisos(linha, conferir, new
            {
                id = linha.Long("ID"),
                idMovimento = linha.Long("ID_MOVIMENTO"),
                idLote = linha.Long("ID_LOTE"),
                pendente = linha.Bool("PENDENTE"),
                avisos = ComoJson(linha.Texto("AVISOS"))
            });
        });

    private static Task<IResult> Estornar(long id, EstornoPedido p, HttpContext http, Banco banco, ILogger<Program> logger, bool conferir) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerData(p.DtEstorno, out var dia))
                return Resposta.Atencao("Data do estorno inválida.");
            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Baixa_Estornar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdBaixa"] = id,
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400),
                ["DtEstorno"] = dia,
                ["SomenteConferir"] = conferir
            }, usuario, http.RequestAborted);
            return ComAvisos(linha, conferir, new
            {
                id = linha.Long("ID"),
                qtdBaixas = linha.Long("QTD_BAIXAS"),
                valor = linha.GetValueOrDefault("VALOR"),
                pendente = linha.Bool("PENDENTE"),
                avisos = ComoJson(linha.Texto("AVISOS"))
            });
        });

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
        using var documento = JsonDocument.Parse(texto);
        return documento.RootElement.Clone();
    }
}
