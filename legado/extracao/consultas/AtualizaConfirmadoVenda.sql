-- Consulta: AtualizaConfirmadoVenda
-- Tipo: Atualização (48)
-- Parâmetros: Formulários![F Movimento Contas]!Confirmado (Texto), Formulários![F Movimento Contas]!DataPagto (Texto), Formulários![F Movimento Contas]!LinkVenda (Texto), Formulários![F Movimento Contas]!NumMovimento (Texto), Formulários![F Movimento Contas]!DataVencto (Texto)
-- Descrição: 

UPDATE [F Movimento Contas] SET [F Movimento Contas].Confirmado = Formulários![F Movimento Contas]!Confirmado, [F Movimento Contas].DataPagto = Formulários![F Movimento Contas]!DataPagto
WHERE ((([F Movimento Contas].LinkVenda)=Formulários![F Movimento Contas]!LinkVenda) And (([F Movimento Contas].NumMovimento)<>Formulários![F Movimento Contas]!NumMovimento) And (([F Movimento Contas].DataVencto)=Formulários![F Movimento Contas]!DataVencto));
