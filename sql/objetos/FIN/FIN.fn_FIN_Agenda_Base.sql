/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Agenda_Base]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Fonte única do que entra na agenda da tela inicial (P03,
                etapa 04h1): as parcelas de contas a pagar (D) e a receber (C)
                com vencimento entre @De e @Ate, de lançamentos ativos e fora
                da lixeira, só dos tipos que o usuário vê (@VerPagar /
                @VerReceber, conferidos por quem chama).
                  - em aberto (ABERTA/PARCIAL): entra o saldo da parcela;
                  - @Realizado = 1: entra também o já pago/recebido
                    (VALOR_BAIXADO, inclusive das parcelas PAGA).
                Lançamento de previsão entra e vem marcado (PREVISAO).
                Parcela cancelada nunca entra. Em linha (inline), para entrar
                no plano de quem chama (lição da 04f2c).
                VALOR_D / VALOR_C: o valor da agenda no lado certo (o outro
                fica 0). ABERTO_D / ABERTO_C: só o que está em aberto (base do
                saldo previsto acumulado).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Agenda_Base]
(
    @De         DATE,
    @Ate        DATE,
    @VerPagar   BIT,
    @VerReceber BIT,
    @Realizado  BIT,
    @IdEmpresa  INT
)
RETURNS TABLE
AS
RETURN
    SELECT x.ID_PARCELA, x.ID_LANCAMENTO, x.TIPO, x.DT_VENCIMENTO, x.SITUACAO, x.PREVISAO, x.ID_EMPRESA,
           x.VALOR, x.ABERTO, x.REALIZADO,
           CAST(x.ABERTO + x.REALIZADO AS DECIMAL(18,2))                                     AS VALOR_AGENDA,
           CAST(CASE WHEN x.TIPO = 'P' THEN x.ABERTO + x.REALIZADO ELSE 0 END AS DECIMAL(18,2)) AS VALOR_D,
           CAST(CASE WHEN x.TIPO = 'R' THEN x.ABERTO + x.REALIZADO ELSE 0 END AS DECIMAL(18,2)) AS VALOR_C,
           CAST(CASE WHEN x.TIPO = 'P' THEN x.ABERTO ELSE 0 END AS DECIMAL(18,2))            AS ABERTO_D,
           CAST(CASE WHEN x.TIPO = 'R' THEN x.ABERTO ELSE 0 END AS DECIMAL(18,2))            AS ABERTO_C
    FROM (SELECT p.ID_PARCELA, p.ID_LANCAMENTO, l.TIPO, p.DT_VENCIMENTO, p.SITUACAO, l.PREVISAO, l.ID_EMPRESA, p.VALOR,
                 CAST(CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') THEN ISNULL(p.SALDO, 0) ELSE 0 END AS DECIMAL(18,2)) AS ABERTO,
                 CAST(CASE WHEN ISNULL(@Realizado, 0) = 1 THEN ISNULL(p.VALOR_BAIXADO, 0) ELSE 0 END AS DECIMAL(18,2)) AS REALIZADO
          FROM FIN.Parcela p WITH (NOLOCK)
          INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
          WHERE p.DT_VENCIMENTO >= @De
            AND p.DT_VENCIMENTO <= @Ate
            AND (p.SITUACAO IN ('ABERTA', 'PARCIAL') OR (ISNULL(@Realizado, 0) = 1 AND p.SITUACAO = 'PAGA'))
            AND l.DT_EXCLUSAO IS NULL
            AND l.SITUACAO = 'ATIVO'
            AND ((l.TIPO = 'P' AND ISNULL(@VerPagar, 0) = 1) OR (l.TIPO = 'R' AND ISNULL(@VerReceber, 0) = 1))
            AND (@IdEmpresa IS NULL OR l.ID_EMPRESA = @IdEmpresa)) x
    WHERE x.ABERTO + x.REALIZADO <> 0;
GO
