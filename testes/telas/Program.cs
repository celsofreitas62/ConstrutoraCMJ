// =============================================================================
//  SistemaCMJ - testes/telas/Program.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 22/11/2026 (fase 4, conversa 04a; sugestão aprovada pelo Celso
//              na 03h: testes automáticos das telas antes de cada publicação)
//  Descrição : Abre o sistema num Edge invisível e confere, tela por tela:
//                1) entrar (login do usuário de teste do LOCAL);
//                2) abrir cada tela do menu e cada ficha: a página carrega,
//                   tem título, não abre janela de erro/recusa, não tem erro
//                   de JavaScript e nenhuma chamada da API responde 500;
//                3) gravar um registro de teste de verdade, pelo caminho do
//                   usuário (usuário "teste.automatico", inativo, só LOCAL):
//                   Gravar -> "Gravar?" -> Confirmar -> "Concluído".
//              Resultado: uma linha por conferência, "RESULTADO: OK" ou
//              "RESULTADO: FALHAS (n)" no fim; código de saída = falhas.
//              Foto da tela em cada falha em %LOCALAPPDATA%\SistemaCMJ\testes_telas.
//              Pré-requisito: o sistema rodando no notebook (api\rodar.cmd).
//  Uso       : pelo executor (entrada\testar_telas.pedido) ou
//              dotnet run --project testes\telas
// =============================================================================
using System.Diagnostics;
using System.Text.Json;
using Microsoft.Playwright;

var config = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "config.json"))).RootElement;
var endereco = config.GetProperty("endereco").GetString()!.TrimEnd('/');
var login = config.GetProperty("login").GetString()!;
var senha = config.GetProperty("senha").GetString()!;
var loginGravacao = config.GetProperty("loginGravacao").GetString()!;
var fichas = config.GetProperty("fichasSemMenu").EnumerateArray().Select(e => e.GetString()!).ToList();
var pastaFotos = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SistemaCMJ", "testes_telas");
Directory.CreateDirectory(pastaFotos);
foreach (var antiga in Directory.GetFiles(pastaFotos, "*.png")) File.Delete(antiga);

var falhas = 0;
var total = 0;
void Linha(bool ok, string oque, string detalhe = "")
{
    total++;
    if (!ok) falhas++;
    Console.WriteLine((ok ? "OK    " : "FALHA ") + oque + (detalhe.Length > 0 ? "  -> " + detalhe : ""));
}

