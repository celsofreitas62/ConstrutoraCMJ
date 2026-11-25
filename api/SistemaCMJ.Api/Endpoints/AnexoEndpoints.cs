// =============================================================================
//  SistemaCMJ.Api - Endpoints/AnexoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (etapa 04d2, passo 5)
//  Descrição : Anexos genéricos de qualquer tela (aba "Anexos"; componente
//              js/anexos.js). Permissão e validação ficam nas procedures
//              SIS_Anexo_Tipo_Listar/_Listar/_Gravar/_Obter/_Excluir; a API só
//              guarda o arquivo em ANEXO_PASTA_RAIZ\ano\mês com nome gerado
//              (GUID + extensão) e o SHA-256. Se o banco recusar, o arquivo
//              recém-gravado é apagado. Baixar confere o hash antes de entregar.
// =============================================================================
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record AnexoExcluirPedido(string? Item, string? Motivo);

public static partial class AnexoEndpoints
{
    [GeneratedRegex("^[a-z0-9]{1,10}$")]
    private static partial Regex ExtensaoValida();

    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/sis/anexos/tipos", Tipos);
        app.MapGet("/api/sis/anexos", Listar);
        app.MapPost("/api/sis/anexos", Gravar);
        app.MapGet("/api/sis/anexos/{id:long}/arquivo", Baixar);
        app.MapPost("/api/sis/anexos/{id:long}/excluir", Excluir);
    }

    private static Task<IResult> Tipos(string? item, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Anexo_Tipo_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Item"] = Banco.Cortar(item?.Trim(), 40)
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Listar(string? item, string? tabela, long? idRegistro, bool? incluirExcluidos, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Anexo_Listar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Item"] = Banco.Cortar(item?.Trim(), 40),
                ["Tabela"] = Banco.Cortar(tabela?.Trim(), 256),
                ["IdRegistro"] = idRegistro ?? 0,
                ["IncluirExcluidos"] = incluirExcluidos == true
            }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });

    private static Task<IResult> Gravar(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            if (!http.Request.HasFormContentType)
                return Resposta.Atencao("Escolha o arquivo para anexar.");
            var form = await http.Request.ReadFormAsync(http.RequestAborted);
            var arquivo = form.Files.GetFile("arquivo");
            if (arquivo is null || arquivo.Length == 0)
                return Resposta.Atencao("Escolha o arquivo para anexar.");

            var maxMb = await banco.ParametroInteiroAsync("ANEXO_TAMANHO_MAX_MB", http.RequestAborted);
            if (arquivo.Length > (long)maxMb * 1048576)
                return Resposta.Atencao("O arquivo precisa ter até " + maxMb + " MB.");

            var nomeOriginal = Path.GetFileName(arquivo.FileName ?? "").Trim();
            var extensao = Path.GetExtension(nomeOriginal).TrimStart('.').ToLowerInvariant();
            if (nomeOriginal.Length == 0 || !ExtensaoValida().IsMatch(extensao))
                return Resposta.Atencao("O arquivo precisa ter um nome com extensão (ex.: contrato.pdf).");

            DateOnly? validade = null;
            var textoValidade = form["dtValidade"].ToString().Trim();
            if (textoValidade.Length > 0)
            {
                if (!DateOnly.TryParseExact(textoValidade, "yyyy-MM-dd", out var data))
                    return Resposta.Atencao("Validade inválida.");
                validade = data;
            }
            if (!long.TryParse(form["idRegistro"], out var idRegistro) || idRegistro <= 0)
                return Resposta.Atencao("Grave o registro antes de anexar arquivos.");

            var raiz = (await banco.ParametroAsync("ANEXO_PASTA_RAIZ", http.RequestAborted)).Trim();
            if (raiz.Length == 0)
                return Resposta.Atencao("A pasta dos anexos não está configurada (parâmetro ANEXO_PASTA_RAIZ).");
            var agora = DateTime.Now;
            var pastaRelativa = agora.ToString("yyyy") + "\\" + agora.ToString("MM");
            var nomeArquivo = Guid.NewGuid().ToString("N") + "." + extensao;
            var pasta = Path.Combine(raiz, agora.ToString("yyyy"), agora.ToString("MM"));
            Directory.CreateDirectory(pasta);
            var caminho = Path.Combine(pasta, nomeArquivo);

            byte[] hash;
            try
            {
                await using (var destino = new FileStream(caminho, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                await using (var origem = arquivo.OpenReadStream())
                {
                    using var calculo = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                    var buffer = new byte[81920];
                    int lidos;
                    while ((lidos = await origem.ReadAsync(buffer, http.RequestAborted)) > 0)
                    {
                        calculo.AppendData(buffer, 0, lidos);
                        await destino.WriteAsync(buffer.AsMemory(0, lidos), http.RequestAborted);
                    }
                    hash = calculo.GetHashAndReset();
                }

                var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Anexo_Gravar", new Dictionary<string, object?>
                {
                    ["IdUsuario"] = usuario.IdUsuario,
                    ["Item"] = Banco.Cortar(form["item"].ToString().Trim(), 40),
                    ["Tabela"] = Banco.Cortar(form["tabela"].ToString().Trim(), 256),
                    ["IdRegistro"] = idRegistro,
                    ["CodigoTipo"] = Banco.Cortar(form["codigoTipo"].ToString().Trim().ToUpperInvariant(), 30),
                    ["NomeOriginal"] = Banco.Cortar(nomeOriginal, 260),
                    ["NomeArquivo"] = nomeArquivo,
                    ["PastaRelativa"] = pastaRelativa,
                    ["TamanhoBytes"] = arquivo.Length,
                    ["HashSha256"] = hash,
                    ["Descricao"] = Banco.Cortar(form["descricao"].ToString().Trim(), 400),
                    ["DtValidade"] = validade
                }, usuario, http.RequestAborted);
                if (!resultado.Bool("SUCESSO")) ApagarSemErro(caminho);
                return Resposta.DeGravacao(resultado);
            }
            catch
            {
                ApagarSemErro(caminho);
                throw;
            }
        });

    private static Task<IResult> Baixar(long id, string? item, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Anexo_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Item"] = Banco.Cortar(item?.Trim(), 40),
                ["IdAnexo"] = id
            }, usuario, http.RequestAborted);
            if (linhas.Count == 0) return Resposta.Atencao("Anexo não encontrado.");
            var a = linhas[0];
            var caminho = a.Texto("CAMINHO_COMPLETO");
            if (!File.Exists(caminho))
                return Resposta.Atencao("O arquivo deste anexo não foi encontrado no servidor. Avise o administrador do sistema.");
            await using (var leitura = File.OpenRead(caminho))
            {
                var hash = await SHA256.HashDataAsync(leitura, http.RequestAborted);
                var esperado = a.Bytes("HASH_SHA256");
                if (esperado is null || !hash.AsSpan().SequenceEqual(esperado))
                    return Resposta.Atencao("O arquivo deste anexo foi alterado no servidor e não será entregue. Avise o administrador do sistema.");
            }
            var tipo = a.Texto("EXTENSAO").ToLowerInvariant() switch
            {
                "pdf" => "application/pdf",
                "png" => "image/png",
                "jpg" or "jpeg" => "image/jpeg",
                "svg" => "image/svg+xml",
                "txt" => "text/plain",
                "xml" => "application/xml",
                _ => "application/octet-stream"
            };
            http.Response.Headers["X-Content-Type-Options"] = "nosniff";
            return Results.File(caminho, tipo, a.Texto("NOME_ORIGINAL"));
        });

    private static Task<IResult> Excluir(long id, AnexoExcluirPedido p, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var resultado = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Anexo_Excluir", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Item"] = Banco.Cortar(p.Item?.Trim(), 40),
                ["IdAnexo"] = id,
                ["Motivo"] = Banco.Cortar(p.Motivo?.Trim(), 400)
            }, usuario, http.RequestAborted);
            return Resposta.DeGravacao(resultado);
        });

    private static void ApagarSemErro(string caminho)
    {
        try { if (File.Exists(caminho)) File.Delete(caminho); } catch { /* sobra um arquivo órfão; não atrapalha */ }
    }
}
