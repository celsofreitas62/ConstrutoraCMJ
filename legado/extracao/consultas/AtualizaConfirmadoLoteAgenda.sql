-- Consulta: AtualizaConfirmadoLoteAgenda
-- Tipo: Atualização (48)
-- Parâmetros: Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!Confirmado (Texto), Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!DataPagto (Texto), Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!MovPagtoLote (Texto), Formulários![Menu Principal]!AgendaFinanceraMenu.Form!DataVencto (Texto)
-- Descrição: 

UPDATE [F Movimento Contas] SET [F Movimento Contas].Confirmado = Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!Confirmado, [F Movimento Contas].DataPagto = Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!DataPagto
WHERE ((([F Movimento Contas].MovPagtoLote)=Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!MovPagtoLote) And (([F Movimento Contas].NumMovimento)<>Formulários![Menu Principal]!AgendaFinanceraMenu.Formulário!MovPagtoLote) And (([F Movimento Contas].DataVencto)=Formulários![Menu Principal]!AgendaFinanceraMenu.Form!DataVencto));
