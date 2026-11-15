-- Consulta: ~sq_cF Conciliacao~sq_cF Conciliacao SubForm
-- Tipo: Seleção (0)
-- Parâmetros: __CodigoConta (Texto), [F Movimento Contas].[DataVinculada] (Texto), [F Movimento Contas].[EmAberto] (Texto)
-- Descrição: 

PARAMETERS __CodigoConta Value;
SELECT DISTINCTROW *
FROM (SELECT [F Contas Financeiras].[Descricao], [F Movimento Contas].[DataVinculada], [F Movimento Contas].[DataMovto], [F Movimento Contas].[ValorDebito], [F Movimento Contas].[ValorCredito], [F Movimento Contas].[EmAberto], [F Movimento Contas].[Complemento], [F Movimento Contas].[Confirmado], [F Contas Financeiras].[Conciliacao], [F Movimento Contas].[ContaFinanceira], [F Contas Financeiras].[Tipo Conta] FROM [F Contas Financeiras] INNER JOIN [F Movimento Contas] ON [F Contas Financeiras].[CodigoConta]=[F Movimento Contas].[ContaFinanceira] WHERE ((([F Movimento Contas].[Confirmado])=False) And (([F Contas Financeiras].[Conciliacao])=True)) Or ((([F Contas Financeiras].[Tipo Conta])=4)) ORDER BY [F Contas Financeiras].[Descricao], [F Movimento Contas].[DataVinculada], [F Movimento Contas].[DataMovto]; )  AS [F Conciliacao]
WHERE ([__CodigoConta] = ContaFinanceira);
