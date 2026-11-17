# SistemaCMJ

> Nome do projeto definido em 14/11/2026 (antes chamado **CashBookCMJ**, nome que continua só na pasta do Access legado `CashBookCMJ/`).

Sistema de gestão financeira e de vendas de imóveis da **Construtora CMJ** (razão social a confirmar). Projeto particular de **Celso de Freitas**, desenvolvido com o Claude. Substitui o sistema atual em **Microsoft Access (.mdb)**, que funciona mas está obsoleto.

> Este arquivo é o ponto de partida de toda sessão. Ler também, sempre que for escrever SQL ou e-mail:
> - [padroes/PADRAO_SQL.md](padroes/PADRAO_SQL.md): regras obrigatórias de T-SQL
> - [padroes/PADRAO_EMAIL.md](padroes/PADRAO_EMAIL.md): padrão de e-mails e avisos (fila + processador)
> - [padroes/GABARITOS.md](padroes/GABARITOS.md): esqueletos de procedure, trigger, function e orquestrador de e-mail
> - [padroes/PADRAO_TELAS.md](padroes/PADRAO_TELAS.md): padrão das telas (mensagens em janela com OK, permissões, ajuda)
> - [padroes/PADRAO_RELATORIOS.md](padroes/PADRAO_RELATORIOS.md): relatórios A4, PDF, e-mail, extratos de cliente e fornecedor
> - [docs/requisitos/](docs/requisitos/): pedidos detalhados do Celso (ex.: os 12 de 16/11/2026, medição de empreitada)
> - [padroes/BOAS_PRATICAS.md](padroes/BOAS_PRATICAS.md): como trabalhamos (ambientes, autorização, entrega de scripts, testes)
> - [padroes/ORIGEM_PADRAO.md](padroes/ORIGEM_PADRAO.md): mapa regra a regra do padrão de origem do Celso para este projeto
> - [docs/GUIA_DO_CELSO.md](docs/GUIA_DO_CELSO.md): guia do Celso (como abrir cada conversa, frases úteis, Git, o que só ele faz). Manter atualizado quando o modo de trabalhar mudar.
>
> **Regra geral: tudo neste projeto segue o padrão profissional do Celso** (o "padrão Togni" que ele usa no trabalho), adaptado só onde a tecnologia é diferente (sem DataFlex, SQL Server Express). Se o Celso citar uma regra pelo número de origem, procurar no mapa `ORIGEM_PADRAO.md`.
>
> Manter este arquivo atualizado a cada decisão tomada, item concluído ou regra nova (o diário de decisões fica em `docs/DIARIO_DECISOES.md`).

---

## 0. Estado atual e como retomar (atualizar sempre)

