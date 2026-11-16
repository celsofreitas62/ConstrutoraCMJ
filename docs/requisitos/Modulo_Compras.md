# Módulo de Compras (`COMP`)

Pedido do Celso em 16/11/2026: "precisarei de um módulo de compras; não tenho nenhum modelo, então crie um do zero baseado nos modelos básicos de mercado e depois vamos incrementando. O que puder integrar com o contas a pagar pode integrar."

Status: **desenho inicial (versão 1)**, a validar com o Celso e a CMJ (perguntas no fim). Nada foi copiado do Access (o Access não tem compras).

## 1. Fluxo (padrão de mercado, "requisição ao pagamento")

```
Solicitação ──> Cotação ──> Aprovação ──> Pedido de compra ──> Recebimento ──> Contas a pagar
 (obra pede)   (mapa com    (alçada por   (enviado ao          (conferência,   (títulos gerados
               fornecedores) valor)        fornecedor)          nota fiscal)    pela condição de
                                                                                pagamento)
```

- Cada passo é opcional conforme parâmetro e valor: **compra direta** (sem solicitação e sem cotação) para valores abaixo de um limite (`COMPRA_DIRETA_LIMITE`).
- Todo documento tem situação, histórico (auditoria da base SIS), anexos (orçamentos, nota fiscal, comprovante) e liga à **obra** e ao **centro de custo**.
- De qualquer ponto se chega aos outros com um clique (pedido → cotação → solicitação → títulos a pagar e de volta), seguindo o princípio da seção 3.1 do CLAUDE.md.

## 2. Cadastros do módulo

| Cadastro | Conteúdo básico |
|---|---|
| **Insumos / produtos e serviços** | código, descrição, unidade (un, m², m³, kg, saco, h…), grupo, tipo (material / serviço / equipamento), **conta do plano de contas e centro de custo padrão** (para o contas a pagar sair já classificado), situação. Opcional no futuro: código SINAPI. |
| **Grupos de insumo** | árvore simples (ex.: Cimento e argamassa, Aço, Elétrica, Hidráulica, Serviços de terceiros). Também usada nos relatórios. |
| **Unidades de medida** | sigla, nome, casas decimais da quantidade. |
| **Condições de pagamento** | ex.: "à vista", "30/60/90", "entrada + 2x"; quantidade de parcelas, dias de cada uma e percentual de cada uma. Usada no pedido e na geração dos títulos. |
| **Fornecedores** | já previstos em `CAD` (seção 3 do CLAUDE.md). Compras acrescenta: grupos que o fornecedor atende, prazo médio de entrega e avaliação (prazo, qualidade, preço). |
| **Alçadas de aprovação** | faixa de valor → quem aprova (usuário ou perfil); por obra se a CMJ quiser. |

## 3. Documentos

### 3.1 Solicitação de compra (requisição)
- Quem pede (usuário), **obra**, centro de custo, data em que precisa, prioridade, observação.
- Itens: insumo, quantidade, unidade, observação do item.
- Situações: Rascunho → Enviada → Em cotação → Atendida (total ou parcial) → Cancelada.

### 3.2 Cotação (mapa de cotação)
- Junta itens de uma ou mais solicitações.
- Para cada fornecedor convidado: preço unitário por item, frete, desconto, prazo de entrega, condição de pagamento, validade da proposta e anexo do orçamento recebido.
- **Mapa comparativo**: itens nas linhas, fornecedores nas colunas, com o menor preço destacado e o total por fornecedor. Também mostra o **último preço pago** de cada item.
- Escolha do vencedor por item ou pelo total, com justificativa obrigatória quando não for o menor preço.
- Mínimo de cotações por parâmetro (`COMPRA_COTACOES_MINIMO`, ex.: 3); abaixo disso exige justificativa.
- Opcional: e-mail pedindo cotação ao fornecedor (padrão de e-mail do sistema, etapa 02d).

### 3.3 Aprovação
- O pedido gerado (da cotação ou direto) entra em **aguardando aprovação** quando o valor passa da alçada de quem comprou.
- Aprovar ou reprovar com motivo; tudo fica no histórico. Aviso por e-mail ao aprovador (fila de e-mail).
- Ação nova de permissão: **APROVAR** (no item "Pedidos de compra").

### 3.4 Pedido de compra (ordem de compra)
- Fornecedor, obra, centro de custo, comprador, data, previsão de entrega, local de entrega (endereço da obra), condição de pagamento, frete (CIF/FOB e valor), desconto, observações.
- Itens: insumo, quantidade, unidade, preço unitário, desconto, total, **conta do plano** (vem do insumo, pode trocar).
- Situações: Rascunho → Aguardando aprovação → Aprovado → Enviado ao fornecedor → Recebido parcial → Recebido → Encerrado / Cancelado.
- **PDF do pedido** no padrão de relatórios (A4, logotipo da empresa e **da obra**), com envio ao fornecedor por e-mail.
- Alteração depois de aprovado volta para aprovação (e fica no histórico).

