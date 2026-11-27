/*******************************************************************************
  Objeto      : [FIN].[FIN_Transferencia_Estornar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Estorna uma transferência (etapa 04g2). Nada é apagado: os
                dois movimentos ganham um movimento inverso na data do estorno
                (lote ESTORNO_TRANSFERENCIA); originais e inversos ficam
                ESTORNADO (o saldo soma os quatro e zera) e a transferência
                fica ESTORNADA com data, motivo e quem estornou.
                @DtEstorno (padrão hoje): nas duas contas valem a trava de
                datas (motivo com LANCAR_RETROATIVO), o caixa fechado e o mês
                fechado da empresa. Movimento já conciliado bloqueia (desfazer
                a conciliação antes). Motivo obrigatório.
                @SomenteConferir = 1: prévia, sem gravar.
                Permissão: ESTORNAR em BANCO_TRANSFERENCIA.
                Devolve SUCESSO, MENSAGEM, ID, VALOR, PENDENTE, AVISOS.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Transferencia_Estornar @IdUsuario = 2, @IdTransferencia = 1, @Motivo = N'Conta errada', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Transferencia_Estornar]
    @IdUsuario        INT,
    @IdTransferencia  BIGINT,
    @Motivo           NVARCHAR(400)  = NULL,
    @DtEstorno        DATE           = NULL,
    @SomenteConferir  BIT            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[FIN].[FIN_Transferencia_Estornar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @Situacao    VARCHAR(10);
    DECLARE @Valor       DECIMAL(18,2);
    DECLARE @IdLote      BIGINT;
    DECLARE @Avisos      NVARCHAR(MAX) = N'[]';
    DECLARE @Linhas      INT;

    CREATE TABLE #M (ID_MOVIMENTO BIGINT NOT NULL PRIMARY KEY, ID_CONTA INT NOT NULL, ID_EMPRESA INT NOT NULL, DESCRICAO NVARCHAR(60) NOT NULL, CONCILIADO BIT NOT NULL);
    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Motivo    = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @DtEstorno = ISNULL(@DtEstorno, CONVERT(DATE, SYSDATETIME()));

        SELECT @Situacao = t.SITUACAO, @Valor = t.VALOR FROM FIN.Transferencia t WHERE t.ID_TRANSFERENCIA = @IdTransferencia;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_TRANSFERENCIA', 'ESTORNAR') = 0
            SET @Recusa = N'Você não tem permissão para estornar transferências.';
        IF @Recusa = N'' AND @Situacao IS NULL
            SET @Recusa = N'Transferência não encontrada.';
        IF @Recusa = N'' AND @Situacao = 'ESTORNADA'
            SET @Recusa = N'Esta transferência já foi estornada.';
        IF @Recusa = N'' AND @SomenteConferir = 0 AND LEN(@Motivo) < 5
            SET @Recusa = N'Informe o motivo do estorno.';

        IF @Recusa = N''
            INSERT INTO #M (ID_MOVIMENTO, ID_CONTA, ID_EMPRESA, DESCRICAO, CONCILIADO)
            SELECT m.ID_MOVIMENTO, m.ID_CONTA, c.ID_EMPRESA, c.DESCRICAO, m.CONCILIADO
            FROM BANCO.Movimento m
            INNER JOIN BANCO.Conta c ON c.ID_CONTA = m.ID_CONTA
            WHERE m.ID_TRANSFERENCIA = @IdTransferencia AND m.SITUACAO = 'ATIVO';

        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM #M)
            SET @Recusa = N'A transferência não tem movimentos ativos para estornar.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdTransferencia AS ID,
                   CAST(ISNULL(@Valor, 0) AS DECIMAL(18,2)) AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- Regras na data do estorno, nas duas contas
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Regras';

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'CONCILIADO', 'BLOQUEIO', N'O movimento na conta ' + m.DESCRICAO + N' já foi conciliado com o extrato do banco: desfaça a conciliação antes de estornar.',
               m.ID_CONTA, ''
        FROM #M m WHERE m.CONCILIADO = 1;

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'CAIXA_FECHADO', 'BLOQUEIO', BANCO.fn_BANCO_Caixa_Recusa(m.ID_CONTA, @DtEstorno), m.ID_CONTA, 'dtEstorno'
        FROM #M m WHERE BANCO.fn_BANCO_Caixa_Recusa(m.ID_CONTA, @DtEstorno) <> N'';

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'MES_FECHADO', 'BLOQUEIO',
               N'O mês ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(f.MES)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(f.MES))
               + N' está fechado na empresa da conta ' + m.DESCRICAO + N'.', m.ID_CONTA, 'dtEstorno'
        FROM #M m
        INNER JOIN FIN.Mes_Fechado f ON f.ID_EMPRESA = m.ID_EMPRESA AND f.FECHADO = 1
                                    AND f.MES = DATEFROMPARTS(YEAR(@DtEstorno), MONTH(@DtEstorno), 1);

        IF FIN.fn_FIN_Data_Recusa('BAIXA', @DtEstorno) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_ESTORNO',
                    CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_TRANSFERENCIA', 'LANCAR_RETROATIVO') = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
                    REPLACE(FIN.fn_FIN_Data_Recusa('BAIXA', @DtEstorno), N'de pagamento', N'do estorno'), 'dtEstorno');

        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
        BEGIN
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdTransferencia AS ID,
                   @Valor AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF @SomenteConferir = 1
        BEGIN
            SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia do estorno.' AS NVARCHAR(400)) AS MENSAGEM, @IdTransferencia AS ID, @Valor AS VALOR,
                   CAST(CASE WHEN EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') THEN 1 ELSE 0 END AS BIT) AS PENDENTE,
                   CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- Gravação
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Gravação';
        SET @Usuario = ISNULL(SIS.fn_SIS_Usuario_Login(@IdUsuario), N'sistema');
        BEGIN TRANSACTION;

        -- concorrência: alguém estornou no meio
        UPDATE t
           SET t.SITUACAO = 'ESTORNADA', t.DT_ESTORNO = @DtEstorno, t.MOTIVO_ESTORNO = @Motivo, t.USUARIO_ESTORNO = @Usuario,
               t.DT_HORA_ESTORNO = SYSDATETIME(), t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM FIN.Transferencia t WITH (UPDLOCK, HOLDLOCK)
        WHERE t.ID_TRANSFERENCIA = @IdTransferencia AND t.SITUACAO = 'ATIVA';
        SET @Linhas = @@ROWCOUNT;

        IF @Linhas = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'A transferência foi estornada por outra pessoa. Abra a lista de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   @IdTransferencia AS ID, @Valor AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdUsuario, @Origem = 'ESTORNO_TRANSFERENCIA', @Descricao = @Motivo,
             @TabelaReferencia = N'FIN.Transferencia', @IdReferencia = @IdTransferencia, @IdLote = @IdLote OUTPUT;

        UPDATE t SET t.ID_LOTE_ESTORNO = @IdLote FROM FIN.Transferencia t WHERE t.ID_TRANSFERENCIA = @IdTransferencia;

        INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_TRANSFERENCIA, SITUACAO, ID_LOTE, USUARIO_CRIACAO)
        SELECT m.ID_CONTA, @DtEstorno, -m.VALOR, m.TIPO, LEFT(N'Estorno: ' + m.HISTORICO, 200), m.DOCUMENTO, m.ID_TRANSFERENCIA, 'ESTORNADO', @IdLote, @Usuario
        FROM BANCO.Movimento m INNER JOIN #M x ON x.ID_MOVIMENTO = m.ID_MOVIMENTO;

        UPDATE m
           SET m.SITUACAO = 'ESTORNADO', m.DT_ALTERACAO = SYSDATETIME(), m.USUARIO_ALTERACAO = @Usuario
        FROM BANCO.Movimento m INNER JOIN #M x ON x.ID_MOVIMENTO = m.ID_MOVIMENTO;

        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'FIN.Transferencia', @IdTransferencia, 'ESTORNO', 'MOTIVO', N'Transferência estornada em ' + CONVERT(NVARCHAR(10), @DtEstorno, 103) + N'.',
               @Motivo, NULL, @IdUsuario, @Usuario
        UNION ALL
        SELECT N'FIN.Transferencia', @IdTransferencia, r.CODIGO, r.NIVEL, r.MENSAGEM, @Motivo, r.ID_REFERENCIA, @IdUsuario, @Usuario
        FROM #Regra r WHERE r.NIVEL = 'MOTIVO';

        EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = 1;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Transferência estornada.' AS NVARCHAR(400)) AS MENSAGEM, @IdTransferencia AS ID, @Valor AS VALOR,
               CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível estornar a transferência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdTransferencia AS ID, CAST(0 AS DECIMAL(18,2)) AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO
