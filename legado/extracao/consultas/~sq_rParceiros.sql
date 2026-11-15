-- Consulta: ~sq_rParceiros
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro], [Parceiros].[Cliente], [Parceiros].[Fornecedor], [Parceiros].[Inativo], [Parceiros].[Funcionario], [Parceiros].[Master], [Parceiros].[Telefone]
FROM Parceiros
WHERE ((([Parceiros].[Master])=False));
