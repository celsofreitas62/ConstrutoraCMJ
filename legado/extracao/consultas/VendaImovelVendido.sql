-- Consulta: VendaImovelVendido
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Imoveis].[Vendido], [EmpVinculada].[NomeVinculada], [EmpVinculada].[ImovelEmVenda], [Imoveis].[Modelo], [Imoveis].[EmpVinculada], [Imoveis].[Vendedor], [Imoveis].[IndiceReajuste], [Parceiros].[AplicarReajuste], [EmpVinculada].[FinanceiraPadrao], [Imoveis].[CodImovel], [Imoveis].[NomeImovel], [Imoveis].[Divisao], [Imoveis].[Estilo], [Imoveis].[Proprietario], [Imoveis].[PercentualComissao], [Parceiros].[NomeParceiro], Parceiros_1.NomeParceiro AS NomeDoVendedor
FROM (EmpVinculada INNER JOIN (Parceiros INNER JOIN Imoveis ON [Parceiros].[CodigoParceiro]=[Imoveis].[Proprietario]) ON [EmpVinculada].[CodigoVinculada]=[Imoveis].[EmpVinculada]) INNER JOIN Parceiros AS Parceiros_1 ON [Imoveis].[Vendedor]=Parceiros_1.CodigoParceiro
WHERE ((([Imoveis].[Vendido])=False) And (([EmpVinculada].[NomeVinculada])<>"sistema") And (([EmpVinculada].[ImovelEmVenda])=True) And (([Imoveis].[Modelo])=False));
