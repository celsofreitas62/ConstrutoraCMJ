// =============================================================================
//  SistemaCMJ.Api - Endpoints/PlanoContaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (etapa 04e)
//  Descrição : Tela "Plano de contas" (CAD_PLANO_CONTA), em árvore: grupo
//              (nível 1) › subgrupo (2) › conta (3). A API só repassa:
//              permissão, validação e travas (conta/subgrupo com lançamento não
//              muda de lugar) estão em CAD_Plano_Conta_Listar,
//              CAD_Plano_Grupo_Gravar, _Subgrupo_Gravar, _Conta_Gravar e
//              CAD_Plano_Excluir (Desativar/Reativar por nível).
// =============================================================================
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record PlanoItemPedido(
    int Nivel,
    int? Id,
    int? IdPai,
    short? Numero,
    string? Descricao,
    string? Tipo,
    bool CustoObra,
    short? Ordem,
    bool Contabil,
    string? ContaContabilRef);

public sealed record PlanoExcluirPedido(int Nivel, bool Reativar);

public static class PlanoContaEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/cad/plano-contas", Listar);
        app.MapPost("/api/cad/plano-contas", Gravar);
        app.MapPost("/api/cad/plano-contas/{id:int}/excluir", Excluir);
    }

    private static Task<IResult> Listar(bool? somenteAtivos, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("CAD.CAD_Plano_Conta_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["SomenteAtivos"] = somenteAtivos == true
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Gravar(PlanoItemPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var id = p.Id is > 0 ? p.Id : null;
            var descricao = Banco.Cortar(p.Descricao?.Trim(), 80);
            var (procedure, parametros) = p.Nivel switch
            {
                1 => ("CAD.CAD_Plano_Grupo_Gravar", new Dictionary<string, object?>
                {
                    ["IdPlanoGrupo"] = id, ["Numero"] = p.Numero, ["Descricao"] = descricao,
                    ["Tipo"] = Banco.Cortar(p.Tipo?.Trim(), 15), ["CustoObra"] = p.CustoObra, ["Ordem"] = p.Ordem
                }),
                2 => ("CAD.CAD_Plano_Subgrupo_Gravar", new Dictionary<string, object?>
                {
                    ["IdPlanoSubgrupo"] = id, ["IdPlanoGrupo"] = p.IdPai, ["Numero"] = p.Numero, ["Descricao"] = descricao, ["Ordem"] = p.Ordem
                }),
                3 => ("CAD.CAD_Plano_Conta_Gravar", new Dictionary<string, object?>
                {
                    ["IdPlanoConta"] = id, ["IdPlanoSubgrupo"] = p.IdPai, ["Numero"] = p.Numero, ["Descricao"] = descricao,
                    ["Contabil"] = p.Contabil, ["ContaContabilRef"] = Banco.Cortar(p.ContaContabilRef?.Trim(), 30)
                }),
                _ => (null as string, null as Dictionary<string, object?>)
            };
            if (procedure is null || parametros is null)
                return Resposta.Atencao("Nível do plano de contas inválido.");
            parametros["IdUsuario"] = usuario.IdUsuario;
            var resultado = await banco.ExecutarUmaLinhaAsync(procedure, parametros, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Excluir(int id, PlanoExcluirPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Plano_Excluir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Nivel"] = (byte)pedido.Nivel,
                ["Id"] = id,
                ["Reativar"] = pedido.Reativar
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });
}
