-- Consulta: ~sq_dPosicaoImoveis~sq_dEmpVinculada
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"sistema"))
ORDER BY [EmpVinculada].[NomeVinculada];
