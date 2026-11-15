-- Consulta: ~sq_cPagto Lote Header~sq_cCodigoParceiro
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro], [Parceiros].[Telefone]
FROM Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>"sistema") And (([Parceiros].[PagtoLote])=True) And (([Parceiros].[Inativo])=False))
ORDER BY [Parceiros].[NomeParceiro];
