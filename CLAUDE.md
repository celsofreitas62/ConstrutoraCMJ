# SistemaCMJ

> Nome do projeto definido em 14/11/2026 (antes chamado **CashBookCMJ**, nome que continua só na pasta do Access legado `CashBookCMJ/`).

Sistema de gestão financeira e de vendas de imóveis da **Construtora CMJ** (razão social a confirmar). Projeto particular de **Celso de Freitas**, desenvolvido com o Claude. Substitui o sistema atual em **Microsoft Access (.mdb)**, que funciona mas está obsoleto.

> Este arquivo é o ponto de partida de toda sessão. Ler também, sempre que for escrever SQL ou e-mail:
> - [padroes/PADRAO_SQL.md](padroes/PADRAO_SQL.md): regras obrigatórias de T-SQL
> - [padroes/PADRAO_EMAIL.md](padroes/PADRAO_EMAIL.md): padrão de e-mails e avisos (fila + processador)
> - [padroes/GABARITOS.md](padroes/GABARITOS.md): esqueletos de procedure, trigger, function e orquestrador de e-mail
> - [padroes/BOAS_PRATICAS.md](padroes/BOAS_PRATICAS.md): como trabalhamos (ambientes, autorização, entrega de scripts, testes)
> - [padroes/ORIGEM_PADRAO.md](padroes/ORIGEM_PADRAO.md): mapa regra a regra do padrão de origem do Celso para este projeto
> - [docs/GUIA_DO_CELSO.md](docs/GUIA_DO_CELSO.md): guia do Celso (como abrir cada conversa, frases úteis, Git, o que só ele faz). Manter atualizado quando o modo de trabalhar mudar.
>
> **Regra geral: tudo neste projeto segue o padrão profissional do Celso** (o "padrão Togni" que ele usa no trabalho), adaptado só onde a tecnologia é diferente (sem DataFlex, SQL Server Express). Se o Celso citar uma regra pelo número de origem, procurar no mapa `ORIGEM_PADRAO.md`.
>
> Manter este arquivo atualizado a cada decisão tomada, item concluído ou regra nova (seção "Diário de decisões" no fim).

---

## 0. Estado atual e como retomar (atualizar sempre)

**Situação em 13/11/2026**: proposta comercial pronta (`docs/Proposta_Comercial_CMJ.pdf`) e sendo enviada pelo Celso à CMJ. **Desenvolvimento só começa se a proposta for aprovada.** A conversa inicial foi feita em outro computador; este `CLAUDE.md` e a pasta `padroes/` guardam tudo o que foi decidido. O projeto continua no Claude particular do Celso, no laptop dele.

**Situação em 14/11/2026**: ambiente de desenvolvimento instalado e conferido no notebook do Celso (seção 4.2). Aprovados: nome do projeto, nomes dos bancos, API em ASP.NET Core, arquivo MASTER de instalação, schemas por bloco e nova nomenclatura (diário, seção 10). O Celso está elaborando as próximas definições de padrão.

**Situação em 14/11/2026 (conversa "01 – Git e levantamento do Access")**: **Git ligado** em `C:\SistemaCMJ` (branch `main`, 1º commit `cc80ec7`). Criado `docs/GUIA_DO_CELSO.md`. O levantamento do Access fica para a próxima conversa. **O Celso vai instalar o Microsoft Access no notebook em 15/11/2026**; com o Access instalado, a extração de tabelas, consultas, formulários e VBA pode ser feita direto pelo Access.

**Situação em 15/11/2026 (conversa "01b – Levantamento do Access", em andamento)**: os `.mdb` são **Jet 4 (formato Access 2000/2003)**. Nem o notebook nem as máquinas de trabalho do Claude têm leitor de `.mdb` (sem `mdbtools`, sem driver ACE, sem internet para instalar). Caminho escolhido: **extração pelo próprio Access**, com o script `legado/ferramentas/Extrair_Access.ps1` (estrutura, índices, relações, contagens, SQL das consultas, formulários/relatórios/macros/VBA por `SaveAsText`, referências do VBA; com `-ExportarDados`, dados em CSV UTF-8 em `legado/dados_brutos/`, fora do Git). Aguardando o Celso instalar o Access e rodar o script; depois o Claude analisa a saída e escreve `legado/schema_access.md` e o relatório de regras de negócio.

