-- Consulta: ~sq_cF Movimento Contas Analise~sq_cContasFinanceiras
-- Tipo: Seleção (0)
-- Parâmetros: [Forms]![F Movimento Contas Analise]![TiposContaFinanceira] (Texto)
-- Descrição: 

SELECT [F Contas Financeiras].[CodigoConta], [F Contas Financeiras].[Descricao], [F Contas Financeiras].[NaoListarResumo]
FROM [F Contas Financeiras]
WHERE ((([F Contas Financeiras].[Tipo Conta])=[Forms]![F Movimento Contas Analise]![TiposContaFinanceira]) And (([F Contas Financeiras].[NaoListarResumo])=False));
