-- Consulta: ~sq_rPlano de Contas
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Plano1].[DescricaoPlano1], [Plano2].[DescricaoPlano2], [Plano3].[DescricaoPlano3], [Plano1].[Plano1], [Plano2].[Plano2]
FROM (Plano1 INNER JOIN Plano2 ON [Plano1].[Plano1]=[Plano2].[Plano1]) INNER JOIN Plano3 ON [Plano2].[Plano2]=[Plano3].[Plano2];
