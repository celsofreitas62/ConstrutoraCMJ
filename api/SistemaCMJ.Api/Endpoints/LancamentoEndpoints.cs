// =============================================================================
//  SistemaCMJ.Api - Endpoints/LancamentoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (etapa 04f)
//  Descrição : Telas "Contas a pagar" (FIN_PAGAR) e "Contas a receber"
//              (FIN_RECEBER), ficha do lançamento e aba Movimentação do
//              Parceiro. A API só repassa: permissão, regras, proteções contra
//              erro de digitação (P17) e travas estão em FIN_Lancamento_Listar
//              / _Obter / _Conferir / _Gravar / _Cancelar / _Padroes_Obter.
//              Excluir vai pela lixeira genérica (POST /api/sis/lixeira/excluir,
//              Item FIN_PAGAR ou FIN_RECEBER, Tabela FIN.Lancamento).
//              Gravar e conferir devolvem os avisos (JSON da procedure):
//                tipo OK        gravado (dados.id) / prévia sem bloqueio
//                tipo PENDENTE  há aviso a confirmar ou motivo a informar
//                tipo ATENCAO   bloqueio ou dado inválido (dados.avisos)
// =============================================================================
using System.Globalization;
using System.Text.Json;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record LancamentoPedido(
    long? IdLancamento,
    string? Tipo,
    int? IdCentroCusto,
    int? IdPessoa,
    int? IdPlanoConta,
    int? IdHistoricoPadrao,
    string? Documento,
    string? DtEmissao,
    string? DtCompetencia,
    string? Historico,
    string? Observacao,
    decimal? ValorTotal,
    bool Previsao,
    string? Integracao,
    JsonElement? Parcelas,
    string[]? AvisosConfirmados = null,
    string? MotivoRetroativo = null,
    bool MarcarTipoParceiro = false);

public sealed record CancelarPedido(string? Motivo);