**Situação em 17/11/2026 (conversa "03c – Financeiro e ensaio da migração", em andamento)**: etapas 01, 02, 03a e 3b concluídas (3b no notebook, https://localhost:5443; subir: dois cliques em `api\rodar.cmd`; compilar: `api\compilar.cmd`; usuários no LOCAL: `celso` nível 2 e `renata` Administrador nível 1). **3c**: modelo do financeiro **aprovado** (`docs/requisitos/Modelo_FIN.md`) e **SQL homologado no LOCAL** (pacote `03c_FIN_LOCAL`, testes 03c 51/0, 03a 68/0, 02d 127/0). **Boletim semanal da implantação** aprovado (`docs/requisitos/Boletim_Implantacao.md`): SQL homologado; API (agendador de rotinas + envio de e-mail por MailKit) e tela `sis/comunicados.html` escritas, **aguardando o Celso compilar, criar a senha de app do Google (`api\configurar_email.cmd`) e testar**. No notebook, o parâmetro `EMAIL_LOCAL_LIBERADOS = COMUNICADO` deixa só o boletim aprovado sair de verdade. **Falta na 3c**: ensaio da migração do movimento (`MIG`, 2018 em diante + arquivo morto antes de 2018, com saldos). Sicredi: CNAB 400 (faltam manual, posto e regras). GitHub ligado (`origin`); envio pelo `enviar_github.cmd`. Servidor da CMJ: Windows 11 Pro.

**Histórico e decisões**: tudo em [docs/DIARIO_DECISOES.md](docs/DIARIO_DECISOES.md) (separado em 16/11/2026). Ler só quando precisar do motivo de uma decisão.

**Ao retomar, primeiro**:
1. Ler esta seção, a seção 7 (fases) e os `padroes/`. Relembrar ao Celso as pendências da seção 6 que interessam à etapa.
2. Pedir uma vez a permissão de apagar na pasta (o Git precisa apagar os `.lock`).
3. **Sempre perguntar o próximo passo e esperar a confirmação do Celso antes de desenvolver** (seção 9).
4. Trabalho organizado em **uma conversa por etapa** dentro do projeto **SistemaCMJ**; cada conversa termina atualizando esta seção, a seção 7 e o diário.
5. **Ao fechar cada etapa, avisar o Celso** para abrir uma conversa nova com o nome da próxima etapa (`docs/GUIA_DO_CELSO.md`, seção 3) e escrever "Vamos continuar o SistemaCMJ".

## 1. Objetivo

Sistema **simples, ágil e moderno** para a construtora:

- **Contas a pagar e a receber**, caixa e bancos.
- **Venda de imóveis** construídos pela própria CMJ: empreendimentos, unidades (apartamentos), clientes, contratos de venda, **geração do plano de parcelas** e todo o ciclo da venda até a quitação.
- **Cobrança via boleto Sicredi**: gerar o arquivo de **remessa** no layout do Sicredi, receber o **retorno**/boletos do banco e **enviar por e-mail ao cliente** o boleto em anexo.
- **Custo de obra** rápido: lançamentos por obra/etapa, comparando orçado com realizado.
- **Dashboards e relatórios gerenciais**: fluxo de caixa (realizado e projetado), posição de recebíveis e pagáveis, inadimplência, vendas, custo por obra, sempre com **drill-down** (clicar no número abre o detalhe que o compõe).
- **E-mails de controle e avisos** em todo o sistema (vencimentos a pagar/receber, resumo diário, boletos, falhas), no padrão de [PADRAO_EMAIL.md](padroes/PADRAO_EMAIL.md).
- **Migração dos dados do Access**: a empresa não pode redigitar nada.

Usuários: **no máximo 3 simultâneos** (raro). Uso interno, na rede da empresa.

## 2. Arquitetura

| Camada | Tecnologia | Situação |
|---|---|---|
| Banco | **SQL Server Express**, T-SQL puro, no servidor da empresa | decidido |
| Regras de negócio | **Stored procedures** (cálculo, validação, gravação, montagem de e-mail) | decidido |
| Frontend | **HTML + CSS + JavaScript** (sem DataFlex) | decidido |
| API / serviço | camada fina entre o HTML e o SQL: autentica, chama as procedures, devolve JSON, serve arquivos, **envia e-mails da fila (SMTP)**, **roda as rotinas agendadas**, gera/lê CNAB e PDF de boleto | **decidido: ASP.NET Core** (14/11/2026) |

**Por que precisa de um serviço**: o navegador não fala direto com o SQL Server, e o **Express não tem SQL Server Agent nem Database Mail**. Alguém tem de enviar e-mail, agendar rotinas e ler/gravar arquivos.

**Decidido em 14/11/2026**: **ASP.NET Core (C#)**, compilado para o **.NET 10 (LTS)**, com Minimal API, rodando como **serviço do Windows** (ou no IIS) no mesmo servidor do SQL Express.
- Nativo no Windows e no SQL Server (Microsoft.Data.SqlClient), sem driver ODBC no meio.
- `BackgroundService` substitui o SQL Agent: processa a fila de e-mails a cada minuto e roda as rotinas diárias.
- Envio SMTP com MailKit (UTF-8 correto, anexos); bibliotecas maduras para CNAB e PDF.
- Publica um único executável; o HTML/JS fica em `wwwroot` do próprio serviço.

Node.js foi avaliado e descartado: o .NET é mais forte para o que a API faz além de ponte (agendador, SMTP, CNAB, PDF) e é nativo no Windows Server.

**Princípio**: a lógica de negócio fica no **SQL** (procedures), como no padrão do autor. A API não decide regra de negócio; ela autentica, valida formato, chama a procedure e devolve o resultado (`SUCESSO` / `MENSAGEM` / dados).

### 2.1 Restrição: somente software gratuito (decidido 13/11/2026)

Tudo o que o sistema usar tem de ser **gratuito para uso comercial**. Antes de adotar qualquer biblioteca, conferir a licença (preferir MIT, Apache 2.0, BSD). Licenças "gratuitas só abaixo de X de faturamento" ou "só para uso não comercial" **não servem**.

| Peça | Escolha gratuita | Observação |
|---|---|---|
| Banco | SQL Server **Express** | Gratuito também para uso comercial. Limites: **50 GB por banco no SQL Server 2025 Express** (10 GB nas versões 2022 e anteriores), até 4 núcleos, ~1,4 GB de memória para cache. Para 3 usuários, sobra. |
| Administração do banco | SSMS | Gratuito. |
| API / serviço | **.NET (ASP.NET Core)** ou **Node.js** | Os dois são open source (MIT). |
| Servidor web | Kestrel (embutido no .NET) como serviço do Windows, ou IIS | O IIS já vem com o Windows Server, sem custo extra. |
| Editor | VS Code | Gratuito. Visual Studio Community também é gratuito para desenvolvedor individual. |
| Envio de e-mail (código) | MailKit (.NET) ou Nodemailer (Node) | MIT. |
| PDF (boleto, relatórios) | PdfSharp/MigraDoc (MIT) ou geração a partir de HTML | **Evitar QuestPDF** (gratuito só para empresas com faturamento até US$ 1 milhão por ano). |
| Boleto / CNAB | biblioteca open source (ex.: BoletoNetCore) ou implementação própria do layout | Conferir a licença e se a lib cobre o Sicredi no layout escolhido; senão, escrever o gerador/leitor do layout a partir do manual do banco. |
| Gráficos do dashboard | Chart.js (MIT) ou Apache ECharts (Apache 2.0) | Arquivos servidos localmente, sem depender de CDN. |
| HTTPS | certificado autoassinado / CA interna, ou Let's Encrypt se houver domínio público | Gratuito. |
| Agendamentos e backup | serviço da aplicação + Agendador de Tarefas do Windows + `sqlcmd` | Gratuito (substitui o SQL Agent). |
| Controle de versão | Git (ou SVN/Tortoise) | Gratuito. |

**Servidor de e-mail**: não montar servidor de e-mail próprio (cai em spam, dá manutenção e é inseguro). Usar o **SMTP da conta de e-mail que a CMJ já tem** no domínio dela (Microsoft 365, Google Workspace ou o provedor da hospedagem), com uma caixa só para envio (ex.: `financeiro@` ou `naoresponda@`). Assim não há custo novo. Se a CMJ não tiver e-mail próprio, existem planos gratuitos de serviços de envio (limite diário de envios), mas aí o volume mensal de boletos precisa caber no limite. Uma conta Gmail pessoal só serve para teste.

**Custos que não são de software** (ficam fora da restrição, mas é bom a CMJ saber): a tarifa que o Sicredi cobra por boleto registrado/liquidado, a licença do Windows Server (já existente), e o e-mail do domínio (se já existir, sem custo novo).

## 3. Módulos (escopo inicial, a validar com o Access)

Schemas aprovados (14/11/2026): `CAD`, `BANCO`, `IMOB`, `VENDA`, `FIN`, `COBR`, `OBRA`, `GER`, `SIS` e `MIG` (só migração). Em 16/11/2026 entrou `COMP` (Compras, seção 3.9). Nomenclatura: PADRAO_SQL regras 29 a 31.

1. **Cadastros**: em `CAD`: empresa(s), clientes (PF/PJ, cônjuge/coobrigado, contatos, endereço), fornecedores, plano de contas, centros de custo. Em `IMOB`: empreendimentos/obras (**cada obra tem a sua própria logomarca**, cadastrada junto com a obra; ver seção 3.6), blocos e unidades (tipo, área, valor de tabela, situação: disponível / reservada / vendida / distratada), índices de correção. Em `BANCO`: bancos e contas bancárias.
2. **Vendas (`VENDA`)**: proposta/reserva → contrato de venda → plano de pagamento (entrada/sinal, mensais, intermediárias/balões, parcela das chaves, saldo financiado) → **geração das parcelas** como títulos a receber → aditivos, renegociação, distrato, quitação. Impede vender a mesma unidade duas vezes (UPDLOCK).
   - **Contrato gerado pelo sistema**: modelo (minuta) com campos preenchidos a partir da venda (comprador, cônjuge, unidade, valores, plano de pagamento); cada geração vira uma **versão** gravada; só a última versão sem pendências pode ir para assinatura.
   - **Assinatura digital (opcional, se a CMJ quiser)**: mesmo desenho já usado pelo Celso em produção num projeto anterior (contrato de prestador de serviço). Plataforma via API (FastSign, ZapSign ou outra que a CMJ escolher; o plano é pago pela CMJ). Fluxo: cadastro dos signatários (comprador, cônjuge/coobrigado, representante da CMJ, testemunhas) → **Enviar para assinatura** (o serviço manda o PDF pela API, guarda o ID do documento e os links) → acompanhamento de quem já assinou (botão **Verificar** + verificação automática ao abrir a venda e rotina agendada, porque o servidor não tem endereço público para receber aviso da plataforma) → ao concluir, **baixa o PDF assinado**, guarda junto da venda, situação `ASSINADO` e grava a data real de assinatura → **Cancelar** envio, se necessário. Chamada HTTP sempre pelo serviço com fila e idempotência (PADRAO_SQL regra 53); token da plataforma nunca em tabela nem em log (regra 54). Testar primeiro no ambiente de teste (sandbox) da plataforma.
3. **Financeiro (`FIN`)**: títulos a pagar e a receber, baixas totais/parciais, juros/multa/desconto, estornos, transferências entre contas, caixa. Extrato e conciliação bancária ficam em `BANCO`.
4. **Cobrança (`COBR`)**: carteira Sicredi, geração de **nosso número**, arquivo de **remessa**, leitura do **retorno** (liquidação, baixa, rejeição, tarifas), PDF do boleto, envio por e-mail ao cliente, 2ª via.
4.1 **Compras (`COMP`)** (pedido do Celso, 16/11/2026): solicitação → cotação (mapa comparativo) → aprovação por alçada → pedido de compra → recebimento com nota fiscal → **títulos a pagar gerados sozinhos** pela condição de pagamento, já com obra, centro de custo e conta. Desenho na seção 3.9 e em `docs/requisitos/Modulo_Compras.md`.
5. **Custos de obra (`OBRA`)**: orçamento por obra/etapa, lançamentos de custo (vindos do contas a pagar com obra/centro de custo), realizado x orçado, custo por m².
6. **Gerencial (`GER`)**: dashboard e relatórios com drill-down (fluxo de caixa diário/mensal realizado + projetado, recebíveis por empreendimento, inadimplência por faixa de atraso, vendas por período, custo por obra).
7. **Sistema (`SIS`)**: usuários e permissões, parâmetros, grupos de e-mail, fila de e-mail, log de erros, histórico de alterações, agenda das rotinas.
8. **Menu do sistema (pedido do Celso, 15/11/2026; revisto em 16/11/2026: árvore que abre e fecha no lugar, caminho sempre visível)**: se possível, **menu lateral em drill-down**: barra à esquerda com os módulos; clicar no módulo abre os itens/telas dele (e subníveis, se houver) na própria barra, com volta ao nível anterior. Só aparecem os módulos liberados na licença (3.5) e os itens permitidos ao usuário (3.6). Definir o desenho na fase das telas (fase 4, Cadastros).
9. **Ajuda (requisito do Celso, 13/11/2026)**: o sistema terá **Ajuda geral** (visão do sistema, primeiros passos, rotinas do dia a dia, perguntas frequentes, glossário: nosso número, remessa, retorno etc.) e **Ajuda em cada página** (botão "?" fixo em toda tela, abrindo um painel lateral com: para que serve a tela, como preencher cada campo, o que cada botão faz, cuidados e erros comuns). Regras:
   - Conteúdo em linguagem simples, escrito junto com cada tela: **nenhuma página é considerada pronta sem a sua ajuda**.
   - Textos em arquivos próprios (um por página, ex.: `wwwroot/ajuda/fin-titulos.html`), separados do código da tela, para poder corrigir a ajuda sem mexer no sistema.
   - Dica curta (tooltip) nos campos menos óbvios; a ajuda da página leva ao tópico certo da ajuda geral.
   - A ajuda geral tem busca por palavra.

## 3.1 Pedidos do cliente para o funcionamento (passados pelo Celso em 14/11/2026)

Princípio geral: **sistema ágil, totalmente integrado e fácil de manter os lançamentos**. Achar a informação rápido e, ao clicar, abrir direto a tela de manutenção daquele movimento.

1. **Tela de abertura = agenda**: grid (lista) dos compromissos **a pagar e a receber da semana**, com filtros por cliente/fornecedor, período, obra, situação e **busca por nome ou parte do nome**. Clicou numa linha, abre a manutenção daquele lançamento.
2. **Lote de movimento**: todo processo que gera vários registros de uma vez grava um **número de lote** (ex.: uma venda gerou 30 parcelas = lote 123). Dá para filtrar por lote, por obra, por empreendimento, por unidade e por cliente, e corrigir o lote inteiro a partir dele.
3. **Lançamento único integrado** (no lugar do lançamento dobrado débito/crédito do Access): um lançamento controla o que foi pago e o que ainda falta pagar/receber de cada cliente e fornecedor. Modelo na seção 3.2.
4. **Conciliação bancária** com o extrato do banco.
5. **Relatórios de fechamento contábil** para enviar à contabilidade.
6. **Anexar documentos** a cada lançamento e às vendas (contrato, PDF de acordo, nota, comprovante etc.).

## 3.2 Modelo financeiro: lançamento único (APROVADO pelo Celso em 14/11/2026)

É o modelo usado pelos sistemas financeiros atuais: o usuário lança **uma vez**; o sistema sabe o que está em aberto e gera sozinho o que a contabilidade precisa.

| Nível | Tabela (proposta) | O que guarda |
|---|---|---|
| Documento | `FIN.Lancamento` | um por obrigação: tipo (Pagar/Receber), pessoa, documento/nota, categoria (plano de contas), obra/centro de custo, histórico, **origem** (manual, venda, nota, importação) e **lote** |
| Parcela | `FIN.Parcela` | uma por vencimento: número, vencimento, valor, situação (aberta, parcial, paga, cancelada). **Saldo em aberto = valor − baixas** |
| Baixa | `FIN.Baixa` | cada pagamento/recebimento, total ou parcial: data, valor, juros, multa, desconto, conta bancária. Estorno = baixa de estorno, nunca apagar |
| Movimento bancário | `BANCO.Movimento` | gerado automaticamente pela baixa (e por tarifas/transferências); é ele que concilia com o extrato |
| Lote | `SIS.Lote` | número sequencial + origem + data + usuário; gravado em todo lançamento/parcela gerado junto |
| Anexo | `SIS.Anexo` | genérico para qualquer registro (lançamento, parcela, baixa, venda, contrato, cliente): tipo, nome original, caminho em disco, tamanho, hash, quem/quando. Arquivo fica em disco, o banco guarda só a referência |

- **Débito e crédito continuam existindo, mas gerados pelo sistema** para o relatório contábil: cada categoria e cada conta bancária têm a sua conta contábil de referência; a exportação monta as partidas dobradas a partir das baixas. O usuário não lança em dobro.
- **Conciliação**: importar o extrato **OFX** (arquivo que o internet banking gera) e o retorno de cobrança do Sicredi; o sistema sugere os pares por valor + data + documento; o usuário confirma; o que sobra do extrato (tarifa, IOF, estorno) pode virar lançamento com um clique.
- Índices pensados para a agenda e a busca: vencimento, situação, pessoa, obra, lote; busca por parte do nome em `CAD.Pessoa`.

## 3.3 Rotinas e controles de mercado (TODOS APROVADOS pelo Celso em 14/11/2026)

Vindas do que os sistemas de construtoras e os financeiros atuais oferecem. **Os 20 itens fazem parte do escopo.** Itens 15 (alçada) e 16 (retenções) dependem de a CMJ querer/da contabilidade: construir parametrizados e desligáveis.

**Vendas de imóveis**
1. **Espelho de vendas**: mapa visual do empreendimento (blocos x andares) com a situação de cada unidade (disponível, reservada, vendida, distratada), clicável.
2. **Ficha financeira do contrato / extrato do cliente**: tudo o que foi pago, o que falta, atrasos e correções, com PDF para enviar ao cliente.
3. **Reajuste automático das parcelas por índice** (INCC na obra, IGP-M/IPCA depois das chaves), com histórico de cada reajuste e conferência antes de aplicar.
4. **Declaração anual de pagamentos para o Imposto de Renda do comprador** (pedida todo ano pelos clientes de construtora).
5. **Termo de quitação** gerado ao quitar o contrato.
6. **Renegociação/acordo** com histórico: parcelas originais canceladas e novas geradas num lote de acordo, com o PDF do acordo anexado.
7. **Comissão de corretor/imobiliária** por venda (se a CMJ usar).

**Financeiro**
8. **Lançamentos recorrentes** (aluguel, internet, honorários): gera as parcelas do mês automaticamente.
9. **Rateio** de um lançamento entre várias obras/centros de custo.
10. **Fechamento de mês**: depois de fechado, ninguém altera lançamento daquele mês sem reabrir (com permissão e registro).
11. **Alerta de pagamento em duplicidade**: mesmo fornecedor + valor + documento perto da mesma data.
12. **Régua de cobrança**: e-mail automático ao cliente X dias antes do vencimento, no vencimento e depois do atraso (já previsto no padrão de e-mail).
13. **Fluxo de caixa projetado** com saldos bancários reais + parcelas em aberto, diário e mensal.
14. **Regime de caixa e de competência** nos relatórios (data do pagamento x mês a que a despesa pertence).
15. **Aprovação de pagamentos** acima de um valor (alçada), se a CMJ quiser esse controle.
16. **Retenções de impostos em notas de serviço** (ISS, INSS, IR, PIS/COFINS/CSLL), comuns em obra; avaliar com a contabilidade.

**Sistema**
17. **Busca geral** no topo de toda tela (cliente, fornecedor, unidade, contrato, nº de documento, valor).
18. **Histórico de alterações** visível na própria tela de manutenção (quem mudou o quê e quando).
19. **Permissões por perfil** (quem baixa, estorna, cancela contrato, reabre mês, vê painel).
20. **Exportar para Excel** em toda lista/grid.

**Perguntas para fechar o desenho** (PENDENTES: o Celso vai perguntar à CMJ; registrar as respostas no diário):
- A contabilidade usa qual programa e em que formato quer o fechamento (planilha, PDF, arquivo de importação do sistema contábil)?
- ~~O Sicredi da CMJ disponibiliza o extrato em **OFX**?~~ **Sim** (17/11/2026); a CMJ guarda os OFX numa pasta por empresa (caminho no cadastro da empresa).
- A CMJ trabalha com mais de uma conta bancária / mais de um banco?
- ~~Os relatórios da contabilidade são por regime de caixa ou de competência?~~ **Regime de caixa** (17/11/2026).

## 3.4 Parametrização total (decidido em 14/11/2026; reforçado em 17/11/2026)

**Regra do Celso (17/11/2026): tudo o que for possível no sistema deve ser parametrizado, como nos melhores softwares de mercado.** Ao desenhar qualquer rotina, perguntar "isto pode mudar um dia?"; se puder, vira parâmetro ou cadastro.

**Nada fixo no código**: percentuais (multa, juros, desconto), dias (carência, aviso de vencimento, régua de cobrança), contas padrão, e-mails, textos de e-mail, limites de alçada, índices etc. ficam em `SIS.Parametro` (chave, valor, tipo, descrição, módulo, quem alterou e quando), editáveis numa tela do administrador e **auditados**. Regra já prevista no PADRAO_SQL (regra 33), agora obrigatória para tudo.

## 3.5 Licença, módulos e proteção contra cópia (decidido em 14/11/2026)

Objetivo do Celso: só ele (desenvolvedor) habilita módulos e define empresa/CNPJ; o sistema não funciona se for copiado para outro servidor ou computador sem autorização; ele pode instalar módulo novo no cliente que fica **desligado até ele liberar**.

Desenho:
- **Chave de licença assinada digitalmente** pelo Celso (par de chaves: a privada fica só com ele; a pública vai embutida na API). A chave contém: razão social, CNPJ, **identificação do servidor** autorizado, módulos liberados e, se ele quiser, data de validade.
- A licença fica gravada em `SIS.Licenca`. A **API confere a assinatura** ao iniciar e a cada login: assinatura inválida, CNPJ diferente ou servidor diferente → sistema não abre (só a tela de "licença inválida"). Módulo não liberado → não aparece no menu e a API recusa as chamadas dele.
- **Razão social e CNPJ** dos relatórios, e-mails e boletos vêm da licença: ninguém altera por tela. **Revisto em 16/11/2026**: a licença tem **um só CNPJ**, que só registra o software e impede a cópia; as empresas do grupo (Construtora, SPEs, Holding) são cadastradas livremente em `CAD.Empresa`, e os documentos de uma empresa/obra usam a razão social e o CNPJ dela. A licença continua valendo para o que é do sistema (cabeçalho, e-mails do sistema).
- **Gerador de licença**: programa pequeno, só no computador do Celso, que gera a chave (nunca vai para o cliente).
- **Limite honesto**: num servidor que é do cliente, nenhuma proteção é impossível de quebrar por quem tem acesso de administrador ao Windows e ao SQL; isto impede o uso e a cópia casuais e deixa claro que a cópia é proibida. A proteção completa vem junto com o **contrato** (cláusula de licença de uso: o código-fonte e os direitos ficam com o desenvolvedor). A proposta atual diz só "sem custo de licença": avaliar incluir essa cláusula antes do envio.
- **Papéis**: o **desenvolvedor** não é usuário do dia a dia; ele atua pela licença. O **administrador do sistema** (alguém da CMJ) tem acesso geral e cuida dos usuários e permissões, mas **não** libera módulos nem altera empresa/CNPJ.

## 3.6 Usuários e permissões (decidido em 14/11/2026)

- Cadastro de usuários feito pelo **administrador do sistema**.
- Três níveis: **Módulo** (ex.: Financeiro) → **Item/tela** (ex.: Títulos a pagar) → **Ação**: ver, incluir, alterar, excluir, e ações especiais da tela (baixar, estornar, cancelar contrato, reabrir mês, exportar, ver painel).
- **Perfis** (ex.: Financeiro, Vendas, Consulta) com as permissões; cada usuário recebe um perfil e o administrador pode dar ou tirar permissões individuais além do perfil.
- Tabelas previstas em `SIS`: `Modulo`, `Item`, `Acao`, `Perfil`, `Perfil_Permissao`, `Usuario`, `Usuario_Permissao`. Toda procedure chamada pela API confere a permissão antes de agir; a tela esconde o que o usuário não pode fazer.
- Senha com hash forte, troca obrigatória no primeiro acesso, bloqueio após tentativas erradas, registro de login/logout.
- **Identidade visual por cliente** (pedido do Celso, 15/11/2026): logomarcas e cores ficam em **parâmetros** (tipos `ARQUIVO` e `COR`), editáveis só pelo administrador geral; instalar em outro cliente = trocar os arquivos e os parâmetros, sem mexer no sistema. Arquivos na pasta do parâmetro `IDENTIDADE_PASTA` (`C:\SistemaCMJ_Arquivos\Identidade`); versões da CMJ em `docs/identidade/`.
- **Logomarca por obra** (pedido do Celso, 15/11/2026): cada empreendimento/obra tem a sua logomarca, enviada no cadastro da obra (upload, sem mexer no sistema). Proposta para o desenho do `IMOB` (etapa 03): a imagem entra como **anexo da obra** (`SIS.Anexo`, tipo `LOGOMARCA`, a mais recente ativa vale), com as versões tratadas pela API. Documentos e e-mails ligados a uma obra (contrato, boleto, extrato do cliente, espelho de vendas, relatórios por obra) usam a logomarca da obra; sem logomarca da obra, usam a da empresa (parâmetros `EMPRESA_LOGO*`). A 02c já cria o tipo de anexo `LOGOMARCA`.
- **Dois níveis de administrador** (pedido do Celso, 15/11/2026): **Administrador geral** (nível 2, login `celso`, o criador do sistema) vê e faz tudo, inclusive **Licença e Parâmetros** (telas `EXCLUSIVO_GERAL`); seu usuário e seu perfil são invisíveis para os demais. **Administrador** (nível 1, login `admin`, da CMJ) vê todos os menus liberados, cuida de usuários e perfis e vê o log de erros, mas não vê Licença nem Parâmetros e não altera o administrador geral. Telas exclusivas não podem ser dadas a ninguém por marcação.

## 3.7 Follow-up de movimentações / auditoria (decidido em 14/11/2026, "importante")

- **Toda inclusão, alteração e exclusão** em tabela de negócio grava em `SIS.Auditoria`: tabela, ID do registro, operação (I/A/E), campo, **valor antes**, **valor depois**, usuário, data/hora, estação, tela/rotina de origem e lote.
- Gravação por trigger set-based em cada tabela (padrão do gabarito de trigger), com o usuário vindo da API via `SESSION_CONTEXT`.
- **Ninguém altera nem apaga a auditoria**, nem o administrador.
- Consulta: aba **"Histórico"** em toda tela de manutenção (quem fez o quê naquele registro) e uma tela geral de consulta com filtros por usuário, período, tabela, registro e operação.

## 3.8 Pedidos do Celso de 16/11/2026 (12 itens, detalhe em `docs/requisitos/Pedidos_Celso_2026-11-16.md`)

1. Recusa e erro em **janela com OK** (`padroes/PADRAO_TELAS.md`).
2. e 4. Tela **Instalação e manutenção**, exclusiva do administrador geral: cada comando de instalação/manutenção vira botão. O SQL grava o pedido numa fila; o serviço executa uma **lista fixa** de comandos, com saída registrada; só no servidor ou com senha pedida de novo. A primeira instalação (SQL Express, .NET, o próprio serviço) fica num instalador único rodado uma vez. Lado SQL na 02d.
3. **Ajuda exclusiva** do administrador geral (instalação, licença, parâmetros, comandos).
5. **Habilitar módulo e tela**: chave `HABILITADO` em `SIS.Modulo` e `SIS.Item`, só o nível 2 liga; aparece só o que está **na licença e habilitado**. Entra na 02c.
6. Painel: **obras em andamento** em gráfico financeiro com drill-down (obra > custo, vendas, recebido > etapas > lançamentos).
7. **Medição de empreitada** completa (contrato, itens, medições numeradas, diárias, descontos, aprovação gera o lançamento a pagar com a referência da medição): `docs/requisitos/Medicao_Empreitada.md`. Planilha de origem em `PlanilhasCMJ/` (fora do Git: dados pessoais).
8. Baixa com juros, multa, desconto, abatimento, tarifa, correção e retenções, cada um no seu campo.
9. Lote: grade com os lançamentos do lote; clique abre o movimento.
10. Mês fechado bloqueia só os lançamentos em conta **marcada como contábil** no plano de contas.
11. Plano de contas em 3 níveis sempre alinhados (só o nível 3 recebe lançamento; 3 > 2 > 1 por chave estrangeira); análise do plano do Access e proposta de melhoria **na etapa 03**.
12. Relatórios A4 profissionais, PDF para imprimir e enviar, com logomarca da empresa e da obra; extrato do cliente e do fornecedor (`padroes/PADRAO_RELATORIOS.md`).

## 3.9 Módulo de Compras (pedido do Celso em 16/11/2026; desenho inicial em `docs/requisitos/Modulo_Compras.md`)

O Celso não tem modelo: criado do zero no padrão de mercado, para ir incrementando. Pontos principais:
- Fluxo: solicitação → cotação → aprovação (alçada por valor, ação nova **APROVAR**) → pedido → recebimento (parcial, com nota fiscal) → contas a pagar. Compra direta sem cotação abaixo de um limite (parâmetro).
- Cadastros: insumos/produtos e serviços (com conta do plano e centro de custo padrão), grupos, unidades, condições de pagamento, alçadas; fornecedores continuam em `CAD`.
- **Integração com o financeiro**: pedido aprovado = **compromisso** (fluxo de caixa projetado e custo comprometido da obra); recebimento com nota = **títulos a pagar** em um lote, com vínculo nos dois sentidos; respeita mês fechado; não se apaga o que já gerou título (estorna).
- Empreitada/serviço medido continua pela **medição** (`OBRA`); Compras cuida de material e serviço com valor fechado.
- Encaixe: módulo `COMP` cadastrado **desligado** na 02d; tabelas na etapa 03; telas logo depois do Financeiro (fase 6.1). Versão 2 possível: almoxarifado por obra, contratos de fornecimento, leitura do XML da NF-e.
- Perguntas à CMJ: pendência 14 da seção 6.

## 4. Pontos já sabidos sobre o ambiente

- **SQL Server Express**: limite de 50 GB por banco na versão 2025 (10 GB nas anteriores; usar a 2025 se o Windows do servidor permitir), sem Agent, sem Database Mail. Arquivos (PDF, CNAB, anexos) em **disco**, banco guarda só a referência.
- **Bancos**: `SISTEMACMJ_LOCAL` (desenvolvimento, instância `.\SQL2025` no notebook do Celso) e `SISTEMACMJ` (produção, servidor da CMJ).
- **Entrega de SQL**: scripts `.sql` em `sql/`, executados pelo usuário no **SSMS (Abrir arquivo + F5)**. CRLF, BOM só se houver acento (PADRAO_SQL regras 37-38).
- **Segurança**: senhas com hash forte (PBKDF2/bcrypt/Argon2), nunca texto puro nem criptografia reversível; HTTPS mesmo na intranet; dados de clientes (CPF, endereço, renda) são dados pessoais (LGPD): acesso por perfil, mascarar onde não for necessário, sem dados reais em teste fora do ambiente da empresa.
- **E-mail de teste**: `celsofreitas62@gmail.com`. Nunca testar com e-mail real de cliente.

## 4.1 Instalação no servidor da CMJ (feita pelo Celso)

Avaliação (13/11/2026): **o Celso dá conta sozinho**. É o mesmo tipo de trabalho que ele já faz com SQL Server/SSMS e com servidor web. Um especialista de rede só entra se a rede da CMJ tiver firewall/roteador gerenciado por terceiro ou se for preciso acesso de fora da empresa.

| Passo | Dificuldade | Observação |
|---|---|---|
| Conferir versão do Windows, espaço em disco, usuário administrador | fácil | pré-requisito de tudo |
| Instalar SQL Server Express + SSMS | fácil | instalação "Básica" ou "Personalizada"; modo de autenticação misto; anotar o nome da instância |
| Liberar o SQL só para o próprio servidor | fácil | a API roda no mesmo servidor, então o SQL **não** precisa ser aberto na rede (mais seguro) |
| Instalar o runtime do .NET (Hosting Bundle) ou Node.js | fácil | um instalador |
| Publicar a aplicação como serviço do Windows (ou no IIS) | fácil a médio | roteiro passo a passo será escrito no projeto |
| Liberar a porta do sistema no Firewall do Windows | fácil | uma regra de entrada, só para a rede interna |
| Endereço fixo do servidor na rede (IP fixo ou nome) | fácil a médio | se o roteador distribui IP, pode precisar de quem administra a rede |
| HTTPS na intranet (certificado) | médio | certificado autoassinado instalado nos 3 computadores resolve |
| E-mail: SMTP da conta da CMJ | fácil a médio | testar se a porta 587 de saída não está bloqueada pelo firewall/provedor |
| Backup agendado + cópia para outro disco | fácil | Agendador de Tarefas + script. **O servidor da CMJ já sincroniza com o Google Drive de madrugada**: a sincronização tem de levar o arquivo de **backup** (`.bak` gerado pelo `BACKUP DATABASE` antes do horário da sincronização, no HD), **nunca** os arquivos do banco em uso (`.mdf`/`.ldf`), que copiados com o SQL ligado saem inutilizáveis. Teste de restauração periódico. **Nobreak** recomendado. |
| Acesso remoto para suporte | depende | AnyDesk/RustDesk resolve; VPN ou acesso de fora da empresa é com o pessoal de rede |
| Uso fora da empresa (celular, home office) | **especialista** | não está no escopo; exige VPN ou publicação segura na internet |

**A fazer**: escrever `docs/Roteiro_Instalacao_Servidor.md` passo a passo (pedido do Celso em 14/11/2026). API já definida (ASP.NET Core); falta a versão do Windows do servidor. O banco é instalado rodando **um único arquivo**: `sql/MASTER/SISTEMACMJ_MASTER_Instalacao.sql` (PADRAO_SQL regras 58 a 60).

## 4.2 Ambiente de desenvolvimento (notebook do Celso, instalado em 14/11/2026)

| Item | Versão / configuração |
|---|---|
| SQL Server 2025 **Express** | 17.0.1000.7, instância nomeada **`.\SQL2025`**, só Database Engine, collation `Latin1_General_CI_AS`, autenticação mista, serviço automático. O SQL Server 2022 antigo da máquina continua instalado e não é usado no projeto. |
| SSMS | 22 |
| .NET SDK | 11.0.100 (compila para .NET 10 LTS, que é o alvo da API) |
| VS Code | 1.146.0 + extensões C# Dev Kit, SQL Server (mssql), Live Server. Sem GitHub Copilot (pago). |
| Git | 2.56.1, `core.autocrlf = false` (não mexe em CRLF/BOM dos `.sql`) |

## 5. Sistema legado (Access)

- Pasta para o material extraído: [legado/](legado/).
- **Arquivos recebidos** (14/11/2026): `CashBookCMJ/CashBookCMJ.mdb` (front-end: telas, consultas, VBA, ~14 MB) e `CashBookCMJ/CashBookCMJ_be.mdb` (back-end: dados, ~136 MB). O Access já está dividido.
- Nesta máquina **não há driver ODBC do Access** instalado. Para extrair: usar a máquina que tem o Access, ou instalar o *Microsoft Access Database Engine* (ACE, mesma arquitetura 32/64 bits do Office).
- **O que extrair**:
  1. Estrutura de todas as tabelas (campos, tipos, tamanhos, obrigatórios, chaves, índices, relacionamentos) → `legado/schema_access.md`.
  2. Consultas salvas (SQL de cada query): revelam as regras de negócio e os relatórios atuais.
  3. Formulários e relatórios: lista, campos, e o **código VBA** (módulos e eventos), principalmente cálculo de parcelas, juros/multa, correção e geração de boletos.
  4. Volume de dados por tabela e qualidade (nulos, duplicidades, datas inválidas, órfãos).
- **Dados extraídos agora são só para o desenvolvimento** (decidido em 15/11/2026): a cópia dos `.mdb` que está no notebook serve para desenhar o modelo, escrever e ensaiar a migração. **A importação para valer é feita na instalação no cliente**, com o `.mdb` atualizado daquele dia. Por isso, tudo da migração (extração + carga em `MIG.*` + transformação + conferência) tem de ser **um processo repetível, rodado no servidor da CMJ**, sem nenhum passo manual que dependa dos dados de hoje; nada de corrigir dado à mão na cópia de desenvolvimento.
- **`ArquivoMorto`: SUBSTITUÍDO em 16/11/2026** (ver o item seguinte). Decisão anterior, de 15/11/2026: no Access é a tabela de movimentos antigos arquivados (147.866 registros, **mesmos 43 campos** de `F Movimento Contas`, que tem 101.612). Na migração os dois são **unidos no movimento único do sistema novo** (modelo da seção 3.2), guardando de qual tabela veio cada registro (origem `ACCESS_MOVTO` / `ACCESS_ARQMORTO`) para a conferência. Cuidar de chave repetida entre as duas tabelas e de movimento que esteja nas duas. O sistema novo não terá "arquivo morto": histórico fica no mesmo lugar, filtrado por data/situação.
- **Arquivo morto só para consulta** (decidido pelo Celso em 16/11/2026, substitui a decisão de 15/11/2026): migra para o modelo novo (lançamento único) **só o movimento da tabela atual** (`F Movimento Contas`). Os lançamentos velhos do `ArquivoMorto` (2008-2019) vão para uma tabela própria de **arquivo morto**, com os dados como eram (fornecedor, cliente, empresa, conta, plano, valores, datas), para consulta de pagamentos da época, fornecedores etc. Item de menu **"Arquivo morto"**: só consulta (filtros, busca, exportar), **sem manutenção nenhuma** (nada se inclui, altera, exclui ou baixa). A **base de 2015 não migra** (é backup).
- **Migração**: tabelas de *staging* (`mig.*`) recebendo o Access cru → procedures de transformação para o modelo novo → relatório de conferência (contagens e totais por cliente/contrato/obra batendo com o Access) → carga final em produção. Repetível quantas vezes for preciso até a virada.

## 6. Decisões pendentes (perguntar ao Celso)

> O Celso vai responder oportunamente, conforme tiver as informações em mãos. Não bloquear o trabalho por causa delas: seguir com o que não depende da resposta e relembrar as pendências relevantes no início de cada etapa. Ao receber uma resposta, mover o item para o diário (`docs/DIARIO_DECISOES.md`).

1. ~~Camada de API~~: **resolvido** em 14/11/2026 (ASP.NET Core).
2. ~~Caminho do .mdb~~: **resolvido** em 14/11/2026 (pasta `CashBookCMJ/`, dividido em front-end e back-end).
3. **Sicredi** (respondido em parte em 17/11/2026): layout **CNAB 400**; hoje os boletos são feitos **no site do banco**; cooperativa **0217**, conta **73623-5**, código do beneficiário **55.73623**, carteira **Simples**. Falta:
   - o **manual do CNAB 400 do Sicredi** (pedir ao gerente) e a liberação da **troca de arquivos** (remessa/retorno) para a conta, já que hoje se usa o site;
   - **posto** da cooperativa (faz parte do nosso número e do arquivo);
   - regras de multa/juros/desconto/protesto/baixa automática;
   - se as outras SPEs também terão cobrança (cada uma com o seu beneficiário);
   - avaliar a **API de Cobrança do Sicredi** como evolução do CNAB.
4. **Correção das parcelas**: há correção monetária (ex.: INCC durante a obra, IGP-M/IPCA após as chaves)? Juros de tabela Price/SAC no saldo? Como o Access faz hoje?
5. ~~**Identidade visual**~~: **resolvido** em 15/11/2026 (logomarca `CashBookCMJ/Logomarca.jpg`, cores vermelho `#D43414` e cinza `#A8A8A8`, tudo em parâmetros; razão social e CNPJ vêm da licença). Falta só o CNPJ real da CMJ para a licença de produção.
6. **Servidor da empresa** (já se sabe: servidor **dedicado com Windows 11 Pro**, informado em 16/11/2026; Ryzen 5, 16 GB, SSD 240 GB + HD 1 TB; o SQL Server 2025 Express aceita Windows 10 ou mais novo): falta (as versões atuais do SQL Server Express e do .NET pedem Windows Server 2016 ou mais novo; se for mais antigo, ajustar as versões), a versão do SQL Server Express, se já existe instância, servidor SMTP/conta de envio (Microsoft 365, Google, provedor próprio), certificado para HTTPS.
7. ~~Schemas~~: **resolvido** em 14/11/2026 (schemas por bloco, PADRAO_SQL regra 31).
8. ~~**Multiempresa**~~: **resolvido** em 16/11/2026 (`CAD.Empresa` livre, várias empresas; licença com um CNPJ só).
9. **Perfis de usuário**: quem pode baixar título, estornar, cancelar contrato, ver dashboards.
10. **E-mail da CMJ**: a empresa já tem e-mail no próprio domínio? Qual provedor? Dá para criar uma caixa só para envio do sistema?
11. **Assinatura digital**: a CMJ quer? Qual plataforma (FastSign, ZapSign, outra)? Quem assina pela CMJ? Precisa de testemunhas?
13. **Medição de empreitada** (a confirmar no desenho da `OBRA`): retenção técnica? histórico de aditivos? medir além do contratado bloqueia ou só alerta? descontos dos funcionários do empreiteiro geram lançamento próprio ou só abatem da medição? (`docs/requisitos/Medicao_Empreitada.md`, seção 4)
14. **Compras** (desenho em `docs/requisitos/Modulo_Compras.md`, seção 8): quem pede (obra ou escritório)? quem aprova e a partir de que valor? quantas cotações? quem confere a entrega? controla estoque de obra? paga adiantado? a nota chega antes, junto ou depois da entrega?
15. ~~**GitHub**~~: **resolvido** em 16/11/2026 (repositório privado `celsofreitas62/ConstrutoraCMJ`, remoto `origin`; primeiro envio pelo Celso).
12. **Volume**: quantos contratos ativos e quantos boletos por mês, em média (define o limite de envio de e-mail e o tamanho do banco).

**A fazer quando for preciso (lembretes do Celso)**:
- **Valor por extenso** (pedido em 15/11/2026): rotina que devolve um valor em reais por extenso ("mil duzentos e trinta e quatro reais e cinquenta e seis centavos"), para contratos, recibos, termo de quitação, declaração de IR e outros usos. Pela regra 30 do PADRAO_SQL (só leitura, devolve um valor) será a function `SIS.fn_SIS_Valor_Extenso`; fazer antes do contrato de venda (fase 5) ou quando a primeira rotina precisar.

## 7. Plano de trabalho (fases, revisto em 16/11/2026)

**Versão 1 = o mínimo para a CMJ largar o Access** (aprovado em 16/11/2026; o conteúdo exato pode ser ajustado pelo Celso): cadastros; contas a pagar e a receber com baixa, caixa e conciliação pelo OFX; vendas com plano de pagamento, parcelas e reajuste; boleto Sicredi (remessa, retorno, e-mail ao cliente); relatórios do dia a dia (agenda da semana, a pagar/receber, extratos de cliente e fornecedor, fechamento para a contabilidade); arquivo morto (consulta); migração do Access.

**Depois da virada (versões 1.x)**: Compras, medição de empreitada, custo de obra completo (orçado x realizado), painel com drill-down, assinatura digital, comissão, alçada de aprovação, retenções, botões de instalação pela tela (lado da API) e os demais itens da seção 3.3 que não forem indispensáveis no dia 1.

| Fase | Conteúdo | Situação |
|---|---|---|
| 1 | Levantamento do Access | concluída (15/11/2026) |
| 2 | Base `SIS` (02a a 02d) | concluída (16/11/2026) |
| 3a | `CAD` + cadastro do `BANCO` (SQL) | concluída (16/11/2026) |
| 3b | **Esqueleto da API** (login, sessão, chamada de procedure, menu) + **primeira tela no navegador** (Pessoas) | concluída (16/11/2026) |
| 3c | Desenho do `FIN` + arquivo morto + **ensaio da migração do movimento** com os dados reais | **próxima** |
| 3d | **Ensaio da instalação no servidor da CMJ** (SQL Express, .NET 10, serviço do Windows, HTTPS na rede, firewall, acesso da Renata pelo computador dela) + **backup automático com teste de restauração** + proteções de operação (limite de tentativas de login por computador, registro da API em arquivo, endereço de "saúde") + **controle de versão do banco** (programa e banco na mesma versão) + **teste automático da API** | |
| 4 | Telas dos cadastros e do financeiro (agenda, pagar/receber, baixa, caixa, conciliação) | |
| 5 | `IMOB` + `VENDA` (empreendimento, unidades, espelho, contrato, parcelas, reajuste) | |
| 6 | `COBR` Sicredi (remessa, retorno, PDF, e-mail) | |
| 7 | Relatórios essenciais + ajuda das telas | |
| 8 | Migração final, roteiro de instalação, **uso em paralelo** com o Access, treinamento do usuário-chave, **virada** | |
| 1.x | Itens de "depois da virada" | |

## 8. Estrutura da pasta

```
C:\SistemaCMJ\            (sincronizada com o Google Drive)
├── CLAUDE.md            este arquivo (contexto e estado do projeto)
├── padroes/             padrão SQL, padrão de e-mail, gabaritos, boas práticas
├── CashBookCMJ/         sistema Access legado (.mdb), só leitura
├── legado/              material extraído do Access
├── sql/
│   ├── local/           scripts só do desenvolvimento (ex.: criar o SISTEMACMJ_LOCAL)
│   ├── objetos/<BLOCO>/ arquivo de trabalho de cada objeto (um por objeto; _GERAL = schemas), testado no SISTEMACMJ_LOCAL
│   ├── pacotes/         pacote de cada parte, gerado juntando os arquivos de objetos/ na ordem da regra 59 (não editar à mão)
│   ├── testes/<BLOCO>/  scripts de homologação (só LOCAL; mostram ESPERADO x OBTIDO)
│   ├── ferramentas/     montar_pacote.py: o Claude gera os pacotes juntando os arquivos de objetos/ (normaliza CRLF/BOM)
│   └── MASTER/          SISTEMACMJ_MASTER_Instalacao.sql (só o que o Celso aprovou)
├── PlanilhasCMJ/        planilhas de trabalho da CMJ (ex.: Medição.xlsx), referência; fora do Git (dados pessoais)
├── docs/                proposta, roteiro de instalação, layouts Sicredi, manuais; identidade/ (logomarcas); requisitos/ (pedidos detalhados)
└── Padrao_SQL/          material de referência do padrão de origem (não faz parte do sistema)
```

## 9. Como trabalhar neste projeto (para o Claude)

- Responder e documentar **em português do Brasil**.
- **Sempre perguntar ao Celso o próximo passo antes de começar o desenvolvimento dele** (regra do Celso, 15/11/2026): apresentar a proposta e esperar a confirmação. O sistema será **modernizado**: nada do Access é reaproveitado do jeito que foi feito sem o Celso confirmar; o levantamento em `legado/` serve para entender dados e regras, não como modelo a copiar.
- **Avisar o Celso quando for hora de abrir uma conversa nova** (fim de etapa), dizendo o nome da próxima conversa.
- **A cada mudança de fase, dar ao Celso a opinião do Claude sobre o andamento e sugestões de melhoria** pelas boas práticas de mercado, em que ele talvez não tenha pensado (pedido do Celso, 16/11/2026). As sugestões são propostas: só entram no projeto com a aprovação dele.
- Aplicar sempre os padrões de `padroes/` sem precisar ser lembrado; se algo conflitar, perguntar antes.
- Antes de assumir nome/tipo de campo, ler o DDL em `sql/` ou o levantamento em `legado/`. Nunca adivinhar.
- Desenvolver e testar no `SISTEMACMJ_LOCAL`; o usuário promove para produção.
- Toda rotina financeira é **tudo-ou-nada** e auditada (quem, quando, antes/depois).
- Ao final de cada etapa, atualizar as seções 0, 6 (pendências) e 7 (fases) deste arquivo e o diário (`docs/DIARIO_DECISOES.md`).
- **Commits feitos pelo Claude** (pedido do Celso, 16/11/2026): depois de cada etapa/ajuste homologado e de cada registro de decisões, fazer `git add -A` + `git commit` na pasta pelo shell do notebook, com a mensagem no padrão ("02c: ...") e as linhas de atribuição; avisar o código do commit. Na conversa nova, pedir uma vez a permissão de apagar na pasta (o Git precisa apagar os `.lock`). **`git push` também automático** (autorizado pelo Celso em 16/11/2026): depois de cada commit, enviar para o `origin` quando o ambiente conseguir. **Hoje o ambiente do Claude não alcança o GitHub**: avisar o Celso para dar dois cliques em `enviar_github.cmd` (raiz da pasta). Nunca `reset`, `rebase`, push forçado ou apagar histórico sem o Celso pedir.

## 10. Diário de decisões

Movido para [docs/DIARIO_DECISOES.md](docs/DIARIO_DECISOES.md) em 16/11/2026. Toda decisão nova vai para o fim daquele arquivo, na hora.
