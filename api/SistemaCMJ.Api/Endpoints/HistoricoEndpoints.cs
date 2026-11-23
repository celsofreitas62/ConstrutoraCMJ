// =============================================================================
//  SistemaCMJ.Api - Endpoints/HistoricoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 23/11/2026 (fase 4, conversa 04b2)
//  Descrição : Histórico padrão, desfazer e lixeira (pedido P20), para todas
//              as telas. A API só repassa: permissão, regras, prévia e
//              gravação (tudo ou nada) estão nas procedures da 04b:
//                aba Histórico      SIS_Historico_Listar (registro + filhas)
//                prévia/desfazer    SIS_Historico_Desfazer_Previa / _Desfazer
//                botão Excluir      SIS_Lixeira_Excluir (manda para a lixeira)
//                tela Lixeira       SIS_Lixeira_Listar / _Recuperar / _Manter /
//                                   _Esvaziar / _Prazo_Listar / _Prazo_Gravar
//                tela Auditoria     SIS_Auditoria_Listar (desfazer lote pela
//                                   prévia com @Item = SIS_AUDITORIA)
//              Única coisa feita aqui: senha nunca sai no histórico (campos
//              SENHA_* somem, inclusive de dentro da "foto" das inclusões).
// =============================================================================
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record DesfazerPedido(string? Item, string? Modo, string? Tabela, long? IdRegistro, long? IdAuditoria, string? DataHora, long? IdLote, string? Motivo);
public sealed record LixeiraExcluirPedido(string? Item, string? Tabela, long? IdRegistro, string? Motivo);
public sealed record LixeiraMotivoPedido(string? Motivo);
public sealed record LixeiraManterPedido(int? Dias);
public sealed record LixeiraEsvaziarPedido(long[]? Ids, string? Motivo);
public sealed record LixeiraPrazoPedido(string? Tabela, int? Dias);

public static class HistoricoEndpoints
{
    // Nome de cada parte da ficha no histórico (tabelas filhas que "vão junto").
    private static readonly Dictionary<string, string> Partes = new(StringComparer.OrdinalIgnoreCase)
    {
        ["CAD.Pessoa_Contato"] = "Contato",
        ["CAD.Pessoa_Vinculo"] = "Vínculo",
        ["CAD.Pessoa_Dado_Bancario"] = "Dado bancário",
        ["SIS.Usuario_Permissao"] = "Permissão individual",
        ["SIS.Perfil_Permissao"] = "Permissão"
    };

    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/sis/historico", Listar);
        app.MapPost("/api/sis/historico/previa", Previa);
        app.MapPost("/api/sis/historico/desfazer", Desfazer);

        app.MapPost("/api/sis/lixeira/excluir", Excluir);
        app.MapGet("/api/sis/lixeira", LixeiraListar);
        app.MapPost("/api/sis/lixeira/{id:long}/recuperar", Recuperar);
        app.MapPost("/api/sis/lixeira/{id:long}/manter", Manter);
        app.MapPost("/api/sis/lixeira/esvaziar", Esvaziar);
        app.MapGet("/api/sis/lixeira/prazos", PrazoListar);
        app.MapPost("/api/sis/lixeira/prazos", PrazoGravar);

