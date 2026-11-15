-- Consulta: ~sq_dCReceber Abertas Periodo~sq_dEmpVinculada
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"disponivel programador"));
