-- Consulta: ~sq_cOcorrencias Mensais~sq_cContaFinanceira
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Contas Financeiras].[CodigoConta], [F Contas Financeiras].[Descricao], [F Tipos Conta Financeira].[Descricao]
FROM [F Tipos Conta Financeira] INNER JOIN [F Contas Financeiras] ON [F Tipos Conta Financeira].[CodTipoConta]=[F Contas Financeiras].[Tipo Conta]
WHERE ((([F Contas Financeiras].[Descricao])<>"sistema"))
ORDER BY [F Contas Financeiras].[Descricao];
