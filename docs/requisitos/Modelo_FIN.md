# Modelo de dados: bloco FIN, arquivo morto e ensaio da migração do movimento (proposta)

Conversa "03c – Financeiro e ensaio da migração", 16/11/2026. Base: seção 3.2 do CLAUDE.md (lançamento único, aprovado em 14/11/2026), pedidos do Celso de 16/11/2026 (itens 8, 9 e 10), `CAD`/`BANCO` já criados e o movimento do Access (`legado/dados_brutos/F Movimento Contas.csv`, 102.230 linhas).

> **Situação: PROPOSTA, aguardando a aprovação do Celso.** Nada foi criado no banco.

## 1. Como o Access grava o dinheiro (achados de 16/11/2026, a confirmar com o Celso)

O Access usa **lançamento dobrado** com três contas "de enchimento" (`1 Creditos`, `2 Debitos`, `3 Pagto em Lote`) além das contas reais (bancos, caixas, permuta) e da `9 N/A`.

| Situação | Como aparece no Access | Quantidade |
|---|---|---:|
| **Conta a pagar paga em lote** (Bankline) | títulos na conta `3` (débito, por fornecedor, com vencimento, `PagamentoLote = True`) + **1 débito no banco** pelo total (parceiro N/A) + **1 crédito na conta `1`** por título (contrapartida), todos com o mesmo `MovPagtoLote` | 10.436 grupos |
| **Parcela de venda** | 1 débito na conta `2` (cliente, `ClassificacaoVenda = A`) + 1 crédito no banco (`C`), ligados por `LinkVenda` | 3.894 pares |
| **Parcela de venda ainda a receber** | o mesmo par, com `Confirmado = False` e **sem data de pagamento** | 749 pares (vencimentos até 2030) |
| **Conta a pagar em aberto** | débito direto no banco com `Efetuado = False` | ~320 |
| **Conta `N/A`** | 12.830 linhas (2012 em diante), quase todas `Efetuado`/`Confirmado` | a entender |

Leitura provisória dos campos: `Confirmado` = pago/recebido de fato (marca `Efetuado` e preenche `DataPagto`); `Efetuado` = lançamento valendo (sai do "previsto"); `Integracao`/`SomenteIntegracao` = entra no relatório contábil / só contábil, sem dinheiro; `CodAtribui*`/`CodAnterior*` = troca automática de parceiro/empresa na baixa de venda. **Precisa da confirmação do Celso antes de virar regra de migração** (seção 6).

## 2. Tabelas propostas do `FIN` (modelo da seção 3.2)

### 2.1 `FIN.Lancamento` (o documento: uma obrigação)
`ID_LANCAMENTO` (BIGINT), `TIPO` (`P` pagar / `R` receber), `ID_EMPRESA`, `ID_CENTRO_CUSTO`, `ID_PESSOA`, `ID_PLANO_CONTA` (só nível 3), `DOCUMENTO` (nº nota/recibo), `DT_EMISSAO`, `DT_COMPETENCIA` (mês a que pertence, item 14 da 3.3), `HISTORICO`, `OBSERVACAO`, `VALOR_TOTAL`, `ORIGEM` (`MANUAL`, `VENDA`, `COMPRA`, `MEDICAO`, `RECORRENTE`, `MIGRACAO`...), `ID_ORIGEM` (registro que gerou), `ID_LOTE` (`SIS.Lote`), `SITUACAO` (`ATIVO` / `CANCELADO`), `PREVISAO` (BIT: previsão sem documento, para o fluxo projetado), `CONTABIL` (entra no relatório contábil; padrão vem do plano de contas), `CODIGO_ACCESS` + `ORIGEM_ACCESS`, auditoria.

### 2.2 `FIN.Parcela` (um vencimento)
`ID_PARCELA` (BIGINT), `ID_LANCAMENTO`, `NUMERO`, `QTD_PARCELAS`, `DT_VENCIMENTO`, `VALOR`, `VALOR_BAIXADO` (mantido por trigger de delta, regra 9), `SALDO` (calculado: valor − baixado), `SITUACAO` (`ABERTA` / `PARCIAL` / `PAGA` / `CANCELADA`), `ID_CONTA_PREVISTA` (conta bancária prevista, para o fluxo de caixa), `ID_LOTE`, auditoria. Índices: vencimento + situação, pessoa, centro de custo, lote (agenda e busca).

### 2.3 `FIN.Baixa` (cada pagamento/recebimento)
`ID_BAIXA` (BIGINT), `ID_PARCELA`, `DT_PAGAMENTO`, `ID_CONTA` (`BANCO.Conta`), `FORMA` (`PIX`, `BOLETO`, `TED`, `DINHEIRO`, `PERMUTA`, `CHEQUE`...), **um campo para cada valor** (pedido 8): `VALOR_PRINCIPAL`, `JUROS`, `MULTA`, `CORRECAO`, `DESCONTO`, `ABATIMENTO`, `TARIFA`, `RETENCAO` (total; detalhe por imposto na v1.x), `VALOR_LIQUIDO` (calculado), `ID_BAIXA_ESTORNADA` (estorno = baixa negativa que aponta para a original; nada é apagado), `ID_LOTE`, auditoria.

