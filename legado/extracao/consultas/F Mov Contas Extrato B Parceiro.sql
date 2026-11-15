-- Consulta: F Mov Contas Extrato B Parceiro
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Parceiro]!DTInicial (Texto), Formulários![Extrato Contas Parceiro]!CodigoParceiro (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, DataMovto, MovtoOrigem, ValorCredito, NumDoc, Historico, Complemento, CodigoParceiro, Efetuado, CodigoVinculada )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].DataPagto, [F Movimento Contas].NumMovimento, [ValorCredito]-[ValorDebito] AS VLancamento, [F Movimento Contas].NumDoc, [F Movimento Contas].CodHistorico, [F Movimento Contas].Complemento, Parceiros.CodigoParceiro, [F Movimento Contas].Efetuado, [F Movimento Contas].EmpVinculada
FROM Parceiros INNER JOIN [F Movimento Contas] ON Parceiros.CodigoParceiro=[F Movimento Contas].CodigoParceiro
WHERE ((([F Movimento Contas].Confirmado)=True) And (([F Movimento Contas].DataPagto)>=Formulários![Extrato Contas Parceiro]!DTInicial) And ((Parceiros.CodigoParceiro)=Formulários![Extrato Contas Parceiro]!CodigoParceiro) And (([F Movimento Contas].SomenteIntegracao)=False))
ORDER BY [F Movimento Contas].Confirmado, [F Movimento Contas].DataPagto;
