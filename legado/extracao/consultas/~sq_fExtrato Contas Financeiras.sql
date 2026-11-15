-- Consulta: ~sq_fExtrato Contas Financeiras
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Contas Financeiras].[CodigoConta], [F Contas Financeiras].[Descricao], [F Contas Financeiras].[Numero Conta], [F Contas Financeiras].[Tipo Conta], [F Contas Financeiras].[Master]
FROM [F Contas Financeiras]
WHERE ((([F Contas Financeiras].[Master])=False))
ORDER BY [F Contas Financeiras].[Descricao];