**Situação em 15/11/2026, 10h (conversa 01b)**: extração **concluída sem erros** na base atual e na base de 2015. Levantamento escrito em `legado/schema_access.md` (tabelas, movimento, comparação das três fontes de movimento, qualidade dos dados, telas e relatórios). Conclusão principal: a base de 2015 é um backup antigo e não traz dado novo (aguardando confirmação do Celso). Pontos para o Celso decidir: seção 7 do `schema_access.md`.

**Ao retomar, primeiro** (atualizado em 15/11/2026, fim da conversa 01b):
1. Perguntar ao Celso se a proposta foi aprovada (e se entrou a cláusula de licença de uso, seção 3.5) e se já tem as respostas pendentes: versão do Windows do servidor, as 4 perguntas da seção 3.3 e as 3 decisões do levantamento (`legado/schema_access.md`, seção 7: base 2015 fora da migração? histórico desde 2008 ou a partir de um ano? materiais/modelos/cheques continuam?).
2. **Próximo passo confirmado pelo Celso (15/11/2026)**: **Fase 2, base `SIS`**, na conversa **"02 – Base SIS"**: licença, parâmetros, usuários/permissões, auditoria, lote, anexo, log, fila de e-mail (seções 3.4 a 3.7), seguindo `padroes/`. **Antes de escrever qualquer script, apresentar a proposta de tabelas e procedures e esperar a confirmação do Celso** (regra da seção 9).
3. Fase 1 (levantamento) **concluída** em 15/11/2026: material em `legado/` (ver `legado/schema_access.md`). As regras de cada tela antiga (parcelas, reajuste, pagamento em lote, transferências) serão lidas do VBA (`legado/extracao/objetos/`) quando cada módulo for desenhado, e levadas ao Celso para decidir o que modernizar.
4. Trabalho organizado em **uma conversa por etapa**, dentro do projeto **SistemaCMJ** no Claude; cada conversa começa lendo este arquivo e termina atualizando esta seção.
5. **Ao fechar cada etapa, avisar o Celso** para abrir uma conversa nova dentro do projeto, com o nome da próxima etapa (lista em `docs/GUIA_DO_CELSO.md`, seção 3), e escrever "Vamos continuar o SistemaCMJ".

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

Schemas aprovados (14/11/2026): `CAD`, `BANCO`, `IMOB`, `VENDA`, `FIN`, `COBR`, `OBRA`, `GER`, `SIS` e `MIG` (só migração). Nomenclatura: PADRAO_SQL regras 29 a 31.

1. **Cadastros**: em `CAD`: empresa(s), clientes (PF/PJ, cônjuge/coobrigado, contatos, endereço), fornecedores, plano de contas, centros de custo. Em `IMOB`: empreendimentos/obras, blocos e unidades (tipo, área, valor de tabela, situação: disponível / reservada / vendida / distratada), índices de correção. Em `BANCO`: bancos e contas bancárias.
2. **Vendas (`VENDA`)**: proposta/reserva → contrato de venda → plano de pagamento (entrada/sinal, mensais, intermediárias/balões, parcela das chaves, saldo financiado) → **geração das parcelas** como títulos a receber → aditivos, renegociação, distrato, quitação. Impede vender a mesma unidade duas vezes (UPDLOCK).
   - **Contrato gerado pelo sistema**: modelo (minuta) com campos preenchidos a partir da venda (comprador, cônjuge, unidade, valores, plano de pagamento); cada geração vira uma **versão** gravada; só a última versão sem pendências pode ir para assinatura.
   - **Assinatura digital (opcional, se a CMJ quiser)**: mesmo desenho já usado pelo Celso em produção num projeto anterior (contrato de prestador de serviço). Plataforma via API (FastSign, ZapSign ou outra que a CMJ escolher; o plano é pago pela CMJ). Fluxo: cadastro dos signatários (comprador, cônjuge/coobrigado, representante da CMJ, testemunhas) → **Enviar para assinatura** (o serviço manda o PDF pela API, guarda o ID do documento e os links) → acompanhamento de quem já assinou (botão **Verificar** + verificação automática ao abrir a venda e rotina agendada, porque o servidor não tem endereço público para receber aviso da plataforma) → ao concluir, **baixa o PDF assinado**, guarda junto da venda, situação `ASSINADO` e grava a data real de assinatura → **Cancelar** envio, se necessário. Chamada HTTP sempre pelo serviço com fila e idempotência (PADRAO_SQL regra 53); token da plataforma nunca em tabela nem em log (regra 54). Testar primeiro no ambiente de teste (sandbox) da plataforma.
