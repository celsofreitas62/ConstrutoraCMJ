-- Consulta: Gerar Temp Parcelas Movto
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![F Movimento Contas]!ProximoVencto (Texto), Formulários![F Movimento Contas]!ComplementoProximaParcela (Texto), [Formulários]![F Movimento Contas]![NumMovimento] (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( CodigoVinculada, CodigoParceiro, CodigoConta, Plano3, Historico, NumDoc, ReferenteNotaFiscal, ValorDebito, ValorCredito, DataMovto, Observacao, MovPagtoLote, PagamentoLote, Efetuado, Confirmado, Integracao, SomenteIntegracao, DataVencto, Complemento )
SELECT [F Movimento Contas].EmpVinculada, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].ContaFinanceira, [F Movimento Contas].Plano3, [F Movimento Contas].CodHistorico, [F Movimento Contas].NumDoc, [F Movimento Contas].ReferenteNotaFiscal, [F Movimento Contas].ValorDebito, [F Movimento Contas].ValorCredito, [F Movimento Contas].DataMovto, [F Movimento Contas].Observacao, [F Movimento Contas].MovPagtoLote, [F Movimento Contas].PagamentoLote, [F Movimento Contas].Efetuado, [F Movimento Contas].Confirmado, [F Movimento Contas].Integracao, [F Movimento Contas].SomenteIntegracao, Formulários![F Movimento Contas]!ProximoVencto AS VenctoParcMov, Formulários![F Movimento Contas]!ComplementoProximaParcela AS ComplemParc
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].NumMovimento)=[Formulários]![F Movimento Contas]![NumMovimento]));
