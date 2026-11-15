# Levantamento do Access legado (CashBook CMJ)

Conversa "01b – Levantamento do Access", 15/11/2026. Fonte: extração feita com `legado/ferramentas/Extrair_Access.ps1`.

> **Uso deste documento**: retrato do sistema antigo para entender os dados e as regras e planejar a migração. **Não é o modelo do sistema novo.** O SistemaCMJ será modernizado; nada do Access é copiado do jeito que foi feito sem o Celso confirmar.

Material bruto (para consulta detalhada):

| Arquivo | Conteúdo |
|---|---|
| `legado/extracao/tabelas.csv`, `campos.csv`, `indices.csv`, `relacoes.csv` | estrutura completa (base atual) |
| `legado/extracao/consultas/` + `consultas.csv` | SQL das 340 consultas |
| `legado/extracao/objetos/` + `objetos.csv` | 65 formulários, 39 relatórios, 2 macros, 1 módulo (com o VBA de cada tela) |
| `legado/extracao/vinculos.csv`, `referencias_vba.csv`, `resumo.txt` | vínculos do front-end, referências do VBA, resumo |
| `legado/extracao_CashBookCMJ_be_2015/` | estrutura da base antiga de 2015 |
| `legado/dados_brutos/` | dados em CSV (**fora do Git**, LGPD) |

## 1. Visão geral

- Access **Jet 4 (formato 2000/2003)**, dividido em front-end (`CashBookCMJ.mdb`: telas, consultas, VBA) e back-end (`CashBookCMJ_be.mdb`: dados). Título do aplicativo: "CashBook CMJ"; abre pelo formulário **Menu Principal** (menu do tipo *Switchboard*).
- O front-end procura os dados em `C:\CashBookCMJ\CashBookCMJ_be.mdb` (caminho fixo no vínculo das 23 tabelas).
- Dados desde **2008**. Última alteração de estrutura em 2021.
- **Atenção**: a contagem de registros que o Access informa está desatualizada (base sem compactar). Os números reais abaixo são os contados nos CSV.

## 2. Tabelas da base atual (back-end)

| Tabela | Registros | Para que serve | Bloco provável no sistema novo |
|---|---:|---|---|
| **F Movimento Contas** | **102.230** | movimento financeiro: cada linha é um débito ou crédito (a pagar/receber, pago/recebido, parcelas de venda, transferências) | `FIN` / `BANCO` (lançamento único, seção 3.2 do CLAUDE.md) |
| **ArquivoMorto** | **147.866** | movimentos antigos arquivados, mesma estrutura do anterior | junta com o movimento (decidido) |
| Parceiros | 1.437 | cadastro único de clientes (320), fornecedores (816) e funcionários (284) | `CAD.Pessoa` |
| EmpMaster | 35 | empresa "mãe" (grupo), com CNPJ | `CAD` empresa |
| EmpVinculada | 57 | empresas/obras/empreendimentos vinculados à master: % de administração, conta padrão, se tem imóvel em venda (16), se controla custos (37) | `CAD` empresa / `IMOB` empreendimento / `OBRA` |
| F Contas Financeiras | 27 | contas bancárias e caixas (Itaú e Sicredi por empreendimento, caixas, permuta, contas "de sistema") | `BANCO.Conta` |
| F Tipos Conta Financeira | 8 | tipo da conta: conta corrente, dinheiro, agrupadora, sistema, N/A | domínio fixo |
| Historico | 80 | histórico padrão do lançamento (Pgto Efetuado, NF N., Bankline, Salário, impostos...) | `FIN` tabela de apoio |
| Plano1 / Plano2 / Plano3 | 27 / 64 / 686 | plano de contas em 3 níveis (grupos de despesa de obra: mão de obra, fundação, acabamentos, impostos...) | `CAD.PlanoConta` |
| Imoveis | 389 | unidades à venda (casa, apartamento, loja): empresa, comprador (`Proprietario`), vendedor, índice de reajuste, % de comissão, vendido | `IMOB.Unidade` |
| CondPagtoImovel | 1.208 | plano de pagamento da venda por imóvel: Entrada, Mensais, Semestrais, Anuais, Chaves, Reserva, Adesão, À vista; quantidade de parcelas e valor | `VENDA` plano de pagamento |
| Indices / ValorIndices | 41 / 16 | índices de reajuste (IGP-M, INCC-M e índices "por contrato", ex.: "Opera Jan.25") e seus valores | `CAD`/`VENDA` índice de correção |
| Periodicidade | 8 | diário, mensal, semestral... | domínio fixo |
| Ocorrencias Mensais | 134 | modelo de lançamentos recorrentes (salário, mensalidade, condomínio...) gerados todo mês | `FIN` lançamento recorrente (item 8 da seção 3.3) |
| AnoMes Ocorrencias Mensais | 214 | controle de quais meses já foram gerados | idem |
| Material / MovMaterial | 647 / 3.697 | materiais e quantidades/preços ligados a um movimento | avaliar se continua (`OBRA`) |
| PadraoRelatorio | 4 | lançamentos-modelo usados como padrão de tela/relatório | não migra (avaliar) |
| Arquivo Sistema | 1 | parâmetros: nome do cliente, cidade padrão, dados do último cheque, senha | `SIS.Parametro` (avaliar) |
| Switchboard Items | 54 | itens do menu do Access | não migra |

