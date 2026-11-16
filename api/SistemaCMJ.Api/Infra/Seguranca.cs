// =============================================================================
//  SistemaCMJ.Api - Infra/Seguranca.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Senha (PBKDF2-SHA256) e token de sessão.
//              - O banco NUNCA recebe a senha: só hash (32 bytes), salt
//                (16 bytes) e iterações (SIS.Usuario).
//              - O token da sessão (32 bytes aleatórios) vai só no cookie;
//                o banco guarda o SHA-256 dele (SIS.Sessao).
// =============================================================================
using System.Security.Cryptography;
using System.Text;

namespace SistemaCMJ.Api.Infra;

public static class Seguranca
{
    public const string Algoritmo = "PBKDF2-SHA256";
    public const string NomeCookie = "cmj_sessao";
    public const int IteracoesMinimas = 100_000;

    // Valores fixos só para "gastar o mesmo tempo" quando o login não existe.
    private static readonly byte[] SaltFalso = RandomNumberGenerator.GetBytes(16);

    public static byte[] CalcularHash(string senha, byte[] salt, int iteracoes) =>
        Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(senha), salt, iteracoes, HashAlgorithmName.SHA256, 32);

    public static bool SenhaConfere(string senha, byte[] salt, int iteracoes, byte[] hashGravado) =>
        CryptographicOperations.FixedTimeEquals(CalcularHash(senha, salt, iteracoes), hashGravado);

    /// <summary>Faz o mesmo trabalho de uma conferência real, para o tempo de
    /// resposta não revelar se o login existe.</summary>
    public static void SimularConferencia(string senha, int iteracoes) =>
        _ = CalcularHash(senha, SaltFalso, Math.Max(iteracoes, IteracoesMinimas));

    public static (byte[] Hash, byte[] Salt) NovaSenha(string senha, int iteracoes)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        return (CalcularHash(senha, salt, iteracoes), salt);
    }

    /// <summary>Regras da senha nova. Devolve a recusa ou "" quando está boa.</summary>
    public static string ConferirRegras(string senha, int tamanhoMinimo)
    {
        tamanhoMinimo = Math.Max(tamanhoMinimo, 8);
        if (senha.Length < tamanhoMinimo)
            return $"A senha precisa ter pelo menos {tamanhoMinimo} caracteres.";
        if (senha.Length > 128)
            return "A senha pode ter no máximo 128 caracteres.";
        if (!senha.Any(char.IsLetter) || !senha.Any(char.IsDigit))
            return "A senha precisa ter letras e números.";
        return "";
    }

    public static (string Token, byte[] TokenHash) NovoToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(32);
        return (Base64UrlEncode(bytes), SHA256.HashData(bytes));
    }

    /// <summary>SHA-256 do token do cookie; null se o cookie não tem formato válido.</summary>
    public static byte[]? HashDoToken(string? token)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Length > 100)
            return null;
        try
        {
            var bytes = Base64UrlDecode(token);
            return bytes.Length == 32 ? SHA256.HashData(bytes) : null;
        }
        catch (FormatException)
        {
            return null;
        }
    }

    private static string Base64UrlEncode(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] Base64UrlDecode(string texto)
    {
        var b64 = texto.Replace('-', '+').Replace('_', '/');
        b64 = b64.PadRight(b64.Length + (4 - b64.Length % 4) % 4, '=');
        return Convert.FromBase64String(b64);
    }
}
