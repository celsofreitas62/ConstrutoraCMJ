-- Consulta: ~sq_dResumo Geral~sq_dExtrato Conta Financeira
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Temp Movimento Contas].[CodigoConta], [F Contas Financeiras].[Limite Credito], [F Temp Movimento Contas].[EmAberto], [F Temp Movimento Contas].[Confirmado], [F Temp Movimento Contas].[Complemento], [F Temp Movimento Contas].[ValorCredito], [F Temp Movimento Contas].[ValorDebito], [F Temp Movimento Contas].[NumMovimento], [F Temp Movimento Contas].[DataMovto], [F Contas Financeiras].[Descricao]
FROM [F Temp Movimento Contas] LEFT JOIN [F Contas Financeiras] ON [F Temp Movimento Contas].[CodigoConta]=[F Contas Financeiras].[CodigoConta];
