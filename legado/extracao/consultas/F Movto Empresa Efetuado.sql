-- Consulta: F Movto Empresa Efetuado
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![F Movto Empresa]!EmpVinculada (Texto), Formulários![F Movto Empresa]!DataIni (Texto), Formulários![F Movto Empresa]!DataFim (Texto)
-- Descrição: 

SELECT [F Movimento Contas].[EmpVinculada], [F Movimento Contas].[CodigoParceiro], [F Movimento Contas].[SomenteIntegracao], [F Movimento Contas].[Efetuado], [F Movimento Contas].[DataVencto], [F Movimento Contas].[DataPagto], [F Movimento Contas].[DataMovto], [F Movimento Contas].[AgrupadorVenda], [F Movimento Contas].[Confirmado], [F Movimento Contas].[PagamentoLote], [F Movimento Contas].[SelPagtoLote], [F Movimento Contas].[ContaFinanceira], [F Movimento Contas].[ReferenteNotaFiscal], [F Movimento Contas].[Integracao], [F Movimento Contas].[NumDoc], [F Movimento Contas].[NumMovimento], [EmpVinculada].[FinanceiraPadrao], [Parceiros].[NomeParceiro], [F Movimento Contas].[MovPagtoLote], [F Movimento Contas].[CodHistorico], [F Movimento Contas].[Complemento], [F Movimento Contas].[ValorDebito], [F Movimento Contas].[ValorCredito]
FROM Parceiros INNER JOIN (EmpVinculada INNER JOIN [F Movimento Contas] ON [EmpVinculada].[CodigoVinculada]=[F Movimento Contas].[EmpVinculada]) ON [Parceiros].[CodigoParceiro]=[F Movimento Contas].[CodigoParceiro]
WHERE ((([F Movimento Contas].[EmpVinculada])=Formulários![F Movto Empresa]!EmpVinculada) And (([F Movimento Contas].[SomenteIntegracao])=False) And (([F Movimento Contas].[Efetuado])=True) And (([F Movimento Contas].[DataPagto])>=Formulários![F Movto Empresa]!DataIni And ([F Movimento Contas].[DataPagto])<=Formulários![F Movto Empresa]!DataFim))
ORDER BY [F Movimento Contas].[DataVencto], [F Movimento Contas].[DataPagto], [F Movimento Contas].[ValorCredito];
