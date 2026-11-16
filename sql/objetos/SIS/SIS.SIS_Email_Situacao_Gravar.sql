/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Situacao_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "E-mails enviados":
                @Acao = 'REENVIAR': e-mail em ERRO ou CANCELADO volta para a
                        fila (PENDENTE, tentativas zeradas). Permissão
                        ENVIAR. E-mail já enviado não é reenviado por aqui
                        (evita mandar duas vezes ao cliente).
                @Acao = 'CANCELAR': e-mail PENDENTE ou em ERRO não sai mais.
                        Permissão CANCELAR. @Motivo obrigatório.
                Tudo fica no SIS.Email_Log com o usuário.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Situacao_Gravar @IdUsuario = 2, @IdEmail = 1, @Acao = 'REENVIAR';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Situacao_Gravar]
    @IdUsuario  INT,
    @IdEmail    BIGINT,
    @Acao       VARCHAR(10),
    @Motivo     NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Situacao_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Status     VARCHAR(12);
    DECLARE @Tentativas INT;
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();

    BEGIN TRY
        SET @Acao   = UPPER(LTRIM(RTRIM(ISNULL(@Acao, ''))));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF @Acao NOT IN ('REENVIAR', 'CANCELAR')
            SET @Recusa = N'Ação inválida.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', CASE @Acao WHEN 'REENVIAR' THEN 'ENVIAR' ELSE 'CANCELAR' END) = 0
            SET @Recusa = CASE @Acao WHEN 'REENVIAR' THEN N'Você não tem permissão para reenviar e-mails.' ELSE N'Você não tem permissão para cancelar e-mails.' END;
        IF @Recusa = N'' AND @Acao = 'CANCELAR' AND @Motivo = N''
            SET @Recusa = N'Informe o motivo do cancelamento.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        SELECT @Status = f.STATUS, @Tentativas = f.TENTATIVAS
        FROM SIS.Email_Fila f WITH (UPDLOCK, ROWLOCK)
        WHERE f.ID_EMAIL = @IdEmail;

        SET @Recusa = CASE WHEN @Status IS NULL THEN N'E-mail não encontrado.'
                           WHEN @Acao = 'REENVIAR' AND @Status NOT IN ('ERRO', 'CANCELADO')
                                THEN N'Só e-mail com erro ou cancelado pode ser reenviado (situação: ' + @Status + N').'
                           WHEN @Acao = 'CANCELAR' AND @Status NOT IN ('PENDENTE', 'ERRO')
                                THEN N'Só e-mail pendente ou com erro pode ser cancelado (situação: ' + @Status + N').'
                           ELSE N'' END;

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        UPDATE f
           SET f.STATUS            = CASE @Acao WHEN 'REENVIAR' THEN 'PENDENTE' ELSE 'CANCELADO' END,
               f.TENTATIVAS        = CASE @Acao WHEN 'REENVIAR' THEN 0 ELSE f.TENTATIVAS END,
               f.PROXIMA_TENTATIVA = CASE @Acao WHEN 'REENVIAR' THEN @Agora ELSE f.PROXIMA_TENTATIVA END,
               f.ULTIMO_ERRO       = CASE @Acao WHEN 'REENVIAR' THEN N'' ELSE f.ULTIMO_ERRO END,
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, USUARIO)
        VALUES (@IdEmail, @Tentativas, CASE @Acao WHEN 'REENVIAR' THEN 'REENVIO' ELSE 'CANCELADO' END,
                CASE @Acao WHEN 'REENVIAR' THEN N'Reenvio pedido pela tela.' ELSE LEFT(N'Cancelado: ' + @Motivo, 1000) END, @Usuario);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE @Acao WHEN 'REENVIAR' THEN N'E-mail colocado de novo na fila.' ELSE N'E-mail cancelado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
    END CATCH;
END;
GO
