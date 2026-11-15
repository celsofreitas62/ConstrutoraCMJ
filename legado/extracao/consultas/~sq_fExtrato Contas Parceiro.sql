-- Consulta: ~sq_fExtrato Contas Parceiro
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro], [Parceiros].[Master]
FROM Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>"N/A") And (([Parceiros].[Master])=False))
ORDER BY [Parceiros].[NomeParceiro];
