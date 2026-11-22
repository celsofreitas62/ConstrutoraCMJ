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

## 9. Parte B: transformação do movimento (aprovada pelo Celso em 18/11/2026)

Regras aprovadas (proposta de 18/11/2026): pagamento em lote = cada título vira conta a pagar paga e a saída do banco vira um movimento pelo total, ligado a todos os pagamentos (lote do Access = lote do sistema); parcela de venda = conta a receber do cliente (recebida: baixa + entrada no banco; não recebida: em aberto; ligação com o contrato guardada para a fase 5); caixinha = conta Caixa da empresa (empresa sem caixa ganha um); pagamento/recebimento direto = lançamento já baixado com movimento; crédito/débito solto = transferência banco x Caixa contábil; "Somente integração" = lançamento só contábil; "Efetuado" sem "Confirmado" = baixa não compensada; obra, empresa, plano e pessoa pelos de-paras da parte A (imóvel próprio pelo centro do imóvel; linha "N/A" usa a obra da outra linha do documento); repetível (apaga só o que veio da migração, com prévia); conferência de totais por ano, empresa, conta, pessoa e plano.

**Casos que não se encaixam** (decisão do Celso, 18/11/2026): além da lista, **uma tela no sistema** para ver e corrigir os casos **linha a linha**, de fácil visualização: cada caso mostra os dados do Access e o motivo; o usuário escolhe o que fazer (corrigir obra, pessoa, conta, plano, data ou valor; mandar para o arquivo morto; ignorar com motivo). A correção fica guardada pelo código do Access e é aplicada em toda nova rodada da migração (o processo continua repetível), até o dia da virada. Acesso: os dois administradores.

## 10. Parte B: primeira rodada (18/11/2026, SISTEMACMJ_LOCAL)

Pacote `03c2b_mig_LOCAL`, script `sql/local/03c2b_Migracao_Movimento_LOCAL.sql` (prévia, gravação e conferência). Objetos: `MIG.Tabelas_Transformacao.sql` (casos, correções por caso e por linha, destino de cada linha, de-para das vendas), `MIG.MIG_Movimento_Transformar` e `MIG.MIG_Movimento_Conferencia_Listar`.

**Desempenho**: a primeira tentativa de gravação passou de 20 minutos e foi cancelada. Causa: as triggers de auditoria buscavam de novo cada linha no `inserted`/`deleted` (sem índice), o que fica quadrático em carga grande. `SIS.SIS_Auditoria_Trigger_Gerar` v1.1 monta a foto JSON direto da linha (mesmo conteúdo na `SIS.Auditoria`); vai para o MASTER. Com isso a gravação inteira levou cerca de **1 minuto**. Ficaram 2 triggers no formato antigo (conferir quais e gerar de novo).

**Gravado**: 18.593 lançamentos a pagar (R$ 78,9 mi) e 4.268 a receber (R$ 79,6 mi); 1.085 parcelas em aberto (R$ 13,8 mi); 21.776 baixas; 12.099 movimentos de banco/caixa; 3.914 transferências; 5.571 lotes do Access; **312 casos** (R$ 8,5 mi, 1,6% dos documentos) para a tela de correção.

**Conferência**: total de títulos por ano e tipo, Access × sistema, **diferença zero em todos os anos (2018 a 2030)**. Saldos por conta: as diferenças grandes das contas Sicredi de Opera, Orion, Music e do Itaú Maui são as **parcelas de venda ainda não pagas**, que no Access já estavam lançadas no banco sem confirmação e no sistema ficam em aberto (bate com o "em aberto" de cada empresa). O restante (cerca de R$ 220 mil na Construtora, menos de R$ 2 mil nos caixas) vem de títulos a pagar em aberto e dos 312 casos; conferir conta a conta na tela de casos.

**Próximo**: tela de casos (linha a linha, os dois administradores), arquivo morto recebendo os casos marcados para ele, segunda rodada para provar que repete igual, e conferência com a Renata.

**Segunda rodada (18/11/2026)**: números idênticos aos da primeira (gravação repetível); triggers de auditoria todas no formato novo.

## 11. Tela "Casos da migração" (aprovada pelo Celso em 18/11/2026)

Menu **Sistema › Migração › Casos da migração** (`sis/migracao-casos.html`, item `MIG_CASOS`, ações VER e ALTERAR; os dois administradores). Só existe onde a migração roda; na virada o item é desabilitado. Ajuda: `ajuda/sis-migracao-casos.html`.

