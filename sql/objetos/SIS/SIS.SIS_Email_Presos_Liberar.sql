/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Presos_Liberar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Rotina automática (SIS.Rotina EMAIL_PRESOS). Um e-mail que
                ficou em PROCESSANDO mais que EMAIL_MINUTOS_PRESO minutos
                (o serviço caiu no meio do envio) volta para PENDENTE, ou vai
                para ERRO se já gastou todas as tentativas. Registra no
                SIS.Email_Log (LIBERADO). Sem parâmetro e sem retorno, como
                toda rotina da agenda.
                Pode repetir um envio se o serviço caiu depois de enviar e
                antes de gravar o resultado (raro; preferível a perder o
                e-mail).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Presos_Liberar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Presos_Liberar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Presos_Liberar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Parâmetros';
    DECLARE @Minutos    INT;
    DECLARE @Max        INT;
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Soltos     TABLE (ID_EMAIL BIGINT, TENTATIVAS INT, STATUS VARCHAR(12));

    BEGIN TRY
        SET @Minutos = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_MINUTOS_PRESO'), 15);
        SET @Max     = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_TENTATIVAS_MAX'), 5);
        IF @Minutos < 5 SET @Minutos = 5;
        IF @Max < 1 SET @Max = 1;

        SET @EtapaAtual = 'Liberação';
        BEGIN TRANSACTION;

        UPDATE f
           SET f.STATUS            = CASE WHEN f.TENTATIVAS >= @Max THEN 'ERRO' ELSE 'PENDENTE' END,
               f.PROXIMA_TENTATIVA = @Agora,
               f.ULTIMO_ERRO       = N'Ficou preso em processamento (o serviço parou no meio do envio).',
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = N'sistema'
        OUTPUT inserted.ID_EMAIL, inserted.TENTATIVAS, inserted.STATUS INTO @Soltos (ID_EMAIL, TENTATIVAS, STATUS)
        FROM SIS.Email_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE f.STATUS = 'PROCESSANDO'
          AND f.DT_CAPTURA < DATEADD(MINUTE, -@Minutos, @Agora);

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, USUARIO)
        SELECT s.ID_EMAIL, s.TENTATIVAS, 'LIBERADO',
               CASE WHEN s.STATUS = 'ERRO' THEN N'Preso em processamento; tentativas esgotadas: marcado como erro.'
                    ELSE N'Preso em processamento há mais de ' + CAST(@Minutos AS NVARCHAR(10)) + N' min: volta para a fila.' END,
               N'sistema'
        FROM @Soltos s;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
