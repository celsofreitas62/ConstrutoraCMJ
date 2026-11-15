-- Consulta: AtualizaEfetuadoLoteAgenda
-- Tipo: Atualização (48)
-- Parâmetros: Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!Efetuado (Texto), Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!MovPagtoLote (Texto), Formulários![Menu Principal]!AgendaFinanceraMenu.Form!DataVencto (Texto)
-- Descrição: 

UPDATE [F Movimento Contas] SET [F Movimento Contas].Efetuado = Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!Efetuado
WHERE ((([F Movimento Contas].MovPagtoLote)=Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!MovPagtoLote) And (([F Movimento Contas].NumMovimento)<>Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!MovPagtoLote) And (([F Movimento Contas].DataVencto)=Formulários![Menu Principal]!AgendaFinanceraMenu.Form!DataVencto));
