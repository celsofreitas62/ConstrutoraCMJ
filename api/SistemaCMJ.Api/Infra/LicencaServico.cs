// =============================================================================
//  SistemaCMJ.Api - Infra/LicencaServico.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 20/11/2026 (fase 3d)
//  Descrição : Confere a licença (CLAUDE.md seção 3.5) ao subir, a cada login
//              e a cada minuto:
//                - arquivo Licenca:Arquivo (padrão %ProgramData%\SisCMJ\licenca.lic);
//                - assinatura com a chave pública embutida (LicencaChavePublica);
//                - servidor = este computador; validade (se houver).
//              Licença boa e diferente da do banco: grava em SIS.Licenca pelo
//              SIS_Licenca_Gravar (em nome do usuário "sistema"), que liga os
//              módulos liberados. Trocar a licença = trocar o arquivo; o sistema
//              pega sozinho em até 1 minuto.
//              Licença inválida: só /api/saude, /api/identidade e o primeiro
//              acesso respondem; as telas mostram o motivo e o código deste
//              servidor; o agendador não roda.
//              Desenvolvimento sem chave pública (par de chaves ainda não
//              criado): aceita, com aviso no registro.
// =============================================================================
using System.Text.Json;

namespace SistemaCMJ.Api.Infra;

public sealed class LicencaServico(Banco banco, IConfiguration configuracao, IHostEnvironment ambiente, ILogger<LicencaServico> logger)
{
    private readonly SemaphoreSlim trava = new(1, 1);
    private DateTime conferidaEm = DateTime.MinValue;
    private bool ok;
    private string motivo = "";
    private string ultimoMotivoAvisado = "-";
    private string textoGravado = "";

    public string CodigoServidor { get; } = LicencaFormato.CodigoDesteComputador();
    public LicencaDados? Dados { get; private set; }
    public string Motivo => motivo;

    public string Arquivo => configuracao["Licenca:Arquivo"] is { Length: > 0 } a
        ? Environment.ExpandEnvironmentVariables(a)
        : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SisCMJ", "licenca.lic");

    public async Task<bool> ConferirAsync(CancellationToken ct = default)
    {
        if (DateTime.UtcNow - conferidaEm < TimeSpan.FromMinutes(1))
            return ok;
        await trava.WaitAsync(ct);
        try
        {
            if (DateTime.UtcNow - conferidaEm < TimeSpan.FromMinutes(1))
                return ok;
            (ok, motivo) = await AvaliarAsync(ct);
            conferidaEm = DateTime.UtcNow;
            if (motivo != ultimoMotivoAvisado)
            {
                if (ok) logger.LogInformation("Licença: {Situacao}. Código deste servidor: {Codigo}.", motivo.Length > 0 ? motivo : "válida", CodigoServidor);
                else logger.LogError("Licença inválida: {Motivo}. Código deste servidor: {Codigo}. Arquivo: {Arquivo}.", motivo, CodigoServidor, Arquivo);
                ultimoMotivoAvisado = motivo;
            }
            return ok;
        }
        finally
        {
            trava.Release();
        }
    }

    private async Task<(bool, string)> AvaliarAsync(CancellationToken ct)
    {
        if (LicencaChavePublica.Pem.Length == 0)
            return ambiente.IsDevelopment()
                ? (true, "desenvolvimento sem par de chaves (licença não conferida)")
                : (false, "o programa não tem a chave pública de licença");
        if (!File.Exists(Arquivo))
            return (false, "arquivo de licença não encontrado");

        string texto;
        try { texto = await File.ReadAllTextAsync(Arquivo, ct); }
        catch (Exception erro) when (erro is not OperationCanceledException) { return (false, "não foi possível ler o arquivo de licença"); }

        var (dados, recusa) = LicencaFormato.Ler(texto, LicencaChavePublica.Pem);
        if (dados is null) return (false, recusa);
        if (!string.Equals(dados.Servidor, CodigoServidor, StringComparison.OrdinalIgnoreCase))
            return (false, "a licença foi emitida para outro servidor");
        if (dados.Validade is { Length: > 0 } v && DateOnly.TryParse(v, out var validade) && validade < DateOnly.FromDateTime(DateTime.Today))
            return (false, "a licença venceu em " + validade.ToString("dd/MM/yyyy"));

        Dados = dados;
        if (texto != textoGravado)
        {
            var gravada = await GravarNoBancoAsync(texto, dados, ct);
            if (gravada.Length > 0) return (false, gravada);
            textoGravado = texto;
        }
        return (true, "");
    }

    private async Task<string> GravarNoBancoAsync(string texto, LicencaDados dados, CancellationToken ct)
    {
        try
        {
            var atual = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Licenca_Obter", null, null, ct);
            if (atual.Bool("ENCONTRADA") && atual.Texto("CHAVE_LICENCA") == texto)
                return "";
            var idSistema = Convert.ToInt32(await banco.EscalarAsync("SELECT SIS.fn_SIS_Usuario_Id('sistema')", null, ct));
            var empresas = JsonSerializer.Serialize(new[]
            {
                new Dictionary<string, object?> { ["cnpj"] = dados.Cnpj, ["razao_social"] = dados.RazaoSocial, ["nome_fantasia"] = dados.NomeFantasia, ["principal"] = true }
            });
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Licenca_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = idSistema,
                ["ChaveLicenca"] = texto,
                ["IdServidor"] = dados.Servidor,
                ["DtEmissao"] = DateTime.Parse(dados.Emissao),
                ["DtValidade"] = dados.Validade is { Length: > 0 } v ? DateTime.Parse(v) : null,
                ["Modulos"] = string.Join(",", dados.Modulos),
                ["EmpresasJson"] = empresas
            }, null, ct);
            if (!r.Bool("SUCESSO"))
                return "o banco recusou a licença: " + r.Texto("MENSAGEM");
            logger.LogInformation("Licença instalada no banco: {Razao} ({Cnpj}), módulos {Modulos}.", dados.RazaoSocial, dados.Cnpj, string.Join(",", dados.Modulos));
            return "";
        }
        catch (Exception erro) when (erro is not OperationCanceledException)
        {
            logger.LogError(erro, "Falha ao gravar a licença no banco");
            return "não foi possível gravar a licença no banco";
        }
    }

    public string Mensagem() =>
        "A licença do sistema não é válida (" + motivo + "). Código deste servidor: " + CodigoServidor +
        ". Fale com o fornecedor do sistema.";
}
