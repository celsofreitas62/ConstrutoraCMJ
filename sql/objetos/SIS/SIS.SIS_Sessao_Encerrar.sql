/*******************************************************************************
  Objeto      : [SIS].[SIS_Sessao_Encerrar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Encerra a sessão do token (botão "Sair"). Pode ser chamada de
                novo sem erro: sessão já encerrada continua como estava.
                @Motivo: LOGOUT (padrão) ou ADMIN.
                Devolve 1 linha: SUCESSO, MENSAGEM.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Sessao_Encerrar]
    @TokenHash  VARBINARY(32),
    @Motivo     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Sessao_Encerrar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Encerramento';

    BEGIN TRY
        SET @Motivo = UPPER(ISNULL(NULLIF(LTRIM(RTRIM(@Motivo)), ''), 'LOGOUT'));
        IF @Motivo NOT IN ('LOGOUT', 'ADMIN') SET @Motivo = 'LOGOUT';

        UPDATE s SET s.DT_FIM = SYSDATETIME(), s.MOTIVO_FIM = @Motivo
        FROM SIS.Sessao s
        WHERE s.TOKEN_HASH = @TokenHash
          AND s.DT_FIM IS NULL;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Sessão encerrada.' AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível encerrar a sessão. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO
