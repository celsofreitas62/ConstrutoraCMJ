// =============================================================================
//  SistemaCMJ.Api - Infra/Resposta.cs
//  Autor     : Celso de Freitas
//  Refatorado: Claude
//  Criação   : 16/11/2026 (fase 3b)
//  Descrição : Formato único de resposta para as telas (padroes/PADRAO_TELAS.md):
//                { sucesso, tipo, mensagem, dados }
//              tipo: "OK"            sucesso (aviso discreto que some sozinho)
//                    "ATENCAO"       recusa de regra de negócio (SUCESSO = 0 ou erro 50001)
//                    "ERRO"          falha técnica (texto técnico só no SIS.Log_Erro)
//                    "SESSAO"        sessão expirada/encerrada (volta ao login)
//                    "TROCAR_SENHA"  precisa trocar a senha antes de continuar
// =============================================================================
using Microsoft.Data.SqlClient;

namespace SistemaCMJ.Api.Infra;

public static class Resposta
{
    public const string MensagemErroTecnico = "Não foi possível concluir a operação. O erro foi registrado para análise.";

    public static IResult Ok(object? dados = null, string mensagem = "") =>
        Results.Json(new { sucesso = true, tipo = "OK", mensagem, dados });

    public static IResult Atencao(string mensagem) =>
        Results.Json(new { sucesso = false, tipo = "ATENCAO", mensagem, dados = (object?)null });

    public static IResult Erro() =>
        Results.Json(new { sucesso = false, tipo = "ERRO", mensagem = MensagemErroTecnico, dados = (object?)null });

    public static IResult Sessao(string mensagem) =>
        Results.Json(new { sucesso = false, tipo = "SESSAO", mensagem, dados = (object?)null }, statusCode: StatusCodes.Status401Unauthorized);

    public static IResult TrocarSenha() =>
        Results.Json(new { sucesso = false, tipo = "TROCAR_SENHA", mensagem = "Defina uma nova senha para continuar.", dados = (object?)null }, statusCode: StatusCodes.Status403Forbidden);

    /// <summary>Resposta de procedure de gravação (1 linha com SUCESSO, MENSAGEM e às vezes ID).</summary>
    public static IResult DeGravacao(Linha linha)
    {
        var mensagem = linha.Texto("MENSAGEM");
        if (!linha.Bool("SUCESSO"))
            return Atencao(mensagem);
        return Ok(new { id = linha.ContainsKey("ID") ? linha.Long("ID") : null }, mensagem);
    }

    /// <summary>
    /// Executa a ação da tela tratando os erros num lugar só:
    /// erro 50001 do SQL (padrão "Listar") = ATENCAO com a mensagem amigável;
    /// qualquer outro erro = ERRO genérico + registro em SIS.Log_Erro.
    /// </summary>
    public static async Task<IResult> Rodar(HttpContext http, Banco banco, ILogger logger, Func<Task<IResult>> acao)
    {
        try
        {
            return await acao();
        }
        catch (SqlException erro) when (erro.Number == 50001)
        {
            return Atencao(erro.Message);
        }
        catch (OperationCanceledException) when (http.RequestAborted.IsCancellationRequested)
        {
            return Results.Empty;
        }
        catch (Exception erro)
        {
            logger.LogError(erro, "Falha em {Metodo} {Caminho}", http.Request.Method, http.Request.Path);
            await banco.RegistrarErroAsync("API " + http.Request.Method + " " + http.Request.Path, "Requisição", erro);
            return Erro();
        }
    }
}
