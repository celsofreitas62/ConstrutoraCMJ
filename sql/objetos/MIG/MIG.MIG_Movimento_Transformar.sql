/*******************************************************************************
  Objeto      : [MIG].[MIG_Movimento_Transformar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Etapa 03c2, parte B: transforma os documentos do Access que vão
                para o sistema novo (MIG.Movimento, DESTINO = 'SISTEMA') em
                lançamento, parcela, baixa, movimento bancário e transferência,
                pelas regras aprovadas pelo Celso em 18/11/2026
                (docs/requisitos/Migracao_Movimento.md, seção 9):
                  LOTE      títulos da conta "Pagto em Lote" + uma saída (banco
                            ou caixinha) com o mesmo total: cada título vira conta
                            a pagar; a saída vira UM movimento ligado a todas as
                            baixas; o lote do Access vira um SIS.Lote;
                  VENDA     linha da conta "Débitos" (cliente) + entrada no banco
                            ou caixa: conta a receber; ligação com o contrato em
                            MIG.DePara_Venda;
                  AVULSO    pagamentos e recebimentos direto no banco ou no caixa
                            (caixinha = conta Caixa da empresa);
                  TRANSF    créditos e débitos soltos: transferência entre o banco
                            e o Caixa contábil da empresa (banco da linha, se
                            houver; senão a conta padrão da obra ou da empresa);
                  CASO      o resto: MIG.Caso, para a tela de correção.
                  ABATER    documento marcado na tela como "crédito" manual que
                            abate a parcela de uma venda (MIG.Caso_Correcao,
                            LINK_VENDA_DESTINO): vira uma baixa só de
                            abatimento na parcela (VALOR_PRINCIPAL = ABATIMENTO,
                            líquido zero, sem movimento no banco); a parcela
                            fica com o saldo real devido.
                Correções da tela (MIG.Caso_Correcao e Caso_Correcao_Linha) são
                aplicadas antes da classificação.
                Situação: linha confirmada = baixa; "efetuado" sem "confirmado"
                com data de pagamento = baixa não compensada (cheque); sem data
                = parcela em aberto. "Somente integração" = lançamento só
                contábil e baixa sem movimento no banco.
                @Unidade (tela de casos, botão "Conferir"): classifica só aquele
                documento, atualiza a linha dele em MIG.Caso e devolve uma
                linha (UNIDADE, REGRA, MOTIVO, DETALHE); nada é gravado no
                financeiro.
                MIG.Caso guarda os casos e também os documentos que já têm
                correção da tela (REGRA_ATUAL = como ficaram), para a tela
                mostrar o que foi resolvido.
                @Executar = 0 (padrão): só a prévia (classificação e números),
                nada é gravado no financeiro. @Executar = 1: apaga a carga
                anterior da migração (lotes de origem MIGRACAO) e grava de novo,
                tudo-ou-nada. Usuário "sistema", origem MIGRACAO.
                Pré-requisito: MIG_Movimento_Preparar e MIG_Cadastros_Processar.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
    v1.1 (18/11/2026) - Tela de casos: parâmetro @Unidade (conferir um
                        documento só); MIG.Caso atualizada por MERGE, mantendo
                        os documentos corrigidos (REGRA_ATUAL, MOTIVO_ORIGINAL).
    v1.2 (18/11/2026) - Aviso "Revisar" (MIG.Caso.REVISAR): linha corrigida que
                        mudou ou foi apagada no Access, documento com decisão
                        que mudou ou sumiu do Access.
    v1.3 (18/11/2026) - @Unidades (lista JSON): confere vários documentos de uma
                        vez (ações em lote da tela de casos); uma linha por
                        documento no retorno.
    v1.4 (18/11/2026) - Troca de lote pela tela (Caso_Correcao_Linha.LOTE): a
                        linha passa para o documento do lote novo (0 = sai do
                        lote: avulso ou venda); padrão de contas recalculado nos
                        documentos afetados; a conferência inclui o documento
                        de destino (depois dos pedidos).
    v1.5 (19/11/2026) - Lote novo da migração (900001 em diante); decisões da
                        tela (ignorar / arquivo morto) valem para o documento
                        como ele está depois da troca de lote.
    v1.6 (23/11/2026) - Etapa 03f2: decisão ABATER (resposta da Renata de
                        23/11/2026, nº 308074 e 308076): baixa só de abatimento
                        na parcela da venda de destino, na conta prevista da
                        parcela (ou no Caixa contábil da empresa), com o nº do
                        Access e o motivo. Destino inválido (venda que não
                        migra como conta a receber, já paga, abatimento maior
                        que a parcela) devolve o documento para a lista de
                        casos com o motivo. Conferir um documento ABATER
                        confere também a venda de destino.

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Movimento_Transformar;                 -- prévia
    -- EXEC MIG.MIG_Movimento_Transformar @Executar = 1;   -- grava
    -- EXEC MIG.MIG_Movimento_Transformar @Unidade = 'L:123'; -- confere um documento
    -- EXEC MIG.MIG_Movimento_Transformar @Unidades = N'["L:123","V:45"]'; -- confere vários
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Movimento_Transformar]
    @Executar           BIT          = 0,
    @NomeCaixa          NVARCHAR(60) = N'Caixa',
    @NomeCaixaContabil  NVARCHAR(60) = N'Caixa contábil',
    @Unidade            VARCHAR(40)  = NULL,
    @Unidades           NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[MIG].[MIG_Movimento_Transformar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @IdSistema    INT;
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @IdPrincipal  INT;
    DECLARE @IdLoteGeral  BIGINT;
    DECLARE @Agora        DATETIME2(0) = SYSDATETIME();

    BEGIN TRY
        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;

        IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
            THROW 50001, N'Rode antes o MIG.MIG_Movimento_Preparar.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.DePara_Centro) OR NOT EXISTS (SELECT 1 FROM MIG.DePara_Plano)
            THROW 50001, N'Rode antes o MIG.MIG_Cadastros_Processar.', 1;
        -- documentos escolhidos (tela de casos): um (@Unidade) ou vários (@Unidades)
        CREATE TABLE #Sel (UNIDADE VARCHAR(40) NOT NULL PRIMARY KEY, PEDIDO BIT NOT NULL DEFAULT (1));
        IF @Unidade IS NOT NULL
            INSERT INTO #Sel (UNIDADE) VALUES (@Unidade);
        IF ISJSON(ISNULL(@Unidades, N'')) = 1
            INSERT INTO #Sel (UNIDADE)
            SELECT DISTINCT LEFT(j.value, 40) FROM OPENJSON(@Unidades) j
            WHERE j.value IS NOT NULL AND NOT EXISTS (SELECT 1 FROM #Sel s WHERE s.UNIDADE = LEFT(j.value, 40));
        DECLARE @Filtrar BIT = CASE WHEN EXISTS (SELECT 1 FROM #Sel) THEN 1 ELSE 0 END;
        -- linha trocada de lote: confere também o documento para onde ela foi
        INSERT INTO #Sel (UNIDADE, PEDIDO)
        SELECT DISTINCT d.UNIDADE, 0
        FROM MIG.Caso_Correcao_Linha o
        INNER JOIN MIG.Movimento m ON m.ORIGEM = o.ORIGEM AND m.NUM = o.NUM
        CROSS APPLY (SELECT CAST(CASE WHEN o.LOTE IS NULL THEN m.UNIDADE
                                         WHEN o.LOTE > 0 THEN 'L:' + CONVERT(VARCHAR(20), o.LOTE)
                                         WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
                                         ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END AS VARCHAR(40)) AS UNIDADE) d
        WHERE @Filtrar = 1 AND o.LOTE IS NOT NULL
          AND o.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s)
          AND NOT EXISTS (SELECT 1 FROM #Sel s WHERE s.UNIDADE = d.UNIDADE);
        -- documento que abate uma parcela: confere também a venda de destino
        INSERT INTO #Sel (UNIDADE, PEDIDO)
        SELECT DISTINCT 'V:' + CONVERT(VARCHAR(20), cc.LINK_VENDA_DESTINO), 0
        FROM MIG.Caso_Correcao cc
        WHERE @Filtrar = 1 AND cc.ACAO = 'ABATER'
          AND cc.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s)
          AND NOT EXISTS (SELECT 1 FROM #Sel s WHERE s.UNIDADE = 'V:' + CONVERT(VARCHAR(20), cc.LINK_VENDA_DESTINO));
        IF (@Unidade IS NOT NULL OR @Unidades IS NOT NULL) AND @Filtrar = 0
            THROW 50001, N'Nenhum documento informado para conferir.', 1;
        IF @Filtrar = 1 AND ISNULL(@Executar, 0) = 1
            THROW 50001, N'A conferência de documentos escolhidos (@Unidade/@Unidades) não grava: rode sem @Executar.', 1;

        SELECT @IdSistema = u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdSistema);
        EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Origem = N'MIGRACAO';
        SELECT @IdPrincipal = e.ID_EMPRESA
        FROM CAD.Empresa e INNER JOIN MIG.Classif_Empresa c ON c.CODIGO_MASTER = e.CODIGO_ACCESS AND c.PRINCIPAL = 1;

        /* ------------------------------------------------------------------
           1. Linhas do Access (com as correções da tela) e os de-paras
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Linhas';
        SELECT h.CodHistorico AS COD, f.ID_HISTORICO_PADRAO
        INTO #Hist
        FROM (SELECT TRY_CONVERT(INT, a.CodHistorico) AS CodHistorico, LEFT(LTRIM(RTRIM(ISNULL(a.Descricao, N''))), 80) AS DESCRICAO FROM MIG.Access_Historico a) h
        CROSS APPLY (SELECT TOP (1) x.ID_HISTORICO_PADRAO FROM FIN.Historico_Padrao x
                     WHERE x.CODIGO_ACCESS = h.CodHistorico OR x.DESCRICAO = h.DESCRICAO
                     ORDER BY CASE WHEN x.CODIGO_ACCESS = h.CodHistorico THEN 0 ELSE 1 END) f
        WHERE h.CodHistorico IS NOT NULL;

        SELECT m.ORIGEM, m.NUM, eu.UNIDADE, m.PADRAO, m.CONTRATO, m.LINK_VENDA, m.IMOVEL,
               m.UNIDADE AS UNIDADE_ACCESS, CAST(CASE WHEN o.LOTE IS NULL THEN 0 ELSE 1 END AS BIT) AS MOVIDA,
               COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS EV,
               COALESCE(o.PARCEIRO, m.PARCEIRO)           AS PAR,
               COALESCE(o.CONTA, m.CONTA)                 AS CONTA,
               COALESCE(o.PLANO3, m.PLANO3)               AS P3,
               m.HISTORICO,
               CASE WHEN COALESCE(o.DT_MOVTO,  m.DT_MOVTO)  BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_MOVTO,  m.DT_MOVTO)  END AS DM,
               CASE WHEN COALESCE(o.DT_VENCTO, m.DT_VENCTO) BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_VENCTO, m.DT_VENCTO) END AS DV,
               CASE WHEN COALESCE(o.DT_PAGTO,  m.DT_PAGTO)  BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_PAGTO,  m.DT_PAGTO)  END AS DP,
               m.DT_UNIDADE,
               COALESCE(o.VALOR_DEBITO, m.VALOR_DEBITO)   AS DEB,
               COALESCE(o.VALOR_CREDITO, m.VALOR_CREDITO) AS CRE,
               COALESCE(o.CONFIRMADO, m.CONFIRMADO)       AS CONF,
               m.EFETUADO AS EFET, m.INTEGRACAO AS INTEG, m.SOMENTE_INTEGRACAO AS SOI,
               m.NUM_DOC, m.COMPLEMENTO, m.OBSERVACAO, m.NOTA_FISCAL,
               CAST('' AS VARCHAR(4)) AS TC, CAST('' AS CHAR(1)) AS LADO, CAST(0 AS DECIMAL(18,2)) AS VALOR,
               CAST(NULL AS INT) AS ID_CENTRO, CAST(NULL AS INT) AS ID_EMPRESA, CAST(NULL AS INT) AS ID_CONTA_PADRAO,
               CAST(NULL AS INT) AS ID_PESSOA, CAST(NULL AS INT) AS ID_PLANO, CAST(NULL AS INT) AS ID_CONTA_BCO,
               CAST(NULL AS INT) AS ID_EMPRESA_BCO, CAST(NULL AS INT) AS ID_HIST
        INTO #L
        FROM MIG.Movimento m
        LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
        CROSS APPLY (SELECT CAST(CASE WHEN o.LOTE IS NULL THEN m.UNIDADE
                                         WHEN o.LOTE > 0 THEN 'L:' + CONVERT(VARCHAR(20), o.LOTE)
                                         WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
                                         ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END AS VARCHAR(40)) AS UNIDADE) eu
        WHERE m.DESTINO = 'SISTEMA'
          AND (@Filtrar = 0 OR m.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s) OR eu.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s))
          AND ISNULL(o.IGNORAR_LINHA, 0) = 0
          AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao c WHERE c.UNIDADE = eu.UNIDADE);

        CREATE UNIQUE CLUSTERED INDEX IX_L ON #L (ORIGEM, NUM);
        CREATE INDEX IX_L_U ON #L (UNIDADE);

        UPDATE l
           SET l.TC    = CASE l.CONTA WHEN 1 THEN 'CRED' WHEN 2 THEN 'DEB' WHEN 3 THEN 'LOTE' WHEN 9 THEN 'NA' ELSE 'BCO' END,
               l.LADO  = CASE WHEN l.DEB > 0 AND l.CRE > 0 THEN 'X' WHEN l.DEB > 0 THEN 'D' WHEN l.CRE > 0 THEN 'C' ELSE '0' END,
               l.VALOR = l.DEB + l.CRE
        FROM #L l;

        UPDATE l
           SET l.ID_CENTRO       = COALESCE(dp.ID_CENTRO_CUSTO, dc.ID_CENTRO_CUSTO),
               l.ID_EMPRESA      = COALESCE(cc.ID_EMPRESA, dc.ID_EMPRESA),
               l.ID_CONTA_PADRAO = dc.ID_CONTA_PADRAO,
               l.ID_PESSOA       = p.ID_PESSOA,
               l.ID_PLANO        = dp.ID_PLANO_CONTA,
               l.ID_CONTA_BCO    = CASE WHEN l.TC = 'BCO' THEN k.ID_CONTA END,
               l.ID_EMPRESA_BCO  = CASE WHEN l.TC = 'BCO' THEN k.ID_EMPRESA END,
               l.ID_HIST         = h.ID_HISTORICO_PADRAO
        FROM #L l
        LEFT JOIN MIG.DePara_Centro dc ON dc.CODIGO_VINCULADA = l.EV
        LEFT JOIN MIG.DePara_Plano dp  ON dp.PLANO3_ACCESS = l.P3
        LEFT JOIN CAD.Centro_Custo cc  ON cc.ID_CENTRO_CUSTO = dp.ID_CENTRO_CUSTO
        LEFT JOIN CAD.Pessoa p         ON p.CODIGO_ACCESS = l.PAR AND l.PAR > 1
        LEFT JOIN BANCO.Conta k        ON k.CODIGO_ACCESS = l.CONTA
        LEFT JOIN #Hist h              ON h.COD = l.HISTORICO;

        /* ------------------------------------------------------------------
           2. Classificação de cada documento (unidade)
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Classificação';
        SELECT l.UNIDADE, MIN(l.PADRAO) AS PADRAO, LEFT(l.UNIDADE, 1) AS TIPO_U,
               COUNT(*) AS N, MIN(l.DT_UNIDADE) AS DT_UNIDADE,
               SUM(l.DEB) AS S_DEB_TOTAL, SUM(l.CRE) AS S_CRE_TOTAL,
               SUM(CASE WHEN l.LADO = 'X' THEN 1 ELSE 0 END) AS N_DUPLO,
               SUM(CASE WHEN l.LADO IN ('D', 'C') THEN 1 ELSE 0 END) AS N_NZ,
               SUM(CASE WHEN l.TC = 'LOTE' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_LOTE,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_PAG,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_REC,
               SUM(CASE WHEN l.TC = 'BCO' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_PAG_BCO,
               SUM(CASE WHEN l.TC = 'BCO' AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_REC_BCO,
               SUM(CASE WHEN l.TC = 'CRED' AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_CRED,
               SUM(CASE WHEN l.TC = 'DEB' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_DEBD,
               SUM(CASE WHEN l.LADO IN ('D', 'C') AND NOT ((l.TC = 'LOTE' AND l.LADO = 'D') OR l.TC IN ('BCO', 'NA')
                                                         OR (l.TC = 'CRED' AND l.LADO = 'C') OR (l.TC = 'DEB' AND l.LADO = 'D')) THEN 1 ELSE 0 END) AS N_OUTRO,
               SUM(CASE WHEN l.TC = 'LOTE' AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_LOTE,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_PAG,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'C' THEN l.VALOR ELSE 0 END) AS S_REC,
               SUM(CASE WHEN l.TC = 'CRED' AND l.LADO = 'C' THEN l.VALOR ELSE 0 END) AS S_CRED,
               SUM(CASE WHEN l.TC = 'DEB' AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_DEBD,
               SUM(CASE WHEN l.TC IN ('CRED', 'DEB') AND l.LADO IN ('D', 'C') AND l.CONF = 0 THEN 1 ELSE 0 END) AS N_TR_NAO_CONF,
               CAST('' AS VARCHAR(12)) AS REGRA, CAST(N'' AS NVARCHAR(400)) AS MOTIVO, CAST(N'' AS NVARCHAR(400)) AS DETALHE
        INTO #U
        FROM #L l
        GROUP BY l.UNIDADE;

        -- documentos que ganharam ou perderam linha por troca de lote: padrão de contas refeito
        WITH Afetadas AS (
            SELECT l.UNIDADE FROM #L l WHERE l.MOVIDA = 1
            UNION SELECT l.UNIDADE_ACCESS FROM #L l WHERE l.MOVIDA = 1),
        Pares AS (
            SELECT DISTINCT l.UNIDADE, CONVERT(VARCHAR(20), l.TC + '-' + l.LADO) AS PAR
            FROM #L l INNER JOIN Afetadas a ON a.UNIDADE = l.UNIDADE)
        UPDATE u
           SET u.PADRAO = LEFT(LEFT(u.UNIDADE, 1) + '|' + p.PADRAO, 200)
        FROM #U u
        INNER JOIN (SELECT x.UNIDADE, STRING_AGG(x.PAR, '|') WITHIN GROUP (ORDER BY x.PAR) AS PADRAO FROM Pares x GROUP BY x.UNIDADE) p
                ON p.UNIDADE = u.UNIDADE;

        UPDATE u
           SET u.REGRA = CASE
                   WHEN u.N_DUPLO > 0 THEN 'CASO'
                   WHEN u.N_NZ = 0 THEN 'CASO'
                   WHEN u.N_OUTRO > 0 THEN 'CASO'
                   WHEN u.N_LOTE > 0 AND u.TIPO_U = 'L' AND u.N_PAG = 1 AND u.N_REC = 0 AND u.N_DEBD = 0 AND ABS(u.S_LOTE - u.S_PAG) <= 0.01 THEN 'LOTE'
                   WHEN u.N_LOTE > 0 THEN 'CASO'
                   WHEN u.TIPO_U = 'V' AND u.N_NZ = 2 AND u.N_DEBD = 1 AND u.N_REC = 1 AND ABS(u.S_DEBD - u.S_REC) <= 0.01 THEN 'VENDA'
                   WHEN u.TIPO_U = 'V' THEN 'CASO'
                   WHEN u.N_NZ = 2 AND u.N_PAG_BCO = 1 AND u.N_CRED = 1 AND u.S_PAG = u.S_CRED THEN 'TRANSF_PAR'
                   WHEN u.N_NZ = 2 AND u.N_REC_BCO = 1 AND u.N_DEBD = 1 AND u.S_REC = u.S_DEBD THEN 'TRANSF_PAR'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ AND u.N_TR_NAO_CONF = 0 THEN 'TRANSF'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ THEN 'CASO'
                   WHEN u.N_CRED + u.N_DEBD = 0 THEN 'AVULSO'
                   ELSE 'CASO' END,
               u.MOTIVO = CASE
                   WHEN u.N_DUPLO > 0 THEN N'Linha com débito e crédito ao mesmo tempo'
                   WHEN u.N_NZ = 0 THEN N'Documento com valor zero'
                   WHEN u.N_OUTRO > 0 THEN N'Combinação de contas não prevista (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')'
                   WHEN u.N_LOTE > 0 AND u.TIPO_U <> 'L' THEN N'Título de pagamento em lote fora de um lote'
                   WHEN u.N_LOTE > 0 AND u.N_PAG = 0 THEN N'Pagamento em lote sem a saída do banco ou do caixa'
                   WHEN u.N_LOTE > 0 AND u.N_PAG > 1 THEN N'Pagamento em lote com mais de uma saída'
                   WHEN u.N_LOTE > 0 AND (u.N_REC > 0 OR u.N_DEBD > 0) THEN N'Pagamento em lote com entrada no mesmo lote'
                   WHEN u.N_LOTE > 0 THEN N'Total dos títulos do lote diferente da saída do banco ou do caixa'
                   WHEN u.TIPO_U = 'V' THEN N'Parcela de venda fora do padrão (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ THEN N'Transferência não confirmada'
                   ELSE N'Combinação de contas não prevista (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')' END
        FROM #U u;
        UPDATE #U SET DETALHE = N'Títulos ' + FORMAT(S_LOTE, 'N2', 'pt-BR') + N'; saída ' + FORMAT(S_PAG, 'N2', 'pt-BR')
        WHERE REGRA = 'CASO' AND N_LOTE > 0;
        UPDATE #U SET MOTIVO = N'', DETALHE = N'' WHERE REGRA <> 'CASO';

        /* ------------------------------------------------------------------
           3. Contas auxiliares: centro administrativo, caixa e Caixa contábil
              de cada empresa
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Contas auxiliares';
        SELECT c.ID_EMPRESA, MIN(c.ID_CENTRO_CUSTO) AS ID_CENTRO
        INTO #CentroAdm
        FROM CAD.Centro_Custo c
        WHERE c.TIPO = 'ADMINISTRATIVO' AND c.ATIVO = 1 AND c.CODIGO_ACCESS IS NOT NULL
        GROUP BY c.ID_EMPRESA;

        SELECT e.ID_EMPRESA,
               (SELECT TOP (1) k.ID_CONTA FROM BANCO.Conta k
                WHERE k.ID_EMPRESA = e.ID_EMPRESA AND k.TIPO = 'CAIXA' AND k.DESCRICAO <> @NomeCaixaContabil
                ORDER BY k.ATIVO DESC, CASE WHEN k.CODIGO_ACCESS IS NULL THEN 1 ELSE 0 END, k.ID_CONTA) AS ID_CONTA
        INTO #Caixa
        FROM CAD.Empresa e
        WHERE e.CODIGO_ACCESS IS NOT NULL;

        SELECT k.ID_EMPRESA, MIN(k.ID_CONTA) AS ID_CONTA
        INTO #CxContabil
        FROM BANCO.Conta k
        WHERE k.TIPO = 'CAIXA' AND k.DESCRICAO = @NomeCaixaContabil
        GROUP BY k.ID_EMPRESA;

        /* ------------------------------------------------------------------
           4. Títulos (lançamentos) e transferências a gerar
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Títulos';
        -- linha que paga/recebe em cada LOTE e VENDA
        ;WITH Pag AS
        (
            SELECT l.UNIDADE, l.ORIGEM, l.NUM, l.TC, l.CONF, l.EFET, l.SOI, l.DP, l.DM, l.DV, l.ID_CONTA_BCO, l.ID_EMPRESA, l.ID_CENTRO, l.ID_PLANO,
                   l.ID_PESSOA, l.EV, l.VALOR, l.COMPLEMENTO, l.NUM_DOC, l.INTEG,
                   ROW_NUMBER() OVER (PARTITION BY l.UNIDADE ORDER BY l.NUM) AS RN
            FROM #L l
            INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
            WHERE (u.REGRA = 'LOTE'  AND l.TC IN ('BCO', 'NA') AND l.LADO = 'D')
               OR (u.REGRA = 'VENDA' AND l.TC IN ('BCO', 'NA') AND l.LADO = 'C')
        )
        SELECT t.ORIGEM, t.NUM, t.UNIDADE, u.REGRA,
               CAST(CASE WHEN u.REGRA = 'VENDA' THEN 'R' WHEN u.REGRA = 'LOTE' THEN 'P' WHEN t.LADO = 'D' THEN 'P' ELSE 'R' END AS CHAR(1)) AS TIPO,
               -- obra/plano: na venda vêm da linha da entrada; nos demais, do próprio título
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_CENTRO, t.ID_CENTRO) ELSE t.ID_CENTRO END AS ID_CENTRO,
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_EMPRESA, t.ID_EMPRESA) ELSE t.ID_EMPRESA END AS ID_EMPRESA,
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_PLANO, t.ID_PLANO) ELSE t.ID_PLANO END AS ID_PLANO,
               COALESCE(t.ID_PESSOA, p.ID_PESSOA) AS ID_PESSOA,
               t.ID_HIST,
               CAST(LEFT(ISNULL(t.NUM_DOC, N''), 40) AS NVARCHAR(40)) AS DOCUMENTO,
               COALESCE(t.DM, t.DV, t.DT_UNIDADE) AS DT_EMISSAO,
               COALESCE(t.DV, t.DM, t.DT_UNIDADE) AS DT_VENC,
               CAST(LEFT(ISNULL(NULLIF(t.COMPLEMENTO, N''), ISNULL(p.COMPLEMENTO, N'')), 200) AS NVARCHAR(200)) AS HISTORICO,
               CAST(LEFT(CONCAT_WS(N' | ', NULLIF(t.OBSERVACAO, N''), N'NF: ' + NULLIF(t.NOTA_FISCAL, N''),
                                   N'Access: ' + t.ORIGEM + N' ' + CONVERT(NVARCHAR(12), t.NUM) + N', documento ' + t.UNIDADE), 2000) AS NVARCHAR(2000)) AS OBSERVACAO,
               t.VALOR,
               CAST(CASE WHEN t.SOI = 1 THEN 'SO_CONTABIL' WHEN t.INTEG = 1 THEN 'COMPLETA' ELSE 'NENHUMA' END AS VARCHAR(12)) AS INTEGRACAO,
               -- quem paga: a linha da saída/entrada (LOTE/VENDA) ou o próprio título (AVULSO)
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.TC ELSE t.TC END AS TC_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ID_CONTA_BCO ELSE t.ID_CONTA_BCO END AS ID_CONTA_BCO,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.CONF ELSE t.CONF END AS CONF,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.EFET ELSE t.EFET END AS EFET,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.SOI ELSE t.SOI END AS SOI_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN COALESCE(p.DP, p.DM, t.DP, t.DM) ELSE COALESCE(t.DP, t.DM, t.DV) END AS DT_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.DP ELSE t.DP END AS DP_ORIGINAL,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ORIGEM ELSE t.ORIGEM END AS PAG_ORIGEM,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.NUM ELSE t.NUM END AS PAG_NUM,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ID_EMPRESA ELSE NULL END AS ID_EMPRESA_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN ISNULL(p.COMPLEMENTO, N'') ELSE ISNULL(t.COMPLEMENTO, N'') END AS HIST_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN ISNULL(p.NUM_DOC, N'') ELSE ISNULL(t.NUM_DOC, N'') END AS DOC_PAG,
               t.LINK_VENDA, t.IMOVEL, t.PAR, t.CONTRATO, t.NUM_DOC,
               CAST(NULL AS INT) AS ID_CONTA_PAG,
               CAST(0 AS BIT) AS PAGO, CAST(1 AS BIT) AS COMPENSADO, CAST(0 AS BIT) AS GERA_MOV
        INTO #T
        FROM #L t
        INNER JOIN #U u ON u.UNIDADE = t.UNIDADE
        LEFT JOIN Pag p ON p.UNIDADE = t.UNIDADE AND p.RN = 1 AND u.REGRA IN ('LOTE', 'VENDA')
        WHERE (u.REGRA = 'LOTE'   AND t.TC = 'LOTE' AND t.LADO = 'D')
           OR (u.REGRA = 'VENDA'  AND t.TC = 'DEB'  AND t.LADO = 'D')
           OR (u.REGRA = 'AVULSO' AND t.TC IN ('BCO', 'NA') AND t.LADO IN ('D', 'C'));

        -- empresa e obra: sem obra no Access ("N/A"), usa a empresa da conta que pagou e a área administrativa dela
        UPDATE t SET t.ID_EMPRESA = COALESCE(t.ID_EMPRESA, t.ID_EMPRESA_PAG, k.ID_EMPRESA, @IdPrincipal)
        FROM #T t LEFT JOIN BANCO.Conta k ON k.ID_CONTA = t.ID_CONTA_BCO;
        UPDATE t SET t.ID_CENTRO = a.ID_CENTRO
        FROM #T t INNER JOIN #CentroAdm a ON a.ID_EMPRESA = t.ID_EMPRESA
        WHERE t.ID_CENTRO IS NULL;

        -- conta que pagou: o banco da linha ou o caixa da empresa (no lote, a empresa do 1º título)
        ;WITH EmpLote AS (SELECT t.UNIDADE, MIN(t.ID_EMPRESA) AS ID_EMPRESA FROM #T t WHERE t.REGRA = 'LOTE' GROUP BY t.UNIDADE)
        UPDATE t
           SET t.ID_CONTA_PAG = CASE WHEN t.TC_PAG = 'BCO' THEN t.ID_CONTA_BCO
                                     ELSE (SELECT c.ID_CONTA FROM #Caixa c WHERE c.ID_EMPRESA = COALESCE(t.ID_EMPRESA_PAG, el.ID_EMPRESA, t.ID_EMPRESA)) END,
               t.PAGO       = CASE WHEN t.CONF = 1 OR (t.EFET = 1 AND t.DP_ORIGINAL IS NOT NULL) THEN 1 ELSE 0 END,
               t.COMPENSADO = CASE WHEN t.CONF = 1 THEN 1 ELSE 0 END
        FROM #T t LEFT JOIN EmpLote el ON el.UNIDADE = t.UNIDADE;
        UPDATE #T SET GERA_MOV = CASE WHEN PAGO = 1 AND COMPENSADO = 1 AND SOI_PAG = 0 THEN 1 ELSE 0 END;

        -- transferências (créditos e débitos soltos; pares banco + contrapartida)
        SET @EtapaAtual = 'Transferências';
        SELECT l.ORIGEM, l.NUM, l.UNIDADE, u.REGRA,
               COALESCE(l.DP, l.DM, l.DV) AS DT,
               l.VALOR,
               CAST(LEFT(CONCAT_WS(N' - ', NULLIF(l.COMPLEMENTO, N''), NULLIF(l.NUM_DOC, N''), N'Access ' + CONVERT(NVARCHAR(12), l.NUM)), 200) AS NVARCHAR(200)) AS HISTORICO,
               -- banco: o da linha do par; senão a conta padrão da obra; senão a da empresa
               COALESCE(b.ID_CONTA_BCO, l.ID_CONTA_PADRAO, e.ID_CONTA_BANCARIA_PADRAO) AS ID_BANCO,
               l.LADO, l.TC, l.ID_EMPRESA,
               b.ORIGEM AS BCO_ORIGEM, b.NUM AS BCO_NUM,
               CAST(NULL AS INT) AS ID_CX, CAST(NULL AS INT) AS ID_ORIGEM, CAST(NULL AS INT) AS ID_DESTINO
        INTO #TR
        FROM #L l
        INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
        LEFT JOIN #L b ON b.UNIDADE = l.UNIDADE AND u.REGRA = 'TRANSF_PAR' AND b.TC = 'BCO'
        LEFT JOIN CAD.Empresa e ON e.ID_EMPRESA = l.ID_EMPRESA
        WHERE u.REGRA IN ('TRANSF', 'TRANSF_PAR') AND ((l.TC = 'CRED' AND l.LADO = 'C') OR (l.TC = 'DEB' AND l.LADO = 'D'));

        UPDATE r
           SET r.ID_CX      = x.ID_CONTA,
               r.ID_ORIGEM  = CASE WHEN r.TC = 'CRED' THEN r.ID_BANCO ELSE x.ID_CONTA END,   -- crédito solto: saque do banco para o caixa contábil
               r.ID_DESTINO = CASE WHEN r.TC = 'CRED' THEN x.ID_CONTA ELSE r.ID_BANCO END    -- débito solto: do caixa contábil para o banco
        FROM #TR r
        LEFT JOIN BANCO.Conta k ON k.ID_CONTA = r.ID_BANCO
        LEFT JOIN #CxContabil x ON x.ID_EMPRESA = k.ID_EMPRESA;

        -- transferência sem banco identificável vira caso
        UPDATE u SET u.REGRA = 'CASO', u.MOTIVO = N'Transferência sem conta bancária identificável (obra sem conta padrão)'
        FROM #U u WHERE EXISTS (SELECT 1 FROM #TR r WHERE r.UNIDADE = u.UNIDADE AND (r.ID_ORIGEM IS NULL OR r.ID_DESTINO IS NULL OR r.ID_ORIGEM = r.ID_DESTINO));
        DELETE r FROM #TR r INNER JOIN #U u ON u.UNIDADE = r.UNIDADE WHERE u.REGRA = 'CASO';

        -- título pago sem conta (empresa sem caixa) vira caso
        UPDATE u SET u.REGRA = 'CASO', u.MOTIVO = N'Pagamento sem conta identificável'
        FROM #U u WHERE EXISTS (SELECT 1 FROM #T t WHERE t.UNIDADE = u.UNIDADE AND t.PAGO = 1 AND t.ID_CONTA_PAG IS NULL AND t.TC_PAG = 'BCO');
        DELETE t FROM #T t INNER JOIN #U u ON u.UNIDADE = t.UNIDADE WHERE u.REGRA = 'CASO';

        -- abatimentos: "crédito" manual do Access que abate a parcela de uma venda
        SET @EtapaAtual = 'Abatimentos';
        SELECT cc.UNIDADE, cc.LINK_VENDA_DESTINO AS LINK, cc.MOTIVO AS MOTIVO_TELA, x.NUM, x.DT, x.VALOR,
               t.ORIGEM AS T_ORIGEM, t.NUM AS T_NUM, t.VALOR AS T_VALOR, t.PAGO AS T_PAGO,
               COALESCE(t.ID_CONTA_PAG, cx.ID_CONTA) AS ID_CONTA,
               CAST(N'' AS NVARCHAR(400)) AS ERRO
        INTO #Ab
        FROM MIG.Caso_Correcao cc
        CROSS APPLY (SELECT MIN(m.NUM) AS NUM,
                            COALESCE(MIN(CASE WHEN m.DT_MOVTO BETWEEN '2000-01-01' AND '2060-12-31' THEN m.DT_MOVTO END), MIN(m.DT_UNIDADE)) AS DT,
                            SUM(ISNULL(m.VALOR_CREDITO, 0) - ISNULL(m.VALOR_DEBITO, 0)) AS VALOR
                     FROM MIG.vw_MIG_Linha_Unidade v
                     INNER JOIN MIG.Movimento m ON m.ORIGEM = v.ORIGEM AND m.NUM = v.NUM
                     WHERE v.UNIDADE = cc.UNIDADE) x
        OUTER APPLY (SELECT TOP (1) t.ORIGEM, t.NUM, t.VALOR, t.PAGO, t.ID_CONTA_PAG, t.ID_EMPRESA
                     FROM #T t
                     WHERE t.REGRA = 'VENDA' AND t.UNIDADE = 'V:' + CONVERT(VARCHAR(20), cc.LINK_VENDA_DESTINO)
                     ORDER BY t.NUM) t
        LEFT JOIN #CxContabil cx ON cx.ID_EMPRESA = t.ID_EMPRESA
        WHERE cc.ACAO = 'ABATER'
          AND (@Filtrar = 0 OR cc.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s));

        UPDATE a
           SET a.ERRO = CASE
                   WHEN ISNULL(a.VALOR, 0) <= 0 THEN N'Abatimento: o documento não tem valor de crédito'
                   WHEN a.DT IS NULL THEN N'Abatimento: o documento não tem data'
                   WHEN a.T_NUM IS NULL THEN N'Abatimento: a venda ' + CONVERT(NVARCHAR(20), a.LINK) + N' não migra como conta a receber'
                   WHEN a.T_PAGO = 1 THEN N'Abatimento: a parcela da venda ' + CONVERT(NVARCHAR(20), a.LINK) + N' já está paga'
                   WHEN a.ID_CONTA IS NULL THEN N'Abatimento: a parcela da venda ' + CONVERT(NVARCHAR(20), a.LINK) + N' não tem conta prevista'
                   WHEN s.TOTAL > a.T_VALOR THEN N'Abatimento maior que a parcela da venda ' + CONVERT(NVARCHAR(20), a.LINK)
                                                 + N' (' + FORMAT(s.TOTAL, 'N2', 'pt-BR') + N' × ' + FORMAT(a.T_VALOR, 'N2', 'pt-BR') + N')'
                   ELSE N'' END
        FROM #Ab a
        OUTER APPLY (SELECT SUM(ISNULL(b.VALOR, 0)) AS TOTAL FROM #Ab b WHERE b.LINK = a.LINK) s;

        -- casos para a tela, mais os documentos que já têm correção da tela
        SET @EtapaAtual = 'Casos';
        SELECT v.UNIDADE, MIN(m.PADRAO) AS PADRAO, COUNT(*) AS N, SUM(m.VALOR_DEBITO) AS D, SUM(m.VALOR_CREDITO) AS C,
               MIN(m.DT_UNIDADE) AS DT, MIN(cc.ACAO) AS ACAO
        INTO #Dec
        FROM MIG.vw_MIG_Linha_Unidade v
        INNER JOIN MIG.Movimento m ON m.ORIGEM = v.ORIGEM AND m.NUM = v.NUM
        INNER JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = v.UNIDADE
        WHERE @Filtrar = 0 OR v.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s)
        GROUP BY v.UNIDADE;

        SELECT u.UNIDADE, CAST(ISNULL(u.PADRAO, '') AS VARCHAR(200)) AS PADRAO, CAST(u.REGRA AS VARCHAR(15)) AS REGRA,
               u.MOTIVO, u.DETALHE, u.N, u.S_DEB_TOTAL AS D, u.S_CRE_TOTAL AS C, u.DT_UNIDADE AS DT
        INTO #CasoNovo
        FROM #U u
        WHERE u.REGRA = 'CASO' OR EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = u.UNIDADE)
        UNION ALL
        SELECT d.UNIDADE, ISNULL(d.PADRAO, ''),
               CAST(CASE WHEN ISNULL(a.ERRO, N'') <> N'' THEN 'CASO' ELSE d.ACAO END AS VARCHAR(15)),
               ISNULL(a.ERRO, N''),
               CAST(CASE WHEN a.UNIDADE IS NOT NULL AND a.ERRO = N''
                         THEN N'Abate ' + FORMAT(a.VALOR, 'N2', 'pt-BR') + N' da parcela da venda ' + CONVERT(NVARCHAR(20), a.LINK)
                              + N' (saldo ' + FORMAT(a.T_VALOR - a.VALOR, 'N2', 'pt-BR') + N')'
                         ELSE N'' END AS NVARCHAR(400)),
               d.N, d.D, d.C, d.DT
        FROM #Dec d
        LEFT JOIN #Ab a ON a.UNIDADE = d.UNIDADE
        UNION ALL   -- todas as linhas do documento marcadas "ignorar": o documento fica de fora
        SELECT m.UNIDADE, MIN(m.PADRAO), 'IGNORAR', N'', N'', COUNT(*), SUM(m.VALOR_DEBITO), SUM(m.VALOR_CREDITO), MIN(m.DT_UNIDADE)
        FROM MIG.Movimento m
        WHERE m.DESTINO = 'SISTEMA' AND (@Filtrar = 0 OR m.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s))
          AND EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = m.UNIDADE)
          AND NOT EXISTS (SELECT 1 FROM #U u WHERE u.UNIDADE = m.UNIDADE)
          AND NOT EXISTS (SELECT 1 FROM #Dec d WHERE d.UNIDADE = m.UNIDADE)
        GROUP BY m.UNIDADE;

        -- Access mudou depois da correção: avisa para revisar
        SELECT x.UNIDADE, MIN(x.MSG) AS MSG
        INTO #Rev
        FROM (
            SELECT o.UNIDADE, N'A linha ' + CONVERT(NVARCHAR(12), o.NUM) + N' mudou no Access depois da correção' AS MSG
            FROM MIG.Caso_Correcao_Linha o
            INNER JOIN MIG.Movimento m ON m.ORIGEM = o.ORIGEM AND m.NUM = o.NUM
            WHERE o.HASH_ACCESS IS NOT NULL AND o.HASH_ACCESS <> m.HASH_CONTEUDO
            UNION ALL
            SELECT o.UNIDADE, N'A linha ' + CONVERT(NVARCHAR(12), o.NUM) + N' foi apagada no Access depois da correção'
            FROM MIG.Caso_Correcao_Linha o
            WHERE NOT EXISTS (SELECT 1 FROM MIG.Movimento m WHERE m.ORIGEM = o.ORIGEM AND m.NUM = o.NUM AND m.DESTINO = 'SISTEMA')
            UNION ALL
            SELECT cc.UNIDADE, CASE WHEN h.H IS NULL THEN N'O documento não existe mais no Access'
                                    ELSE N'O documento mudou no Access depois da decisão' END
            FROM MIG.Caso_Correcao cc
            CROSS APPLY (SELECT MIG.fn_MIG_Hash_Unidade(cc.UNIDADE) AS H) h
            WHERE cc.HASH_ACCESS IS NOT NULL AND (h.H IS NULL OR h.H <> cc.HASH_ACCESS)
        ) x
        WHERE @Filtrar = 0 OR x.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s)
        GROUP BY x.UNIDADE;

        -- documento corrigido que sumiu do Access: continua na tela, para revisar
        INSERT INTO #CasoNovo (UNIDADE, PADRAO, REGRA, MOTIVO, DETALHE, N, D, C, DT)
        SELECT r.UNIDADE, '', 'APAGADO', N'Documento não existe mais no Access', N'', 0, 0, 0, NULL
        FROM #Rev r
        WHERE NOT EXISTS (SELECT 1 FROM #CasoNovo n WHERE n.UNIDADE = r.UNIDADE)
          AND NOT EXISTS (SELECT 1 FROM MIG.Movimento m WHERE m.UNIDADE = r.UNIDADE AND m.DESTINO = 'SISTEMA');

        BEGIN TRANSACTION;
        WITH Alvo AS (SELECT * FROM MIG.Caso c WHERE @Filtrar = 0 OR c.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s))
        MERGE Alvo AS c
        USING (SELECT n.*, ISNULL(r.MSG, N'') AS REV FROM #CasoNovo n LEFT JOIN #Rev r ON r.UNIDADE = n.UNIDADE) AS n ON n.UNIDADE = c.UNIDADE
        WHEN MATCHED THEN UPDATE SET
             c.PADRAO = n.PADRAO, c.REGRA_ATUAL = n.REGRA, c.MOTIVO = n.MOTIVO, c.DETALHE = n.DETALHE,
             c.LINHAS = n.N, c.VALOR_DEBITO = n.D, c.VALOR_CREDITO = n.C, c.DT_DOCUMENTO = n.DT, c.DT_CALCULO = SYSDATETIME(), c.REVISAR = n.REV,
             c.MOTIVO_ORIGINAL = CASE WHEN c.MOTIVO_ORIGINAL = N'' THEN c.MOTIVO ELSE c.MOTIVO_ORIGINAL END
        WHEN NOT MATCHED BY TARGET THEN
             INSERT (UNIDADE, PADRAO, REGRA_ATUAL, MOTIVO, MOTIVO_ORIGINAL, DETALHE, LINHAS, VALOR_DEBITO, VALOR_CREDITO, DT_DOCUMENTO, REVISAR)
             VALUES (n.UNIDADE, n.PADRAO, n.REGRA, n.MOTIVO, n.MOTIVO, n.DETALHE, n.N, n.D, n.C, n.DT, n.REV)
        WHEN NOT MATCHED BY SOURCE THEN DELETE;
        COMMIT TRANSACTION;

        -- conferência de um documento só (tela de casos)
        IF @Filtrar = 1
        BEGIN
            SELECT s.UNIDADE,
                   CAST(COALESCE(n.REGRA, u.REGRA, 'SEM_LINHAS') AS VARCHAR(15)) AS REGRA,
                   COALESCE(n.MOTIVO, u.MOTIVO, N'') AS MOTIVO,
                   COALESCE(n.DETALHE, u.DETALHE, N'') AS DETALHE,
                   ISNULL(r.MSG, N'') AS REVISAR
            FROM #Sel s
            LEFT JOIN #CasoNovo n ON n.UNIDADE = s.UNIDADE
            LEFT JOIN #U u ON u.UNIDADE = s.UNIDADE
            LEFT JOIN #Rev r ON r.UNIDADE = s.UNIDADE
            ORDER BY s.PEDIDO DESC, s.UNIDADE;
            DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;
            RETURN;
        END;

        /* ------------------------------------------------------------------
           Prévia
           ------------------------------------------------------------------ */
        IF ISNULL(@Executar, 0) = 0
        BEGIN
            SELECT 'PREVIA' AS GRADE, u.REGRA, COUNT(*) AS DOCUMENTOS, SUM(u.N) AS LINHAS, SUM(u.S_DEB_TOTAL) AS DEBITOS, SUM(u.S_CRE_TOTAL) AS CREDITOS
            FROM #U u GROUP BY u.REGRA ORDER BY u.REGRA;
            SELECT 'TITULOS' AS GRADE, t.REGRA, t.TIPO, COUNT(*) AS LANCAMENTOS, SUM(t.VALOR) AS VALOR,
                   SUM(CASE WHEN t.PAGO = 1 THEN 1 ELSE 0 END) AS PAGOS, SUM(CASE WHEN t.PAGO = 0 THEN 1 ELSE 0 END) AS EM_ABERTO,
                   SUM(CASE WHEN t.PAGO = 1 AND t.COMPENSADO = 0 THEN 1 ELSE 0 END) AS NAO_COMPENSADOS,
                   SUM(CASE WHEN t.ID_PESSOA IS NULL THEN 1 ELSE 0 END) AS SEM_PESSOA, SUM(CASE WHEN t.ID_PLANO IS NULL THEN 1 ELSE 0 END) AS SEM_PLANO,
                   SUM(CASE WHEN t.ID_CENTRO IS NULL THEN 1 ELSE 0 END) AS SEM_CENTRO,
                   SUM(CASE WHEN t.PAGO = 1 AND t.ID_CONTA_PAG IS NULL THEN 1 ELSE 0 END) AS PAGO_SEM_CONTA
            FROM #T t GROUP BY t.REGRA, t.TIPO ORDER BY t.REGRA, t.TIPO;
            SELECT 'TRANSFERENCIAS' AS GRADE, r.REGRA, r.TC, COUNT(*) AS QTD, SUM(r.VALOR) AS VALOR FROM #TR r GROUP BY r.REGRA, r.TC;
            SELECT 'ABATIMENTOS' AS GRADE, a.UNIDADE, a.LINK, a.VALOR, a.T_VALOR AS VALOR_PARCELA, a.T_VALOR - a.VALOR AS SALDO, a.ERRO FROM #Ab a ORDER BY a.UNIDADE;
            SELECT 'CASOS' AS GRADE, c.MOTIVO, COUNT(*) AS DOCUMENTOS, SUM(c.LINHAS) AS LINHAS FROM MIG.Caso c WHERE c.REGRA_ATUAL = 'CASO' GROUP BY c.MOTIVO ORDER BY COUNT(*) DESC;
            DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;
            RETURN;
        END;

        /* ------------------------------------------------------------------
           5. Gravação (tudo-ou-nada)
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Gravação: limpeza da carga anterior';
        BEGIN TRANSACTION;

        DELETE b FROM FIN.Baixa b
        INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE l.ORIGEM = 'MIGRACAO';
        DELETE m FROM BANCO.Movimento m INNER JOIN SIS.Lote x ON x.ID_LOTE = m.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO';
        DELETE t FROM FIN.Transferencia t INNER JOIN SIS.Lote x ON x.ID_LOTE = t.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO';
        DELETE p FROM FIN.Parcela p INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.ORIGEM = 'MIGRACAO';
        DELETE FROM MIG.DePara_Venda;
        DELETE FROM FIN.Lancamento WHERE ORIGEM = 'MIGRACAO';
        DELETE FROM SIS.Lote WHERE ORIGEM = 'MIGRACAO';
        DELETE FROM MIG.Linha_Destino;

        SET @EtapaAtual = 'Gravação: caixas';
        INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, CONCILIA, MOSTRA_SALDO, ATIVO, USUARIO_CRIACAO)
        SELECT DISTINCT e.ID_EMPRESA, @NomeCaixa, 'CAIXA', 0, 1, 1, @Usuario
        FROM #T t
        INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = t.ID_EMPRESA
        WHERE t.TC_PAG = 'NA' AND t.ID_CONTA_PAG IS NULL
          AND NOT EXISTS (SELECT 1 FROM BANCO.Conta k WHERE k.ID_EMPRESA = e.ID_EMPRESA AND k.DESCRICAO = @NomeCaixa);
        UPDATE t SET t.ID_CONTA_PAG = k.ID_CONTA
        FROM #T t INNER JOIN BANCO.Conta k ON k.ID_EMPRESA = t.ID_EMPRESA AND k.DESCRICAO = @NomeCaixa
        WHERE t.TC_PAG = 'NA' AND t.ID_CONTA_PAG IS NULL;

        SET @EtapaAtual = 'Gravação: lotes';
        INSERT INTO SIS.Lote (ORIGEM, DESCRICAO, TABELA_REFERENCIA, QTD_REGISTROS, USUARIO_CRIACAO)
        VALUES ('MIGRACAO', N'Migração do movimento do Access (lançamentos avulsos, vendas e transferências)', N'FIN.Lancamento', 0, @Usuario);
        SET @IdLoteGeral = SCOPE_IDENTITY();

        CREATE TABLE #MapLote (UNIDADE VARCHAR(40) PRIMARY KEY, ID_LOTE BIGINT);
        MERGE SIS.Lote AS d
        USING (SELECT t.UNIDADE, COUNT(*) AS QTD FROM #T t WHERE t.REGRA = 'LOTE' GROUP BY t.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (ORIGEM, DESCRICAO, TABELA_REFERENCIA, QTD_REGISTROS, USUARIO_CRIACAO)
             VALUES ('MIGRACAO', N'Pagamento em lote do Access nº ' + SUBSTRING(s.UNIDADE, 3, 20), N'FIN.Lancamento', s.QTD, @Usuario)
        OUTPUT s.UNIDADE, inserted.ID_LOTE INTO #MapLote (UNIDADE, ID_LOTE);

        SET @EtapaAtual = 'Gravação: lançamentos';
        CREATE TABLE #MapLanc (ORIGEM VARCHAR(20), NUM INT, ID_LANCAMENTO BIGINT, PRIMARY KEY (ORIGEM, NUM));
        MERGE FIN.Lancamento AS d
        USING (SELECT t.*, ISNULL(ml.ID_LOTE, @IdLoteGeral) AS ID_LOTE FROM #T t LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (TIPO, ID_EMPRESA, ID_CENTRO_CUSTO, ID_PESSOA, ID_PLANO_CONTA, ID_HISTORICO_PADRAO, DOCUMENTO, DT_EMISSAO, DT_COMPETENCIA,
                                      HISTORICO, OBSERVACAO, VALOR_TOTAL, ORIGEM, ID_LOTE, INTEGRACAO, CODIGO_ACCESS, ORIGEM_ACCESS, USUARIO_CRIACAO)
             VALUES (s.TIPO, s.ID_EMPRESA, s.ID_CENTRO, s.ID_PESSOA, s.ID_PLANO, s.ID_HIST, s.DOCUMENTO, s.DT_EMISSAO, DATEFROMPARTS(YEAR(s.DT_EMISSAO), MONTH(s.DT_EMISSAO), 1),
                     s.HISTORICO, s.OBSERVACAO, s.VALOR, 'MIGRACAO', s.ID_LOTE, s.INTEGRACAO, s.NUM, s.ORIGEM, @Usuario)
        OUTPUT s.ORIGEM, s.NUM, inserted.ID_LANCAMENTO INTO #MapLanc (ORIGEM, NUM, ID_LANCAMENTO);

        SET @EtapaAtual = 'Gravação: parcelas';
        INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR, ID_CONTA_PREVISTA, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT m.ID_LANCAMENTO, 1, 1, t.DT_VENC, t.VALOR, t.ID_CONTA_PAG, ISNULL(ml.ID_LOTE, @IdLoteGeral), t.NUM, @Usuario
        FROM #T t
        INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE;

        SET @EtapaAtual = 'Gravação: movimentos das baixas';
        -- um movimento por saída/entrada (no lote, um só pelo total)
        SELECT t.PAG_ORIGEM, t.PAG_NUM, MIN(t.UNIDADE) AS UNIDADE, MIN(t.ID_CONTA_PAG) AS ID_CONTA, MIN(t.DT_PAG) AS DT,
               SUM(CASE WHEN t.TIPO = 'P' THEN -t.VALOR ELSE t.VALOR END) AS VALOR,
               CAST(LEFT(MIN(t.HIST_PAG), 200) AS NVARCHAR(200)) AS HISTORICO, CAST(LEFT(MIN(t.DOC_PAG), 40) AS NVARCHAR(40)) AS DOCUMENTO
        INTO #Mov
        FROM #T t
        WHERE t.GERA_MOV = 1
        GROUP BY t.PAG_ORIGEM, t.PAG_NUM;

        CREATE TABLE #MapMov (PAG_ORIGEM VARCHAR(20), PAG_NUM INT, ID_MOVIMENTO BIGINT, PRIMARY KEY (PAG_ORIGEM, PAG_NUM));
        MERGE BANCO.Movimento AS d
        USING (SELECT v.*, ISNULL(ml.ID_LOTE, @IdLoteGeral) AS ID_LOTE FROM #Mov v LEFT JOIN #MapLote ml ON ml.UNIDADE = v.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
             VALUES (s.ID_CONTA, s.DT, s.VALOR, 'BAIXA', s.HISTORICO, s.DOCUMENTO, s.ID_LOTE, s.PAG_NUM, @Usuario)
        OUTPUT s.PAG_ORIGEM, s.PAG_NUM, inserted.ID_MOVIMENTO INTO #MapMov (PAG_ORIGEM, PAG_NUM, ID_MOVIMENTO);

        SET @EtapaAtual = 'Gravação: baixas';
        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, ID_MOVIMENTO, COMPENSADO, DT_COMPENSACAO, OBSERVACAO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT p.ID_PARCELA, t.DT_PAG, t.ID_CONTA_PAG, CASE WHEN t.COMPENSADO = 0 THEN 'CHEQUE' ELSE 'OUTRA' END, t.VALOR, mm.ID_MOVIMENTO,
               t.COMPENSADO, CASE WHEN t.COMPENSADO = 1 THEN t.DT_PAG END,
               CAST(CASE WHEN t.SOI_PAG = 1 THEN N'Somente integração no Access: sem movimento no banco.' ELSE N'' END AS NVARCHAR(400)),
               ISNULL(ml.ID_LOTE, @IdLoteGeral), t.PAG_NUM, @Usuario
        FROM #T t
        INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        INNER JOIN FIN.Parcela p ON p.ID_LANCAMENTO = m.ID_LANCAMENTO
        LEFT JOIN #MapMov mm ON mm.PAG_ORIGEM = t.PAG_ORIGEM AND mm.PAG_NUM = t.PAG_NUM
        LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE
        WHERE t.PAGO = 1 AND t.ID_CONTA_PAG IS NOT NULL;

        SET @EtapaAtual = 'Gravação: abatimentos';
        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, ABATIMENTO, ID_MOVIMENTO, COMPENSADO, DT_COMPENSACAO,
                               OBSERVACAO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT p.ID_PARCELA, a.DT, a.ID_CONTA, 'OUTRA', a.VALOR, a.VALOR, NULL, 1, a.DT,
               CAST(LEFT(N'Abatimento sem dinheiro: "crédito" do Access nº ' + CONVERT(NVARCHAR(12), a.NUM) + N' (documento ' + a.UNIDADE + N'). '
                         + ISNULL(a.MOTIVO_TELA, N''), 400) AS NVARCHAR(400)),
               @IdLoteGeral, a.NUM, @Usuario
        FROM #Ab a
        INNER JOIN #MapLanc m ON m.ORIGEM = a.T_ORIGEM AND m.NUM = a.T_NUM
        INNER JOIN FIN.Parcela p ON p.ID_LANCAMENTO = m.ID_LANCAMENTO
        WHERE a.ERRO = N'';

        SET @EtapaAtual = 'Gravação: transferências';
        CREATE TABLE #MapTr (ORIGEM VARCHAR(20), NUM INT, ID_TRANSFERENCIA BIGINT, PRIMARY KEY (ORIGEM, NUM));
        MERGE FIN.Transferencia AS d
        USING #TR AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (DT_TRANSFERENCIA, ID_CONTA_ORIGEM, ID_CONTA_DESTINO, VALOR, HISTORICO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
             VALUES (s.DT, s.ID_ORIGEM, s.ID_DESTINO, s.VALOR, s.HISTORICO, @IdLoteGeral, s.NUM, @Usuario)
        OUTPUT s.ORIGEM, s.NUM, inserted.ID_TRANSFERENCIA INTO #MapTr (ORIGEM, NUM, ID_TRANSFERENCIA);

        INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, ID_TRANSFERENCIA, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT x.ID_CONTA, r.DT, x.VALOR, 'TRANSFERENCIA', r.HISTORICO, mt.ID_TRANSFERENCIA, @IdLoteGeral, r.NUM, @Usuario
        FROM #TR r
        INNER JOIN #MapTr mt ON mt.ORIGEM = r.ORIGEM AND mt.NUM = r.NUM
        CROSS APPLY (VALUES (r.ID_ORIGEM, -r.VALOR), (r.ID_DESTINO, r.VALOR)) x (ID_CONTA, VALOR);

        SET @EtapaAtual = 'Gravação: destino das linhas';
        INSERT INTO MIG.Linha_Destino (ORIGEM, NUM, UNIDADE, REGRA, PAPEL, ID_LANCAMENTO, ID_MOVIMENTO, ID_TRANSFERENCIA, ID_CONTA, VALOR)
        SELECT l.ORIGEM, l.NUM, l.UNIDADE, u.REGRA,
               CASE WHEN tt.NUM IS NOT NULL THEN 'TITULO'
                    WHEN pg.PAG_NUM IS NOT NULL THEN 'PAGAMENTO'
                    WHEN tr.NUM IS NOT NULL OR tb.NUM IS NOT NULL THEN 'TRANSFERENCIA'
                    WHEN u.REGRA = 'CASO' THEN 'CASO'
                    ELSE 'CONTRAPARTIDA' END,
               ml.ID_LANCAMENTO,
               COALESCE(mm.ID_MOVIMENTO, mm2.ID_MOVIMENTO),
               COALESCE(mt.ID_TRANSFERENCIA, mt2.ID_TRANSFERENCIA),
               COALESCE(tt.ID_CONTA_PAG, pg.ID_CONTA, tr.ID_BANCO, tb.ID_BANCO),
               l.VALOR
        FROM #L l
        INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
        LEFT JOIN #T tt ON tt.ORIGEM = l.ORIGEM AND tt.NUM = l.NUM
        LEFT JOIN #MapLanc ml ON ml.ORIGEM = l.ORIGEM AND ml.NUM = l.NUM
        LEFT JOIN (SELECT PAG_ORIGEM, PAG_NUM, MIN(ID_CONTA_PAG) AS ID_CONTA FROM #T GROUP BY PAG_ORIGEM, PAG_NUM) pg ON pg.PAG_ORIGEM = l.ORIGEM AND pg.PAG_NUM = l.NUM AND tt.NUM IS NULL
        LEFT JOIN #MapMov mm ON mm.PAG_ORIGEM = l.ORIGEM AND mm.PAG_NUM = l.NUM
        LEFT JOIN #MapMov mm2 ON mm2.PAG_ORIGEM = tt.PAG_ORIGEM AND mm2.PAG_NUM = tt.PAG_NUM AND mm.ID_MOVIMENTO IS NULL
        LEFT JOIN #TR tr ON tr.ORIGEM = l.ORIGEM AND tr.NUM = l.NUM
        LEFT JOIN #TR tb ON tb.BCO_ORIGEM = l.ORIGEM AND tb.BCO_NUM = l.NUM
        LEFT JOIN #MapTr mt ON mt.ORIGEM = l.ORIGEM AND mt.NUM = l.NUM
        LEFT JOIN #MapTr mt2 ON mt2.ORIGEM = tb.ORIGEM AND mt2.NUM = tb.NUM;

        INSERT INTO MIG.Linha_Destino (ORIGEM, NUM, UNIDADE, REGRA, PAPEL, ID_LANCAMENTO, ID_MOVIMENTO, ID_TRANSFERENCIA, ID_CONTA, VALOR)
        SELECT v.ORIGEM, v.NUM, a.UNIDADE, 'ABATER', 'ABATIMENTO', m.ID_LANCAMENTO, NULL, NULL, a.ID_CONTA,
               ISNULL(mv.VALOR_DEBITO, 0) + ISNULL(mv.VALOR_CREDITO, 0)
        FROM #Ab a
        INNER JOIN #MapLanc m ON m.ORIGEM = a.T_ORIGEM AND m.NUM = a.T_NUM
        INNER JOIN MIG.vw_MIG_Linha_Unidade v ON v.UNIDADE = a.UNIDADE
        INNER JOIN MIG.Movimento mv ON mv.ORIGEM = v.ORIGEM AND mv.NUM = v.NUM
        WHERE a.ERRO = N''
          AND NOT EXISTS (SELECT 1 FROM MIG.Linha_Destino d WHERE d.ORIGEM = v.ORIGEM AND d.NUM = v.NUM);

        INSERT INTO MIG.DePara_Venda (ID_LANCAMENTO, ORIGEM, NUM, LINK_VENDA, IMOVEL, PARCEIRO, CONTRATO, NUM_DOC)
        SELECT m.ID_LANCAMENTO, t.ORIGEM, t.NUM, ISNULL(t.LINK_VENDA, 0), t.IMOVEL, t.PAR, ISNULL(t.CONTRATO, ''), CAST(LEFT(ISNULL(t.NUM_DOC, N''), 100) AS NVARCHAR(100))
        FROM #T t INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        WHERE t.REGRA = 'VENDA';

        UPDATE SIS.Lote SET QTD_REGISTROS = (SELECT COUNT(*) FROM FIN.Lancamento l WHERE l.ID_LOTE = @IdLoteGeral) WHERE ID_LOTE = @IdLoteGeral;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;

        SELECT 'GRAVADO' AS GRADE, r.ORDEM, r.ITEM, r.QTD, r.VALOR
        FROM (
            SELECT 1 AS ORDEM, N'Lançamentos a pagar' AS ITEM, COUNT(*) AS QTD, SUM(l.VALOR_TOTAL) AS VALOR FROM FIN.Lancamento l WHERE l.ORIGEM = 'MIGRACAO' AND l.TIPO = 'P'
            UNION ALL SELECT 2, N'Lançamentos a receber', COUNT(*), SUM(l.VALOR_TOTAL) FROM FIN.Lancamento l WHERE l.ORIGEM = 'MIGRACAO' AND l.TIPO = 'R'
            UNION ALL SELECT 3, N'Parcelas em aberto', COUNT(*), SUM(p.SALDO) FROM FIN.Parcela p INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.ORIGEM = 'MIGRACAO' AND p.SALDO > 0
            UNION ALL SELECT 4, N'Baixas', COUNT(*), SUM(b.VALOR_LIQUIDO) FROM FIN.Baixa b INNER JOIN SIS.Lote x ON x.ID_LOTE = b.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 5, N'Movimentos de baixa (banco/caixa)', COUNT(*), SUM(m.VALOR) FROM BANCO.Movimento m INNER JOIN SIS.Lote x ON x.ID_LOTE = m.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO' AND m.TIPO = 'BAIXA'
            UNION ALL SELECT 6, N'Transferências', COUNT(*), SUM(t.VALOR) FROM FIN.Transferencia t INNER JOIN SIS.Lote x ON x.ID_LOTE = t.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 7, N'Lotes do Access', COUNT(*) - 1, NULL FROM SIS.Lote x WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 8, N'Abatimentos de parcela (sem dinheiro)', COUNT(*), SUM(b.ABATIMENTO) FROM FIN.Baixa b INNER JOIN SIS.Lote x ON x.ID_LOTE = b.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO' AND b.ABATIMENTO > 0
            UNION ALL SELECT 9, N'Casos para a tela', COUNT(*), SUM(c.VALOR_DEBITO + c.VALOR_CREDITO) FROM MIG.Caso c WHERE c.REGRA_ATUAL = 'CASO'
        ) r ORDER BY r.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