public static class LancamentoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/fin/lancamentos", Listar);
        app.MapGet("/api/fin/lancamentos/padroes", Padroes);
        app.MapGet("/api/fin/lancamentos/{id:long}", Obter);
        app.MapPost("/api/fin/lancamentos", Gravar);
        app.MapPost("/api/fin/lancamentos/conferir", Conferir);
        app.MapPost("/api/fin/lancamentos/{id:long}/cancelar", Cancelar);
    }

    private static Task<IResult> Listar(string? tipo, string? visao, string? situacao, DateOnly? vencDe, DateOnly? vencAte,
                                        int? idEmpresa, int? idCentroCusto, int? idPessoa, int? idPlanoConta, long? idLote,
                                        long? idLancamento, string? documento, string? texto, decimal? valorDe, decimal? valorAte,
                                        string? ordem, int? pagina, int? porPagina,
                                        HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("FIN.FIN_Lancamento_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Tipo"] = string.IsNullOrWhiteSpace(tipo) ? null : Banco.Cortar(tipo.Trim().ToUpperInvariant(), 1),
                ["Visao"] = Banco.Cortar(visao?.Trim().ToUpperInvariant(), 12),
                ["Situacao"] = Banco.Cortar(situacao?.Trim().ToUpperInvariant(), 12),
                ["VencDe"] = vencDe,
                ["VencAte"] = vencAte,
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["IdCentroCusto"] = idCentroCusto is > 0 ? idCentroCusto : null,
                ["IdPessoa"] = idPessoa is > 0 ? idPessoa : null,
                ["IdPlanoConta"] = idPlanoConta is > 0 ? idPlanoConta : null,
                ["IdLote"] = idLote is > 0 ? idLote : null,
                ["IdLancamento"] = idLancamento is > 0 ? idLancamento : null,
                ["Documento"] = Banco.Cortar(documento?.Trim(), 40),
                ["Texto"] = Banco.Cortar(texto?.Trim(), 100),
                ["ValorDe"] = valorDe,
                ["ValorAte"] = valorAte,
                ["Ordem"] = Banco.Cortar(ordem?.Trim().ToUpperInvariant(), 12),
                ["Pagina"] = pagina is > 0 ? pagina : 1,
                ["PorPagina"] = porPagina is > 0 ? porPagina : null
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Obter(long id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Lancamento_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdLancamento"] = id
            }, usuario, http.RequestAborted);
            foreach (var coluna in new[] { "PARCELAS", "BAIXAS", "AVISOS_CONFIRMADOS" })
                linha[coluna] = ComoJson(linha.Texto(coluna));
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Padroes(int idPessoa, string tipo, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Lancamento_Padroes_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdPessoa"] = idPessoa,
                ["Tipo"] = Banco.Cortar(tipo.Trim().ToUpperInvariant(), 1)
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Gravar(LancamentoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerDatas(p, out var emissao, out var competencia, out var recusa))
                return Resposta.Atencao(recusa);

            var parametros = Parametros(p, usuario.IdUsuario, emissao, competencia);
            parametros["AvisosConfirmados"] = Banco.Cortar(string.Join(",", (p.AvisosConfirmados ?? []).Select(a => a.Trim().ToUpperInvariant())), 1000);
            parametros["MotivoRetroativo"] = Banco.Cortar(p.MotivoRetroativo?.Trim(), 400);
            parametros["MarcarTipoParceiro"] = p.MarcarTipoParceiro;

            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Lancamento_Gravar", parametros, usuario, http.RequestAborted);
            return ComAvisos(linha, conferir: false);
        });

    private static Task<IResult> Conferir(LancamentoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerDatas(p, out var emissao, out var competencia, out var recusa))
                return Resposta.Atencao(recusa);

            var linha = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Lancamento_Conferir", Parametros(p, usuario.IdUsuario, emissao, competencia),
                                                          usuario, http.RequestAborted);
            return ComAvisos(linha, conferir: true);
        });

    private static Task<IResult> Cancelar(long id, CancelarPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Lancamento_Cancelar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdLancamento"] = id,
                ["Motivo"] = Banco.Cortar(pedido.Motivo?.Trim(), 400)
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Dictionary<string, object?> Parametros(LancamentoPedido p, int idUsuario, DateOnly? emissao, DateOnly? competencia) => new()
    {
        ["IdUsuario"] = idUsuario,
        ["IdLancamento"] = p.IdLancamento is > 0 ? p.IdLancamento : null,
        ["Tipo"] = string.IsNullOrWhiteSpace(p.Tipo) ? null : Banco.Cortar(p.Tipo.Trim().ToUpperInvariant(), 1),
        ["IdCentroCusto"] = p.IdCentroCusto is > 0 ? p.IdCentroCusto : null,
        ["IdPessoa"] = p.IdPessoa is > 0 ? p.IdPessoa : null,
        ["IdPlanoConta"] = p.IdPlanoConta is > 0 ? p.IdPlanoConta : null,
        ["IdHistoricoPadrao"] = p.IdHistoricoPadrao is > 0 ? p.IdHistoricoPadrao : null,
        ["Documento"] = Banco.Cortar(p.Documento?.Trim(), 40),
        ["DtEmissao"] = emissao,
        ["DtCompetencia"] = competencia,
        ["Historico"] = Banco.Cortar(p.Historico?.Trim(), 200),
        ["Observacao"] = Banco.Cortar(p.Observacao?.Trim(), 2000),
        ["ValorTotal"] = p.ValorTotal,
        ["Previsao"] = p.Previsao,
        ["Integracao"] = Banco.Cortar(p.Integracao?.Trim().ToUpperInvariant(), 12),
        ["Parcelas"] = p.Parcelas is { ValueKind: JsonValueKind.Array } lista ? lista.GetRawText() : null
    };

    private static bool LerDatas(LancamentoPedido p, out DateOnly? emissao, out DateOnly? competencia, out string recusa)
    {
        emissao = null;
        competencia = null;
        recusa = "";
        if (!string.IsNullOrWhiteSpace(p.DtEmissao))
        {
            if (!DateOnly.TryParseExact(p.DtEmissao.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var data))
            {
                recusa = "Data de emissão inválida.";
                return false;
            }
            emissao = data;
        }
        if (!string.IsNullOrWhiteSpace(p.DtCompetencia))
        {
            var texto = p.DtCompetencia.Trim();
            if (texto.Length == 7) texto += "-01";
            if (!DateOnly.TryParseExact(texto, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var mes))
            {
                recusa = "Mês de competência inválido.";
                return false;
            }
            competencia = mes;
        }
        return true;
    }

    /// <summary>Resposta da gravação ou da prévia com os avisos da procedure.</summary>
    private static IResult ComAvisos(Linha linha, bool conferir)
    {
        var mensagem = linha.Texto("MENSAGEM");
        var dados = new
        {
            id = linha.Long("ID"),
            pendente = linha.Bool("PENDENTE"),
            avisos = ComoJson(linha.Texto("AVISOS"))
        };
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
