-- Consulta: Custos Empresa Anterior2
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Relatorio Custos Empresa2]!DTInicial (Texto), [Formulários]![Relatorio Custos Empresa2]![CodigoVinculada] (Texto)
-- Descrição: 

SELECT CustoEmpresa.EmpVinculada, Sum(CustoEmpresa.ValorDebito) AS DebitoAnterior, Sum(CustoEmpresa.ValorCredito) AS CreditoAnterior
FROM CustoEmpresa
WHERE (((CustoEmpresa.DataPagto)<Formulários![Relatorio Custos Empresa2]!DTInicial) And ((CustoEmpresa.SomenteIntegracao)=False) And ((CustoEmpresa.Plano1)<>1))
GROUP BY CustoEmpresa.EmpVinculada
HAVING (((CustoEmpresa.EmpVinculada)=[Formulários]![Relatorio Custos Empresa2]![CodigoVinculada]));
