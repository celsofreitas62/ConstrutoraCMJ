-- Consulta: EmissaoChequeViaFinan
-- Tipo: Atualização (48)
-- Parâmetros: Formulários![Pagto Lote Header Finan]!Movimento.Formulário![Numero Conta] (Texto), Formulários![Pagto Lote Header Finan]!Movimento.Formulário!NomeVinculada (Texto), Formulários![Pagto Lote Header Finan]!Movimento.Formulário!FinanceiraDescricao (Texto), Formulários![Pagto Lote Header Finan]!Movimento.Formulário!NumDoc (Texto), Formulários![Pagto Lote Header Finan]!DataParaPagamento (Texto), Formulários![Pagto Lote Header Finan]!Movimento.Formulário!ValorDebito (Texto)
-- Descrição: 

UPDATE [Arquivo Sistema] SET [Arquivo Sistema].Favorecido = Null, [Arquivo Sistema].FavorecidoCopiaCheque = Null, [Arquivo Sistema].ContaCorrente = Formulários![Pagto Lote Header Finan]!Movimento.Formulário![Numero Conta], [Arquivo Sistema].EmpresaDoCheque = Formulários![Pagto Lote Header Finan]!Movimento.Formulário!NomeVinculada, [Arquivo Sistema].NomeBanco = Formulários![Pagto Lote Header Finan]!Movimento.Formulário!FinanceiraDescricao, [Arquivo Sistema].NumeroCheque = Formulários![Pagto Lote Header Finan]!Movimento.Formulário!NumDoc, [Arquivo Sistema].DataDoCheque = Formulários![Pagto Lote Header Finan]!DataParaPagamento, [Arquivo Sistema].ValorDoCheque = Formulários![Pagto Lote Header Finan]!Movimento.Formulário!ValorDebito
WHERE ((([Arquivo Sistema].IDSistema)=1));
