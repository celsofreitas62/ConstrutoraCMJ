-- Consulta: ~sq_cVendaImovelVendido~sq_cVendaCondPagto
-- Tipo: Seleção (0)
-- Parâmetros: __CodImovel (Texto), Formulários!VendaImovelVendido!CodImovel (Texto)
-- Descrição: 

PARAMETERS __CodImovel Value;
SELECT DISTINCTROW *
FROM CondPagtoConsulta AS VendaImovelVendido
WHERE ([__CodImovel] = CodImovel);
