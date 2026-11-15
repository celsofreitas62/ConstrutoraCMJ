-- Consulta: ~sq_cF Movto Empresa APagar~sq_cCodigoParceiro
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[CodigoParceiro], [Parceiros].[NomeParceiro]
FROM EmpVinculada, Parceiros
WHERE ((([Parceiros].[NomeParceiro])<>"sistema"));
