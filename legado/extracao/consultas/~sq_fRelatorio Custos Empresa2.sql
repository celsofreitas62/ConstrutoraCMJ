-- Consulta: ~sq_fRelatorio Custos Empresa2
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[Custos], [EmpVinculada].[CodigoVinculada], [EmpVinculada].[NomeVinculada], [EmpVinculada].[FinanceiraPadrao], [F Contas Financeiras].[Descricao], [EmpVinculada].[DataInicialCustos]
FROM [F Contas Financeiras] INNER JOIN EmpVinculada ON [F Contas Financeiras].[CodigoConta]=[EmpVinculada].[FinanceiraPadrao]
WHERE ((([EmpVinculada].[Custos])=True) And (([EmpVinculada].[NomeVinculada])<>"N/A") And (([EmpVinculada].[Master])=False))
ORDER BY [EmpVinculada].[NomeVinculada];
