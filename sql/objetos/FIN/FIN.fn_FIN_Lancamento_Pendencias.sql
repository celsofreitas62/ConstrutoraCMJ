/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Lancamento_Pendencias]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - pendências em aberto de um lançamento, uma linha por
                pendência. Fonte única da lista, dos contadores, da ficha e,
                mais adiante, do check-up diário (P25).
                AUTOMATICA: calculada na hora (nada gravado), só para
                  lançamento em aberto (ativo, fora da lixeira, com parcela
                  ABERTA ou PARCIAL) emitido a partir de FIN_PEND_A_PARTIR_DE;
                  some sozinha quando o problema é corrigido. Regras ligadas
                  por parâmetro (nível 1):
                    SEM_CENTRO      FIN_PEND_SEM_CENTRO (S/N)
                    SEM_PLANO       FIN_PEND_SEM_PLANO (S/N)
                    SEM_DOCUMENTO   FIN_PEND_SEM_DOCUMENTO (P, R, A ou N)
                    SEM_ANEXO       FIN_PEND_PAGAR_SEM_ANEXO_VALOR (a pagar
                                    com valor total acima; 0 = desligada)
                    NAO_APTO        FIN_PEND_RECEBER_NAO_APTO (a receber; P10)
                    VENCIDA         FIN_PEND_VENCIDA_DIAS (0 = desligada; uma
                                    linha por lançamento, com a parcela mais
                                    antiga)
                  Automáticas nunca bloqueiam a baixa.
                MANUAL: FIN.Lancamento_Pendencia ABERTA e ativa, de lançamento
                  ativo fora da lixeira (pago ou não). BLOQUEIA_BAIXA vem do
                  tipo; ATRASADA = previsão já passou.
                Função em linha: nas listas entra por CROSS APPLY sem custo
                por linha.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c). Parâmetros lidos direto de
                        SIS.Parametro (sem função escalar por linha).

  Homologação (LOCAL):
    -- SELECT TOP 50 l.ID_LANCAMENTO, f.* FROM FIN.Lancamento l CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) f;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Lancamento_Pendencias] (@IdLancamento BIGINT)
