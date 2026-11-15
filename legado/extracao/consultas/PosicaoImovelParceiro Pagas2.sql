-- Consulta: PosicaoImovelParceiro Pagas2
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários!SelecionaEmpresaPosicaoCompradores2!CodigoVinculada (Texto), Formulários!SelecionaEmpresaPosicaoCompradores2!AnoDesejado (Texto)
-- Descrição: 

INSERT INTO PosicaoImovelParceiro ( EmpVinculada, CodigoParceiro, Imovel, ValorCredito, ValorDebito )
SELECT [F Movimento Contas].CodAtribuiEmpresa, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodImovel, [F Movimento Contas].ValorDebito AS Credito, [F Movimento Contas].ValorDebito
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].CodAtribuiEmpresa)=Formulários!SelecionaEmpresaPosicaoCompradores2!CodigoVinculada) And (([F Movimento Contas].CodImovel)<>1) And ((Year([DataPagto]))=Formulários!SelecionaEmpresaPosicaoCompradores2!AnoDesejado));
