// =============================================================================
//  SistemaCMJ.Api - Endpoints/ParametroEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 26/11/2026 (etapa 04f2d)
//  Descrição : Telas "Parâmetros" (SIS_PARAMETRO, só o administrador geral) e
//              "Parâmetros de uso" (SIS_PARAMETRO_USO, os dois
//              administradores; ?uso=1). A API só repassa: permissão, nível,
//              conferência do valor, motivo obrigatório e efeito estão em
//              SIS_Parametro_Listar / _Conferir / _Gravar.
//                GET  /api/sis/parametros            lista (uso=1, texto)
//                POST /api/sis/parametros/conferir   prévia: pede motivo?
//                                                    efeito nas pendências
//                POST /api/sis/parametros/gravar     grava (valor, motivo)
// =============================================================================
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record ParametroPedido(string? Chave, string? Valor, string? Motivo);

public static class ParametroEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/sis/parametros", Listar);
        app.MapPost("/api/sis/parametros/conferir", Conferir);
        app.MapPost("/api/sis/parametros/gravar", Gravar);
    }

    private static Task<IResult> Listar(bool? uso, string? texto, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Parametro_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Texto"] = Banco.Cortar(texto?.Trim(), 100),
                ["SoUso"] = uso == true
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Conferir(ParametroPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Parametro_Conferir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Chave"] = Banco.Cortar(p.Chave?.Trim().ToUpperInvariant(), 60),
                ["Valor"] = Banco.Cortar(p.Valor ?? "", 4000)
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linha);
        });

    private static Task<IResult> Gravar(ParametroPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linha = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Parametro_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Chave"] = Banco.Cortar(p.Chave?.Trim().ToUpperInvariant(), 60),
                ["Valor"] = Banco.Cortar(p.Valor ?? "", 4000),
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400)
            }, usuario, http.RequestAborted);
            return linha.Bool("SUCESSO")
                ? Resposta.Ok(new { id = linha.Long("ID_PARAMETRO") }, linha.Texto("MENSAGEM"))
                : Resposta.Atencao(linha.Texto("MENSAGEM"));
        });
}
