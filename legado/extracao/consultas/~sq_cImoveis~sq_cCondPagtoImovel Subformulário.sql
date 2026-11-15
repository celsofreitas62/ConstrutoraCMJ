-- Consulta: ~sq_cImoveis~sq_cCondPagtoImovel Subformulário
-- Tipo: Seleção (0)
-- Parâmetros: __Imoveis Subformulário.Form!CodImovel (Texto)
-- Descrição: 

PARAMETERS [__Imoveis Subformulário].Form!CodImovel Value;
SELECT DISTINCTROW *
FROM (SELECT CondPagtoImovel.*, [QtdParcelas]*[ValorInicial] AS TTipoPagto FROM CondPagtoImovel)  AS Imoveis
WHERE ([__Imoveis Subformulário].Form!CodImovel = CodImovel);
