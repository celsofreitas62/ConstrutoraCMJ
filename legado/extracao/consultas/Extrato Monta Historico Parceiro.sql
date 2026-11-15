-- Consulta: Extrato Monta Historico Parceiro
-- Tipo: Atualização (48)
-- Descrição: 

UPDATE (Historico INNER JOIN [F Temp Movimento Contas] ON Historico.CodHistorico=[F Temp Movimento Contas].Historico) INNER JOIN EmpVinculada ON [F Temp Movimento Contas].CodigoVinculada=EmpVinculada.CodigoVinculada SET [F Temp Movimento Contas].HistoricoExtrato = IIf([F Temp Movimento Contas]![CodigoVinculada]<>1,([Historico]![Descricao] & " " & [F Temp Movimento Contas]![NumDoc] & " " & [F Temp Movimento Contas]![Complemento] & " - " & [EmpVinculada]![NomeVinculada]),([Historico]![Descricao] & " " & [F Temp Movimento Contas]![NumDoc] & " " & [F Temp Movimento Contas]![Complemento]));
