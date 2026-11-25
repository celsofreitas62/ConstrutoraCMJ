// =============================================================================
//  SistemaCMJ.Api - Endpoints/CentroCustoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (etapa 04e)
//  Descrição : Tela "Centros de custo" (CAD_CENTRO_CUSTO) e a fonte das
//              escolhas com busca (GET /api/cad/seletor/{tipo}: PLANO, CENTRO
//              ou CONTA; componente js/seletor.js). A API só repassa:
//              permissão, validação e travas estão em CAD_Centro_Custo_Listar /
//              _Obter / _Gravar / _Excluir e CAD_Seletor_Listar.
//              Data de encerramento: a tela manda sempre (MexerEncerramento = 1).
//              04f (25/11/2026): escolhas PESSOA e HISTORICO; filtro = código do
//              tipo de parceiro que aparece primeiro (ex.: FORNECEDOR).
// =============================================================================
using System.Globalization;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record CentroCustoPedido(
    int? IdCentroCusto,
    int? IdEmpresa,
    string? Codigo,
    string? Descricao,
    string? Tipo,
    bool Contabil,
    int? IdContaBancariaPadrao,
    string? DtEncerramento);

public static class CentroCustoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/cad/centros-custo", Listar);
        app.MapGet("/api/cad/centros-custo/{id:int}", Obter);
        app.MapPost("/api/cad/centros-custo", Gravar);
        app.MapPost("/api/cad/centros-custo/{id:int}/excluir", Excluir);
        app.MapGet("/api/cad/seletor/{tipo}", Seletor);
    }

    private static Task<IResult> Listar(int? idEmpresa, bool? somenteAtivos, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("CAD.CAD_Centro_Custo_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["SomenteAtivos"] = somenteAtivos == true
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Obter(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Centro_Custo_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdCentroCusto"] = id
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Gravar(CentroCustoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            DateOnly? encerramento = null;
            if (!string.IsNullOrWhiteSpace(p.DtEncerramento))
            {
                if (!DateOnly.TryParseExact(p.DtEncerramento.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var data))
                    return Resposta.Atencao("Data de encerramento inválida.");
                encerramento = data;
            }
            var resultado = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Centro_Custo_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdCentroCusto"] = p.IdCentroCusto is > 0 ? p.IdCentroCusto : null,
                ["IdEmpresa"] = p.IdEmpresa,
                ["Codigo"] = Banco.Cortar(p.Codigo?.Trim(), 20),
                ["Descricao"] = Banco.Cortar(p.Descricao?.Trim(), 100),
                ["Tipo"] = Banco.Cortar(p.Tipo?.Trim(), 15),
                ["Contabil"] = p.Contabil,
                ["IdContaBancariaPadrao"] = p.IdContaBancariaPadrao is > 0 ? p.IdContaBancariaPadrao : null,
                ["DtEncerramento"] = encerramento,
                ["MexerEncerramento"] = true
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Excluir(int id, ExcluirPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Centro_Custo_Excluir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdCentroCusto"] = id,
                ["Reativar"] = pedido.Reativar
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Seletor(string tipo, string? busca, int? idEmpresa, int? idAtual, string? filtro, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("CAD.CAD_Seletor_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Tipo"] = Banco.Cortar(tipo.Trim().ToUpperInvariant(), 10),
                ["Busca"] = Banco.Cortar(busca?.Trim(), 100),
                ["IdEmpresa"] = idEmpresa is > 0 ? idEmpresa : null,
                ["IdAtual"] = idAtual is > 0 ? idAtual : null,
                ["Filtro"] = string.IsNullOrWhiteSpace(filtro) ? null : Banco.Cortar(filtro.Trim().ToUpperInvariant(), 20)
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });
}
