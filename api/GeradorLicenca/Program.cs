// =============================================================================
//  SisCMJ - Gerador de licença (api\GeradorLicenca)
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 20/11/2026 (fase 3d)
//  Descrição : Só no computador do Celso. Uso: api\gerar_licenca.cmd.
//                1) criar o par de chaves (uma vez): a PRIVADA vai para um
//                   arquivo cifrado com a senha dele (AES-256, PBKDF2 600 mil
//                   iterações): esse arquivo é a cópia de trabalho E a de
//                   segurança (pode ir para o Google Drive; sem a senha não
//                   serve para nada). A PÚBLICA é gravada em
//                   api\SistemaCMJ.Api\Infra\LicencaChavePublica.cs.
//                2) gerar licença: razão social, CNPJ, código do servidor,
//                   módulos; sem validade (decisão de 20/11/2026);
//                3) código deste computador;
//                4) conferir um arquivo de licença.
//              Se a chave privada (ou a senha) se perder, não dá para gerar
//              licença nova: seria preciso criar outro par e reinstalar o
//              programa em todos os clientes.
// =============================================================================
using System.Security.Cryptography;
using System.Text;
using SistemaCMJ.Api.Infra;

Console.OutputEncoding = Encoding.UTF8;
var raizProjeto = args.Length > 0 ? Path.GetFullPath(args[0]) : Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".."));
var pastaChave = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "SisCMJ_Chave");
var arquivoChave = Path.Combine(pastaChave, "chave_privada_siscmj.pem");
var arquivoPublicaCs = Path.Combine(raizProjeto, "api", "SistemaCMJ.Api", "Infra", "LicencaChavePublica.cs");
var licencaDev = Path.Combine(raizProjeto, "api", "licenca", "licenca.lic");
string[] todosModulos = ["SIS", "CAD", "BANCO", "FIN", "IMOB", "VENDA", "COBR", "COMP", "OBRA", "GER"];

while (true)
{
    Console.WriteLine();
    Console.WriteLine("=== SisCMJ - Gerador de licença ===");
    Console.WriteLine("Chave privada: " + arquivoChave + (File.Exists(arquivoChave) ? "" : "  (ainda não criada)"));
    Console.WriteLine(" 1) Criar o par de chaves (só uma vez)");
    Console.WriteLine(" 2) Gerar uma licença");
    Console.WriteLine(" 3) Código deste computador");
    Console.WriteLine(" 4) Conferir um arquivo de licença");
    Console.WriteLine(" 0) Sair");
    Console.Write("Opção: ");
    var opcao = (Console.ReadLine() ?? "").Trim();
    try
    {
        switch (opcao)
        {
            case "1": CriarChaves(); break;
            case "2": GerarLicenca(); break;
            case "3": Console.WriteLine("Código deste computador: " + LicencaFormato.CodigoDesteComputador()); break;
            case "4": Conferir(); break;
            case "0": return 0;
            default: Console.WriteLine("Opção inválida."); break;
        }
    }
    catch (CryptographicException)
    {
        Console.WriteLine("ERRO: senha errada ou arquivo da chave danificado.");
    }
    catch (Exception erro)
    {
        Console.WriteLine("ERRO: " + erro.Message);
    }
}

void CriarChaves()
{
    if (File.Exists(arquivoChave))
    {
        Console.WriteLine("Já existe uma chave privada. Criar outra invalidaria todas as licenças já emitidas: não faço.");
        return;
    }
    Console.WriteLine("A senha protege a chave privada. Mínimo 12 caracteres, com letras e números. Guarde-a FORA do Google Drive.");
    var senha = LerSenha("Senha: ");
    if (senha.Length < 12 || !senha.Any(char.IsLetter) || !senha.Any(char.IsDigit)) { Console.WriteLine("Senha fraca: mínimo 12 caracteres, com letras e números."); return; }
    if (LerSenha("Repita a senha: ") != senha) { Console.WriteLine("As senhas não são iguais."); return; }

    using var chave = ECDsa.Create(ECCurve.NamedCurves.nistP256);
    var pem = chave.ExportEncryptedPkcs8PrivateKeyPem(senha.AsSpan(),
        new PbeParameters(PbeEncryptionAlgorithm.Aes256Cbc, HashAlgorithmName.SHA256, 600_000));
    Directory.CreateDirectory(pastaChave);
    File.WriteAllText(arquivoChave, pem);

    var publica = chave.ExportSubjectPublicKeyInfoPem().Replace("\r", "").Trim();
    var cs = "// =============================================================================\r\n" +
             "//  SistemaCMJ.Api - Infra/LicencaChavePublica.cs\r\n" +
             "//  GERADO pelo gerador de licença (api\\gerar_licenca.cmd, opção 1) em " + DateTime.Now.ToString("dd/MM/yyyy HH:mm") + ".\r\n" +
             "//  NÃO EDITAR À MÃO. A chave pública não é segredo; a privada nunca entra no projeto.\r\n" +
             "// =============================================================================\r\n" +
             "namespace SistemaCMJ.Api.Infra;\r\n\r\npublic static class LicencaChavePublica\r\n{\r\n" +
             "    public const string Pem = \"" + publica.Replace("\n", "\\n") + "\";\r\n}\r\n";
    File.WriteAllText(arquivoPublicaCs, cs, new UTF8Encoding(true));
    Console.WriteLine();
    Console.WriteLine("Par de chaves criado.");
    Console.WriteLine(" - Chave privada (cifrada com a sua senha): " + arquivoChave);
    Console.WriteLine("   COPIE este arquivo para o Google Drive. Sem ele e sem a senha não dá para gerar licença.");
    Console.WriteLine(" - Chave pública gravada no programa: " + arquivoPublicaCs);
    Console.WriteLine("   Avise o Claude: o programa precisa ser compilado de novo.");
}

