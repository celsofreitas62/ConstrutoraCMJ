-- Consulta: F Mov Contas Extrato Monta Historico
-- Tipo: Atualização (48)
-- Descrição: 

UPDATE (Historico INNER JOIN [F Temp Movimento Contas] ON Historico.CodHistorico=[F Temp Movimento Contas].Historico) INNER JOIN Parceiros ON [F Temp Movimento Contas].CodigoParceiro=Parceiros.CodigoParceiro SET [F Temp Movimento Contas].HistoricoExtrato = IIf([F Temp Movimento Contas]![CodigoParceiro]<>1,([Historico]![Descricao] & " " & [F Temp Movimento Contas]![NumDoc] & " " & [F Temp Movimento Contas]![Complemento] & " " & [Parceiros]![NomeParceiro]),([Historico]![Descricao] & " " & [F Temp Movimento Contas]![NumDoc] & " " & [F Temp Movimento Contas]![Complemento]));
