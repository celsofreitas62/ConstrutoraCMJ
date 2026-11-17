/*******************************************************************************
  Objeto      : [FIN].[tg_FIN_Baixa_Saldo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Mantém FIN.Parcela.VALOR_BAIXADO e a SITUACAO (ABERTA, PARCIAL,
                PAGA) a cada inclusão/alteração/exclusão de baixa, por delta
                (regra 9: UNION ALL de inserted positivo e deleted negativo).
                Parcela CANCELADA não muda de situação. Sem recursão: só atualiza
                o que muda (regra 20).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER TRIGGER [FIN].[tg_FIN_Baixa_Saldo]
ON [FIN].[Baixa]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    ;WITH Delta AS
    (
        SELECT d.ID_PARCELA, SUM(d.VALOR) AS VALOR
        FROM (
                SELECT i.ID_PARCELA, i.VALOR_PRINCIPAL AS VALOR FROM inserted i
                UNION ALL
                SELECT x.ID_PARCELA, -x.VALOR_PRINCIPAL FROM deleted x
             ) d
        GROUP BY d.ID_PARCELA
    )
    UPDATE p
       SET p.VALOR_BAIXADO = p.VALOR_BAIXADO + dl.VALOR
    FROM FIN.Parcela p
    INNER JOIN Delta dl ON dl.ID_PARCELA = p.ID_PARCELA
    WHERE dl.VALOR <> 0;

    UPDATE p
       SET p.SITUACAO = CASE WHEN p.VALOR_BAIXADO <= 0 THEN 'ABERTA'
                             WHEN p.VALOR_BAIXADO >= p.VALOR THEN 'PAGA'
                             ELSE 'PARCIAL' END
    FROM FIN.Parcela p
    WHERE p.ID_PARCELA IN (SELECT i.ID_PARCELA FROM inserted i UNION SELECT x.ID_PARCELA FROM deleted x)
      AND p.SITUACAO <> 'CANCELADA'
      AND p.SITUACAO <> CASE WHEN p.VALOR_BAIXADO <= 0 THEN 'ABERTA'
                             WHEN p.VALOR_BAIXADO >= p.VALOR THEN 'PAGA'
                             ELSE 'PARCIAL' END;
END;
GO
