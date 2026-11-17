/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Descartar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Descarta uma prévia (nada é enviado). Permissão: APROVAR em
                SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Descartar]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Edicao_Descartar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'APROVAR') = 0
            SET @Recusa = N'Você não tem permissão para descartar comunicados.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Edicao e WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao AND e.SITUACAO = 'PREVIA')
            SET @Recusa = N'Só uma prévia pendente pode ser descartada.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        UPDATE SIS.Comunicado_Edicao
           SET SITUACAO = 'DESCARTADA', DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_COMUNICADO_EDICAO = @IdEdicao AND SITUACAO = 'PREVIA';

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia descartada. Nada foi enviado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível descartar a prévia. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
