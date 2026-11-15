-- Consulta: ~sq_dF Movto Parceiro PagoPagar~sq_dCodigoParceiro
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro], [Parceiros].[Cliente], [Parceiros].[Fornecedor], [Parceiros].[Funcionario]
FROM Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>"sistema"));
