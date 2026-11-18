/*******************************************************************************
  Objeto      : [MIG].[MIG_Movimento_Conferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Conferência da transformação do movimento (etapa 03c2, parte B),
                Access x sistema novo. Grades:
                  1. RESUMO: linhas do Access por regra e papel (título,
                     pagamento, contrapartida, transferência, caso);
                  2. TITULOS_ANO: títulos do Access x lançamentos gravados, por
                     ano e tipo (valor, pagos, em aberto) - a diferença tem de
                     ser zero;
                  3. CONTAS: por conta, o que o Access tinha nas linhas de banco e
                     caixinha x movimentos gravados (baixas e transferências);
                     a diferença é explicada pelas transferências dos lançamentos
                     soltos e pelas baixas "somente integração";
                  4. EMPRESAS: lançamentos por empresa;
                  5. CASOS: documentos para a tela de correção.
                Só leitura.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
    v1.1 (18/11/2026) - Casos: só os que ainda não se encaixam, mais a grade
                        CASOS_SITUACAO (pendentes, corrigidos, ignorados, arquivo morto).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Movimento_Conferencia_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    /* 1. Resumo */
    SELECT 'RESUMO' AS GRADE, d.REGRA, d.PAPEL, COUNT(DISTINCT d.UNIDADE) AS DOCUMENTOS, COUNT(*) AS LINHAS, SUM(d.VALOR) AS VALOR
    FROM MIG.Linha_Destino d
    GROUP BY d.REGRA, d.PAPEL
    UNION ALL
    SELECT 'RESUMO', 'IGNORADA', 'CORRECAO', COUNT(DISTINCT m.UNIDADE), COUNT(*), SUM(m.VALOR_DEBITO + m.VALOR_CREDITO)
    FROM MIG.Movimento m
    WHERE m.DESTINO = 'SISTEMA' AND NOT EXISTS (SELECT 1 FROM MIG.Linha_Destino d WHERE d.ORIGEM = m.ORIGEM AND d.NUM = m.NUM)
    ORDER BY 2, 3;

    /* 2. Títulos por ano: Access x sistema */
    SELECT 'TITULOS_ANO' AS GRADE, YEAR(l.DT_EMISSAO) AS ANO, l.TIPO,
           COUNT(*) AS LANCAMENTOS,
           SUM(m.VALOR_DEBITO + m.VALOR_CREDITO) AS VALOR_ACCESS,
           SUM(l.VALOR_TOTAL) AS VALOR_SISTEMA,
           SUM(l.VALOR_TOTAL) - SUM(m.VALOR_DEBITO + m.VALOR_CREDITO) AS DIFERENCA,
           SUM(p.VALOR_BAIXADO) AS PAGO, SUM(p.SALDO) AS EM_ABERTO
    FROM MIG.Linha_Destino d
    INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
    INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = d.ID_LANCAMENTO
    INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_LANCAMENTO = l.ID_LANCAMENTO
    WHERE d.PAPEL = 'TITULO'
    GROUP BY YEAR(l.DT_EMISSAO), l.TIPO
    ORDER BY 2, 3;

    /* 3. Contas */
    ;WITH Acc AS
    (
        SELECT d.ID_CONTA,
               SUM(CASE WHEN m.CONTA NOT IN (1, 2, 3) THEN m.VALOR_CREDITO - m.VALOR_DEBITO ELSE 0 END) AS ACCESS_BANCO_CAIXINHA,
               SUM(CASE WHEN m.CONTA NOT IN (1, 2, 3) AND m.SOMENTE_INTEGRACAO = 1 THEN m.VALOR_CREDITO - m.VALOR_DEBITO ELSE 0 END) AS ACCESS_SOMENTE_INTEGRACAO
        FROM MIG.Linha_Destino d
        INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
        WHERE d.PAPEL IN ('PAGAMENTO', 'TITULO') AND d.ID_CONTA IS NOT NULL AND m.CONTA NOT IN (1, 2, 3)
          AND (d.PAPEL = 'PAGAMENTO' OR d.REGRA = 'AVULSO')
        GROUP BY d.ID_CONTA
    ),
    Novo AS
    (
        SELECT mv.ID_CONTA,
               SUM(CASE WHEN mv.TIPO = 'BAIXA' THEN mv.VALOR ELSE 0 END) AS NOVO_BAIXAS,
               SUM(CASE WHEN mv.TIPO = 'TRANSFERENCIA' THEN mv.VALOR ELSE 0 END) AS NOVO_TRANSFERENCIAS
        FROM BANCO.Movimento mv WITH (NOLOCK)
        INNER JOIN SIS.Lote x WITH (NOLOCK) ON x.ID_LOTE = mv.ID_LOTE
        WHERE x.ORIGEM = 'MIGRACAO'
        GROUP BY mv.ID_CONTA
    )
    SELECT 'CONTAS' AS GRADE, e.NOME_FANTASIA AS EMPRESA, k.DESCRICAO AS CONTA, k.TIPO,
           ISNULL(a.ACCESS_BANCO_CAIXINHA, 0) AS ACCESS_BANCO_CAIXINHA,
           ISNULL(a.ACCESS_SOMENTE_INTEGRACAO, 0) AS ACCESS_SOMENTE_INTEGRACAO,
           ISNULL(n.NOVO_BAIXAS, 0) AS NOVO_BAIXAS,
           ISNULL(n.NOVO_TRANSFERENCIAS, 0) AS NOVO_TRANSFERENCIAS,
           ISNULL(n.NOVO_BAIXAS, 0) - (ISNULL(a.ACCESS_BANCO_CAIXINHA, 0) - ISNULL(a.ACCESS_SOMENTE_INTEGRACAO, 0)) AS DIFERENCA_BAIXAS
    FROM BANCO.Conta k WITH (NOLOCK)
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = k.ID_EMPRESA
    LEFT JOIN Acc a ON a.ID_CONTA = k.ID_CONTA
    LEFT JOIN Novo n ON n.ID_CONTA = k.ID_CONTA
    WHERE a.ID_CONTA IS NOT NULL OR n.ID_CONTA IS NOT NULL
    ORDER BY e.NOME_FANTASIA, k.DESCRICAO;

    /* 4. Empresas */
    SELECT 'EMPRESAS' AS GRADE, e.NOME_FANTASIA AS EMPRESA, l.TIPO, COUNT(*) AS LANCAMENTOS, SUM(l.VALOR_TOTAL) AS VALOR,
           SUM(p.VALOR_BAIXADO) AS PAGO, SUM(p.SALDO) AS EM_ABERTO,
           SUM(CASE WHEN l.ID_PESSOA IS NULL THEN 1 ELSE 0 END) AS SEM_PESSOA,
           SUM(CASE WHEN l.ID_PLANO_CONTA IS NULL THEN 1 ELSE 0 END) AS SEM_PLANO
    FROM FIN.Lancamento l WITH (NOLOCK)
    INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_LANCAMENTO = l.ID_LANCAMENTO
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
    WHERE l.ORIGEM = 'MIGRACAO'
    GROUP BY e.NOME_FANTASIA, l.TIPO
    ORDER BY e.NOME_FANTASIA, l.TIPO;

    /* 5. Casos */
    SELECT 'CASOS' AS GRADE, c.MOTIVO, COUNT(*) AS DOCUMENTOS, SUM(c.LINHAS) AS LINHAS, SUM(c.VALOR_DEBITO) AS DEBITOS, SUM(c.VALOR_CREDITO) AS CREDITOS,
           MIN(c.DT_DOCUMENTO) AS DE, MAX(c.DT_DOCUMENTO) AS ATE
    FROM MIG.Caso c
    WHERE c.REGRA_ATUAL = 'CASO'
    GROUP BY c.MOTIVO
    ORDER BY COUNT(*) DESC;

    SELECT 'CASOS_SITUACAO' AS GRADE, c.REGRA_ATUAL, COUNT(*) AS DOCUMENTOS, SUM(c.VALOR_DEBITO + c.VALOR_CREDITO) AS VALOR
    FROM MIG.Caso c
    GROUP BY c.REGRA_ATUAL
    ORDER BY c.REGRA_ATUAL;
END;
GO
