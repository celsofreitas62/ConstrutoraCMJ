// =============================================================================
//  SistemaCMJ.Api - Endpoints/SaudeEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 20/11/2026 (fase 3d)
//  Descrição : Endereço de "saúde" do sistema: GET /api/saude (sem login).
//              Diz se o serviço está no ar e se o banco responde, com a versão
//              do programa. Serve para o roteiro de instalação, para conferir
//              depois de uma atualização e para monitoramento.
//              Resposta: 200 quando tudo está bem; 503 quando o banco não
//              responde. Não mostra detalhe técnico do erro (vai para o
//              registro em arquivo).
// =============================================================================
using System.Diagnostics;
using System.Reflection;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public static class SaudeEndpoints
{
    public static string VersaoPrograma { get; } =
        (typeof(SaudeEndpoints).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "0")
        .Split('+')[0];

    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/saude", Saude);
    }

    private static async Task<IResult> Saude(Banco banco, ILogger<Banco> logger, CancellationToken ct)
    {
        var relogio = Stopwatch.StartNew();
        var bancoOk = false;
        try
        {
            using var limite = CancellationTokenSource.CreateLinkedTokenSource(ct);
            limite.CancelAfter(TimeSpan.FromSeconds(10));
            bancoOk = Convert.ToInt32(await banco.EscalarAsync("SELECT 1", null, limite.Token)) == 1;
        }
        catch (Exception erro)
        {
            logger.LogError(erro, "Saúde: o banco não respondeu");
        }
        relogio.Stop();

        var corpo = new
        {
            sistema = "SisCMJ",
            situacao = bancoOk ? "ok" : "banco_fora",
            versao = VersaoPrograma,
            banco = bancoOk ? "ok" : "erro",
            tempoBancoMs = relogio.ElapsedMilliseconds,
            horario = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
        };
        return Results.Json(corpo, statusCode: bancoOk ? StatusCodes.Status200OK : StatusCodes.Status503ServiceUnavailable);
    }
}
