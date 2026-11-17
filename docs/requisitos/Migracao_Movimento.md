# Ensaio da migração do movimento: o que os dados mostram e as regras propostas

Conversa "03c – Financeiro e ensaio da migração", 17/11/2026. Fonte: `legado/dados_brutos/F Movimento Contas.csv` (102.230 linhas) e `ArquivoMorto.csv` (147.866), análise feita pelo Claude com os scripts da pasta de trabalho dele (resultados abaixo, repetíveis no SQL do `MIG`).

> **Situação: regras APROVADAS pelo Celso em 17/11/2026 (seção 7): corte em 01/01/2022.** Primeira rodada do ensaio feita em 17/11/2026 no LOCAL (seção 6): carga crua, classificação e arquivo morto. Os lançamentos de 2018 em diante ainda não foram gerados no `FIN`.

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

## 6. Primeira rodada do ensaio (17/11/2026, SISTEMACMJ_LOCAL)

Rodado pelo Claude no SSMS: pacote `sql/pacotes/03c_mig_LOCAL.sql` (schema `MIG`, não vai para o MASTER) e `sql/local/03c_Ensaio_Migracao_LOCAL.sql` (1 min 54 s).

| Passo | Resultado |
|---|---|
| Carga crua dos 11 CSV | todos OK; movimento 102.230 e arquivo morto 147.866 linhas, iguais ao Access |
| Classificação (`MIG.Movimento`) | 250.096 linhas, nenhuma perdida: **sistema novo 79.575 linhas / 30.348 documentos**; **arquivo morto 128.831** (109.474 de movimento + os resumos "Sd Acum" até 01/01/2018); duplicadas fora 29.349; resumos de 2019 e 2020 fora 12.335; casos de data 6 |
| Arquivo morto (`FIN.Arquivo_Morto`) | **128.831 linhas** carregadas (106.854 do ArquivoMorto + 21.977 do movimento atual), de 2008 a 01/01/2018, todas com pessoa e conta em texto; saldos do Access em 31/12/2017 em `FIN.Arquivo_Morto_Saldo` (só referência) |
| Padrões de 2018 em diante | iguais aos da análise (seção 3): lote 9.542, caixinha saída 6.732, crédito solto 3.785, venda 3.712, banco saída 2.246, débito solto 1.824, caixinha entrada 1.009, banco entrada 648 |

Para conferir: `EXEC MIG.MIG_Conferencia_Listar;` e a tela "Arquivo morto" (fase 4).

**Próximo passo** (depois das respostas da seção 5): de-paras (pessoas, empresas/obras e centros de custo, contas, plano), carga dos cadastros do Access no `CAD`/`BANCO` e transformação dos 30.348 documentos em lançamento, parcela, baixa e movimento bancário, com a conferência de totais por ano, empresa, conta e pessoa.

## 7. Decisões do Celso (17/11/2026) e segunda rodada

**Decisões:**
1. **Corte em 01/01/2022** (a CMJ analisou e preferiu; o Claude recomendou: de 2022 em diante os dados não têm os vícios do arquivamento do Access, que vão só até 2020). **Contrato de venda vai inteiro**: se tem alguma parcela de 2022 em diante, todas as parcelas dele migram (25 contratos atravessavam o corte).
2. **Saldo inicial** de cada conta = **saldo do extrato do banco no dia da virada**; o movimento migrado é histórico (relatórios), sem recompor saldo antigo.
3. **Lançamentos soltos nas contas de sistema** (explicação do Celso): crédito na conta "Créditos" = **saque do banco que entrou no caixa contábil**; débito na conta "Débitos" = **valor recebido no dia que entrou no banco**. Todos os lançamentos integrados passam pelo caixa contábil. Regra proposta pelo Claude para a transformação: cada empresa ganha a conta **"Caixa contábil"** (tipo CAIXA); o crédito solto vira **transferência banco → caixa contábil** e o débito solto **transferência caixa contábil → banco**, usando a conta bancária padrão da obra/empresa no Access (`FinanceiraPadrao`); sem conta identificável, vai para a lista de casos.
4. **Pendentes antigos** (39 de 2009-2017 e os 6 não confirmados de 2018-2021): ficam só no arquivo morto.

**Segunda rodada** (`MIG_Movimento_Preparar` v1.1, `@Corte = '2022-01-01'`), 17/11/2026: 250.096 linhas, nenhuma perdida.

| Destino | Linhas | Documentos |
|---|---:|---:|
| Sistema novo (2022 em diante + contratos inteiros) | 50.251 | 19.204 |
| Arquivo morto (até 31/12/2021, com os resumos "Sd Acum") | 170.490 | 51.782 |
| Cópias repetidas (fora) | 29.349 | |
| Casos de data | 6 | 6 |

