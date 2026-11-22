# Migração dos cadastros do Access (etapa 03c2, parte A)

Conversa "03c2 – Migração: cadastros e transformação do movimento", 17/11/2026. Decisões da CMJ nos documentos `CashBookCMJ/Migracao_Perguntas_CMJ_03c2.docx` e `CashBookCMJ/Perguntas_CMJ_03c2_parte2.docx` (registradas em `Migracao_Movimento.md`, seção 8, e `Regras_Venda_Cobranca.md`).

> **Situação: feita e homologada no SISTEMACMJ_LOCAL em 17/11/2026.** Repetível: a 2ª rodada não altera nada.

## 1. Como rodar

1. Pacote `sql/pacotes/03c2_mig_LOCAL.sql` (CNPJ para notas de compra e DDA na empresa + objetos do `MIG`).
2. `sql/local/03c2_Migracao_Cadastros_LOCAL.sql`: migra, roda de novo para provar que é repetível e mostra a conferência.

No servidor da CMJ, no dia da virada, a sequência é a mesma (com o `.mdb` do dia): carga crua, preparação do movimento, arquivo morto, **cadastros**, transformação do movimento.

## 2. Onde ficam as decisões (fonte única, em `sql/objetos/MIG/Carga_MIG_Classificacao.sql`)

| Tabela | O que decide |
|---|---|
| `MIG.Classif_Empresa` | qual EmpMaster é empresa do grupo (razão social, CNPJ, CNPJ de notas/DDA, RET) e qual não é (as obras dele ficam na Construtora) |
| `MIG.Classif_Centro` | código, nome, tipo e dona de cada obra do Access; cliente da obra por administração |
| `MIG.Classif_Centro_Extra` | centros que não existem no Access: imóveis próprios e particulares (eram contas do plano) |
| `MIG.Classif_Conta` | dona, banco, agência e número de cada conta |
| `MIG.Config_Plano_Grupo` | nome, tipo e "custo de obra" de cada grupo do plano; grupos do plano antigo como histórico |
| `MIG.DePara_Plano_Excecao` | contas que mudam de lugar (receitas, não operacional, imóveis, despesas antigas) |

O que não está nessas tabelas segue a regra automática e aparece na conferência. Nenhum dado é corrigido à mão.

## 3. Regras principais

- **Pessoas**: um Parceiro = uma pessoa (nada é juntado). CNPJ de 12 ou 13 dígitos ganha os zeros à esquerda; com CPF e CNPJ, fica o CNPJ e o CPF vai para a observação. Sem documento, o tipo (física/jurídica) sai do nome (Ltda, S/A, Comércio, Construtora...). E-mails separados e conferidos; telefones com DDD (10 a 13 dígitos) viram contatos; **telefone sem DDD, e-mail inválido, CEP ou UF fora do padrão vão para a observação** ("... no Access: ..."), nada se perde.
- **Empresas**: CNPJ e razão social vazios na classificação não apagam o que for digitado depois na tela.
- **Contas**: ativa se tem movimento de 2022 em diante; cada empresa ganha o "Caixa contábil". A conta padrão do centro só é gravada se for da mesma empresa.
- **Centros**: ativo se tem movimento desde o corte; "contábil" vem da marca do Access.
- **Plano**: o número sai do nome ("9.1.5 - Material Eletrico" → conta 09.1.05 "Material Eletrico"); plano antigo em grupos inativos 90 a 92; só migra conta que teve algum movimento.
- **Históricos padrão**: todos os que têm texto (inclusive os marcados como "do sistema" no Access, que são os mais usados: Pgto Efetuado, Depósito, Compra, Recebimento).
- Grava como usuário `sistema`, origem `MIGRACAO` (auditoria).

## 4. Resultado no LOCAL (17/11/2026)

| Cadastro | No sistema novo | Ativos |
|---|---:|---:|
| Empresas | 10 | 10 |
| Contas do Access | 23 | 17 |
| "Caixa contábil" | 10 | 10 |
| Pessoas | 1.432 | 1.366 |
| Contatos | 477 | 477 |
| Centros (obras do Access) | 51 | 16 |
| Centros (imóveis próprios e particulares) | 9 | 9 |
| Históricos padrão | 71 | 71 |
| Plano: grupos / contas | 23 / 623 | 20 grupos ativos |

De-para do plano: 166 contas do plano novo, 412 do plano antigo (histórico), 34 exceções. Pessoas: 573 usadas desde o corte; 679 sem documento; 27 com documento que não confere; 355 com algum dado do Access guardado na observação (quase sempre telefone sem DDD).

**Pendências da conferência**: só as esperadas: "N/A" (caixinha/contrapartida, tratada na transformação) e o CNPJ de 4 empresas (Ilha das Galès, La Sante, Judice e Daher, MJ Incorporadora).

## 5. Para a CMJ conferir (proposta do Claude, muda pela tela)

1. **Custo de obra** por grupo: sim para 00, 01, 03 a 10, 15, 16 e 18; não para 02 (administrativas), 11 (vendas), 12 a 14 (impostos) e 17 (reembolsos).
2. **Contrib. Previdenciária - Desoneração** (CPRB, plano antigo, 11 lançamentos) foi para 03.1.3 INSS; **RET** (plano antigo) para 14.1.1 RET.
3. **Holding sem conta padrão**: no Access a obra da Holding apontava para a conta Itaú da Construtora; escolher na tela (ex.: Sicredi Holding).
4. Nomes dos subgrupos vieram do Access ("DESP. ADM. GERAL", "ENCARGOS SOCIAIS"): podem ser melhorados pela tela.
5. Imóveis próprios: as despesas de "Sala 112 La Sante" (461) eram lançadas em parte pela Construtora; o centro do imóvel é da Holding. Na transformação, a empresa do lançamento vem do centro: confirmar.

## 6. Respostas da CMJ ao 3º documento (recebidas em 20/11/2026)

Arquivo respondido: `CashBookCMJ/Conferencia_Cadastros_CMJ_03c2_parte3_RESPONDIDO.docx` (o original de 17/11 ficou ao lado). **Aplicado em 22/11/2026 (conversa 03f)** na classificação (`Carga_MIG_Classificacao.sql` v1.1), conferido na 3ª rodada (seção 7).

1. **Custo de obra por grupo**: correto, exceto **11 (vendas), 12, 13 e 14 (impostos municipais, estaduais e federais)**, marcados "Correção" sobre o "Não" proposto. Esses quatro grupos **entram no custo da obra** (confirmado pelo Celso em 20/11/2026).
2. **Contas que mudaram de lugar**: todas corretas. Desoneração (CPRB) fica em 03.1.03 INSS, **sem conta própria** ("Correto (não)").
3. **Nomes dos subgrupos**: sem sugestão; ficam os do Access (podem mudar pela tela).
4. **Imóveis próprios**:
   - La Sante Sala 110/vaga 9: **vendida**; Allegro Apto. 52: **vendido**; Giuseppina Apto. 12: **vendido**. Centro de custo **inativo** (só histórico) (confirmado pelo Celso em 20/11/2026).
   - La Sante Sala 113/vaga 40: **verificar** (talvez vendida): fica ativa até a CMJ confirmar.
   - La Sante Sala 112/vaga 10: Holding, correto; **alugada pela Construtora**.
   - Vagas La Sante e Allegro Apto. 13: Holding, correto.
   - **Casa Danielle e Casa 66 (Marco Bosque Araucárias)**: empresa dona passa a ser a **Holding** (não a Construtora).
5. **Conta padrão da Holding**: **Sicredi Holding (0217 / 28656-3)**.
6. **CNPJs das 4 empresas** (dígitos conferidos, todos válidos):
   - Ilha das Gales Incorporadora SPE Ltda: 18.757.133/0001-72
   - Judice e Daher Incorporadora e Construtora SPE Ltda (Allegro): 23.465.751/0001-89
   - MJ Incorporadora SPE Ltda (Square): 34.939.234/0001-10
   - Edifício Comercial La Sante SPE: 21.126.427/0001-00
7. **Pessoas incompletas**: sem DDD padrão automático; a Renata vai **regularizar os cadastros no SisCMJ** (telefones e dados para boleto), com **trava para não emitir boleto para cadastro irregular** (pedido P10 em `Pedidos_Futuros.md`).

## 7. Terceira rodada com o Access de 20/11/2026 (conversa 03f, 22/11/2026)

**Extração nova** do `CashBookCMJ_be.mdb` de 20/11 pelo executor (pedido fixo `extrair_access.pedido`, executor v1.5; cerca de 20 minutos, 23 tabelas, 0 erros). `F Movimento Contas`: 102.372 linhas (antes 101.612); `ArquivoMorto` e `Parceiros` sem mudança.

**O que mudou no código** (pacote `03c2_mig_LOCAL` regerado; MIGRACAO v1.2):
- `MIG.Tabelas_Cadastros` v1.1: `Classif_Centro.CODIGO_CONTA_PADRAO` (conta padrão decidida pela CMJ, no lugar da do Access) e `Classif_Centro_Extra.ATIVO` (vazio = regra automática; 0/1 = decisão da CMJ).
- `MIG_Cadastros_Processar` v1.1: usa as duas colunas.
- `Carga_MIG_Classificacao` v1.1: as respostas da seção 6.

**Conferência** (LOCAL): 2ª passada dos cadastros sem nenhuma alteração (repetível). CNPJ e razão social das 4 SPEs gravados; centro e empresa Holding com a conta padrão Sicredi Holding; Casa Danielle e Casa 66 na Holding; Sala 110, Allegro 52 e Giuseppina 12 inativos; Sala 113 ativa; grupos 11 a 14 no custo de obra. Na conferência dos cadastros só sobra o esperado ("N/A", caixinha/contrapartida). Testes 03c2 20/0, 03a 68/0 e 03c2c (tela de casos) 61/0. MIGRACAO v1.2 ensaiada por cima no banco de ensaio `SISTEMACMJ`: sem erro, mesmas colunas e procedures do LOCAL.
