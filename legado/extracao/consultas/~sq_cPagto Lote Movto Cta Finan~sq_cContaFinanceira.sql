-- Consulta: ~sq_cPagto Lote Movto Cta Finan~sq_cContaFinanceira
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Contas Financeiras].[CodigoConta], [F Contas Financeiras].[Descricao], [F Tipos Conta Financeira].[Descricao]
FROM [F Tipos Conta Financeira] INNER JOIN [F Contas Financeiras] ON [F Tipos Conta Financeira].[CodTipoConta]=[F Contas Financeiras].[Tipo Conta]
ORDER BY [F Contas Financeiras].[Descricao];
