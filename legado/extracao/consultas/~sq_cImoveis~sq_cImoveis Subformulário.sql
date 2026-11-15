-- Consulta: ~sq_cImoveis~sq_cImoveis Subformulário
-- Tipo: Seleção (0)
-- Parâmetros: __CodigoVinculada (Texto)
-- Descrição: 

PARAMETERS __CodigoVinculada Value;
SELECT DISTINCTROW *
FROM ControleImoveis AS Imoveis
WHERE ([__CodigoVinculada] = EmpVinculada);
