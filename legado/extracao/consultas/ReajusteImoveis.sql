-- Consulta: ReajusteImoveis
-- Tipo: Seleção (0)
-- Parâmetros: Formulários!ReajusteImoveis!EmpresaSelecionada (Texto), Formulários!ReajusteImoveis!IndiceSelecionado (Texto)
-- Descrição: 

SELECT Imoveis.EmpVinculada, Imoveis.IndiceReajuste, Imoveis.Modelo, CondPagtoImovel.QtdParcelas, [QtdParcelas]*[ValorInicial] AS TotalAtual, CondPagtoImovel.ValorReajustado, [QtdParcelas]*[ValorReajustado] AS TotalReajustado, Imoveis.NomeImovel, CondPagtoImovel.NomePagto, CondPagtoImovel.ValorInicial, Imoveis.Vendido, Imoveis.Estilo, Imoveis.Divisao
FROM Imoveis INNER JOIN CondPagtoImovel ON Imoveis.CodImovel=CondPagtoImovel.CodImovel
WHERE (((Imoveis.EmpVinculada)=Formulários!ReajusteImoveis!EmpresaSelecionada) And ((Imoveis.IndiceReajuste)=Formulários!ReajusteImoveis!IndiceSelecionado) And ((Imoveis.Vendido)=False));
