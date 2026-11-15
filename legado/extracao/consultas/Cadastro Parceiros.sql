-- Consulta: Cadastro Parceiros
-- Tipo: Seleção (0)
-- Descrição: 

SELECT Parceiros.*, Parceiros.Master
FROM Parceiros
WHERE (((Parceiros.Master)=False));
