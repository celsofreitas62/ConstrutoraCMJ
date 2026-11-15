/*******************************************************************************
  Objeto      : [SIS].[SIS_Log_Erro_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Grava um erro da API ou do serviço em SIS.Log_Erro, para tudo
                ficar no mesmo lugar dos erros do SQL. As procedures do SQL não
                precisam chamar esta: gravam direto no CATCH (gabaritos).
                @Detalhe: pilha de chamadas/contexto técnico. Nunca enviar
                senha, token ou cabeçalho de autenticação (regra 53/54).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_LOG_ERRO.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Log_Erro_Gravar @Rotina = N'API/teste', @Etapa = N'Homologação', @NumeroErro = 0, @Mensagem = N'Teste de gravação de erro', @Linha = 0, @Origem = 'API';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Log_Erro_Gravar]
    @Rotina      NVARCHAR(256),
    @Etapa       NVARCHAR(200)  = NULL,
    @NumeroErro  INT            = NULL,
    @Mensagem    NVARCHAR(4000),
    @Linha       INT            = NULL,
    @Origem      VARCHAR(10)    = NULL,
    @Detalhe     NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdLogErro BIGINT;

    BEGIN TRY
        SET @Origem = UPPER(ISNULL(NULLIF(LTRIM(RTRIM(@Origem)), ''), 'API'));
        IF @Origem NOT IN ('SQL', 'API', 'SERVICO') SET @Origem = 'API';

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, ORIGEM, DETALHE)
        VALUES (ISNULL(@Rotina, N''), ISNULL(@Etapa, N''), ISNULL(@NumeroErro, 0), ISNULL(@Mensagem, N''), ISNULL(@Linha, 0), @Origem, @Detalhe);

        SET @IdLogErro = CAST(SCOPE_IDENTITY() AS BIGINT);

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Erro registrado.' AS NVARCHAR(400)) AS MENSAGEM, @IdLogErro AS ID_LOG_ERRO;
    END TRY
    BEGIN CATCH
        -- O próprio log falhou: não há onde registrar; devolve o motivo para a API gravar no arquivo de log dela.
        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível registrar o erro: ' + ISNULL(ERROR_MESSAGE(), N'') AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_LOG_ERRO;
    END CATCH;
END;
GO
