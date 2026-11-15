-- Consulta: ParcelasImovelCred
-- Tipo: Seleção (0)
-- Parâmetros: Formulários!Imoveis!ParcelasImovel.Form!AgrupadorVenda (Texto)
-- Descrição: 

SELECT [F Movimento Contas].Complemento, [F Movimento Contas].ValorDebito, [F Movimento Contas].ValorCredito, [F Movimento Contas].DataVencto, [F Movimento Contas].DataPagto, [F Movimento Contas].AgrupadorVenda, [F Movimento Contas].ContaFinanceira, [F Movimento Contas].ValorOriginalImovel, [F Movimento Contas].CodigoCondPagto, [F Movimento Contas].NumMovimento
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].ValorDebito)=0) And (([F Movimento Contas].DataPagto) Is Null) And (([F Movimento Contas].AgrupadorVenda)=Formulários!Imoveis!ParcelasImovel.Form!AgrupadorVenda));
