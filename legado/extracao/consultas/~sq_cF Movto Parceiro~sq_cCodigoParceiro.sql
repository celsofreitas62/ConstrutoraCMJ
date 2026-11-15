-- Consulta: ~sq_cF Movto Parceiro~sq_cCodigoParceiro
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro]
FROM Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>"sistema"))
ORDER BY [Parceiros].[NomeParceiro];
