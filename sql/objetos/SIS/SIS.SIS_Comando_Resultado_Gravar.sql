/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Resultado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço, ao terminar um comando capturado:
                grava CONCLUIDO (@Sucesso = 1) ou ERRO, o código de saída e a
                saída do comando (o serviço tira senhas e chaves antes de
                mandar). Só aceita pedido em EXECUTANDO.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Resultado_Gravar @IdPedido = 1, @Sucesso = 1, @CodigoSaida = 0, @Saida = N'ok';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Resultado_Gravar]
    @IdPedido     BIGINT,
    @Sucesso      BIT,
    @CodigoSaida  INT           = NULL,
    @Saida        NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Resultado_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Gravação';
    DECLARE @Linhas     INT;

    BEGIN TRY
        UPDATE f
           SET f.STATUS       = CASE WHEN ISNULL(@Sucesso, 0) = 1 THEN 'CONCLUIDO' ELSE 'ERRO' END,
               f.DT_FIM       = SYSDATETIME(),
               f.CODIGO_SAIDA = @CodigoSaida,
               f.SAIDA        = ISNULL(@Saida, N'')
        FROM SIS.Comando_Fila f
        WHERE f.ID_PEDIDO = @IdPedido AND f.STATUS = 'EXECUTANDO';
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Resultado gravado.' ELSE N'O pedido não está em execução.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o resultado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END CATCH;
END;
GO
