-- Consulta: ~sq_cF Movto Empresa~sq_cEmpVinculada
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"N/A" And ([EmpVinculada].[NomeVinculada])<>"Escolha a Empresa" And ([EmpVinculada].[NomeVinculada])<>"sistema"))
ORDER BY [EmpVinculada].[NomeVinculada];
