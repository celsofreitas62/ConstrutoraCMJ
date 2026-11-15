-- Consulta: ~sq_cF Movimento Contas xxx~sq_cCodigoParceiro
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro], [Parceiros].[Cliente], [Parceiros].[Fornecedor], [Parceiros].[Funcionario]
FROM Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>"disponivel programador") And (([Parceiros].[Inativo])=False))
ORDER BY [Parceiros].[NomeParceiro];
