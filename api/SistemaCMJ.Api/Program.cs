// =============================================================================
//  SistemaCMJ.Api - Program.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Ponto de partida do serviço do SistemaCMJ (ASP.NET Core,
//              .NET 10, Minimal API). Serve as telas (wwwroot) e a API (/api).
//              Linha de comando:
//                dotnet run                         -> sobe o sistema
//                dotnet run -- senha-inicial celso  -> primeira senha de um usuário
//              Agendador (17/11/2026, fase 3c): roda as rotinas agendadas e
//              envia os e-mails da fila a cada minuto (Infra/Agendador.cs).
//              Licença: nesta fase só é lida (conferência da assinatura numa
//              parte própria, antes da instalação na CMJ).
//              Servidor (20/11/2026, fase 3d):
//                - roda como serviço do Windows (nome SisCMJ);
//                - configuração do servidor fora da pasta do programa:
//                  %ProgramData%\SisCMJ\appsettings.Servidor.json (opcional;
//                  outro caminho em SisCMJ:ArquivoConfig), depois as variáveis
//                  de ambiente; endereço, porta e certificado HTTPS na seção
//                  "Kestrel" (appsettings.Production.json);
//                - registro em arquivo (Infra/RegistroArquivo.cs);
//                - erro não tratado em /api vira resposta padrão e vai para o
//                  registro;
//                - GET /api/saude (Endpoints/SaudeEndpoints.cs);
//                - versão do banco conferida (Infra/VersaoBanco.cs);
//                - telas e ajuda EMBUTIDAS no executável fora do
//                  desenvolvimento (decisão de 18/11/2026; Telas:Embutidas);
//                  no desenvolvimento ficam soltas em wwwroot;
//                - primeiro acesso da instalação, só no próprio servidor
//                  (Endpoints/InstalacaoEndpoints.cs, /instalacao.html);
//                - licença conferida (Infra/LicencaServico.cs);
//                - ajuda exclusiva do administrador geral, só pela API
//                  (Endpoints/AjudaGeralEndpoints.cs; 22/11/2026, etapa 03g).
// =============================================================================
using SistemaCMJ.Api.Endpoints;
using SistemaCMJ.Api.Ferramentas;
using SistemaCMJ.Api.Infra;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting.WindowsServices;

// Como serviço do Windows, a pasta de trabalho é a do executável (não C:\Windows\System32).
var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = WindowsServiceHelpers.IsWindowsService() ? AppContext.BaseDirectory : default
});
builder.Host.UseWindowsService(opcoes => opcoes.ServiceName = "SisCMJ");

// Configuração do servidor (conexão, e-mail, pastas): arquivo protegido fora da pasta do programa.
// Só fora do desenvolvimento: no notebook o rodar.cmd nunca lê a configuração de um serviço instalado ali.
var arquivoServidor = builder.Configuration["SisCMJ:ArquivoConfig"];
if (string.IsNullOrWhiteSpace(arquivoServidor))
    arquivoServidor = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "SisCMJ", "appsettings.Servidor.json");
if (!builder.Environment.IsDevelopment())
{
    builder.Configuration.AddJsonFile(arquivoServidor, optional: true, reloadOnChange: false);
    builder.Configuration.AddEnvironmentVariables();
    builder.Configuration.AddCommandLine(args);
}

var registroArquivo = new RegistroArquivoProvider(builder.Configuration);
builder.Logging.AddProvider(registroArquivo);

builder.Services.AddSingleton<Banco>();
builder.Services.AddSingleton<EnvioEmail>();
builder.Services.AddSingleton<VersaoBanco>();
builder.Services.AddSingleton<LicencaServico>();

if (args.Length > 0 && args[0].Equals("senha-inicial", StringComparison.OrdinalIgnoreCase))
{
    var banco = new Banco(builder.Configuration);
    return await SenhaInicial.RodarAsync(args, banco);
}

builder.Services.AddHostedService<Agendador>();

var app = builder.Build();

app.Logger.LogInformation("SisCMJ {Versao} iniciado ({Ambiente}). Pasta do programa: {Pasta}. Configuração do servidor: {Arquivo} ({Existe}). Registro em: {Registro}",
    SaudeEndpoints.VersaoPrograma, app.Environment.EnvironmentName, app.Environment.ContentRootPath,
    arquivoServidor, app.Environment.IsDevelopment() ? "não usada no desenvolvimento" : File.Exists(arquivoServidor) ? "encontrada" : "não existe", registroArquivo.Pasta);
_ = app.Services.GetRequiredService<LicencaServico>().ConferirAsync();   // registra a situação da licença ao subir
app.Lifetime.ApplicationStopping.Register(() => app.Logger.LogInformation("SisCMJ parando."));

// Erro não tratado: registra e devolve a resposta padrão (o texto técnico não vai para a tela).
app.Use(async (http, proximo) =>
{
    try
    {
        await proximo();
    }
    catch (Exception erro) when (!http.Response.HasStarted && !http.RequestAborted.IsCancellationRequested)
    {
        app.Logger.LogError(erro, "Erro não tratado em {Metodo} {Caminho}", http.Request.Method, http.Request.Path);
        http.Response.Clear();
        await Resposta.Erro().ExecuteAsync(http);
    }
});

// Cabeçalhos de segurança em toda resposta.
app.Use(async (http, proximo) =>
{
    var cabecalhos = http.Response.Headers;
    cabecalhos["X-Content-Type-Options"] = "nosniff";
    cabecalhos["X-Frame-Options"] = "DENY";
    cabecalhos["Referrer-Policy"] = "no-referrer";
    cabecalhos["Content-Security-Policy"] =
        "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'";
    if (http.Request.Path.StartsWithSegments("/api"))
        cabecalhos.CacheControl = "no-store";
    await proximo();
});

// Telas: embutidas no executável (servidor) ou soltas em wwwroot (desenvolvimento).
var telasEmbutidas = app.Configuration.GetValue("Telas:Embutidas", !app.Environment.IsDevelopment());
if (telasEmbutidas)
    app.Environment.WebRootFileProvider = new ManifestEmbeddedFileProvider(typeof(Program).Assembly, "wwwroot");
app.Logger.LogInformation("Telas {Origem}.", telasEmbutidas ? "embutidas no executável" : "soltas em " + app.Environment.WebRootPath);

app.UseDefaultFiles();
app.UseStaticFiles(new StaticFileOptions
{
    // Telas sempre atualizadas durante o desenvolvimento.
    OnPrepareResponse = arquivo => arquivo.Context.Response.Headers.CacheControl = "no-cache"
});

app.UseMiddleware<SessaoMiddleware>();

AcessoEndpoints.Mapear(app);
SistemaEndpoints.Mapear(app);
PessoaEndpoints.Mapear(app);
UsuarioEndpoints.Mapear(app);
HistoricoEndpoints.Mapear(app);
ComunicadoEndpoints.Mapear(app);
ComunicadoEndpoints.MapearLogo(app);
MigracaoEndpoints.Mapear(app);
BackupEndpoints.Mapear(app);
SaudeEndpoints.Mapear(app);
InstalacaoEndpoints.Mapear(app);
AjudaGeralEndpoints.Mapear(app, telasEmbutidas);

// Rota /api que não existe: resposta padrão (não cai na página).
app.MapFallback("/api/{**resto}", () => Results.NotFound());

await app.RunAsync();
return 0;
