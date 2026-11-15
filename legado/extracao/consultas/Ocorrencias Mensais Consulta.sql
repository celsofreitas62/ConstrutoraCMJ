-- Consulta: Ocorrencias Mensais Consulta
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Ocorrencias Mensais].[EmpVinculada], [Ocorrencias Mensais].[CodigoParceiro], [Ocorrencias Mensais].[EmitirCheque], [Ocorrencias Mensais].[CodHistorico], [Ocorrencias Mensais].[DiaVencimento], [Ocorrencias Mensais].[DataMovto], [Ocorrencias Mensais].[ValorDebito], [Ocorrencias Mensais].[ValorCredito], [Ocorrencias Mensais].[Complemento], [Ocorrencias Mensais].[Plano3], [Ocorrencias Mensais].[ContaFinanceira], [Ocorrencias Mensais].[Integracao], [Ocorrencias Mensais].[DataVencto], [Ocorrencias Mensais].[Observacao], [Ocorrencias Mensais].[NumDoc], [Ocorrencias Mensais].[PagamentoLote], [Ocorrencias Mensais].[SomenteIntegracao], [Plano2].[DescricaoPlano2], [Plano1].[DescricaoPlano1]
FROM (Plano1 INNER JOIN Plano2 ON [Plano1].[Plano1]=[Plano2].[Plano1]) INNER JOIN ([Ocorrencias Mensais] INNER JOIN Plano3 ON [Ocorrencias Mensais].[Plano3]=[Plano3].[Plano3]) ON [Plano2].[Plano2]=[Plano3].[Plano2]
ORDER BY [Ocorrencias Mensais].[EmpVinculada], [Ocorrencias Mensais].[DiaVencimento];
