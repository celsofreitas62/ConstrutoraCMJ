// =============================================================================
//  SistemaCMJ.Api - Endpoints/ConsultaEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 25/11/2026 (fase 4, conversa 04d)
//  Descrição : Consultas públicas na internet para preencher cadastros (P12):
//                GET /api/cad/consulta/cep/{cep}    endereço pelo CEP
//                GET /api/cad/consulta/cnpj/{cnpj}  razão social, fantasia,
//                                                   endereço e situação na Receita
//              A consulta é feita pelo SERVIDOR (o navegador não sai para a
//              internet). Endereços, liga/desliga e tempo-limite vêm dos
//              parâmetros (CAD.CAD_Consulta_Config_Obter); CEP consultado fica
//              guardado em CAD.Cep_Cache. Qualquer falha devolve um aviso e a
//              tela deixa digitar à mão (nada trava). Só dados públicos saem do
//              servidor (o número do CEP/CNPJ); nada é registrado em log além
//              do erro técnico.
// =============================================================================
using System.Text.Json;
using System.Text.RegularExpressions;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public static class ConsultaEndpoints
{
    private static readonly HttpClient Cliente = CriarCliente();

    private static HttpClient CriarCliente()
    {
        var c = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
        c.DefaultRequestHeaders.UserAgent.ParseAdd("SisCMJ/1.0");
        c.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        return c;
    }

    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/cad/consulta/cep/{cep}", Cep);
        app.MapGet("/api/cad/consulta/cnpj/{cnpj}", Cnpj);
    }

    private static Task<IResult> Cep(string cep, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var digitos = Regex.Replace(cep ?? "", "[^0-9]", "");
            if (digitos.Length != 8) return Resposta.Atencao("CEP inválido: são 8 dígitos.");

            var cfg = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Consulta_Config_Obter", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario,
                ["Cep"] = digitos
            }, usuario, http.RequestAborted);
            if (!cfg.Bool("PODE")) return Resposta.Atencao("Você não tem permissão para preencher cadastros.");
            if (cfg.Bool("CEP_EM_CACHE"))
                return Resposta.Ok(Endereco(cfg.Texto("LOGRADOURO"), cfg.Texto("COMPLEMENTO"), cfg.Texto("BAIRRO"),
                                            cfg.Texto("CIDADE"), cfg.Texto("UF"), cfg.Texto("CODIGO_IBGE"), "cache"));
            if (!cfg.Bool("CEP_ATIVA")) return Resposta.Atencao("A consulta de CEP está desligada: preencha o endereço à mão.");

            var limite = TempoLimite(cfg);
            Dictionary<string, string>? achado = null;
            string fonte = "";
            foreach (var (url, formato) in new[] { (cfg.Texto("CEP_URL_PRINCIPAL"), "VIACEP"), (cfg.Texto("CEP_URL_RESERVA"), "BRASILAPI") })
            {
                if (string.IsNullOrWhiteSpace(url)) continue;
                var json = await Buscar(url.Replace("{cep}", digitos), limite, logger, http.RequestAborted);
                if (json is null) continue;
                achado = formato == "VIACEP" ? LerViaCep(json.Value) : LerBrasilApiCep(json.Value);
                if (achado is not null) { fonte = formato; break; }
            }
            if (achado is null)
                return Resposta.Atencao("CEP não encontrado ou consulta indisponível agora. Confira o número ou preencha o endereço à mão.");

            await banco.ExecutarAsync("CAD.CAD_Cep_Cache_Gravar", new Dictionary<string, object?>
            {
                ["IdUsuario"] = usuario.IdUsuario, ["Cep"] = digitos,
                ["Logradouro"] = achado["logradouro"], ["Complemento"] = achado["complemento"], ["Bairro"] = achado["bairro"],
                ["Cidade"] = achado["cidade"], ["Uf"] = achado["uf"], ["CodigoIbge"] = achado["ibge"], ["Fonte"] = fonte
            }, usuario, http.RequestAborted);

            return Resposta.Ok(Endereco(achado["logradouro"], achado["complemento"], achado["bairro"], achado["cidade"], achado["uf"], achado["ibge"], fonte));
        });

    private static Task<IResult> Cnpj(string cnpj, HttpContext http, Banco banco, ILogger<Program> logger) =>
        Resposta.Rodar(http, banco, logger, async () =>
        {
            var usuario = http.Usuario();
            var doc = Regex.Replace((cnpj ?? "").ToUpperInvariant(), "[^0-9A-Z]", "");
            if (doc.Length != 14) return Resposta.Atencao("CNPJ inválido: são 14 caracteres.");

            var cfg = await banco.ExecutarUmaLinhaAsync("CAD.CAD_Consulta_Config_Obter",
                new Dictionary<string, object?> { ["IdUsuario"] = usuario.IdUsuario }, usuario, http.RequestAborted);
            if (!cfg.Bool("PODE")) return Resposta.Atencao("Você não tem permissão para preencher cadastros.");
            if (!cfg.Bool("CNPJ_ATIVA")) return Resposta.Atencao("A consulta de CNPJ está desligada: preencha os dados à mão.");
            var url = cfg.Texto("CNPJ_URL");
            if (string.IsNullOrWhiteSpace(url)) return Resposta.Atencao("A consulta de CNPJ não está configurada.");

            var json = await Buscar(url.Replace("{cnpj}", doc), TempoLimite(cfg), logger, http.RequestAborted);
            if (json is null || json.Value.ValueKind != JsonValueKind.Object || string.IsNullOrWhiteSpace(Campo(json.Value, "razao_social")))
                return Resposta.Atencao("CNPJ não encontrado na Receita ou consulta indisponível agora. Preencha os dados à mão.");

            var j = json.Value;
            var tipoLogr = Campo(j, "descricao_tipo_de_logradouro");
            var logr = Campo(j, "logradouro");
            if (tipoLogr != "" && !logr.StartsWith(tipoLogr, StringComparison.OrdinalIgnoreCase)) logr = tipoLogr + " " + logr;
            var situacao = Campo(j, "descricao_situacao_cadastral");
            return Resposta.Ok(new
            {
                razaoSocial = Campo(j, "razao_social"),
                nomeFantasia = Campo(j, "nome_fantasia"),
                situacao,
                situacaoAtiva = situacao.Equals("ATIVA", StringComparison.OrdinalIgnoreCase),
                cep = Regex.Replace(Campo(j, "cep"), "[^0-9]", ""),
                logradouro = Titulo(logr),
                numero = Campo(j, "numero"),
                complemento = Titulo(Campo(j, "complemento")),
                bairro = Titulo(Campo(j, "bairro")),
                cidade = Titulo(Campo(j, "municipio")),
                uf = Campo(j, "uf").ToUpperInvariant(),
                telefone = Regex.Replace(Campo(j, "ddd_telefone_1"), "[^0-9]", ""),
                email = Campo(j, "email").ToLowerInvariant(),
                fonte = "BRASILAPI"
            }, situacao.Equals("ATIVA", StringComparison.OrdinalIgnoreCase) || situacao == ""
                ? "" : "Atenção: a situação deste CNPJ na Receita é " + situacao + ".");
        });

    private static object Endereco(string logradouro, string complemento, string bairro, string cidade, string uf, string ibge, string fonte) =>
        new { logradouro, complemento, bairro, cidade, uf, ibge, fonte };

    private static TimeSpan TempoLimite(Linha cfg)
    {
        var s = int.TryParse(cfg.Texto("TEMPO_LIMITE_SEG"), out var n) && n is > 0 and <= 60 ? n : 8;
        return TimeSpan.FromSeconds(s);
    }

    private static async Task<JsonElement?> Buscar(string url, TimeSpan limite, ILogger logger, CancellationToken ct)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps) return null;
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(limite);
        try
        {
            using var resp = await Cliente.GetAsync(uri, cts.Token);
            if (!resp.IsSuccessStatusCode) return null;
            var texto = await resp.Content.ReadAsStringAsync(cts.Token);
            using var doc = JsonDocument.Parse(texto);
            return doc.RootElement.Clone();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
        {
            logger.LogWarning("Consulta externa falhou ({Host}): {Erro}", uri.Host, ex.GetType().Name);
            return null;
        }
    }

    private static Dictionary<string, string>? LerViaCep(JsonElement j)
    {
        if (j.ValueKind != JsonValueKind.Object || j.TryGetProperty("erro", out _)) return null;
        var cidade = Campo(j, "localidade");
        if (cidade == "") return null;
        return new() { ["logradouro"] = Campo(j, "logradouro"), ["complemento"] = Campo(j, "complemento"), ["bairro"] = Campo(j, "bairro"),
                       ["cidade"] = cidade, ["uf"] = Campo(j, "uf").ToUpperInvariant(), ["ibge"] = Campo(j, "ibge") };
    }

    private static Dictionary<string, string>? LerBrasilApiCep(JsonElement j)
    {
        if (j.ValueKind != JsonValueKind.Object) return null;
        var cidade = Campo(j, "city");
        if (cidade == "") return null;
        return new() { ["logradouro"] = Campo(j, "street"), ["complemento"] = "", ["bairro"] = Campo(j, "neighborhood"),
                       ["cidade"] = cidade, ["uf"] = Campo(j, "state").ToUpperInvariant(), ["ibge"] = "" };
    }

    private static string Campo(JsonElement j, string nome) =>
        j.TryGetProperty(nome, out var v) ? v.ValueKind switch
        {
            JsonValueKind.String => v.GetString()?.Trim() ?? "",
            JsonValueKind.Number => v.GetRawText(),
            _ => ""
        } : "";

    // A Receita devolve tudo em maiúsculas: "RUA DAS FLORES" -> "Rua das Flores"
    private static string Titulo(string s)
    {
        if (s == "" || s.Any(char.IsLower)) return s;
        var menores = new HashSet<string> { "da", "das", "de", "do", "dos", "e" };
        var palavras = s.ToLowerInvariant().Split(' ', StringSplitOptions.RemoveEmptyEntries);
        for (var i = 0; i < palavras.Length; i++)
            if (i == 0 || !menores.Contains(palavras[i]))
                palavras[i] = char.ToUpperInvariant(palavras[i][0]) + palavras[i][1..];
        return string.Join(' ', palavras);
    }
}
