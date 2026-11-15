-- Consulta: ~sq_cF Movimento Contas xxx~sq_cEmpVinculada
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"disponivel programador"))
ORDER BY [EmpVinculada].[NomeVinculada];
