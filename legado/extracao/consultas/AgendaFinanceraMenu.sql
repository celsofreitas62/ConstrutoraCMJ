-- Consulta: AgendaFinanceraMenu
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Movimento Contas].[DataVencto], [F Movimento Contas].[Confirmado], [F Movimento Contas].[ContaFinanceira], [F Movimento Contas].[Plano3], [F Movimento Contas].[LinkVenda], [F Movimento Contas].[DataPagto], [F Movimento Contas].[MovPagtoLote], [F Movimento Contas].[AgrupadorVenda], [F Movimento Contas].[CodAtribuiParceiro], [F Movimento Contas].[CodAtribuiEmpresa], [F Movimento Contas].[CodAnteriorParceiro], [F Movimento Contas].[CodAnteriorEmpresa], [F Movimento Contas].[NumMovimento], [F Movimento Contas].[EmpVinculada], [F Movimento Contas].[CodigoParceiro], [F Movimento Contas].[CodHistorico], [F Movimento Contas].[NumDoc], [F Movimento Contas].[Complemento], [F Movimento Contas].[Efetuado], [F Movimento Contas].[ValorDebito], [F Movimento Contas].[ValorCredito]
FROM Parceiros INNER JOIN (EmpVinculada INNER JOIN ([F Contas Financeiras] INNER JOIN [F Movimento Contas] ON [F Contas Financeiras].[CodigoConta]=[F Movimento Contas].[ContaFinanceira]) ON [EmpVinculada].[CodigoVinculada]=[F Movimento Contas].[EmpVinculada]) ON [Parceiros].[CodigoParceiro]=[F Movimento Contas].[CodigoParceiro]
WHERE ((([F Movimento Contas].[Confirmado])=False) And (([F Movimento Contas].[ContaFinanceira])<>1 And ([F Movimento Contas].[ContaFinanceira])<>2))
ORDER BY [F Movimento Contas].[DataVencto];
