-- Consulta: ~sq_cF Manutencao Agrupada Vendas~sq_cPlano3
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Plano3].[Plano3], [Plano3].[DescricaoPlano3], [Plano2].[DescricaoPlano2], [Plano1].[DescricaoPlano1]
FROM (Plano1 INNER JOIN Plano2 ON [Plano1].[Plano1]=[Plano2].[Plano1]) INNER JOIN Plano3 ON [Plano2].[Plano2]=[Plano3].[Plano2]
WHERE ((([Plano3].[DescricaoPlano3])<>"sistema"));
