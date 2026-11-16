/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Executar_Agora]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botão "Executar agora" da tela "Rotinas automáticas": marca a
                rotina para rodar na próxima volta do agendador (o serviço
                confere a cada minuto). Vale também para rotina desligada
                (roda uma vez). A execução fica registrada como MANUAL, com
                quem pediu.
                Recusa se já está em execução ou se o módulo da rotina está
                fora da licença ou desabilitado.
                Permissão: EXECUTAR em SIS_ROTINA. Devolve SUCESSO, MENSAGEM,
                ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Executar_Agora @IdUsuario = 2, @Codigo = 'EMAIL_PRESOS';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Executar_Agora]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Executar_Agora]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @IdRotina   INT;
    DECLARE @EmExecucao BIT;
    DECLARE @Disponivel BIT;

    BEGIN TRY
        SET @Codigo = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'EXECUTAR') = 0
            SET @Recusa = N'Você não tem permissão para executar rotinas.';

        IF @Recusa = N''
        BEGIN
            SELECT @IdRotina = r.ID_ROTINA, @EmExecucao = r.EM_EXECUCAO,
                   @Disponivel = CASE WHEN m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END
            FROM SIS.Rotina r
            INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
            WHERE r.CODIGO = @Codigo;

            SET @Recusa = CASE WHEN @IdRotina IS NULL THEN N'Rotina não encontrada.'
                               WHEN @EmExecucao = 1 THEN N'A rotina já está em execução.'
                               WHEN @Disponivel = 0 THEN N'O módulo desta rotina está fora da licença ou desabilitado.'
                               ELSE N'' END;
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE r
           SET r.PROXIMA_EXECUCAO = SYSDATETIME(),
               r.SOLICITADA_POR   = SIS.fn_SIS_Usuario_Login(@IdUsuario)
        FROM SIS.Rotina r
        WHERE r.ID_ROTINA = @IdRotina AND r.EM_EXECUCAO = 0;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Pedido registrado: a rotina roda em até 1 minuto.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdRotina AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível registrar o pedido. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
    END CATCH;
END;
GO
