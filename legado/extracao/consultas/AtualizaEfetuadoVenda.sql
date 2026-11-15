-- Consulta: AtualizaEfetuadoVenda
-- Tipo: Atualização (48)
-- Parâmetros: Formulários![F Movimento Contas]!Efetuado (Texto), Formulários![F Movimento Contas]!AgrupadorVenda (Texto), Formulários![F Movimento Contas]!NumMovimento (Texto), Formulários![Menu Principal]!AgendaFinanceraMenu.Form!DataVencto (Texto)
-- Descrição: 

UPDATE [F Movimento Contas] SET [F Movimento Contas].Efetuado = Formulários![F Movimento Contas]!Efetuado
WHERE ((([F Movimento Contas].AgrupadorVenda)=Formulários![F Movimento Contas]!AgrupadorVenda) And (([F Movimento Contas].NumMovimento)<>Formulários![F Movimento Contas]!NumMovimento) And (([F Movimento Contas].DataVencto)=Formulários![Menu Principal]!AgendaFinanceraMenu.Form!DataVencto));