Console.WriteLine("SistemaCMJ - testes automaticos das telas (v1.0)");
Console.WriteLine("Endereco: " + endereco + "   usuario: " + login + "   inicio: " + DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss"));
Console.WriteLine(new string('=', 70));

using var playwright = await Playwright.CreateAsync();
await using var navegador = await playwright.Chromium.LaunchAsync(new() { Channel = "msedge", Headless = true });
var contexto = await navegador.NewContextAsync(new() { IgnoreHTTPSErrors = true, Locale = "pt-BR", ViewportSize = new() { Width = 1366, Height = 900 } });
var pagina = await contexto.NewPageAsync();

// Erros colhidos durante cada tela
var errosJs = new List<string>();
var errosApi = new List<string>();
pagina.Console += (_, m) => { if (m.Type == "error") errosJs.Add(m.Text); };
pagina.PageError += (_, e) => errosJs.Add(e);
pagina.Response += (_, r) => { if (r.Status >= 500 && r.Url.Contains("/api/")) errosApi.Add(r.Status + " " + new Uri(r.Url).AbsolutePath); };

async Task Foto(string nome)
{
    var arquivo = Path.Combine(pastaFotos, string.Concat(nome.Select(c => char.IsLetterOrDigit(c) ? c : '_')) + ".png");
    try { await pagina.ScreenshotAsync(new() { Path = arquivo, FullPage = true }); Console.WriteLine("       foto: " + arquivo); } catch { }
}

/// <summary>Janela de mensagem aberta (dialog.janela): título e texto, ou null.</summary>
async Task<(string Titulo, string Texto)?> JanelaAberta()
{
    var janela = pagina.Locator("dialog.janela");
    if (await janela.CountAsync() == 0) return null;
    return ((await janela.Locator("h2").First.InnerTextAsync()).Trim(), (await janela.Locator(".janela-texto").First.InnerTextAsync()).Trim());
}

async Task<JsonElement> Api(string caminho) =>
    await pagina.EvaluateAsync<JsonElement>("async (u) => (await fetch(u, { headers: { 'X-CMJ': '1' }, credentials: 'same-origin' })).json()", caminho);

// ---------------------------------------------------------------- 1) Entrar
var relogio = Stopwatch.StartNew();
try
{
    await pagina.GotoAsync(endereco + "/login.html");
    await pagina.Locator("input[type=text]").First.FillAsync(login);
    await pagina.Locator("input[type=password]").First.FillAsync(senha);
    await pagina.Locator("input[type=password]").First.PressAsync("Enter");
    await pagina.WaitForURLAsync(u => !u.Contains("/login.html"), new() { Timeout = 15000 });
    Linha(!pagina.Url.Contains("trocar-senha"), "entrar no sistema", pagina.Url.Contains("trocar-senha") ? "o usuario de teste pediu troca de senha (rode sql/local/04a_Usuario_Teste_Telas_LOCAL.sql)" : "");
}
catch (Exception erro)
{
    Linha(false, "entrar no sistema", "o sistema esta rodando (api\\rodar.cmd)? " + erro.Message.Split('\n')[0]);
    await Foto("login");
    Console.WriteLine(new string('=', 70));
    Console.WriteLine("RESULTADO: FALHAS (" + falhas + ")");
    return falhas;
}

// ---------------------------------------------------------------- 2) Abrir cada tela
var menu = await Api("/api/menu");
var telas = new List<string>();
if (menu.GetProperty("sucesso").GetBoolean())
    foreach (var item in menu.GetProperty("dados").EnumerateArray())
        if (item.GetProperty("TIPO").GetString() == "TELA" && item.TryGetProperty("CAMINHO", out var c) && c.GetString() is { Length: > 0 } caminho)
            telas.Add(caminho);
Linha(telas.Count > 0, "menu carregado", telas.Count + " telas");
foreach (var ficha in fichas) if (!telas.Contains(ficha)) telas.Add(ficha);

foreach (var tela in telas)
{
    errosJs.Clear();
    errosApi.Clear();
    relogio.Restart();
    var motivo = "";
    try
    {
        await pagina.GotoAsync(endereco + "/" + tela, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
        await pagina.WaitForTimeoutAsync(300);
        if (await JanelaAberta() is { } j) motivo = "janela \"" + j.Titulo + "\": " + j.Texto;
        else if (!pagina.Url.EndsWith(tela, StringComparison.OrdinalIgnoreCase) && !pagina.Url.Contains("/" + tela + "?")) motivo = "foi parar em " + pagina.Url;
        else if ((await pagina.Locator("h1").CountAsync()) == 0 || (await pagina.Locator("h1").First.InnerTextAsync()).Trim().Length == 0) motivo = "pagina sem titulo (h1)";
        if (motivo.Length == 0 && errosJs.Count > 0) motivo = "erro de JavaScript: " + errosJs[0];
        if (motivo.Length == 0 && errosApi.Count > 0) motivo = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivo = erro.Message.Split('\n')[0]; }
    Linha(motivo.Length == 0, "abrir " + tela + " (" + relogio.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivo);
    if (motivo.Length > 0) await Foto(tela);
    if (await JanelaAberta() is not null) await pagina.Locator("dialog.janela .botao-principal").First.ClickAsync();
}

// ---------------------------------------------------------------- 3) Gravar um registro de teste
errosJs.Clear();
errosApi.Clear();
relogio.Restart();
var motivoGravar = "";
try
{
    var busca = await Api("/api/sis/usuarios?busca=" + Uri.EscapeDataString(loginGravacao) + "&situacao=TODOS");
    var idExistente = busca.GetProperty("dados").EnumerateArray()
        .Where(u => u.GetProperty("LOGIN").GetString() == loginGravacao).Select(u => u.GetProperty("ID_USUARIO").GetInt32()).FirstOrDefault();
    await pagina.GotoAsync(endereco + "/sis/usuario.html" + (idExistente > 0 ? "?id=" + idExistente : ""), new() { WaitUntil = WaitUntilState.NetworkIdle });
    if (idExistente == 0) await pagina.Locator("#login").FillAsync(loginGravacao);
    var nome = "Teste automatico das telas " + DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss");
    await pagina.Locator("#nome").FillAsync(nome);
    await pagina.Locator("#perfil").SelectOptionAsync(new SelectOptionValue { Label = "Consulta" });
    await pagina.Locator("#ativo").SetCheckedAsync(false);
    await pagina.Locator("#botao-gravar").ClickAsync();
    await pagina.Locator("dialog.janela").WaitForAsync(new() { Timeout = 5000 });
    var pergunta = await JanelaAberta();
    if (pergunta?.Titulo != "Gravar?") motivoGravar = "esperava a janela \"Gravar?\", veio " + (pergunta?.Titulo ?? "nada");
    else
    {
        await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
        await pagina.WaitForFunctionAsync("() => { const h = document.querySelector('dialog.janela h2'); return h && h.textContent !== 'Gravar?'; }", null, new() { Timeout = 15000 });
        var resposta = await JanelaAberta();
        if (resposta?.Titulo != "Concluído") motivoGravar = "janela \"" + resposta?.Titulo + "\": " + resposta?.Texto;
        else
        {
            await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            var gravado = (await pagina.Locator("#nome").InputValueAsync()).Trim();
            if (gravado != nome) motivoGravar = "depois de gravar, o nome na ficha e \"" + gravado + "\"";
        }
    }
    if (motivoGravar.Length == 0 && errosJs.Count > 0) motivoGravar = "erro de JavaScript: " + errosJs[0];
    if (motivoGravar.Length == 0 && errosApi.Count > 0) motivoGravar = "API respondeu " + errosApi[0];
}
catch (Exception erro) { motivoGravar = erro.Message.Split('\n')[0]; }
Linha(motivoGravar.Length == 0, "gravar usuario de teste " + loginGravacao + " (" + relogio.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivoGravar);
if (motivoGravar.Length > 0) await Foto("gravar");

// ---------------------------------------------------------------- Fim
try { await pagina.EvaluateAsync("() => fetch('/api/logout', { method: 'POST', headers: { 'X-CMJ': '1' } })"); } catch { }
Console.WriteLine(new string('=', 70));
Console.WriteLine("Conferencias: " + total + "   falhas: " + falhas + "   fim: " + DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss"));
Console.WriteLine(falhas == 0 ? "RESULTADO: OK" : "RESULTADO: FALHAS (" + falhas + ")");
return falhas;
