-- Consulta: LimparCamposDoCheque
-- Tipo: Atualização (48)
-- Descrição: 

UPDATE [Arquivo Sistema] SET [Arquivo Sistema].EmpresaDoCheque = Null, [Arquivo Sistema].Favorecido = Null, [Arquivo Sistema].FavorecidoCopiaCheque = Null, [Arquivo Sistema].NomeBanco = Null, [Arquivo Sistema].NumeroCheque = Null, [Arquivo Sistema].ContaCorrente = Null, [Arquivo Sistema].DataDoCheque = Date(), [Arquivo Sistema].ValorDoCheque = 0
WHERE ((([Arquivo Sistema].IDSistema)=1));
