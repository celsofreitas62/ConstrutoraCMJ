-- Consulta: ~sq_cReajusteImoveis~sq_cEmpresaSelecionada
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada], [EmpVinculada].[ImovelEmVenda]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"N/A" And ([EmpVinculada].[NomeVinculada])<>"sistema") And (([EmpVinculada].[ImovelEmVenda])=True));
