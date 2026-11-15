-- Consulta: ~sq_fRelatorioContabil
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"N/A") And (([EmpVinculada].[Master])=False))
ORDER BY [EmpVinculada].[NomeVinculada];
