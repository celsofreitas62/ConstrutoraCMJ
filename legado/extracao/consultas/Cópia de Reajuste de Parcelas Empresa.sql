-- Consulta: Cópia de Reajuste de Parcelas Empresa
-- Tipo: Seleção (0)
-- Parâmetros: [Formulários]![ReajusteParceiros]![EmpresaSelecionada] (Texto), [Formulários]![ReajusteParceiros]![IndiceSelecionado] (Texto)
-- Descrição: 

SELECT [F Movimento Contas].ValorCredito, [F Movimento Contas].ValorOriginalImovel, [F Movimento Contas].CodImovel, [F Movimento Contas].CodigoCondPagto, [F Movimento Contas].AgrupadorVenda, [F Movimento Contas].LinkVenda, [F Movimento Contas].EmpVinculada, [F Movimento Contas].IndiceReajuste
FROM Parceiros INNER JOIN (Indices INNER JOIN (Imoveis INNER JOIN (EmpVinculada INNER JOIN [F Movimento Contas] ON EmpVinculada.CodigoVinculada = [F Movimento Contas].EmpVinculada) ON Imoveis.CodImovel = [F Movimento Contas].CodImovel) ON Indices.CodIndice = [F Movimento Contas].IndiceReajuste) ON Parceiros.CodigoParceiro = [F Movimento Contas].CodigoParceiro
WHERE ((([F Movimento Contas].EmpVinculada)=[Formulários]![ReajusteParceiros]![EmpresaSelecionada]) AND (([F Movimento Contas].IndiceReajuste)=[Formulários]![ReajusteParceiros]![IndiceSelecionado]) AND (([F Movimento Contas].PagoAntecipado)=False) AND (([F Movimento Contas].DataPagto) Is Null) AND (([F Movimento Contas].SofreReajuste)=True) AND (([F Movimento Contas].Confirmado)=False));
