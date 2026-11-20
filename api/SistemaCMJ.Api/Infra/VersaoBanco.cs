// =============================================================================
//  SistemaCMJ.Api - Infra/VersaoBanco.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 20/11/2026 (fase 3d)
//  Descrição : Programa e banco na mesma versão (CLAUDE.md seção 7, fase 3d).
//              VersaoExigida é a versão do banco que ESTE programa espera; a
//              do banco vem de SIS.fn_SIS_Versao_Banco (gravada pelo MASTER em
//              sql/objetos/SIS/Carga_SIS_Versao.sql).
//              REGRA: toda mudança que vai para o MASTER sobe o número lá e
//              aqui, juntos.
//              Versão diferente: as telas recebem o aviso (só /api/saude
//              responde) e o agendador não roda rotinas nem e-mails. A
//              conferência é refeita a cada minuto: depois de rodar o MASTER,
//              o sistema volta sozinho, sem reiniciar o serviço.
// =============================================================================
namespace SistemaCMJ.Api.Infra;

public sealed class VersaoBanco(Banco banco, ILogger<VersaoBanco> logger)
{
    public const string VersaoExigida = "1.1";

    private readonly SemaphoreSlim trava = new(1, 1);
    private DateTime conferidaEm = DateTime.MinValue;
    private string versaoAtual = "";
    private bool ok;
    private bool avisouDiferenca;

    public string Atual => versaoAtual;

    /// <summary>true quando o banco está na versão que o programa espera.</summary>
    public async Task<bool> ConferirAsync(CancellationToken ct = default)
    {
        if (DateTime.UtcNow - conferidaEm < TimeSpan.FromMinutes(1))
            return ok;

        await trava.WaitAsync(ct);
        try
        {
            if (DateTime.UtcNow - conferidaEm < TimeSpan.FromMinutes(1))
                return ok;
            try
            {
                versaoAtual = Convert.ToString(await banco.EscalarAsync("SELECT SIS.fn_SIS_Versao_Banco()", null, ct)) ?? "";
            }
            catch (Exception erro) when (erro is not OperationCanceledException)
            {
                // Banco fora do ar ou sem a function (banco antigo): não trava as telas por isso;
                // a falha de conexão aparece nas próprias chamadas e em /api/saude.
                logger.LogWarning(erro, "Não consegui ler a versão do banco");
                versaoAtual = "";
                conferidaEm = DateTime.UtcNow.AddSeconds(-50);   // tenta de novo em 10 s
                ok = false;
                return ok;
            }
            var antes = ok;
            ok = versaoAtual == VersaoExigida;
            conferidaEm = DateTime.UtcNow;
            if (!ok && !avisouDiferenca)
            {
                logger.LogError("Versão do banco diferente da do programa: banco {Atual}, programa precisa da {Exigida}. Rode o MASTER da versão certa.",
                    versaoAtual.Length > 0 ? versaoAtual : "(sem versão)", VersaoExigida);
                avisouDiferenca = true;
            }
            if (ok && (!antes && avisouDiferenca))
            {
                logger.LogInformation("Versão do banco conferida: {Atual}.", versaoAtual);
                avisouDiferenca = false;
            }
            return ok;
        }
        finally
        {
            trava.Release();
        }
    }

    public string Mensagem() =>
        "O banco de dados está na versão " + (versaoAtual.Length > 0 ? versaoAtual : "(sem versão)") +
        " e o programa precisa da versão " + VersaoExigida + ". Peça ao administrador para atualizar o banco (rodar o MASTER).";
}
