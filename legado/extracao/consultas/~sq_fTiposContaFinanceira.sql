-- Consulta: ~sq_fTiposContaFinanceira
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Tipos Conta Financeira].[CodTipoConta], [F Tipos Conta Financeira].[Descricao], [F Tipos Conta Financeira].[ListaNoResumo], [F Tipos Conta Financeira].[OrdemNoResumo], [F Tipos Conta Financeira].[ListaAgenda], [F Tipos Conta Financeira].[Master]
FROM [F Tipos Conta Financeira]
WHERE ((([F Tipos Conta Financeira].[Master])=False));
