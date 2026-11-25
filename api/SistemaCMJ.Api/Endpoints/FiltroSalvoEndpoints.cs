// =============================================================================
//  SistemaCMJ.Api - Endpoints/FiltroSalvoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (etapa 04f2a)
//  Descrição : Filtros salvos pelo usuário nas listas (genérico: o item é o
//              código da tela, ex.: FIN_RECEBER). O filtro é o JSON da tela.
//              Permissão, limite e dono: SIS_Filtro_Salvo_Listar / _Gravar /
//              _Excluir.
// =============================================================================
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record FiltroSalvoPedido(string? Item, string? Nome, string? Filtro, bool Padrao);

public static class FiltroSalvoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/sis/filtros", Listar);
        app.MapPost("/api/sis/filtros", Gravar);
        app.MapDelete("/api/sis/filtros/{id:int}", Excluir);
    }

    private static Task<IResult> Listar(string item, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Filtro_Salvo_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Item"] = Banco.Cortar(item?.Trim().ToUpperInvariant(), 40)
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Gravar(FiltroSalvoPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if ((p.Filtro ?? "").Length > 2000)
                return Resposta.Atencao("Filtro grande demais.");
            var linha = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Filtro_Salvo_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Item"] = Banco.Cortar(p.Item?.Trim().ToUpperInvariant(), 40),
                ["Nome"] = Banco.Cortar(p.Nome?.Trim(), 60),
                ["Filtro"] = p.Filtro ?? "",
                ["Padrao"] = p.Padrao
            }, usuario, http.RequestAborted);
            return Resultado(linha);
        });

    private static Task<IResult> Excluir(int id, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Filtro_Salvo_Excluir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["IdFiltroSalvo"] = id
            }, usuario, http.RequestAborted);
            return Resultado(linha);
        });

    private static IResult Resultado(Linha linha) =>
        linha.Bool("SUCESSO")
            ? Resposta.Ok(new { id = linha.Long("ID_FILTRO_SALVO") }, linha.Texto("MENSAGEM"))
            : Resposta.Atencao(linha.Texto("MENSAGEM"));
}
