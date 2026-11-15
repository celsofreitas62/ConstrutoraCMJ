-- Consulta: ~sq_cF Contas Financeiras~sq_cTipo Conta
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Tipos Conta Financeira].[CodTipoConta], [F Tipos Conta Financeira].[Descricao], [F Tipos Conta Financeira].[Master]
FROM [F Tipos Conta Financeira]
WHERE ((([F Tipos Conta Financeira].[Master])=False));
