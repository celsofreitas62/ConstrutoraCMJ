/*******************************************************************************
  Objeto      : [SIS].[SIS_Novidades_Marcar_Vista]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Botão "Entendi" do aviso "O que há de novo" (pedido P22):
                grava que o usuário já viu as novidades até a versão instalada
                agora (SIS.Usuario_Novidade). O aviso só volta na próxima
                atualização.
                Devolve 1 linha: SUCESSO, MENSAGEM, VERSAO_VISTA.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Novidades_Marcar_Vista @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Novidades_Marcar_Vista]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Novidades_Marcar_Vista]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Usuário';
    DECLARE @VersaoAtual VARCHAR(20)   = ISNULL(SIS.fn_SIS_Versao_Banco(), '');

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Usuário não identificado. Entre no sistema de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST('' AS VARCHAR(20)) AS VERSAO_VISTA;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;
        UPDATE n
           SET n.VERSAO_VISTA = @VersaoAtual,
               n.DT_VISTA     = SYSDATETIME()
        FROM SIS.Usuario_Novidade n WITH (UPDLOCK, HOLDLOCK)
        WHERE n.ID_USUARIO = @IdUsuario;

        IF @@ROWCOUNT = 0
            INSERT INTO SIS.Usuario_Novidade (ID_USUARIO, VERSAO_VISTA) VALUES (@IdUsuario, @VersaoAtual);
        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Novidades marcadas como vistas.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(@VersaoAtual AS VARCHAR(20)) AS VERSAO_VISTA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível marcar as novidades como vistas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST('' AS VARCHAR(20)) AS VERSAO_VISTA;
    END CATCH;
END;
GO