3. **Financeiro (`FIN`)**: títulos a pagar e a receber, baixas totais/parciais, juros/multa/desconto, estornos, transferências entre contas, caixa. Extrato e conciliação bancária ficam em `BANCO`.
4. **Cobrança (`COBR`)**: carteira Sicredi, geração de **nosso número**, arquivo de **remessa**, leitura do **retorno** (liquidação, baixa, rejeição, tarifas), PDF do boleto, envio por e-mail ao cliente, 2ª via.
5. **Custos de obra (`OBRA`)**: orçamento por obra/etapa, lançamentos de custo (vindos do contas a pagar com obra/centro de custo), realizado x orçado, custo por m².
6. **Gerencial (`GER`)**: dashboard e relatórios com drill-down (fluxo de caixa diário/mensal realizado + projetado, recebíveis por empreendimento, inadimplência por faixa de atraso, vendas por período, custo por obra).
7. **Sistema (`SIS`)**: usuários e permissões, parâmetros, grupos de e-mail, fila de e-mail, log de erros, histórico de alterações, agenda das rotinas.
8. **Menu do sistema (pedido do Celso, 15/11/2026)**: se possível, **menu lateral em drill-down**: barra à esquerda com os módulos; clicar no módulo abre os itens/telas dele (e subníveis, se houver) na própria barra, com volta ao nível anterior. Só aparecem os módulos liberados na licença (3.5) e os itens permitidos ao usuário (3.6). Definir o desenho na fase das telas (fase 4, Cadastros).
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
- O Sicredi da CMJ disponibiliza o extrato em **OFX**? (quase todo internet banking tem)
- A CMJ trabalha com mais de uma conta bancária / mais de um banco?
- Os relatórios da contabilidade são por regime de caixa ou de competência?

## 3.4 Parametrização total (decidido em 14/11/2026)

**Nada fixo no código**: percentuais (multa, juros, desconto), dias (carência, aviso de vencimento, régua de cobrança), contas padrão, e-mails, textos de e-mail, limites de alçada, índices etc. ficam em `SIS.Parametro` (chave, valor, tipo, descrição, módulo, quem alterou e quando), editáveis numa tela do administrador e **auditados**. Regra já prevista no PADRAO_SQL (regra 33), agora obrigatória para tudo.

## 3.5 Licença, módulos e proteção contra cópia (decidido em 14/11/2026)

Objetivo do Celso: só ele (desenvolvedor) habilita módulos e define empresa/CNPJ; o sistema não funciona se for copiado para outro servidor ou computador sem autorização; ele pode instalar módulo novo no cliente que fica **desligado até ele liberar**.

Desenho:
- **Chave de licença assinada digitalmente** pelo Celso (par de chaves: a privada fica só com ele; a pública vai embutida na API). A chave contém: razão social, CNPJ, **identificação do servidor** autorizado, módulos liberados e, se ele quiser, data de validade.
- A licença fica gravada em `SIS.Licenca`. A **API confere a assinatura** ao iniciar e a cada login: assinatura inválida, CNPJ diferente ou servidor diferente → sistema não abre (só a tela de "licença inválida"). Módulo não liberado → não aparece no menu e a API recusa as chamadas dele.
- **Razão social e CNPJ** dos relatórios, e-mails e boletos vêm da licença: ninguém altera por tela.
- **Gerador de licença**: programa pequeno, só no computador do Celso, que gera a chave (nunca vai para o cliente).
- **Limite honesto**: num servidor que é do cliente, nenhuma proteção é impossível de quebrar por quem tem acesso de administrador ao Windows e ao SQL; isto impede o uso e a cópia casuais e deixa claro que a cópia é proibida. A proteção completa vem junto com o **contrato** (cláusula de licença de uso: o código-fonte e os direitos ficam com o desenvolvedor). A proposta atual diz só "sem custo de licença": avaliar incluir essa cláusula antes do envio.
- **Papéis**: o **desenvolvedor** não é usuário do dia a dia; ele atua pela licença. O **administrador do sistema** (alguém da CMJ) tem acesso geral e cuida dos usuários e permissões, mas **não** libera módulos nem altera empresa/CNPJ.

