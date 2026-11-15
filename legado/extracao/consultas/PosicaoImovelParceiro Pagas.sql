-- Consulta: PosicaoImovelParceiro Pagas
-- Tipo: Acréscimo (64)
-- Parâmetros: [Formulários]![SelecionaEmpresaPosicaoCompradores]![CodigoVinculada] (Texto)
-- Descrição: 

INSERT INTO PosicaoImovelParceiro ( EmpVinculada, CodigoParceiro, Imovel, ValorCredito, ValorDebito )
SELECT [F Movimento Contas].CodAtribuiEmpresa, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodImovel, [F Movimento Contas].ValorDebito AS Credito, [F Movimento Contas].ValorDebito
FROM [F Movimento Contas]
WHERE ((([F Movimento Contas].CodAtribuiEmpresa)=[Formulários]![SelecionaEmpresaPosicaoCompradores]![CodigoVinculada]) AND (([F Movimento Contas].CodImovel)<>1) AND (([F Movimento Contas].DataPagto) Is Not Null));
