// =============================================================================
//  SistemaCMJ.Api - Endpoints/AjudaGeralEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 22/11/2026 (etapa 03g)
//  Descrição : Ajuda exclusiva do administrador geral (pedido 3 de 16/11/2026;
//              PADRAO_TELAS regra 9). As páginas ficam na pasta AjudaGeral
//              (gerada por api/ferramentas/montar_ajuda.py a partir de
//              docs/ajuda_geral), embutida no executável e SEM endereço
//              direto: fora de wwwroot, só saem por aqui.
//                GET /api/ajuda-geral          índice (títulos, resumos, busca)
//                GET /api/ajuda-geral/{página} uma página
//              Antes de entregar, SIS_Ajuda_Geral_Obter confere a permissão
//              (SIS_AJUDA_GERAL / VER, só nível 2) e registra a consulta.
//              Recusa, nome inválido e página inexistente recebem a mesma
//              resposta ("Página não encontrada."), para não revelar o que existe.
//              Desenvolvimento com telas soltas: lê a pasta do projeto.
//              v1.1 (22/11/2026, 03g-B): partes dinâmicas. O marcador
//              <!-- dinamico: parametros --> vira a tabela de SIS_Parametro_Listar
//              e <!-- dinamico: comandos --> a de SIS_Comando_Listar, lidas na
//              hora (nunca desatualizam). Todo valor sai codificado (HtmlEncode).
// =============================================================================
using System.Text.Json;
using Microsoft.Data.SqlClient;
using System.Text.RegularExpressions;
using Microsoft.Extensions.FileProviders;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public static partial class AjudaGeralEndpoints
{
    private const string NaoEncontrada = "Página não encontrada.";
    private static IFileProvider arquivos = new NullFileProvider();

    [GeneratedRegex("^[a-z0-9-]{1,60}$")]
    private static partial Regex NomeValido();

    [GeneratedRegex(@"<title>(.*?)</title>", RegexOptions.Singleline)]
    private static partial Regex Titulo();

    [GeneratedRegex(@"<body>(.*)</body>", RegexOptions.Singleline)]
    private static partial Regex Corpo();

    public static void Mapear(WebApplication app, bool embutidas)
    {
        arquivos = embutidas
            ? new ManifestEmbeddedFileProvider(typeof(Program).Assembly, "AjudaGeral")
            : new PhysicalFileProvider(Path.Combine(app.Environment.ContentRootPath, "AjudaGeral"));
        app.MapGet("/api/ajuda-geral", Indice);
        app.MapGet("/api/ajuda-geral/{pagina}", Pagina);
    }

    private static async Task<bool> Liberada(HttpContext http, Banco banco, string pagina)
    {
        var usuario = http.Usuario();
        var linha = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Ajuda_Geral_Obter", new Dictionary<string, object?>
        {
            ["IdUsuario"] = usuario.IdUsuario,
            ["Pagina"] = Banco.Cortar(pagina, 60),
            ["Estacao"] = Banco.Cortar(usuario.Estacao, 100)
        }, usuario, http.RequestAborted);
        return linha.Bool("SUCESSO");
    }

    private static async Task<string?> Ler(string nome, CancellationToken ct)
    {
        var info = arquivos.GetFileInfo(nome);
        if (!info.Exists || info.IsDirectory) return null;
        await using var fluxo = info.CreateReadStream();
        using var leitor = new StreamReader(fluxo, System.Text.Encoding.UTF8);
        return await leitor.ReadToEndAsync(ct);
    }

    private static Task<IResult> Indice(HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            if (!await Liberada(http, banco, ""))
                return Resposta.Atencao(NaoEncontrada);
            var texto = await Ler("indice.json", http.RequestAborted);
            if (texto is null)
                return Resposta.Atencao("A ajuda do administrador geral não está neste programa. Gere de novo (montar_ajuda.py) e compile.");
            using var json = JsonDocument.Parse(texto);
            return Resposta.Ok(json.RootElement.Clone());
        });

    private static Task<IResult> Pagina(string pagina, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var nome = (pagina ?? "").Trim().ToLowerInvariant();
            if (!await Liberada(http, banco, nome) || !NomeValido().IsMatch(nome))
                return Resposta.Atencao(NaoEncontrada);
            var texto = await Ler(nome + ".html", http.RequestAborted);
            if (texto is null)
                return Resposta.Atencao(NaoEncontrada);
            var titulo = System.Net.WebUtility.HtmlDecode(Titulo().Match(texto).Groups[1].Value.Trim());
            var corpo = Corpo().Match(texto).Groups[1].Value.Trim();
            corpo = await Dinamicos(corpo, http, banco);
            http.Response.Headers.CacheControl = "no-store";
            return Resposta.Ok(new { pagina = nome, titulo, html = corpo });
        });

    private static string H(string? texto) => System.Net.WebUtility.HtmlEncode(texto ?? "");

    private static string Tabela(IEnumerable<string> cabecalho, IEnumerable<IEnumerable<string>> linhas)
    {
        var sb = new System.Text.StringBuilder("<table><thead><tr>");
        foreach (var c in cabecalho) sb.Append("<th>").Append(H(c)).Append("</th>");
        sb.Append("</tr></thead><tbody>");
        var n = 0;
        foreach (var l in linhas)
        {
            n++;
            sb.Append("<tr>");
            foreach (var v in l) sb.Append("<td>").Append(v).Append("</td>");   // v já vem codificado
            sb.Append("</tr>");
        }
        sb.Append("</tbody></table>");
        return n == 0 ? "<p><em>Nenhum registro.</em></p>" : sb.ToString();
    }

    private static async Task<string> Dinamicos(string corpo, HttpContext http, Banco banco)
    {
        var usuario = http.Usuario();
        var parametros = new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario };

        if (corpo.Contains("<!-- dinamico: parametros -->"))
        {
            string html;
            try
            {
                var linhas = await banco.ExecutarAsync("SIS.SIS_Parametro_Listar", parametros, usuario, http.RequestAborted);
                html = Tabela(["Módulo", "Chave", "Valor atual", "Padrão", "Descrição", "Admin altera?"],
                    linhas.Select(l => new[]
                    {
                        H(l.Texto("MODULO_NOME")),
                        "<code>" + H(l.Texto("CHAVE")) + "</code>",
                        l.Texto("VALOR") == l.Texto("VALOR_PADRAO") ? H(l.Texto("VALOR")) : "<strong>" + H(l.Texto("VALOR")) + "</strong>",
                        H(l.Texto("VALOR_PADRAO")),
                        H(l.Texto("DESCRICAO")),
                        l.Bool("EDITAVEL_ADMIN") ? "sim" : "não"
                    }));
                html = "<p>" + linhas.Count + " parâmetros. Valor em <strong>negrito</strong> = diferente do padrão.</p>" + html;
            }
            catch (SqlException erro) when (erro.Number == 50001) { html = "<p><em>" + H(erro.Message) + "</em></p>"; }
            corpo = corpo.Replace("<!-- dinamico: parametros -->", html);
        }

        if (corpo.Contains("<!-- dinamico: comandos -->"))
        {
            string html;
            try
            {
                var linhas = await banco.ExecutarAsync("SIS.SIS_Comando_Listar", parametros, usuario, http.RequestAborted);
                html = Tabela(["Grupo", "Código", "Botão", "O que faz", "Cuidado"],
                    linhas.Select(l => new[]
                    {
                        H(l.Texto("GRUPO_NOME")),
                        "<code>" + H(l.Texto("CODIGO")) + "</code>",
                        H(l.Texto("NOME")),
                        H(l.Texto("DESCRICAO")) + (l.Bool("ACEITA_PARAMETRO") && l.Texto("PARAMETRO_DESCRICAO").Length > 0 ? " <em>Pede: " + H(l.Texto("PARAMETRO_DESCRICAO")) + "</em>" : ""),
                        l.Bool("PERIGOSO") ? "⚠️ pede a senha de novo e confirmação" : ""
                    }));
            }
            catch (SqlException erro) when (erro.Number == 50001) { html = "<p><em>" + H(erro.Message) + "</em></p>"; }
            corpo = corpo.Replace("<!-- dinamico: comandos -->", html);
        }
        return corpo;
    }
}