## 3.6 Usuários e permissões (decidido em 14/11/2026)

- Cadastro de usuários feito pelo **administrador do sistema**.
- Três níveis: **Módulo** (ex.: Financeiro) → **Item/tela** (ex.: Títulos a pagar) → **Ação**: ver, incluir, alterar, excluir, e ações especiais da tela (baixar, estornar, cancelar contrato, reabrir mês, exportar, ver painel).
- **Perfis** (ex.: Financeiro, Vendas, Consulta) com as permissões; cada usuário recebe um perfil e o administrador pode dar ou tirar permissões individuais além do perfil.
- Tabelas previstas em `SIS`: `Modulo`, `Item`, `Acao`, `Perfil`, `Perfil_Permissao`, `Usuario`, `Usuario_Permissao`. Toda procedure chamada pela API confere a permissão antes de agir; a tela esconde o que o usuário não pode fazer.
- Senha com hash forte, troca obrigatória no primeiro acesso, bloqueio após tentativas erradas, registro de login/logout.

## 3.7 Follow-up de movimentações / auditoria (decidido em 14/11/2026, "importante")

- **Toda inclusão, alteração e exclusão** em tabela de negócio grava em `SIS.Auditoria`: tabela, ID do registro, operação (I/A/E), campo, **valor antes**, **valor depois**, usuário, data/hora, estação, tela/rotina de origem e lote.
- Gravação por trigger set-based em cada tabela (padrão do gabarito de trigger), com o usuário vindo da API via `SESSION_CONTEXT`.
- **Ninguém altera nem apaga a auditoria**, nem o administrador.
- Consulta: aba **"Histórico"** em toda tela de manutenção (quem fez o quê naquele registro) e uma tela geral de consulta com filtros por usuário, período, tabela, registro e operação.

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
| Backup agendado + cópia para outro disco | fácil | Agendador de Tarefas + script |
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
- **`ArquivoMorto` deixa de existir** (decidido em 15/11/2026): no Access é a tabela de movimentos antigos arquivados (147.866 registros, **mesmos 43 campos** de `F Movimento Contas`, que tem 101.612). Na migração os dois são **unidos no movimento único do sistema novo** (modelo da seção 3.2), guardando de qual tabela veio cada registro (origem `ACCESS_MOVTO` / `ACCESS_ARQMORTO`) para a conferência. Cuidar de chave repetida entre as duas tabelas e de movimento que esteja nas duas. O sistema novo não terá "arquivo morto": histórico fica no mesmo lugar, filtrado por data/situação.
- **Migração**: tabelas de *staging* (`mig.*`) recebendo o Access cru → procedures de transformação para o modelo novo → relatório de conferência (contagens e totais por cliente/contrato/obra batendo com o Access) → carga final em produção. Repetível quantas vezes for preciso até a virada.

## 6. Decisões pendentes (perguntar ao Celso)

> O Celso vai responder oportunamente, conforme tiver as informações em mãos. Não bloquear o trabalho por causa delas: seguir com o que não depende da resposta e relembrar as pendências relevantes no início de cada etapa. Ao receber uma resposta, mover o item para o "Diário de decisões".

1. ~~Camada de API~~: **resolvido** em 14/11/2026 (ASP.NET Core).
2. ~~Caminho do .mdb~~: **resolvido** em 14/11/2026 (pasta `CashBookCMJ/`, dividido em front-end e back-end).
3. **Sicredi**:
   - layout do arquivo: **CNAB 240** ou **CNAB 400**? (confirmar com o gerente / manual que o banco entregou para a conta da CMJ);
   - quem **emite** o boleto: o banco ou a CMJ (o sistema gera o PDF com código de barras e linha digitável)? "Receber os boletos do banco" sugere emissão pelo banco: confirmar como os PDFs chegam;
   - avaliar a **API de Cobrança do Sicredi** (registro on-line, PDF e baixa sem troca de arquivo) como alternativa ou evolução do CNAB;
   - cooperativa, posto, código do beneficiário, carteira, regras de multa/juros/desconto/protesto.
