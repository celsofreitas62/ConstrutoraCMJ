/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Pendencia_Bloqueia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - a baixa pode ser feita? Devolve sempre 1 linha:
                BLOQUEIA (1 = há pendência manual aberta de tipo que bloqueia
                a baixa) e MOTIVO (as pendências, separadas por "; ").
                Vale a pendência do lançamento inteiro (ID_PARCELA vazio) ou
                da parcela informada. Com @IdParcela NULL: qualquer pendência
                que bloqueia o lançamento. As automáticas nunca bloqueiam.
                Usada pela baixa (04g) e pela ficha (aviso).

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- SELECT * FROM FIN.fn_FIN_Pendencia_Bloqueia(123, NULL);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Pendencia_Bloqueia] (@IdLancamento BIGINT, @IdParcela BIGINT)
RETURNS TABLE
AS
RETURN
(
    SELECT CASE WHEN COUNT(*) > 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS BLOQUEIA,
           CAST(ISNULL(STRING_AGG(CONVERT(NVARCHAR(MAX), t.DESCRICAO + CASE WHEN lp.OBSERVACAO <> N'' THEN N' (' + LEFT(lp.OBSERVACAO, 100) + N')' ELSE N'' END), N'; '), N'') AS NVARCHAR(1000)) AS MOTIVO
    FROM FIN.Lancamento_Pendencia lp
    INNER JOIN FIN.Pendencia_Tipo t ON t.ID_PENDENCIA_TIPO = lp.ID_PENDENCIA_TIPO AND t.BLOQUEIA_BAIXA = 1
    WHERE lp.ID_LANCAMENTO = @IdLancamento
      AND lp.SITUACAO = 'ABERTA'
      AND lp.ATIVO = 1
      AND (@IdParcela IS NULL OR lp.ID_PARCELA IS NULL OR lp.ID_PARCELA = @IdParcela)
);
GO
