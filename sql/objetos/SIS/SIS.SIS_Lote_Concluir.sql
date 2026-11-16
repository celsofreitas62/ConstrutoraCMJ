/*******************************************************************************
  Objeto      : [SIS].[SIS_Lote_Concluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Fecha o lote aberto por SIS_Lote_Gerar: grava a quantidade de
                registros gerados e tira o lote do SESSION_CONTEXT (o que for
                gravado depois não leva mais esse número). Uso interno, dentro
                da transação do processo. Sem result set; erro: THROW.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lote_Concluir @IdLote = 1, @QtdRegistros = 30;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lote_Concluir]
    @IdLote        BIGINT,
    @QtdRegistros  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lote_Concluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Gravação';
    DECLARE @Nulo       BIGINT;

    BEGIN TRY
        UPDATE l
           SET l.QTD_REGISTROS = ISNULL(@QtdRegistros, 0)
        FROM SIS.Lote l
        WHERE l.ID_LOTE = @IdLote
          AND l.QTD_REGISTROS <> ISNULL(@QtdRegistros, 0);

        IF TRY_CONVERT(BIGINT, SESSION_CONTEXT(N'ID_LOTE')) = @IdLote
            EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = @Nulo;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = 1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