4. **Correção das parcelas**: há correção monetária (ex.: INCC durante a obra, IGP-M/IPCA após as chaves)? Juros de tabela Price/SAC no saldo? Como o Access faz hoje?
5. **Identidade visual**: logotipo, cor institucional da CMJ, razão social e CNPJ para rodapé de e-mail e relatórios.
6. **Servidor da empresa** (já se sabe: servidor **dedicado com Windows**): falta a versão do Windows (as versões atuais do SQL Server Express e do .NET pedem Windows Server 2016 ou mais novo; se for mais antigo, ajustar as versões), a versão do SQL Server Express, se já existe instância, servidor SMTP/conta de envio (Microsoft 365, Google, provedor próprio), certificado para HTTPS.
7. ~~Schemas~~: **resolvido** em 14/11/2026 (schemas por bloco, PADRAO_SQL regra 31).
8. **Multiempresa**: a CMJ tem mais de um CNPJ / SPE por empreendimento?
9. **Perfis de usuário**: quem pode baixar título, estornar, cancelar contrato, ver dashboards.
10. **E-mail da CMJ**: a empresa já tem e-mail no próprio domínio? Qual provedor? Dá para criar uma caixa só para envio do sistema?
11. **Assinatura digital**: a CMJ quer? Qual plataforma (FastSign, ZapSign, outra)? Quem assina pela CMJ? Precisa de testemunhas?
12. **Volume**: quantos contratos ativos e quantos boletos por mês, em média (define o limite de envio de e-mail e o tamanho do banco).

## 7. Plano de trabalho (fases)

1. **Levantamento**: extrair o Access (estrutura, consultas, VBA, volume) e documentar em `legado/`. Fechar as decisões pendentes. **Concluído em 15/11/2026** (`legado/schema_access.md`); restam as 3 decisões da seção 7 desse arquivo.
2. **Modelo de dados** em SQL (arquivos em `sql/objetos/<BLOCO>/`) + base `SIS` (usuários, parâmetros, log, fila de e-mail, grupos).
3. **Serviço/API** esqueleto: login, chamada genérica de procedure, processador da fila de e-mail, agendador.
4. **Cadastros** (telas HTML + procedures).
5. **Vendas + geração de parcelas.**
6. **Financeiro** (pagar/receber, baixas, caixa, conciliação).
7. **Cobrança Sicredi** (remessa, retorno, PDF, e-mail ao cliente).
8. **Custos de obra.**
9. **Dashboards e relatórios** com drill-down.
10. **Migração** dos dados do Access (ensaios repetidos + conferência) e **virada** para produção.

## 8. Estrutura da pasta

```
C:\SistemaCMJ\            (sincronizada com o Google Drive)
├── CLAUDE.md            este arquivo (contexto e estado do projeto)
├── padroes/             padrão SQL, padrão de e-mail, gabaritos, boas práticas
├── CashBookCMJ/         sistema Access legado (.mdb), só leitura
├── legado/              material extraído do Access
├── sql/
│   ├── objetos/<BLOCO>/ arquivo de trabalho de cada objeto, testado no SISTEMACMJ_LOCAL
│   └── MASTER/          SISTEMACMJ_MASTER_Instalacao.sql (só o que o Celso aprovou)
├── docs/                proposta, roteiro de instalação, layouts Sicredi, manuais
└── Padrao_SQL/          material de referência do padrão de origem (não faz parte do sistema)
```

## 9. Como trabalhar neste projeto (para o Claude)

- Responder e documentar **em português do Brasil**.
- **Sempre perguntar ao Celso o próximo passo antes de começar o desenvolvimento dele** (regra do Celso, 15/11/2026): apresentar a proposta e esperar a confirmação. O sistema será **modernizado**: nada do Access é reaproveitado do jeito que foi feito sem o Celso confirmar; o levantamento em `legado/` serve para entender dados e regras, não como modelo a copiar.
- **Avisar o Celso quando for hora de abrir uma conversa nova** (fim de etapa), dizendo o nome da próxima conversa.
- Aplicar sempre os padrões de `padroes/` sem precisar ser lembrado; se algo conflitar, perguntar antes.
- Antes de assumir nome/tipo de campo, ler o DDL em `sql/` ou o levantamento em `legado/`. Nunca adivinhar.
- Desenvolver e testar no `SISTEMACMJ_LOCAL`; o usuário promove para produção.
- Toda rotina financeira é **tudo-ou-nada** e auditada (quem, quando, antes/depois).
- Ao final de cada etapa, atualizar as seções 6 (pendências), 7 (fases) e 10 (diário) deste arquivo.

## 10. Diário de decisões

