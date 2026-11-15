-- Consulta: Cadastro EmpMaster
-- Tipo: Seleção (0)
-- Descrição: 

SELECT EmpMaster.CodigoMaster, EmpMaster.NomeMaster, EmpMaster.Master, EmpMaster.CNPJ
FROM EmpMaster
WHERE (((EmpMaster.CodigoMaster)<>1) AND ((EmpMaster.Master)=False));
