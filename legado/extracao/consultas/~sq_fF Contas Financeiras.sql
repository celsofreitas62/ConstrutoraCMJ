-- Consulta: ~sq_fF Contas Financeiras
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Contas Financeiras].[Master], [F Contas Financeiras].[CodigoConta], [F Contas Financeiras].[Descricao], [F Contas Financeiras].[Numero Conta], [F Contas Financeiras].[Limite Credito], [F Contas Financeiras].[Tipo Conta], [F Contas Financeiras].[Conciliacao], [F Contas Financeiras].[NaoListarResumo], [F Contas Financeiras].[Observacao]
FROM [F Tipos Conta Financeira] INNER JOIN [F Contas Financeiras] ON [F Tipos Conta Financeira].[CodTipoConta]=[F Contas Financeiras].[Tipo Conta]
WHERE ((([F Contas Financeiras].[Master])=False));
