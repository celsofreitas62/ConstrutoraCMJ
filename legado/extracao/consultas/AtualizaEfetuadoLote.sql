-- Consulta: AtualizaEfetuadoLote
-- Tipo: Atualização (48)
-- Parâmetros: Formulários![F Movimento Contas]!Efetuado (Texto), Formulários![F Movimento Contas]!MovPagtoLote (Texto), Formulários![F Movimento Contas]!DataVencto (Texto)
-- Descrição: 

UPDATE [F Movimento Contas] SET [F Movimento Contas].Efetuado = Formulários![F Movimento Contas]!Efetuado
WHERE ((([F Movimento Contas].MovPagtoLote)=Formulários![F Movimento Contas]!MovPagtoLote) And (([F Movimento Contas].NumMovimento)<>Formulários![F Movimento Contas]!MovPagtoLote) And (([F Movimento Contas].DataVencto)=Formulários![F Movimento Contas]!DataVencto));
