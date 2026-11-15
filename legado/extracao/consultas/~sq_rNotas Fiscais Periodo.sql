-- Consulta: ~sq_rNotas Fiscais Periodo
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Relacao Notas Ficais]!DTInicial (Texto), Formulários![Relacao Notas Ficais]!DTFinal (Texto), Formulários![Relacao Notas Ficais]!CodigoVinculada (Texto)
-- Descrição: 

SELECT [F Movimento Contas].NumMovimento, [F Movimento Contas].ReferenteNotaFiscal, [F Movimento Contas].DataMovto, [F Movimento Contas].Integracao, [F Movimento Contas].EmpVinculada, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodHistorico, [F Movimento Contas].ValorDebito, [F Movimento Contas].ValorCredito, [F Movimento Contas].Complemento, [F Movimento Contas].ContaFinanceira, [F Movimento Contas].DataPagto, [F Movimento Contas].DataVencto
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].ReferenteNotaFiscal) Is Not Null) And (([F Movimento Contas].DataMovto)>=Formulários![Relacao Notas Ficais]!DTInicial And ([F Movimento Contas].DataMovto)<=Formulários![Relacao Notas Ficais]!DTFinal) And (([F Movimento Contas].Integracao)=True) And (([F Movimento Contas].EmpVinculada)=Formulários![Relacao Notas Ficais]!CodigoVinculada) And (([F Movimento Contas].CodigoParceiro)<>1) And (([F Movimento Contas].ValorDebito)<>0));
