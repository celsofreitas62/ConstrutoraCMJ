-- Consulta: Cadastro Historico
-- Tipo: Seleção (0)
-- Descrição: 

SELECT Historico.CodHistorico, Historico.Descricao, Historico.Master
FROM Historico
WHERE (((Historico.Master)=False));