RETURNS TABLE
AS
RETURN
(
    WITH cfg AS (   -- parâmetros lidos direto da tabela (função escalar por linha deixava a lista lenta)
        SELECT MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_CENTRO'       AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS SEM_CENTRO,
               MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_PLANO'        AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS SEM_PLANO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_DOCUMENTO' THEN CONVERT(VARCHAR(1), UPPER(LTRIM(p.VALOR))) END), 'N') AS SEM_DOCUMENTO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR' THEN TRY_CONVERT(DECIMAL(18,2), REPLACE(p.VALOR, N',', N'.')) END), 0) AS ANEXO_VALOR,
               MAX(CASE WHEN p.CHAVE = 'FIN_PEND_RECEBER_NAO_APTO' AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS NAO_APTO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_VENCIDA_DIAS' THEN TRY_CONVERT(INT, p.VALOR) END), 0) AS VENCIDA_DIAS,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_A_PARTIR_DE' THEN TRY_CONVERT(DATE, p.VALOR, 23) END), CAST('19000101' AS DATE)) AS A_PARTIR_DE,
               CAST(SYSDATETIME() AS DATE) AS HOJE
        FROM SIS.Parametro p WITH (NOLOCK)
        WHERE p.CHAVE LIKE 'FIN[_]PEND[_]%'
    ),
    lanc AS (
        SELECT l.ID_LANCAMENTO, l.TIPO, l.ID_PESSOA, l.ID_CENTRO_CUSTO, l.ID_PLANO_CONTA, l.DOCUMENTO, l.VALOR_TOTAL, l.DT_EMISSAO
        FROM FIN.Lancamento l
        WHERE l.ID_LANCAMENTO = @IdLancamento
          AND l.SITUACAO = 'ATIVO'
          AND l.DT_EXCLUSAO IS NULL
    ),
    aberto AS (
        SELECT l.*, c.*
        FROM lanc l
        CROSS JOIN cfg c
        WHERE l.DT_EMISSAO >= c.A_PARTIR_DE
          AND EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO AND p.SITUACAO IN ('ABERTA', 'PARCIAL'))
    )
    SELECT a.ID_LANCAMENTO, CAST(NULL AS BIGINT) AS ID_PARCELA, CAST(NULL AS BIGINT) AS ID_LANCAMENTO_PENDENCIA,
           CAST('AUTOMATICA' AS VARCHAR(10)) AS ORIGEM, CAST('SEM_CENTRO' AS VARCHAR(20)) AS CODIGO,
           CAST(N'Sem centro de custo' AS NVARCHAR(400)) AS DESCRICAO,
           CAST(N'Informe o centro de custo (obra) na ficha do lançamento.' AS NVARCHAR(400)) AS ORIENTACAO,
           CAST(0 AS BIT) AS BLOQUEIA_BAIXA, CAST(0 AS BIT) AS ATRASADA,
           CAST(NULL AS INT) AS ID_PENDENCIA_TIPO, CAST(NULL AS INT) AS ID_USUARIO_RESPONSAVEL, CAST(NULL AS DATE) AS DT_PREVISAO
    FROM aberto a
    WHERE a.SEM_CENTRO = 1 AND a.ID_CENTRO_CUSTO IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_PLANO', N'Sem conta do plano de contas',
           N'Informe a conta do plano de contas na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.SEM_PLANO = 1 AND a.ID_PLANO_CONTA IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_DOCUMENTO', N'Sem número de documento',
           N'Informe o número do documento (nota fiscal, boleto, contrato) na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.DOCUMENTO = N'' AND (a.SEM_DOCUMENTO = 'A' OR a.SEM_DOCUMENTO = a.TIPO)

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_ANEXO',
           N'Sem anexo (valor acima de ' + SIS.fn_SIS_Formatar_Moeda(a.ANEXO_VALOR) + N')',
           N'Anexe a nota fiscal, o boleto ou o contrato na aba Anexos.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.TIPO = 'P' AND a.ANEXO_VALOR > 0 AND a.VALOR_TOTAL > a.ANEXO_VALOR
      AND NOT EXISTS (SELECT 1 FROM SIS.Anexo x
                      WHERE x.TABELA_REFERENCIA = N'FIN.Lancamento' AND x.ID_REFERENCIA = a.ID_LANCAMENTO AND x.SITUACAO = 'ATIVO')

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'NAO_APTO',
           N'Parceiro não apto para cobrança: ' + ISNULL(f.PENDENCIA, N''),
           N'Complete o cadastro do parceiro (Cadastros › Parceiros, filtro "Pendências de cadastro").', 0, 0, NULL, NULL, NULL
    FROM aberto a
    CROSS APPLY (SELECT TOP (1) c.APTO, c.PENDENCIA FROM CAD.fn_CAD_Pessoa_Pendencia_Cobranca(a.ID_PESSOA) c) f   -- TOP: busca só o parceiro do lançamento
    WHERE a.TIPO = 'R' AND a.NAO_APTO = 1 AND f.APTO = 0

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'NAO_APTO', N'Sem parceiro para a cobrança',
           N'Informe o parceiro (cliente) na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.TIPO = 'R' AND a.NAO_APTO = 1 AND a.ID_PESSOA IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, v.ID_PARCELA, NULL, 'AUTOMATICA', 'VENCIDA',
           CASE WHEN v.QTD = 1 THEN N'Parcela vencida há mais de ' ELSE CONVERT(NVARCHAR(10), v.QTD) + N' parcelas vencidas há mais de ' END
             + CONVERT(NVARCHAR(10), a.VENCIDA_DIAS) + N' dias (desde ' + CONVERT(NVARCHAR(10), v.DT_VENCIMENTO, 103) + N')',
           CASE a.TIPO WHEN 'P' THEN N'Pague, renegocie ou corrija o vencimento.' ELSE N'Cobre o cliente, renegocie ou corrija o vencimento.' END,
           0, 0, NULL, NULL, NULL
    FROM aberto a
    CROSS APPLY (SELECT TOP (1) p.ID_PARCELA, p.DT_VENCIMENTO, COUNT(*) OVER () AS QTD
                 FROM FIN.Parcela p
                 WHERE p.ID_LANCAMENTO = a.ID_LANCAMENTO AND p.SITUACAO IN ('ABERTA', 'PARCIAL')
                   AND p.DT_VENCIMENTO < DATEADD(DAY, -a.VENCIDA_DIAS, a.HOJE)
                 ORDER BY p.DT_VENCIMENTO, p.NUMERO) v
    WHERE a.VENCIDA_DIAS > 0

    UNION ALL
    SELECT lp.ID_LANCAMENTO, lp.ID_PARCELA, lp.ID_LANCAMENTO_PENDENCIA, 'MANUAL', t.CODIGO,
           t.DESCRICAO + CASE WHEN lp.OBSERVACAO <> N'' THEN N': ' + LEFT(lp.OBSERVACAO, 300) ELSE N'' END,
           t.ORIENTACAO, t.BLOQUEIA_BAIXA,
           CASE WHEN lp.DT_PREVISAO < c.HOJE THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
           lp.ID_PENDENCIA_TIPO, lp.ID_USUARIO_RESPONSAVEL, lp.DT_PREVISAO
    FROM lanc l
    CROSS JOIN cfg c
    INNER JOIN FIN.Lancamento_Pendencia lp ON lp.ID_LANCAMENTO = l.ID_LANCAMENTO AND lp.SITUACAO = 'ABERTA' AND lp.ATIVO = 1
    INNER JOIN FIN.Pendencia_Tipo t ON t.ID_PENDENCIA_TIPO = lp.ID_PENDENCIA_TIPO
);
GO
