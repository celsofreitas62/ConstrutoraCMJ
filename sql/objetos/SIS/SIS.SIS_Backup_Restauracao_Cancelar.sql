/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Cancelar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Cancela um pedido de restauração que ainda está aguardando
                (PENDENTE), antes de a tarefa do Windows começar (tela
                Sistema > Backups, SIS_BACKUP, ação RESTAURAR). Depois de
                EXECUTANDO não dá mais para cancelar.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_RESTAURACAO.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Restauracao_Cancelar @IdUsuario = 1, @IdRestauracao = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Cancelar]
    @IdUsuario      INT,
    @IdRestauracao  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Cancelar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Linhas     INT;
    DECLARE @Login      NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'RESTAURAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para restaurar backup.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        SELECT @Login = u.LOGIN FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario;

        SET @EtapaAtual = 'Gravação';
        UPDATE r
           SET r.SITUACAO          = 'CANCELADO',
               r.DT_FIM            = SYSDATETIME(),
               r.MENSAGEM          = LEFT(N'Cancelado por ' + ISNULL(@Login, N'') + N' antes de começar.', 2000),
               r.DT_ALTERACAO      = SYSDATETIME(),
               r.USUARIO_ALTERACAO = ISNULL(@Login, N'')
        FROM SIS.Backup_Restauracao r
        WHERE r.ID_RESTAURACAO = @IdRestauracao
          AND r.SITUACAO = 'PENDENTE';
        SET @Linhas = @@ROWCOUNT;

        IF @Linhas = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(N'Este pedido não está mais aguardando (já começou, terminou ou foi cancelado). Atualize a lista.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Pedido de restauração cancelado.' AS NVARCHAR(400)) AS MENSAGEM, @IdRestauracao AS ID_RESTAURACAO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível cancelar o pedido. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_RESTAURACAO;
    END CATCH;
END;
GO
