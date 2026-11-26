/*******************************************************************************
  Objeto      : [FIN].[FIN_Baixa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Baixa (pagamento ou recebimento) de uma ou várias parcelas, total
                ou parcial (etapa 04g, desenho aprovado em 26/11/2026). Todas as
                parcelas do mesmo tipo (pagar ou receber). Tudo-ou-nada.
                @Itens: JSON [{"idParcela":1,"principal":100.00,"juros":0,
                "multa":0,"correcao":0,"desconto":0,"abatimento":0,
                "retencao":0,"tarifa":0}]. principal = quanto da parcela fica
                quitado (abate o saldo; o abatimento faz parte dele, sem
                dinheiro). Gera um lote (origem BAIXA), UM BANCO.Movimento pelo
                total líquido (entra no receber, sai no pagar; sem movimento
                quando o líquido é zero, ex.: só abatimento) e um movimento
                TARIFA pela soma das tarifas. Cheque nasce não compensado (a
                compensação entra com a conciliação).
                Regras (mesmo contrato do FIN_Lancamento_Gravar: BLOQUEIO,
                MOTIVO, AVISO; @SomenteConferir = 1 é a prévia):
                  BLOQUEIO  parcela inexistente/repetida/cancelada/sem saldo,
                            lançamento cancelado/na lixeira/de previsão, tipos
                            misturados, valor acima do saldo ou negativo,
                            conta inativa, forma inválida, mês fechado (conta
                            contábil, mês do pagamento), caixa fechado
                            (BANCO.fn_BANCO_Caixa_Recusa); trava de datas,
                            pendência que bloqueia e desconto acima do limite
                            para quem não tem a permissão;
                  MOTIVO    trava de datas com LANCAR_RETROATIVO, pendência
                            que bloqueia com LIBERAR_PENDENCIA (justificativa)
                            e desconto acima do limite com DESCONTO_LIMITE:
                            grava só com @Motivo;
                  AVISO     encargo diferente do calculado (ENCARGO_AJUSTADO),
                            conta de outra empresa (CONTA_OUTRA_EMPRESA),
                            pagamento antes da emissão (PAGTO_ANTES_EMISSAO):
                            grava só com o código em @AvisosConfirmados.
                Avisos e motivos ficam em SIS.Aviso_Confirmado (TABELA
                FIN.Baixa).
                Permissão: BAIXAR em FIN_PAGAR / FIN_RECEBER.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID (1ª baixa), ID_MOVIMENTO,
                ID_LOTE, PENDENTE, AVISOS (JSON: codigo, nivel, mensagem,
                idReferencia = ID_PARCELA, campo).
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Baixa_Gravar @IdUsuario = 2, @DtPagamento = '2026-11-26', @IdConta = 1, @Forma = 'PIX',
    --      @Itens = N'[{"idParcela":1,"principal":100}]', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Baixa_Gravar]
    @IdUsuario          INT,
    @DtPagamento        DATE            = NULL,
    @IdConta            INT             = NULL,
    @Forma              VARCHAR(12)     = NULL,
    @Itens              NVARCHAR(MAX)   = NULL,
    @Documento          NVARCHAR(40)    = NULL,
    @Observacao         NVARCHAR(400)   = NULL,
    @AvisosConfirmados  NVARCHAR(1000)  = NULL,
    @Motivo             NVARCHAR(400)   = NULL,
    @SomenteConferir    BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[FIN].[FIN_Baixa_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @Tipo        CHAR(1);
    DECLARE @Item        VARCHAR(40);
    DECLARE @Avisos      NVARCHAR(MAX) = N'[]';
    DECLARE @Pendente    BIT = 0;
    DECLARE @IdEmpresaConta INT;
    DECLARE @ContaAtiva  BIT;
    DECLARE @Liquido     DECIMAL(18,2);
    DECLARE @Tarifa      DECIMAL(18,2);
    DECLARE @IdLote      BIGINT;
    DECLARE @IdMovimento BIGINT;
    DECLARE @IdPrimeira  BIGINT;
    DECLARE @N           INT;
    DECLARE @Historico   NVARCHAR(200);

    CREATE TABLE #I (ORDEM INT NOT NULL, ID_PARCELA BIGINT NULL, PRINCIPAL DECIMAL(18,2) NULL, JUROS DECIMAL(18,2) NULL, MULTA DECIMAL(18,2) NULL,
                     CORRECAO DECIMAL(18,2) NULL, DESCONTO DECIMAL(18,2) NULL, ABATIMENTO DECIMAL(18,2) NULL, RETENCAO DECIMAL(18,2) NULL,
                     TARIFA DECIMAL(18,2) NULL, ID_LANCAMENTO BIGINT NULL, TIPO CHAR(1) NULL, ID_EMPRESA INT NULL, ID_PLANO_CONTA INT NULL,
                     NUMERO SMALLINT NULL, QTD SMALLINT NULL, SALDO DECIMAL(18,2) NULL, SITUACAO VARCHAR(10) NULL, SITUACAO_LANC VARCHAR(10) NULL,
                     PREVISAO BIT NULL, DT_EMISSAO DATE NULL, PESSOA NVARCHAR(150) NULL, DOCUMENTO NVARCHAR(40) NULL,
                     SUG_JUROS DECIMAL(18,2) NULL, SUG_MULTA DECIMAL(18,2) NULL, CALCULA BIT NULL, DESC_LIMITE DECIMAL(18,2) NULL,
                     ID_BAIXA BIGINT NULL);
    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Forma             = UPPER(LTRIM(RTRIM(ISNULL(@Forma, ''))));
        SET @Documento         = LTRIM(RTRIM(ISNULL(@Documento, N'')));
        SET @Observacao        = LTRIM(RTRIM(ISNULL(@Observacao, N'')));
        SET @Motivo            = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        SET @AvisosConfirmados = ISNULL(@AvisosConfirmados, N'');

        ---------------------------------------------------------------------
        -- 1) Itens
        ---------------------------------------------------------------------
        IF ISJSON(ISNULL(@Itens, N'')) = 1
            INSERT INTO #I (ORDEM, ID_PARCELA, PRINCIPAL, JUROS, MULTA, CORRECAO, DESCONTO, ABATIMENTO, RETENCAO, TARIFA)
            SELECT CONVERT(INT, j.[key]) + 1, x.idParcela, x.principal, ISNULL(x.juros, 0), ISNULL(x.multa, 0), ISNULL(x.correcao, 0),
                   ISNULL(x.desconto, 0), ISNULL(x.abatimento, 0), ISNULL(x.retencao, 0), ISNULL(x.tarifa, 0)
            FROM OPENJSON(@Itens) j
            CROSS APPLY OPENJSON(j.[value]) WITH (idParcela BIGINT '$.idParcela', principal DECIMAL(18,2) '$.principal', juros DECIMAL(18,2) '$.juros',
                                                  multa DECIMAL(18,2) '$.multa', correcao DECIMAL(18,2) '$.correcao', desconto DECIMAL(18,2) '$.desconto',
                                                  abatimento DECIMAL(18,2) '$.abatimento', retencao DECIMAL(18,2) '$.retencao', tarifa DECIMAL(18,2) '$.tarifa') x;

        UPDATE i
           SET i.ID_LANCAMENTO = l.ID_LANCAMENTO, i.TIPO = l.TIPO, i.ID_EMPRESA = l.ID_EMPRESA, i.ID_PLANO_CONTA = l.ID_PLANO_CONTA,
               i.NUMERO = p.NUMERO, i.QTD = p.QTD_PARCELAS, i.SALDO = p.SALDO, i.SITUACAO = p.SITUACAO, i.SITUACAO_LANC = l.SITUACAO,
               i.PREVISAO = l.PREVISAO, i.DT_EMISSAO = l.DT_EMISSAO, i.DOCUMENTO = l.DOCUMENTO,
               i.PESSOA = ISNULL(NULLIF(pe.NOME_FANTASIA, N''), pe.NOME)
        FROM #I i
        INNER JOIN FIN.Parcela p    ON p.ID_PARCELA = i.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        LEFT  JOIN CAD.Pessoa pe    ON pe.ID_PESSOA = l.ID_PESSOA;

        SELECT TOP 1 @Tipo = i.TIPO FROM #I i WHERE i.TIPO IS NOT NULL ORDER BY i.ORDEM;
        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;

        IF NOT EXISTS (SELECT 1 FROM #I)
            SET @Recusa = N'Escolha pelo menos uma parcela para baixar.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #I WHERE ID_LANCAMENTO IS NULL)
            SET @Recusa = N'Parcela não encontrada.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'BAIXAR') = 0
            SET @Recusa = CASE @Tipo WHEN 'P' THEN N'Você não tem permissão para baixar contas a pagar.' ELSE N'Você não tem permissão para baixar contas a receber.' END;
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #I WHERE TIPO <> @Tipo)
            SET @Recusa = N'Baixe as contas a pagar e as contas a receber separadamente.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #I GROUP BY ID_PARCELA HAVING COUNT(*) > 1)
            SET @Recusa = N'A mesma parcela foi escolhida mais de uma vez.';
        IF @Recusa = N'' AND @DtPagamento IS NULL
            SET @Recusa = CASE @Tipo WHEN 'P' THEN N'Informe a data do pagamento.' ELSE N'Informe a data do recebimento.' END;

        SELECT @IdEmpresaConta = c.ID_EMPRESA, @ContaAtiva = c.ATIVO FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta;
        IF @Recusa = N'' AND @ContaAtiva IS NULL
            SET @Recusa = N'Escolha a conta (banco ou caixa).';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID,
                   CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #I;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        UPDATE i
           SET i.SUG_JUROS = s.JUROS, i.SUG_MULTA = s.MULTA, i.CALCULA = s.CALCULA, i.DESC_LIMITE = s.DESCONTO_LIMITE
        FROM #I i
        CROSS APPLY FIN.fn_FIN_Baixa_Sugerir(i.ID_PARCELA, @DtPagamento, i.PRINCIPAL) s;

        ---------------------------------------------------------------------
        -- 2) Regras
        ---------------------------------------------------------------------
        IF @ContaAtiva = 0
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CONTA_INATIVA', 'BLOQUEIO', N'A conta escolhida está desativada.', 'idConta');

        IF @Forma NOT IN ('PIX', 'BOLETO', 'TED', 'DOC', 'DEBITO', 'DINHEIRO', 'CHEQUE', 'PERMUTA', 'CARTAO', 'OUTRA')
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('FORMA', 'BLOQUEIO', N'Escolha a forma de pagamento.', 'forma');

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'PARCELA_SITUACAO', 'BLOQUEIO',
               N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N' de ' + ISNULL(i.PESSOA, N'')
               + CASE WHEN i.SITUACAO_LANC = 'CANCELADO' OR i.SITUACAO = 'CANCELADA' THEN N': está cancelada.'
                      WHEN SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', i.ID_LANCAMENTO) = 1 THEN N': o lançamento está na lixeira.'
                      WHEN i.PREVISAO = 1 THEN N': é uma previsão (tire a marca de previsão no lançamento antes de baixar).'
                      ELSE N': não tem saldo em aberto.' END,
               i.ID_PARCELA, 'itens'
        FROM #I i
        WHERE i.SITUACAO_LANC = 'CANCELADO' OR i.SITUACAO = 'CANCELADA' OR i.PREVISAO = 1 OR i.SALDO <= 0
           OR SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', i.ID_LANCAMENTO) = 1;

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'VALOR', 'BLOQUEIO',
               N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N' de ' + ISNULL(i.PESSOA, N'')
               + CASE WHEN ISNULL(i.PRINCIPAL, 0) <= 0 THEN N': informe o valor a baixar.'
                      WHEN i.PRINCIPAL > i.SALDO THEN N': o valor ' + FORMAT(i.PRINCIPAL, 'N2', 'pt-BR') + N' passa do saldo em aberto ' + FORMAT(i.SALDO, 'N2', 'pt-BR') + N'.'
                      WHEN i.ABATIMENTO > i.PRINCIPAL THEN N': o abatimento passa do valor baixado.'
                      ELSE N': juros, multa, correção, desconto, abatimento, retenção e tarifa não podem ser negativos, e o valor líquido não pode ficar negativo.' END,
               i.ID_PARCELA, 'itens'
        FROM #I i
        WHERE i.SALDO > 0
          AND (ISNULL(i.PRINCIPAL, 0) <= 0 OR i.PRINCIPAL > i.SALDO OR i.ABATIMENTO > i.PRINCIPAL
               OR i.JUROS < 0 OR i.MULTA < 0 OR i.CORRECAO < 0 OR i.DESCONTO < 0 OR i.ABATIMENTO < 0 OR i.RETENCAO < 0 OR i.TARIFA < 0
               OR i.PRINCIPAL + i.JUROS + i.MULTA + i.CORRECAO - i.DESCONTO - i.ABATIMENTO - i.RETENCAO < 0);

        -- mês fechado (conta contábil; regime de caixa: mês do pagamento)
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'MES_FECHADO', 'BLOQUEIO',
               N'O mês ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(m.MES)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(m.MES))
               + N' está fechado para a empresa ' + ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) + N' (conta contábil).', 'dtPagamento'
        FROM #I i
        INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = i.ID_EMPRESA AND m.MES = DATEFROMPARTS(YEAR(@DtPagamento), MONTH(@DtPagamento), 1) AND m.FECHADO = 1
        INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = i.ID_PLANO_CONTA AND pc.CONTABIL = 1
        INNER JOIN CAD.Empresa e      ON e.ID_EMPRESA = i.ID_EMPRESA;

        -- caixa fechado
        IF BANCO.fn_BANCO_Caixa_Recusa(@IdConta, @DtPagamento) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CAIXA_FECHADO', 'BLOQUEIO', BANCO.fn_BANCO_Caixa_Recusa(@IdConta, @DtPagamento), 'dtPagamento');

        -- trava de datas
        IF FIN.fn_FIN_Data_Recusa('BAIXA', @DtPagamento) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_BAIXA', CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LANCAR_RETROATIVO') = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
                    FIN.fn_FIN_Data_Recusa('BAIXA', @DtPagamento), 'dtPagamento');

        -- pendência que bloqueia a baixa (P27): liberação com justificativa
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'PENDENCIA_BLOQUEIA',
               CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LIBERAR_PENDENCIA') = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
               LEFT(N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N' de ' + ISNULL(i.PESSOA, N'')
                    + N': pendência que bloqueia a baixa (' + b.MOTIVO + N')'
                    + CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LIBERAR_PENDENCIA') = 1 THEN N'. Para liberar, informe a justificativa.'
                           ELSE N'. Resolva a pendência ou peça a quem pode liberar.' END, 400),
               i.ID_PARCELA, 'itens'
        FROM #I i
        CROSS APPLY FIN.fn_FIN_Pendencia_Bloqueia(i.ID_LANCAMENTO, i.ID_PARCELA) b
        WHERE b.BLOQUEIA = 1;

        -- desconto acima do limite (só a receber)
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'DESCONTO_LIMITE',
               CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'DESCONTO_LIMITE') = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
               N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N': desconto de ' + FORMAT(i.DESCONTO, 'N2', 'pt-BR')
               + N' passa do limite de ' + FORMAT(i.DESC_LIMITE, 'N2', 'pt-BR')
               + CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'DESCONTO_LIMITE') = 1 THEN N'. Informe o motivo.' ELSE N'. Peça a quem pode dar desconto maior.' END,
               i.ID_PARCELA, 'itens'
        FROM #I i
        WHERE i.DESC_LIMITE IS NOT NULL AND i.DESCONTO > i.DESC_LIMITE;

        -- avisos
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT 'ENCARGO_AJUSTADO', 'AVISO',
               N'Parcela ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD) + N': juros e multa informados ('
               + FORMAT(i.JUROS + i.MULTA, 'N2', 'pt-BR') + N') diferentes do calculado (' + FORMAT(i.SUG_JUROS + i.SUG_MULTA, 'N2', 'pt-BR') + N').',
               i.ID_PARCELA, 'itens'
        FROM #I i
        WHERE i.CALCULA = 1 AND i.JUROS + i.MULTA <> i.SUG_JUROS + i.SUG_MULTA;

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'CONTA_OUTRA_EMPRESA', 'AVISO', N'A conta escolhida é de outra empresa do grupo que não a do lançamento.', 'idConta'
        FROM #I i WHERE i.ID_EMPRESA <> @IdEmpresaConta;

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
        SELECT TOP 1 'PAGTO_ANTES_EMISSAO', 'AVISO',
               N'A data ' + CASE @Tipo WHEN 'P' THEN N'do pagamento' ELSE N'do recebimento' END + N' é anterior à emissão do lançamento ('
               + CONVERT(NVARCHAR(10), i.DT_EMISSAO, 103) + N').', i.ID_PARCELA, 'dtPagamento'
        FROM #I i WHERE @DtPagamento < i.DT_EMISSAO ORDER BY i.ORDEM;

        ---------------------------------------------------------------------
        -- 3) Resultado das regras
        ---------------------------------------------------------------------
        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r
                              ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
        BEGIN
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID,
                   CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #I;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF (EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@Motivo) < 5)
           OR EXISTS (SELECT 1 FROM #Regra r WHERE r.NIVEL = 'AVISO'
                        AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@AvisosConfirmados, N',') s WHERE LTRIM(RTRIM(s.value)) = r.CODIGO))
            SET @Pendente = 1;

        IF @SomenteConferir = 1 OR @Pendente = 1
        BEGIN
            SELECT CAST(CASE WHEN @SomenteConferir = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Pendente = 0 THEN N'Nada a confirmar.'
                             WHEN EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@Motivo) < 5
                                  THEN N'Informe o motivo (justificativa) para gravar a baixa.'
                             ELSE N'Confira os avisos antes de gravar.' END AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID, CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE,
                   @Pendente AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #I;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- 4) Gravação
        ---------------------------------------------------------------------
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @N       = (SELECT COUNT(*) FROM #I);
        SELECT @Liquido = SUM(i.PRINCIPAL + i.JUROS + i.MULTA + i.CORRECAO - i.DESCONTO - i.ABATIMENTO - i.RETENCAO), @Tarifa = SUM(i.TARIFA) FROM #I i;
        SET @Historico = LEFT(CASE @Tipo WHEN 'P' THEN N'Pagamento' ELSE N'Recebimento' END
                         + CASE WHEN @N = 1 THEN (SELECT N' - ' + ISNULL(i.PESSOA, N'') + N' - parc. ' + CONVERT(NVARCHAR(5), i.NUMERO) + N'/' + CONVERT(NVARCHAR(5), i.QTD)
                                                  + CASE WHEN i.DOCUMENTO <> N'' THEN N' - doc. ' + i.DOCUMENTO ELSE N'' END FROM #I i)
                                ELSE N' de ' + CONVERT(NVARCHAR(10), @N) + N' parcelas' END, 200);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdUsuario, @Origem = 'BAIXA', @Descricao = @Historico,
             @TabelaReferencia = N'FIN.Baixa', @IdLote = @IdLote OUTPUT;

        -- trava as parcelas e confere o saldo de novo (concorrência)
        IF EXISTS (SELECT 1 FROM #I i INNER JOIN FIN.Parcela p WITH (UPDLOCK, HOLDLOCK) ON p.ID_PARCELA = i.ID_PARCELA
                   WHERE p.SALDO < i.PRINCIPAL OR p.SITUACAO = 'CANCELADA')
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Uma das parcelas foi alterada por outra pessoa. Abra a baixa de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID, CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #I;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF @Liquido <> 0
        BEGIN
            INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_LOTE, USUARIO_CRIACAO)
            VALUES (@IdConta, @DtPagamento, CASE @Tipo WHEN 'P' THEN -@Liquido ELSE @Liquido END, 'BAIXA', @Historico, @Documento, @IdLote, ISNULL(@Usuario, N'sistema'));
            SET @IdMovimento = SCOPE_IDENTITY();
        END;

        IF @Tarifa > 0
            INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_LOTE, USUARIO_CRIACAO)
            VALUES (@IdConta, @DtPagamento, -@Tarifa, 'TARIFA', LEFT(N'Tarifa - ' + @Historico, 200), @Documento, @IdLote, ISNULL(@Usuario, N'sistema'));

        DECLARE @Ids TABLE (ID_BAIXA BIGINT NOT NULL, ID_PARCELA BIGINT NOT NULL);

        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, JUROS, MULTA, CORRECAO, DESCONTO, ABATIMENTO,
                               TARIFA, RETENCAO, ID_MOVIMENTO, COMPENSADO, OBSERVACAO, ID_LOTE, USUARIO_CRIACAO)
        OUTPUT inserted.ID_BAIXA, inserted.ID_PARCELA INTO @Ids (ID_BAIXA, ID_PARCELA)
        SELECT i.ID_PARCELA, @DtPagamento, @IdConta, @Forma, i.PRINCIPAL, i.JUROS, i.MULTA, i.CORRECAO, i.DESCONTO, i.ABATIMENTO,
               i.TARIFA, i.RETENCAO, @IdMovimento, CASE WHEN @Forma = 'CHEQUE' THEN 0 ELSE 1 END, @Observacao, @IdLote, ISNULL(@Usuario, N'sistema')
        FROM #I i
        ORDER BY i.ORDEM;

        UPDATE i SET i.ID_BAIXA = d.ID_BAIXA FROM #I i INNER JOIN @Ids d ON d.ID_PARCELA = i.ID_PARCELA;
        SELECT TOP 1 @IdPrimeira = i.ID_BAIXA FROM #I i ORDER BY i.ORDEM;

        -- avisos confirmados e motivos (na baixa da parcela citada; os gerais na primeira)
        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'FIN.Baixa', ISNULL(i.ID_BAIXA, @IdPrimeira), r.CODIGO, r.NIVEL, r.MENSAGEM,
               CASE WHEN r.NIVEL = 'MOTIVO' THEN @Motivo ELSE N'' END, r.ID_REFERENCIA, @IdUsuario, ISNULL(@Usuario, N'sistema')
        FROM #Regra r
        LEFT JOIN #I i ON i.ID_PARCELA = r.ID_REFERENCIA
        WHERE r.NIVEL IN ('AVISO', 'MOTIVO');

        EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = @N;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @N = 1 THEN CASE @Tipo WHEN 'P' THEN N'Pagamento gravado.' ELSE N'Recebimento gravado.' END
                         ELSE CONVERT(NVARCHAR(10), @N) + CASE @Tipo WHEN 'P' THEN N' pagamentos gravados.' ELSE N' recebimentos gravados.' END END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPrimeira AS ID, @IdMovimento AS ID_MOVIMENTO, @IdLote AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #I;
        DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #I;
        DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a baixa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID, CAST(NULL AS BIGINT) AS ID_MOVIMENTO, CAST(NULL AS BIGINT) AS ID_LOTE, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO
