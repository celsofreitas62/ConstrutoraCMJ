// =============================================================================
//  SistemaCMJ.Api - Endpoints/ParceiroTipoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (etapa 04d2)
//  Descrição : Tela "Tipos de parceiro" (CAD_PARCEIRO_TIPO). A API só repassa:
//              permissão e validação estão em CAD_Parceiro_Tipo_Listar/_Gravar.
//              Tipos de fábrica (SISTEMA = 1) são protegidos pela procedure.
// =============================================================================
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record ParceiroTipoPedido(int? IdParceiroTipo, string? Codigo, string? Descricao, int? Ordem, bool Ativo = true);

public static class ParceiroTipoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/cad/parceiro-tipos", Listar);
        app.MapPost("/api/cad/parceiro-tipos", Gravar);
    }

    private static Task<IResult> Listar(string? busca, bool? somenteAtivos, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("CAD.CAD_Parceiro_Tipo_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Busca"] = Banco.Cortar(busca?.Trim(), 60),
                ["SomenteAtivos"] = somenteAtivos == true
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Gravar(ParceiroTipoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Parceiro_Tipo_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdParceiroTipo"] = p.IdParceiroTipo is > 0 ? p.IdParceiroTipo : null,
                ["Codigo"] = Banco.Cortar(p.Codigo?.Trim().ToUpperInvariant(), 20),
                ["Descricao"] = Banco.Cortar(p.Descricao?.Trim(), 60),
                ["Ordem"] = p.Ordem,
                ["Ativo"] = p.Ativo
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });
}
