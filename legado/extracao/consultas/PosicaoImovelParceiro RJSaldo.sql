-- Consulta: PosicaoImovelParceiro RJSaldo
-- Tipo: Acréscimo (64)
-- Parâmetros: [Formulários]![SelecionaEmpresaPosicaoCompradores]![CodigoVinculada] (Texto)
-- Descrição: 

INSERT INTO PosicaoImovelParceiro ( EmpVinculada, CodigoParceiro, Imovel, ValorDebito )
SELECT Imoveis.EmpVinculada, [F Movimento Contas].CodigoParceiro, [F Movimento Contas].CodImovel, [F Movimento Contas].ValorDebito
FROM Plano3 INNER JOIN (Imoveis INNER JOIN [F Movimento Contas] ON Imoveis.[CodImovel] = [F Movimento Contas].[CodImovel]) ON Plano3.[Plano3] = [F Movimento Contas].[Plano3]
WHERE (((Imoveis.EmpVinculada)=[Formulários]![SelecionaEmpresaPosicaoCompradores]![CodigoVinculada]) AND (([F Movimento Contas].CodImovel)<>1) AND ((Plano3.Plano3)=129) AND (([F Movimento Contas].DataPagto) Is Null));