- **Resumo**: etiquetas por situação (Pendente, Em correção, Resolvido, Ignorado, Arquivo morto) e por motivo, clicáveis; filtros por busca, empresa e ano; **Exportar planilha** (CSV para o Excel).
- **Documento aberto**: as linhas do Access numa grade editável (ignorar a linha, conta, obra, pessoa, plano, datas, débito, crédito, confirmado). Campo alterado fica destacado com o valor do Access embaixo; totais de débito e crédito na hora.
- **Ações**: Gravar correção (motivo obrigatório; grava e confere na hora se o documento passou a se encaixar), Conferir (sem gravar), Ignorar documento, Mandar para o arquivo morto (motivo obrigatório), Desfazer correções. Confirmação antes de cada uma; Ctrl+S grava, Esc fecha.
- **Banco**: `MIG.Caso` ganhou `REGRA_ATUAL` e `MOTIVO_ORIGINAL` e passa a guardar também os documentos corrigidos; correções em `MIG.Caso_Correcao` (decisão) e `MIG.Caso_Correcao_Linha` (só o que difere do Access; data vazia = 01/01/1900), com auditoria. Procedures `MIG_Caso_Listar`, `_Obter`, `_Opcoes`, `_Gravar`, `_Conferir`; `MIG_Movimento_Transformar` v1.1 com `@Unidade` (classifica um documento só). API: `Endpoints/MigracaoEndpoints.cs` (`/api/mig/...`). Teste: `sql/testes/MIG/03c2c_Homologacao_MIG.sql`.
- **Arquivo morto**: `MIG_Arquivo_Morto_Processar` v1.2 recebe os documentos marcados "Arquivo morto" na tela, com o motivo no início da observação; o script `03c2b_Migracao_Movimento_LOCAL.sql` roda o arquivo morto antes da transformação. Teste 03c2c 36/0.
- **Topo e menu fixos** no computador (pedido do Celso, `PADRAO_TELAS` item 16); motivo virou lista de escolha nos filtros (eram etiquetas demais).
- **Guia para a Renata**: `CashBookCMJ/Correcao_Casos_Migracao_CMJ_03c2.docx` (casos por motivo, o que costuma ser e o que fazer, espaço para resposta). Observação: os 54 "Documento com valor zero" têm valores negativos no Access (estornos); se forem muitos do mesmo jeito, dá para virar regra.

## 12. Access em uso até a virada (decisão do Celso, 18/11/2026)

- O Access continua em uso; a Renata corrige os casos desde já. Correções guardadas pelo número do Access e reaplicadas a cada nova cópia do Access (sugestão: a cada 15 dias).
- **Aviso "Revisar"**: a correção guarda a impressão digital do Access (`HASH_ACCESS`: da linha, ou do documento inteiro nas decisões, `MIG.fn_MIG_Hash_Unidade`). Se a linha ou o documento mudar ou sumir do Access, a rodada marca `MIG.Caso.REVISAR` e a tela mostra a situação "Revisar" com o aviso; gravar de novo (ou repetir a decisão) atualiza a impressão e tira o aviso. Documento corrigido que sumiu do Access continua na tela (`REGRA_ATUAL = APAGADO`).
- **Instalação (3d)**: botão "Baixar correções" da tela (`/api/mig/casos/correcoes.sql`, `MIG.MIG_Caso_Correcao_Exportar`) gera o .sql que substitui as correções do servidor da CMJ pelas do notebook (com usuários, datas e impressões); rodar no servidor depois do pacote 03c2b e antes da migração. **Incluir no roteiro da 3d.**
- Guia da Renata atualizado (seção 7 "Até a instalação final"). Teste 03c2c v1.2: 43/0.

## 13. Selecionar todos e ações em lote (pedido do Celso, 18/11/2026)

- Lista: caixinha em cada documento e "selecionar todos" no cabeçalho (todos os da lista com os filtros; trocar filtro desmarca tudo). Barra de lote com quantos estão marcados e o valor, um motivo só e os botões Conferir, Ignorar, Arquivo morto, Desfazer e Desmarcar; confirmação antes de gravar. `MIG.MIG_Caso_Lote_Gravar` (até 1.000 por vez) e `MIG_Caso_Conferir`/`MIG_Movimento_Transformar` com `@Unidades` (lista JSON). API: `/api/mig/casos/lote` e `/conferir-lote`.
- Documento aberto: "Ignorar" e "Confirmado" no cabeçalho da grade marcam ou desmarcam todas as linhas.

## 14. Troca de lote pela tela (pedido do Celso para a Renata, 18/11/2026)

