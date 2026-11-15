-- Consulta: ~sq_cF Manutencao Agrupada Vendas~sq_cCodHistorico
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Historico].[CodHistorico], [Historico].[Descricao]
FROM Historico
WHERE ((([Historico].[Descricao])<>"sistema"));
