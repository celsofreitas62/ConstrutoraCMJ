-- Consulta: ~sq_cPlano1~sq_cPlano2 Subformulário
-- Tipo: Seleção (0)
-- Parâmetros: __Plano1 (Texto)
-- Descrição: 

PARAMETERS __Plano1 Value;
SELECT DISTINCTROW *
FROM Plano2 AS Plano1
WHERE ([__Plano1] = Plano1);
