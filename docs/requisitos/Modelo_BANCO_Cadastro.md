# Modelo de dados: cadastro do bloco BANCO (proposta, parte 03a)

Conversa "03 – Modelo de dados", 16/11/2026. Só o **cadastro** (bancos e contas); extrato, movimento e conciliação vêm com o `FIN`.

> **Situação: APROVADA pelo Celso em 16/11/2026** (parte 03a).

## 1. O Access (`F Contas Financeiras`, 27 registros)

- Contas do Itaú e do Sicredi **de cada empresa/SPE** (Construtora, Orion, Opera, Maui, Music, Holding...), caixas em dinheiro por empresa e uma conta "Permuta".
- Contas de enchimento do lançamento dobrado (`Creditos`, `Debitos`, `Pagto em Lote`) e `N/A` (usada em 2.160 lançamentos desde 2024, provavelmente previsões sem conta): **não migram como conta**.
- Agência e conta num campo só, escritas de jeitos diferentes (`0217 73623-5`, `25629-5`).

## 2. Tabelas propostas

### `BANCO.Banco` (lista de bancos)
`ID_BANCO`, `CODIGO` (COMPE, 3 dígitos: 001, 104, 237, 341, 748...), `ISPB` (8 dígitos, usado no PIX), `NOME`, `ATIVO`. Carga inicial com os principais bancos; o administrador acrescenta outros. Usada também nos dados bancários das pessoas (TED).

### `BANCO.Conta` (contas da empresa)
`ID_CONTA`, `ID_EMPRESA` (titular, FK `CAD.Empresa`), `DESCRICAO` (apelido, ex.: "Sicredi Orion"), `TIPO` (`CORRENTE` / `POUPANCA` / `APLICACAO` / `CAIXA` / `PERMUTA`), `ID_BANCO` (vazio para caixa e permuta), `AGENCIA`, `AGENCIA_DV`, `NUMERO`, `NUMERO_DV`, `LIMITE_CREDITO`, `SALDO_INICIAL` + `DT_SALDO_INICIAL` (saldo de abertura), `CONCILIA` (entra na conciliação), `MOSTRA_SALDO` (aparece no resumo de saldos e no fluxo de caixa), `CONTA_CONTABIL_REF`, `ORDEM`, `ATIVO`, `CODIGO_ACCESS`, auditoria.
- Caixa em dinheiro = conta do tipo `CAIXA`. Permuta = conta do tipo `PERMUTA` (quitação sem dinheiro).
- Os dados de cobrança do Sicredi (cooperativa, posto, código do beneficiário, carteira) ficam no `COBR`, ligados à conta.
- `CAD.Empresa` e `CAD.Centro_Custo` apontam para a conta padrão (FK criada depois das duas tabelas).
