# Modelo de dados: bloco FIN, arquivo morto e ensaio da migração do movimento (proposta)

Conversa "03c – Financeiro e ensaio da migração", 16/11/2026. Base: seção 3.2 do CLAUDE.md (lançamento único, aprovado em 14/11/2026), pedidos do Celso de 16/11/2026 (itens 8, 9 e 10), `CAD`/`BANCO` já criados e o movimento do Access (`legado/dados_brutos/F Movimento Contas.csv`, 102.230 linhas).

> **Situação: APROVADA pelo Celso em 17/11/2026.** Tabelas criadas e homologadas no LOCAL (pacote 03c). Migração (seção 4): em andamento.

## 1. Como o Access grava o dinheiro (achados de 16/11/2026, a confirmar com o Celso)

O Access usa **lançamento dobrado** com três contas "de enchimento" (`1 Creditos`, `2 Debitos`, `3 Pagto em Lote`) além das contas reais (bancos, caixas, permuta) e da `9 N/A`.

| Situação | Como aparece no Access | Quantidade |
|---|---|---:|
| **Conta a pagar paga em lote** (Bankline) | títulos na conta `3` (débito, por fornecedor, com vencimento, `PagamentoLote = True`) + **1 débito no banco** pelo total (parceiro N/A) + **1 crédito na conta `1`** por título (contrapartida), todos com o mesmo `MovPagtoLote` | 10.436 grupos |
| **Parcela de venda** | 1 débito na conta `2` (cliente, `ClassificacaoVenda = A`) + 1 crédito no banco (`C`), ligados por `LinkVenda` | 3.894 pares |
| **Parcela de venda ainda a receber** | o mesmo par, com `Confirmado = False` e **sem data de pagamento** | 749 pares (vencimentos até 2030) |
| **Conta a pagar em aberto** | débito direto no banco com `Efetuado = False` | ~320 |
| **Conta `N/A`** | 12.830 linhas (2012 em diante), quase todas `Efetuado`/`Confirmado` | a entender |

Significado dos campos (**confirmado pelo Celso em 17/11/2026**):
- `Confirmado` = **pago/recebido de fato**.
- `Efetuado` = pago, **aguardando a compensação do cheque** (quando for o caso).
- `Integracao` = o lançamento faz parte da **contabilidade, do custo e do banco**.
- `SomenteIntegracao` = só para os **relatórios da contabilidade**, sem mexer no banco nem no custo.
- Conta `N/A` = controle de **caixinha** (dinheiro que entrou/saiu no escritório), sem precisar informar empresa ou pessoa.
- `CodAtribui*`/`CodAnterior*` = troca automática de parceiro/empresa na baixa de venda (leitura do VBA).

## 2. Tabelas propostas do `FIN` (modelo da seção 3.2)

### 2.1 `FIN.Lancamento` (o documento: uma obrigação)
`ID_LANCAMENTO` (BIGINT), `TIPO` (`P` pagar / `R` receber), `ID_EMPRESA`, `ID_CENTRO_CUSTO`, `ID_PESSOA`, `ID_PLANO_CONTA` (só nível 3), `DOCUMENTO` (nº nota/recibo), `DT_EMISSAO`, `DT_COMPETENCIA` (mês a que pertence, item 14 da 3.3), `HISTORICO`, `OBSERVACAO`, `VALOR_TOTAL`, `ORIGEM` (`MANUAL`, `VENDA`, `COMPRA`, `MEDICAO`, `RECORRENTE`, `MIGRACAO`...), `ID_ORIGEM` (registro que gerou), `ID_LOTE` (`SIS.Lote`), `SITUACAO` (`ATIVO` / `CANCELADO`), `PREVISAO` (BIT: previsão sem documento, para o fluxo projetado), `INTEGRACAO` (`COMPLETA` = contabilidade + custo + banco; `SO_CONTABIL` = só relatórios da contabilidade, sem banco nem custo; `NENHUMA`), padrão vindo do plano de contas (equivale ao `Integracao`/`SomenteIntegracao` do Access), `ID_PEDIDO_COMPRA` (quando vem de Compras, dá acesso ao pedido, à cotação e ao histórico de preços; FK ligada quando o `COMP` existir), `CODIGO_ACCESS` + `ORIGEM_ACCESS`, auditoria.