void GerarLicenca()
{
    if (!File.Exists(arquivoChave)) { Console.WriteLine("Crie o par de chaves primeiro (opção 1)."); return; }
    var senha = LerSenha("Senha da chave privada: ");
    using var chave = ECDsa.Create();
    chave.ImportFromEncryptedPem(File.ReadAllText(arquivoChave), senha.AsSpan());

    var razao = Perguntar("Razão social: ");
    if (razao.Length == 0) { Console.WriteLine("Razão social obrigatória."); return; }
    var cnpj = new string(Perguntar("CNPJ: ").Where(char.IsDigit).ToArray());
    if (!CnpjValido(cnpj)) { Console.WriteLine("CNPJ inválido."); return; }
    var fantasia = Perguntar("Nome fantasia (Enter = nenhum): ");
    var meu = LicencaFormato.CodigoDesteComputador();
    var servidor = Perguntar("Código do servidor (Enter = este computador " + meu + "): ").ToUpperInvariant();
    if (servidor.Length == 0) servidor = meu;
    var mods = Perguntar("Módulos separados por vírgula (Enter = todos: " + string.Join(",", todosModulos) + "): ").ToUpperInvariant();
    var modulos = mods.Length == 0 ? todosModulos : mods.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
    if (!modulos.Contains("SIS")) modulos = ["SIS", .. modulos];
    var desconhecidos = modulos.Where(m => !todosModulos.Contains(m)).ToArray();
    if (desconhecidos.Length > 0) Console.WriteLine("Aviso: módulos não conhecidos por este gerador: " + string.Join(",", desconhecidos) + " (ficam guardados na licença).");
    var observacao = Perguntar("Observação (Enter = nenhuma): ");

    var dados = new LicencaDados(1, razao, cnpj, fantasia, servidor, modulos, DateTime.Today.ToString("yyyy-MM-dd"), null, observacao);
    var texto = LicencaFormato.Montar(dados, chave);
    var (conferido, motivo) = LicencaFormato.Ler(texto, chave.ExportSubjectPublicKeyInfoPem());
    if (conferido is null) { Console.WriteLine("ERRO na conferência: " + motivo); return; }

    var pasta = Path.Combine(pastaChave, "licencas");
    Directory.CreateDirectory(pasta);
    var arquivo = Path.Combine(pasta, cnpj + "_" + servidor[..Math.Min(8, servidor.Length)] + "_" + DateTime.Now.ToString("yyyyMMdd_HHmm") + ".lic");
    File.WriteAllText(arquivo, texto);
    Console.WriteLine();
    Console.WriteLine("Licença gerada: " + arquivo);
    Console.WriteLine("No servidor, copie como: C:\\ProgramData\\SisCMJ\\licenca.lic (o sistema pega sozinho em até 1 minuto).");
    if (servidor == meu && Perguntar("Instalar também neste notebook (api\\licenca\\licenca.lic, desenvolvimento)? (S/N): ").Equals("S", StringComparison.OrdinalIgnoreCase))
    {
        Directory.CreateDirectory(Path.GetDirectoryName(licencaDev)!);
        File.WriteAllText(licencaDev, texto);
        Console.WriteLine("Instalada em " + licencaDev);
    }
}

void Conferir()
{
    var arquivo = Perguntar("Arquivo de licença: ").Trim('"');
    if (!File.Exists(arquivo)) { Console.WriteLine("Arquivo não encontrado."); return; }
    if (!File.Exists(arquivoChave)) { Console.WriteLine("Sem a chave (opção 1) não dá para conferir a assinatura."); return; }
    var senha = LerSenha("Senha da chave privada: ");
    using var chave = ECDsa.Create();
    chave.ImportFromEncryptedPem(File.ReadAllText(arquivoChave), senha.AsSpan());
    var (d, motivo) = LicencaFormato.Ler(File.ReadAllText(arquivo), chave.ExportSubjectPublicKeyInfoPem());
    if (d is null) { Console.WriteLine("INVÁLIDA: " + motivo); return; }
    Console.WriteLine("VÁLIDA: " + d.RazaoSocial + " (" + d.Cnpj + "), servidor " + d.Servidor + ", módulos " + string.Join(",", d.Modulos) + ", emitida em " + d.Emissao + (d.Validade is null ? ", sem validade" : ", válida até " + d.Validade));
}

static string Perguntar(string texto) { Console.Write(texto); return (Console.ReadLine() ?? "").Trim(); }

static string LerSenha(string texto)
{
    Console.Write(texto);
    var sb = new StringBuilder();
    while (true)
    {
        var k = Console.ReadKey(intercept: true);
        if (k.Key == ConsoleKey.Enter) break;
        if (k.Key == ConsoleKey.Backspace) { if (sb.Length > 0) { sb.Length--; Console.Write("\b \b"); } continue; }
        if (!char.IsControl(k.KeyChar)) { sb.Append(k.KeyChar); Console.Write('*'); }
    }
    Console.WriteLine();
    return sb.ToString();
}

static bool CnpjValido(string c)
{
    if (c.Length != 14 || c.Distinct().Count() == 1) return false;
    int Dv(string s, int[] pesos) { var soma = 0; for (var i = 0; i < pesos.Length; i++) soma += (s[i] - '0') * pesos[i]; var r = soma % 11; return r < 2 ? 0 : 11 - r; }
    var d1 = Dv(c, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
    var d2 = Dv(c, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
    return c[12] - '0' == d1 && c[13] - '0' == d2;
}
