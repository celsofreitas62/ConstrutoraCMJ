-- Consulta: ~sq_dF Movimento Contas Fin 0s~sq_dResumo Cartao Credito
-- Tipo: Seleção (0)
-- Parâmetros: (não foi possível ler: consulta depende de tabela vinculada ou de outra consulta)
-- Descrição: 

SELECT Resumo Cartao Credito.*, [F Contas Financeiras].[Limite Credito]
FROM [F Contas Financeiras] INNER JOIN [Resumo Cartao Credito] ON [F Contas Financeiras].[CodigoConta]=[Resumo Cartao Credito].[CodigoConta];
