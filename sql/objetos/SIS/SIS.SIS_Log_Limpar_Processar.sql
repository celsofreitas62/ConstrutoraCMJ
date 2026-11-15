/*******************************************************************************
  Objeto      : [SIS].[SIS_Log_Limpar_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Rotina diária (agenda das rotinas, etapa 02d): apaga do
                SIS.Log_Passo o que for mais antigo que LOG_PASSO_DIAS_RETENCAO
                (mínimo de segurança: 7 dias), em blocos de 5.000 linhas para
                não segurar a tabela.
                SIS.Log_Erro NÃO é apagado por esta rotina.
                Automação: em erro, registra em SIS.Log_Erro e relança.
                Devolve 1 linha: SUCESSO, MENSAGEM, QTD_EXCLUIDA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Log_Limpar_Processar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Log_Limpar_Processar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Log_Limpar_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Parâmetros';
    DECLARE @Dias       INT;
    DECLARE @Corte      DATETIME2(0);
    DECLARE @Bloco      INT           = 1;
    DECLARE @Total      INT           = 0;

    BEGIN TRY
        SET @Dias = SIS.fn_SIS_Parametro_Inteiro('LOG_PASSO_DIAS_RETENCAO');
        IF @Dias < 7 SET @Dias = 7;
        SET @Corte = DATEADD(DAY, -@Dias, SYSDATETIME());

        SET @EtapaAtual = 'Limpeza do Log_Passo';
        WHILE @Bloco > 0
        BEGIN
            DELETE TOP (5000) lp
            FROM SIS.Log_Passo lp
            WHERE lp.DT_PASSO < @Corte;

            SET @Bloco = @@ROWCOUNT;
            SET @Total = @Total + @Bloco;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Log de passos: ' + CONVERT(NVARCHAR(20), @Total) + N' linha(s) com mais de ' + CONVERT(NVARCHAR(10), @Dias) + N' dias excluída(s).' AS NVARCHAR(400)) AS MENSAGEM,
               @Total AS QTD_EXCLUIDA;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