Arquivo morto carregado: **170.490 linhas** (118.481 do ArquivoMorto + 52.009 do movimento atual), de 2008 a 31/12/2021. Padrões do sistema novo: lote 5.513, caixinha saída 3.647, venda 3.212, crédito solto 2.570, banco saída 1.495, débito solto 1.279, caixinha entrada 583, banco entrada 389.

## 8. Respostas da CMJ para a 03c2 (17/11/2026)

Documento `CashBookCMJ/Migracao_Perguntas_CMJ_03c2.docx`, respondido pela Renata.

**Propostas aprovadas** (as três):
1. Receitas e despesas lançadas no plano antigo desde 2022 ganham de-para para o plano novo (receitas no grupo novo de Receitas, com nome genérico); a lista vai para conferência.
2. Parcelas de venda entram agora como contas a receber do cliente, com obra e unidade no texto; a ligação com o imóvel e o contrato do Access fica guardada para a fase 5.
3. Créditos e débitos soltos: conta "Caixa contábil" por empresa e transferências com a conta bancária padrão da obra/empresa.

**Classificação das obras e empresas usadas desde 2022:**

| Access | Fica no SisCMJ |
|---|---|
| 1 - Construtora Marcilio Judice | empresa (Construtora) + centro administrativo |
| 4 - Holding Judice e Filhos | empresa (Holding) |
| 58 - Ilha das Galés, 61 - Allegro (Judice e Daher), 62 - Square (MJ Incorporadora), 63 - Maui, 67 - Orion, 68 - Opera, 69 - Music | empresa do grupo (SPE) + obra |
| 59 - Edifício La Sante | empresa do grupo: **Edifício Comercial La Sante SPE** + obra |
| Construtora e La Sante - 01321-7 | controle do custo/receita da obra La Sante **até sair a documentação da SPE**: centro de custo da Construtora ligado à obra La Sante |
| Jd. Carolina - Obra Diogo e Outros (62) | **obra particular dos proprietários** (centro de custo tipo PARTICULAR) |
| Marco Aurelio | **despesa particular de toda a família** (centro de custo tipo PARTICULAR) |
| Ronaldo Dellaroli | **estudo de viabilidade, obra não executada** (centro de custo inativo) |
| 65 - Indiara e 66 - Paladium (CADAP) | obra por administração; CADAP como cliente (pessoa) |
| N/A | não vira empresa |

As demais, sem movimento desde 2022, entram como centros de custo inativos, sem tratamento diferente.

**SPEs**: todas têm como sócios, na abertura, a Construtora CMJ, Diogo Marcilio Judice, Marco Aurelio Judice e Danielle Marcilio Judice Daher; o terreno é negociado com terceiros e a SPE é aberta para o empreendimento. Todas são empresas do grupo.

**CNPJs informados** (dígitos conferidos): Construtora Marcilio Judice Sociedade Empresária Ltda 25.686.528/0001-97; Judice e Filhos Administração de Bens Ltda 27.546.995/0001-47; Marcilio Judice Incorporadora SPE Ltda (Maui) 36.451.082/0001-38; Orion Incorporadora SPE Ltda 52.095.394/0001-02; Opera Residences 56.304.064/0001-30; Music Incorporadora SPE Ltda 68.542.803/0001-01. **A verificar**: Ilha das Galès, Judice e Daher, MJ Incorporadora (Square) e La Sante.

**Opera e o RET**: com a tributação pelo RET, a Receita criou um segundo CNPJ, **56.304.064/0002-11**, usado nas notas de compras e serviços e no DDA do Sicredi; os boletos de cobrança aos clientes saem no **/0001-30**.

**Reajuste das parcelas de venda**: o contrato traz a data-base da tabela de preços (ex.: compra em nov/2026 com tabela atualizada até out/2026: data-base out/2026). Índice: **INCC-M da FGV**, coluna "Número Índice desde Jan/1993 (Dez/1992 = 1,00)", do mês anterior à assinatura. Reajuste **mensal**; a CMJ calcula o acumulado à mão porque a FGV demora a publicar: acumulado do mês = acumulado do mês anterior × (1 + variação do mês ÷ 100). Fator aplicado às parcelas que vencem no mês = índice do mês anterior ÷ índice da data-base (ex.: parcelas de out/2026 com data-base jun/2026 = índice de set/2026 ÷ índice de jun/2026). Observação do Claude: no exemplo, 4.502,5477 ÷ 4.426,0236 = **1,0173** (e não 1,1360, como estava no documento). Boletos: **juros de 1% ao mês pro rata die e multa de 2%** sobre a parcela.
