-- Consulta: Manutencao Agrupada Vendas
-- Tipo: Seleção (0)
-- Parâmetros: [Movto Agrupador] (Texto)
-- Descrição: 

SELECT [F Movimento Contas].ClassificacaoVenda, [F Movimento Contas].NumMovimento, [F Movimento Contas].EmpVinculada, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodHistorico, [F Movimento Contas].DataMovto, [F Movimento Contas].ValorDebito, [F Movimento Contas].ValorCredito, [F Movimento Contas].Complemento, [F Movimento Contas].Plano3, [F Movimento Contas].ContaFinanceira, [F Movimento Contas].Confirmado, [F Movimento Contas].Integracao, [F Movimento Contas].DataPagto, [F Movimento Contas].DataVencto, [F Movimento Contas].MovPagtoLote, [F Movimento Contas].SelPagtoLote, [F Movimento Contas].Observacao, [F Movimento Contas].NumDoc, [F Movimento Contas].CodImovel, [F Movimento Contas].AgrupadorVenda, [F Movimento Contas].SofreReajuste, [F Movimento Contas].IndiceReajuste, [F Movimento Contas].Efetuado
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].AgrupadorVenda)=[Movto Agrupador]))
ORDER BY [F Movimento Contas].ClassificacaoVenda, [F Movimento Contas].NumMovimento;
