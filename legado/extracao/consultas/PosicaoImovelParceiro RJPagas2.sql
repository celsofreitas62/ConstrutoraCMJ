-- Consulta: PosicaoImovelParceiro RJPagas2
-- Tipo: Acréscimo (64)
-- Parâmetros: Formulários!SelecionaEmpresaPosicaoCompradores2!CodigoVinculada (Texto), Formulários!SelecionaEmpresaPosicaoCompradores2!AnoDesejado (Texto)
-- Descrição: 

INSERT INTO PosicaoImovelParceiro ( EmpVinculada, CodigoParceiro, Imovel, ValorCredito, ValorDebito )
SELECT Imoveis.EmpVinculada, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodImovel, [F Movimento Contas].ValorDebito AS Credito, [F Movimento Contas].ValorDebito
FROM Plano3 INNER JOIN (Imoveis INNER JOIN [F Movimento Contas] ON Imoveis.CodImovel=[F Movimento Contas].CodImovel) ON Plano3.Plano3=[F Movimento Contas].Plano3
WHERE (((Imoveis.EmpVinculada)=Formulários!SelecionaEmpresaPosicaoCompradores2!CodigoVinculada) And (([F Movimento Contas].CodImovel)<>1) And ((Plano3.Plano3)=129) And ((Year([DataPagto]))=Formulários!SelecionaEmpresaPosicaoCompradores2!AnoDesejado));