        app.MapGet("/api/sis/auditoria", AuditoriaListar);
    }

    // ------------------------------------------------------------------ Histórico

    private static Task<IResult> Listar(string? item, string? tabela, long? id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Historico_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Item"] = Banco.Cortar(item, 40),
                ["Tabela"] = Banco.Cortar(tabela, 256),
                ["IdRegistro"] = id,
                ["MaxLinhas"] = 1000
            }, usuario, http.RequestAborted);
            var saida = new List<Linha>();
            foreach (var l in linhas)
            {
                var campo = l.Texto("CAMPO");
                if (Sigiloso(campo)) continue;
                if (campo.Equals("DT_SENHA", StringComparison.OrdinalIgnoreCase)) l["CAMPO"] = "Senha definida em";
                l["VALOR_ANTES"] = SemSenha(l.Texto("VALOR_ANTES"));
                l["VALOR_DEPOIS"] = SemSenha(l.Texto("VALOR_DEPOIS"));
                l["PARTE"] = l.Bool("PRINCIPAL") ? "" : Partes.GetValueOrDefault(l.Texto("TABELA"), l.Texto("TABELA"));
                saida.Add(l);
            }
            return Resposta.Ok(saida);
        });

    private static Task<IResult> Previa(DesfazerPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerDataHora(p.DataHora, out var dataHora))
                return Resposta.Atencao("Data e hora do ponto do histórico inválidas.");
            var linhas = await banco.ExecutarAsync("SIS.SIS_Historico_Desfazer_Previa", ParametrosDesfazer(p, dataHora, usuario, comMotivo: false), usuario, http.RequestAborted);
            foreach (var l in linhas)
            {
                if (Sigiloso(l.Texto("CAMPO"))) { l["VALOR_ATUAL"] = "(sigiloso)"; l["VALOR_NOVO"] = "(sigiloso)"; }
                l["VALOR_ATUAL"] = SemSenha(l.Texto("VALOR_ATUAL"));
                l["VALOR_NOVO"] = SemSenha(l.Texto("VALOR_NOVO"));
            }
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Desfazer(DesfazerPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!LerDataHora(p.DataHora, out var dataHora))
                return Resposta.Atencao("Data e hora do ponto do histórico inválidas.");
            if ((p.Motivo?.Trim().Length ?? 0) < 3)
                return Resposta.Atencao("Informe o motivo do desfazer.");
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Historico_Desfazer", ParametrosDesfazer(p, dataHora, usuario, comMotivo: true), usuario, http.RequestAborted);
            return r.Bool("SUCESSO")
                ? Resposta.Ok(new { id = r.Long("ID_DESFAZER"), registros = r.Int("QTD_REGISTROS"), campos = r.Int("QTD_CAMPOS"), lixeira = r.Int("QTD_LIXEIRA") }, r.Texto("MENSAGEM"))
                : Resposta.Atencao(r.Texto("MENSAGEM"));
        });

    private static Dictionary<string, object?> ParametrosDesfazer(DesfazerPedido p, DateTime? dataHora, Contexto usuario, bool comMotivo)
    {
        var parametros = new Dictionary<string, object?>
        {
            ["IdUsuario"] = usuario.IdUsuario,
            ["Item"] = Banco.Cortar(p.Item, 40),
            ["Modo"] = Banco.Cortar(p.Modo?.Trim().ToUpperInvariant(), 10),
            ["Tabela"] = Banco.Cortar(p.Tabela, 256),
            ["IdRegistro"] = p.IdRegistro,
            ["IdAuditoria"] = p.IdAuditoria,
            ["DataHora"] = dataHora,
            ["IdLote"] = p.IdLote
        };
        if (comMotivo) parametros["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400);
        return parametros;
    }

    // ------------------------------------------------------------------ Lixeira

    private static Task<IResult> Excluir(LixeiraExcluirPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Lixeira_Excluir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Item"] = Banco.Cortar(p.Item, 40),
                ["Tabela"] = Banco.Cortar(p.Tabela, 256),
                ["IdRegistro"] = p.IdRegistro,
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400)
            }, usuario, http.RequestAborted);
            return r.Bool("SUCESSO")
                ? Resposta.Ok(new { id = r.Long("ID_LIXEIRA"), dtApagar = r["DT_APAGAR"] }, r.Texto("MENSAGEM"))
                : Resposta.Atencao(r.Texto("MENSAGEM"));
        });

    private static Task<IResult> LixeiraListar(string? modulo, string? item, string? inicio, string? fim, string? usuario, string? texto, string? situacao,
        HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var quem = http.Usuario();
            if (!LerData(inicio, out var dtInicio) || !LerData(fim, out var dtFim))
                return Resposta.Atencao("Data do filtro inválida.");
            var linhas = await banco.ExecutarAsync("SIS.SIS_Lixeira_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = quem.IdUsuario,
                ["Modulo"] = Banco.Cortar(modulo, 10),
                ["Item"] = Banco.Cortar(item, 40),
                ["DtInicio"] = dtInicio,
                ["DtFim"] = dtFim,
                ["Usuario"] = Banco.Cortar(usuario?.Trim(), 100),
                ["Texto"] = Banco.Cortar(texto?.Trim(), 100),
                ["Situacao"] = SituacaoLixeira(situacao)
            }, quem, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Recuperar(long id, LixeiraMotivoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Lixeira_Recuperar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdLixeira"] = id,
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400)
            }, usuario, http.RequestAborted);
            return r.Bool("SUCESSO")
                ? Resposta.Ok(new { tabela = r.Texto("TABELA"), id = r.Long("ID_REGISTRO") }, r.Texto("MENSAGEM"))
                : Resposta.Atencao(r.Texto("MENSAGEM"));
        });

    private static Task<IResult> Manter(long id, LixeiraManterPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Lixeira_Manter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdLixeira"] = id,
                ["Dias"] = p.Dias
            }, usuario, http.RequestAborted);
            return r.Bool("SUCESSO") ? Resposta.Ok(new { dtApagar = r["DT_APAGAR"] }, r.Texto("MENSAGEM")) : Resposta.Atencao(r.Texto("MENSAGEM"));
        });

    private static Task<IResult> Esvaziar(LixeiraEsvaziarPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (p.Ids is not { Length: > 0 })
                return Resposta.Atencao("Marque os registros a apagar de vez.");
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Lixeira_Esvaziar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Ids"] = string.Join(",", p.Ids.Distinct()),
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400)
            }, usuario, http.RequestAborted);
            return r.Bool("SUCESSO")
                ? Resposta.Ok(new { apagados = r.Int("QTD_APAGADOS"), recusados = r.Int("QTD_RECUSADOS") }, r.Texto("MENSAGEM"))
                : Resposta.Atencao(r.Texto("MENSAGEM"));
        });

    private static Task<IResult> PrazoListar(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            return Resposta.Ok(await banco.ExecutarAsync("SIS.SIS_Lixeira_Prazo_Listar",
                new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario }, usuario, http.RequestAborted));
        });

    private static Task<IResult> PrazoGravar(LixeiraPrazoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Lixeira_Prazo_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Tabela"] = Banco.Cortar(p.Tabela, 256),
                ["Dias"] = p.Dias
            }, usuario, http.RequestAborted);
            return r.Bool("SUCESSO") ? Resposta.Ok(null, r.Texto("MENSAGEM")) : Resposta.Atencao(r.Texto("MENSAGEM"));
        });

    // ------------------------------------------------------------------ Auditoria (histórico geral)

    private static Task<IResult> AuditoriaListar(string? inicio, string? fim, string? usuario, string? tabela, long? idRegistro, string? operacao, long? lote,
        HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var quem = http.Usuario();
            if (!LerData(inicio, out var dtInicio) || !LerData(fim, out var dtFim))
                return Resposta.Atencao("Data do filtro inválida.");
            var linhas = await banco.ExecutarAsync("SIS.SIS_Auditoria_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = quem.IdUsuario,
                ["DtInicio"] = dtInicio,
                ["DtFim"] = dtFim,
                ["Usuario"] = Banco.Cortar(usuario?.Trim(), 100),
                ["Tabela"] = Banco.Cortar(tabela?.Trim(), 256),
                ["IdRegistro"] = idRegistro,
                ["Operacao"] = Banco.Cortar(operacao?.Trim().ToUpperInvariant(), 1),
                ["IdLote"] = lote,
                ["MaxLinhas"] = 2000
            }, quem, http.RequestAborted);
            var saida = new List<Linha>();
            foreach (var l in linhas)
            {
                if (Sigiloso(l.Texto("CAMPO"))) continue;
                l["VALOR_ANTES"] = SemSenha(l.Texto("VALOR_ANTES"));
                l["VALOR_DEPOIS"] = SemSenha(l.Texto("VALOR_DEPOIS"));
                saida.Add(l);
            }
            return Resposta.Ok(saida);
        });

    // ------------------------------------------------------------------ Apoio

    /// <summary>LIXEIRA (padrão), RECUPERADO, APAGADO ou TODOS (vazio = todas).</summary>
    private static string SituacaoLixeira(string? situacao)
    {
        var s = (situacao ?? "LIXEIRA").Trim().ToUpperInvariant();
        return s == "TODOS" ? "" : Banco.Cortar(s, 12);
    }

    private static bool Sigiloso(string campo) => campo.StartsWith("SENHA_", StringComparison.OrdinalIgnoreCase);

    /// <summary>Tira os campos de senha da "foto" (JSON) de inclusões e exclusões.</summary>
    private static string SemSenha(string valor)
    {
        if (valor.Length < 2 || valor[0] != '{' || !valor.Contains("SENHA_", StringComparison.OrdinalIgnoreCase))
            return valor;
        try
        {
            if (JsonNode.Parse(valor) is not JsonObject objeto) return valor;
            foreach (var chave in objeto.Select(p => p.Key).Where(Sigiloso).ToList())
                objeto.Remove(chave);
            return objeto.ToJsonString();
        }
        catch (JsonException)
        {
            return valor;
        }
    }

    private static bool LerData(string? texto, out DateOnly? data)
    {
        data = null;
        if (string.IsNullOrWhiteSpace(texto)) return true;
        if (!DateOnly.TryParseExact(texto.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)) return false;
        data = d;
        return true;
    }

    private static bool LerDataHora(string? texto, out DateTime? dataHora)
    {
        dataHora = null;
        if (string.IsNullOrWhiteSpace(texto)) return true;
        if (!DateTime.TryParse(texto.Trim(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out var d)) return false;
        dataHora = d;
        return true;
    }
}
