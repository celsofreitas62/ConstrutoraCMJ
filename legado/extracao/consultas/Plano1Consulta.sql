-- Consulta: Plano1Consulta
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [Plano1].[Plano1], [Plano1].[DescricaoPlano1]
FROM Plano1
WHERE ((([Plano1].[DescricaoPlano1])<>"sistema"))
ORDER BY [Plano1].[DescricaoPlano1];
