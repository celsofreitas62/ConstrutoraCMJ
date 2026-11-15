-- Consulta: ~sq_rExtrato Contas Parceiro
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Temp Movimento Contas].[CodigoConta], [F Temp Movimento Contas].[MovtoOrigem], [F Temp Movimento Contas].[Efetuado], [F Temp Movimento Contas].[HistoricoExtrato], [F Temp Movimento Contas].[NumDoc], [Historico].[Descricao], [F Contas Financeiras].[Limite Credito], [F Temp Movimento Contas].[EmAberto], [F Temp Movimento Contas].[Confirmado], [F Temp Movimento Contas].[Complemento], [F Temp Movimento Contas].[ValorCredito], [F Temp Movimento Contas].[ValorDebito], [F Temp Movimento Contas].[NumMovimento], [F Temp Movimento Contas].[DataMovto]
FROM Historico RIGHT JOIN ([F Temp Movimento Contas] LEFT JOIN [F Contas Financeiras] ON [F Temp Movimento Contas].[CodigoConta]=[F Contas Financeiras].[CodigoConta]) ON [Historico].[CodHistorico]=[F Temp Movimento Contas].[Historico];
