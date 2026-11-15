-- Consulta: Cadastro Plano Contas
-- Tipo: Seleção (0)
-- Descrição: 

SELECT Plano1.Plano1, Plano1.DescricaoPlano1, Plano1.Master
FROM Plano1
WHERE (((Plano1.Master)=False));
