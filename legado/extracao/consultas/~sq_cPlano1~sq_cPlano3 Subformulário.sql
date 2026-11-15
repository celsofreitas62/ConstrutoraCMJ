-- Consulta: ~sq_cPlano1~sq_cPlano3 Subformulário
-- Tipo: Seleção (0)
-- Parâmetros: __Plano2 Subformulário.Form!Plano2 (Texto)
-- Descrição: 

PARAMETERS [__Plano2 Subformulário].Form!Plano2 Value;
SELECT DISTINCTROW *
FROM Plano3 AS Plano1
WHERE ([__Plano2 Subformulário].Form!Plano2 = Plano2);
