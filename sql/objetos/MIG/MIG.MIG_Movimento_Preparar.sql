/*******************************************************************************
  Objeto      : [MIG].[MIG_Movimento_Preparar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Junta o movimento atual e o arquivo morto do Access numa tabela
                tipada (MIG.Movimento) e classifica cada linha, com as regras de
                docs/requisitos/Migracao_Movimento.md:
                - SD_ACUM: linha de saldo acumulado da virada de ano
                  (NumDoc "Sd Acum"): não é movimento;
                - DUPLICADA: linha do arquivo morto igual, campo a campo (fora o
                  número), a uma do movimento atual: fica a do movimento atual;
                - DT_VALIDA: data do movimento entre 2000 e 2035; se não, a de
                  vencimento; se nenhuma, NULL (lista de casos; regra 43);
                - UNIDADE: documento do sistema novo: o lote de pagamento
                  (MovPagtoLote, junta as duas tabelas), a venda (LinkVenda) ou
                  a própria linha;
                - DT_UNIDADE: maior data das linhas de banco/caixa da unidade
                  (ou de qualquer linha, se não houver banco); antes de @Corte
                  = arquivo morto;
                - CONTRATO de venda (imóvel + cliente da parcela): se alguma
                  parcela é de @Corte em diante, o contrato inteiro vai para o
                  sistema novo (extrato e ficha do contrato completos);
                - PADRAO: combinação dos tipos de conta e lados da unidade
                  (ex.: L|BCO-D|CRED-C|LOTE-D).
                Contas de sistema do Access: 1 Créditos, 2 Débitos, 3 Pagto em
                Lote, 9 N/A (caixinha). Repetível: recria MIG.Movimento.
                Devolve o resumo da classificação.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
    v1.1 (17/11/2026) - Corte em parâmetro (@Corte, padrão 01/01/2022, decisão
                        do Celso) e contrato de venda inteiro no sistema novo.
    v1.2 (19/11/2026) - Índice por (ORIGEM, NUM), para a tela de casos.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- MIG.Movimento é refeita a cada ensaio: apagar aqui evita erro de compilação
-- quando a estrutura dela muda entre versões desta procedure.
DROP TABLE IF EXISTS MIG.Movimento;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Movimento_Preparar]
    @Corte  DATE = '2022-01-01'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Movimento_Preparar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Tipagem';

    BEGIN TRY
        DROP TABLE IF EXISTS MIG.Movimento;

        ;WITH Fonte AS
        (
            SELECT CAST('ACCESS_MOVTO' AS VARCHAR(20)) AS ORIGEM, m.* FROM MIG.Access_Movimento m
            UNION ALL
            SELECT CAST('ACCESS_ARQMORTO' AS VARCHAR(20)), a.* FROM MIG.Access_ArquivoMorto a
        )
        SELECT IDENTITY(BIGINT, 1, 1) AS ID_MIG,
               f.ORIGEM,
               TRY_CONVERT(INT, f.NumMovimento)                              AS NUM,
               TRY_CONVERT(INT, f.EmpVinculada)                              AS EMP_VINCULADA,
               TRY_CONVERT(INT, f.CodigoParceiro)                            AS PARCEIRO,
               TRY_CONVERT(INT, f.CodHistorico)                              AS HISTORICO,
               TRY_CONVERT(DATE, LEFT(f.DataMovto, 10), 23)                  AS DT_MOVTO,
               TRY_CONVERT(DATE, LEFT(f.DataVencto, 10), 23)                 AS DT_VENCTO,
               TRY_CONVERT(DATE, LEFT(f.DataPagto, 10), 23)                  AS DT_PAGTO,
               ROUND(ISNULL(TRY_CONVERT(DECIMAL(19,6), f.ValorDebito), 0), 2)  AS VALOR_DEBITO,
               ROUND(ISNULL(TRY_CONVERT(DECIMAL(19,6), f.ValorCredito), 0), 2) AS VALOR_CREDITO,
               ISNULL(f.Complemento, N'')                                    AS COMPLEMENTO,
               TRY_CONVERT(INT, f.Plano1) AS PLANO1, TRY_CONVERT(INT, f.Plano2) AS PLANO2, TRY_CONVERT(INT, f.Plano3) AS PLANO3,
               TRY_CONVERT(INT, f.ContaFinanceira)                           AS CONTA,
               CAST(CASE WHEN f.Confirmado = N'True' THEN 1 ELSE 0 END AS BIT)        AS CONFIRMADO,
               CAST(CASE WHEN f.Efetuado = N'True' THEN 1 ELSE 0 END AS BIT)          AS EFETUADO,
               CAST(CASE WHEN f.Integracao = N'True' THEN 1 ELSE 0 END AS BIT)        AS INTEGRACAO,
               CAST(CASE WHEN f.SomenteIntegracao = N'True' THEN 1 ELSE 0 END AS BIT) AS SOMENTE_INTEGRACAO,
               CAST(CASE WHEN f.PagamentoLote = N'True' THEN 1 ELSE 0 END AS BIT)     AS PAGAMENTO_LOTE,
               ISNULL(TRY_CONVERT(INT, f.MovPagtoLote), 0)                   AS LOTE,
               ISNULL(TRY_CONVERT(INT, f.LinkVenda), 0)                      AS LINK_VENDA,
               TRY_CONVERT(INT, f.CodImovel)                                 AS IMOVEL,
               ISNULL(f.ClassificacaoVenda, N'')                             AS CLASSIF_VENDA,
               ISNULL(f.NumDoc, N'')                                         AS NUM_DOC,
               ISNULL(f.ReferenteNotaFiscal, N'')                            AS NOTA_FISCAL,
               ISNULL(f.Observacao, N'')                                     AS OBSERVACAO,
               HASHBYTES('SHA2_256', CONCAT_WS(N'|', f.EmpVinculada, f.CodigoParceiro, f.CodHistorico, f.DataMovto, f.ValorDebito, f.ValorCredito,
                         f.Complemento, f.Plano1, f.Plano2, f.Plano3, f.ContaFinanceira, f.Confirmado, f.Integracao, f.DataPagto, f.DataVencto,
                         f.MovPagtoLote, f.SelPagtoLote, f.Observacao, f.NumDoc, f.CodImovel, f.AgrupadorVenda, f.ClassificacaoVenda, f.SofreReajuste,
                         f.IndiceReajuste, f.CodAtribuiParceiro, f.CodAtribuiEmpresa, f.CodAnteriorParceiro, f.CodAnteriorEmpresa, f.Efetuado,
                         f.LinkVenda, f.PagoAntecipado, f.ValorReajustado, f.ReferenteNotaFiscal, f.PagamentoLote, f.PadraoRelatorio,
                         f.SomenteIntegracao, f.AnoOcorrenciaMensal, f.MesOcorrenciaMensal, f.EmitirCheque, f.ChequeEmitido,
                         f.ValorOriginalImovel, f.CodigoCondPagto)) AS HASH_CONTEUDO,
               CAST(0 AS BIT)                 AS SD_ACUM,
               CAST(0 AS BIT)                 AS DUPLICADA,
               CAST(NULL AS DATE)             AS DT_VALIDA,
               CAST('' AS VARCHAR(6))         AS TIPO_CONTA,
               CAST('' AS CHAR(1))            AS LADO,
               CAST('' AS VARCHAR(40))        AS UNIDADE,
               CAST(NULL AS DATE)             AS DT_UNIDADE,
               CAST('' AS VARCHAR(200))       AS PADRAO,
               CAST('' AS VARCHAR(40))        AS CONTRATO,
               CAST('' AS VARCHAR(12))        AS DESTINO
        INTO MIG.Movimento
        FROM Fonte f;

        CREATE UNIQUE CLUSTERED INDEX IX_MIG_Movimento_ID ON MIG.Movimento (ID_MIG);

        SET @EtapaAtual = 'Classificação da linha';
        UPDATE m
           SET m.SD_ACUM    = CASE WHEN LTRIM(RTRIM(m.NUM_DOC)) = N'Sd Acum' THEN 1 ELSE 0 END,
               m.DT_VALIDA  = CASE WHEN m.DT_MOVTO  BETWEEN '2000-01-01' AND '2035-12-31' THEN m.DT_MOVTO
                                   WHEN m.DT_VENCTO BETWEEN '2000-01-01' AND '2035-12-31' THEN m.DT_VENCTO END,
               m.TIPO_CONTA = CASE m.CONTA WHEN 1 THEN 'CRED' WHEN 2 THEN 'DEB' WHEN 3 THEN 'LOTE' WHEN 9 THEN 'NA' ELSE 'BCO' END,
               m.LADO       = CASE WHEN m.VALOR_DEBITO > 0 THEN 'D' WHEN m.VALOR_CREDITO > 0 THEN 'C' ELSE '0' END
        FROM MIG.Movimento m;

        UPDATE a
           SET a.DUPLICADA = 1
        FROM MIG.Movimento a
        WHERE a.ORIGEM = 'ACCESS_ARQMORTO'
          AND EXISTS (SELECT 1 FROM MIG.Movimento m WHERE m.ORIGEM = 'ACCESS_MOVTO' AND m.HASH_CONTEUDO = a.HASH_CONTEUDO);

        SET @EtapaAtual = 'Unidades';
        UPDATE m
           SET m.UNIDADE = CASE WHEN m.LOTE > 0       THEN 'L:' + CONVERT(VARCHAR(20), m.LOTE)
                                WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
                                ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END
        FROM MIG.Movimento m
        WHERE m.SD_ACUM = 0 AND m.DUPLICADA = 0;

        CREATE INDEX IX_MIG_Movimento_UNIDADE ON MIG.Movimento (UNIDADE) INCLUDE (TIPO_CONTA, LADO, DT_VALIDA);
        CREATE INDEX IX_MIG_Movimento_ORIGEM_NUM ON MIG.Movimento (ORIGEM, NUM) INCLUDE (UNIDADE, DESTINO, LINK_VENDA, LOTE);

        SELECT x.UNIDADE,
               COALESCE(MAX(CASE WHEN x.TIPO_CONTA IN ('BCO', 'NA') THEN x.DT_VALIDA END), MAX(x.DT_VALIDA)) AS DT_UNIDADE,
               CAST('' AS VARCHAR(200)) AS PADRAO
        INTO #U
        FROM MIG.Movimento x
        WHERE x.UNIDADE <> ''
        GROUP BY x.UNIDADE;

        ;WITH P AS
        (
            SELECT d.UNIDADE, LEFT(d.UNIDADE, 1) + '|' + STRING_AGG(CAST(d.PAR AS VARCHAR(MAX)), '|') WITHIN GROUP (ORDER BY d.PAR) AS PADRAO
            FROM (SELECT DISTINCT x.UNIDADE, x.TIPO_CONTA + '-' + x.LADO AS PAR FROM MIG.Movimento x WHERE x.UNIDADE <> '') d
            GROUP BY d.UNIDADE
        )
        UPDATE u SET u.PADRAO = LEFT(p.PADRAO, 200) FROM #U u INNER JOIN P p ON p.UNIDADE = u.UNIDADE;

        UPDATE m
           SET m.DT_UNIDADE = u.DT_UNIDADE,
               m.PADRAO     = u.PADRAO
        FROM MIG.Movimento m
        INNER JOIN #U u ON u.UNIDADE = m.UNIDADE;

        SET @EtapaAtual = 'Destino';
        UPDATE m
           SET m.DESTINO = CASE WHEN m.DUPLICADA = 1                        THEN 'FORA_DUPLIC'
                                WHEN m.SD_ACUM = 1 AND m.DT_VALIDA <= @Corte THEN 'ARQ_MORTO'
                                WHEN m.SD_ACUM = 1                          THEN 'FORA_SDACUM'
                                WHEN m.DT_UNIDADE IS NULL                   THEN 'CASO_DATA'
                                WHEN m.DT_UNIDADE < @Corte                  THEN 'ARQ_MORTO'
                                ELSE 'SISTEMA' END
        FROM MIG.Movimento m;

        -- contrato de venda: imóvel + cliente da parcela (linha na conta 2 "Débitos")
        ;WITH C AS
        (
            SELECT d.UNIDADE, MIN(CONVERT(VARCHAR(12), d.IMOVEL) + ':' + CONVERT(VARCHAR(12), d.PARCEIRO)) AS CONTRATO
            FROM MIG.Movimento d
            WHERE d.UNIDADE LIKE 'V:%' AND d.CONTA = 2
            GROUP BY d.UNIDADE
        )
        UPDATE m SET m.CONTRATO = c.CONTRATO
        FROM MIG.Movimento m INNER JOIN C c ON c.UNIDADE = m.UNIDADE;

        UPDATE m
           SET m.DESTINO = 'SISTEMA'
        FROM MIG.Movimento m
        WHERE m.DESTINO = 'ARQ_MORTO' AND m.CONTRATO <> ''
          AND EXISTS (SELECT 1 FROM MIG.Movimento x WHERE x.CONTRATO = m.CONTRATO AND x.DESTINO = 'SISTEMA');

        DROP TABLE IF EXISTS #U;

        SELECT m.DESTINO, COUNT(*) AS LINHAS, COUNT(DISTINCT NULLIF(m.UNIDADE, '')) AS DOCUMENTOS,
               SUM(m.VALOR_DEBITO) AS DEBITOS, SUM(m.VALOR_CREDITO) AS CREDITOS
        FROM MIG.Movimento m
        GROUP BY m.DESTINO
        ORDER BY m.DESTINO;
    END TRY
    BEGIN CATCH
        DROP TABLE IF EXISTS #U;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
