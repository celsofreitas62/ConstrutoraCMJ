-- Consulta: ~sq_cConciliacao Financiamento~sq_cConciliacao Finan SubForm
-- Tipo: Seleção (0)
-- Parâmetros: __CodigoConta (Texto), [F Movimento Contas].[DataVinculada] (Texto), [F Movimento Contas].[EmAberto] (Texto)
-- Descrição: 

PARAMETERS __CodigoConta Value;
SELECT DISTINCTROW *
FROM (SELECT [F Contas Financeiras].[Descricao], [F Movimento Contas].[DataVinculada], [F Movimento Contas].[DataMovto], [F Movimento Contas].[ValorDebito], [F Movimento Contas].[ValorCredito], [F Movimento Contas].[EmAberto], [F Movimento Contas].[Complemento], [F Movimento Contas].[Confirmado], [F Contas Financeiras].[Conciliacao], [F Movimento Contas].[ContaFinanceira], [F Contas Financeiras].[Tipo Conta] FROM [F Contas Financeiras] INNER JOIN [F Movimento Contas] ON [F Contas Financeiras].[CodigoConta]=[F Movimento Contas].[ContaFinanceira] WHERE ((([F Movimento Contas].[EmAberto])=True) And (([F Movimento Contas].[Confirmado])=False) And (([F Contas Financeiras].[Tipo Conta])=4)) Or ((([F Movimento Contas].[EmAberto])=True) And (([F Movimento Contas].[Confirmado])=False)) Or ((([F Movimento Contas].[EmAberto])=True) And (([F Movimento Contas].[Confirmado])=False)) ORDER BY [F Contas Financeiras].[Descricao], [F Movimento Contas].[DataVinculada], [F Movimento Contas].[DataMovto]; )  AS [Conciliacao Financiamento]
WHERE ([__CodigoConta] = ContaFinanceira);
