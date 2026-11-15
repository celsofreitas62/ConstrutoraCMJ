-- Consulta: ~sq_fSelecionaEmpresaPosicaoCompradores2
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada], [EmpVinculada].[ImovelEmVenda]
FROM EmpVinculada
WHERE ((([EmpVinculada].[NomeVinculada])<>"N/A") And (([EmpVinculada].[ImovelEmVenda])=True) And (([EmpVinculada].[Master])=False))
ORDER BY [EmpVinculada].[NomeVinculada];