### 2.4 `BANCO.Movimento` (o que passa na conta)
`ID_MOVIMENTO` (BIGINT), `ID_CONTA`, `DT_MOVIMENTO`, `VALOR` (positivo entra, negativo sai), `TIPO` (`BAIXA`, `TRANSFERENCIA`, `TARIFA`, `AJUSTE`, `SALDO_INICIAL`), `ID_BAIXA` (quando vem de baixa), `ID_TRANSFERENCIA`, `HISTORICO`, `CONCILIADO` + `ID_EXTRATO` (conciliação, fase 4), `ID_LOTE`, auditoria. **Pagamento em lote** (Bankline de várias contas) = várias baixas com **um só movimento bancário** pelo total, todas no mesmo lote: é assim que o extrato bate.

### 2.5 Apoio
- `FIN.Transferencia` (entre contas e entre empresas do grupo: gera dois movimentos).
- `FIN.Historico_Padrao` (os 80 históricos do Access, revistos).
- `FIN.Mes_Fechado` (empresa + mês; só bloqueia lançamento em conta `CONTABIL`, pedido 10).
- Rateio (item 9 da 3.3) e recorrentes (item 8): **fica para a fase 4**, sem tabela agora.

## 3. Arquivo morto (decidido em 16/11/2026: só consulta)

- Tabela `FIN.Arquivo_Morto`: os 147.866 lançamentos de 2008-2019 **com os dados como eram**, já traduzidos para texto legível (empresa, obra, pessoa, conta, plano em 3 níveis, histórico, complemento, documento, débito, crédito, datas, situação) + os códigos do Access, para a busca e o "Exportar".
- Sem ligação (FK) com o modelo novo: o que mudar no cadastro novo não altera o passado. Busca por pessoa usa o nome gravado e, quando houver, o `ID_PESSOA` do de-para.
- Procedure só de leitura `FIN.FIN_Arquivo_Morto_Listar` (filtros, busca por parte do nome, paginação); tela na fase 4 sem incluir/alterar/excluir.

## 4. Ensaio da migração do movimento (repetível no servidor da CMJ)

1. **Extração**: o PowerShell da 01b (`Extrair_Access.ps1`) passa a gerar só os CSV que a migração usa, com data/hora da extração.
2. **Carga crua** em `MIG.*` (uma tabela por tabela do Access, tudo texto, `BULK INSERT`), apagando a carga anterior.
3. **De-para**: `MIG.Depara_Pessoa`, `MIG.Depara_Empresa_CC` (a tabela de classificação que o Celso confere uma vez), `MIG.Depara_Conta`, `MIG.Depara_Plano`.
4. **Transformação** (procedures `MIG.MIG_*_Processar`, tudo-ou-nada, com `SIS.Log_Passo`):
   - grupos de **pagamento em lote** → 1 lançamento + parcela + baixa por título, 1 movimento bancário pelo total;
   - pares de **venda** → título a receber (cliente, venda) + baixa quando `Confirmado`; aberto quando não;
   - lançamento avulso no banco → lançamento + parcela + baixa;
   - conta `N/A` e casos estranhos (débito e crédito na mesma linha, valor zero/negativo, datas fora de faixa) → regra própria ou **lista de rejeitados** para o Celso decidir a regra (nunca correção à mão).
5. **Conferência** (`MIG.MIG_Conferencia_Listar`): quantidade e soma por ano, empresa, conta bancária, pessoa e situação, Access x sistema novo; saldo de cada conta bancária no fim de cada mês igual nos dois.
6. Rodar o ensaio no `SISTEMACMJ_LOCAL` quantas vezes for preciso até a conferência bater.

## 5. Ordem de trabalho proposta para a 3c

1. Celso responde às perguntas da seção 6 (pode ser amanhã).
2. Tabelas do `FIN` + `BANCO.Movimento` + arquivo morto (SQL, testado no LOCAL).
3. `MIG`: carga crua + de-paras + transformação do movimento + conferência.
4. Rodar o ensaio, mostrar a conferência ao Celso, ajustar as regras.
5. Procedures de tela do `FIN` ficam para a fase 4, junto com as telas.

## 6. Perguntas para o Celso

1. **Sicredi** (lembrete obrigatório): CNAB 240 ou 400? Quem emite o boleto? Cooperativa, posto, beneficiário, carteira.
2. Confirmar a leitura dos campos `Confirmado`, `Efetuado`, `Integracao` e `SomenteIntegracao` (seção 1).
3. Para que a CMJ usa a conta **`N/A`** (12.830 lançamentos)? Previsão, lançamento só contábil, outra coisa?
4. Quanto do histórico do movimento atual migra para o modelo novo: tudo (2009 em diante) ou só a partir de um ano, com o anterior indo para o arquivo morto e um **saldo inicial** por conta?
5. `Material`/`MovMaterial` e `PadraoRelatorio` continuam? (pendência da 01b)
6. Perguntas da seção 3.3 do CLAUDE.md que pesam aqui: a CMJ tem extrato **OFX**? A contabilidade quer caixa ou competência?
