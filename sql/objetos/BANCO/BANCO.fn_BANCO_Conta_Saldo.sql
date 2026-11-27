/*******************************************************************************
  Objeto      : [BANCO].[fn_BANCO_Conta_Saldo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Saldo de cada conta no fim do dia @Data (etapa 04g2). Fonte
                única do saldo: transferência (aviso de saldo), extrato,
                saldos por conta e fechamento de caixa chamam esta função.
                Regra (aprovada em 19/11/2026): SALDO_INICIAL é o saldo de
                abertura do dia DT_SALDO_INICIAL; movimento com data anterior
                nunca altera o saldo (é histórico). Movimentos estornados
                entram (o par original + inverso zera).
                @IdConta NULL = todas as contas.
                TEM_SALDO = 0 quando @Data é anterior ao saldo inicial (a
                conta ainda não tinha saldo oficial nessa data).
                Function em linha (entra no plano de quem chama).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).
  Homologação (LOCAL):
    -- SELECT * FROM BANCO.fn_BANCO_Conta_Saldo(NULL, '2026-11-27');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [BANCO].[fn_BANCO_Conta_Saldo] (@IdConta INT, @Data DATE)
RETURNS TABLE
AS
RETURN
    SELECT c.ID_CONTA,
           CAST(CASE WHEN c.DT_SALDO_INICIAL IS NULL OR @Data >= c.DT_SALDO_INICIAL THEN c.SALDO_INICIAL + ISNULL(m.TOTAL, 0) ELSE 0 END AS DECIMAL(18,2)) AS SALDO,
           CAST(ISNULL(m.TOTAL, 0) AS DECIMAL(18,2)) AS TOTAL_MOVIMENTOS,
           c.SALDO_INICIAL,
           c.DT_SALDO_INICIAL,
           c.LIMITE_CREDITO,
           CAST(CASE WHEN c.DT_SALDO_INICIAL IS NULL OR @Data >= c.DT_SALDO_INICIAL THEN 1 ELSE 0 END AS BIT) AS TEM_SALDO
    FROM BANCO.Conta c WITH (NOLOCK)
    OUTER APPLY (SELECT SUM(x.VALOR) AS TOTAL
                 FROM BANCO.Movimento x WITH (NOLOCK)
                 WHERE x.ID_CONTA = c.ID_CONTA
                   AND x.DT_MOVIMENTO <= @Data
                   AND (c.DT_SALDO_INICIAL IS NULL OR x.DT_MOVIMENTO >= c.DT_SALDO_INICIAL)) m
    WHERE (@IdConta IS NULL OR c.ID_CONTA = @IdConta);
GO