- **13/11/2026**: projeto iniciado. Decidido: SQL Server Express + T-SQL puro, frontend HTML, sem DataFlex; mesmo padrão de SQL e de e-mails que o autor usa profissionalmente (adaptado em `padroes/`); boleto Sicredi com remessa/retorno e envio do boleto por e-mail ao cliente; dashboards com drill-down; migração completa dos dados do Access. Como o Express não tem Agent nem Database Mail, e-mails viram **fila no SQL + envio pelo serviço da aplicação**, e as rotinas agendadas rodam no serviço.
- **13/11/2026**: restrição definida: **todo software do projeto tem de ser gratuito para uso comercial** (seção 2.1). Confirmado que é viável: SQL Server Express, .NET ou Node.js, bibliotecas MIT/Apache, SMTP da conta de e-mail que a CMJ já tiver. As pendências da seção 6 serão respondidas pelo Celso aos poucos.
- **13/11/2026**: o servidor da CMJ é **dedicado, com Windows**; versão ainda não informada.
- **13/11/2026**: proposta comercial redigida em `docs/Proposta_Comercial_CMJ.html` (fonte editável) e `.pdf`: R$ 1.800,00/mês nos meses 1-6 (desenvolvimento e implantação) + R$ 900,00/mês nos meses 7-12 (acompanhamento, ajustes, novas solicitações) = R$ 16.200,00 em 12 meses; resgate do Access e treinamento incluídos; escopo = tudo dentro do sistema, fora disso conversado antes. Ainda não enviada; telefone/e-mail de contato e condições de pagamento a confirmar pelo Celso.
- **13/11/2026**: proposta revisada: retirado "tudo o que a CMJ pedir"; meses 7-12 cobrem ajustes só em **contas a pagar, a receber (com boletos) e vendas**, até **8 h/mês** (correção de defeito sempre sem custo); excedente ou fora dessas áreas a **R$ 100/h** com aprovação prévia; nova seção "Depois dos 12 meses" com **suporte opcional de R$ 400/mês** (até 4 h de ajustes) e reajuste anual pelo IPCA; contato do Celso no rodapé. Os valores de 8 h, R$ 100/h e R$ 400 foram sugestão do Claude, sujeitos a ajuste. Em avaliação: trocar a divisão para 9 meses × R$ 1.800 + 3 meses × R$ 900 (R$ 18.900).
- **13/11/2026**: arquitetura **confirmada pelo Celso**: **SQL puro + HTML, sem DataFlex**. As tabelas SQL são desenhadas a partir do levantamento do Access (estrutura e dados reais); toda a regra de negócio fica em T-SQL (procedures, triggers, functions, views); as telas são HTML/CSS/JavaScript. A única peça entre os dois é uma **ponte fina** (API), necessária porque o navegador não conecta direto no SQL Server e porque o Express não tem Agent nem Database Mail. Ela **não tem regra de negócio**: só faz login, chama a procedure, devolve o resultado em JSON, envia os e-mails da fila e dispara as rotinas agendadas.
- **13/11/2026**: avaliado o SQL Server **Standard** (que tem Agent e Database Mail) para 3 usuários: licença Servidor + CAL, cerca de US$ 989 pelo servidor + US$ 230 por usuário (preço de lista de referência) ≈ US$ 1.700 a 1.900, algo em torno de **R$ 10 a 14 mil** com câmbio, impostos e margem de revenda (cotar com revenda Microsoft). Por núcleo (mínimo 4 núcleos) passaria de R$ 40 mil. **Conclusão: não compensa**: a ponte (API) é necessária de qualquer jeito, então colocar nela o envio de e-mail e o agendamento custa pouco; e o Express 2025 subiu o limite para 50 GB. **Express confirmado pelo Celso (13/11/2026).** Se a CMJ quiser Standard no futuro, a migração é só trocar a edição (mesmo banco, mesmo código).
- **13/11/2026**: incluído na proposta e no escopo: **contrato de venda gerado pelo sistema** e **assinatura digital opcional** (FastSign, ZapSign ou outra), dentro do valor do desenvolvimento (mês 3); plano da plataforma pago pela CMJ. Ajuda geral + ajuda por página também já constam na proposta.
- **13/11/2026**: proposta final (ainda não enviada): **9 meses × R$ 1.800 (desenvolvimento e implantação) + 3 meses × R$ 900 (acompanhamento e ajustes) = R$ 18.900**. Cronograma: mês 1 levantamento/resgate Access/servidor · 2 cadastros · 3 vendas e parcelas · 4 pagar/receber/caixa · 5 boletos Sicredi e e-mail · 6 custo de obra · 7 painel e relatórios · 8 conferência final, treinamento, início do uso · 9 acompanhamento e acertos · 10-12 ajustes em pagar/receber/vendas. **Sem limite de horas e sem valor por hora**: pedidos fora de pagar/receber/vendas são analisados e orçados à parte. Correção de defeito sempre sem custo. Suporte opcional após 12 meses: R$ 400/mês, reajuste anual IPCA.
- **14/11/2026**: ambiente de desenvolvimento instalado no notebook do Celso (seção 4.2): SQL Server 2025 Express na instância `.\SQL2025`, SSMS 22, .NET SDK 11, VS Code com extensões, Git.
- **14/11/2026**: projeto passa a se chamar **SistemaCMJ** (era CashBookCMJ). Bancos: **`SISTEMACMJ_LOCAL`** (desenvolvimento) e **`SISTEMACMJ`** (produção). Pasta oficial: `C:\SistemaCMJ`, sincronizada com o Google Drive.
- **14/11/2026**: API definida: **ASP.NET Core (C#)**, alvo **.NET 10 LTS** no servidor (o .NET 11 é STS; os dois perdem suporte por volta de nov/2028, mas o 10 tem um ano a mais de uso em produção). Node.js descartado.
- **14/11/2026**: instalação no cliente por **um único arquivo MASTER** (`sql/MASTER/SISTEMACMJ_MASTER_Instalacao.sql`), idempotente. Tudo é criado e testado livremente no LOCAL; só entra no MASTER o que o Celso aprovar. Junto, um **roteiro passo a passo** de instalação do servidor (`docs/Roteiro_Instalacao_Servidor.md`, a escrever). PADRAO_SQL regras 58 a 60.
- **14/11/2026**: **schemas por bloco** aprovados: `CAD`, `BANCO`, `IMOB`, `VENDA`, `FIN`, `COBR`, `OBRA`, `GER`, `SIS`, `MIG` (fora do MASTER). **Nomenclatura** aprovada: tabela `SCHEMA.Entidade` (singular, sem prefixo); procedure `SCHEMA.BLOCO_Entidade_Acao` (sem `tsp_`, nunca `sp_`; ações `Listar/Obter/Gravar/Excluir/Gerar/Processar/Baixar/Estornar/Enviar`); `fn_`, `vw_`, `tg_`, `seq_` + bloco; restrições `PK_/FK_/IX_/UQ_/CK_/DF_` com nome fixo. Substitui as antigas regras 29 e 31 do PADRAO_SQL. Gabaritos e exemplos dos `padroes/` atualizados para os novos nomes. Na dúvida sobre o bloco de um objeto, perguntar ao Celso.
- **14/11/2026**: recebidos os pedidos de funcionamento do cliente (seção 3.1): agenda da semana como tela de abertura com filtros e busca por parte do nome, clique abre a manutenção; número de lote em tudo que é gerado junto; **lançamento único integrado no lugar do débito/crédito dobrado do Access**; conciliação bancária; fechamento contábil para a contabilidade; anexos em lançamentos e vendas. Proposto o modelo financeiro (seção 3.2) e 20 sugestões de mercado (seção 3.3), **aguardando aprovação**. Pendente: versão do Windows do servidor (o Celso vai perguntar).
- **14/11/2026**: o Celso **aprovou o modelo financeiro (3.2) e as 20 sugestões de mercado (3.3)**. As 4 perguntas (contabilidade, OFX, contas bancárias, caixa x competência) ficam pendentes: ele vai perguntar à CMJ.
- **14/11/2026**: decididos: **parametrização total** (3.4); **licença assinada digitalmente** com empresa, CNPJ, servidor e módulos, só o desenvolvedor libera módulo, sistema não roda se copiado (3.5); **usuários e permissões** por módulo → item → ação, geridos pelo administrador da CMJ (3.6); **auditoria completa** de inclusão/alteração/exclusão com antes/depois e consulta por tela (3.7). Recomendado incluir cláusula de licença de uso/propriedade do código na proposta.
- **14/11/2026**: criados `.gitignore` (sem `.mdb`, `CashBookCMJ/`, `Padrao_SQL/`, pasta temporária do Drive, segredos, `bin/obj`) e `.gitattributes` (`* -text`: Git não altera CRLF/BOM). O `git init` e o 1º commit são feitos pelo Celso no PowerShell do notebook. Criado `docs/GUIA_DO_CELSO.md` (como usar o Claude no projeto, nomes das conversas por etapa, frases úteis, Git). Combinado: ao fim de cada etapa, o Claude lembra o Celso de abrir a conversa da próxima etapa.
- **14/11/2026**: **Git ligado** pelo Celso em `C:\SistemaCMJ` (branch `main`, commit `cc80ec7`, 11 arquivos). `padroes/Scripts.sql` (script completo do banco `DBTOGNI_PROD`, da empresa de origem do padrão) ficou **fora do Git** (`.gitignore`), pelo mesmo motivo de `Padrao_SQL/`: informação interna de outra empresa não entra no repositório do SistemaCMJ. Sugestão (ainda não feita): mover esse arquivo para `Padrao_SQL/`. Etapa 01 encerrada; levantamento do Access passa para a conversa "01b – Levantamento do Access".
- **15/11/2026**: levantamento do Access iniciado (conversa 01b). Arquivos confirmados como **Jet 4** (Access 2000/2003). Extração será feita pelo **Access instalado no notebook**, via `legado/ferramentas/Extrair_Access.ps1` (automação COM do Access, trabalhando em cópias na pasta temporária; os originais não são alterados; macros/VBA desabilitados na abertura e formulário de inicialização removido só da cópia). Saída em `legado/extracao/` (vai para o Git) e dados reais em `legado/dados_brutos/` (**fora do Git**, LGPD; incluído no `.gitignore`).
- **15/11/2026**: o Celso lembrou: **os dados extraídos agora são para o desenvolvimento**; a importação real será rodada **no cliente, na instalação**, a partir do `.mdb` atualizado. A migração inteira tem de ser repetível e rodar no servidor da CMJ (seção 5). No cliente o Access está instalado e licenciado; no notebook o Access está sem licença (modo somente leitura), e o script `Extrair_Access.ps1` foi ajustado para funcionar assim mesmo (leitura dos dados pelo DAO).
- **15/11/2026**: decidido pelo Celso: a tabela **`ArquivoMorto`** do Access **é eliminada** e seus registros entram **na tabela de movimento do sistema novo**, junto com `F Movimento Contas` (mesma estrutura, 43 campos). Ver seção 5.
- **15/11/2026**: existe uma **base de dados ainda mais antiga**: `CashBookCMJ/CashBookCMJ_be 2015.mdb` (~76 MB, Jet 4). Também será extraída (parâmetros `-ArquivoBE` e `-SomenteBE` do script; saída em `legado/extracao_CashBookCMJ_be_2015/` e `legado/dados_brutos/CashBookCMJ_be_2015/`) e avaliada para entrar na migração junto com o movimento (cuidar de sobreposição com `ArquivoMorto` e `F Movimento Contas`). Exportação de dados do script trocada para leitura em blocos (`GetRows`), porque a leitura campo a campo levaria horas.
- **15/11/2026**: pedido do Celso para a fase de desenvolvimento das telas: **menu do sistema em formato drill-down lateral**, se possível (seção 3, item 8).
- **15/11/2026**: **regra do Celso**: sempre perguntar o próximo passo para confirmação antes de desenvolver; o sistema será modernizado, nada do Access é copiado como foi feito sem confirmação (seção 9 e `padroes/BOAS_PRATICAS.md`). Avisar quando for hora de abrir conversa nova.
- **15/11/2026**: extração concluída (base atual e 2015, 0 erros). Contagem real: movimento 102.230, arquivo morto 147.866 (o Access mostrava números desatualizados por falta de compactação). Base 2015 = backup: `ArquivoMorto` 2015 100% contido no atual; movimento 2015 já existe na base atual (1.560 alterados depois e 263 excluídos depois). `ArquivoMorto` tem numeração própria que colide com o movimento: chave nova na migração, guardando número e origem. Documento: `legado/schema_access.md`.
- **15/11/2026**: **etapa 01b encerrada** (Git: commit `8d0523b`). Próximo passo **confirmado pelo Celso**: conversa **"02 – Base SIS"**.
