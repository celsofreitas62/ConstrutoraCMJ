-- Consulta: Plano2Consulta
-- Tipo: Seleção (0)
-- Parâmetros: [Formulários]![F Movimento Contas]![Plano1] (Texto)
-- Descrição: 

SELECT Plano2.Plano2, Plano2.DescricaoPlano2, Plano2.Plano1
FROM Plano2
WHERE (((Plano2.Plano1)=[Formulários]![F Movimento Contas]![Plano1]));
