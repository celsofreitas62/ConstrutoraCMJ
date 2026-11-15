-- Consulta: F Mov Contas Extrato D Empresa
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Empresa]!DTInicial (Texto), Formulários![Extrato Contas Empresa]!CodigoVinculada (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, DataMovto, MovtoOrigem, ValorCredito, Complemento, CodigoVinculada, Historico, NumDoc, CodigoParceiro, Efetuado )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].DataVencto, [F Movimento Contas].NumMovimento, [ValorCredito]-[ValorDebito] AS VLancamento, [F Movimento Contas].Complemento, EmpVinculada.CodigoVinculada, [F Movimento Contas].CodHistorico, [F Movimento Contas].NumDoc, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].Efetuado
FROM Parceiros INNER JOIN (Historico INNER JOIN (EmpVinculada INNER JOIN [F Movimento Contas] ON EmpVinculada.CodigoVinculada=[F Movimento Contas].EmpVinculada) ON Historico.CodHistorico=[F Movimento Contas].CodHistorico) ON Parceiros.CodigoParceiro=[F Movimento Contas].CodigoParceiro
WHERE ((([F Movimento Contas].Confirmado)=False) And (([F Movimento Contas].DataVencto)<Formulários![Extrato Contas Empresa]!DTInicial) And ((EmpVinculada.CodigoVinculada)=Formulários![Extrato Contas Empresa]!CodigoVinculada) And (([F Movimento Contas].SomenteIntegracao)=False))
ORDER BY [F Movimento Contas].Confirmado, [F Movimento Contas].DataVencto;
