/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Solicitar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Registra um pedido de restauração do banco (tela Sistema >
                Backups, SIS_BACKUP, ação RESTAURAR). Não restaura nada: a
                tarefa do Windows "Restauração (pedidos)" confere os pedidos a
                cada minuto e faz a restauração (o login da API não tem
                permissão para restaurar).
                Confirmação forte: a API confere a senha do usuário
                (@SenhaConferida = 1), o usuário escreve RESTAURAR
                (@Confirmacao) e informa o motivo (mínimo no parâmetro
                BACKUP_RESTAURACAO_MOTIVO_MINIMO).
                @TipoPonto BACKUP: volta para o backup completo ou de
                segurança @IdBackup. DATA_HORA: volta para @DtPonto, com o
                último completo antes dele e os backups do log seguintes
                (fn_SIS_Backup_Plano).
                Um pedido em aberto (PENDENTE ou EXECUTANDO) por vez.
                Avisa por e-mail o EMAIL_ADMIN_ALERTA (se preenchido).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_RESTAURACAO.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
    v1.1 (20/11/2026) - Recusa ponto anterior à atualização para a versão atual
                        do banco (fn_SIS_Backup_Limite_Versao): achado no ensaio.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = 1, @TipoPonto = 'DATA_HORA', @DtPonto = '2026-11-20 14:25',
    --      @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Solicitar]
    @IdUsuario       INT,
    @TipoPonto       VARCHAR(10),
    @IdBackup        BIGINT        = NULL,
    @DtPonto         DATETIME2(0)  = NULL,
    @Motivo          NVARCHAR(400) = NULL,
    @Confirmacao     NVARCHAR(20)  = NULL,
    @SenhaConferida  BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Solicitar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @MotivoMin    INT;
    DECLARE @Login        NVARCHAR(100);
    DECLARE @Plano        NVARCHAR(4000) = N'';
    DECLARE @QtdLinhas    INT, @QtdSemArquivo INT, @Alcanca INT;
    DECLARE @DtVolta      DATETIME2(0);
    DECLARE @DtLimite     DATETIME2(0)  = SIS.fn_SIS_Backup_Limite_Versao();
    DECLARE @IdRestauracao INT;
    DECLARE @Para NVARCHAR(400), @Corpo NVARCHAR(MAX), @Chave NVARCHAR(200), @IdEmail BIGINT;

    BEGIN TRY
        SET @TipoPonto = UPPER(LTRIM(RTRIM(ISNULL(@TipoPonto, ''))));
        SET @Motivo    = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @MotivoMin = ISNULL(TRY_CONVERT(INT, SIS.fn_SIS_Parametro('BACKUP_RESTAURACAO_MOTIVO_MINIMO')), 10);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'RESTAURAR') = 0
            SET @Recusa = N'Você não tem permissão para restaurar backup.';
        ELSE IF ISNULL(@SenhaConferida, 0) = 0
            SET @Recusa = N'A senha não confere.';
        ELSE IF UPPER(LTRIM(RTRIM(ISNULL(@Confirmacao, N'')))) <> N'RESTAURAR'
            SET @Recusa = N'Para confirmar, escreva a palavra RESTAURAR.';
        ELSE IF LEN(@Motivo) < @MotivoMin
            SET @Recusa = N'Informe o motivo da restauração (pelo menos ' + CONVERT(NVARCHAR(10), @MotivoMin) + N' letras).';
        ELSE IF @TipoPonto NOT IN ('BACKUP', 'DATA_HORA')
            SET @Recusa = N'Escolha um backup ou um dia e hora para voltar.';
        ELSE IF @TipoPonto = 'BACKUP' AND @IdBackup IS NULL
            SET @Recusa = N'Escolha o backup para voltar.';
        ELSE IF @TipoPonto = 'DATA_HORA' AND @DtPonto IS NULL
            SET @Recusa = N'Informe o dia e a hora para voltar.';
        ELSE IF @TipoPonto = 'DATA_HORA' AND @DtPonto >= SYSDATETIME()
            SET @Recusa = N'O dia e a hora para voltar precisam estar no passado.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        IF @TipoPonto = 'BACKUP' SET @DtPonto = NULL;
        IF @TipoPonto = 'DATA_HORA' SET @IdBackup = NULL;

        SET @EtapaAtual = 'Plano';
        SELECT @QtdLinhas     = COUNT(*),
               @QtdSemArquivo = SUM(CASE WHEN p.ARQUIVO_EXISTE = 0 THEN 1 ELSE 0 END),
               @Alcanca       = MAX(CAST(p.ALCANCA_PONTO AS INT)),
               @DtVolta       = MAX(CASE WHEN p.ORDEM = 0 THEN p.DT_FIM END)
        FROM SIS.fn_SIS_Backup_Plano(@IdBackup, @DtPonto) p;

        SET @Plano = ISNULL(STUFF((SELECT N' | ' + CONVERT(NVARCHAR(10), p.ORDEM) + N': ' + p.ARQUIVO
                                   FROM SIS.fn_SIS_Backup_Plano(@IdBackup, @DtPonto) p
                                   ORDER BY p.ORDEM
                                   FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 3, N''), N'');

        IF ISNULL(@QtdLinhas, 0) = 0
            SET @Recusa = CASE WHEN @TipoPonto = 'BACKUP' THEN N'Backup não encontrado ou não serve para restaurar. Atualize a lista.'
                               ELSE N'Não há backup completo antes desse dia e hora. Escolha um ponto dentro do período mostrado em "Dá para voltar".' END;
        ELSE IF ISNULL(@QtdSemArquivo, 0) > 0
            SET @Recusa = N'Algum arquivo de backup necessário já foi apagado pela limpeza. Escolha um ponto mais recente.';
        ELSE IF ISNULL(@Alcanca, 0) = 0
            SET @Recusa = N'Ainda não há backup de hora em hora depois desse dia e hora. Escolha um ponto até o último backup ou espere o próximo backup de hora em hora.';
        ELSE IF ISNULL(@DtPonto, @DtVolta) < @DtLimite
            SET @Recusa = N'Não dá para voltar para antes de ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@DtLimite), N'') + N', quando o sistema foi atualizado para a versão '
                        + SIS.fn_SIS_Versao_Banco() + N': o banco ficaria numa versão diferente do programa e o sistema pararia.';
        ELSE IF LEN(@Plano) > 3900
            SET @Recusa = N'O ponto escolhido usa backups demais. Escolha um ponto mais perto de um backup completo.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        SELECT @Login = u.LOGIN FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            -- sem ROLLBACK na recusa: nada foi gravado e a rotina pode ser chamada por INSERT ... EXEC (teste)
            IF EXISTS (SELECT 1 FROM SIS.Backup_Restauracao r WITH (UPDLOCK, HOLDLOCK) WHERE r.SITUACAO IN ('PENDENTE', 'EXECUTANDO'))
                SET @Recusa = N'Já existe um pedido de restauração em andamento. Espere terminar ou cancele o pedido que está aguardando.';

            IF @Recusa = N''
            BEGIN
                INSERT INTO SIS.Backup_Restauracao (TIPO_PONTO, ID_BACKUP, DT_PONTO, MOTIVO, SITUACAO, ID_USUARIO_PEDIDO, USUARIO_PEDIDO, PLANO)
                VALUES (@TipoPonto, @IdBackup, @DtPonto, @Motivo, 'PENDENTE', @IdUsuario, ISNULL(@Login, N''), ISNULL(@Plano, N''));
                SET @IdRestauracao = CAST(SCOPE_IDENTITY() AS INT);
            END;

        COMMIT TRANSACTION;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_RESTAURACAO;
            RETURN;
        END;

        SET @EtapaAtual = 'Aviso por e-mail';
        BEGIN TRY
            SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
            IF @Para <> N''
            BEGIN
                SET @Corpo = SIS.fn_SIS_Email_HTML(N'Pedido de restauração do banco', 'ALERTA',
                    N'<p><b>' + SIS.fn_SIS_Texto_HTML(ISNULL(@Login, N'')) + N'</b> pediu para restaurar o banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME())
                    + N'</b>, voltando para <b>' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(ISNULL(@DtPonto, @DtVolta)), N'') + N'</b>.</p>'
                    + N'<p>Motivo: ' + SIS.fn_SIS_Texto_HTML(@Motivo) + N'</p>'
                    + N'<p>Pedido nº ' + CONVERT(NVARCHAR(10), @IdRestauracao) + N'. O sistema fica fora do ar por alguns minutos durante a restauração.</p>',
                    @NomeProc, NULL, 0);
                SET @Chave = N'RESTAURACAO_PEDIDO_' + CONVERT(NVARCHAR(10), @IdRestauracao);
                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: pedido de restauração do banco', @CorpoHTML = @Corpo,
                     @Tipo = 'ALERTA', @Origem = @NomeProc, @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
            END;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> -1
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Pedido de restauração nº ' + CONVERT(NVARCHAR(10), @IdRestauracao)
                    + N' registrado. Em até 1 minuto o sistema sai do ar por alguns minutos para restaurar; depois, entre de novo.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdRestauracao AS ID_RESTAURACAO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível registrar o pedido de restauração. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_RESTAURACAO;
    END CATCH;
END;
GO
