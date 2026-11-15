-- Consulta: ~sq_rF Contas Financeiras
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Tipos Conta Financeira].[Descricao], [F Contas Financeiras].[Descricao], [F Contas Financeiras].[Numero Conta], [F Contas Financeiras].[Limite Credito]
FROM [F Tipos Conta Financeira] INNER JOIN [F Contas Financeiras] ON [F Tipos Conta Financeira].[CodTipoConta]=[F Contas Financeiras].[Tipo Conta];