- Coluna **Lote** na grade do documento: número do lote do Access, editável. Outro número move a linha para aquele lote (precisa existir no Access); 0 tira a linha do lote (vira avulso, ou venda se tiver ligação de venda). Guardado em `MIG.Caso_Correcao_Linha.LOTE` (NULL = mantém).
- `MIG_Movimento_Transformar` v1.4: o documento da linha passa a ser o do lote novo; o padrão de contas é refeito nos documentos que ganharam ou perderam linha; a conferência de um documento inclui o lote de destino (depois do pedido), e a tela diz como ele ficou. A linha continua aparecendo no documento de origem (onde foi corrigida).

- **Lote novo da migração** (pedido da Renata, 19/11/2026): número de 900001 em diante não precisa existir no Access; serve para separar linhas de um lote num lote só delas (a tela indica o próximo número livre). O documento novo pode ser aberto, corrigido, ignorado ou mandado ao arquivo morto (`MIG.vw_MIG_Linha_Unidade`, `MIG.fn_MIG_Linhas_Documento`). Desempenho: índice (ORIGEM, NUM) em `MIG.Movimento`. Teste 03c2c 60/0.

## 15. Casos antes e depois da virada (decisões do Celso, 19/11/2026)

1. **Regra fixa dos saldos**: o saldo inicial de cada conta (banco, caixa) é o saldo do extrato no dia da virada; **movimento com data anterior ao saldo inicial da conta nunca altera o saldo** (é histórico, para relatórios e consultas). Vale para o movimento migrado e para casos incluídos depois.
2. **Antes da virada**: resolver só os casos **com valor em aberto** (parcela ou conta ainda não paga), senão faltaria cobrança ou pagamento no sistema novo. Filtro "Valor em aberto" na tela e aviso na lista (`MIG_Caso_Listar` v1.3, coluna EM_ABERTO).
3. **Depois da virada**: os demais casos a Renata resolve com calma no servidor. A tela continua habilitada e ganha **"Migrar casos resolvidos"** (só o administrador geral): inclui só os documentos resolvidos, sem refazer a migração, sempre como histórico. **Entra no roteiro da instalação e da virada (fases 3d e 8).**
4. Arquivo morto (até 2021) não é afetado pelas correções, salvo documento mandado para lá pela tela.

## 16. Terceira rodada com o Access de 20/11/2026 (conversa 03f, 22/11/2026)

Extração nova pelo executor (pedido `extrair_access.pedido`), respostas do 3º documento aplicadas (`Migracao_Cadastros.md`, seções 6 e 7) e a sequência completa no LOCAL: carga, preparação (corte 01/01/2022), arquivo morto, cadastros (2 passadas, repetível), transformação e conferência. Rodada repetida do zero com o mesmo resultado, linha por linha.

| | 2ª rodada (Access de 14/11) | 3ª rodada (Access de 20/11) |
|---|---:|---:|
| Linhas do `F Movimento Contas` | 101.612 | 102.372 |
| Títulos: diferença Access × sistema, todos os anos | 0,00 | 0,00 |
| Casos pendentes na tela | 141 | 139 |
| Casos com valor em aberto | 2 | 2 (os mesmos) |

- **Correções da Renata preservadas**: 123 documentos mandados para o arquivo morto, 46 ignorados, 1 com lote trocado, 12 linhas corrigidas; nenhum aviso "Revisar". O arquivo morto tem 170.886 linhas: as 170.490 até 2021 mais as 396 dos documentos mandados para lá pela tela.
- **Saíram da lista** 2 casos: o lote 277730 (é o "lote 27730 do Vanderlei" das notas anteriores; corrigido no Access, agora fecha) e a venda 13514 (Chaves, Loja 3 Orion), que passou a entrar como conta a receber em aberto.
- **Achados para a CMJ** (documento `CashBookCMJ/Conferencia_Migracao_CMJ_03f.docx`):
  1. ao corrigir o lote 277730, o pagamento de R$ 8.331,00 do Vanderlei de 04/10/2024 ficou **duas vezes** no Access (nº 277727, antigo, e nº 310158, novo);
  2. a venda 13514 tem a data do movimento em **30/04/2057** (vencimento 30/04/2027): na conferência por ano aparece o ano 2057;
  3. saída de R$ 85.000,00 da Holding (19/11/2026, não confirmada) entra como paga e não compensada (regra aprovada), por isso a diferença de 85.000 na conferência do Sicredi Holding;
  4. Sala 113 ainda sem confirmação;
  5. os 2 casos com valor em aberto (nº 308074 e 308076, recebimentos parciais da Opera sem banco) continuam pendentes e precisam ser resolvidos antes da virada.
- **Ajuste no LOCAL**: o `MIG_Movimento_Preparar` v1.2 (índice ORIGEM+NUM, de 19/11) só estava no MASTER de migração, não no LOCAL; aplicado e a rodada refeita. As triggers de auditoria das correções são geradas e diferem só no texto gerado.