### 2.2 `FIN.Parcela` (um vencimento)
`ID_PARCELA` (BIGINT), `ID_LANCAMENTO`, `NUMERO`, `QTD_PARCELAS`, `DT_VENCIMENTO`, `VALOR`, `VALOR_BAIXADO` (mantido por trigger de delta, regra 9), `SALDO` (calculado: valor − baixado), `SITUACAO` (`ABERTA` / `PARCIAL` / `PAGA` / `CANCELADA`), `ID_CONTA_PREVISTA` (conta bancária prevista, para o fluxo de caixa), `ID_LOTE`, auditoria. Índices: vencimento + situação, pessoa, centro de custo, lote (agenda e busca).

### 2.3 `FIN.Baixa` (cada pagamento/recebimento)
`ID_BAIXA` (BIGINT), `ID_PARCELA`, `DT_PAGAMENTO`, `ID_CONTA` (`BANCO.Conta`), `FORMA` (`PIX`, `BOLETO`, `TED`, `DINHEIRO`, `PERMUTA`, `CHEQUE`...), **um campo para cada valor** (pedido 8): `VALOR_PRINCIPAL`, `JUROS`, `MULTA`, `CORRECAO`, `DESCONTO`, `ABATIMENTO`, `TARIFA`, `RETENCAO` (total; detalhe por imposto na v1.x), `VALOR_LIQUIDO` (calculado), `ID_BAIXA_ESTORNADA` (estorno = baixa negativa que aponta para a original; nada é apagado), `COMPENSADO` (BIT) + `DT_COMPENSACAO` (cheque pago mas ainda não compensado = baixa feita e não compensada: é o "Efetuado sem Confirmado" do Access), `ID_LOTE`, auditoria. Regime de caixa (a contabilidade da CMJ): o relatório contábil usa a data de pagamento/compensação.

### 2.4 `BANCO.Movimento` (o que passa na conta)
`ID_MOVIMENTO` (BIGINT), `ID_CONTA`, `DT_MOVIMENTO`, `VALOR` (positivo entra, negativo sai), `TIPO` (`BAIXA`, `TRANSFERENCIA`, `TARIFA`, `AJUSTE`, `SALDO_INICIAL`), `ID_BAIXA` (quando vem de baixa), `ID_TRANSFERENCIA`, `HISTORICO`, `CONCILIADO` + `ID_EXTRATO` (conciliação, fase 4), `ID_LOTE`, auditoria. **Pagamento em lote** (Bankline de várias contas) = várias baixas com **um só movimento bancário** pelo total, todas no mesmo lote: é assim que o extrato bate.

### 2.5 Apoio
- `FIN.Transferencia` (entre contas e entre empresas do grupo: gera dois movimentos).
- `FIN.Historico_Padrao` (os 80 históricos do Access, revistos).
- `FIN.Mes_Fechado` (empresa + mês; só bloqueia lançamento em conta `CONTABIL`, pedido 10).
- Rateio (item 9 da 3.3) e recorrentes (item 8): **fica para a fase 4**, sem tabela agora.
- **Caixinha** (a conta `N/A` do Access): conta `CAIXA` no `BANCO.Conta`; pessoa opcional no lançamento de caixinha; a empresa vem do centro de custo padrão da conta (o lançamento nunca fica sem empresa, para o relatório por empresa fechar).
- **Material** (pedido do Celso, 17/11/2026): o preço pago em cada compra fica no **módulo de Compras** (histórico de preços); o lançamento do financeiro só aponta para o **pedido de compra**, e dali se chega ao material aprovado, à cotação e às comparações de preço. Os dados do `Material`/`MovMaterial` do Access migram como **histórico de preços** (consulta), quando o `COMP` for criado.

