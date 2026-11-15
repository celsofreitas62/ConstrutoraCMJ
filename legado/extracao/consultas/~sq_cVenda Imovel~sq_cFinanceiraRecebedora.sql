-- Consulta: ~sq_cVenda Imovel~sq_cFinanceiraRecebedora
-- Tipo: Seleção (0)
-- Descrição: 

SELECT [F Contas Financeiras].[CodigoConta], [F Contas Financeiras].[Descricao]
FROM [F Contas Financeiras]
WHERE ((([F Contas Financeiras].[Descricao])<>"Creditos" And ([F Contas Financeiras].[Descricao])<>"Debitos" And ([F Contas Financeiras].[Descricao])<>"Caixa" And ([F Contas Financeiras].[Descricao])<>"Pagto em Lote"));
