/*******************************************************************************
  Objeto      : [FIN].[FIN_Baixa_Estornar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Estorna uma baixa (etapa 04g, aprovado em 26/11/2026). Nada é
                apagado: cada baixa estornada ganha uma baixa com os valores
                negativos (ID_BAIXA_ESTORNADA) e o movimento bancário ganha um
                movimento inverso; original e inverso ficam com SITUACAO
                ESTORNADO (o saldo soma os dois e zera). Pagamento em lote (um
                movimento para várias baixas) estorna inteiro, com a tarifa do
                mesmo lote. A parcela volta ao saldo anterior (gatilho do saldo).
                @DtEstorno (padrão hoje): data do estorno no banco/caixa;
                confere trava de datas (motivo com LANCAR_RETROATIVO), mês
                fechado (conta contábil) e caixa fechado nessa data.
                Motivo obrigatório (vai em OBSERVACAO das baixas de estorno e
                em SIS.Aviso_Confirmado, código ESTORNO).
                @SomenteConferir = 1: devolve, sem gravar, quantas baixas e o
                valor que serão estornados (prévia da tela).
                Permissão: ESTORNAR em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID (baixa informada), QTD_BAIXAS,
                VALOR (líquido estornado), PENDENTE, AVISOS.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Baixa_Estornar @IdUsuario = 2, @IdBaixa = 1, @Motivo = N'Baixa em dobro', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Baixa_Estornar]
    @IdUsuario        INT,
    @IdBaixa          BIGINT,
    @Motivo           NVARCHAR(400)  = NULL,
    @DtEstorno        DATE           = NULL,
    @SomenteConferir  BIT            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Baixa_Estornar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @Tipo         CHAR(1);
    DECLARE @Item         VARCHAR(40);
    DECLARE @IdMovimento  BIGINT;
    DECLARE @IdLoteOrig   BIGINT;
    DECLARE @OrigemLote   VARCHAR(30);
    DECLARE @IdConta      INT;
    DECLARE @Estornada    BIGINT;
    DECLARE @IdLote       BIGINT;
    DECLARE @Qtd          INT;
    DECLARE @Valor        DECIMAL(18,2);
    DECLARE @Avisos       NVARCHAR(MAX) = N'[]';
    DECLARE @Pendente     BIT = 0;
    DECLARE @PodeRetro    BIT;

    CREATE TABLE #B (ID_BAIXA BIGINT NOT NULL PRIMARY KEY, ID_EMPRESA INT NULL, ID_PLANO_CONTA INT NULL, LIQUIDO DECIMAL(18,2) NOT NULL);
    CREATE TABLE #M (ID_MOVIMENTO BIGINT NOT NULL PRIMARY KEY);
    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Motivo    = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @DtEstorno = ISNULL(@DtEstorno, CONVERT(DATE, SYSDATETIME()));

        SELECT @Tipo = l.TIPO, @IdMovimento = b.ID_MOVIMENTO, @IdLoteOrig = b.ID_LOTE, @IdConta = b.ID_CONTA, @Estornada = b.ID_BAIXA_ESTORNADA
        FROM FIN.Baixa b
        INNER JOIN FIN.Parcela p    ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE b.ID_BAIXA = @IdBaixa;
        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;
        SELECT @OrigemLote = x.ORIGEM FROM SIS.Lote x WHERE x.ID_LOTE = @IdLoteOrig;

        IF @Tipo IS NULL
            SET @Recusa = N'Baixa não encontrada.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ESTORNAR') = 0
            SET @Recusa = N'Você não tem permissão para estornar baixas.';
        IF @Recusa = N'' AND @Estornada IS NOT NULL
            SET @Recusa = N'Este registro já é um estorno.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Baixa x WHERE x.ID_BAIXA_ESTORNADA = @IdBaixa)
            SET @Recusa = N'Esta baixa já foi estornada.';
        IF @Recusa = N'' AND @SomenteConferir = 0 AND LEN(@Motivo) < 5
            SET @Recusa = N'Informe o motivo do estorno.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdBaixa AS ID, 0 AS QTD_BAIXAS,
                   CAST(0 AS DECIMAL(18,2)) AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        -- o que vai junto: as baixas do mesmo movimento (pagamento em lote) ainda não estornadas
        INSERT INTO #B (ID_BAIXA, ID_EMPRESA, ID_PLANO_CONTA, LIQUIDO)
        SELECT b.ID_BAIXA, l.ID_EMPRESA, l.ID_PLANO_CONTA, b.VALOR_LIQUIDO
        FROM FIN.Baixa b
        INNER JOIN FIN.Parcela p    ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE (b.ID_BAIXA = @IdBaixa OR (@IdMovimento IS NOT NULL AND b.ID_MOVIMENTO = @IdMovimento))
          AND b.ID_BAIXA_ESTORNADA IS NULL
          AND NOT EXISTS (SELECT 1 FROM FIN.Baixa x WHERE x.ID_BAIXA_ESTORNADA = b.ID_BAIXA);

        -- movimentos: o da baixa e a tarifa do mesmo lote de baixa
        INSERT INTO #M (ID_MOVIMENTO)
        SELECT m.ID_MOVIMENTO
        FROM BANCO.Movimento m
        WHERE m.SITUACAO = 'ATIVO'
          AND (m.ID_MOVIMENTO = @IdMovimento
               OR (@OrigemLote = 'BAIXA' AND m.ID_LOTE = @IdLoteOrig AND m.TIPO = 'TARIFA'));

        SELECT @Qtd = COUNT(*), @Valor = SUM(LIQUIDO) FROM #B;

        -- regras na data do estorno
        SET @PodeRetro = SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LANCAR_RETROATIVO');
        IF FIN.fn_FIN_Data_Recusa('BAIXA', @DtEstorno) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_BAIXA', CASE WHEN @PodeRetro = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END, FIN.fn_FIN_Data_Recusa('BAIXA', @DtEstorno), 'dtEstorno');

        IF BANCO.fn_BANCO_Caixa_Recusa(@IdConta, @DtEstorno) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CAIXA_FECHADO', 'BLOQUEIO', BANCO.fn_BANCO_Caixa_Recusa(@IdConta, @DtEstorno), 'dtEstorno');

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'MES_FECHADO', 'BLOQUEIO',
               N'O mês ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(m.MES)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(m.MES)) + N' está fechado (conta contábil).', 'dtEstorno'
        FROM #B b
        INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = b.ID_EMPRESA AND m.MES = DATEFROMPARTS(YEAR(@DtEstorno), MONTH(@DtEstorno), 1) AND m.FECHADO = 1
        INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = b.ID_PLANO_CONTA AND pc.CONTABIL = 1;

        IF @Qtd > 1
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('ESTORNO_LOTE', 'INFO', N'Esta baixa faz parte de um pagamento em lote: as ' + CONVERT(NVARCHAR(10), @Qtd)
                    + N' baixas do mesmo movimento serão estornadas juntas (' + FORMAT(@Valor, 'N2', 'pt-BR') + N').', '');

        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
        BEGIN
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdBaixa AS ID, @Qtd AS QTD_BAIXAS,
                   @Valor AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF @SomenteConferir = 1
        BEGIN
            SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia do estorno.' AS NVARCHAR(400)) AS MENSAGEM, @IdBaixa AS ID, @Qtd AS QTD_BAIXAS,
                   @Valor AS VALOR, CAST(CASE WHEN EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') THEN 1 ELSE 0 END AS BIT) AS PENDENTE,
                   CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- Gravação
        ---------------------------------------------------------------------
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdUsuario, @Origem = 'ESTORNO_BAIXA', @Descricao = @Motivo,
             @TabelaReferencia = N'FIN.Baixa', @IdReferencia = @IdBaixa, @IdLote = @IdLote OUTPUT;

        -- concorrência: alguém estornou no meio
        IF EXISTS (SELECT 1 FROM #B b INNER JOIN FIN.Baixa x WITH (UPDLOCK, HOLDLOCK) ON x.ID_BAIXA_ESTORNADA = b.ID_BAIXA)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'A baixa foi estornada por outra pessoa. Abra a ficha de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   @IdBaixa AS ID, 0 AS QTD_BAIXAS, CAST(0 AS DECIMAL(18,2)) AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        DECLARE @Mov TABLE (ID_ORIGINAL BIGINT NOT NULL, ID_INVERSO BIGINT NOT NULL);

        MERGE BANCO.Movimento AS t
        USING (SELECT m.ID_MOVIMENTO, m.ID_CONTA, m.VALOR, m.TIPO, m.HISTORICO, m.DOCUMENTO
               FROM BANCO.Movimento m INNER JOIN #M x ON x.ID_MOVIMENTO = m.ID_MOVIMENTO) AS s
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, SITUACAO, ID_LOTE, USUARIO_CRIACAO)
            VALUES (s.ID_CONTA, @DtEstorno, -s.VALOR, s.TIPO, LEFT(N'Estorno: ' + s.HISTORICO, 200), s.DOCUMENTO, 'ESTORNADO', @IdLote, ISNULL(@Usuario, N'sistema'))
        OUTPUT s.ID_MOVIMENTO, inserted.ID_MOVIMENTO INTO @Mov (ID_ORIGINAL, ID_INVERSO);

        UPDATE m
           SET m.SITUACAO = 'ESTORNADO', m.DT_ALTERACAO = SYSDATETIME(), m.USUARIO_ALTERACAO = @Usuario
        FROM BANCO.Movimento m INNER JOIN #M x ON x.ID_MOVIMENTO = m.ID_MOVIMENTO;

        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, JUROS, MULTA, CORRECAO, DESCONTO, ABATIMENTO,
                               TARIFA, RETENCAO, ID_MOVIMENTO, COMPENSADO, DT_COMPENSACAO, ID_BAIXA_ESTORNADA, OBSERVACAO, ID_LOTE, USUARIO_CRIACAO)
        SELECT b.ID_PARCELA, @DtEstorno, b.ID_CONTA, b.FORMA, -b.VALOR_PRINCIPAL, -b.JUROS, -b.MULTA, -b.CORRECAO, -b.DESCONTO, -b.ABATIMENTO,
               -b.TARIFA, -b.RETENCAO, mv.ID_INVERSO, b.COMPENSADO, b.DT_COMPENSACAO, b.ID_BAIXA, LEFT(N'Estorno: ' + @Motivo, 400), @IdLote, ISNULL(@Usuario, N'sistema')
        FROM FIN.Baixa b
        INNER JOIN #B x ON x.ID_BAIXA = b.ID_BAIXA
        LEFT  JOIN @Mov mv ON mv.ID_ORIGINAL = b.ID_MOVIMENTO;

        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'FIN.Baixa', b.ID_BAIXA, 'ESTORNO', 'MOTIVO', N'Baixa estornada em ' + CONVERT(NVARCHAR(10), @DtEstorno, 103) + N'.', @Motivo, NULL, @IdUsuario, ISNULL(@Usuario, N'sistema')
        FROM #B b
        UNION ALL
        SELECT N'FIN.Baixa', @IdBaixa, r.CODIGO, r.NIVEL, r.MENSAGEM, @Motivo, NULL, @IdUsuario, ISNULL(@Usuario, N'sistema')
        FROM #Regra r WHERE r.NIVEL = 'MOTIVO';

        EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = @Qtd;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Qtd = 1 THEN N'Baixa estornada.' ELSE CONVERT(NVARCHAR(10), @Qtd) + N' baixas estornadas.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdBaixa AS ID, @Qtd AS QTD_BAIXAS, @Valor AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #B; DROP TABLE IF EXISTS #M; DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível estornar a baixa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdBaixa AS ID, 0 AS QTD_BAIXAS, CAST(0 AS DECIMAL(18,2)) AS VALOR, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO
