/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Pendencia_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - inclui (@IdLancamentoPendencia NULL) ou altera uma
                pendência manual do lançamento: tipo, parcela (opcional),
                observação, responsável e previsão. @Ativo = 0: desativa a
                pendência lançada por engano (não conta mais em lugar
                nenhum; o histórico guarda).
                Regras: lançamento ativo e fora da lixeira; tipo ativo e que
                vale para o tipo do lançamento (a pagar / a receber); parcela
                do próprio lançamento; responsável = usuário ativo; uma só
                pendência aberta do mesmo tipo por lançamento e parcela;
                pendência resolvida não é alterada (reabrir antes).
                Permissão: PENDENCIA em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = 2, @IdLancamento = 1, @IdPendenciaTipo = 1, @Observacao = N'NF 123';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Pendencia_Gravar]
    @IdUsuario              INT,
    @IdLancamentoPendencia  BIGINT          = NULL,
    @IdLancamento           BIGINT,
    @IdParcela              BIGINT          = NULL,
    @IdPendenciaTipo        INT,
    @Observacao             NVARCHAR(1000)  = NULL,
    @IdUsuarioResponsavel   INT             = NULL,
    @DtPrevisao             DATE            = NULL,
    @Ativo                  BIT             = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Pendencia_Gravar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Validação';
    DECLARE @Recusa        NVARCHAR(400) = N'';
    DECLARE @Usuario       NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @TipoLanc      CHAR(1);
    DECLARE @SituacaoLanc  VARCHAR(10);
    DECLARE @AplicaA       CHAR(1);
    DECLARE @TipoAtivo     BIT;
    DECLARE @TipoAtual     INT;
    DECLARE @LancAtual     BIGINT;
    DECLARE @SituacaoAtual VARCHAR(10);
    DECLARE @AtivoAtual    BIT;
    DECLARE @Linhas        INT;

    BEGIN TRY
        SET @Observacao = LTRIM(RTRIM(ISNULL(@Observacao, N'')));
        SET @Ativo      = ISNULL(@Ativo, 1);
        IF @IdUsuarioResponsavel = 0 SET @IdUsuarioResponsavel = NULL;
        IF @IdParcela = 0 SET @IdParcela = NULL;

        IF @IdLancamentoPendencia IS NOT NULL
            SELECT @LancAtual = lp.ID_LANCAMENTO, @SituacaoAtual = lp.SITUACAO, @AtivoAtual = lp.ATIVO, @TipoAtual = lp.ID_PENDENCIA_TIPO
            FROM FIN.Lancamento_Pendencia lp WHERE lp.ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia;

        IF @IdLancamentoPendencia IS NOT NULL AND @IdLancamento IS NULL
            SET @IdLancamento = @LancAtual;

        SELECT @TipoLanc = l.TIPO, @SituacaoLanc = l.SITUACAO FROM FIN.Lancamento l WHERE l.ID_LANCAMENTO = @IdLancamento;
        SELECT @AplicaA = t.APLICA_A, @TipoAtivo = CASE WHEN t.ATIVO = 1 AND t.DT_EXCLUSAO IS NULL THEN 1 ELSE 0 END
        FROM FIN.Pendencia_Tipo t WHERE t.ID_PENDENCIA_TIPO = @IdPendenciaTipo;

        IF @TipoLanc IS NULL
            SET @Recusa = N'Lançamento não encontrado.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @TipoLanc WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'PENDENCIA') = 0
            SET @Recusa = N'Você não tem permissão para lançar ou alterar pendências.';
        IF @Recusa = N'' AND @IdLancamentoPendencia IS NOT NULL AND (@LancAtual IS NULL OR @LancAtual <> @IdLancamento)
            SET @Recusa = N'Pendência não encontrada neste lançamento.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento) = 1
            SET @Recusa = N'O lançamento está na lixeira.';
        IF @Recusa = N'' AND @IdLancamentoPendencia IS NULL AND @SituacaoLanc = 'CANCELADO'
            SET @Recusa = N'O lançamento está cancelado.';
        IF @Recusa = N'' AND @IdLancamentoPendencia IS NOT NULL AND @AtivoAtual = 0
            SET @Recusa = N'Esta pendência foi desativada.';
        IF @Recusa = N'' AND @IdLancamentoPendencia IS NOT NULL AND @SituacaoAtual = 'RESOLVIDA'
            SET @Recusa = N'A pendência já está resolvida: reabra-a antes de alterar.';

        IF @Recusa = N'' AND @Ativo = 1
        BEGIN
            IF @AplicaA IS NULL
                SET @Recusa = N'Escolha o tipo da pendência.';
            IF @Recusa = N'' AND @TipoAtivo = 0 AND ISNULL(@TipoAtual, 0) <> @IdPendenciaTipo
                SET @Recusa = N'Este tipo de pendência está desativado.';
            IF @Recusa = N'' AND @AplicaA NOT IN ('A', @TipoLanc)
                SET @Recusa = CASE @TipoLanc WHEN 'P' THEN N'Este tipo de pendência vale só para contas a receber.'
                                             ELSE N'Este tipo de pendência vale só para contas a pagar.' END;
            IF @Recusa = N'' AND @IdParcela IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdParcela AND p.ID_LANCAMENTO = @IdLancamento)
                SET @Recusa = N'A parcela escolhida não é deste lançamento.';
            IF @Recusa = N'' AND @IdUsuarioResponsavel IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdUsuarioResponsavel AND u.ATIVO = 1)
                SET @Recusa = N'O responsável escolhido não é um usuário ativo.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Lancamento_Pendencia x
                                         WHERE x.ID_LANCAMENTO = @IdLancamento AND x.ID_PENDENCIA_TIPO = @IdPendenciaTipo
                                           AND ISNULL(x.ID_PARCELA, 0) = ISNULL(@IdParcela, 0)
                                           AND x.SITUACAO = 'ABERTA' AND x.ATIVO = 1
                                           AND x.ID_LANCAMENTO_PENDENCIA <> ISNULL(@IdLancamentoPendencia, 0))
                SET @Recusa = N'Já existe uma pendência aberta deste tipo neste lançamento' + CASE WHEN @IdParcela IS NULL THEN N'.' ELSE N' e parcela.' END;
        END;

        IF @Recusa = N'' AND @Ativo = 0 AND @IdLancamentoPendencia IS NULL
            SET @Recusa = N'Pendência não encontrada.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdLancamentoPendencia IS NULL
        BEGIN
            INSERT INTO FIN.Lancamento_Pendencia (ID_LANCAMENTO, ID_PARCELA, ID_PENDENCIA_TIPO, OBSERVACAO, ID_USUARIO_RESPONSAVEL, DT_PREVISAO,
                                                  SITUACAO, ORIGEM, ATIVO, USUARIO_CRIACAO)
            VALUES (@IdLancamento, @IdParcela, @IdPendenciaTipo, @Observacao, @IdUsuarioResponsavel, @DtPrevisao,
                    'ABERTA', 'MANUAL', 1, ISNULL(@Usuario, N''));
            SET @IdLancamentoPendencia = SCOPE_IDENTITY();
            SET @Linhas = 1;
        END
        ELSE IF @Ativo = 0
        BEGIN
            UPDATE FIN.Lancamento_Pendencia
               SET ATIVO = 0, DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
             WHERE ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia AND ATIVO = 1 AND SITUACAO = 'ABERTA';
            SET @Linhas = @@ROWCOUNT;
        END
        ELSE
        BEGIN
            UPDATE FIN.Lancamento_Pendencia
               SET ID_PARCELA = @IdParcela, ID_PENDENCIA_TIPO = @IdPendenciaTipo, OBSERVACAO = @Observacao,
                   ID_USUARIO_RESPONSAVEL = @IdUsuarioResponsavel, DT_PREVISAO = @DtPrevisao,
                   DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
             WHERE ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia AND ATIVO = 1 AND SITUACAO = 'ABERTA';
            SET @Linhas = @@ROWCOUNT;
        END;

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas <> 1 THEN N'A pendência foi alterada por outra pessoa. Abra a ficha de novo.'
                         WHEN @Ativo = 0 THEN N'Pendência desativada.'
                         ELSE N'Pendência gravada.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamentoPendencia AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a pendência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
    END CATCH;
END;
GO
