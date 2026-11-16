/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Resultado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço, depois de tentar enviar um e-mail
                capturado (PADRAO_EMAIL regras 3 a 5).
                @Resultado:
                  ENVIADO         : STATUS = ENVIADO.
                  ERRO_TEMPORARIO : volta para PENDENTE e espera 1, 5, 15 e
                                    depois 60 min a cada tentativa; passou de
                                    EMAIL_TENTATIVAS_MAX, vira ERRO.
                  ERRO_PERMANENTE : ERRO direto (endereço inválido, anexo
                                    que não existe, recusa definitiva).
                Toda tentativa vai para SIS.Email_Log.
                E-mail que terminou em ERRO gera um alerta técnico para o
                parâmetro EMAIL_ADMIN_ALERTA (se preenchido), uma vez por
                e-mail (CHAVE_ORIGEM 'ALERTA_EMAIL:<id>'). Alerta que falha
                não gera outro alerta.
                Devolve SUCESSO, MENSAGEM, ID (ID = ID_EMAIL).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Resultado_Gravar @IdEmail = 1, @Resultado = 'ENVIADO', @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Resultado_Gravar]
    @IdEmail    BIGINT,
    @Resultado  VARCHAR(20),
    @Mensagem   NVARCHAR(1000) = NULL,
    @Servidor   NVARCHAR(128)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Email_Resultado_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Status      VARCHAR(12);
    DECLARE @Tentativas  INT;
    DECLARE @Tipo        VARCHAR(30);
    DECLARE @Assunto     NVARCHAR(400);
    DECLARE @Para        NVARCHAR(2000);
    DECLARE @Max         INT           = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_TENTATIVAS_MAX'), 5);
    DECLARE @Novo        VARCHAR(12);
    DECLARE @Espera      INT;
    DECLARE @Agora       DATETIME2(0)  = SYSDATETIME();
    DECLARE @Alerta      NVARCHAR(256);
    DECLARE @Corpo       NVARCHAR(MAX);
    DECLARE @IdAlerta    BIGINT;
    DECLARE @Chave       NVARCHAR(200);

    BEGIN TRY
        SET @Resultado = UPPER(LTRIM(RTRIM(ISNULL(@Resultado, ''))));
        SET @Mensagem  = LEFT(ISNULL(@Mensagem, N''), 1000);
        IF @Max < 1 SET @Max = 1;

        IF @Resultado NOT IN ('ENVIADO', 'ERRO_TEMPORARIO', 'ERRO_PERMANENTE')
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Resultado inválido.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        BEGIN TRANSACTION;

        SELECT @Status = f.STATUS, @Tentativas = f.TENTATIVAS, @Tipo = f.TIPO, @Assunto = f.ASSUNTO, @Para = f.PARA
        FROM SIS.Email_Fila f WITH (UPDLOCK, ROWLOCK)
        WHERE f.ID_EMAIL = @IdEmail;

        IF @Status IS NULL OR @Status <> 'PROCESSANDO'
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Status IS NULL THEN N'E-mail não encontrado.' ELSE N'O e-mail não está em processamento (situação: ' + @Status + N').' END AS NVARCHAR(400)) AS MENSAGEM,
                   @IdEmail AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Novo = CASE WHEN @Resultado = 'ENVIADO' THEN 'ENVIADO'
                         WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Tentativas < @Max THEN 'PENDENTE'
                         ELSE 'ERRO' END;
        SET @Espera = CASE WHEN @Tentativas <= 1 THEN 1 WHEN @Tentativas = 2 THEN 5 WHEN @Tentativas = 3 THEN 15 ELSE 60 END;

        UPDATE f
           SET f.STATUS            = @Novo,
               f.DT_ENVIO          = CASE WHEN @Novo = 'ENVIADO' THEN @Agora ELSE f.DT_ENVIO END,
               f.ULTIMO_ERRO       = CASE WHEN @Novo = 'ENVIADO' THEN N'' ELSE @Mensagem END,
               f.PROXIMA_TENTATIVA = CASE WHEN @Novo = 'PENDENTE' THEN DATEADD(MINUTE, @Espera, @Agora) ELSE f.PROXIMA_TENTATIVA END,
               f.SERVIDOR          = CASE WHEN ISNULL(@Servidor, N'') <> N'' THEN LEFT(@Servidor, 128) ELSE f.SERVIDOR END,
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = N'sistema'
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, SERVIDOR, USUARIO)
        VALUES (@IdEmail, @Tentativas,
                CASE WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Novo = 'ERRO' THEN 'ERRO_PERMANENTE' ELSE @Resultado END,
                CASE WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Novo = 'ERRO' THEN LEFT(N'Limite de tentativas atingido. ' + @Mensagem, 1000) ELSE @Mensagem END,
                LEFT(ISNULL(@Servidor, N''), 128), N'sistema');

        -- Alerta técnico (uma vez por e-mail; alerta não gera alerta)
        SET @EtapaAtual = 'Alerta';
        SET @Alerta = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
        IF @Novo = 'ERRO' AND @Tipo <> 'ALERTA_EMAIL' AND @Alerta <> N''
        BEGIN
            SET @Chave = N'ALERTA_EMAIL:' + CAST(@IdEmail AS NVARCHAR(20));
            SET @Corpo = SIS.fn_SIS_Email_HTML(
                             N'Falha no envio de e-mail', 'ALERTA',
                             N'<p>Um e-mail do sistema não pôde ser enviado e foi marcado como erro.</p>'
                           + N'<table style="border-collapse:collapse;font-size:13px;">'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Número</td><td style="padding:4px 8px;">' + CAST(@IdEmail AS NVARCHAR(20)) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Tipo</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Tipo) + N'</td></tr>'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Assunto</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Assunto) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Para</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Para) + N'</td></tr>'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Tentativas</td><td style="padding:4px 8px;">' + CAST(@Tentativas AS NVARCHAR(10)) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Erro</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Mensagem) + N'</td></tr>'
                           + N'</table>'
                           + N'<p>Para reenviar, use a tela Sistema &gt; E-mails &gt; E-mails enviados.</p>',
                             @NomeProc, '', 0);

            EXEC SIS.SIS_Email_Enfileirar
                 @Para = @Alerta,
                 @Assunto = N'SistemaCMJ - FALHA no envio de e-mail',
                 @CorpoHTML = @Corpo,
                 @Tipo = 'ALERTA_EMAIL',
                 @Origem = @NomeProc,
                 @ChaveOrigem = @Chave,
                 @IdEmail = @IdAlerta OUTPUT;
        END;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE @Novo WHEN 'ENVIADO'  THEN N'Enviado.'
                               WHEN 'PENDENTE' THEN N'Nova tentativa em ' + CAST(@Espera AS NVARCHAR(5)) + N' min.'
                               ELSE N'Marcado como erro.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o resultado do envio. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
    END CATCH;
END;
GO
