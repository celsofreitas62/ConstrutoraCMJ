-- Consulta: ~sq_cEmpMaster~sq_cEmpVinculada Subformulário
-- Tipo: Seleção (0)
-- Parâmetros: __CodigoMaster (Texto)
-- Descrição: 

PARAMETERS __CodigoMaster Value;
SELECT DISTINCTROW *
FROM EmpVinculada AS EmpMaster
WHERE ([__CodigoMaster] = CodigoMaster);
