/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Cancelar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Cancela um pedido de comando que ainda não começou
                (PENDENTE). Comando em execução não é interrompido por aqui.
                Permissão: CANCELAR em SIS_INSTALACAO. Devolve SUCESSO,
                MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Cancelar @IdUsuario = 2, @IdPedido = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Cancelar]
    @IdUsuario  INT,
    @IdPedido   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Cancelar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Linhas     INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'CANCELAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para cancelar comandos.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE f
           SET f.STATUS               = 'CANCELADO',
               f.DT_CANCELAMENTO      = SYSDATETIME(),
               f.USUARIO_CANCELAMENTO = SIS.fn_SIS_Usuario_Login(@IdUsuario)
        FROM SIS.Comando_Fila f
        WHERE f.ID_PEDIDO = @IdPedido AND f.STATUS = 'PENDENTE';
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Pedido cancelado.' ELSE N'Só pedido pendente (que ainda não começou) pode ser cancelado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível cancelar. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END CATCH;
END;
GO
