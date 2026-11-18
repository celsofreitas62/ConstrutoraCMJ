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
// =============================================================================
using SistemaCMJ.Api.Endpoints;
using SistemaCMJ.Api.Ferramentas;
using SistemaCMJ.Api.Infra;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<Banco>();
builder.Services.AddSingleton<EnvioEmail>();

if (args.Length > 0 && args[0].Equals("senha-inicial", StringComparison.OrdinalIgnoreCase))
{
    var banco = new Banco(builder.Configuration);
    return await SenhaInicial.RodarAsync(args, banco);
}

builder.Services.AddHostedService<Agendador>();

var app = builder.Build();

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
ComunicadoEndpoints.Mapear(app);
ComunicadoEndpoints.MapearLogo(app);
MigracaoEndpoints.Mapear(app);

// Rota /api que não existe: resposta padrão (não cai na página).
app.MapFallback("/api/{**resto}", () => Results.NotFound());

await app.RunAsync();
return 0;
