/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Parcela_Baixa_Viva]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Baixas vivas da parcela: as que não são estorno e não foram
                estornadas. Fonte única da regra "a parcela tem pagamento ou
                recebimento" para alterar e cancelar o lançamento (decisão do
                Celso, 04g4: baixa estornada não trava; excluir continua
                proibido com qualquer baixa, para guardar o histórico).
                Em linha (inline): uso com EXISTS por parcela.

  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g4).

  Homologação (LOCAL):
    -- SELECT * FROM FIN.fn_FIN_Parcela_Baixa_Viva(123);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Parcela_Baixa_Viva] (@IdParcela BIGINT)
RETURNS TABLE
AS
RETURN
(
    SELECT b.ID_BAIXA
    FROM FIN.Baixa b
    WHERE b.ID_PARCELA = @IdParcela
      AND b.ID_BAIXA_ESTORNADA IS NULL
      AND NOT EXISTS (SELECT 1 FROM FIN.Baixa x WHERE x.ID_BAIXA_ESTORNADA = b.ID_BAIXA)
);
GO
