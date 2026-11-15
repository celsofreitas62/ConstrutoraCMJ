-- Consulta: ~sq_cVenda Imovel~sq_cCombinação42
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"sistema") And (([EmpVinculada].[ImovelEmVenda])=True));
