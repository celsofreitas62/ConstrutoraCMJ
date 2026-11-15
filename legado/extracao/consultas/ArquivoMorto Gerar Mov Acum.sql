-- Consulta: ArquivoMorto Gerar Mov Acum
-- Tipo: Acréscimo (64)
-- Parâmetros: [Formulários]![ArquivoMorto]![DTProxMov] (Texto), [Formulários]![ArquivoMorto]![DataIniRel] (Texto), [Formulários]![ArquivoMorto]![DataFimRel] (Texto)
-- Descrição: 

INSERT INTO [F Movimento Contas] ( EmpVinculada, CodigoParceiro, CodHistorico, DataMovto, ValorDebito, ValorCredito, NumDoc, Complemento, Plano1, Plano2, Plano3, ContaFinanceira, Confirmado, DataPagto, DataVencto, Efetuado )
SELECT [F Movimento Contas].EmpVinculada, [F Movimento Contas].CodigoParceiro, 7 AS Historico, [Formulários]![ArquivoMorto]![DTProxMov] AS DtMovto, Sum([F Movimento Contas].ValorDebito) AS TTDebito, Sum([F Movimento Contas].ValorCredito) AS TTCredito, "Sd Acum" AS Doc, [Formulários]![ArquivoMorto]![DataIniRel] & " a " & [Formulários]![ArquivoMorto]![DataFimRel] AS Compl, 1 AS Plan1, 1 AS Plan2, IIf(([TTCredito]-[TTDebito])>0,1,2) AS Plan3, [F Movimento Contas].ContaFinanceira, True AS Confirm, [Formulários]![ArquivoMorto]![DTProxMov] AS DtPagto, [Formulários]![ArquivoMorto]![DTProxMov] AS DtVencto, True AS Efet
FROM Parceiros INNER JOIN (Imoveis INNER JOIN ([F Contas Financeiras] INNER JOIN [F Movimento Contas] ON [F Contas Financeiras].CodigoConta=[F Movimento Contas].ContaFinanceira) ON Imoveis.CodImovel=[F Movimento Contas].CodImovel) ON Parceiros.CodigoParceiro=[F Movimento Contas].CodigoParceiro
WHERE ((([F Movimento Contas].Confirmado)=True) And (([F Movimento Contas].DataPagto)>=Formulários!ArquivoMorto!DataIniRel And ([F Movimento Contas].DataPagto)<=Formulários!ArquivoMorto!DataFimRel))
GROUP BY [F Movimento Contas].EmpVinculada, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].ContaFinanceira;
