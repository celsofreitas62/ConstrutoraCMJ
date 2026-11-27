/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Extrato_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Extrato de uma conta no período (tela Bancos › Extrato e
                saldos, etapa 04g2). A 1ª linha é sempre o SALDO ANTERIOR
                (fim do dia anterior a @DtDe); se o saldo inicial da conta cai
                dentro do período, entra uma linha SALDO_INICIAL nessa data.
                Depois cada movimento, em ordem de data e de inclusão, com o
                SALDO_ACUMULADO. Regra de 19/11/2026: movimento com data
                anterior ao saldo inicial aparece como histórico
                (CONTA_SALDO = 0) e não mexe no saldo. Estornos entram (o par
                original + inverso zera); @OcultarEstornados = 1 só esconde
                as linhas (o saldo continua contando tudo).
                Origem de cada linha: baixa (lançamento, parceiro, quantas
                parcelas no pagamento em lote), transferência (a outra conta)
                ou o tipo do movimento.
                ENTRADA/SAIDA e os totais só contam os movimentos (o saldo
                inicial não é entrada). Todas as linhas trazem SALDO_ANTERIOR, TOTAL_ENTRADAS,
                TOTAL_SAIDAS e SALDO_FINAL do período.
                Período obrigatório, até BANCO_EXTRATO_MAX_DIAS dias.
                Permissão: VER em BANCO_EXTRATO (recusa por THROW 50001).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Extrato_Listar @IdUsuario = 2, @IdConta = 1, @DtDe = '2026-11-01', @DtAte = '2026-11-30';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Extrato_Listar]
    @IdUsuario          INT,
    @IdConta            INT,
    @DtDe               DATE           = NULL,
    @DtAte              DATE           = NULL,
    @OcultarEstornados  BIT            = 0,
    @Texto              NVARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[BANCO].[BANCO_Extrato_Listar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Permissão';
    DECLARE @MaxDias      INT;
    DECLARE @DtSaldoIni   DATE;
    DECLARE @SaldoIni     DECIMAL(18,2);
    DECLARE @SaldoAnt     DECIMAL(18,2);
    DECLARE @DtAnterior   DATE;

    DROP TABLE IF EXISTS #L;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_EXTRATO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver o extrato das contas.', 1;

        SELECT @DtSaldoIni = c.DT_SALDO_INICIAL, @SaldoIni = c.SALDO_INICIAL FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta;
        IF @SaldoIni IS NULL
            THROW 50001, N'Escolha a conta.', 1;

        SET @DtAte   = ISNULL(@DtAte, CONVERT(DATE, SYSDATETIME()));
        SET @DtDe    = ISNULL(@DtDe, DATEFROMPARTS(YEAR(@DtAte), MONTH(@DtAte), 1));
        SET @MaxDias = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BANCO_EXTRATO_MAX_DIAS'), 400);
        IF @DtDe > @DtAte
            THROW 50001, N'A data inicial é depois da final.', 1;
        IF DATEDIFF(DAY, @DtDe, @DtAte) + 1 > @MaxDias
            THROW 50001, N'Período grande demais para o extrato: escolha no máximo o número de dias do parâmetro BANCO_EXTRATO_MAX_DIAS.', 1;

        SET @Texto      = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @DtAnterior = DATEADD(DAY, -1, @DtDe);

        SET @EtapaAtual = 'Saldo anterior';
        SELECT @SaldoAnt = s.SALDO FROM BANCO.fn_BANCO_Conta_Saldo(@IdConta, @DtAnterior) s;
        SET @SaldoAnt = ISNULL(@SaldoAnt, 0);

        SET @EtapaAtual = 'Linhas';
        CREATE TABLE #L
        (
            SEQ               INT            NOT NULL,
            DT_MOVIMENTO      DATE           NOT NULL,
            ID_MOVIMENTO      BIGINT         NULL,
            TIPO              VARCHAR(15)    NOT NULL,
            HISTORICO         NVARCHAR(200)  NOT NULL,
            DOCUMENTO         NVARCHAR(40)   NOT NULL,
            VALOR             DECIMAL(18,2)  NOT NULL,
            CONTA_SALDO       BIT            NOT NULL,
            SITUACAO          VARCHAR(10)    NOT NULL,
            CONCILIADO        BIT            NOT NULL,
            ID_TRANSFERENCIA  BIGINT         NULL,
            ID_LOTE           BIGINT         NULL,
            USUARIO_CRIACAO   NVARCHAR(100)  NOT NULL
        );

        INSERT INTO #L (SEQ, DT_MOVIMENTO, ID_MOVIMENTO, TIPO, HISTORICO, DOCUMENTO, VALOR, CONTA_SALDO, SITUACAO, CONCILIADO, ID_TRANSFERENCIA, ID_LOTE, USUARIO_CRIACAO)
        SELECT 0, @DtAnterior, NULL, 'SALDO_ANTERIOR', N'Saldo anterior', N'', @SaldoAnt, 0, 'ATIVO', 0, NULL, NULL, N''
        UNION ALL
        SELECT 1, @DtSaldoIni, NULL, 'SALDO_INICIAL', N'Saldo inicial da conta', N'', @SaldoIni, 1, 'ATIVO', 0, NULL, NULL, N''
        WHERE @DtSaldoIni BETWEEN @DtDe AND @DtAte
        UNION ALL
        SELECT 2, m.DT_MOVIMENTO, m.ID_MOVIMENTO, m.TIPO, m.HISTORICO, m.DOCUMENTO, m.VALOR,
               CAST(CASE WHEN @DtSaldoIni IS NULL OR m.DT_MOVIMENTO >= @DtSaldoIni THEN 1 ELSE 0 END AS BIT),
               m.SITUACAO, m.CONCILIADO, m.ID_TRANSFERENCIA, m.ID_LOTE, m.USUARIO_CRIACAO
        FROM BANCO.Movimento m WITH (NOLOCK)
        WHERE m.ID_CONTA = @IdConta AND m.DT_MOVIMENTO BETWEEN @DtDe AND @DtAte;

        SET @EtapaAtual = 'Consulta';
        ;WITH a AS
        (
            SELECT l.*,
                   CAST(@SaldoAnt + SUM(CASE WHEN l.SEQ > 0 AND l.CONTA_SALDO = 1 THEN l.VALOR ELSE 0 END)
                        OVER (ORDER BY l.DT_MOVIMENTO, l.SEQ, l.ID_MOVIMENTO ROWS UNBOUNDED PRECEDING) AS DECIMAL(18,2)) AS SALDO_ACUMULADO,
                   CAST(SUM(CASE WHEN l.SEQ = 2 AND l.CONTA_SALDO = 1 AND l.VALOR > 0 THEN l.VALOR ELSE 0 END) OVER () AS DECIMAL(18,2)) AS TOTAL_ENTRADAS,
                   CAST(SUM(CASE WHEN l.SEQ = 2 AND l.CONTA_SALDO = 1 AND l.VALOR < 0 THEN -l.VALOR ELSE 0 END) OVER () AS DECIMAL(18,2)) AS TOTAL_SAIDAS,
                   CAST(@SaldoAnt + SUM(CASE WHEN l.SEQ > 0 AND l.CONTA_SALDO = 1 THEN l.VALOR ELSE 0 END) OVER () AS DECIMAL(18,2)) AS SALDO_FINAL
            FROM #L l
        )
        SELECT a.DT_MOVIMENTO, a.ID_MOVIMENTO, a.TIPO, a.HISTORICO, a.DOCUMENTO, a.VALOR,
               CAST(CASE WHEN a.SEQ = 2 AND a.VALOR > 0 THEN a.VALOR ELSE 0 END AS DECIMAL(18,2)) AS ENTRADA,
               CAST(CASE WHEN a.SEQ = 2 AND a.VALOR < 0 THEN -a.VALOR ELSE 0 END AS DECIMAL(18,2)) AS SAIDA,
               a.SALDO_ACUMULADO, a.CONTA_SALDO, a.SITUACAO, a.CONCILIADO, a.ID_TRANSFERENCIA, a.ID_LOTE, a.USUARIO_CRIACAO,
               ISNULL(b.ID_LANCAMENTO, 0) AS ID_LANCAMENTO, ISNULL(b.LANC_TIPO, '') AS LANCAMENTO_TIPO, ISNULL(b.PESSOA, N'') AS PESSOA,
               ISNULL(b.QTD, 0) AS QTD_BAIXAS, ISNULL(oc.DESCRICAO, N'') AS OUTRA_CONTA,
               CAST(@SaldoAnt AS DECIMAL(18,2)) AS SALDO_ANTERIOR, a.TOTAL_ENTRADAS, a.TOTAL_SAIDAS, a.SALDO_FINAL
        FROM a
        OUTER APPLY (SELECT TOP 1 l.ID_LANCAMENTO, l.TIPO AS LANC_TIPO, ISNULL(NULLIF(pe.NOME_FANTASIA, N''), pe.NOME) AS PESSOA,
                            COUNT(*) OVER () AS QTD
                     FROM FIN.Baixa bx WITH (NOLOCK)
                     INNER JOIN FIN.Parcela p    WITH (NOLOCK) ON p.ID_PARCELA = bx.ID_PARCELA
                     INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
                     LEFT  JOIN CAD.Pessoa pe    WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
                     WHERE a.ID_MOVIMENTO IS NOT NULL AND bx.ID_MOVIMENTO = a.ID_MOVIMENTO
                     ORDER BY bx.ID_BAIXA) b
        OUTER APPLY (SELECT TOP 1 c.DESCRICAO
                     FROM FIN.Transferencia t WITH (NOLOCK)
                     INNER JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = CASE WHEN t.ID_CONTA_ORIGEM = @IdConta THEN t.ID_CONTA_DESTINO ELSE t.ID_CONTA_ORIGEM END
                     WHERE a.ID_TRANSFERENCIA IS NOT NULL AND t.ID_TRANSFERENCIA = a.ID_TRANSFERENCIA
                     ORDER BY t.ID_TRANSFERENCIA) oc
        WHERE a.SEQ < 2
           OR ((ISNULL(@OcultarEstornados, 0) = 0 OR a.SITUACAO = 'ATIVO')
               AND (@Texto IS NULL OR a.HISTORICO LIKE N'%' + @Texto + N'%' OR a.DOCUMENTO LIKE N'%' + @Texto + N'%'
                    OR ISNULL(b.PESSOA, N'') LIKE N'%' + @Texto + N'%'))
        ORDER BY a.DT_MOVIMENTO, a.SEQ, a.ID_MOVIMENTO;

        DROP TABLE IF EXISTS #L;
    END TRY
    BEGIN CATCH
        DROP TABLE IF EXISTS #L;
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível montar o extrato. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