### 2.6 Extrato OFX e conciliação (respostas do Celso, 17/11/2026; telas na fase 4)
- O Sicredi fornece o OFX; a CMJ já guarda os arquivos **numa pasta por empresa**. Campo novo `PASTA_OFX` em `CAD.Empresa` (caminho editável no cadastro). Como uma empresa pode ter mais de uma conta, o sistema identifica a conta pelo **banco/agência/conta que vem dentro do arquivo**, não pelo nome do arquivo.
- Mês **sem movimento** não gera OFX (acontece com uma empresa): falta de arquivo não é erro.
- Cada arquivo lido fica registrado (`BANCO.Extrato_Arquivo`: nome, hash, conta, período) para **não importar duas vezes**; linhas em `BANCO.Extrato_Linha` (data, valor, documento, histórico, `FITID` único por conta).
- **Conciliação automática**: o sistema casa extrato x `BANCO.Movimento` por valor + data (com tolerância de dias, parâmetro) + documento; o que casar fica conciliado. O que estiver no extrato e **não** estiver no sistema aparece numa lista na **tela de conciliação** para o usuário confirmar, escolhendo a conta do plano e o centro de custo, e o sistema **cria o lançamento já baixado** (tarifa, IOF, rendimento, PIX recebido...).
- Para o desenvolvimento: um OFX de exemplo na pasta do projeto no Google Drive (fora do Git: dados bancários).

## 3. Arquivo morto (decidido em 16/11/2026: só consulta)

- Tabela `FIN.Arquivo_Morto`: os 147.866 lançamentos de 2008-2019 **com os dados como eram**, já traduzidos para texto legível (empresa, obra, pessoa, conta, plano em 3 níveis, histórico, complemento, documento, débito, crédito, datas, situação) + os códigos do Access, para a busca e o "Exportar".
- Sem ligação (FK) com o modelo novo: o que mudar no cadastro novo não altera o passado. Busca por pessoa usa o nome gravado e, quando houver, o `ID_PESSOA` do de-para.
- Procedure só de leitura `FIN.FIN_Arquivo_Morto_Listar` (filtros, busca por parte do nome, paginação); tela na fase 4 sem incluir/alterar/excluir.

## 4. Ensaio da migração do movimento (repetível no servidor da CMJ)

**Corte decidido pelo Celso em 17/11/2026: migra para o modelo novo o movimento de 2018 em diante; o anterior a 2018 fica no arquivo morto, com os saldos.** Isso vale para as duas tabelas do Access (o `F Movimento Contas` tem linhas de 2017 e o `ArquivoMorto` tem linhas de 2018-2019). Proposta de regra:
- data de corte pela **data do movimento** (`DataMovto`) em 01/01/2018;
- o que for anterior a 2018 mas **ainda estiver em aberto** (não `Confirmado`) migra também para o modelo novo, para nenhum compromisso pendente sumir;
- cada conta bancária/caixa começa no sistema novo com **saldo inicial em 01/01/2018** = saldo do Access até 31/12/2017 (lançamento `SALDO_INICIAL`), conferido no relatório de conferência;
- o arquivo morto mostra também o **saldo por conta** na data do corte.

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

## 6. Perguntas ao Celso e respostas (17/11/2026)

1. **Sicredi**: **CNAB 400**; hoje os boletos são feitos no site do banco. Cooperativa 0217, conta 73623-5, beneficiário 55.73623, carteira Simples. (Detalhe e o que falta na seção 6 do CLAUDE.md.)
2. Campos do Access: respondido (seção 1).
3. Conta `N/A`: caixinha, sem empresa ou pessoa obrigatória (seção 2.5).
4. Histórico: **2018 em diante** no modelo novo; antes de 2018 no arquivo morto, com saldos (seção 4).
5. `Material`/`MovMaterial`: continua, integrado ao módulo de Compras (seção 2.5). `PadraoRelatorio`: sem resposta; proposta: não migra.
6. OFX: **sim**, pasta por empresa (seção 2.6). Contabilidade: **regime de caixa**.

Confirmados em 17/11/2026: data de corte pela data do movimento + pendências anteriores a 2018 migrando (seção 4); `PadraoRelatorio` não migra.
