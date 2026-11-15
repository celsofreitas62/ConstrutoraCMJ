-- Consulta: Reajuste de Parcelas Empresa
-- Tipo: Atualização (48)
-- Parâmetros: [Formulários]![ReajusteParceiros]![FatorReajuste] (Texto), [Formulários]![ReajusteParceiros]![PercentualReajuste] (Texto), Formulários!ReajusteParceiros!EmpresaSelecionada (Texto), Formulários!ReajusteParceiros!IndiceSelecionado (Texto)
-- Descrição: 

UPDATE Parceiros INNER JOIN (Indices INNER JOIN (Imoveis INNER JOIN (EmpVinculada INNER JOIN [F Movimento Contas] ON EmpVinculada.CodigoVinculada=[F Movimento Contas].EmpVinculada) ON Imoveis.CodImovel=[F Movimento Contas].CodImovel) ON Indices.CodIndice=[F Movimento Contas].IndiceReajuste) ON Parceiros.CodigoParceiro=[F Movimento Contas].CodigoParceiro SET [F Movimento Contas].ValorCredito = IIf([Formulários]![ReajusteParceiros]![FatorReajuste]="%",([ValorOriginalImovel]+([ValorOriginalImovel]*([Formulários]![ReajusteParceiros]![PercentualReajuste]/100))),([ValorOriginalImovel]*[Formulários]![ReajusteParceiros]![PercentualReajuste]))
WHERE ((([F Movimento Contas].EmpVinculada)=Formulários!ReajusteParceiros!EmpresaSelecionada) And (([F Movimento Contas].IndiceReajuste)=Formulários!ReajusteParceiros!IndiceSelecionado) And (([F Movimento Contas].PagoAntecipado)=False) And (([F Movimento Contas].DataPagto) Is Null) And (([F Movimento Contas].SofreReajuste)=True) And (([F Movimento Contas].Confirmado)=False));
