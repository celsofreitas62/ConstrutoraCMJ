/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Baixa_Sugerir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Baixa (04g): sugestão de juros, multa e limite de desconto de
                uma parcela numa data de pagamento. Fonte única do cálculo
                (tela e FIN_Baixa_Gravar). Função em linha (parâmetros lidos
                direto de SIS.Parametro, lição de desempenho da 04f2c).
                  - calcula só a receber, ou também a pagar quando
                    FIN_BAIXA_CALCULA_PAGAR = S;
                  - atraso = dias entre o vencimento e o pagamento; dentro da
                    carência (FIN_BAIXA_CARENCIA_DIAS) não há encargo; passou,
                    conta desde o vencimento;
                  - multa (FIN_BAIXA_MULTA_PERC) sobre o principal pago, uma
                    vez só: se a parcela já pagou multa numa baixa parcial,
                    não sugere de novo;
                  - juros (FIN_BAIXA_JUROS_MES_PERC) ao mês, pro rata dia
                    (mês de 30 dias), sobre o principal pago;
                  - DESCONTO_LIMITE: só a receber; % do saldo
                    (FIN_BAIXA_DESCONTO_LIMITE_PERC); NULL = sem limite.
                @Principal NULL = o saldo da parcela.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).
  Homologação (LOCAL):
    -- SELECT * FROM FIN.fn_FIN_Baixa_Sugerir(1, '2026-11-26', NULL);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Baixa_Sugerir] (@IdParcela BIGINT, @DtPagamento DATE, @Principal DECIMAL(18,2))
RETURNS TABLE
AS
RETURN
    WITH Par AS
    (
        SELECT ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_MULTA_PERC'           THEN TRY_CONVERT(DECIMAL(9,4), REPLACE(p.VALOR, N',', N'.')) END), 0) AS MULTA_PERC,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_JUROS_MES_PERC'       THEN TRY_CONVERT(DECIMAL(9,4), REPLACE(p.VALOR, N',', N'.')) END), 0) AS JUROS_PERC,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_CARENCIA_DIAS'        THEN TRY_CONVERT(INT, p.VALOR) END), 0)                                  AS CARENCIA,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_CALCULA_PAGAR'        THEN UPPER(LEFT(p.VALOR, 1)) END), N'N')                                 AS CALCULA_PAGAR,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_BAIXA_DESCONTO_LIMITE_PERC' THEN TRY_CONVERT(DECIMAL(9,4), REPLACE(p.VALOR, N',', N'.')) END), 0) AS DESC_PERC
        FROM SIS.Parametro p
        WHERE p.CHAVE IN ('FIN_BAIXA_MULTA_PERC', 'FIN_BAIXA_JUROS_MES_PERC', 'FIN_BAIXA_CARENCIA_DIAS', 'FIN_BAIXA_CALCULA_PAGAR', 'FIN_BAIXA_DESCONTO_LIMITE_PERC')
    ),
    Base AS
    (
        SELECT p.ID_PARCELA, l.TIPO, p.DT_VENCIMENTO, p.SALDO,
               CAST(ISNULL(@Principal, p.SALDO) AS DECIMAL(18,2)) AS PRINCIPAL,
               CASE WHEN @DtPagamento > p.DT_VENCIMENTO THEN DATEDIFF(DAY, p.DT_VENCIMENTO, @DtPagamento) ELSE 0 END AS DIAS_ATRASO,
               CASE WHEN EXISTS (SELECT 1 FROM FIN.Baixa b WHERE b.ID_PARCELA = p.ID_PARCELA GROUP BY b.ID_PARCELA HAVING SUM(b.MULTA) > 0)
                    THEN 1 ELSE 0 END AS JA_PAGOU_MULTA,
               x.MULTA_PERC, x.JUROS_PERC, x.CARENCIA, x.DESC_PERC,
               CASE WHEN l.TIPO = 'R' OR x.CALCULA_PAGAR = N'S' THEN 1 ELSE 0 END AS CALCULA_TIPO
        FROM FIN.Parcela p
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        CROSS JOIN Par x
        WHERE p.ID_PARCELA = @IdParcela
    )
    SELECT b.ID_PARCELA, b.TIPO, b.DT_VENCIMENTO, b.SALDO, b.PRINCIPAL, b.DIAS_ATRASO,
           CAST(CASE WHEN b.CALCULA_TIPO = 1 AND b.DIAS_ATRASO > b.CARENCIA THEN 1 ELSE 0 END AS BIT) AS CALCULA,
           CAST(CASE WHEN b.CALCULA_TIPO = 1 AND b.DIAS_ATRASO > b.CARENCIA AND b.JA_PAGOU_MULTA = 0
                     THEN ROUND(b.PRINCIPAL * b.MULTA_PERC / 100.0, 2) ELSE 0 END AS DECIMAL(18,2)) AS MULTA,
           CAST(CASE WHEN b.CALCULA_TIPO = 1 AND b.DIAS_ATRASO > b.CARENCIA
                     THEN ROUND(b.PRINCIPAL * b.JUROS_PERC / 100.0 / 30.0 * b.DIAS_ATRASO, 2) ELSE 0 END AS DECIMAL(18,2)) AS JUROS,
           CAST(CASE WHEN b.TIPO = 'R' AND b.DESC_PERC > 0 THEN ROUND(b.SALDO * b.DESC_PERC / 100.0, 2) END AS DECIMAL(18,2)) AS DESCONTO_LIMITE,
           b.MULTA_PERC, b.JUROS_PERC, b.CARENCIA
    FROM Base b;
GO
