-- Consulta: ~sq_fExtrato Movimento Contabil
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada], [EmpVinculada].[Contabil]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"N/A") And (([EmpVinculada].[Master])=False) And (([EmpVinculada].[Contabil])=True))
ORDER BY [EmpVinculada].[NomeVinculada];
