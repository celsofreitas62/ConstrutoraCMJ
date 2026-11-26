// =============================================================================
//  SistemaCMJ.Api - Endpoints/PendenciaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 26/11/2026 (etapa 04f2c, P27)
//  Descrição : Pendências dos lançamentos (contas a pagar e a receber) e tela
//              "Tipos de pendência" (FIN_PENDENCIA_TIPO). A API só repassa:
//              permissão, regras e as pendências automáticas estão no banco
//              (FIN.fn_FIN_Lancamento_Pendencias e procedures FIN_Pendencia_* /
//              FIN_Lancamento_Pendencia_*). Filtro e colunas da lista e
//              contadores ficam em /api/fin/lancamentos e /resumo.
//              Excluir um tipo vai pela lixeira genérica (POST
//              /api/sis/lixeira/excluir, Item FIN_PENDENCIA_TIPO, Tabela
//              FIN.Pendencia_Tipo).
// =============================================================================
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record PendenciaTipoPedido(int? IdPendenciaTipo, string? Codigo, string? Descricao, string? Orientacao,
                                         string? AplicaA, bool BloqueiaBaixa = false, int? Ordem = null, bool Ativo = true);

public sealed record PendenciaPedido(long? IdLancamentoPendencia, long? IdParcela, int? IdPendenciaTipo, string? Observacao,
                                     int? IdResponsavel, string? DtPrevisao, bool Ativo = true);

public sealed record PendenciaResolverPedido(string? Resolucao);

public static class PendenciaEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/fin/pendencia-tipos", ListarTipos);
        app.MapPost("/api/fin/pendencia-tipos", GravarTipo);
        app.MapGet("/api/fin/pendencias/responsaveis", Responsaveis);
        app.MapGet("/api/fin/lancamentos/{id:long}/pendencias", Listar);
        app.MapPost("/api/fin/lancamentos/{id:long}/pendencias", Gravar);
        app.MapPost("/api/fin/pendencias/{idPendencia:long}/resolver", Resolver);
        app.MapPost("/api/fin/pendencias/{idPendencia:long}/reabrir", Reabrir);
    }

    private static Task<IResult> ListarTipos(string? busca, bool? somenteAtivos, string? tipo, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("FIN.FIN_Pendencia_Tipo_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Busca"] = Banco.Cortar(busca?.Trim(), 60),
                ["SomenteAtivos"] = somenteAtivos == true,
                ["Tipo"] = string.IsNullOrWhiteSpace(tipo) ? null : Banco.Cortar(tipo.Trim().ToUpperInvariant(), 1)
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> GravarTipo(PendenciaTipoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Pendencia_Tipo_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdPendenciaTipo"] = p.IdPendenciaTipo is > 0 ? p.IdPendenciaTipo : null,
                ["Codigo"] = Banco.Cortar(p.Codigo?.Trim().ToUpperInvariant(), 20),
                ["Descricao"] = Banco.Cortar(p.Descricao?.Trim(), 60),
                ["Orientacao"] = Banco.Cortar(p.Orientacao?.Trim(), 400),
                ["AplicaA"] = Banco.Cortar(string.IsNullOrWhiteSpace(p.AplicaA) ? "A" : p.AplicaA.Trim().ToUpperInvariant(), 1),
                ["BloqueiaBaixa"] = p.BloqueiaBaixa,
                ["Ordem"] = p.Ordem,
                ["Ativo"] = p.Ativo
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    /// <summary>Usuários que podem ser responsáveis por uma pendência (só ID, nome e login).</summary>
    private static Task<IResult> Responsaveis(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("FIN.FIN_Pendencia_Responsavel_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    /// <summary>Quadro de pendências da ficha: automáticas e manuais (abertas e, se pedido, resolvidas).</summary>
    private static Task<IResult> Listar(long id, bool? incluirResolvidas, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("FIN.FIN_Lancamento_Pendencia_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdLancamento"] = id,
                ["IncluirResolvidas"] = incluirResolvidas != false
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    /// <summary>Inclui (sem idLancamentoPendencia) ou altera uma pendência manual; ativo = false desativa a lançada por engano.</summary>
    private static Task<IResult> Gravar(long id, PendenciaPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            DateOnly? previsao = null;
            if (!string.IsNullOrWhiteSpace(p.DtPrevisao))
            {
                if (!DateOnly.TryParse(p.DtPrevisao.Trim(), System.Globalization.CultureInfo.InvariantCulture, out var d))
                    return Resposta.Atencao("Data de previsão inválida.");
                previsao = d;
            }
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Lancamento_Pendencia_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdLancamentoPendencia"] = p.IdLancamentoPendencia is > 0 ? p.IdLancamentoPendencia : null,
                ["IdLancamento"] = id,
                ["IdParcela"] = p.IdParcela is > 0 ? p.IdParcela : null,
                ["IdPendenciaTipo"] = p.IdPendenciaTipo,
                ["Observacao"] = Banco.Cortar(p.Observacao?.Trim(), 1000),
                ["IdUsuarioResponsavel"] = p.IdResponsavel is > 0 ? p.IdResponsavel : null,
                ["DtPrevisao"] = previsao,
                ["Ativo"] = p.Ativo
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Resolver(long idPendencia, PendenciaResolverPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Lancamento_Pendencia_Resolver", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdLancamentoPendencia"] = idPendencia,
                ["Resolucao"] = Banco.Cortar(p.Resolucao?.Trim(), 1000)
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Reabrir(long idPendencia, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("FIN.FIN_Lancamento_Pendencia_Reabrir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdLancamentoPendencia"] = idPendencia
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });
}
