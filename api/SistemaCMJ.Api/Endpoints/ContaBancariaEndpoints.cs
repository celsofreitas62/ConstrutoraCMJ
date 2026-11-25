// =============================================================================
//  SistemaCMJ.Api - Endpoints/ContaBancariaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (etapa 04e)
//  Descrição : Telas "Contas bancárias" (BANCO_CONTA) e "Bancos"
//              (BANCO_BANCO). A API só repassa: permissão, validação e travas
//              (conta com movimento, mês fechado) estão nas procedures
//              BANCO_Conta_Listar / _Obter / _Gravar / _Excluir e
//              BANCO_Banco_Listar / _Gravar. A lista de bancos ativos para as
//              escolhas continua em GET /api/banco/bancos (SistemaEndpoints).
// =============================================================================
using System.Globalization;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record ContaBancariaPedido(
    int? IdConta,
    int? IdEmpresa,
    string? Descricao,
    string? Tipo,
    int? IdBanco,
    string? Agencia,
    string? AgenciaDv,
    string? Numero,
    string? NumeroDv,
    decimal? LimiteCredito,
    decimal? SaldoInicial,
    string? DtSaldoInicial,
    bool Concilia,
    bool MostraSaldo,
    string? ContaContabilRef,
    short? Ordem);

public sealed record BancoPedido(int? IdBanco, string? Codigo, string? Ispb, string? Nome, bool Ativo = true);

public static class ContaBancariaEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/banco/contas", Listar);
        app.MapGet("/api/banco/contas/{id:int}", Obter);
        app.MapPost("/api/banco/contas", Gravar);
        app.MapPost("/api/banco/contas/{id:int}/excluir", Excluir);
        app.MapGet("/api/banco/bancos/todos", ListarBancos);
        app.MapPost("/api/banco/bancos", GravarBanco);
    }

    private static Task<IResult> Listar(int? idEmpresa, bool? somenteAtivos, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("BANCO.BANCO_Conta_Listar", new Dictionary<string, object?>
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
            var linha = await banco.ExecutarUmaLinhaAsync("BANCO.BANCO_Conta_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdConta"] = id
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Gravar(ContaBancariaPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            DateOnly? dtSaldo = null;
            if (!string.IsNullOrWhiteSpace(p.DtSaldoInicial))
            {
                if (!DateOnly.TryParseExact(p.DtSaldoInicial.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var data))
                    return Resposta.Atencao("Data do saldo inicial inválida.");
                dtSaldo = data;
            }
            var resultado = await banco.ExecutarUmaLinhaAsync("BANCO.BANCO_Conta_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdConta"] = p.IdConta is > 0 ? p.IdConta : null,
                ["IdEmpresa"] = p.IdEmpresa,
                ["Descricao"] = Banco.Cortar(p.Descricao?.Trim(), 60),
                ["Tipo"] = Banco.Cortar(p.Tipo?.Trim(), 10),
                ["IdBanco"] = p.IdBanco is > 0 ? p.IdBanco : null,
                ["Agencia"] = Banco.Cortar(p.Agencia?.Trim(), 10),
                ["AgenciaDv"] = Banco.Cortar(p.AgenciaDv?.Trim(), 2),
                ["Numero"] = Banco.Cortar(p.Numero?.Trim(), 20),
                ["NumeroDv"] = Banco.Cortar(p.NumeroDv?.Trim(), 2),
                ["LimiteCredito"] = p.LimiteCredito ?? 0m,
                ["SaldoInicial"] = p.SaldoInicial ?? 0m,
                ["DtSaldoInicial"] = dtSaldo,
                ["Concilia"] = p.Concilia,
                ["MostraSaldo"] = p.MostraSaldo,
                ["ContaContabilRef"] = Banco.Cortar(p.ContaContabilRef?.Trim(), 30),
                ["Ordem"] = p.Ordem ?? (short)0
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> Excluir(int id, ExcluirPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("BANCO.BANCO_Conta_Excluir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdConta"] = id,
                ["Reativar"] = pedido.Reativar
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static Task<IResult> ListarBancos(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("BANCO.BANCO_Banco_Listar",
                new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario, ["SomenteAtivos"] = false }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> GravarBanco(BancoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("BANCO.BANCO_Banco_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdBanco"] = p.IdBanco is > 0 ? p.IdBanco : null,
                ["Codigo"] = Banco.Cortar(p.Codigo?.Trim(), 10),
                ["Ispb"] = Banco.Cortar(p.Ispb?.Trim(), 20),
                ["Nome"] = Banco.Cortar(p.Nome?.Trim(), 80),
                ["Ativo"] = p.Ativo
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });
}
