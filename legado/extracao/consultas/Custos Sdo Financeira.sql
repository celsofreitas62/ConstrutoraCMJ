-- Consulta: Custos Sdo Financeira
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Relatorio Custos Empresa]!FinanceiraPadrao (Texto), Formulários![Relatorio Custos Empresa]!DTFinal (Texto)
-- Descrição: 

SELECT CustoEmpresa.Confirmado, Sum([ValorCredito]-[ValorDebito]) AS SdoAtualCustos
FROM CustoEmpresa INNER JOIN [F Contas Financeiras] ON CustoEmpresa.ContaFinanceira=[F Contas Financeiras].CodigoConta
WHERE (((CustoEmpresa.ContaFinanceira)=Formulários![Relatorio Custos Empresa]!FinanceiraPadrao) And ((CustoEmpresa.DataPagto)<=Formulários![Relatorio Custos Empresa]!DTFinal) And ((CustoEmpresa.SomenteIntegracao)=False))
GROUP BY CustoEmpresa.Confirmado
HAVING (((CustoEmpresa.Confirmado)=True));
