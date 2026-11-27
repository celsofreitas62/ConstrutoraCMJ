/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Caixa_Reabrir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Reabre um fechamento de caixa (etapa 04g2). Só o último
                fechamento da conta (para voltar mais, reabrir um de cada
                vez, do mais novo para o mais antigo). Motivo obrigatório.
                Se o fechamento gravou um AJUSTE, o ajuste é desfeito
                (movimento inverso na mesma data; os dois ficam ESTORNADO),
                para o próximo fechamento partir do saldo real. Ajuste já
                conciliado bloqueia. O registro fica REABERTO com data, quem
                e motivo (nada é apagado).
                @SomenteConferir = 1: prévia (diz se há ajuste a desfazer).
                Permissão: REABRIR em BANCO_CAIXA.
                Devolve SUCESSO, MENSAGEM, ID, VALOR_AJUSTE, PENDENTE, AVISOS.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Caixa_Reabrir @IdUsuario = 2, @IdCaixaFechamento = 1, @Motivo = N'Recebimento esquecido', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Caixa_Reabrir]
    @IdUsuario          INT,
    @IdCaixaFechamento  BIGINT,
    @Motivo             NVARCHAR(400)  = NULL,
    @SomenteConferir    BIT            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[BANCO].[BANCO_Caixa_Reabrir]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @IdConta     INT;
    DECLARE @Data        DATE;
    DECLARE @Situacao    VARCHAR(10);
    DECLARE @IdAjuste    BIGINT;
    DECLARE @ValorAjuste DECIMAL(18,2) = 0;
    DECLARE @AjusteConc  BIT = 0;
    DECLARE @AjusteSit   VARCHAR(10);
    DECLARE @IdLote      BIGINT;
    DECLARE @Linhas      INT;
    DECLARE @Avisos      NVARCHAR(MAX) = N'[]';

    BEGIN TRY
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        SELECT @IdConta = f.ID_CONTA, @Data = f.DT_FECHAMENTO, @Situacao = f.SITUACAO, @IdAjuste = f.ID_MOVIMENTO_AJUSTE
        FROM BANCO.Caixa_Fechamento f WHERE f.ID_CAIXA_FECHAMENTO = @IdCaixaFechamento;
        SELECT @ValorAjuste = m.VALOR, @AjusteConc = m.CONCILIADO, @AjusteSit = m.SITUACAO FROM BANCO.Movimento m WHERE m.ID_MOVIMENTO = @IdAjuste;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CAIXA', 'REABRIR') = 0
            SET @Recusa = N'Você não tem permissão para reabrir o caixa.';
        IF @Recusa = N'' AND @Situacao IS NULL
            SET @Recusa = N'Fechamento não encontrado.';
        IF @Recusa = N'' AND @Situacao = 'REABERTO'
            SET @Recusa = N'Este fechamento já foi reaberto.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM BANCO.Caixa_Fechamento f WHERE f.ID_CONTA = @IdConta AND f.SITUACAO = 'FECHADO' AND f.DT_FECHAMENTO > @Data)
            SET @Recusa = N'Há um fechamento mais novo nesta conta: reabra primeiro o mais novo.';
        IF @Recusa = N'' AND @AjusteConc = 1
            SET @Recusa = N'O ajuste deste fechamento já foi conciliado: desfaça a conciliação antes de reabrir.';
        IF @Recusa = N'' AND @SomenteConferir = 0 AND LEN(@Motivo) < 5
            SET @Recusa = N'Informe o motivo da reabertura.';

        IF @AjusteSit = 'ESTORNADO' SET @ValorAjuste = 0;

        IF @Recusa = N'' AND @ValorAjuste <> 0
            SET @Avisos = (SELECT 'AJUSTE_DESFEITO' AS codigo, 'INFO' AS nivel,
                                  N'O ajuste de ' + FORMAT(@ValorAjuste, 'N2', 'pt-BR') + N' gravado neste fechamento será desfeito.' AS mensagem,
                                  @IdAjuste AS idReferencia, '' AS campo
                           FOR JSON PATH, INCLUDE_NULL_VALUES);

        IF @Recusa <> N'' OR @SomenteConferir = 1
        BEGIN
            SELECT CAST(CASE WHEN @Recusa = N'' THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Recusa <> N'' THEN @Recusa ELSE N'Prévia da reabertura.' END AS NVARCHAR(400)) AS MENSAGEM,
                   @IdCaixaFechamento AS ID, CAST(ISNULL(@ValorAjuste, 0) AS DECIMAL(18,2)) AS VALOR_AJUSTE, CAST(0 AS BIT) AS PENDENTE,
                   CAST(ISNULL(@Avisos, N'[]') AS NVARCHAR(MAX)) AS AVISOS;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = ISNULL(SIS.fn_SIS_Usuario_Login(@IdUsuario), N'sistema');
        BEGIN TRANSACTION;

        UPDATE f
           SET f.SITUACAO = 'REABERTO', f.DT_REABERTURA = SYSDATETIME(), f.USUARIO_REABERTURA = @Usuario, f.MOTIVO_REABERTURA = @Motivo,
               f.DT_ALTERACAO = SYSDATETIME(), f.USUARIO_ALTERACAO = @Usuario
        FROM BANCO.Caixa_Fechamento f WITH (UPDLOCK, HOLDLOCK)
        WHERE f.ID_CAIXA_FECHAMENTO = @IdCaixaFechamento AND f.SITUACAO = 'FECHADO';
        SET @Linhas = @@ROWCOUNT;

        IF @Linhas = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'O fechamento foi reaberto por outra pessoa. Abra a tela de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   @IdCaixaFechamento AS ID, CAST(0 AS DECIMAL(18,2)) AS VALOR_AJUSTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            RETURN;
        END;

        IF @ValorAjuste <> 0
        BEGIN
            EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdUsuario, @Origem = 'CAIXA_REABERTURA', @Descricao = @Motivo,
                 @TabelaReferencia = N'BANCO.Caixa_Fechamento', @IdReferencia = @IdCaixaFechamento, @IdLote = @IdLote OUTPUT;

            INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, SITUACAO, ID_LOTE, USUARIO_CRIACAO)
            SELECT m.ID_CONTA, m.DT_MOVIMENTO, -m.VALOR, m.TIPO, LEFT(N'Estorno (caixa reaberto): ' + m.HISTORICO, 200), 'ESTORNADO', @IdLote, @Usuario
            FROM BANCO.Movimento m WHERE m.ID_MOVIMENTO = @IdAjuste;

            UPDATE m SET m.SITUACAO = 'ESTORNADO', m.DT_ALTERACAO = SYSDATETIME(), m.USUARIO_ALTERACAO = @Usuario
            FROM BANCO.Movimento m WHERE m.ID_MOVIMENTO = @IdAjuste;

            EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = 1;
        END;

        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        VALUES (N'BANCO.Caixa_Fechamento', @IdCaixaFechamento, 'REABERTURA_CAIXA', 'MOTIVO',
                N'Caixa reaberto (fechamento de ' + CONVERT(NVARCHAR(10), @Data, 103) + N')' + CASE WHEN @ValorAjuste <> 0 THEN N', ajuste desfeito.' ELSE N'.' END,
                @Motivo, @IdAjuste, @IdUsuario, @Usuario);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Caixa reaberto.' AS NVARCHAR(400)) AS MENSAGEM, @IdCaixaFechamento AS ID,
               CAST(@ValorAjuste AS DECIMAL(18,2)) AS VALOR_AJUSTE, CAST(0 AS BIT) AS PENDENTE, CAST(ISNULL(@Avisos, N'[]') AS NVARCHAR(MAX)) AS AVISOS;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível reabrir o caixa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdCaixaFechamento AS ID, CAST(0 AS DECIMAL(18,2)) AS VALOR_AJUSTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO
