-- Consulta: CondPagtoConsulta
-- Tipo: Seleção (0)
-- Parâmetros: Formulários!VendaImovelVendido!CodImovel (Texto)
-- Descrição: 

SELECT [CondPagtoImovel].[CodImovel], [CondPagtoImovel].[CodPagtoImovel], [CondPagtoImovel].[NomePagto], [CondPagtoImovel].[QtdParcelas], [CondPagtoImovel].[DiasCalculo], [CondPagtoImovel].[Vencimento], [CondPagtoImovel].[ValorInicial]
FROM CondPagtoImovel
WHERE ((([CondPagtoImovel].[CodImovel])=Formulários!VendaImovelVendido!CodImovel));
