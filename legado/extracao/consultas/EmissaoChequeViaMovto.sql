-- Consulta: EmissaoChequeViaMovto
-- Tipo: Atualização (48)
-- Parâmetros: Formulários![F Movimento Contas]!NomeVinculada (Texto), Formulários![F Movimento Contas]!NomeBanco (Texto), Formulários![F Movimento Contas]!NumDoc (Texto), Formulários![F Movimento Contas]![Numero Conta] (Texto), Formulários![F Movimento Contas]!DataPagto (Texto), Formulários![F Movimento Contas]!ValorDebito (Texto)
-- Descrição: 

UPDATE [Arquivo Sistema] SET [Arquivo Sistema].Favorecido = "Por favor, digite o nome do favorecido ou deixe em branco", [Arquivo Sistema].FavorecidoCopiaCheque = "Digite o nome do favorecido ou deixe em branco", [Arquivo Sistema].EmpresaDoCheque = Formulários![F Movimento Contas]!NomeVinculada, [Arquivo Sistema].NomeBanco = Formulários![F Movimento Contas]!NomeBanco, [Arquivo Sistema].NumeroCheque = Formulários![F Movimento Contas]!NumDoc, [Arquivo Sistema].ContaCorrente = Formulários![F Movimento Contas]![Numero Conta], [Arquivo Sistema].DataDoCheque = Formulários![F Movimento Contas]!DataPagto, [Arquivo Sistema].ValorDoCheque = Formulários![F Movimento Contas]!ValorDebito
WHERE ((([Arquivo Sistema].IDSistema)=1));