No front-end há ainda 5 tabelas locais de trabalho (`CustoEmpresa` com 3.454 linhas, e 4 temporárias vazias), que não migram.

### 2.1 Relacionamentos (integridade no Access)

Todos com atualização e exclusão em cascata:
`EmpMaster → EmpVinculada → F Movimento Contas`; `Parceiros`, `Historico`, `Plano3`, `F Contas Financeiras`, `Imoveis`, `Indices → F Movimento Contas`; `Plano1 → Plano2 → Plano3`; `F Tipos Conta Financeira → F Contas Financeiras`; `Imoveis → CondPagtoImovel`; `Indices → ValorIndices`; `Periodicidade → Indices`; `Material → MovMaterial`.
O `ArquivoMorto` não tem relacionamento (só índices).

## 3. O movimento financeiro (`F Movimento Contas`)

43 campos. Os principais:

| Grupo | Campos | Observação |
|---|---|---|
| Chave | `NumMovimento` (autonumeração) | |
| Quem/onde | `EmpVinculada`, `CodigoParceiro`, `ContaFinanceira`, `CodImovel` | `CodImovel` está preenchido em todas as linhas (usa um imóvel "genérico" quando não é venda) |
| Classificação | `Plano1`, `Plano2`, `Plano3`, `CodHistorico`, `Complemento`, `NumDoc`, `ReferenteNotaFiscal`, `Observacao` | |
| Valores | `ValorDebito`, `ValorCredito`, `ValorReajustado`, `ValorOriginalImovel` | débito e crédito em colunas separadas |
| Datas | `DataMovto`, `DataVencto`, `DataPagto` | |
| Situação | `Confirmado`, `Efetuado`, `PagoAntecipado`, `Integracao`, `SomenteIntegracao` | a confirmar no VBA o significado exato de cada um |
| Venda de imóvel | `LinkVenda`, `AgrupadorVenda`, `ClassificacaoVenda` (A/C/D/E), `CodigoCondPagto`, `SofreReajuste`, `IndiceReajuste` | 8.079 linhas ligadas a vendas na base atual |
| Pagamento em lote | `MovPagtoLote`, `SelPagtoLote`, `PagamentoLote` | o Access já tem a ideia de "lote" (pedido do cliente, seção 3.1) |
| Recorrentes | `AnoOcorrenciaMensal`, `MesOcorrenciaMensal` | |
| Cheque | `EmitirCheque`, `ChequeEmitido` | não usados (todos "não") |
| Transferências entre empresas | `CodAtribuiParceiro`, `CodAtribuiEmpresa`, `CodAnteriorParceiro`, `CodAnteriorEmpresa` | |

Distribuição por ano (data do movimento): o movimento ativo tem 2017 em diante, mais parcelas futuras até 2030; o `ArquivoMorto` tem 2008 a 2019.

## 4. As três fontes de movimento

| Fonte | Registros | Débitos (R$) | Créditos (R$) | Período |
|---|---:|---:|---:|---|
| Base atual, `F Movimento Contas` | 102.230 | 868.826.857,00 | 582.572.965,12 | 2009 → parcelas até 2030 |
| Base atual, `ArquivoMorto` | 147.866 | 1.016.666.419,07 | 676.498.272,76 | 2008 → 2019 (+ 20 em 2020) |
| Base 2015, `F Movimento Contas` | 70.439 | 248.093.078,07 | 164.105.669,63 | 2015 → 2025 |
| Base 2015, `ArquivoMorto` | 65.540 | 101.716.331,37 | 70.063.039,33 | 2008 → 2014 |

