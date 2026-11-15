-- Consulta: F Mov Contas Extrato C Financeiras
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Financeiras]!DTInicial (Texto), Formulários![Extrato Contas Financeiras]!CodigoConta (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, DataMovto, MovtoOrigem, CodigoParceiro, ValorCredito, Complemento, CodigoConta, Historico, NumDoc, Efetuado )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].DataVencto, [F Movimento Contas].NumMovimento, [F Movimento Contas].CodigoParceiro, [ValorCredito]-[ValorDebito] AS VLancamento, [F Movimento Contas].Complemento, [F Contas Financeiras].CodigoConta, [F Movimento Contas].CodHistorico, [F Movimento Contas].NumDoc, [F Movimento Contas].Efetuado
FROM Historico INNER JOIN ([F Contas Financeiras] INNER JOIN [F Movimento Contas] ON [F Contas Financeiras].CodigoConta=[F Movimento Contas].ContaFinanceira) ON Historico.CodHistorico=[F Movimento Contas].CodHistorico
WHERE ((([F Movimento Contas].Confirmado)=False) And (([F Movimento Contas].DataVencto)>=Formulários![Extrato Contas Financeiras]!DTInicial) And (([F Contas Financeiras].CodigoConta)=Formulários![Extrato Contas Financeiras]!CodigoConta) And (([F Movimento Contas].SomenteIntegracao)=False))
ORDER BY [F Movimento Contas].Confirmado, [F Movimento Contas].DataVencto;
