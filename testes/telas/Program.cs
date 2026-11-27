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
//                   salvo (04f2a); 9) ficha do lançamento (04f2b);
//                10) pendências (04f2c2): + Pendência no lançamento de teste,
//                   resolver, reabrir; contador "Com pendência" na lista.
//                11) Movimentação do Parceiro (resumo e filtro pelo contador) e
//                   Parâmetros de uso (prévia do efeito, motivo ao afrouxar uma
//                   regra, volta ao valor de antes) (04f2d).
//                12) baixa e estorno (04g3d): receber 0,10 do lançamento fixo de
//                   teste pela janela de baixa, estornar pela aba Baixas e
//                   marcar a parcela na lista ("Baixar marcadas" abre a janela).
//                13) caixa (04g4d): transferir 0,10 entre as contas de teste e estornar,
//                   extrato do dia, fechar o caixa B com a contagem por cedulas e reabrir.
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
        // ------------------------------------------------------------ 10) Pendências (04f2c2, 26/11/2026)
        // No lançamento de teste: quadro aparece, "+ Pendência" (1º tipo da lista, previsão "+7 dias") >
        // Incluir > item manual aparece > Resolver (nota) > vai para "Resolvidas" > Reabrir > volta a aberta.
        // Na lista: clicar em "Com pendência" filtra por pendência e passa para "por lançamento".
        if (motivo9.Length == 0)
        {
            var relogio10 = Stopwatch.StartNew();
            var motivo10 = "";
            try
            {
                await pagina.GotoAsync(url9, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
                var quadro = pagina.Locator("#quadro-pendencias");
                if (!await quadro.IsVisibleAsync()) motivo10 = "o quadro de Pendencias nao apareceu na ficha";
                else if (!await quadro.Locator(".quadro-pendencias-topo .botao").IsVisibleAsync()) motivo10 = "botao + Pendencia nao apareceu (acao PENDENCIA?)";
                if (motivo10.Length == 0)
                {
                    var manuaisAntes = await quadro.Locator(".pendencia-item:not(.resolvida) .pendencia-origem", new() { HasText = "Manual" }).CountAsync();
                    await quadro.Locator(".quadro-pendencias-topo .botao").ClickAsync();
                    var janela = pagina.Locator("dialog.janela-larga");
                    await janela.WaitForAsync(new() { Timeout = 10000 });
                    await janela.Locator("select").First.SelectOptionAsync(new SelectOptionValue { Index = 1 });
                    await janela.Locator(".atalhos-data-botoes .botao", new() { HasText = "+7 dias" }).ClickAsync();
                    await janela.Locator("textarea").FillAsync("Teste automatico das telas");
                    await janela.Locator(".botao-principal").ClickAsync();
                    await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                    if (await JanelaAberta() is { } jp) motivo10 = "incluir: janela \"" + jp.Titulo + "\": " + jp.Texto;
                    else
                    {
                        var abertas = quadro.Locator(".pendencia-item:not(.resolvida)", new() { HasText = "Teste automatico das telas" });
                        await abertas.First.WaitForAsync(new() { Timeout = 10000 });
                        if (await quadro.Locator(".pendencia-item:not(.resolvida) .pendencia-origem", new() { HasText = "Manual" }).CountAsync() != manuaisAntes + 1) motivo10 = "a pendencia incluida nao apareceu no quadro";
                    }
                }
                if (motivo10.Length == 0)
                {
                    var item = quadro.Locator(".pendencia-item:not(.resolvida)", new() { HasText = "Teste automatico das telas" }).First;
                    await item.Locator(".botao", new() { HasText = "Resolver" }).ClickAsync();
                    await pagina.Locator("dialog.janela textarea").FillAsync("Resolvida pelo teste automatico");
                    await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
                    await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                    if (await JanelaAberta() is { } jr) motivo10 = "resolver: janela \"" + jr.Titulo + "\": " + jr.Texto;
                    else
                    {
                        var resolvida = quadro.Locator(".pendencias-resolvidas .pendencia-item", new() { HasText = "Teste automatico das telas" }).First;
                        await quadro.Locator(".pendencias-resolvidas summary").ClickAsync();
                        await resolvida.WaitForAsync(new() { Timeout = 10000 });
                        await resolvida.Locator(".botao", new() { HasText = "Reabrir" }).ClickAsync();
                        await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
                        await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                        if (await JanelaAberta() is { } jb) motivo10 = "reabrir: janela \"" + jb.Titulo + "\": " + jb.Texto;
                        else
                        {
                            try { await quadro.Locator(".pendencia-item:not(.resolvida)", new() { HasText = "Teste automatico das telas" }).First.WaitForAsync(new() { Timeout = 10000 }); }
                            catch (TimeoutException) { motivo10 = "depois de reabrir, a pendencia nao voltou para aberta"; }
                        }
                    }
                }
                if (motivo10.Length == 0)
                {
                    await pagina.GotoAsync(endereco + "/fin/lancamentos.html?tipo=P", new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 60000 });
                    if ((await pagina.Locator("#qtd-pendencia").InnerTextAsync()).Trim() is "–" or "0") motivo10 = "contador Com pendencia nao carregou (ou zero com a pendencia de teste aberta)";
                    else
                    {
                        await pagina.Locator(".contador-pendencia").ClickAsync();
                        await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                        if (await pagina.Locator("#pendencia").InputValueAsync() != "COM" || await pagina.Locator("#visao").InputValueAsync() != "LANCAMENTO")
                            motivo10 = "clicar em Com pendencia nao filtrou";
                        else if (await pagina.Locator("#linhas .etiqueta-pendencia").CountAsync() == 0) motivo10 = "lista filtrada sem etiqueta de pendencia";
                        await pagina.Locator("#botao-limpar").ClickAsync();
                        await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                    }
                }
                if (motivo10.Length == 0 && errosJs.Count > 0) motivo10 = "erro de JavaScript: " + errosJs[0];
                if (motivo10.Length == 0 && errosApi.Count > 0) motivo10 = "API respondeu " + errosApi[0];
            }
            catch (Exception erro) { motivo10 = erro.Message.Split('\n')[0]; }
            Linha(motivo10.Length == 0, "pendencias: incluir, resolver, reabrir e contador na lista (" + relogio10.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivo10);
            if (motivo10.Length > 0) await Foto("fin_pendencias");
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

// ---------------------------------------------------------------- 11) Movimentação do Parceiro e Parâmetros de uso (04f2d, 26/11/2026)
// a) ficha de um parceiro com conta a receber em aberto: aba Movimentação, resumo (contadores) e grade com linha;
//    clicar no contador "A receber em aberto" filtra a grade.
// b) Parâmetros de uso: prévia do efeito de um parâmetro de pendência (FIN_PEND_VENCIDA_DIAS, cancelada, nada gravado);
//    afrouxar uma regra (FIN_REGRA_DUPLIC_DOCUMENTO para "Não confere") pede o motivo e grava; depois volta ao valor de antes.
{
    errosJs.Clear();
    errosApi.Clear();
    var relogio11 = Stopwatch.StartNew();
    var motivo11 = "";
    try
    {
        var aberto = await Api("/api/fin/lancamentos?tipo=R&situacao=EM_ABERTO&porPagina=10");
        var idPessoa = 0;
        if (aberto.GetProperty("sucesso").GetBoolean())
            foreach (var l in aberto.GetProperty("dados").EnumerateArray())
                if (l.TryGetProperty("ID_PESSOA", out var ip) && ip.ValueKind == JsonValueKind.Number) { idPessoa = ip.GetInt32(); break; }
        if (idPessoa == 0) motivo11 = "nenhum parceiro com conta a receber em aberto no LOCAL";
        else
        {
            await pagina.GotoAsync(endereco + "/cad/pessoa.html?id=" + idPessoa, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            var aba = pagina.Locator("#aba-movimentacao");
            if (!await aba.IsVisibleAsync()) motivo11 = "aba Movimentacao nao apareceu";
            else
            {
                await aba.ClickAsync();
                await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                var painel = pagina.Locator("#movimentacao");
                await painel.Locator("tbody tr").First.WaitForAsync(new() { Timeout = 30000 });
                if (await painel.Locator(".contador").CountAsync() < 3) motivo11 = "resumo da Movimentacao sem os contadores";
                else if (await painel.Locator("tbody tr.clicavel").CountAsync() == 0) motivo11 = "grade da Movimentacao sem lancamento (o parceiro tem conta em aberto)";
                else
                {
                    await painel.Locator(".contador", new() { HasText = "A receber em aberto" }).ClickAsync();
                    await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                    var tipos = await painel.Locator("tbody tr.clicavel td:first-child").AllInnerTextsAsync();
                    if (tipos.Count == 0 || tipos.Any(t => t.Trim() != "A receber")) motivo11 = "contador A receber em aberto nao filtrou a grade";
                }
            }
        }

        if (motivo11.Length == 0)
        {
            await pagina.GotoAsync(endereco + "/sis/parametros.html?uso=1", new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            // prévia do efeito, cancelada
            var linhaPend = pagina.Locator(".tabela-parametros tbody tr", new() { HasText = "FIN_PEND_VENCIDA_DIAS" }).First;
            var campoPend = linhaPend.Locator("input");
            var dias = await campoPend.InputValueAsync();
            await campoPend.FillAsync(((int.TryParse(dias, out var diasNum) ? diasNum : 30) + 5).ToString());
            await linhaPend.Locator(".botao", new() { HasText = "Gravar" }).ClickAsync();
            await pagina.Locator("dialog.janela").WaitForAsync(new() { Timeout = 60000 });
            var previa = await JanelaAberta();
            if (previa is null || !previa.Value.Texto.Contains("lançamentos em aberto")) motivo11 = "previa do parametro de pendencia sem o efeito: " + previa?.Texto;
            await pagina.Locator("dialog.janela .botao:not(.botao-principal)").First.ClickAsync();
            await campoPend.FillAsync(dias);

            // afrouxar com motivo e voltar
            if (motivo11.Length == 0)
            {
                var linhaRegra = pagina.Locator(".tabela-parametros tbody tr", new() { HasText = "FIN_REGRA_DUPLIC_DOCUMENTO" }).First;
                var antes = await linhaRegra.Locator("select").InputValueAsync();
                if (antes != "NAO")
                {
                    await linhaRegra.Locator("select").SelectOptionAsync("NAO");
                    await linhaRegra.Locator(".botao", new() { HasText = "Gravar" }).ClickAsync();
                    var textoMotivo = pagina.Locator("dialog.janela textarea");
                    try { await textoMotivo.WaitForAsync(new() { Timeout = 15000 }); }
                    catch (TimeoutException) { motivo11 = "afrouxar a regra nao pediu o motivo"; }
                    if (motivo11.Length == 0)
                    {
                        await textoMotivo.FillAsync("Teste automatico das telas");
                        await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
                        await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                        await pagina.WaitForTimeoutAsync(500);
                        if (await JanelaAberta() is { } jg) motivo11 = "gravar com motivo: janela \"" + jg.Titulo + "\": " + jg.Texto;
                        linhaRegra = pagina.Locator(".tabela-parametros tbody tr", new() { HasText = "FIN_REGRA_DUPLIC_DOCUMENTO" }).First;
                        if (motivo11.Length == 0 && await linhaRegra.Locator("select").InputValueAsync() != "NAO") motivo11 = "a regra nao ficou gravada como Nao confere";
                        // volta ao valor de antes (aperta: sem motivo)
                        await linhaRegra.Locator("select").SelectOptionAsync(antes);
                        await linhaRegra.Locator(".botao", new() { HasText = "Gravar" }).ClickAsync();
                        await pagina.Locator("dialog.janela .botao-principal").ClickAsync();
                        await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
                        await pagina.WaitForTimeoutAsync(500);
                        linhaRegra = pagina.Locator(".tabela-parametros tbody tr", new() { HasText = "FIN_REGRA_DUPLIC_DOCUMENTO" }).First;
                        if (motivo11.Length == 0 && await linhaRegra.Locator("select").InputValueAsync() != antes) motivo11 = "a regra nao voltou para " + antes;
                    }
                }
            }
        }
        if (motivo11.Length == 0 && errosJs.Count > 0) motivo11 = "erro de JavaScript: " + errosJs[0];
        if (motivo11.Length == 0 && errosApi.Count > 0) motivo11 = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivo11 = erro.Message.Split('\n')[0]; }
    Linha(motivo11.Length == 0, "movimentacao do parceiro e parametros de uso: previa do efeito, motivo ao afrouxar (" + relogio11.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivo11);
    if (motivo11.Length > 0) await Foto("movimentacao_parametros");
}

// ---------------------------------------------------------------- 12) Baixa e estorno (04g3d, 27/11/2026)
// Conta a receber fixa do LOCAL (sql/local/04g3_Lancamento_Teste_Telas_LOCAL.sql): na aba Parcelas,
// Receber > janela de baixa (conta e forma já vêm escolhidas) > valor 0,10 > Receber > Gravar? >
// avisos, se vierem > Concluído > saldo 999,90; aba Baixas > Estornar > data e motivo, prévia >
// Estornar? > Concluído > saldo volta a 1.000,00. Na lista (visão por parcela), marcar a parcela
// mostra a barra "1 parcela marcada" e "Baixar marcadas" abre a mesma janela (fecha sem gravar).
{
    errosJs.Clear();
    errosApi.Clear();
    var relogio12 = Stopwatch.StartNew();
    var motivo12 = "";
    try
    {
        var busca = await Api("/api/fin/lancamentos?tipo=R&visao=LANCAMENTO&situacao=&texto=" + Uri.EscapeDataString("Teste automatico das telas - baixa"));
        long idLanc = 0;
        if (busca.TryGetProperty("dados", out var dadosBusca) && dadosBusca.ValueKind == JsonValueKind.Array && dadosBusca.GetArrayLength() > 0)
            idLanc = dadosBusca[0].GetProperty("ID_LANCAMENTO").GetInt64();
        if (idLanc == 0) motivo12 = "lancamento de teste nao encontrado: rodar sql/local/04g3_Lancamento_Teste_Telas_LOCAL.sql";

        async Task<decimal> Saldo()
        {
            var l = await Api("/api/fin/lancamentos/" + idLanc);
            return l.GetProperty("dados").GetProperty("PARCELAS")[0].GetProperty("saldo").GetDecimal();
        }
        // conclui a gravação: avisos (Estou ciente + motivo), se vierem, e a janela "Concluído"
        async Task<string> Concluir(string acao)
        {
            await pagina.WaitForFunctionAsync("() => { const d = [...document.querySelectorAll('dialog.janela')].pop(); const h = d && d.querySelector('h2'); return h && !['Gravar?', 'Estornar?'].includes(h.textContent); }", null, new() { Timeout = 15000 });
            var avisos = pagina.Locator("dialog.janela-avisos");
            if (await avisos.CountAsync() > 0)
            {
                if ((await avisos.Locator("h2").InnerTextAsync()).Trim() == "Não dá para gravar")
                    return acao + ": bloqueio: " + (await avisos.Locator(".lista-avisos").InnerTextAsync()).Replace("\n", " | ");
                var marcas = avisos.Locator(".aviso-aviso input[type=checkbox]");
                for (var i = 0; i < await marcas.CountAsync(); i++) await marcas.Nth(i).SetCheckedAsync(true);
                if (await avisos.Locator("textarea").CountAsync() > 0) await avisos.Locator("textarea").FillAsync("Teste automatico das telas");
                await avisos.Locator(".botao-principal").ClickAsync();
            }
            await pagina.WaitForFunctionAsync("() => { const d = [...document.querySelectorAll('dialog.janela')].pop(); const h = d && d.querySelector('h2'); return h && h.textContent === 'Concluído'; }", null, new() { Timeout = 15000 });
            await pagina.Locator("dialog.janela").Last.Locator(".botao-principal").ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            await pagina.WaitForTimeoutAsync(500);
            return "";
        }

        if (motivo12.Length == 0)
        {
            var antes = await Saldo();
            if (antes < 0.10m) motivo12 = "a parcela de teste esta sem saldo (" + antes + ")";
            else
            {
                await pagina.GotoAsync(endereco + "/fin/lancamento.html?tipo=R&id=" + idLanc + "#parcelas", new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
                await pagina.Locator("#linhas-parcelas .col-baixar .botao", new() { HasText = "Receber" }).First.ClickAsync();
                var janela = pagina.Locator("dialog.janela-baixa");
                await janela.WaitForAsync(new() { Timeout = 10000 });
                await pagina.WaitForFunctionAsync("() => { const c = document.querySelector('dialog.janela-baixa input.seletor-campo'); return c && c.value.trim().length > 0; }", null, new() { Timeout = 10000 });
                if (await janela.Locator("#baixa-forma").InputValueAsync() == "") motivo12 = "a forma padrao nao veio escolhida";
                else
                {
                    var valor = janela.Locator("input[aria-label^='Valor quitado']").First;
                    await valor.FillAsync("0,10");
                    await valor.DispatchEventAsync("change");
                    if (!(await janela.Locator(".baixa-rodape").InnerTextAsync()).Contains("0,10")) motivo12 = "o total da janela nao mostrou 0,10";
                    else
                    {
                        await janela.Locator(".janela-botoes .botao-principal").ClickAsync();
                        await pagina.WaitForFunctionAsync("() => { const d = [...document.querySelectorAll('dialog.janela')].pop(); return d && d.querySelector('h2').textContent === 'Gravar?'; }", null, new() { Timeout = 5000 });
                        await pagina.Locator("dialog.janela").Last.Locator(".botao-principal").ClickAsync();
                        motivo12 = await Concluir("baixa");
                        if (motivo12.Length == 0 && await Saldo() != antes - 0.10m) motivo12 = "depois da baixa, o saldo nao baixou 0,10";
                    }
                }
            }
        }
        if (motivo12.Length == 0)
        {
            var antes = await Saldo();
            await pagina.GotoAsync(endereco + "/fin/lancamento.html?tipo=R&id=" + idLanc + "#baixas", new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            await pagina.Locator("#linhas-baixas .botao", new() { HasText = "Estornar" }).First.ClickAsync();
            var janela = pagina.Locator("dialog.janela", new() { HasText = "Estornar baixa" });
            await janela.WaitForAsync(new() { Timeout = 10000 });
            await janela.Locator("textarea").FillAsync("Teste automatico das telas");
            var botao = janela.Locator(".botao-perigo");
            await pagina.WaitForFunctionAsync("() => { const b = document.querySelector('dialog.janela .botao-perigo'); return b && !b.disabled; }", null, new() { Timeout = 10000 });
            await botao.ClickAsync();
            await pagina.WaitForFunctionAsync("() => { const d = [...document.querySelectorAll('dialog.janela')].pop(); return d && d.querySelector('h2').textContent === 'Estornar?'; }", null, new() { Timeout = 5000 });
            await pagina.Locator("dialog.janela").Last.Locator(".botao-principal").ClickAsync();
            motivo12 = await Concluir("estorno");
            if (motivo12.Length == 0 && await Saldo() != antes + 0.10m) motivo12 = "depois do estorno, o saldo nao voltou";
        }
        if (motivo12.Length == 0)
        {
            await pagina.GotoAsync(endereco + "/fin/lancamentos.html?tipo=R&visao=PARCELA&situacao=", new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 60000 });
            await pagina.Locator("#texto").FillAsync("Teste automatico das telas - baixa");
            await pagina.WaitForTimeoutAsync(800);
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            var marca = pagina.Locator("#linhas .col-marcar input[type=checkbox]").First;
            await marca.CheckAsync();
            if (!(await pagina.Locator("#marcadas-texto").InnerTextAsync()).StartsWith("1 parcela marcada")) motivo12 = "lista: a barra das marcadas nao mostrou 1 parcela";
            else if (!pagina.Url.Contains("lancamentos.html")) motivo12 = "lista: marcar a parcela abriu a ficha";
            else
            {
                await pagina.Locator("#botao-baixar").ClickAsync();
                await pagina.Locator("dialog.janela-baixa").WaitForAsync(new() { Timeout = 10000 });
                await pagina.Locator("dialog.janela-baixa .janela-botoes .botao", new() { HasText = "Cancelar" }).ClickAsync();
                await pagina.WaitForTimeoutAsync(300);
                if (await pagina.Locator("dialog.janela").CountAsync() > 0) motivo12 = "lista: a janela de baixa nao fechou com Cancelar";
                await pagina.Locator("#botao-limpar").ClickAsync();
                await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            }
        }
        if (motivo12.Length == 0 && errosJs.Count > 0) motivo12 = "erro de JavaScript: " + errosJs[0];
        if (motivo12.Length == 0 && errosApi.Count > 0) motivo12 = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivo12 = erro.Message.Split('\n')[0]; }
    Linha(motivo12.Length == 0, "baixa e estorno: receber 0,10 pela ficha, estornar, marcar na lista (" + relogio12.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivo12);
    if (motivo12.Length > 0) await Foto("fin_baixa");
}

// ---------------------------------------------------------------- 13) Caixa: transferência, extrato e fechamento (04g4d, 27/11/2026)
// Contas fixas do LOCAL (sql/local/04g3_Lancamento_Teste_Telas_LOCAL.sql v1.1): "Caixa Teste telas" e
// "Caixa Teste telas B". + Transferir 0,10 de uma para a outra (avisos, se vierem: saldo insuficiente) >
// Concluído; Estornar pela lista (data e motivo, prévia) > Concluído; extrato do dia mostra a transferência
// estornada; fechamento do caixa B com a contagem por cédulas (1 moeda de 0,10 = sobra de 0,10, motivo, sem
// ajuste) > Concluído; Reabrir esse fechamento > Concluído (o caixa B fica aberto para a próxima rodada).
{
    errosJs.Clear();
    errosApi.Clear();
    var relogio13 = Stopwatch.StartNew();
    var motivo13 = "";
    var hoje13 = DateTime.Today.ToString("yyyy-MM-dd");
    try
    {
        async Task<JsonElement> Post(string caminho, string corpo) =>
            await pagina.EvaluateAsync<JsonElement>("async ([u, b]) => (await fetch(u, { method: 'POST', headers: { 'X-CMJ': '1', 'Content-Type': 'application/json' }, credentials: 'same-origin', body: b })).json()", new object[] { caminho, corpo });
        // espera a próxima janela depois da confirmação; trata os avisos (Estou ciente + motivo) e fecha o "Concluído"
        async Task<string> Concluir13(string acao, string confirmacao)
        {
            await pagina.WaitForFunctionAsync("(t) => { const d = [...document.querySelectorAll('dialog.janela')].pop(); return d && d.querySelector('h2').textContent === t; }", confirmacao, new() { Timeout = 10000 });
            await pagina.Locator("dialog.janela").Last.Locator(".botao-principal").ClickAsync();
            try
            {
                await pagina.WaitForFunctionAsync("() => { const d = [...document.querySelectorAll('dialog.janela')].pop(); if (!d) return false; if (d.classList.contains('janela-avisos')) return true; const h = d.querySelector('h2'); return h && ['Concluído', 'Atenção', 'Erro'].includes(h.textContent.trim()); }", null, new() { Timeout = 15000 });
            }
            catch (TimeoutException) { }
            var avisos = pagina.Locator("dialog.janela-avisos");
            if (await avisos.CountAsync() > 0)
            {
                if ((await avisos.Locator("h2").InnerTextAsync()).Trim() == "Não dá para gravar")
                    return acao + ": bloqueio: " + (await avisos.Locator(".lista-avisos").InnerTextAsync()).Replace("\n", " | ");
                var marcas = avisos.Locator(".aviso-aviso input[type=checkbox]");
                for (var i = 0; i < await marcas.CountAsync(); i++) await marcas.Nth(i).SetCheckedAsync(true);
                if (await avisos.Locator("textarea").CountAsync() > 0) await avisos.Locator("textarea").FillAsync("Teste automatico das telas");
                await avisos.Locator(".botao-principal").ClickAsync();
            }
            try
            {
                await pagina.WaitForFunctionAsync("() => { const d = [...document.querySelectorAll('dialog.janela')].pop(); const h = d && d.querySelector('h2'); return h && h.textContent === 'Concluído'; }", null, new() { Timeout = 15000 });
            }
            catch (TimeoutException)
            {
                var j = await JanelaAberta();
                return acao + ": nao chegou ao Concluido" + (j is null ? "" : " (" + j.Value.Titulo + ": " + j.Value.Texto + ")");
            }
            await pagina.Locator("dialog.janela").Last.Locator(".botao-principal").ClickAsync();
            await pagina.WaitForLoadStateAsync(LoadState.NetworkIdle);
            await pagina.WaitForTimeoutAsync(500);
            return "";
        }
        async Task Escolher13(string seletor, string descricao)
        {
            var campo = pagina.Locator(seletor + " input.seletor-campo");
            await campo.ClickAsync();
            await campo.FillAsync(descricao);
            var opcao = pagina.Locator(seletor + " .seletor-opcao").Filter(new() { Has = pagina.Locator(".seletor-descricao", new() { HasTextRegex = new System.Text.RegularExpressions.Regex("^" + System.Text.RegularExpressions.Regex.Escape(descricao) + "$") }) });
            await opcao.First.WaitForAsync(new() { Timeout = 10000 });
            await opcao.First.DispatchEventAsync("mousedown");
        }

        long idA = 0, idB = 0;
        var saldos = await Api("/api/banco/saldos?todas=true&inativas=true");
        foreach (var s in saldos.GetProperty("dados").EnumerateArray())
        {
            var d = s.GetProperty("DESCRICAO").GetString();
            if (d == "Caixa Teste telas") idA = s.GetProperty("ID_CONTA").GetInt64();
            if (d == "Caixa Teste telas B") idB = s.GetProperty("ID_CONTA").GetInt64();
        }
        if (idA == 0 || idB == 0) motivo13 = "contas de teste nao encontradas: rodar sql/local/04g3_Lancamento_Teste_Telas_LOCAL.sql (v1.1)";

        // limpeza de uma rodada que parou no meio: caixa B fechado volta a abrir
        if (motivo13.Length == 0)
        {
            var abertos = await Api("/api/banco/caixa?idConta=" + idB + "&situacao=FECHADO");
            foreach (var f in abertos.GetProperty("dados").EnumerateArray())
                if (f.GetProperty("PODE_REABRIR").GetBoolean())
                    await Post("/api/banco/caixa/" + f.GetProperty("ID_CAIXA_FECHAMENTO").GetInt64() + "/reabrir", "{\"motivo\":\"Teste automatico das telas (limpeza)\"}");
        }

        // a) + Transferir
        long idTransf = 0;
        if (motivo13.Length == 0)
        {
            await pagina.GotoAsync(endereco + "/banco/transferencias.html?idConta=" + idA + "&de=" + hoje13 + "&ate=" + hoje13, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            await pagina.Locator("#botao-incluir").ClickAsync();
            var janela = pagina.Locator("dialog.janela", new() { HasText = "Nova transferência" });
            await janela.WaitForAsync(new() { Timeout = 10000 });
            await pagina.WaitForFunctionAsync("() => { const c = document.querySelector('#tr-origem input.seletor-campo'); return c && c.value.trim().length > 0; }", null, new() { Timeout = 10000 });
            if ((await pagina.Locator("#tr-origem input.seletor-campo").InputValueAsync()).Trim() != "Caixa Teste telas") await Escolher13("#tr-origem", "Caixa Teste telas");
            await Escolher13("#tr-destino", "Caixa Teste telas B");
            await janela.Locator("#tr-valor").FillAsync("0,10");
            await janela.Locator("#tr-historico").FillAsync("Teste automatico das telas");
            await janela.Locator(".janela-botoes .botao-principal").ClickAsync();
            motivo13 = await Concluir13("transferencia", "Gravar?");
            if (motivo13.Length == 0)
            {
                var lista = await Api("/api/banco/transferencias?idConta=" + idA + "&de=" + hoje13 + "&ate=" + hoje13 + "&situacao=ATIVA&texto=" + Uri.EscapeDataString("Teste automatico das telas"));
                var dados = lista.GetProperty("dados");
                if (dados.GetArrayLength() == 0) motivo13 = "a transferencia nao apareceu na lista";
                else
                {
                    idTransf = dados[0].GetProperty("ID_TRANSFERENCIA").GetInt64();
                    if (dados[0].GetProperty("VALOR").GetDecimal() != 0.10m || dados[0].GetProperty("ID_CONTA_DESTINO").GetInt64() != idB) motivo13 = "a transferencia gravada nao bate (valor ou destino)";
                }
            }
        }

        // b) Estornar pela lista
        if (motivo13.Length == 0)
        {
            await pagina.GotoAsync(endereco + "/banco/transferencias.html?idConta=" + idA + "&de=" + hoje13 + "&ate=" + hoje13, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            await pagina.Locator("#linhas tr.linha-marcada, #linhas tr").Filter(new() { HasText = "Teste automatico das telas" }).Locator(".botao", new() { HasText = "Estornar" }).First.ClickAsync();
            var janela = pagina.Locator("dialog.janela", new() { HasText = "Estornar transferência" });
            await janela.WaitForAsync(new() { Timeout = 10000 });
            await janela.Locator("textarea").FillAsync("Teste automatico das telas");
            await pagina.WaitForFunctionAsync("() => { const b = document.querySelector('dialog.janela .botao-perigo'); return b && !b.disabled; }", null, new() { Timeout = 10000 });
            await janela.Locator(".botao-perigo").ClickAsync();
            motivo13 = await Concluir13("estorno da transferencia", "Estornar?");
            if (motivo13.Length == 0)
            {
                var lista = await Api("/api/banco/transferencias?idConta=" + idA + "&de=" + hoje13 + "&ate=" + hoje13 + "&situacao=ESTORNADA&texto=" + Uri.EscapeDataString("Teste automatico das telas"));
                var achou = lista.GetProperty("dados").EnumerateArray().Any(t => t.GetProperty("ID_TRANSFERENCIA").GetInt64() == idTransf);
                if (!achou) motivo13 = "depois do estorno, a transferencia nao ficou ESTORNADA";
            }
        }

        // c) Extrato do dia da conta de origem
        if (motivo13.Length == 0)
        {
            await pagina.GotoAsync(endereco + "/banco/extrato.html?conta=" + idA + "&de=" + hoje13 + "&ate=" + hoje13, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            await pagina.Locator("#extrato-resumo").WaitForAsync(new() { Timeout = 10000 });
            var texto = await pagina.Locator("#extrato").InnerTextAsync();
            if (!texto.Contains("Saldo anterior")) motivo13 = "extrato: sem a linha de saldo anterior";
            else if (!texto.Contains("Transferência para Caixa Teste telas B")) motivo13 = "extrato: a transferencia nao apareceu";
            else if (!texto.Contains("Estornado")) motivo13 = "extrato: a etiqueta Estornado nao apareceu";
            else if ((await pagina.Locator("#saldos tr").CountAsync()) == 0) motivo13 = "extrato: o quadro de saldos ficou vazio";
        }

        // d) Fechamento do caixa B com a contagem por cédulas (sobra de 0,10, sem ajuste)
        if (motivo13.Length == 0)
        {
            await pagina.GotoAsync(endereco + "/banco/caixa.html?conta=" + idB, new() { WaitUntil = WaitUntilState.NetworkIdle, Timeout = 30000 });
            await pagina.WaitForFunctionAsync("() => !document.getElementById('previa').hidden || !document.getElementById('previa-erro').hidden", null, new() { Timeout = 10000 });
            if (await pagina.Locator("#previa-erro").IsVisibleAsync()) motivo13 = "fechamento: " + await pagina.Locator("#previa-erro").InnerTextAsync();
            else
            {
                var sistema = (await pagina.Locator("#p-sistema").InnerTextAsync()).Trim();
                await pagina.Locator("#usar-contagem").CheckAsync();
                var moeda10 = pagina.Locator("input[aria-label='Quantidade: Moeda de 0,10']");
                await moeda10.FillAsync("1");
                await moeda10.DispatchEventAsync("input");
                var contado = await pagina.Locator("#saldoContado").InputValueAsync();
                if (contado != "0,10") motivo13 = "fechamento: a contagem nao levou 0,10 ao saldo contado (" + contado + ")";
                else
                {
                    if (sistema != "0,10") await pagina.Locator("#motivo").FillAsync("Teste automatico das telas");
                    await pagina.Locator("#botao-fechar").ClickAsync();
                    motivo13 = await Concluir13("fechamento", "Gravar?");
                }
                if (motivo13.Length == 0)
                {
                    var f = (await Api("/api/banco/caixa?idConta=" + idB + "&situacao=FECHADO")).GetProperty("dados");
                    if (f.GetArrayLength() == 0) motivo13 = "fechamento: nao apareceu na lista";
                    else if (f[0].GetProperty("SALDO_CONTADO").GetDecimal() != 0.10m || !(f[0].GetProperty("OBSERVACAO").GetString() ?? "").StartsWith("Contagem:"))
                        motivo13 = "fechamento: contado ou contagem nao gravados";
                }
            }
        }

        // e) Reabrir o fechamento pela lista
        if (motivo13.Length == 0)
        {
            await pagina.Locator("#linhas .botao", new() { HasText = "Reabrir" }).First.ClickAsync();
            var janela = pagina.Locator("dialog.janela", new() { HasText = "Reabrir fechamento de caixa" });
            await janela.WaitForAsync(new() { Timeout = 10000 });
            await janela.Locator("textarea").FillAsync("Teste automatico das telas");
            await pagina.WaitForFunctionAsync("() => { const b = document.querySelector('dialog.janela .botao-perigo'); return b && !b.disabled; }", null, new() { Timeout = 10000 });
            await janela.Locator(".botao-perigo").ClickAsync();
            motivo13 = await Concluir13("reabertura", "Reabrir?");
            if (motivo13.Length == 0 && (await Api("/api/banco/caixa?idConta=" + idB + "&situacao=FECHADO")).GetProperty("dados").GetArrayLength() > 0)
                motivo13 = "reabertura: o caixa B continua fechado";
        }
        if (motivo13.Length == 0 && errosJs.Count > 0) motivo13 = "erro de JavaScript: " + errosJs[0];
        if (motivo13.Length == 0 && errosApi.Count > 0) motivo13 = "API respondeu " + errosApi[0];
    }
    catch (Exception erro) { motivo13 = erro.Message.Split('\n')[0]; }
    Linha(motivo13.Length == 0, "caixa: transferir 0,10 e estornar, extrato, fechar o caixa com a contagem e reabrir (" + relogio13.Elapsed.TotalSeconds.ToString("0.0") + " s)", motivo13);
    if (motivo13.Length > 0) await Foto("banco_caixa");
}

// ---------------------------------------------------------------- Fim
try { await pagina.EvaluateAsync("() => fetch('/api/logout', { method: 'POST', headers: { 'X-CMJ': '1' } })"); } catch { }
Console.WriteLine(new string('=', 70));
Console.WriteLine("Conferencias: " + total + "   falhas: " + falhas + "   fim: " + DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss"));
Console.WriteLine(falhas == 0 ? "RESULTADO: OK" : "RESULTADO: FALHAS (" + falhas + ")");
return falhas;
