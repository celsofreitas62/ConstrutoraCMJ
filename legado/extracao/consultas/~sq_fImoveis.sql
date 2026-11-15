-- Consulta: ~sq_fImoveis
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada], [EmpVinculada].[ImovelEmVenda]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"sistema") And (([EmpVinculada].[ImovelEmVenda])=True));
