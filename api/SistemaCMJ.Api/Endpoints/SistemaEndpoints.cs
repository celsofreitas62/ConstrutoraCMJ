// =============================================================================
//  SistemaCMJ.Api - Endpoints/SistemaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Menu do usuário, identidade visual (cores e logomarcas dos
//              parâmetros) e listas de apoio usadas por várias telas.
//              22/11/2026 (03g): o menu esconde as telas ainda não construídas.
// =============================================================================
using System.Text.RegularExpressions;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public static partial class SistemaEndpoints
{
    // Logomarcas que a tela pode pedir -> parâmetro com o nome do arquivo.
    private static readonly Dictionary<string, string> Logos = new(StringComparer.OrdinalIgnoreCase)
    {
        ["horizontal"] = "EMPRESA_LOGO_HORIZONTAL",
        ["simbolo"] = "EMPRESA_LOGO_SIMBOLO",
        ["vertical"] = "EMPRESA_LOGO"
    };

    private static readonly Dictionary<string, string> TiposImagem = new(StringComparer.OrdinalIgnoreCase)
    {
        [".png"] = "image/png",
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".svg"] = "image/svg+xml",
        [".webp"] = "image/webp"
    };

    [GeneratedRegex("^#[0-9A-Fa-f]{6}$")]
    private static partial Regex CorValida();

    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/identidade", Identidade);
        app.MapGet("/api/identidade/logo/{tipo}", Logo);
        app.MapGet("/api/menu", Menu);
        app.MapGet("/api/banco/bancos", Bancos);
    }

    private static Task<IResult> Identidade(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var principal = await banco.ParametroAsync("EMPRESA_COR_PRINCIPAL", http.RequestAborted);
            var secundaria = await banco.ParametroAsync("EMPRESA_COR_SECUNDARIA", http.RequestAborted);
            var nomeSistema = await banco.ParametroAsync("SISTEMA_NOME", http.RequestAborted);
            return Resposta.Ok(new
            {
                corPrincipal = CorValida().IsMatch(principal) ? principal : "#D43414",
                corSecundaria = CorValida().IsMatch(secundaria) ? secundaria : "#A8A8A8",
                nomeSistema = nomeSistema.Length > 0 ? nomeSistema : "SistemaCMJ"
            });
        });

    private static async Task<IResult> Logo(string tipo, HttpContext http, Banco banco, IConfiguration configuracao, ILogger<Program> logger)
    {
        if (!Logos.TryGetValue(tipo, out var chave))
            return Results.NotFound();
        try
        {
            var arquivo = await banco.ParametroAsync(chave, http.RequestAborted);
            if (arquivo.Length == 0 || Path.GetFileName(arquivo) != arquivo
                || !TiposImagem.TryGetValue(Path.GetExtension(arquivo), out var tipoConteudo))
                return Results.NotFound();

            var pastas = new[]
            {
                await banco.ParametroAsync("IDENTIDADE_PASTA", http.RequestAborted),
                configuracao["Identidade:PastaReserva"] ?? ""
            };
            foreach (var pasta in pastas.Where(p => p.Length > 0))
            {
                var caminho = Path.Combine(pasta, arquivo);
                if (File.Exists(caminho))
                {
                    http.Response.Headers.CacheControl = "private, max-age=3600";
                    return Results.File(caminho, tipoConteudo);
                }
            }
            return Results.NotFound();
        }
        catch (Exception erro)
        {
            logger.LogError(erro, "Falha ao ler a logomarca {Tipo}", tipo);
            await banco.RegistrarErroAsync("API GET /api/identidade/logo", "Ler logomarca", erro);
            return Results.NotFound();
        }
    }

    private static Task<IResult> Menu(HttpContext http, Banco banco, IWebHostEnvironment ambiente, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("SIS.SIS_Menu_Listar",
                new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario }, usuario, http.RequestAborted);
            // 04d2 (25/11/2026): a tela de Pessoas aparece com o rótulo do parâmetro (ex.: "Parceiros").
            var rotulo = (await banco.ParametroAsync("PARCEIRO_ROTULO_PLURAL", http.RequestAborted)).Trim();
            if (rotulo.Length > 0)
                foreach (var l in linhas.Where(l => l.Texto("CODIGO") == "CAD_PESSOA"))
                    l["NOME"] = rotulo;
            return Resposta.Ok(SoTelasProntas(linhas, ambiente));
        });

    /// <summary>
    /// Tira do menu as telas cujo arquivo ainda não existe neste programa (cadastradas
    /// no banco antes de serem construídas) e os menus e módulos que ficarem vazios. A tela
    /// aparece sozinha quando for construída. Aprovado pelo Celso em 22/11/2026 (03g).
    /// O que vem depois de "?" no caminho (ex.: fin/lancamentos.html?tipo=P) não conta (04f2a).
    /// </summary>
    private static List<Linha> SoTelasProntas(List<Linha> linhas, IWebHostEnvironment ambiente)
    {
        var prontas = linhas.Where(l => l.Texto("TIPO") != "TELA"
            || (l.Texto("CAMINHO").Length > 0 && ambiente.WebRootFileProvider.GetFileInfo(l.Texto("CAMINHO").Split('?')[0].TrimStart('/')).Exists)).ToList();
        while (true)
        {
            var pais = prontas.Select(l => l.Texto("CHAVE_PAI")).Where(c => c.Length > 0).ToHashSet();
            var vazios = prontas.Where(l => l.Texto("TIPO") is "MENU" or "MODULO" && !pais.Contains(l.Texto("CHAVE"))).ToList();
            if (vazios.Count == 0) return prontas;
            prontas = prontas.Except(vazios).ToList();
        }
    }

    private static Task<IResult> Bancos(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var linhas = await banco.ExecutarAsync("BANCO.BANCO_Banco_Listar",
                new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario, ["SomenteAtivos"] = true }, usuario, http.RequestAborted);
            return Resposta.Ok(linhas);
        });
}
