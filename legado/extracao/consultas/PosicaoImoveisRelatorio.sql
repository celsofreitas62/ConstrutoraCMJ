-- Consulta: PosicaoImoveisRelatorio
-- Tipo: Seleção (0)
-- Parâmetros: Formulários!SelecionaEmpresaPosicaoImovel!CodigoVinculada (Texto)
-- Descrição: 

SELECT ControleImoveis.Vendido, ControleImoveis.Divisao, ControleImoveis.NomeImovel, ControleImoveis.CodImovel, ControleImoveis.Modelo, TotalImovel.TImovel, ControleImoveis.NomeParceiro, ControleImoveis.Estilo, ControleImoveis.EmpVinculada, ControleImoveis.Proprietario
FROM ControleImoveis INNER JOIN TotalImovel ON ControleImoveis.CodImovel=TotalImovel.CodImovel
WHERE (((ControleImoveis.NomeImovel)<>"N/A") And ((ControleImoveis.Modelo)=False) And ((ControleImoveis.EmpVinculada)=Formulários!SelecionaEmpresaPosicaoImovel!CodigoVinculada))
ORDER BY ControleImoveis.Vendido, ControleImoveis.Divisao, ControleImoveis.NomeImovel;
