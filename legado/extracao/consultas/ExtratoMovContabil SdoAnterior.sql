-- Consulta: ExtratoMovContabil SdoAnterior
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Extrato Movimento Contabil]!CodigoVinculada (Texto), Formulários![Extrato Movimento Contabil]!DTInicial (Texto)
-- Descrição: 

SELECT [F Movimento Contas].EmpVinculada, [F Movimento Contas].Integracao, [F Movimento Contas].Efetuado, [F Movimento Contas].DataPagto, EmpVinculada.NomeVinculada, [F Movimento Contas].Confirmado, [F Movimento Contas].NumMovimento, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodHistorico, [F Movimento Contas].ValorDebito, [F Movimento Contas].ValorCredito, [F Movimento Contas].Complemento, [F Movimento Contas].Plano3, [F Movimento Contas].ContaFinanceira, [F Movimento Contas].DataMovto, [F Movimento Contas].NumDoc, [F Movimento Contas].ReferenteNotaFiscal
FROM EmpVinculada INNER JOIN [F Movimento Contas] ON EmpVinculada.CodigoVinculada=[F Movimento Contas].EmpVinculada
WHERE ((([F Movimento Contas].EmpVinculada)=Formulários![Extrato Movimento Contabil]!CodigoVinculada) And (([F Movimento Contas].Integracao)=True) And (([F Movimento Contas].Efetuado)=True) And (([F Movimento Contas].DataPagto)<Formulários![Extrato Movimento Contabil]!DTInicial))
ORDER BY [F Movimento Contas].DataPagto;
