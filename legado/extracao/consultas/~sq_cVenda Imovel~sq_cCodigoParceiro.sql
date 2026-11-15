-- Consulta: ~sq_cVenda Imovel~sq_cCodigoParceiro
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro], [Parceiros].[Cliente], [Parceiros].[Fornecedor], [Parceiros].[Funcionario]
FROM Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>"sistema"));
