-- Consulta: Custos Empresa Anterior
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Relatorio Custos Empresa]!DataInicialCustos (Texto), Formulários![Relatorio Custos Empresa]!DTInicial (Texto), [Formulários]![Relatorio Custos Empresa]![CodigoVinculada] (Texto)
-- Descrição: 

SELECT [F Movimento Contas].EmpVinculada, Sum([F Movimento Contas].ValorCredito) AS CreditoAnterior, Sum([F Movimento Contas].ValorDebito) AS DebitoAnterior
FROM EmpVinculada INNER JOIN [F Movimento Contas] ON EmpVinculada.CodigoVinculada=[F Movimento Contas].EmpVinculada
WHERE ((([F Movimento Contas].DataPagto)>Formulários![Relatorio Custos Empresa]!DataInicialCustos And ([F Movimento Contas].DataPagto)<Formulários![Relatorio Custos Empresa]!DTInicial) And (([F Movimento Contas].SomenteIntegracao)=False) And (([F Movimento Contas].Plano1)<>1))
GROUP BY [F Movimento Contas].EmpVinculada
HAVING ((([F Movimento Contas].EmpVinculada)=[Formulários]![Relatorio Custos Empresa]![CodigoVinculada]));