### 3.5 Recebimento (entrada)
- Contra um pedido: quantidade recebida por item (permite parcial), data, quem conferiu, divergências (falta, avaria, item errado) e observação.
- Dados da **nota fiscal**: número, série, data de emissão, chave de acesso (44 dígitos), valor total; anexo do PDF/XML.
- Diferença de preço ou quantidade entre nota e pedido: aviso; acima de uma tolerância por parâmetro (`COMPRA_TOLERANCIA_PCT`) precisa de liberação de quem tem APROVAR.
- **Futuro (gratuito)**: ler o XML da NF-e para preencher a entrada sozinha.

## 4. Integração com o contas a pagar e com a obra

1. **Pedido aprovado = compromisso**. Entra no **fluxo de caixa projetado** como "previsto" nas datas da condição de pagamento e no **custo comprometido** da obra (realizado x comprometido x orçado no dashboard). Ainda não é título a pagar.
2. **Recebimento com nota = títulos a pagar reais**. O sistema gera, no mesmo lançamento único do financeiro (seção 3.2 do CLAUDE.md), as parcelas pela condição de pagamento: fornecedor, documento = número da nota, vencimentos, valores, **conta do plano, obra e centro de custo** de cada item (rateio pela soma dos itens). Gera tudo em **um lote** (base SIS), para ver e desfazer junto.
3. **Vínculo nos dois sentidos**: o título guarda o pedido e o recebimento de origem; no pedido aparecem os títulos e a situação de pagamento (aberto / pago / atrasado).
4. **Proteções**:
   - não se apaga pedido nem recebimento que já gerou título; para desfazer, estorna;
   - respeita o **mês fechado** (pedido 10 do Celso): não gera título com data contábil em mês fechado;
   - não se paga mais do que o pedido sem liberação.
5. **Adiantamento a fornecedor** (pagar antes de receber): título com a marca "adiantamento", abatido no recebimento.
6. **Empreitada / serviços medidos**: continuam pela **medição de empreitada** (módulo OBRA, `docs/requisitos/Medicao_Empreitada.md`). Compras cuida de material e de serviço simples (pedido com valor fechado). Os dois usam os mesmos fornecedores, contas e obras.

## 5. Consultas, relatórios e painel
- Solicitações pendentes (sem cotação ou sem pedido) e há quantos dias.
- Pedidos em aberto, **entregas atrasadas** e pedidos aguardando aprovação.
- Histórico de preço por insumo e fornecedor (gráfico), com última compra e média.
- Compras por obra, por grupo de insumo, por fornecedor e por período.
- Comprometido x pago por obra (entra no drill-down do dashboard gerencial, pedido 6).
- Avaliação de fornecedores (prazo cumprido, divergências no recebimento).
- Todos com impressão A4 e envio por e-mail no padrão de relatórios.

## 6. Parâmetros previstos
`COMPRA_DIRETA_LIMITE`, `COMPRA_COTACOES_MINIMO`, `COMPRA_TOLERANCIA_PCT`, `COMPRA_EXIGE_SOLICITACAO` (S/N), `COMPRA_EMAIL_APROVADOR` (S/N), `COMPRA_NUMERACAO_PEDIDO` (formato do número, ex.: PC-2026-00001).

## 7. Onde entra no projeto
- **Agora (02d)**: o módulo `COMP` ("Compras") é cadastrado na tabela de módulos, **desligado** (fora da licença e não habilitado), para já aparecer na tela "Módulos e telas" do administrador geral.
- **Etapa 03 (modelo de dados)**: tabelas do schema `COMP`, junto com `CAD` e `FIN`, porque dependem de fornecedor, plano de contas, obra e título a pagar.
- **Fase das telas**: logo depois do Financeiro (fase 6.1 do plano), porque gera títulos a pagar e precisa deles prontos.
- **Versão 2 (se a CMJ quiser)**: almoxarifado/estoque por obra (entrada, saída para a obra, transferência entre obras, inventário), contratos de fornecimento com preço fechado e leitura do XML da NF-e.

## 8. Perguntas para a CMJ (pendentes)
1. Quem pede as compras: o pessoal da obra pelo sistema ou só o escritório?
2. Quem aprova, e a partir de que valor? A alçada muda por obra?
3. Quantas cotações a CMJ exige, e a partir de que valor?
4. Quem confere a entrega na obra, e essa pessoa usa o sistema?
5. Controla estoque/almoxarifado de obra hoje (mesmo em planilha)?
6. Paga fornecedor antes de receber (adiantamento)? Com que frequência?
7. A nota fiscal chega antes da entrega, junto ou depois?
