-- Consulta: F Mov Contas Extrato A Empresa
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários![Extrato Contas Empresa]!DTInicial (Texto), Formulários![Extrato Contas Empresa]!CodigoVinculada (Texto)
-- Descrição: 

INSERT INTO [F Temp Movimento Contas] ( Confirmado, CodigoVinculada, Efetuado, ValorCredito, DataMovto, Historico, Complemento, CodigoParceiro )
SELECT [F Movimento Contas].Confirmado, [F Movimento Contas].EmpVinculada, [F Movimento Contas].Efetuado, Sum([ValorCredito]-[ValorDebito]) AS SdoAnterior, Formulários![Extrato Contas Empresa]!DTInicial AS DTAnterior, "7" AS CodHistorico, "Anterior Confirmados" AS DescricaoComp, "1" AS Parceiro
FROM EmpVinculada INNER JOIN [F Movimento Contas] ON EmpVinculada.CodigoVinculada=[F Movimento Contas].EmpVinculada
WHERE ((([F Movimento Contas].SomenteIntegracao)=False) And (([F Movimento Contas].DataPagto)<Formulários![Extrato Contas Empresa]!DTInicial))
GROUP BY [F Movimento Contas].Confirmado, [F Movimento Contas].EmpVinculada, [F Movimento Contas].Efetuado
HAVING ((([F Movimento Contas].Confirmado)=True) And (([F Movimento Contas].EmpVinculada)=Formulários![Extrato Contas Empresa]!CodigoVinculada));
