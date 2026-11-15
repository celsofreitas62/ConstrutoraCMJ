-- Consulta: EmpVinculada Consulta
-- Tipo: Seleção (0)
-- Parâmetros: [EmpVinculada].Imoveis (Texto)
-- Descrição: 

SELECT EmpVinculada.NomeVinculada, EmpMaster.NomeMaster, EmpVinculada.CodigoVinculada, [EmpVinculada].Imoveis AS Expr1
FROM EmpMaster INNER JOIN EmpVinculada ON EmpMaster.CodigoMaster=EmpVinculada.CodigoMaster
WHERE (((EmpVinculada.NomeVinculada)<>"N/A" And (EmpVinculada.NomeVinculada)<>"sistema") And ((EmpVinculada.Imoveis)=True))
ORDER BY EmpVinculada.NomeVinculada;
