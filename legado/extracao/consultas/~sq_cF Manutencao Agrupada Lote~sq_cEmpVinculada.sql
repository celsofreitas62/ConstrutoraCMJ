-- Consulta: ~sq_cF Manutencao Agrupada Lote~sq_cEmpVinculada
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"sistema"));
