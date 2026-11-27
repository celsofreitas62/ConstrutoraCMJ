/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Inclui (@IdLancamento NULL) ou altera um lançamento a pagar (P)
                ou a receber (R) com as suas parcelas (telas Contas a pagar e
                Contas a receber, etapa 04f). Tudo-ou-nada.
                @Parcelas: JSON [{"id":null|ID_PARCELA,"vencimento":"aaaa-mm-dd",
                "valor":100.00,"idContaPrevista":null}]; a numeração é refeita
                pela ordem de vencimento. Parcela existente fora da lista é
                retirada (só sem nenhuma baixa, nem estornada). Empresa vem do centro de custo.
                Proteções contra erro de digitação (P17), conferidas aqui e na
                prévia (@SomenteConferir = 1, usada por FIN_Lancamento_Conferir):
                  BLOQUEIO  não grava (fixos: parceiro/centro/conta inativos,
                            mês fechado de conta contábil, trava de datas sem a
                            permissão LANCAR_RETROATIVO; e as regras FIN_REGRA_*
                            com BLOQUEIO, CENTRO_ENCERRADO_BLOQUEIA = S);
                  MOTIVO    trava de datas para quem tem LANCAR_RETROATIVO:
                            grava só com @MotivoRetroativo;
                  AVISO     grava só se o código vier em @AvisosConfirmados
                            (lista separada por vírgula).
                Avisos confirmados e motivos ficam em SIS.Aviso_Confirmado.
                Em alteração, cada regra só olha o que mudou. Com baixa, ficam
                travados o parceiro, o valor total e as parcelas com baixa.
                Duplicidade de documento: só documento com número (no Access o
                campo também guardava textos como "Pis, Cofins e CSLL").
                @MarcarTipoParceiro = 1: marca o tipo Fornecedor (P) ou Cliente
                (R) no parceiro (resposta ao aviso TIPO_PARCEIRO).
                Permissão: INCLUIR ou ALTERAR em FIN_PAGAR / FIN_RECEBER.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID, PENDENTE (há avisos a
                confirmar ou motivo a informar) e AVISOS (JSON: codigo, nivel,
                mensagem, idReferencia, campo).
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
    v1.1 (26/11/2026) - Etapa 04f2b: integração em branco vale COMPLETA (a API
                        manda texto vazio quando a ficha não informa).

    v1.2 (27/11/2026) - Etapa 04g4: só a baixa viva (não estornada) trava
                        parceiro, valor total e parcela (fn_FIN_Parcela_Baixa_Viva);
                        parcela só com baixa estornada muda, mas não sai.
  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = 2, @Tipo = 'P', @IdCentroCusto = 1, @IdPessoa = 1, @IdPlanoConta = 1,
    --      @DtEmissao = '2026-11-25', @ValorTotal = 100, @Parcelas = N'[{"vencimento":"2026-12-10","valor":100}]', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Gravar]
    @IdUsuario           INT,
    @IdLancamento        BIGINT          = NULL,
    @Tipo                CHAR(1)         = NULL,
    @IdCentroCusto       INT             = NULL,
    @IdPessoa            INT             = NULL,
    @IdPlanoConta        INT             = NULL,
    @IdHistoricoPadrao   INT             = NULL,
    @Documento           NVARCHAR(40)    = NULL,
    @DtEmissao           DATE            = NULL,
    @DtCompetencia       DATE            = NULL,
    @Historico           NVARCHAR(200)   = NULL,
    @Observacao          NVARCHAR(2000)  = NULL,
    @ValorTotal          DECIMAL(18,2)   = NULL,
    @Previsao            BIT             = 0,
    @Integracao          VARCHAR(12)     = NULL,
    @Parcelas            NVARCHAR(MAX)   = NULL,
    @AvisosConfirmados   NVARCHAR(1000)  = NULL,
    @MotivoRetroativo    NVARCHAR(400)   = NULL,
    @MarcarTipoParceiro  BIT             = 0,
    @SomenteConferir     BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Gravar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @Item         VARCHAR(40);
    DECLARE @Hoje         DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Novo         BIT;
    DECLARE @Avisos       NVARCHAR(MAX) = N'[]';
    DECLARE @Pendente     BIT = 0;
    DECLARE @Nivel        VARCHAR(12);
    DECLARE @N            INT;
    DECLARE @Meses        INT;
    DECLARE @V            DECIMAL(18,6);
    DECLARE @Soma         DECIMAL(18,2);
    DECLARE @IdEmpresa    INT;
    DECLARE @TemBaixa     BIT = 0;
    DECLARE @PodeRetro    BIT = 0;
    DECLARE @IdTipoMarcar INT;
    DECLARE @IdTipoNA     INT;

    -- valores atuais (alteração)
    DECLARE @aTipo CHAR(1), @aCentro INT, @aPessoa INT, @aPlano INT, @aDocumento NVARCHAR(40), @aEmissao DATE,
            @aCompetencia DATE, @aValor DECIMAL(18,2), @aOrigem VARCHAR(15), @aSituacao VARCHAR(10), @aEmpresa INT;
    DECLARE @MudouPessoa BIT = 1, @MudouPlano BIT = 1, @MudouCentro BIT = 1, @MudouEmissao BIT = 1,
            @MudouCompetencia BIT = 1, @MudouValor BIT = 1, @MudouDocumento BIT = 1;

    DROP TABLE IF EXISTS #P;
    DROP TABLE IF EXISTS #Regra;
    CREATE TABLE #P (CHAVE INT NOT NULL, ID_PARCELA BIGINT NULL, DT_VENCIMENTO DATE NULL, VALOR DECIMAL(18,2) NULL,
                     ID_CONTA_PREVISTA INT NULL, NUMERO SMALLINT NULL, MUDOU BIT NOT NULL DEFAULT (1));
    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Novo               = CASE WHEN @IdLancamento IS NULL THEN 1 ELSE 0 END;
        SET @Documento          = LTRIM(RTRIM(ISNULL(@Documento, N'')));
        SET @Historico          = LTRIM(RTRIM(ISNULL(@Historico, N'')));
        SET @Observacao         = LTRIM(RTRIM(ISNULL(@Observacao, N'')));
        SET @Integracao         = UPPER(LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(@Integracao)), ''), 'COMPLETA'))));
        SET @Previsao           = ISNULL(@Previsao, 0);
        SET @MotivoRetroativo   = LTRIM(RTRIM(ISNULL(@MotivoRetroativo, N'')));
        SET @AvisosConfirmados  = UPPER(ISNULL(@AvisosConfirmados, N''));
        SET @MarcarTipoParceiro = ISNULL(@MarcarTipoParceiro, 0);
        SET @SomenteConferir    = ISNULL(@SomenteConferir, 0);

        ---------------------------------------------------------------------
        -- 1) Situação atual (alteração) e permissão
        ---------------------------------------------------------------------
        IF @Novo = 0
        BEGIN
            SELECT @aTipo = l.TIPO, @aCentro = l.ID_CENTRO_CUSTO, @aPessoa = l.ID_PESSOA, @aPlano = l.ID_PLANO_CONTA,
                   @aDocumento = l.DOCUMENTO, @aEmissao = l.DT_EMISSAO, @aCompetencia = l.DT_COMPETENCIA, @aValor = l.VALOR_TOTAL,
                   @aOrigem = l.ORIGEM, @aSituacao = l.SITUACAO, @aEmpresa = l.ID_EMPRESA
            FROM FIN.Lancamento l
            WHERE l.ID_LANCAMENTO = @IdLancamento;

            IF @aTipo IS NULL
                SET @Recusa = N'Lançamento não encontrado.';
            ELSE
                SET @Tipo = @aTipo;

            -- só baixa viva (não estornada) trava o lançamento (04g4)
            IF EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_LANCAMENTO = @IdLancamento AND EXISTS (SELECT 1 FROM FIN.fn_FIN_Parcela_Baixa_Viva(p.ID_PARCELA)))
                SET @TemBaixa = 1;
        END;

        SET @Tipo = UPPER(ISNULL(@Tipo, ''));
        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' WHEN 'R' THEN 'FIN_RECEBER' ELSE '' END;

        IF @Recusa = N'' AND @Item = ''
            SET @Recusa = N'Informe se o lançamento é a pagar ou a receber.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, CASE WHEN @Novo = 1 THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para ' + CASE WHEN @Novo = 1 THEN N'incluir' ELSE N'alterar' END
                        + N' contas a ' + CASE @Tipo WHEN 'P' THEN N'pagar.' ELSE N'receber.' END;
        IF @Recusa = N'' AND @Novo = 0 AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento) = 1
            SET @Recusa = N'O lançamento está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @Novo = 0 AND @aSituacao = 'CANCELADO'
            SET @Recusa = N'O lançamento está cancelado e não pode ser alterado.';
        IF @Recusa = N'' AND @Novo = 0 AND @aOrigem NOT IN ('MANUAL', 'MIGRACAO')
            SET @Recusa = N'Este lançamento foi gerado por outra rotina (' + CONVERT(NVARCHAR(15), @aOrigem) + N'): altere pela tela de origem.';

        ---------------------------------------------------------------------
        -- 2) Campos do documento
        ---------------------------------------------------------------------
        IF @Recusa = N'' AND @IdCentroCusto IS NULL AND (@Novo = 1 OR @aCentro IS NOT NULL)
            SET @Recusa = N'Escolha o centro de custo (obra ou setor).';
        IF @Recusa = N'' AND @IdPessoa IS NULL AND (@Novo = 1 OR @aPessoa IS NOT NULL)
            SET @Recusa = N'Escolha o parceiro (' + CASE @Tipo WHEN 'P' THEN N'fornecedor' ELSE N'cliente' END + N').';
        IF @Recusa = N'' AND @IdPlanoConta IS NULL AND (@Novo = 1 OR @aPlano IS NOT NULL)
            SET @Recusa = N'Escolha a conta do plano de contas.';
        IF @Recusa = N'' AND @DtEmissao IS NULL
            SET @Recusa = N'Informe a data de emissão do documento.';
        IF @Recusa = N'' AND @DtEmissao NOT BETWEEN '1990-01-01' AND '2099-12-31'
            SET @Recusa = N'Data de emissão inválida: confira o ano.';
        IF @Recusa = N'' AND ISNULL(@ValorTotal, 0) <= 0
            SET @Recusa = N'Informe o valor total (maior que zero).';
        IF @Recusa = N'' AND @Integracao NOT IN ('COMPLETA', 'SO_CONTABIL', 'NENHUMA')
            SET @Recusa = N'Integração inválida.';
        IF @Recusa = N'' AND @IdHistoricoPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM FIN.Historico_Padrao h WHERE h.ID_HISTORICO_PADRAO = @IdHistoricoPadrao AND h.ATIVO = 1)
            SET @Recusa = N'O histórico padrão escolhido não existe ou está desativado.';
        IF @Recusa = N'' AND @IdCentroCusto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCentroCusto)
            SET @Recusa = N'Centro de custo não encontrado.';
        IF @Recusa = N'' AND @IdPessoa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa)
            SET @Recusa = N'Parceiro não encontrado.';
        IF @Recusa = N'' AND @IdPlanoConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @IdPlanoConta)
            SET @Recusa = N'Conta do plano não encontrada.';

        IF @DtEmissao IS NOT NULL
            SET @DtCompetencia = DATEFROMPARTS(YEAR(ISNULL(@DtCompetencia, @DtEmissao)), MONTH(ISNULL(@DtCompetencia, @DtEmissao)), 1);
        SELECT @IdEmpresa = c.ID_EMPRESA FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCentroCusto;
        SET @IdEmpresa = ISNULL(@IdEmpresa, @aEmpresa);
        IF @Recusa = N'' AND @IdEmpresa IS NULL
            SET @Recusa = N'Escolha o centro de custo (a empresa vem dele).';

        IF @Novo = 0
        BEGIN
            SET @MudouPessoa      = CASE WHEN ISNULL(@IdPessoa, 0)      = ISNULL(@aPessoa, 0)  THEN 0 ELSE 1 END;
            SET @MudouPlano       = CASE WHEN ISNULL(@IdPlanoConta, 0)  = ISNULL(@aPlano, 0)   THEN 0 ELSE 1 END;
            SET @MudouCentro      = CASE WHEN ISNULL(@IdCentroCusto, 0) = ISNULL(@aCentro, 0)  THEN 0 ELSE 1 END;
            SET @MudouEmissao     = CASE WHEN @DtEmissao = @aEmissao         THEN 0 ELSE 1 END;
            SET @MudouCompetencia = CASE WHEN @DtCompetencia = @aCompetencia THEN 0 ELSE 1 END;
            SET @MudouValor       = CASE WHEN @ValorTotal = @aValor          THEN 0 ELSE 1 END;
            SET @MudouDocumento   = CASE WHEN @Documento = ISNULL(@aDocumento, N'') COLLATE Latin1_General_CI_AI THEN 0 ELSE 1 END;
        END;

        IF @Recusa = N'' AND @TemBaixa = 1 AND @MudouPessoa = 1
            SET @Recusa = N'O lançamento já tem pagamento ou recebimento: o parceiro não pode mudar.';
        IF @Recusa = N'' AND @TemBaixa = 1 AND @MudouValor = 1
            SET @Recusa = N'O lançamento já tem pagamento ou recebimento: o valor total não pode mudar (ajuste só as parcelas em aberto).';

        ---------------------------------------------------------------------
        -- 3) Parcelas
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Parcelas';
        IF @Recusa = N'' AND (ISNULL(@Parcelas, N'') = N'' OR ISJSON(@Parcelas) = 0)
            SET @Recusa = N'Informe ao menos uma parcela (use "Gerar parcelas").';

        IF @Recusa = N''
        BEGIN
            INSERT INTO #P (CHAVE, ID_PARCELA, DT_VENCIMENTO, VALOR, ID_CONTA_PREVISTA)
            SELECT CONVERT(INT, k.[key]), j.id, TRY_CONVERT(DATE, j.vencimento, 23), j.valor, j.idContaPrevista
            FROM OPENJSON(@Parcelas) k
            CROSS APPLY OPENJSON(k.value) WITH (id BIGINT '$.id', vencimento VARCHAR(10) '$.vencimento',
                                                valor DECIMAL(18,2) '$.valor', idContaPrevista INT '$.idContaPrevista') j
            WHERE k.[type] = 5;

            SET @N    = (SELECT COUNT(*) FROM #P);
            SET @Soma = (SELECT ISNULL(SUM(x.VALOR), 0) FROM #P x);

            IF @N = 0
                SET @Recusa = N'Informe ao menos uma parcela (use "Gerar parcelas").';
            ELSE IF @N > 480
                SET @Recusa = N'No máximo 480 parcelas por lançamento.';
            ELSE IF EXISTS (SELECT 1 FROM #P WHERE DT_VENCIMENTO IS NULL OR DT_VENCIMENTO NOT BETWEEN '1990-01-01' AND '2099-12-31')
                SET @Recusa = N'Parcela ' + (SELECT TOP 1 CONVERT(NVARCHAR(5), CHAVE + 1) FROM #P
                                              WHERE DT_VENCIMENTO IS NULL OR DT_VENCIMENTO NOT BETWEEN '1990-01-01' AND '2099-12-31' ORDER BY CHAVE)
                            + N': informe um vencimento válido.';
            ELSE IF EXISTS (SELECT 1 FROM #P WHERE ISNULL(VALOR, 0) <= 0)
                SET @Recusa = N'Parcela ' + (SELECT TOP 1 CONVERT(NVARCHAR(5), CHAVE + 1) FROM #P WHERE ISNULL(VALOR, 0) <= 0 ORDER BY CHAVE)
                            + N': informe um valor maior que zero.';
            ELSE IF @Soma <> @ValorTotal
                SET @Recusa = N'A soma das parcelas (' + SIS.fn_SIS_Formatar_Moeda(@Soma)
                            + N') é diferente do valor total (' + SIS.fn_SIS_Formatar_Moeda(@ValorTotal) + N').';
            ELSE IF EXISTS (SELECT 1 FROM #P x WHERE x.ID_PARCELA IS NOT NULL
                              AND NOT EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_PARCELA = x.ID_PARCELA AND p.ID_LANCAMENTO = ISNULL(@IdLancamento, 0)))
                SET @Recusa = N'Parcela de outro lançamento na lista: abra a ficha de novo.';
            ELSE IF EXISTS (SELECT x.ID_PARCELA FROM #P x WHERE x.ID_PARCELA IS NOT NULL GROUP BY x.ID_PARCELA HAVING COUNT(*) > 1)
                SET @Recusa = N'Parcela repetida na lista: abra a ficha de novo.';
            ELSE IF EXISTS (SELECT 1 FROM #P x WHERE x.ID_CONTA_PREVISTA IS NOT NULL
                              AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = x.ID_CONTA_PREVISTA AND c.DT_EXCLUSAO IS NULL
                                                AND (c.ATIVO = 1 OR EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_PARCELA = x.ID_PARCELA AND p.ID_CONTA_PREVISTA = c.ID_CONTA))))
                SET @Recusa = N'A conta bancária prevista de uma parcela não existe ou está desativada.';
        END;

        IF @Recusa = N'' AND @Novo = 0
        BEGIN
            UPDATE x
               SET x.MUDOU = CASE WHEN p.DT_VENCIMENTO = x.DT_VENCIMENTO AND p.VALOR = x.VALOR THEN 0 ELSE 1 END
            FROM #P x
            INNER JOIN FIN.Parcela p ON p.ID_PARCELA = x.ID_PARCELA;

            -- parcelas com baixa viva: não mudam e não saem
            IF EXISTS (SELECT 1 FROM FIN.Parcela p
                       WHERE p.ID_LANCAMENTO = @IdLancamento
                         AND EXISTS (SELECT 1 FROM FIN.fn_FIN_Parcela_Baixa_Viva(p.ID_PARCELA))
                         AND NOT EXISTS (SELECT 1 FROM #P x WHERE x.ID_PARCELA = p.ID_PARCELA AND x.MUDOU = 0))
                SET @Recusa = N'Parcela com pagamento ou recebimento não pode mudar de vencimento ou valor, nem ser retirada.';
            -- parcela só com baixa estornada: pode mudar, mas não sai (guarda o histórico)
            ELSE IF EXISTS (SELECT 1 FROM FIN.Parcela p
                            WHERE p.ID_LANCAMENTO = @IdLancamento
                              AND EXISTS (SELECT 1 FROM FIN.Baixa b WHERE b.ID_PARCELA = p.ID_PARCELA)
                              AND NOT EXISTS (SELECT 1 FROM #P x WHERE x.ID_PARCELA = p.ID_PARCELA))
                SET @Recusa = N'Parcela com baixa estornada não pode ser retirada (guarda o histórico); mude o vencimento ou o valor dela.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID,
                   CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #P;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        WITH n AS (SELECT x.NUMERO, ROW_NUMBER() OVER (ORDER BY x.DT_VENCIMENTO, x.CHAVE) AS NOVO FROM #P x)
        UPDATE n SET n.NUMERO = n.NOVO;

        ---------------------------------------------------------------------
        -- 4) Regras (P17)
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Regras';
        SET @PodeRetro = SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LANCAR_RETROATIVO');

        -- cadastros inativos (bloqueio fixo)
        IF @MudouPessoa = 1 AND @IdPessoa IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa AND (p.ATIVO = 0 OR p.DT_EXCLUSAO IS NOT NULL))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('PARCEIRO_INATIVO', 'BLOQUEIO', N'O parceiro escolhido está desativado ou na lixeira.', 'idPessoa');
        IF @MudouCentro = 1 AND @IdCentroCusto IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCentroCusto AND (c.ATIVO = 0 OR c.DT_EXCLUSAO IS NOT NULL))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CENTRO_INATIVO', 'BLOQUEIO', N'O centro de custo escolhido está desativado ou na lixeira.', 'idCentroCusto');
        IF @MudouPlano = 1 AND @IdPlanoConta IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.vw_CAD_Plano_Conta v INNER JOIN CAD.Plano_Conta c ON c.ID_PLANO_CONTA = v.ID_PLANO_CONTA
                       WHERE v.ID_PLANO_CONTA = @IdPlanoConta AND (v.ATIVO_EFETIVO = 0 OR c.DT_EXCLUSAO IS NOT NULL))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CONTA_INATIVA', 'BLOQUEIO', N'A conta do plano escolhida está desativada ou na lixeira.', 'idPlanoConta');

        -- centro de custo encerrado
        IF (@MudouCentro = 1 OR @MudouEmissao = 1)
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT 'CENTRO_ENCERRADO', CASE WHEN ISNULL(SIS.fn_SIS_Parametro_SN('CENTRO_ENCERRADO_BLOQUEIA'), 1) = 1 THEN 'BLOQUEIO' ELSE 'AVISO' END,
                   N'O centro de custo ' + CONVERT(NVARCHAR(20), c.CODIGO) + N' foi encerrado em ' + CONVERT(NVARCHAR(10), c.DT_ENCERRAMENTO, 103) + N'.', 'idCentroCusto'
            FROM CAD.Centro_Custo c
            WHERE c.ID_CENTRO_CUSTO = @IdCentroCusto AND c.DT_ENCERRAMENTO <= @DtEmissao;

        -- mês fechado (só conta contábil; olha o mês novo e, na alteração, o atual)
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'MES_FECHADO', 'BLOQUEIO',
               N'O mês ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(m.MES)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(m.MES))
               + N' está fechado para a empresa ' + ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) + N' (conta contábil).', 'dtCompetencia'
        FROM (SELECT @IdEmpresa AS EMP, @DtCompetencia AS MES, @IdPlanoConta AS PLANO
              UNION ALL SELECT @aEmpresa, @aCompetencia, @aPlano WHERE @Novo = 0) x
        INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = x.EMP AND m.MES = x.MES AND m.FECHADO = 1
        INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = x.PLANO AND pc.CONTABIL = 1
        INNER JOIN CAD.Empresa e      ON e.ID_EMPRESA = x.EMP
        ORDER BY m.MES;

        -- trava de datas (bloqueio, ou motivo para quem tem LANCAR_RETROATIVO)
        IF @MudouEmissao = 1 AND FIN.fn_FIN_Data_Recusa('EMISSAO', @DtEmissao) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_EMISSAO', CASE WHEN @PodeRetro = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END, FIN.fn_FIN_Data_Recusa('EMISSAO', @DtEmissao), 'dtEmissao');

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'DATA_VENCIMENTO', CASE WHEN @PodeRetro = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
               N'Parcela ' + CONVERT(NVARCHAR(5), x.NUMERO) + N': ' + FIN.fn_FIN_Data_Recusa('VENCIMENTO', x.DT_VENCIMENTO), 'parcelas'
        FROM #P x
        WHERE x.MUDOU = 1 AND FIN.fn_FIN_Data_Recusa('VENCIMENTO', x.DT_VENCIMENTO) <> N''
        ORDER BY x.NUMERO;

        -- data a confirmar (dentro do permitido, mas distante de hoje)
        SET @N = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_DATA_AVISO_DIAS'), 3);
        IF @MudouEmissao = 1 AND ABS(DATEDIFF(DAY, @Hoje, @DtEmissao)) > @N AND NOT EXISTS (SELECT 1 FROM #Regra WHERE CODIGO = 'DATA_EMISSAO')
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_CONFIRMAR', 'AVISO', N'Confirma a data de emissão ' + CONVERT(NVARCHAR(10), @DtEmissao, 103) + N'?', 'dtEmissao');
        IF NOT EXISTS (SELECT 1 FROM #Regra WHERE CODIGO IN ('DATA_VENCIMENTO', 'DATA_CONFIRMAR'))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT TOP 1 'DATA_CONFIRMAR', 'AVISO',
                   N'Confirma o vencimento ' + CONVERT(NVARCHAR(10), x.DT_VENCIMENTO, 103) + N' (parcela ' + CONVERT(NVARCHAR(5), x.NUMERO) + N', já passado)?', 'parcelas'
            FROM #P x
            WHERE x.MUDOU = 1 AND x.DT_VENCIMENTO < DATEADD(DAY, -@N, @Hoje)
            ORDER BY x.NUMERO;

        -- vencimento antes da emissão
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_VENC_ANTES_EMISSAO');
        IF @Nivel <> 'NAO'
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT TOP 1 'VENC_ANTES_EMISSAO', @Nivel,
                   N'A parcela ' + CONVERT(NVARCHAR(5), x.NUMERO) + N' vence em ' + CONVERT(NVARCHAR(10), x.DT_VENCIMENTO, 103)
                   + N', antes da emissão (' + CONVERT(NVARCHAR(10), @DtEmissao, 103) + N').', 'parcelas'
            FROM #P x
            WHERE (x.MUDOU = 1 OR @MudouEmissao = 1) AND x.DT_VENCIMENTO < @DtEmissao
            ORDER BY x.NUMERO;

        -- competência distante da emissão
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_COMPETENCIA_DISTANTE');
        SET @N = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_COMPETENCIA_MESES'), 3);
        SET @Meses = ABS(DATEDIFF(MONTH, @DtEmissao, @DtCompetencia));
        IF @Nivel <> 'NAO' AND (@MudouEmissao = 1 OR @MudouCompetencia = 1) AND @Meses > @N
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('COMPETENCIA_DISTANTE', @Nivel,
                    N'A competência ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(@DtCompetencia)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(@DtCompetencia))
                    + N' está a ' + CONVERT(NVARCHAR(5), @Meses) + N' meses da emissão.', 'dtCompetencia');

        -- mesmo parceiro e mesmo documento (só documento com número)
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_DUPLIC_DOCUMENTO');
        IF @Nivel <> 'NAO' AND @IdPessoa IS NOT NULL AND @Documento LIKE N'%[0-9]%' AND (@MudouDocumento = 1 OR @MudouPessoa = 1)
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
            SELECT TOP 1 'DUPLIC_DOCUMENTO', @Nivel,
                   N'O documento ' + l.DOCUMENTO + N' deste parceiro já foi lançado (nº ' + CONVERT(NVARCHAR(20), l.ID_LANCAMENTO)
                   + N', emissão ' + CONVERT(NVARCHAR(10), l.DT_EMISSAO, 103) + N', ' + SIS.fn_SIS_Formatar_Moeda(l.VALOR_TOTAL) + N').',
                   l.ID_LANCAMENTO, 'documento'
            FROM FIN.Lancamento l WITH (NOLOCK)
            WHERE l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.DOCUMENTO = @Documento
              AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL AND l.ID_LANCAMENTO <> ISNULL(@IdLancamento, 0)
            ORDER BY l.DT_EMISSAO DESC, l.ID_LANCAMENTO DESC;

        -- possível duplicidade: mesmo parceiro, mesmo valor de parcela, vencimento próximo
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_DUPLIC_VALOR');
        SET @N = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_DUPLIC_VALOR_DIAS'), 5);
        IF @Nivel <> 'NAO' AND @IdPessoa IS NOT NULL
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
            SELECT TOP 1 'DUPLIC_VALOR', @Nivel,
                   N'Possível duplicidade: o lançamento nº ' + CONVERT(NVARCHAR(20), l.ID_LANCAMENTO) + N' deste parceiro tem parcela de '
                   + SIS.fn_SIS_Formatar_Moeda(p.VALOR) + N' com vencimento em ' + CONVERT(NVARCHAR(10), p.DT_VENCIMENTO, 103) + N'.',
                   l.ID_LANCAMENTO, 'parcelas'
            FROM #P x
            INNER JOIN FIN.Parcela p    WITH (NOLOCK) ON p.VALOR = x.VALOR AND p.SITUACAO <> 'CANCELADA'
                                                     AND p.DT_VENCIMENTO BETWEEN DATEADD(DAY, -@N, x.DT_VENCIMENTO) AND DATEADD(DAY, @N, x.DT_VENCIMENTO)
            INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
            WHERE (x.MUDOU = 1 OR @MudouPessoa = 1)
              AND l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL
              AND l.ID_LANCAMENTO <> ISNULL(@IdLancamento, 0)
              AND NOT EXISTS (SELECT 1 FROM #Regra r WHERE r.CODIGO = 'DUPLIC_DOCUMENTO' AND r.ID_REFERENCIA = l.ID_LANCAMENTO)
            ORDER BY ABS(DATEDIFF(DAY, x.DT_VENCIMENTO, p.DT_VENCIMENTO)), l.ID_LANCAMENTO DESC;

        -- valor fora do padrão (média do mesmo parceiro e conta do plano)
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_VALOR_FORA_PADRAO');
        IF @Nivel <> 'NAO' AND @IdPessoa IS NOT NULL AND @IdPlanoConta IS NOT NULL AND (@MudouValor = 1 OR @MudouPessoa = 1 OR @MudouPlano = 1)
        BEGIN
            SET @V     = ISNULL(SIS.fn_SIS_Parametro_Decimal('FIN_VALOR_FORA_PADRAO_VEZES'), 3);
            SET @N     = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_VALOR_FORA_PADRAO_MIN_HIST'), 3);
            SET @Meses = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_VALOR_FORA_PADRAO_MESES'), 12);
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT 'VALOR_FORA_PADRAO', @Nivel,
                   N'O valor ' + SIS.fn_SIS_Formatar_Moeda(@ValorTotal) + N' é ' + CONVERT(NVARCHAR(20), CAST(ROUND(@ValorTotal / NULLIF(h.MEDIA, 0), 1) AS DECIMAL(18,1)))
                   + N' vezes a média (' + SIS.fn_SIS_Formatar_Moeda(CAST(h.MEDIA AS DECIMAL(18,2))) + N') dos últimos ' + CONVERT(NVARCHAR(10), h.QTD)
                   + N' lançamentos deste parceiro nesta conta.', 'valorTotal'
            FROM (SELECT COUNT(*) AS QTD, AVG(l.VALOR_TOTAL) AS MEDIA
                  FROM FIN.Lancamento l WITH (NOLOCK)
                  WHERE l.ID_PESSOA = @IdPessoa AND l.ID_PLANO_CONTA = @IdPlanoConta AND l.TIPO = @Tipo
                    AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL AND l.ID_LANCAMENTO <> ISNULL(@IdLancamento, 0)
                    AND l.DT_EMISSAO >= DATEADD(MONTH, -@Meses, @DtEmissao)
                    AND l.DT_EMISSAO <= @DtEmissao) h
            WHERE h.QTD >= @N AND h.MEDIA > 0 AND @ValorTotal > h.MEDIA * @V;
        END;

        -- parceiro sem o tipo Fornecedor / Cliente
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_TIPO_PARCEIRO');
        IF @Nivel <> 'NAO' AND @MudouPessoa = 1 AND @MarcarTipoParceiro = 0
           AND EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa AND ((@Tipo = 'P' AND p.FORNECEDOR = 0) OR (@Tipo = 'R' AND p.CLIENTE = 0)))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('TIPO_PARCEIRO', @Nivel, N'O parceiro não está marcado como ' + CASE @Tipo WHEN 'P' THEN N'Fornecedor' ELSE N'Cliente' END + N'.', 'idPessoa');

        -- conta de receita no a pagar, ou de despesa no a receber
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_TIPO_CONTA');
        IF @Nivel <> 'NAO' AND @MudouPlano = 1
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT 'TIPO_CONTA', @Nivel,
                   N'A conta ' + CONVERT(NVARCHAR(12), v.CODIGO) + N' - ' + v.DESCRICAO + N' é de ' + CASE v.TIPO WHEN 'RECEITA' THEN N'receita' ELSE N'despesa' END
                   + N' e o lançamento é a ' + CASE @Tipo WHEN 'P' THEN N'pagar.' ELSE N'receber.' END, 'idPlanoConta'
            FROM CAD.vw_CAD_Plano_Conta v
            WHERE v.ID_PLANO_CONTA = @IdPlanoConta AND ((@Tipo = 'P' AND v.TIPO = 'RECEITA') OR (@Tipo = 'R' AND v.TIPO = 'DESPESA'));

        ---------------------------------------------------------------------
        -- 5) Resultado das regras
        ---------------------------------------------------------------------
        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r
                              ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
        BEGIN
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID,
                   CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #P;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF (EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@MotivoRetroativo) < 5)
           OR EXISTS (SELECT 1 FROM #Regra r WHERE r.NIVEL = 'AVISO'
                        AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@AvisosConfirmados, N',') s WHERE LTRIM(RTRIM(s.value)) = r.CODIGO))
            SET @Pendente = 1;

        IF @SomenteConferir = 1 OR @Pendente = 1
        BEGIN
            SELECT CAST(CASE WHEN @SomenteConferir = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Pendente = 0 THEN N'Nada a confirmar.'
                             WHEN EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@MotivoRetroativo) < 5
                                  THEN N'Data fora da trava de datas: informe o motivo para gravar.'
                             ELSE N'Confira os avisos antes de gravar.' END AS NVARCHAR(400)) AS MENSAGEM,
                   @IdLancamento AS ID, @Pendente AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #P;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- 6) Gravação
        ---------------------------------------------------------------------
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @N = (SELECT COUNT(*) FROM #P);
        SELECT @IdTipoMarcar = t.ID_PARCEIRO_TIPO FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = CASE @Tipo WHEN 'P' THEN 'FORNECEDOR' ELSE 'CLIENTE' END;
        SELECT @IdTipoNA = t.ID_PARCEIRO_TIPO FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = 'NA';

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- duplicidade de documento conferida de novo com trava (regra 22)
        IF FIN.fn_FIN_Regra_Nivel('FIN_REGRA_DUPLIC_DOCUMENTO') = 'BLOQUEIO' AND @IdPessoa IS NOT NULL AND @Documento LIKE N'%[0-9]%'
           AND (@MudouDocumento = 1 OR @MudouPessoa = 1)
           AND EXISTS (SELECT 1 FROM FIN.Lancamento l WITH (UPDLOCK, HOLDLOCK)
                       WHERE l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.DOCUMENTO = @Documento
                         AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL AND l.ID_LANCAMENTO <> ISNULL(@IdLancamento, 0))
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Este documento deste parceiro acabou de ser lançado por outra pessoa.' AS NVARCHAR(400)) AS MENSAGEM,
                   @IdLancamento AS ID, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #P;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF @Novo = 1
        BEGIN
            INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, ID_CENTRO_CUSTO, ID_PESSOA, ID_PLANO_CONTA, ID_HISTORICO_PADRAO, DOCUMENTO,
                                        DT_EMISSAO, DT_COMPETENCIA, HISTORICO, OBSERVACAO, VALOR_TOTAL, ORIGEM, SITUACAO, PREVISAO,
                                        INTEGRACAO, USUARIO_CRIACAO)
            VALUES (@Tipo, @IdEmpresa, @IdCentroCusto, @IdPessoa, @IdPlanoConta, @IdHistoricoPadrao, ISNULL(@Documento, N''),
                    @DtEmissao, @DtCompetencia, ISNULL(@Historico, N''), ISNULL(@Observacao, N''), ISNULL(@ValorTotal, 0), 'MANUAL', 'ATIVO',
                    ISNULL(@Previsao, 0), ISNULL(@Integracao, 'COMPLETA'), ISNULL(@Usuario, N'sistema'));
            SET @IdLancamento = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE l
               SET l.ID_EMPRESA = @IdEmpresa, l.ID_CENTRO_CUSTO = @IdCentroCusto, l.ID_PESSOA = @IdPessoa, l.ID_PLANO_CONTA = @IdPlanoConta,
                   l.ID_HISTORICO_PADRAO = @IdHistoricoPadrao, l.DOCUMENTO = ISNULL(@Documento, N''), l.DT_EMISSAO = @DtEmissao,
                   l.DT_COMPETENCIA = @DtCompetencia, l.HISTORICO = ISNULL(@Historico, N''), l.OBSERVACAO = ISNULL(@Observacao, N''),
                   l.VALOR_TOTAL = ISNULL(@ValorTotal, 0), l.PREVISAO = ISNULL(@Previsao, 0), l.INTEGRACAO = ISNULL(@Integracao, 'COMPLETA'),
                   l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = @Usuario
            FROM FIN.Lancamento l
            WHERE l.ID_LANCAMENTO = @IdLancamento;

        -- parcelas: retira as que saíram (sem baixa), acerta as que ficaram, inclui as novas
        DELETE p
        FROM FIN.Parcela p
        WHERE p.ID_LANCAMENTO = @IdLancamento
          AND NOT EXISTS (SELECT 1 FROM #P x WHERE x.ID_PARCELA = p.ID_PARCELA)
          AND NOT EXISTS (SELECT 1 FROM FIN.Baixa b WHERE b.ID_PARCELA = p.ID_PARCELA);

        UPDATE p
           SET p.NUMERO = x.NUMERO, p.QTD_PARCELAS = @N, p.DT_VENCIMENTO = x.DT_VENCIMENTO, p.VALOR = x.VALOR,
               p.ID_CONTA_PREVISTA = x.ID_CONTA_PREVISTA,
               p.SITUACAO = CASE WHEN p.SITUACAO = 'CANCELADA' THEN p.SITUACAO
                                 WHEN p.VALOR_BAIXADO = 0 THEN 'ABERTA'
                                 WHEN p.VALOR_BAIXADO >= x.VALOR THEN 'PAGA' ELSE 'PARCIAL' END,
               p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = @Usuario
        FROM FIN.Parcela p
        INNER JOIN #P x ON x.ID_PARCELA = p.ID_PARCELA
        WHERE p.NUMERO <> x.NUMERO OR p.QTD_PARCELAS <> @N OR p.DT_VENCIMENTO <> x.DT_VENCIMENTO OR p.VALOR <> x.VALOR
           OR ISNULL(p.ID_CONTA_PREVISTA, 0) <> ISNULL(x.ID_CONTA_PREVISTA, 0);

        INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR, SITUACAO, ID_CONTA_PREVISTA, USUARIO_CRIACAO)
        SELECT @IdLancamento, ISNULL(x.NUMERO, 1), @N, x.DT_VENCIMENTO, ISNULL(x.VALOR, 0), 'ABERTA', x.ID_CONTA_PREVISTA, ISNULL(@Usuario, N'sistema')
        FROM #P x
        WHERE x.ID_PARCELA IS NULL;

        -- marcar o tipo Fornecedor / Cliente no parceiro (resposta ao aviso)
        IF @MarcarTipoParceiro = 1 AND @IdPessoa IS NOT NULL AND @IdTipoMarcar IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa AND ((@Tipo = 'P' AND p.FORNECEDOR = 0) OR (@Tipo = 'R' AND p.CLIENTE = 0)))
        BEGIN
            UPDATE pt SET pt.ATIVO = 1, pt.DT_ALTERACAO = SYSDATETIME(), pt.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Tipo pt
            WHERE pt.ID_PESSOA = @IdPessoa AND pt.ID_PARCEIRO_TIPO = @IdTipoMarcar AND pt.ATIVO = 0;

            INSERT INTO CAD.Pessoa_Tipo (ID_PESSOA, ID_PARCEIRO_TIPO, ATIVO, USUARIO_CRIACAO)
            SELECT @IdPessoa, @IdTipoMarcar, 1, ISNULL(@Usuario, N'sistema')
            WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo pt WHERE pt.ID_PESSOA = @IdPessoa AND pt.ID_PARCEIRO_TIPO = @IdTipoMarcar);

            UPDATE pt SET pt.ATIVO = 0, pt.DT_ALTERACAO = SYSDATETIME(), pt.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Tipo pt
            WHERE pt.ID_PESSOA = @IdPessoa AND pt.ID_PARCEIRO_TIPO = @IdTipoNA AND pt.ATIVO = 1;

            UPDATE p
               SET p.FORNECEDOR = CASE WHEN @Tipo = 'P' THEN 1 ELSE p.FORNECEDOR END,
                   p.CLIENTE    = CASE WHEN @Tipo = 'R' THEN 1 ELSE p.CLIENTE END,
                   p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa p
            WHERE p.ID_PESSOA = @IdPessoa;

            INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_USUARIO, USUARIO_CRIACAO)
            VALUES (N'FIN.Lancamento', @IdLancamento, 'TIPO_PARCEIRO', 'AVISO',
                    N'Tipo ' + CASE @Tipo WHEN 'P' THEN N'Fornecedor' ELSE N'Cliente' END + N' marcado no parceiro.', N'', @IdUsuario, ISNULL(@Usuario, N'sistema'));
        END;

        -- avisos confirmados e motivo da trava de datas
        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'FIN.Lancamento', @IdLancamento, r.CODIGO, r.NIVEL, r.MENSAGEM,
               CASE WHEN r.NIVEL = 'MOTIVO' THEN ISNULL(@MotivoRetroativo, N'') ELSE N'' END, r.ID_REFERENCIA, @IdUsuario, ISNULL(@Usuario, N'sistema')
        FROM #Regra r
        WHERE r.NIVEL IN ('AVISO', 'MOTIVO');

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Lançamento gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID,
               CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #P;
        DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #P;
        DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o lançamento. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamento AS ID, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO
