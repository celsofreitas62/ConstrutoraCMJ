# Plano de contas: análise do Access e proposta (pedido 11)

Conversa "03 – Modelo de dados", 16/11/2026. Fonte: `legado/dados_brutos/Plano1/2/3.csv` e os 250.096 movimentos (`F Movimento Contas` + `ArquivoMorto`).

> **Situação: proposta aguardando aprovação do Celso.** Nada foi criado no banco.

## 1. Como é no Access

- Três tabelas (`Plano1` 27, `Plano2` 64, `Plano3` 686) ligadas por relacionamento com cascata. O movimento grava **os três códigos** (`Plano1`, `Plano2`, `Plano3`); hoje estão todos coerentes com a árvore (0 divergências), mas nada impede que fiquem desalinhados.
- Campos: descrição (50), `Master` (registro do sistema), `OrdemCusto` (ordem no relatório de custos, só no nível 1), `RelatorioCustos` (marca/desmarca de filtro do relatório, nível 2) e `Ativo` (só no nível 2). Não há tipo (receita/despesa), marca contábil nem conta contábil de referência.

## 2. O que os dados mostram

| Achado | Números |
|---|---|
| **Dois planos convivendo** | antigo: `RECEITAS` (14 subgrupos) e `Despesas` (15 subgrupos, 431 contas), 2008 em diante; novo: grupos numerados `00 - PERMUTAS` a `18 - MEDIDAS COMPENSATÓRIAS` (19 grupos), desde 2015/2016. As despesas migraram para o novo plano a partir de 2020; o antigo ainda recebe ~150 lançamentos/ano (Despesas Particulares, Bens Imóveis, Pró-labore). As **receitas nunca ganharam versão nova**. |
| **Contrapartida do lançamento dobrado** | grupo `Movimento Contas` (contas `Creditos`/`Debitos`): **157.662 linhas (63% do movimento)**. É a segunda perna do débito/crédito; some no lançamento único. |
| Registros de enchimento | `sistema`: 2 grupos, 8 subgrupos, 25 contas, nunca usados. Em branco: 1 grupo, 1 subgrupo, 1 conta. |
| Contas órfãs (sem subgrupo) | 4 (`512`, `635`, `636`, `672`), nunca usadas. |
| Contas nunca usadas | 70 de 686. Só 150 contas tiveram uso a partir de 2025. |
| Duplicadas no mesmo subgrupo | `Bomba` (204/421), `Simples` (318/394), `16.1.1 - Canteiro de Obras` (635/636) |
| Número dentro da descrição | `"9.1.5 - Material Eletrico"`, com erros (`3..1.9`, `5.1.8  -`, `11.2.1 Devolução`), e contas sem número (Permutas). |
| Conta que é na verdade **um imóvel ou uma obra** | `Casa Danielle`, `Sala 110 La Sante`, `Aluguel - Allegro apto. 13`, subgrupo `Obra Terra Forte Café`. |
| Mesma conta em etapas diferentes | `Cimento` (6.1 e 8.1), `Material Consumo` (6.1, 8.1, 9.1): o nível 1 do plano novo funciona como **etapa da obra**. |
| Classificação discutível | `2.1.4 - Distribuição Lucros`, `2.1.9 - Amortizações`, `Juros Senior/Subordinada` como despesa administrativa; `Empréstimo` e `Distribuição de Lucros` como receita. |

## 3. Proposta para o sistema novo

**Estrutura** (três tabelas em `CAD`, alinhamento garantido por chave estrangeira):

| Tabela | Nível | Campos principais |
|---|---|---|
| `CAD.Plano_Grupo` | 1 | `NUMERO`, `DESCRICAO`, `TIPO` (`RECEITA` / `DESPESA` / `NAO_OPERACIONAL`), `CUSTO_OBRA` (S/N: entra no custo da obra e no painel), `ORDEM`, `ATIVO` |
| `CAD.Plano_Subgrupo` | 2 | `ID_PLANO_GRUPO` (FK), `NUMERO`, `DESCRICAO`, `ORDEM`, `ATIVO` |
| `CAD.Plano_Conta` | 3 | `ID_PLANO_SUBGRUPO` (FK), `NUMERO`, `DESCRICAO`, `CONTABIL` (S/N, pedido 10), `CONTA_CONTABIL_REF` (código na contabilidade), `ATIVO`, `CODIGO_ACCESS` (migração) |

- **Só o nível 3 recebe lançamento.** O lançamento (`FIN`, `COMP`, `OBRA`) guarda **apenas** `ID_PLANO_CONTA`; subgrupo e grupo vêm pela árvore, então nunca ficam desalinhados.
- **Código montado pelo sistema** (ex.: `09.1.05`) a partir do número de cada nível; a descrição fica sem número. Ordenação numérica correta (9 antes de 10).
- Mesmo nome permitido em subgrupos diferentes; repetido **no mesmo subgrupo**, não (`UQ`).
- Nada é apagado: desativar o grupo ou subgrupo esconde os filhos das listas de escolha; conta com lançamento não muda de subgrupo sem registro na auditoria.
- `CAD.vw_CAD_Plano_Conta`: a árvore achatada (grupo, subgrupo, conta, código, tipo) para telas, painel e relatórios.
- Transferência entre contas bancárias **não usa plano de contas** (é movimento do `BANCO`); o grupo `Movimento Contas` não migra.

**Limpeza na migração** (regras repetíveis, sem mexer à mão): não migram os registros `sistema`, em branco, órfãos e nunca usados; duplicadas viram uma só (de-para guardado em `MIG`); o número sai da descrição.

## 4. Decisões para o Celso

1. Aprovar a estrutura em três tabelas (seção 3).
2. **Plano antigo (2008-2020)**: (a) migrar como grupos **inativos** "Histórico", só para consulta, ou (b) montar um de-para das contas antigas para as novas, para o painel comparar anos?
3. **Receitas**: montar grupo novo numerado (ex.: `20 - RECEITAS`: Vendas de imóveis, Juros e multas recebidos, Permutas, Administração de obras, Aluguéis, Rendimentos, Reembolsos, Outras)?
4. **Não operacional**: criar grupo próprio para empréstimos (entrada e pagamento), amortizações, juros de financiamento, aportes e distribuição de lucros, tirando-os de receita e de despesa administrativa?
5. **Imóvel ou obra dentro do plano** (Casa Danielle, Sala 110, Allegro apto. 13, Obra Terra Forte Café): trocar por conta genérica ("Aluguéis recebidos", "Despesas de imóveis próprios") e identificar o imóvel pelo centro de custo/unidade?
6. **Orçamento da obra** (`OBRA`): orçar por grupo/subgrupo do plano (as etapas já estão nele) em vez de uma tabela de etapas separada?
7. Quais contas são **contábeis** (pedido 10) e o código na contabilidade: preencher depois, pela tela, com a contabilidade?
