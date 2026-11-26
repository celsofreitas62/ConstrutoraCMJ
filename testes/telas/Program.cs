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
//                   Gravar -> "Gravar?" -> Confirmar -> "Concluído";
//                1b) aviso "O que há de novo" (Entendi) e versão no topo (04c2);
//                4) desfazer essa gravação pela aba Histórico (04b2, 23/11/2026):
//                   "Desfazer esta operação" -> prévia -> motivo -> "Concluído"
//                   e o nome volta a ser o de antes;
//                5) consultas de CEP e CNPJ (04d2); 6) anexar e excluir um
//                   arquivo de teste na ficha do parceiro (04d2);
//                7) fichas de empresa, conta e centro; escolha com busca e
//                   plano de contas em árvore (04e, só leitura);
//                8) contas a pagar e a receber: contadores, filtro e filtro
//                   salvo (04f2a).
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

// ---------------------------------------------------------------- 1b) "O que há de novo" e versão no topo (04c2, 25/11/2026)
// Depois de uma versão nova o aviso aparece uma vez: confere o conteúdo e clica em Entendi
// (fica marcado no banco; nas rodadas seguintes não aparece mais, e tudo bem).
try
{
    var aviso = pagina.Locator("dialog.janela-novidades");
    try { await aviso.WaitForAsync(new() { Timeout = 4000 }); } catch (TimeoutException) { }
    if (await aviso.CountAsync() > 0)
    {
        var titulo = (await aviso.Locator("h2").First.InnerTextAsync()).Trim();
        var itens = await aviso.Locator("li").CountAsync();
        await aviso.Locator(".botao-principal").ClickAsync();
        await aviso.WaitForAsync(new() { State = WaitForSelectorState.Detached, Timeout = 10000 });
        Linha(titulo == "O que há de novo" && itens > 0, "aviso O que ha de novo (Entendi)", titulo + ", " + itens + " itens");
    }
    else Linha(true, "aviso O que ha de novo", "nenhuma novidade pendente para o usuario de teste");
    var versao = (await pagina.Locator("a.topo-versao").First.InnerTextAsync(new() { Timeout = 5000 })).Trim();
    Linha(versao.StartsWith("v"), "versao no topo (atalho para Versoes)", versao);
}
catch (Exception erro)
{
    Linha(false, "aviso O que ha de novo / versao no topo", erro.Message.Split('\n')[0]);
    await Foto("novidades");
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
var nomeAntes = "";
var idTeste = 0;
try
{
    var busca = await Api("/api/sis/usuarios?busca=" + Uri.EscapeDataString(loginGravacao) + "&situacao=TODOS");
    var idExistente = busca.GetProperty("dados").EnumerateArray()
        .Where(u => u.GetProperty("LOGIN").GetString() == loginGravacao).Select(u => u.GetProperty("ID_USUARIO").GetInt32()).FirstOrDefault();
    await pagina.GotoAsync(endereco + "/sis/usuario.html" + (idExistente > 0 ? "?id=" + idExistente : ""), new() { WaitUntil = WaitUntilState.NetworkIdle });
    if (idExistente == 0) await pagina.Locator("#login").FillAsync(loginGravacao);
    idTeste = idExistente;
    nomeAntes = (await pagina.Locator("#nome").InputValueAsync()).Trim();
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

// ---------------------------------------------------------------- 4) Desfazer pela aba Histórico
if (motivoGravar.Length == 0 && idTeste > 0)
{
    errosJs.Clear();
    errosApi.Clear();
    relogio.Restart();
    var motivoDesfazer = "";
    try
    {
        await pagina.Locator("#aba-historico").ClickAsync();
        var botaoDesfazer = pagina.Locator("#historico tr.linha-grupo").First.Locator("button", new() { HasText = "Desfazer esta operação" });
        await botaoDesfazer.WaitForAsync(new() { Timeout = 10000 });
        await botaoDesfazer.ClickAsync();
        await pagina.Locator("dialog.janela textarea").WaitForAsync(new() { Timeout = 10000 });
        await pagina.Locator("dialog.janela textarea").FillAsync("teste automatico das telas");
        await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
        await pagina.WaitForFunctionAsync("() => { const h = document.querySelector('dialog.janela h2'); return h && (h.textContent === 'Concluído' || h.textContent === 'Atenção' || h.textContent === 'Erro'); }", null, new() { Timeout = 15000 });
        var resposta = await JanelaAberta();
        if (resposta?.Titulo != "Concluído") motivoDesfazer = "janela \"" + resposta?.Titulo + "\": " + resposta?.Texto;
        else
        {
            await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            await pagina.WaitForTimeoutAsync(500);
            var voltou = (await pagina.Locator("#nome").InputValueAsync()).Trim();
            if (voltou != nomeAntes) motivoDesfazer = "depois de desfazer, o nome e \"" + voltou + "\" (esperado \"" + nomeAntes + "\")";
        }
        if (motivoDesfazer.Length == 0 && errosJs.Count > 0) motivoDesfazer = "erro de JavaScript: " + errosJs[0];
        if (motivoDesfazer.Length == 0 && errosApi.Count > 0) motivoDesfazer = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivoDesfazer = erro.Message.Split('\n')[0]; }
    Linha(motivoDesfazer.Length == 0, "desfazer a gravacao pela aba Historico (" + relogio.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivoDesfazer);
    if (motivoDesfazer.Length > 0) await Foto("desfazer");
}

// ---------------------------------------------------------------- 5) Consultas de CEP e CNPJ (04d2, 25/11/2026)
// Dependem da internet: falha de comunicação com o serviço aparece como aviso (ATENCAO), não como erro da tela.
foreach (var (rota, oque) in new[] { ("/api/cad/consulta/cep/37701000", "consulta de CEP 37701-000"), ("/api/cad/consulta/cnpj/25686528000197", "consulta de CNPJ da CMJ") })
{
    try
    {
        var r = await Api(rota);
        var ok = r.GetProperty("sucesso").GetBoolean();
        Linha(ok, oque, ok ? "" : r.GetProperty("mensagem").GetString() ?? "");
    }
    catch (Exception erro) { Linha(false, oque, erro.Message.Split('\n')[0]); }
}

// ---------------------------------------------------------------- 6) Anexar e excluir um arquivo de teste (04d2, 25/11/2026)
// No primeiro parceiro ativo da lista: + Anexar arquivo -> tipo Outro -> arquivo .txt -> Anexar -> "Concluído";
// depois Excluir (motivo) -> "Concluído". O arquivo fica guardado como excluído (não atrapalha).
{
    errosJs.Clear();
    errosApi.Clear();
    relogio.Restart();
    var motivoAnexo = "";
    try
    {
        var lista = await Api("/api/cad/pessoas?situacao=ATIVOS");
        var idParceiro = lista.GetProperty("dados").EnumerateArray().Select(p => p.GetProperty("ID_PESSOA").GetInt32()).FirstOrDefault();
        if (idParceiro == 0) motivoAnexo = "nenhum parceiro ativo para anexar";
        else
        {
            await pagina.GotoAsync(endereco + "/cad/pessoa.html?id=" + idParceiro + "#anexos", new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            var anexar = pagina.Locator("#anexos button", new() { HasText = "+ Anexar arquivo" });
            await anexar.WaitForAsync(new() { Timeout = 10000 });
            await anexar.ClickAsync();
            var janela = pagina.Locator("dialog.janela");
            await janela.Locator("select").WaitForAsync(new() { Timeout = 10000 });
            await janela.Locator("select").SelectOptionAsync("OUTRO");
            var nomeArquivo = "teste-automatico-" + DateTime.Now.ToString("yyyyMMddHHmmss") + ".txt";
            await janela.Locator("input[type=file]").SetInputFilesAsync(new FilePayload { Name = nomeArquivo, MimeType = "text/plain", Buffer = System.Text.Encoding.UTF8.GetBytes("Teste automatico das telas " + Guid.NewGuid()) });
            await janela.Locator(".botao-principal").ClickAsync();
            await pagina.WaitForFunctionAsync("() => { const h = document.querySelector('dialog.janela h2'); return (h && h.textContent === 'Concluído') || [...document.querySelectorAll('dialog.janela .aviso-revisar')].some(a => !a.hidden); }", null, new() { Timeout = 20000 });
            var resposta = await JanelaAberta();
            if (resposta?.Titulo != "Concluído") motivoAnexo = "anexar: " + (await janela.Locator(".aviso-revisar").First.InnerTextAsync()).Trim();
            else
            {
                await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
                var linha = pagina.Locator("#anexos tr", new() { HasText = nomeArquivo });
                await linha.WaitForAsync(new() { Timeout = 10000 });
                await linha.Locator("button", new() { HasText = "Excluir" }).ClickAsync();
                await pagina.Locator("dialog.janela input").FillAsync("teste automatico das telas");
                await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
                await pagina.WaitForFunctionAsync("() => { const h = document.querySelector('dialog.janela h2'); return h && (h.textContent === 'Concluído' || h.textContent === 'Atenção' || h.textContent === 'Erro'); }", null, new() { Timeout = 15000 });
                var r2 = await JanelaAberta();
                if (r2?.Titulo != "Concluído") motivoAnexo = "excluir: janela \"" + r2?.Titulo + "\": " + r2?.Texto;
                else await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
            }
        }
        if (motivoAnexo.Length == 0 && errosJs.Count > 0) motivoAnexo = "erro de JavaScript: " + errosJs[0];
        if (motivoAnexo.Length == 0 && errosApi.Count > 0) motivoAnexo = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivoAnexo = erro.Message.Split('\n')[0]; }
    Linha(motivoAnexo.Length == 0, "anexar e excluir arquivo de teste na ficha do parceiro (" + relogio.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivoAnexo);
    if (motivoAnexo.Length > 0) await Foto("anexos");
}

// ---------------------------------------------------------------- 7) Escolha com busca e plano de contas (04e, 25/11/2026)
// Só leitura: na ficha do primeiro parceiro ativo, digita no centro de custo padrão e confere que a lista
// aparece e que escolher preenche o campo (sai sem gravar); no plano de contas, busca, abre e escolhe uma conta.
// Também abre a ficha da primeira empresa, conta bancária e centro de custo pelo id.
{
    errosJs.Clear();
    errosApi.Clear();
    relogio.Restart();
    var motivo7 = "";
    try
    {
        foreach (var (lista, coluna, ficha) in new[] { ("/api/cad/empresas", "ID_EMPRESA", "cad/empresa.html"), ("/api/banco/contas", "ID_CONTA", "banco/conta.html"), ("/api/cad/centros-custo", "ID_CENTRO_CUSTO", "cad/centro-custo.html") })
        {
            var r = await Api(lista);
            var id = r.GetProperty("dados").EnumerateArray().Select(x => x.GetProperty(coluna).GetInt32()).FirstOrDefault();
            if (id == 0) continue;
            await pagina.GotoAsync(endereco + "/" + ficha + "?id=" + id, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            if (await JanelaAberta() is { } j) { motivo7 = ficha + "?id=" + id + ": janela \"" + j.Titulo + "\": " + j.Texto; break; }
            if ((await pagina.Locator("#titulo").InnerTextAsync()).Trim().StartsWith("Nov")) { motivo7 = ficha + "?id=" + id + " abriu como ficha nova"; break; }
        }
        if (motivo7.Length == 0)
        {
            var parceiros = await Api("/api/cad/pessoas?situacao=ATIVOS");
            var idParceiro = parceiros.GetProperty("dados").EnumerateArray().Select(p => p.GetProperty("ID_PESSOA").GetInt32()).FirstOrDefault();
            await pagina.GotoAsync(endereco + "/cad/pessoa.html?id=" + idParceiro, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            var campo = pagina.Locator("#seletor-centro input.seletor-campo");
            await campo.ClickAsync();
            await campo.FillAsync("a");
            var opcao = pagina.Locator("#seletor-centro .seletor-opcao").First;
            await opcao.WaitForAsync(new() { Timeout = 10000 });
            var texto = (await opcao.Locator(".seletor-descricao").InnerTextAsync()).Trim();
            await opcao.DispatchEventAsync("mousedown");
            if ((await campo.InputValueAsync()).Trim() != texto) motivo7 = "escolher na lista nao preencheu o centro de custo";
            await pagina.Locator("#botao-cancelar").ClickAsync();
            if (await JanelaAberta() is not null) await pagina.Locator("dialog.janela .botao-principal").First.ClickAsync(); // descartar
        }
        if (motivo7.Length == 0)
        {
            await pagina.GotoAsync(endereco + "/cad/plano-contas.html", new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            await pagina.Locator("#abrir-tudo").ClickAsync();
            var conta = pagina.Locator("#arvore .plano-n3").First;
            await conta.WaitForAsync(new() { Timeout = 10000 });
            var codigo = (await conta.Locator(".plano-codigo").InnerTextAsync()).Trim();
            await pagina.Locator("#busca").FillAsync(codigo);
            await pagina.WaitForTimeoutAsync(500);
            await pagina.Locator("#arvore .plano-n3").First.ClickAsync();
            var titulo = (await pagina.Locator("#ficha-titulo").InnerTextAsync()).Trim();
            if (!titulo.StartsWith(codigo)) motivo7 = "plano: a ficha mostrou \"" + titulo + "\" em vez da conta " + codigo;
        }
        if (motivo7.Length == 0 && errosJs.Count > 0) motivo7 = "erro de JavaScript: " + errosJs[0];
        if (motivo7.Length == 0 && errosApi.Count > 0) motivo7 = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivo7 = erro.Message.Split('\n')[0]; }
    Linha(motivo7.Length == 0, "fichas de empresa, conta e centro; escolha com busca; plano de contas (" + relogio.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivo7);
    if (motivo7.Length > 0) await Foto("cadastros_base");
}

// ---------------------------------------------------------------- 8) Contas a pagar e a receber (04f2a, 25/11/2026)
// Nas duas telas: contadores carregados; clicar em "Vencidas" marca a situação; salvar um filtro de
// teste (nome "teste automatico", sem abrir com ele), escolher, conferir que voltou, e apagar.
{
    errosJs.Clear();
    errosApi.Clear();
    relogio.Restart();
    var motivo8 = "";
    try
    {
        foreach (var tipo in new[] { "P", "R" })
        {
            await pagina.GotoAsync(endereco + "/fin/lancamentos.html?tipo=" + tipo, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            if (await JanelaAberta() is { } j) { motivo8 = tipo + ": janela \"" + j.Titulo + "\": " + j.Texto; break; }
            if ((await pagina.Locator("#valor-aberto").InnerTextAsync()).Trim() == "–") { motivo8 = tipo + ": contadores nao carregaram"; break; }
            await pagina.Locator(".contador-vencidas").ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            if (await pagina.Locator("#situacao").InputValueAsync() != "VENCIDA") { motivo8 = tipo + ": clicar em Vencidas nao filtrou"; break; }
            await pagina.Locator("#botao-salvar-filtro").ClickAsync();
            await pagina.Locator("dialog.janela input").First.FillAsync("teste automatico");
            await pagina.Locator("dialog.janela .botao-principal").First.ClickAsync();
            await pagina.Locator("dialog.janela .botao:not(.botao-principal)").First.ClickAsync(); // nao abrir com ele
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            if (await JanelaAberta() is { } j2) { motivo8 = tipo + ": salvar filtro abriu \"" + j2.Titulo + "\": " + j2.Texto; break; }
            await pagina.Locator("#botao-limpar").ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            var opcaoSalva = pagina.Locator("#filtro-salvo option", new() { HasText = "teste automatico" });
            await opcaoSalva.WaitForAsync(new() { State = WaitForSelectorState.Attached, Timeout = 10000 });
            var opcao = await opcaoSalva.GetAttributeAsync("value");
            if (string.IsNullOrEmpty(opcao)) { motivo8 = tipo + ": filtro salvo nao apareceu em Meus filtros"; break; }
            await pagina.Locator("#filtro-salvo").SelectOptionAsync(opcao);
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            if (await pagina.Locator("#situacao").InputValueAsync() != "VENCIDA") { motivo8 = tipo + ": aplicar o filtro salvo nao voltou a situacao"; break; }
            await pagina.Locator("#botao-apagar-filtro").ClickAsync();
            await pagina.Locator("dialog.janela .botao-principal").First.ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            try { await pagina.Locator("#filtro-salvo option", new() { HasText = "teste automatico" }).WaitForAsync(new() { State = WaitForSelectorState.Detached, Timeout = 10000 }); }
            catch (TimeoutException) { motivo8 = tipo + ": filtro nao foi apagado"; break; }
            await pagina.Locator("#botao-limpar").ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
        }
        if (motivo8.Length == 0 && errosJs.Count > 0) motivo8 = "erro de JavaScript: " + errosJs[0];
        if (motivo8.Length == 0 && errosApi.Count > 0) motivo8 = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivo8 = erro.Message.Split('\n')[0]; }
    Linha(motivo8.Length == 0, "contas a pagar e a receber: contadores, filtro pela situacao, filtro salvo (" + relogio.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivo8);
    if (motivo8.Length > 0) await Foto("fin_lancamentos");
}

// ---------------------------------------------------------------- 9) Ficha do lançamento (04f2b, 26/11/2026)
// Contas a pagar: incluir um lançamento de teste pelo caminho do usuário (escolhas com busca, gerar
// 2 parcelas, Gravar? > janela de avisos do P17, se vier: marca "Estou ciente", NÃO marca o parceiro >
// Concluído), conferir a ficha gravada, abrir Copiar e descartar, e excluir o lançamento (lixeira).
{
    errosJs.Clear();
    errosApi.Clear();
    relogio.Restart();
    var motivo9 = "";
    var avisos9 = 0;
    try
    {
        async Task Escolher(string seletor, bool pularEncerrado = false)
        {
            var campo = pagina.Locator(seletor + " input.seletor-campo");
            if ((await campo.InputValueAsync()).Trim().Length > 0) return;
            await campo.ClickAsync();
            await campo.FillAsync("a");
            var opcoes = pagina.Locator(seletor + " .seletor-opcao");
            await opcoes.First.WaitForAsync(new() { Timeout = 10000 });
            var qtd = await opcoes.CountAsync();
            for (var i = 0; i < qtd; i++)
            {
                var comp = opcoes.Nth(i).Locator(".seletor-complemento");
                var complemento = await comp.CountAsync() > 0 ? await comp.InnerTextAsync() : "";
                if (pularEncerrado && complemento.Contains("encerrado")) continue;
                await opcoes.Nth(i).DispatchEventAsync("mousedown");
                return;
            }
            throw new Exception("nenhuma opcao valida em " + seletor);
        }
        await pagina.GotoAsync(endereco + "/fin/lancamento.html?tipo=P", new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
        if (await JanelaAberta() is { } j0) motivo9 = "abrir: janela \"" + j0.Titulo + "\": " + j0.Texto;
        if (motivo9.Length == 0)
        {
            await Escolher("#seletor-pessoa");
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            await pagina.WaitForTimeoutAsync(500);
            await Escolher("#seletor-centro", pularEncerrado: true);
            await Escolher("#seletor-plano");
            var historico = "Teste automatico das telas " + DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss");
            await pagina.Locator("#historico").FillAsync(historico);
            await pagina.Locator("#valorTotal").FillAsync("1,01");
            await pagina.Locator("#valorTotal").DispatchEventAsync("change");
            await pagina.Locator("#qtdParcelas").FillAsync("2");
            await pagina.Locator("#primeiroVencimento").FillAsync(DateTime.Today.AddDays(30).ToString("yyyy-MM-dd"));
            await pagina.Locator("#botao-gerar").ClickAsync();
            if (await JanelaAberta() is { } jg) motivo9 = "gerar parcelas: janela \"" + jg.Titulo + "\": " + jg.Texto;
            else if (await pagina.Locator("#linhas-parcelas tr").CountAsync() != 2) motivo9 = "gerar parcelas nao montou 2 parcelas";
            else if ((await pagina.Locator("#soma-parcelas").InnerTextAsync()).Trim() != "1,01") motivo9 = "soma das parcelas diferente de 1,01";
        }
        if (motivo9.Length == 0)
        {
            await pagina.Locator("#botao-gravar").ClickAsync();
            await pagina.Locator("dialog.janela").WaitForAsync(new() { Timeout = 5000 });
            if ((await JanelaAberta())?.Titulo != "Gravar?") motivo9 = "esperava a janela \"Gravar?\"";
            else
            {
                await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
                await pagina.WaitForFunctionAsync("() => { const h = document.querySelector('dialog.janela h2'); return h && h.textContent !== 'Gravar?'; }", null, new() { Timeout = 15000 });
                var janelaAvisos = pagina.Locator("dialog.janela-avisos");
                if (await janelaAvisos.CountAsync() > 0)
                {
                    var titulo = (await janelaAvisos.Locator("h2").InnerTextAsync()).Trim();
                    if (titulo == "Não dá para gravar") motivo9 = "bloqueio: " + (await janelaAvisos.Locator(".lista-avisos").InnerTextAsync()).Replace("\n", " | ");
                    else
                    {
                        var marcas = janelaAvisos.Locator(".aviso-aviso input[type=checkbox]");
                        var n = await marcas.CountAsync();
                        for (var i = 0; i < n; i++)
                        {
                            var rotulo = (await marcas.Nth(i).Locator("xpath=..").InnerTextAsync()).Trim();
                            await marcas.Nth(i).SetCheckedAsync(rotulo == "Estou ciente"); // nao marca o tipo do parceiro
                            if (rotulo == "Estou ciente") avisos9++;
                        }
                        if (await janelaAvisos.Locator("textarea").CountAsync() > 0) await janelaAvisos.Locator("textarea").FillAsync("Teste automatico das telas");
                        await janelaAvisos.Locator(".botao-principal").ClickAsync();
                        await pagina.WaitForFunctionAsync("() => { const h = document.querySelector('dialog.janela h2'); return h && h.textContent === 'Concluído'; }", null, new() { Timeout = 15000 });
                    }
                }
                if (motivo9.Length == 0)
                {
                    var r = await JanelaAberta();
                    if (r?.Titulo != "Concluído") motivo9 = "janela \"" + r?.Titulo + "\": " + r?.Texto;
                    else
                    {
                        await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
                        await pagina.WaitForURLAsync(new System.Text.RegularExpressions.Regex("id=\\d+"), new() { Timeout = 15000 });
                        await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                        if (!(await pagina.Locator("#titulo").InnerTextAsync()).Contains("nº")) motivo9 = "depois de gravar, a ficha nao abriu o lancamento";
                        else if (await pagina.Locator("#linhas-parcelas tr").CountAsync() != 2) motivo9 = "depois de gravar, a ficha nao tem 2 parcelas";
                    }
                }
            }
        }
        var url9 = pagina.Url;
        if (motivo9.Length == 0)
        {
            await pagina.Locator("#botao-copiar").ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            if (!(await pagina.Locator("#titulo").InnerTextAsync()).Contains("cópia")) motivo9 = "Copiar nao abriu a copia";
            else
            {
                await pagina.Locator("#botao-voltar").ClickAsync();
                if (await JanelaAberta() is not null) await pagina.Locator("dialog.janela .botao-principal").First.ClickAsync(); // descartar
                await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            }
        }
        if (motivo9.Length == 0)
        {
            await pagina.GotoAsync(url9, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            await pagina.Locator("#botao-excluir").ClickAsync();
            await pagina.Locator("dialog.janela textarea").FillAsync("Teste automatico das telas");
            await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
            await pagina.WaitForFunctionAsync("() => { const h = document.querySelector('dialog.janela h2'); return h && h.textContent !== 'Excluir lançamento?'; }", null, new() { Timeout = 15000 });
            var r = await JanelaAberta();
            if (r?.Titulo != "Concluído") motivo9 = "excluir: janela \"" + r?.Titulo + "\": " + r?.Texto;
            else await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
        }
        if (motivo9.Length == 0 && errosJs.Count > 0) motivo9 = "erro de JavaScript: " + errosJs[0];
        if (motivo9.Length == 0 && errosApi.Count > 0) motivo9 = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivo9 = erro.Message.Split('\n')[0]; }
    Linha(motivo9.Length == 0, "ficha do lancamento: incluir com 2 parcelas, avisos do P17 (" + avisos9 + "), copiar, excluir (" + relogio.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivo9);
    if (motivo9.Length > 0) await Foto("fin_lancamento");
}

// ---------------------------------------------------------------- Fim
try { await pagina.EvaluateAsync("() => fetch('/api/logout', { method: 'POST', headers: { 'X-CMJ': '1' } })"); } catch { }
Console.WriteLine(new string('=', 70));
Console.WriteLine("Conferencias: " + total + "   falhas: " + falhas + "   fim: " + DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss"));
Console.WriteLine(falhas == 0 ? "RESULTADO: OK" : "RESULTADO: FALHAS (" + falhas + ")");
return falhas;
