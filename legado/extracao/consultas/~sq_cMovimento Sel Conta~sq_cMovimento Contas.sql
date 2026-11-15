-- Consulta: ~sq_cMovimento Sel Conta~sq_cMovimento Contas
-- Tipo: Seleção (0)
-- Parâmetros: (não foi possível ler: consulta depende de tabela vinculada ou de outra consulta)
-- Descrição: 

PARAMETERS __CodigoConta Value;
SELECT DISTINCTROW *
FROM [F Movimento Contas Query] AS [Movimento Sel Conta]
WHERE ([__CodigoConta] = ContaFinanceira);
