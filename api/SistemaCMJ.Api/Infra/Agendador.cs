// =============================================================================
//  SistemaCMJ.Api - Infra/Agendador.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 17/11/2026 (fase 3c)
//  Descrição : Substitui o SQL Server Agent (o Express não tem). A cada minuto,
//              enquanto o sistema estiver ligado:
//                1) SIS_Rotina_Processar: roda as rotinas vencidas da agenda
//                   (ex.: prévia do boletim semanal, sexta 9h). Rotina que
//                   venceu com o sistema desligado roda assim que ele liga;
//                2) envia os e-mails da fila (EnvioEmail).
//              Um passo com erro não impede o outro; o erro vai para o log do
//              serviço e para SIS.Log_Erro. Desliga com "Agendador:Ligado": false.
// =============================================================================
namespace SistemaCMJ.Api.Infra;

public sealed class Agendador(Banco banco, EnvioEmail envio, IConfiguration configuracao, ILogger<Agendador> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        if (string.Equals(configuracao["Agendador:Ligado"], "false", StringComparison.OrdinalIgnoreCase))
        {
            logger.LogInformation("Agendador desligado pela configuração (Agendador:Ligado = false).");
            return;
        }

        var servidor = Environment.MachineName;
        await Task.Delay(TimeSpan.FromSeconds(10), ct);   // deixa o sistema terminar de subir

        using var relogio = new PeriodicTimer(TimeSpan.FromMinutes(1));
        do
        {
            try
            {
                await banco.ExecutarAsync("SIS.SIS_Rotina_Processar",
                    new Dictionary<string, object?> { ["Servidor"] = servidor, ["Maximo"] = 10, ["Silencioso"] = true }, null, ct);
            }
            catch (Exception erro) when (erro is not OperationCanceledException)
            {
                logger.LogError(erro, "Falha ao processar a agenda de rotinas");
                await banco.RegistrarErroAsync("API Agendador", "Rotinas", erro);
            }

            try
            {
                await envio.ProcessarAsync(servidor, ct);
            }
            catch (Exception erro) when (erro is not OperationCanceledException)
            {
                logger.LogError(erro, "Falha ao enviar os e-mails da fila");
                await banco.RegistrarErroAsync("API Agendador", "E-mails", erro);
            }
        }
        while (await relogio.WaitForNextTickAsync(ct));
    }
}
