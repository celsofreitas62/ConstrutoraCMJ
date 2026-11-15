-- Consulta: ~sq_cVenda Imovel~sq_cImovelVendido
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Imoveis].[CodImovel], [Imoveis].[NomeImovel], [Parceiros].[NomeParceiro]
FROM Parceiros INNER JOIN Imoveis ON [Parceiros].[CodigoParceiro]=[Imoveis].[Proprietario]
WHERE ((([Parceiros].[NomeParceiro])<>"sistema"));
