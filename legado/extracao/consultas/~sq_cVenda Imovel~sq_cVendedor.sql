-- Consulta: ~sq_cVenda Imovel~sq_cVendedor
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro]
FROM Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>" sistema"));
