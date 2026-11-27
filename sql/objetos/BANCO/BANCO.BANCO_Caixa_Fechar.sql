/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Caixa_Fechar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Fechamento de caixa de uma conta até uma data (etapa 04g2,
                desenho aprovado em 26/11/2026). Compara o saldo do sistema
                no fim do dia (BANCO.fn_BANCO_Conta_Saldo) com o saldo
                contado. Diferença exige motivo; com @GerarAjuste = 1 (ação
                AJUSTE_CAIXA) grava um movimento AJUSTE pela diferença na
                data do fechamento, e o saldo do sistema passa a ser o
                contado. Fechado, a conta não aceita baixa, estorno,
                transferência nem ajuste com data até a do fechamento
                (BANCO.fn_BANCO_Caixa_Recusa).
                Regras: só os tipos de conta de FIN_CAIXA_FECHAMENTO_TIPOS;
                conta ativa; data até hoje, depois do último fechamento e não
                anterior ao saldo inicial; o ajuste segue a trava de datas.
                Mesmo contrato da baixa (BLOQUEIO, MOTIVO; @SomenteConferir = 1
                é a prévia: com @SaldoContado vazio devolve só o saldo do
                sistema e o movimento desde o último fechamento).
                Motivo e ajuste em SIS.Aviso_Confirmado (TABELA
                BANCO.Caixa_Fechamento, código DIFERENCA_CAIXA).
                Permissão: INCLUIR em BANCO_CAIXA (+ AJUSTE_CAIXA para o
                ajuste).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID, SALDO_SISTEMA,
                SALDO_CONTADO, DIFERENCA, DT_ULTIMO_FECHAMENTO, ENTRADAS,
                SAIDAS, QTD_MOVIMENTOS (desde o último fechamento), PODE_AJUSTE,
                ID_MOVIMENTO_AJUSTE, PENDENTE, AVISOS.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = 2, @IdConta = 1, @DtFechamento = '2026-11-26', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Caixa_Fechar]
    @IdUsuario        INT,
    @IdConta          INT,
    @DtFechamento     DATE            = NULL,
    @SaldoContado     DECIMAL(18,2)   = NULL,
    @Motivo           NVARCHAR(400)   = NULL,
    @GerarAjuste      BIT             = 0,
    @Observacao       NVARCHAR(400)   = NULL,
    @SomenteConferir  BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[BANCO].[BANCO_Caixa_Fechar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @Hoje        DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Tipos       NVARCHAR(400);
    DECLARE @TipoConta   VARCHAR(10);
    DECLARE @Ativa       BIT;
    DECLARE @NaLixeira   BIT;
    DECLARE @NomeConta   NVARCHAR(60);
    DECLARE @Ultimo      DATE;
    DECLARE @Sistema     DECIMAL(18,2);
    DECLARE @TemSaldo    BIT;
    DECLARE @Diferenca   DECIMAL(18,2) = 0;
    DECLARE @Entradas    DECIMAL(18,2) = 0;
    DECLARE @Saidas      DECIMAL(18,2) = 0;
    DECLARE @QtdMov      INT = 0;
    DECLARE @PodeAjuste  BIT;
    DECLARE @Avisos      NVARCHAR(MAX) = N'[]';
    DECLARE @Pendente    BIT = 0;
    DECLARE @IdLote      BIGINT;
    DECLARE @IdAjuste    BIGINT;
    DECLARE @Id          BIGINT;
    DECLARE @Hist        NVARCHAR(200);

    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Motivo      = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @Observacao  = LTRIM(RTRIM(ISNULL(@Observacao, N'')));
        SET @GerarAjuste = ISNULL(@GerarAjuste, 0);
        SET @Tipos       = N',' + REPLACE(UPPER(ISNULL(SIS.fn_SIS_Parametro('FIN_CAIXA_FECHAMENTO_TIPOS'), N'')), N' ', N'') + N',';
        SET @PodeAjuste  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CAIXA', 'AJUSTE_CAIXA');

        SELECT @TipoConta = c.TIPO, @Ativa = c.ATIVO, @NomeConta = c.DESCRICAO, @NaLixeira = CAST(CASE WHEN c.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT)
        FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta;
        SELECT @Ultimo = MAX(f.DT_FECHAMENTO) FROM BANCO.Caixa_Fechamento f WHERE f.ID_CONTA = @IdConta AND f.SITUACAO = 'FECHADO';

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CAIXA', 'INCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para fechar o caixa.';
        IF @Recusa = N'' AND @TipoConta IS NULL
            SET @Recusa = N'Escolha a conta.';
        IF @Recusa = N'' AND CHARINDEX(N',' + @TipoConta + N',', @Tipos) = 0
            SET @Recusa = N'Esta conta não usa o fechamento de caixa (tipos no parâmetro FIN_CAIXA_FECHAMENTO_TIPOS).';
        IF @Recusa = N'' AND (@Ativa = 0 OR @NaLixeira = 1)
            SET @Recusa = N'A conta ' + @NomeConta + N' está desativada.';
        IF @Recusa = N'' AND @DtFechamento IS NULL
            SET @Recusa = N'Informe a data do fechamento.';
        IF @Recusa = N'' AND @DtFechamento > @Hoje
            SET @Recusa = N'Não dá para fechar o caixa de um dia que ainda não chegou.';
        IF @Recusa = N'' AND @Ultimo IS NOT NULL AND @DtFechamento <= @Ultimo
            SET @Recusa = N'O caixa da conta ' + @NomeConta + N' já está fechado até ' + CONVERT(NVARCHAR(10), @Ultimo, 103) + N'.';

        IF @Recusa = N''
        BEGIN
            SELECT @Sistema = s.SALDO, @TemSaldo = s.TEM_SALDO FROM BANCO.fn_BANCO_Conta_Saldo(@IdConta, @DtFechamento) s;
            IF @TemSaldo = 0
                SET @Recusa = N'A data é anterior ao saldo inicial da conta: não há saldo oficial para fechar.';
        END;

        IF @Recusa = N'' AND @SomenteConferir = 0 AND @SaldoContado IS NULL
            SET @Recusa = N'Informe o saldo contado.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID,
                   CAST(ISNULL(@Sistema, 0) AS DECIMAL(18,2)) AS SALDO_SISTEMA, CAST(ISNULL(@SaldoContado, 0) AS DECIMAL(18,2)) AS SALDO_CONTADO,
                   CAST(0 AS DECIMAL(18,2)) AS DIFERENCA, ISNULL(CONVERT(VARCHAR(10), @Ultimo, 23), '') AS DT_ULTIMO_FECHAMENTO,
                   CAST(0 AS DECIMAL(18,2)) AS ENTRADAS, CAST(0 AS DECIMAL(18,2)) AS SAIDAS, 0 AS QTD_MOVIMENTOS, ISNULL(@PodeAjuste, CAST(0 AS BIT)) AS PODE_AJUSTE,
                   CAST(NULL AS BIGINT) AS ID_MOVIMENTO_AJUSTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        -- movimento desde o último fechamento (ou do saldo inicial)
        SELECT @Entradas = ISNULL(SUM(CASE WHEN m.VALOR > 0 THEN m.VALOR ELSE 0 END), 0),
               @Saidas   = ISNULL(SUM(CASE WHEN m.VALOR < 0 THEN -m.VALOR ELSE 0 END), 0),
               @QtdMov   = COUNT(*)
        FROM BANCO.Movimento m
        INNER JOIN BANCO.Conta c ON c.ID_CONTA = m.ID_CONTA
        WHERE m.ID_CONTA = @IdConta AND m.DT_MOVIMENTO <= @DtFechamento
          AND (@Ultimo IS NULL OR m.DT_MOVIMENTO > @Ultimo)
          AND (c.DT_SALDO_INICIAL IS NULL OR m.DT_MOVIMENTO >= c.DT_SALDO_INICIAL);

        SET @Diferenca = CAST(ISNULL(@SaldoContado, @Sistema) - @Sistema AS DECIMAL(18,2));
        IF @Diferenca = 0 SET @GerarAjuste = 0;

        ---------------------------------------------------------------------
        -- Regras
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Regras';
        IF @Diferenca <> 0
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DIFERENCA_CAIXA', 'MOTIVO',
                    N'Diferença de ' + FORMAT(@Diferenca, 'N2', 'pt-BR') + N' entre o saldo contado (' + FORMAT(@SaldoContado, 'N2', 'pt-BR')
                    + N') e o do sistema (' + FORMAT(@Sistema, 'N2', 'pt-BR') + N'): informe o motivo.', 'saldoContado');

        IF @GerarAjuste = 1 AND @PodeAjuste = 0
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('AJUSTE_SEM_PERMISSAO', 'BLOQUEIO', N'Você não tem permissão para ajustar a diferença do caixa: feche sem o ajuste ou peça a um administrador.', 'gerarAjuste');

        IF @GerarAjuste = 1 AND FIN.fn_FIN_Data_Recusa('BAIXA', @DtFechamento) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_AJUSTE', 'BLOQUEIO', REPLACE(FIN.fn_FIN_Data_Recusa('BAIXA', @DtFechamento), N'de pagamento', N'do ajuste'), 'dtFechamento');

        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@Motivo) < 5
            SET @Pendente = 1;

        IF @Recusa <> N'' OR @SomenteConferir = 1 OR @Pendente = 1
        BEGIN
            SELECT CAST(CASE WHEN @Recusa = N'' AND @SomenteConferir = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Recusa <> N'' THEN @Recusa
                             WHEN @Pendente = 1 THEN N'Informe o motivo da diferença para fechar o caixa.'
                             ELSE N'Prévia do fechamento.' END AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID, @Sistema AS SALDO_SISTEMA, CAST(ISNULL(@SaldoContado, @Sistema) AS DECIMAL(18,2)) AS SALDO_CONTADO,
                   @Diferenca AS DIFERENCA, ISNULL(CONVERT(VARCHAR(10), @Ultimo, 23), '') AS DT_ULTIMO_FECHAMENTO,
                   CAST(@Entradas AS DECIMAL(18,2)) AS ENTRADAS, CAST(@Saidas AS DECIMAL(18,2)) AS SAIDAS, @QtdMov AS QTD_MOVIMENTOS, @PodeAjuste AS PODE_AJUSTE,
                   CAST(NULL AS BIGINT) AS ID_MOVIMENTO_AJUSTE, @Pendente AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- Gravação
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Gravação';
        SET @Usuario = ISNULL(SIS.fn_SIS_Usuario_Login(@IdUsuario), N'sistema');
        SET @Hist    = LEFT(N'Ajuste do fechamento de caixa de ' + CONVERT(NVARCHAR(10), @DtFechamento, 103) + N': ' + @Motivo, 200);

        BEGIN TRANSACTION;

        -- concorrência: outro fechamento da mesma conta no meio
        IF EXISTS (SELECT 1 FROM BANCO.Caixa_Fechamento f WITH (UPDLOCK, HOLDLOCK)
                   WHERE f.ID_CONTA = @IdConta AND f.SITUACAO = 'FECHADO' AND f.DT_FECHAMENTO >= @DtFechamento)
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'O caixa desta conta acabou de ser fechado por outra pessoa. Abra a tela de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID, @Sistema AS SALDO_SISTEMA, @SaldoContado AS SALDO_CONTADO, @Diferenca AS DIFERENCA,
                   ISNULL(CONVERT(VARCHAR(10), @Ultimo, 23), '') AS DT_ULTIMO_FECHAMENTO, CAST(@Entradas AS DECIMAL(18,2)) AS ENTRADAS,
                   CAST(@Saidas AS DECIMAL(18,2)) AS SAIDAS, @QtdMov AS QTD_MOVIMENTOS, @PodeAjuste AS PODE_AJUSTE,
                   CAST(NULL AS BIGINT) AS ID_MOVIMENTO_AJUSTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdUsuario, @Origem = 'CAIXA_FECHAMENTO', @Descricao = @NomeConta,
             @TabelaReferencia = N'BANCO.Caixa_Fechamento', @IdReferencia = NULL, @IdLote = @IdLote OUTPUT;

        IF @GerarAjuste = 1
        BEGIN
            INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, SITUACAO, ID_LOTE, USUARIO_CRIACAO)
            VALUES (@IdConta, @DtFechamento, @Diferenca, 'AJUSTE', @Hist, 'ATIVO', @IdLote, @Usuario);
            SET @IdAjuste = SCOPE_IDENTITY();
        END;

        INSERT INTO BANCO.Caixa_Fechamento (ID_CONTA, DT_FECHAMENTO, SALDO_SISTEMA, SALDO_CONTADO, MOTIVO_DIFERENCA, ID_MOVIMENTO_AJUSTE, OBSERVACAO, SITUACAO, USUARIO_CRIACAO)
        VALUES (@IdConta, @DtFechamento, @Sistema, @SaldoContado, CASE WHEN @Diferenca <> 0 THEN @Motivo ELSE N'' END, @IdAjuste, @Observacao, 'FECHADO', @Usuario);
        SET @Id = SCOPE_IDENTITY();

        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'BANCO.Caixa_Fechamento', @Id, r.CODIGO, r.NIVEL,
               LEFT(r.MENSAGEM + CASE WHEN @IdAjuste IS NOT NULL THEN N' Ajuste gravado.' ELSE N' Sem ajuste.' END, 400),
               @Motivo, @IdAjuste, @IdUsuario, @Usuario
        FROM #Regra r WHERE r.NIVEL = 'MOTIVO';

        EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = 1;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Caixa da conta ' + @NomeConta + N' fechado até ' + CONVERT(NVARCHAR(10), @DtFechamento, 103)
                    + CASE WHEN @IdAjuste IS NOT NULL THEN N', com ajuste de ' + FORMAT(@Diferenca, 'N2', 'pt-BR') ELSE N'' END + N'.' AS NVARCHAR(400)) AS MENSAGEM,
               @Id AS ID, @Sistema AS SALDO_SISTEMA, @SaldoContado AS SALDO_CONTADO, @Diferenca AS DIFERENCA,
               ISNULL(CONVERT(VARCHAR(10), @Ultimo, 23), '') AS DT_ULTIMO_FECHAMENTO, CAST(@Entradas AS DECIMAL(18,2)) AS ENTRADAS,
               CAST(@Saidas AS DECIMAL(18,2)) AS SAIDAS, @QtdMov AS QTD_MOVIMENTOS, @PodeAjuste AS PODE_AJUSTE,
               @IdAjuste AS ID_MOVIMENTO_AJUSTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível fechar o caixa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID, CAST(0 AS DECIMAL(18,2)) AS SALDO_SISTEMA, CAST(0 AS DECIMAL(18,2)) AS SALDO_CONTADO,
               CAST(0 AS DECIMAL(18,2)) AS DIFERENCA, CAST('' AS VARCHAR(10)) AS DT_ULTIMO_FECHAMENTO, CAST(0 AS DECIMAL(18,2)) AS ENTRADAS,
               CAST(0 AS DECIMAL(18,2)) AS SAIDAS, 0 AS QTD_MOVIMENTOS, CAST(0 AS BIT) AS PODE_AJUSTE,
               CAST(NULL AS BIGINT) AS ID_MOVIMENTO_AJUSTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO
