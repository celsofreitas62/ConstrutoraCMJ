-- Consulta: ~sq_rRelatorioContabil
-- Tipo: Seleção (0)
-- Parâmetros: Formulários!RelatorioContabil!DTInicial (Texto), Formulários!RelatorioContabil!DTFinal (Texto), Formulários!RelatorioContabil!CodigoVinculada (Texto)
-- Descrição: 

SELECT [F Movimento Contas].NumMovimento, [F Movimento Contas].ReferenteNotaFiscal, [F Movimento Contas].DataPagto, [F Movimento Contas].DataMovto, [F Movimento Contas].Integracao, [F Movimento Contas].EmpVinculada, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodHistorico, [F Movimento Contas].ValorDebito, [F Movimento Contas].ValorCredito, [F Movimento Contas].Complemento, [F Movimento Contas].ContaFinanceira, [F Movimento Contas].DataVencto
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].DataPagto)>=Formulários!RelatorioContabil!DTInicial And ([F Movimento Contas].DataPagto)<=Formulários!RelatorioContabil!DTFinal) And (([F Movimento Contas].Integracao)=True) And (([F Movimento Contas].EmpVinculada)=Formulários!RelatorioContabil!CodigoVinculada) And (([F Movimento Contas].CodigoParceiro)<>1) And (([F Movimento Contas].ValorDebito)<>0));
