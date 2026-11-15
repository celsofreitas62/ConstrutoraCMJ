-- Consulta: AtualizaEfetuadoVendaAgenda
-- Tipo: Atualização (48)
-- Parâmetros: Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!Efetuado (Texto), Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!LinkVenda (Texto), Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!NumMovimento (Texto), [F Movimento Contas] (Texto)
-- Descrição: 

UPDATE [F Movimento Contas] SET [F Movimento Contas].Efetuado = Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!Efetuado
WHERE ((([F Movimento Contas].LinkVenda)=Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!LinkVenda) And (([F Movimento Contas].NumMovimento)<>Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!NumMovimento) And (([F Movimento Contas].DataVencto)=[F Movimento Contas]));
