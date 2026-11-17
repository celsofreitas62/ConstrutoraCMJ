# Ensaio da migração do movimento: o que os dados mostram e as regras propostas

Conversa "03c – Financeiro e ensaio da migração", 17/11/2026. Fonte: `legado/dados_brutos/F Movimento Contas.csv` (102.230 linhas) e `ArquivoMorto.csv` (147.866), análise feita pelo Claude com os scripts da pasta de trabalho dele (resultados abaixo, repetíveis no SQL do `MIG`).

> **Situação: PROPOSTA, aguardando as respostas do Celso (seção 5).** Nenhum dado foi carregado no sistema novo.

## 1. Três descobertas que mudam o ensaio

1. **Linhas de "saldo acumulado" (42.647).** A cada virada de ano, a rotina de arquivamento do Access criou linhas de resumo: `NumDoc = "Sd Acum"`, histórico 7, complemento `01/01/AAAA a 31/12/AAAA`, datadas de 01/01 do ano seguinte, uma por pessoa/empresa/conta. **Não são movimento**: são o saldo transportado. Migrar como lançamento duplicaria todos os valores.
2. **Movimento repetido nas duas tabelas (18.404 linhas).** O arquivamento de 2017 e 2018 **copiou** as linhas para o `ArquivoMorto` sem apagar do movimento atual (2017: 15.569 iguais; 2018: 13.596 iguais, contando os resumos). Fica uma só cópia (a do movimento atual).
3. **O número do lote atravessa as duas tabelas.** `MovPagtoLote` guarda o número original do movimento, que o arquivamento manteve; um mesmo pagamento em lote pode estar metade em cada tabela (2.953 casos). O agrupamento é feito pelo número do lote, juntando as duas tabelas.

Sem os resumos e as cópias, sobram **189.045 linhas**: **109.474 antes de 2018** (arquivo morto) e **79.571 de 2018 em diante**, que formam **30.345 documentos** no sistema novo.

## 2. Saldos bancários do Access não fecham

A soma das linhas de cada conta bancária dá saldos impossíveis (ex.: Itaú Construtora com **-2,97 milhões** em 31/12/2017 pelos próprios resumos do Access). O Access não registrava todo o dinheiro que entrava na conta do banco (boa parte dos recebimentos fica na conta de sistema "Créditos"). **Conclusão: o saldo inicial das contas não pode vir do Access.** Proposta na pergunta 1 (seção 5).

## 3. Os padrões do movimento de 2018 em diante (30.345 documentos)

| Padrão no Access | Documentos | Linhas | Valor (R$) | Como fica no sistema novo (proposta) |
|---|---:|---:|---:|---|
| **Pagamento em lote** (títulos na conta "Pagto em Lote" + contrapartidas em "Créditos" + 1 saída no banco) | 9.542 | 52.917 | 174,5 mi | cada título = lançamento a pagar (fornecedor, plano, empresa, vencimento) + parcela + baixa; a saída do banco = **um** movimento bancário pelo total; as contrapartidas não migram (só conferem: soma dos títulos = saída do banco) |
| **Parcela de venda** (conta "Débitos" + entrada no banco) | 3.711 | 7.422 | 115,8 mi | lançamento a receber do cliente + parcela; confirmado = baixa + movimento no banco; não confirmado = parcela em aberto |
| **Caixinha, saída** (conta N/A, débito) | 6.730 | 6.730 | 36,9 mi | despesa paga pela conta Caixa da empresa (pessoa opcional) |
| **Caixinha, entrada** (conta N/A, crédito) | 1.009 | 1.009 | 21,6 mi | receita recebida pela conta Caixa |
| **Pagamento direto no banco** | 2.247 | 2.247 | 15,6 mi | lançamento a pagar + baixa + movimento |
| **Recebimento direto no banco** | 648 | 648 | 13,1 mi | lançamento a receber + baixa + movimento |
| **Crédito solto na conta "Créditos"** (ex.: "Suprimento de caixa") | 3.785 | 3.785 | 21,4 mi | **a confirmar** (pergunta 2) |
| **Débito solto na conta "Débitos"** (ex.: "Banco Itaú", muitos só contábeis) | 1.824 | 1.824 | 55,1 mi | **a confirmar** (pergunta 2) |
| Pagamento em lote feito pela caixinha | 207 | 1.322 | 10,2 mi | como o lote, com a baixa na conta Caixa |
| Outros (lotes incompletos, valor zero, débito e crédito na mesma linha...) | ~640 | ~1.100 | ~4 mi | lista de casos para o Celso decidir a regra |

Os valores e quantidades são do Access; o relatório de conferência do ensaio mostra os mesmos números lado a lado com o sistema novo.

## 4. Regras que não dependem de resposta

- **Corte**: data do documento = data da saída/entrada no banco (ou da caixinha); antes de 01/01/2018 vai para o arquivo morto. Pagamento em lote nunca é dividido entre os dois lados do corte (99 lotes atravessam o ano).
- **Arquivo morto**: as 109.474 linhas anteriores a 2018, como eram, com os textos legíveis (empresa, obra, pessoa, conta, plano), mais os resumos "Sd Acum" de 01/01/2018 como saldos por pessoa e conta (só consulta).
- **Datas inválidas** (15 linhas, ex.: ano 2202, 8202, 0202): usa a data de vencimento quando ela é válida; 6 linhas com as duas datas inválidas vão para a lista de casos.
- **Pendentes antes de 2018**: 39 linhas não confirmadas, de 2009 a 2017, todas em contas de sistema; vão para o arquivo morto e para a lista de casos (pergunta 3).
- Tudo em `MIG`, repetível no servidor da CMJ com o `.mdb` do dia: carga crua, de-paras (pessoas, empresas/obras, contas, plano), transformação e conferência. Nada é corrigido à mão.

## 5. Perguntas para o Celso

1. **Saldo inicial das contas**: como o Access não tem o saldo real dos bancos, proposta: o sistema novo começa cada conta com o **saldo do extrato do banco no dia da virada** (fase 8); o movimento de 2018 em diante entra como histórico (relatórios por empresa, obra, fornecedor, cliente), sem pretender recompor o saldo antigo. Concorda? Ou prefere informar o saldo real de cada conta em 31/12/2017?
2. **Lançamentos soltos nas contas de sistema** ("Créditos": 3.785, ex. "Suprimento de caixa"; "Débitos": 1.824, ex. "Banco Itaú"): o que a CMJ registrava com eles? Proposta: os marcados "Somente integração" entram como lançamento só contábil (sem banco e sem custo); os demais vão para a lista de casos.
3. **Os 39 pendentes antigos (2009-2017)**: podem ficar só no arquivo morto (não viram contas em aberto no sistema novo)?
