-- Consulta: F Mov Contas Extrato B Financeiras
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Financeiras]!DTInicial (Texto), Formulários![Extrato Contas Financeiras]!CodigoConta (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, DataMovto, MovtoOrigem, ValorCredito, CodigoParceiro, Historico, NumDoc, Complemento, CodigoConta, Efetuado )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].DataMovto, [F Movimento Contas].NumMovimento, [ValorCredito]-[ValorDebito] AS VLancamento, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodHistorico, [F Movimento Contas].NumDoc, [F Movimento Contas].Complemento, [F Contas Financeiras].CodigoConta, [F Movimento Contas].Efetuado
FROM [F Contas Financeiras] INNER JOIN [F Movimento Contas] ON [F Contas Financeiras].CodigoConta=[F Movimento Contas].ContaFinanceira
WHERE ((([F Movimento Contas].Confirmado)=True) And (([F Movimento Contas].DataMovto)>=Formulários![Extrato Contas Financeiras]!DTInicial) And (([F Contas Financeiras].CodigoConta)=Formulários![Extrato Contas Financeiras]!CodigoConta) And (([F Movimento Contas].SomenteIntegracao)=False))
ORDER BY [F Movimento Contas].Confirmado, [F Movimento Contas].DataMovto;
