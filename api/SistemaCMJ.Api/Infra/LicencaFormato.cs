// =============================================================================
//  SistemaCMJ.Api - Infra/LicencaFormato.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 20/11/2026 (fase 3d)
//  Descrição : Formato do arquivo de licença (CLAUDE.md seção 3.5), usado pela
//              API (conferir) e pelo gerador de licença (assinar), que inclui
//              este mesmo arquivo: os dois nunca divergem.
//              Arquivo licenca.lic (texto):
//                linha 1: SISCMJ-LICENCA-1
//                linha 2: dados em JSON (UTF-8), em Base64
//                linha 3: assinatura ECDSA P-256 / SHA-256 dos bytes do JSON, em Base64
//              A licença é ligada ao "código do servidor": o MachineGuid do
//              Windows (HKLM\SOFTWARE\Microsoft\Cryptography), único por
//              instalação do Windows. Copiar o sistema para outro computador
//              invalida a licença.
//              Nada aqui é segredo: a chave PRIVADA fica só com o Celso (arquivo
//              cifrado com senha, fora do projeto); a pública vai no programa.
// =============================================================================
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace SistemaCMJ.Api.Infra;

public sealed record LicencaDados(
    int Versao,
    string RazaoSocial,
    string Cnpj,
    string NomeFantasia,
    string Servidor,
    string[] Modulos,
    string Emissao,
    string? Validade,
    string Observacao);

public static class LicencaFormato
{
    public const string Cabecalho = "SISCMJ-LICENCA-1";
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <summary>Monta o texto do arquivo, assinado com a chave privada.</summary>
    public static string Montar(LicencaDados dados, ECDsa chavePrivada)
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(dados, Json);
        var assinatura = chavePrivada.SignData(bytes, HashAlgorithmName.SHA256);
        return Cabecalho + "\r\n" + Convert.ToBase64String(bytes) + "\r\n" + Convert.ToBase64String(assinatura) + "\r\n";
    }

    /// <summary>Confere a assinatura e devolve os dados; em erro, Dados = null e o motivo.</summary>
    public static (LicencaDados? Dados, string Motivo) Ler(string texto, string chavePublicaPem)
    {
        if (string.IsNullOrWhiteSpace(chavePublicaPem))
            return (null, "o programa não tem a chave pública de licença");
        var linhas = (texto ?? "").Split('\n', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        if (linhas.Length != 3 || linhas[0] != Cabecalho)
            return (null, "arquivo de licença em formato inválido");
        byte[] bytes, assinatura;
        try
        {
            bytes = Convert.FromBase64String(linhas[1]);
            assinatura = Convert.FromBase64String(linhas[2]);
        }
        catch (FormatException)
        {
            return (null, "arquivo de licença em formato inválido");
        }
        using var chave = ECDsa.Create();
        chave.ImportFromPem(chavePublicaPem);
        if (!chave.VerifyData(bytes, assinatura, HashAlgorithmName.SHA256))
            return (null, "assinatura da licença inválida (arquivo alterado ou de outro fornecedor)");
        try
        {
            var dados = JsonSerializer.Deserialize<LicencaDados>(bytes, Json);
            return dados is null ? (null, "licença sem dados") : (dados, "");
        }
        catch (JsonException)
        {
            return (null, "licença sem dados válidos");
        }
    }

    /// <summary>Código deste computador (MachineGuid do Windows), em maiúsculas.</summary>
    public static string CodigoDesteComputador()
    {
        if (!OperatingSystem.IsWindows()) return Environment.MachineName.ToUpperInvariant();
        using var chave = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Cryptography");
        return (chave?.GetValue("MachineGuid") as string ?? "").Trim().ToUpperInvariant();
    }

    public static string Texto(byte[] b) => Encoding.UTF8.GetString(b);
}
