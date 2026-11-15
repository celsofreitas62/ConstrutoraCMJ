-- Consulta: Custos Permuta Despesas
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Relatorio Custos Empresa]!DTInicial (Texto), Formulários![Relatorio Custos Empresa]!DTFinal (Texto), [Formulários]![Relatorio Custos Empresa]![CodigoVinculada] (Texto)
-- Descrição: 

SELECT CustoEmpresa.EmpVinculada, Sum(CustoEmpresa.ValorDebito) AS DebitoAnterior, Sum(CustoEmpresa.ValorCredito) AS CreditoAnterior
FROM CustoEmpresa INNER JOIN EmpVinculada ON CustoEmpresa.EmpVinculada=EmpVinculada.CodigoVinculada
WHERE (((CustoEmpresa.DataPagto)>=Formulários![Relatorio Custos Empresa]!DTInicial And (CustoEmpresa.DataPagto)<=Formulários![Relatorio Custos Empresa]!DTFinal) And ((CustoEmpresa.SomenteIntegracao)=False) And ((CustoEmpresa.Plano1)=25))
GROUP BY CustoEmpresa.EmpVinculada
HAVING (((CustoEmpresa.EmpVinculada)=[Formulários]![Relatorio Custos Empresa]![CodigoVinculada]));
