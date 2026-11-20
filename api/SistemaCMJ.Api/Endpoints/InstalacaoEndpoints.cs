// =============================================================================
//  SistemaCMJ.Api - Endpoints/InstalacaoEndpoints.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 20/11/2026 (fase 3d)
//  Descrição : PRIMEIRO ACESSO da instalação (tela /instalacao.html):
//                GET  /api/instalacao        -> se o banco espera as senhas
//                POST /api/instalacao/senhas -> grava a senha do administrador
//                                               geral e a do administrador da
//                                               empresa, de uma vez
//              Só atende pedido feito NO PRÓPRIO SERVIDOR (localhost); de outro
//              computador responde 404, como se não existisse. E só enquanto
//              nenhum administrador tem senha (SIS_Instalacao_Situacao): depois
//              disso a tela mostra que a instalação já foi concluída.
//              A senha é transformada aqui (PBKDF2-SHA256); o banco só recebe o
//              hash (SIS_Instalacao_Senha_Gravar).
// =============================================================================
using System.Net;
using SistemaCMJ.Api.Infra;

namespace SistemaCMJ.Api.Endpoints;

public sealed record InstalacaoPedido(string? SenhaGeral, string? SenhaEmpresa);

public static class InstalacaoEndpoints
{
    public static void Mapear(WebApplication app)
    {
        app.MapGet("/api/instalacao", Situacao);
        app.MapPost("/api/instalacao/senhas", GravarSenhas);
    }

    private static bool NoServidor(HttpContext http) =>
        http.Connection.RemoteIpAddress is { } ip && IPAddress.IsLoopback(ip);

    private static Task<IResult> Situacao(HttpContext http, Banco banco, ILogger<Program> logger)
    {
        if (!NoServidor(http)) return Task.FromResult(Results.NotFound());
        return Resposta.Rodar(http, banco, logger, async () =>
        {
            var s = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Instalacao_Situacao", null, null, http.RequestAborted);
            return Resposta.Ok(new
            {
                pendente = s.Bool("PENDENTE"),
                loginGeral = s.Texto("LOGIN_GERAL"),
                loginEmpresa = s.Texto("LOGIN_EMPRESA"),
                tamanhoMinimo = Math.Max(await banco.ParametroInteiroAsync("SENHA_TAMANHO_MINIMO", http.RequestAborted), 8)
            });
        });
    }

    private static Task<IResult> GravarSenhas(InstalacaoPedido pedido, HttpContext http, Banco banco, ILogger<Program> logger)
    {
        if (!NoServidor(http)) return Task.FromResult(Results.NotFound());
        return Resposta.Rodar(http, banco, logger, async () =>
        {
            var geral = pedido.SenhaGeral ?? "";
            var empresa = pedido.SenhaEmpresa ?? "";
            var minimo = await banco.ParametroInteiroAsync("SENHA_TAMANHO_MINIMO", http.RequestAborted);
            var recusa = Seguranca.ConferirRegras(geral, minimo);
            if (recusa.Length > 0) return Resposta.Atencao("Administrador geral: " + recusa);
            recusa = Seguranca.ConferirRegras(empresa, minimo);
            if (recusa.Length > 0) return Resposta.Atencao("Administrador da empresa: " + recusa);
            if (geral == empresa) return Resposta.Atencao("Use senhas diferentes para os dois administradores.");

            var iteracoes = Math.Max(await banco.ParametroInteiroAsync("SENHA_PBKDF2_ITERACOES", http.RequestAborted), Seguranca.IteracoesMinimas);
            var (hashGeral, saltGeral) = Seguranca.NovaSenha(geral, iteracoes);
            var (hashEmpresa, saltEmpresa) = Seguranca.NovaSenha(empresa, iteracoes);
            var r = await banco.ExecutarUmaLinhaAsync("SIS.SIS_Instalacao_Senha_Gravar",
                new Dictionary<string, object?>
                {
                    ["HashGeral"] = hashGeral, ["SaltGeral"] = saltGeral,
                    ["HashEmpresa"] = hashEmpresa, ["SaltEmpresa"] = saltEmpresa,
                    ["Iteracoes"] = iteracoes, ["Algoritmo"] = Seguranca.Algoritmo,
                    ["Ip"] = Banco.Cortar(http.Connection.RemoteIpAddress?.ToString(), 45)
                }, null, http.RequestAborted);
            if (r.Bool("SUCESSO"))
                logger.LogInformation("Primeiro acesso: senhas dos administradores definidas no servidor.");
            return r.Bool("SUCESSO") ? Resposta.Ok(null, r.Texto("MENSAGEM")) : Resposta.Atencao(r.Texto("MENSAGEM"));
        });
    }
}
