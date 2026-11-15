-- Consulta: ExcluirPadraoRelatorioCPagar
-- Tipo: Exclusão (32)
-- Descrição: 

DELETE [F Movimento Contas].*, [F Movimento Contas].PadraoRelatorio
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].PadraoRelatorio)=1));
