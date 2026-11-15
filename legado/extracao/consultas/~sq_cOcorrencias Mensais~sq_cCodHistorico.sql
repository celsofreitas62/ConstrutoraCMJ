-- Consulta: ~sq_cOcorrencias Mensais~sq_cCodHistorico
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Historico].[CodHistorico], [Historico].[Descricao]
FROM Historico
WHERE ((([Historico].[Descricao])<>"sistema"))
ORDER BY [Historico].[Descricao];
