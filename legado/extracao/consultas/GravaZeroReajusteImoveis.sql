-- Consulta: GravaZeroReajusteImoveis
-- Tipo: Atualização (48)
-- Parâmetros: [Formulários]![ReajusteImoveis]![EmpresaSelecionada] (Texto)
-- Descrição: 

UPDATE Imoveis INNER JOIN CondPagtoImovel ON Imoveis.CodImovel=CondPagtoImovel.CodImovel SET CondPagtoImovel.ValorReajustado = 0
WHERE (((Imoveis.EmpVinculada)=[Formulários]![ReajusteImoveis]![EmpresaSelecionada]));
