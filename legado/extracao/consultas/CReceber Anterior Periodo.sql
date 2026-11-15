-- Consulta: CReceber Anterior Periodo
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Periodo Relatorio CReceber Abertas]!DataIniRel (Texto)
-- Descrição: 

SELECT [F Movimento Contas].DataVencto, [F Movimento Contas].ValorCredito, [F Movimento Contas].ContaFinanceira, [F Movimento Contas].Confirmado, [F Movimento Contas].CodImovel, [F Movimento Contas].Efetuado, [F Movimento Contas].NumMovimento, [F Movimento Contas].CodigoParceiro, Historico.Descricao AS DescricaoHistorico, [F Movimento Contas].EmpVinculada, [F Movimento Contas].NumDoc, [F Movimento Contas].Complemento, ([DescricaoHistorico] & " " & [NumDoc] & " " & [Complemento]) AS HistoricoRelatorio
FROM Historico INNER JOIN [F Movimento Contas] ON Historico.CodHistorico=[F Movimento Contas].CodHistorico
WHERE ((([F Movimento Contas].DataVencto)<Formulários![Periodo Relatorio CReceber Abertas]!DataIniRel) And (([F Movimento Contas].ValorCredito)<>0) And (([F Movimento Contas].ContaFinanceira)<>2) And (([F Movimento Contas].Confirmado)=False) And (([F Movimento Contas].CodImovel)=1) And (([F Movimento Contas].CodigoParceiro)=1) And (([F Movimento Contas].DataPagto) Is Null));
