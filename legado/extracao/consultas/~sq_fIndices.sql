-- Consulta: ~sq_fIndices
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Indices].[CodIndice], [Indices].[NomeIndice], [Indices].[Periodicidade], [Indices].[CotaIndice], [Indices].[Fator]
FROM Indices
WHERE ((([Indices].[NomeIndice])<>"N/A"));
