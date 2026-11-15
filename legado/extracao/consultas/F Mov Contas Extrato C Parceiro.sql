-- Consulta: F Mov Contas Extrato C Parceiro
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Parceiro]!DTInicial (Texto), Formulários![Extrato Contas Parceiro]!CodigoParceiro (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, DataMovto, MovtoOrigem, ValorCredito, Complemento, CodigoParceiro, Historico, NumDoc, CodigoVinculada, Efetuado )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].DataVencto, [F Movimento Contas].NumMovimento, [ValorCredito]-[ValorDebito] AS VLancamento, [F Movimento Contas].Complemento, Parceiros.CodigoParceiro, [F Movimento Contas].CodHistorico, [F Movimento Contas].NumDoc, [F Movimento Contas].EmpVinculada, [F Movimento Contas].Efetuado
FROM Parceiros INNER JOIN (Historico INNER JOIN [F Movimento Contas] ON Historico.CodHistorico=[F Movimento Contas].CodHistorico) ON Parceiros.CodigoParceiro=[F Movimento Contas].CodigoParceiro
WHERE ((([F Movimento Contas].Confirmado)=False) And (([F Movimento Contas].DataVencto)>=Formulários![Extrato Contas Parceiro]!DTInicial) And ((Parceiros.CodigoParceiro)=Formulários![Extrato Contas Parceiro]!CodigoParceiro) And (([F Movimento Contas].SomenteIntegracao)=False))
ORDER BY [F Movimento Contas].Confirmado, [F Movimento Contas].DataVencto;
