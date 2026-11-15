-- Consulta: ~sq_cRelatorio Custos Empresa~sq_cPlano2 Subformulário
-- Tipo: Seleção (0)
-- Parâmetros: Formulários![Relatorio Custos Empresa]!SemFiltro (Texto)
-- Descrição: 

SELECT Plano2.DescricaoPlano2, Plano2.RelatorioCustos, Plano2.Master
FROM Plano2
WHERE (((Plano2.Master)=False) And ((Plano2.Ativo)=IIf(Formulários![Relatorio Custos Empresa]!SemFiltro=False,True,False)));
