-- Consulta: F Mov Contas Extrato A Parceiro
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Parceiro]!DTInicial (Texto), Formulários![Extrato Contas Parceiro]!CodigoParceiro (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, CodigoParceiro, Efetuado, ValorCredito, DataMovto, Historico, Complemento, CodigoVinculada )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].Efetuado, Sum([ValorCredito]-[ValorDebito]) AS SdoAnterior, Formulários![Extrato Contas Parceiro]!DTInicial AS DTAnterior, "7" AS CodHistorico, "Anterior Confirmados" AS DescricaoComp, "1" AS Empresa
FROM Parceiros INNER JOIN [F Movimento Contas] ON Parceiros.CodigoParceiro=[F Movimento Contas].CodigoParceiro
WHERE ((([F Movimento Contas].SomenteIntegracao)=False) And (([F Movimento Contas].DataPagto)<Formulários![Extrato Contas Parceiro]!DTInicial))
GROUP BY [F Movimento Contas].Confirmado, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].Efetuado
HAVING ((([F Movimento Contas].Confirmado)=True) And (([F Movimento Contas].CodigoParceiro)=Formulários![Extrato Contas Parceiro]!CodigoParceiro));
