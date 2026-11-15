-- Consulta: TotalImovel
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [CondPagtoImovel].[CodImovel], Sum([QtdParcelas]*[ValorInicial]) AS TImovel
FROM CondPagtoImovel
GROUP BY [CondPagtoImovel].[CodImovel];
