-- Consulta: ArquivoMorto Excluir Mov
-- Tipo: Exclusão (32)
-- Parâmetros: Formulários!ArquivoMorto!DataIniRel (Texto), Formulários!ArquivoMorto!DataFimRel (Texto)
-- Descrição: 

DELETE [F Movimento Contas].Confirmado, [F Movimento Contas].DataPagto
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].Confirmado)=True) And (([F Movimento Contas].DataPagto)>=Formulários!ArquivoMorto!DataIniRel And ([F Movimento Contas].DataPagto)<=Formulários!ArquivoMorto!DataFimRel));
