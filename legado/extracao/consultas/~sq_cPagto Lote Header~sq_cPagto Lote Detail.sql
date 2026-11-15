-- Consulta: ~sq_cPagto Lote Header~sq_cPagto Lote Detail
-- Tipo: Seleção (0)
-- Parâmetros: __CodigoParceiro (Texto), Formulários![Pagto Lote Header]!CodigoParceiro (Texto)
-- Descrição: 

PARAMETERS __CodigoParceiro Value;
SELECT DISTINCTROW *
FROM [Pagto Lote Consulta] AS [Pagto Lote Header]
WHERE ([__CodigoParceiro] = CodigoParceiro);
