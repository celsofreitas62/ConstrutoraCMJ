-- Consulta: PosicaoImovelParceiro Total
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [EmpVinculada].[NomeVinculada], [Parceiros].[NomeParceiro], [Imoveis].[NomeImovel], Sum([PosicaoImovelParceiro].[ValorDebito]) AS TotalDebito, Sum([PosicaoImovelParceiro].[ValorCredito]) AS TotalCredito, ([TotalDebito]-[TotalCredito]) AS Saldo
FROM (Imoveis INNER JOIN (EmpVinculada INNER JOIN PosicaoImovelParceiro ON [EmpVinculada].[CodigoVinculada]=[PosicaoImovelParceiro].[EmpVinculada]) ON [Imoveis].[CodImovel]=[PosicaoImovelParceiro].[Imovel]) INNER JOIN Parceiros ON [PosicaoImovelParceiro].[CodigoParceiro]=[Parceiros].[CodigoParceiro]
GROUP BY [EmpVinculada].[NomeVinculada], [Parceiros].[NomeParceiro], [Imoveis].[NomeImovel];
