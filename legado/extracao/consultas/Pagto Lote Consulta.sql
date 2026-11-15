-- Consulta: Pagto Lote Consulta
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Pagto Lote Header]!CodigoParceiro (Texto)
-- Descrição: 

SELECT [F Movimento Contas].CodigoParceiro, [F Movimento Contas].PagamentoLote, [F Movimento Contas].DataPagto, [F Movimento Contas].Confirmado, [F Movimento Contas].SelPagtoLote, [F Movimento Contas].SomenteIntegracao, [F Movimento Contas].Efetuado, [F Movimento Contas].ContaFinanceira, [F Movimento Contas].ReferenteNotaFiscal, [F Movimento Contas].Integracao, [F Movimento Contas].NumDoc, [F Movimento Contas].NumMovimento, EmpVinculada.FinanceiraPadrao, Parceiros.NomeParceiro, [F Movimento Contas].DataVencto, [F Movimento Contas].EmpVinculada, [F Movimento Contas].MovPagtoLote, [F Movimento Contas].CodHistorico, [F Movimento Contas].Complemento, [F Movimento Contas].ValorDebito, [F Movimento Contas].DataMovto
FROM Parceiros INNER JOIN (EmpVinculada INNER JOIN [F Movimento Contas] ON EmpVinculada.CodigoVinculada=[F Movimento Contas].EmpVinculada) ON Parceiros.CodigoParceiro=[F Movimento Contas].CodigoParceiro
WHERE ((([F Movimento Contas].CodigoParceiro)=Formulários![Pagto Lote Header]!CodigoParceiro) And (([F Movimento Contas].PagamentoLote)=True) And (([F Movimento Contas].DataPagto) Is Null) And (([F Movimento Contas].Confirmado)=False) And (([F Movimento Contas].SelPagtoLote)=False) And (([F Movimento Contas].SomenteIntegracao)=False))
ORDER BY [F Movimento Contas].DataVencto, [F Movimento Contas].EmpVinculada, [F Movimento Contas].DataMovto;
