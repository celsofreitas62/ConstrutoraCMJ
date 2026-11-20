/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Resultado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Grava o resultado (OK ou ERRO) de um pedido de restauração.
                Chamada SÓ pelo script do servidor (e pela Capturar); o login
                da API não pode executar (DENY).
                Depois da restauração o banco volta ao passado e o pedido pode
                não existir mais nele (ou estar como PENDENTE): por isso o
                script manda todos os dados do pedido, e esta rotina grava de
                novo a linha com o MESMO ID (IDENTITY_INSERT), ou atualiza a
                que existe. Os dados que vierem vazios ficam como estão.
                @ArquivoBackup: o backup escolhido (TIPO_PONTO BACKUP) é
                localizado pelo arquivo, porque o ID dele pode ter mudado
                quando o script registrou de novo os backups que faltavam.
                Avisa por e-mail o EMAIL_ADMIN_ALERTA e quem pediu.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Resultado]
    @IdRestauracao     INT,
    @Situacao          VARCHAR(12),
    @Mensagem          NVARCHAR(2000) = N'',
    @TipoPonto         VARCHAR(10)    = NULL,
    @ArquivoBackup     NVARCHAR(400)  = NULL,
    @DtPonto           DATETIME2(0)   = NULL,
    @Motivo            NVARCHAR(400)  = NULL,
    @IdUsuarioPedido   INT            = NULL,
    @UsuarioPedido     NVARCHAR(100)  = NULL,
    @DtPedido          DATETIME2(0)   = NULL,
    @DtInicio          DATETIME2(0)   = NULL,
    @Plano             NVARCHAR(4000) = NULL,
    @ArquivoSeguranca  NVARCHAR(400)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Resultado]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @IdBackup   BIGINT;
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Para NVARCHAR(400), @EmailPedido NVARCHAR(200), @Corpo NVARCHAR(MAX), @Chave NVARCHAR(200), @IdEmail BIGINT;
    DECLARE @Titulo NVARCHAR(200), @Texto NVARCHAR(MAX);
    DECLARE @r TABLE (TIPO_PONTO VARCHAR(10), DT_PONTO DATETIME2(0), ID_BACKUP BIGINT, MOTIVO NVARCHAR(400),
                      ID_USUARIO_PEDIDO INT, USUARIO_PEDIDO NVARCHAR(100), ARQUIVO_SEGURANCA NVARCHAR(400));

    BEGIN TRY
        IF @IdRestauracao IS NULL OR ISNULL(@Situacao, '') NOT IN ('OK', 'ERRO')
            THROW 50000, N'Informe o pedido e a situação (OK ou ERRO).', 1;

        IF NULLIF(LTRIM(RTRIM(ISNULL(@ArquivoBackup, N''))), N'') IS NOT NULL
            SELECT TOP (1) @IdBackup = b.ID_BACKUP
            FROM SIS.Backup_Execucao b
            WHERE b.ARQUIVO = @ArquivoBackup AND b.TIPO IN ('COMPLETO', 'SEGURANCA')
            ORDER BY b.ID_BACKUP DESC;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF NOT EXISTS (SELECT 1 FROM SIS.Backup_Restauracao r WITH (UPDLOCK, HOLDLOCK) WHERE r.ID_RESTAURACAO = @IdRestauracao)
            BEGIN
                IF ISNULL(@TipoPonto, '') NOT IN ('BACKUP', 'DATA_HORA')
                   OR (@TipoPonto = 'BACKUP' AND @IdBackup IS NULL)
                   OR (@TipoPonto = 'DATA_HORA' AND @DtPonto IS NULL)
                    THROW 50000, N'Pedido não existe no banco restaurado e faltam os dados para gravar de novo (tipo, backup ou dia e hora).', 1;

                SET IDENTITY_INSERT SIS.Backup_Restauracao ON;
                INSERT INTO SIS.Backup_Restauracao (ID_RESTAURACAO, TIPO_PONTO, ID_BACKUP, DT_PONTO, MOTIVO, SITUACAO, ID_USUARIO_PEDIDO, USUARIO_PEDIDO,
                                                    DT_PEDIDO, DT_INICIO, DT_FIM, PLANO, ARQUIVO_SEGURANCA, MENSAGEM, USUARIO_CRIACAO)
                VALUES (@IdRestauracao, @TipoPonto, CASE WHEN @TipoPonto = 'BACKUP' THEN @IdBackup END, CASE WHEN @TipoPonto = 'DATA_HORA' THEN @DtPonto END,
                        ISNULL(@Motivo, N''), @Situacao, ISNULL(@IdUsuarioPedido, 0), ISNULL(@UsuarioPedido, N''),
                        ISNULL(@DtPedido, @Agora), ISNULL(@DtInicio, @Agora), @Agora, ISNULL(@Plano, N''), ISNULL(@ArquivoSeguranca, N''),
                        LEFT(ISNULL(@Mensagem, N''), 2000), N'restauracao');
                SET IDENTITY_INSERT SIS.Backup_Restauracao OFF;
            END;

            UPDATE r
               SET r.SITUACAO          = @Situacao,
                   r.ID_BACKUP         = CASE WHEN r.TIPO_PONTO = 'BACKUP' THEN ISNULL(@IdBackup, r.ID_BACKUP) ELSE r.ID_BACKUP END,
                   r.DT_INICIO         = ISNULL(r.DT_INICIO, ISNULL(@DtInicio, @Agora)),
                   r.DT_FIM            = @Agora,
                   r.PLANO             = CASE WHEN ISNULL(@Plano, N'') <> N'' THEN @Plano ELSE r.PLANO END,
                   r.ARQUIVO_SEGURANCA = CASE WHEN ISNULL(@ArquivoSeguranca, N'') <> N'' THEN @ArquivoSeguranca ELSE r.ARQUIVO_SEGURANCA END,
                   r.MENSAGEM          = LEFT(ISNULL(@Mensagem, N''), 2000),
                   r.DT_ALTERACAO      = @Agora,
                   r.USUARIO_ALTERACAO = N'restauracao'
            OUTPUT inserted.TIPO_PONTO, inserted.DT_PONTO, inserted.ID_BACKUP, inserted.MOTIVO, inserted.ID_USUARIO_PEDIDO, inserted.USUARIO_PEDIDO, inserted.ARQUIVO_SEGURANCA
            INTO @r
            FROM SIS.Backup_Restauracao r
            WHERE r.ID_RESTAURACAO = @IdRestauracao;

        COMMIT TRANSACTION;

        SET @EtapaAtual = 'Aviso por e-mail';
        BEGIN TRY
            SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
            SELECT @EmailPedido = LTRIM(RTRIM(ISNULL(u.EMAIL, N'')))
            FROM @r x INNER JOIN SIS.Usuario u ON u.ID_USUARIO = x.ID_USUARIO_PEDIDO;
            IF ISNULL(@EmailPedido, N'') <> N'' AND CHARINDEX(@EmailPedido, @Para) = 0
                SET @Para = CASE WHEN @Para = N'' THEN @EmailPedido ELSE @Para + N';' + @EmailPedido END;

            IF @Para <> N''
            BEGIN
                SET @Titulo = CASE WHEN @Situacao = 'OK' THEN N'Restauração do banco concluída' ELSE N'Falha na restauração do banco' END;
                SELECT @Texto = N'<p>Pedido nº ' + CONVERT(NVARCHAR(10), @IdRestauracao) + N', feito por <b>' + SIS.fn_SIS_Texto_HTML(ISNULL(x.USUARIO_PEDIDO, N''))
                              + N'</b>, banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b>.</p>'
                              + N'<p>Voltar para: <b>' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(ISNULL(x.DT_PONTO, b.DT_FIM)), N'') + N'</b>.</p>'
                              + N'<p>Motivo: ' + SIS.fn_SIS_Texto_HTML(ISNULL(x.MOTIVO, N'')) + N'</p>'
                              + N'<p>Resultado: ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Mensagem, N'')) + N'</p>'
                              + CASE WHEN ISNULL(x.ARQUIVO_SEGURANCA, N'') <> N''
                                     THEN N'<p>Backup de segurança feito antes (para desfazer, se preciso): ' + SIS.fn_SIS_Texto_HTML(x.ARQUIVO_SEGURANCA) + N'</p>' ELSE N'' END
                FROM @r x
                LEFT JOIN SIS.Backup_Execucao b ON b.ID_BACKUP = x.ID_BACKUP;

                SET @Corpo = SIS.fn_SIS_Email_HTML(@Titulo, 'ALERTA', ISNULL(@Texto, N''), @NomeProc, NULL, 0);
                SET @Chave = N'RESTAURACAO_RESULTADO_' + CONVERT(NVARCHAR(10), @IdRestauracao) + N'_' + @Situacao;
                SET @Titulo = CASE WHEN @Situacao = 'OK' THEN N'AVISO: restauração do banco concluída' ELSE N'ALERTA: falha na restauração do banco' END;
                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @Titulo, @CorpoHTML = @Corpo,
                     @Tipo = 'ALERTA', @Origem = @NomeProc, @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
            END;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> -1
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;

        SELECT @IdRestauracao AS ID_RESTAURACAO, @Situacao AS SITUACAO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
