-- Consulta: ~sq_cF Nivel1~sq_cF Nivel2 Subform
-- Tipo: Seleção (0)
-- Parâmetros: (não foi possível ler: consulta depende de tabela vinculada ou de outra consulta)
-- Descrição: 

PARAMETERS __Nivel1 Value;
SELECT DISTINCTROW *
FROM [F Nivel2] AS [F Nivel1]
WHERE ([__Nivel1] = Nivel1);
