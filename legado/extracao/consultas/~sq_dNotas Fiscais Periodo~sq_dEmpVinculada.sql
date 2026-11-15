-- Consulta: ~sq_dNotas Fiscais Periodo~sq_dEmpVinculada
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"sistema"));
