-- Consulta: ~sq_cF Movimento Contas Analise~sq_cNivel2
-- Tipo: Seleção (0)
-- Parâmetros: (não foi possível ler: consulta depende de tabela vinculada ou de outra consulta)
-- Descrição: 

SELECT [F Nivel2].[Nivel2], [F Nivel2].[Nivel1], [F Nivel2].[Descricao]
FROM [F Nivel2]
WHERE ((([F Nivel2].[Nivel1])=[Forms]![F Movimento Contas Analise]![Nivel1]))
ORDER BY [F Nivel2].[Nivel1], [F Nivel2].[Descricao];
