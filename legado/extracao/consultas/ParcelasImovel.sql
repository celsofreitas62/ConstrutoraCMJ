-- Consulta: ParcelasImovel
-- Tipo: Seleção (0)
-- Parâmetros: [Formulários]![Imoveis]![Imoveis Subformulário].[Form]![CodImovel] (Texto)
-- Descrição: 

SELECT [F Movimento Contas].ValorDebito, [F Movimento Contas].ValorCredito, [F Movimento Contas].DataVencto, [F Movimento Contas].DataPagto, [F Movimento Contas].AgrupadorVenda, [F Movimento Contas].CodImovel, [F Movimento Contas].ValorOriginalImovel, [F Movimento Contas].CodigoCondPagto, [F Movimento Contas].NumMovimento
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].CodImovel)=[Formulários]![Imoveis]![Imoveis Subformulário].[Form]![CodImovel]));