Comparação (registro a registro, por todos os campos):

- **O `ArquivoMorto` da base 2015 está 100% contido no `ArquivoMorto` atual** (65.540 registros idênticos, mesmo número).
- Do movimento da base 2015, **68.616 de 70.439** existem iguais na base atual (no movimento ou já arquivados). Os 1.823 restantes: **1.560** existem na base atual com o mesmo número mas foram **alterados depois** (principalmente data de pagamento, confirmado, parceiro e valor: são baixas e correções feitas depois de 2015) e **263 foram excluídos** depois (quase todos parcelas de 2020 a 2023, provavelmente renegociadas ou canceladas).
- **Conclusão: a base de 2015 é uma cópia antiga (backup) da mesma base. Não traz dado novo.** Sugestão: não migrar; guardar só como referência. *Aguardando confirmação do Celso.*
- O `ArquivoMorto` tem **numeração própria** (1 a 147.866), que **colide** com números do movimento atual (2.477 números iguais com conteúdo diferente). Na migração o sistema novo gera chave nova e guarda o número antigo + a origem (`ACCESS_MOVTO` / `ACCESS_ARQMORTO`).

## 5. Qualidade dos dados (o que a migração terá de tratar)

| Item | Movimento | Arquivo morto |
|---|---:|---:|
| Data do movimento fora de 2000-2035 (ex.: 0202, 2202, 8202) | 13 | 2 |
| Data de vencimento/pagamento fora de 2000-2035 | 16 | 8 |
| Data de pagamento vazia | 3.292 | 0 |
| Débito **e** crédito preenchidos na mesma linha | 364 | 542 |
| Débito e crédito zerados | 97 | 42 |
| Valores negativos | 37 | 71 |
| Empresa vazia / histórico vazio | 6 / 5 | 0 |

Cadastros:
- **Parceiros**: 669 sem CPF nem CNPJ; 14 CPF/CNPJ repetidos; 4 nomes repetidos; só 207 com e-mail (importante para boleto e régua de cobrança).
- **Índices**: muitos índices "por contrato" (INCC14, INCC17, Opera Jan.25...), que na prática são o mesmo índice com data-base diferente. No sistema novo: um índice (INCC-M, IGP-M) com a série de valores, e a data-base no contrato.
- **Contas e plano de contas**: há registros "sistema", "N/A" e "Teste" usados como coringa.

Todos os problemas vão virar **regras de transformação** na migração (repetível no cliente), sem correção manual na cópia de desenvolvimento.

## 6. Telas e relatórios do Access (para entender as rotinas)

- **Formulários (65)**, por assunto: movimento (`F Movimento Contas`, `F Movimento Contas Vendas`, `F Movto Empresa/Parceiro` a pagar/efetuado, `Filtro Movimento Contas`); **pagamento em lote** (`Pagto Lote Header/Detail/Movto`); **vendas de imóvel** (`VendaCondPagto`, `VendaImovelVendido`, `ParcelasImovel`, `ParcelasImovelCred`, `F Manutencao Agrupada Vendas`); **reajuste** (`ReajusteImoveis`, `ReajusteParceiros`); recorrentes (`F Gerar Ocorrencias Mensais`); extratos (empresa, conta, parceiro, contábil); cadastros; emissão de cheque; agenda financeira (`AgendaFinanceraMenu`).
- **Relatórios (39)**: contas a pagar/receber em aberto por período, extratos, custos por empresa (analítico, sintético, sem financeira, permutas), posição de imóveis e de compradores, relatório contábil, notas fiscais do período, plano de contas, etiquetas.
- **Módulo**: `ValorPorExtenso` (valor por extenso, para cheque/recibo).
- O VBA de cada tela está em `legado/extracao/objetos/`. As regras de **geração de parcelas, reajuste por índice, pagamento em lote e transferência entre empresas** estão lá e serão lidas quando cada módulo for desenhado.

## 7. Pontos para o Celso decidir

1. Base de 2015: confirmar que **não será migrada** (é backup; seção 4).
2. Quanto do histórico migra: tudo desde 2008, ou só a partir de um ano (com saldo inicial)?
3. `Material`/`MovMaterial`, `PadraoRelatorio` e cheques: continuam no sistema novo?
4. O que cada situação significa na prática (`Confirmado`, `Efetuado`, `Integracao`, `SomenteIntegracao`, `ClassificacaoVenda` A/C/D/E): confirmar com o uso real da CMJ.
