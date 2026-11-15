-- Consulta: ~sq_cImoveisVinculada~sq_cImoveisParceiro
-- Tipo: Seleção (0)
-- Parâmetros: (não foi possível ler: consulta depende de tabela vinculada ou de outra consulta)
-- Descrição: 

PARAMETERS __CodigoVinculada Value;
SELECT DISTINCTROW *
FROM (SELECT [Parceiros].[NomeParceiro], [ImoveisParceiro Consulta].[NomeImovel], [ImoveisParceiro Consulta].[ValorMercado], [ImoveisParceiro Consulta].[ValorVendido], [ImoveisParceiro Consulta].[Obervacao], [ImoveisParceiro Consulta].[EmpVinculada] FROM Parceiros INNER JOIN [ImoveisParceiro Consulta] ON [Parceiros].[CodigoParceiro]=[ImoveisParceiro Consulta].[CodParceiro] ORDER BY [ImoveisParceiro Consulta].[NomeImovel]; )  AS ImoveisVinculada
WHERE ([__CodigoVinculada] = EmpVinculada);
