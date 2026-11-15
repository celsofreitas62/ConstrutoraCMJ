-- Consulta: ~sq_cF Movimento Contas Mensais~sq_cNivel2
-- Tipo: Seleção (0)
-- Parâmetros: (não foi possível ler: consulta depende de tabela vinculada ou de outra consulta)
-- Descrição: 

SELECT [F Nivel2].[Nivel2], [F Nivel2].[Descricao], [F Nivel1].[Descricao]
FROM [F Nivel1] INNER JOIN [F Nivel2] ON [F Nivel1].[Nivel1]=[F Nivel2].[Nivel1];
