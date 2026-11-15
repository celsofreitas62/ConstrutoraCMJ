-- Consulta: Gerar Temp Pagto Lote no Movto
-- Tipo: Acréscimo (64)
-- Descrição: 

INSERT INTO [F Movimento Contas] ( CodImovel, Plano2, Plano1, Efetuado, EmpVinculada, CodigoParceiro, CodHistorico, DataMovto, ValorDebito, ValorCredito, Complemento, Plano3, ContaFinanceira, Confirmado, Integracao, DataPagto, DataVencto, MovPagtoLote, Observacao, NumDoc )
SELECT "1" AS Imovel, Plano2.Plano2, Plano1.Plano1, TempLoteMovContas.Efetuado, TempLoteMovContas.EmpVinculada, TempLoteMovContas.CodigoParceiro, TempLoteMovContas.CodHistorico, TempLoteMovContas.DataMovto, TempLoteMovContas.ValorDebito, TempLoteMovContas.ValorCredito, TempLoteMovContas.Complemento, TempLoteMovContas.Plano3, TempLoteMovContas.ContaFinanceira, TempLoteMovContas.Confirmado, TempLoteMovContas.Integracao, TempLoteMovContas.DataPagto, TempLoteMovContas.DataVencto, TempLoteMovContas.MovPagtoLote, TempLoteMovContas.Observacao, TempLoteMovContas.NumDoc
FROM (Plano1 INNER JOIN Plano2 ON Plano1.Plano1=Plano2.Plano1) INNER JOIN (TempLoteMovContas INNER JOIN Plano3 ON TempLoteMovContas.Plano3=Plano3.Plano3) ON Plano2.Plano2=Plano3.Plano2;
