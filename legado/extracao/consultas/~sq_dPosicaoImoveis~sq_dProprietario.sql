-- Consulta: ~sq_dPosicaoImoveis~sq_dProprietario
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro]
FROM Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>"sistema"));
