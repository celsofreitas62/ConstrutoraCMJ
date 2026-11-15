-- Consulta: EfetuaReajusteParceiros
-- Tipo: Atualização (48)
-- Parâmetros: [Formulários]![ReajusteParceiros]![EmpresaSelecionada] (Texto)
-- Descrição: 

UPDATE [F Movimento Contas] SET [F Movimento Contas].ValorReajustado = 0
WHERE ((([F Movimento Contas].CodAtribuiEmpresa)=[Formulários]![ReajusteParceiros]![EmpresaSelecionada]));
