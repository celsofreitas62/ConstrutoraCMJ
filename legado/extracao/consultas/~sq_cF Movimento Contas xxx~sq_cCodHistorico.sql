-- Consulta: ~sq_cF Movimento Contas xxx~sq_cCodHistorico
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Historico].[CodHistorico], [Historico].[Descricao]
FROM Historico
WHERE ((([Historico].[Descricao])<>"disp program"))
ORDER BY [Historico].[Descricao];
