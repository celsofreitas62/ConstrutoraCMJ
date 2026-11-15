-- Consulta: PosicaoImovelParceiro Saldo
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários!SelecionaEmpresaPosicaoCompradores!CodigoVinculada (Texto)
-- Descrição: 

INSERT INTO PosicaoImovelParceiro ( EmpVinculada, CodigoParceiro, Imovel, ValorDebito )
SELECT [F Movimento Contas].CodAtribuiEmpresa, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodImovel, [F Movimento Contas].ValorDebito
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].CodAtribuiEmpresa)=Formulários!SelecionaEmpresaPosicaoCompradores!CodigoVinculada) And (([F Movimento Contas].CodImovel)<>1) And (([F Movimento Contas].DataPagto) Is Null));
