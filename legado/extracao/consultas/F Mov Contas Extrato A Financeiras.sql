-- Consulta: F Mov Contas Extrato A Financeiras
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Financeiras]!DTInicial (Texto), Formulários![Extrato Contas Financeiras]!CodigoConta (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, Efetuado, Historico, CodigoParceiro, ValorCredito, DataMovto, Complemento, CodigoConta )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].Efetuado, "7" AS CodHistorico, "1" AS Parceiro, Sum([ValorCredito]-[ValorDebito]) AS SdoAnterior, Formulários![Extrato Contas Financeiras]!DTInicial AS DTAnterior, "Anterior Confirmados" AS DescricaoComp, [F Contas Financeiras].CodigoConta AS Financeira
FROM [F Contas Financeiras] INNER JOIN [F Movimento Contas] ON [F Contas Financeiras].CodigoConta=[F Movimento Contas].ContaFinanceira
WHERE ((([F Movimento Contas].SomenteIntegracao)=False) And (([F Contas Financeiras].CodigoConta)=Formulários![Extrato Contas Financeiras]!CodigoConta) And (([F Movimento Contas].DataMovto)<Formulários![Extrato Contas Financeiras]!DTInicial))
GROUP BY [F Movimento Contas].Confirmado, [F Movimento Contas].Efetuado, [F Contas Financeiras].CodigoConta
HAVING ((([F Movimento Contas].Confirmado)=True));
