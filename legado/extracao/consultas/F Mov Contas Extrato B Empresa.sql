-- Consulta: F Mov Contas Extrato B Empresa
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Empresa]!DTInicial (Texto), Formulários![Extrato Contas Empresa]!CodigoVinculada (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, DataMovto, CodigoVinculada, MovtoOrigem, ValorCredito, NumDoc, Historico, Complemento, CodigoParceiro, Efetuado )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].DataPagto, EmpVinculada.CodigoVinculada, [F Movimento Contas].NumMovimento, [ValorCredito]-[ValorDebito] AS VLancamento, [F Movimento Contas].NumDoc, [F Movimento Contas].CodHistorico, [F Movimento Contas].Complemento, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].Efetuado
FROM EmpVinculada INNER JOIN [F Movimento Contas] ON EmpVinculada.CodigoVinculada=[F Movimento Contas].EmpVinculada
WHERE ((([F Movimento Contas].Confirmado)=True) And (([F Movimento Contas].DataPagto)>=Formulários![Extrato Contas Empresa]!DTInicial) And ((EmpVinculada.CodigoVinculada)=Formulários![Extrato Contas Empresa]!CodigoVinculada) And (([F Movimento Contas].SomenteIntegracao)=False))
ORDER BY [F Movimento Contas].Confirmado, [F Movimento Contas].DataPagto;
