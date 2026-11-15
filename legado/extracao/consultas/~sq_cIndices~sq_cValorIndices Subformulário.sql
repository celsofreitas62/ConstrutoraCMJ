-- Consulta: ~sq_cIndices~sq_cValorIndices Subformulário
-- Tipo: Seleção (0)
-- Parâmetros: __CodIndice (Texto)
-- Descrição: 

PARAMETERS __CodIndice Value;
SELECT DISTINCTROW *
FROM ValorIndices AS Indices
WHERE ([__CodIndice] = CodIndice);
