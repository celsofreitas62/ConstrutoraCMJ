-- Consulta: ControleImoveis
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Parceiros].[NomeParceiro], [Imoveis].[Modelo], [Imoveis].[EmpVinculada], [Imoveis].[CodImovel], [Imoveis].[NomeImovel], [Imoveis].[Divisao], [Imoveis].[Estilo], [Imoveis].[Proprietario], [Imoveis].[IndiceReajuste], [Imoveis].[PercentualComissao], [Imoveis].[Vendido], [Imoveis].[Vendedor]
FROM EmpVinculada INNER JOIN (Parceiros INNER JOIN Imoveis ON [Parceiros].[CodigoParceiro]=[Imoveis].[Proprietario]) ON [EmpVinculada].[CodigoVinculada]=[Imoveis].[EmpVinculada]
ORDER BY [Imoveis].[CodImovel];
