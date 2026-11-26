# Notas da versão do SisCMJ

Fonte única das notas de cada versão (o que foi corrigido e o que é novo), em linguagem simples, para a CMJ ler.
O `api\publicar.cmd` copia a seção da versão do pacote para `NOTAS_DA_VERSAO.txt`; o `atualizar.cmd` mostra e grava no banco (`SIS.Atualizacao`), base da futura tela **Sistema › Versões** (pedido P22).
**Regra**: toda versão nova ganha a sua seção aqui **antes** de publicar (o publicar recusa pacote sem nota). Título da seção = versão do banco (`## 1.8 (22/11/2026)`). Itens começam por **Novo:**, **Melhoria:** ou **Correção:**.

## 2.5 (em preparação: 04f2a a 04f2e)
- Novo: telas **Contas a pagar** e **Contas a receber** (Financeiro), com os contadores no topo (vencidas, vencem hoje, a vencer e total em aberto; clique para filtrar), busca, filtros por situação, período (vencimento, emissão ou competência), empresa, parceiro, centro de custo, conta do plano e documento, visão por parcela ou por lançamento e o total do filtro.
- Novo: **Meus filtros**: cada usuário salva os filtros que usa sempre (ex.: "Vencidos da CMJ") e pode marcar um para a tela já abrir com ele. Sem filtro marcado, a tela abre com os últimos filtros usados.
- Novo: **Exportar Excel** das contas a pagar e a receber com todas as linhas do filtro.
- Novo: **ficha do lançamento**: incluir e alterar contas a pagar e a receber com as parcelas (botão "Gerar parcelas" pelo nº de parcelas, 1º vencimento e intervalo), cancelar com motivo, excluir para a lixeira, copiar um lançamento, e as abas Parcelas, Baixas, Anexos e Histórico. Clique na linha da lista para abrir; "+ Incluir" abre um novo.
- Novo: **pendências dos lançamentos**: o sistema aponta sozinho o que falta resolver nas contas em aberto (sem centro de custo, sem conta do plano, sem número de documento, conta a pagar acima de um valor sem anexo, cliente sem cadastro completo para cobrança, parcela vencida há muitos dias), e você também pode marcar pendências ("aguardando nota fiscal", "conferir com o contador"...) com responsável e previsão. Algumas pendências podem impedir o pagamento até serem resolvidas. As regras e os tipos de pendência são configuráveis.
- Novo: na lista de contas, os contadores **Com pendência** e **Minhas pendências**, o filtro por pendência e uma etiqueta na linha que mostra as pendências ao passar o mouse (vermelha quando a previsão já passou). Na ficha, o quadro **Pendências** diz como resolver cada uma e leva direto ao campo certo.
- Novo: tela **Tipos de pendência** (Financeiro), para criar os tipos que a empresa usa e dizer quais bloqueiam o pagamento.
- Melhoria: a conferência de CPF/CNPJ ficou mais rápida nas listas.
- Novo: aba **Movimentação** na ficha do Parceiro: o que ele tem a pagar e a receber em aberto, o vencido, o total pago ou recebido nos últimos 12 meses com a média por mês e a data do último pagamento; a lista das parcelas abre o lançamento, e os botões "+ Contas a pagar" e "+ Contas a receber" já trazem o parceiro escolhido.
- Novo: tela **Parâmetros de uso** (Sistema › Configuração), para os administradores ajustarem os avisos ao lançar, as pendências automáticas, a trava de datas e a lista de contas. Antes de gravar, a tela mostra o efeito (ex.: quantos lançamentos passam a ter uma pendência) e, quando a mudança afrouxa uma proteção, pede o motivo, que fica no histórico do parâmetro.
- Novo: **avisos contra erro de digitação** ao gravar um lançamento: o sistema mostra o que parece erro (valor fora da média, documento repetido, datas distantes...) e só grava depois de você marcar "Estou ciente"; o que é bloqueio não deixa gravar.

## 2.4 (25/11/2026)
- Novo: telas de **Empresas** (Cadastros), com busca na Receita pelo CNPJ e no CEP, logomarca, anexos (contrato social, certidões com validade) e as abas das contas bancárias e dos centros de custo da empresa.
- Novo: **rodapé dos e-mails por empresa**: um texto livre com os contatos (e-mails, telefones, site), com prévia de como vai aparecer.
- Novo: telas de **Contas bancárias** e de **Bancos** (Bancos). Depois que a conta tem movimento, a empresa, o tipo e o saldo inicial não mudam mais; o saldo inicial também não muda em mês fechado.
- Novo: tela de **Centros de custo** (Cadastros), com a **data de encerramento** (obra entregue): depois dela, lançamento novo no centro é bloqueado ou avisado, conforme a configuração.
- Novo: **Plano de contas em árvore** (grupo › subgrupo › conta), com busca, quantidade de lançamentos em cada item e a ficha ao lado para incluir, alterar, desativar e ver o histórico.
- Novo: **escolha com busca** de conta do plano, centro de custo e conta bancária: digite parte do nome ou o número e escolha na lista.
- Novo: na ficha do Parceiro, a **conta do plano** e o **centro de custo padrão**, que já vão vir escolhidos nos lançamentos dele.

## 2.3 (25/11/2026)
- Novo: o cadastro de Pessoas passa a se chamar **Parceiros** (o nome pode ser trocado em parâmetro). Cada parceiro pode ter vários **tipos** ao mesmo tempo (cliente, fornecedor, funcionário, corretor e outros que a empresa criar).
- Novo: tela **Tipos de parceiro** (Cadastros), para criar e organizar os tipos.
- Novo: na lista de Parceiros, o filtro por tipo, a marcação **Pendências de cadastro** (clientes com parcela em aberto cujo cadastro ainda não serve para boleto) e a coluna **Cobrança**, que diz o que falta.
- Novo: na ficha, o **CEP preenche o endereço** e o **CNPJ preenche razão social, nome fantasia e endereço** (pela internet; pergunta antes de trocar o que já foi digitado).
- Novo: aba **Anexos** na ficha do parceiro (contratos, documentos, certidões), com validade e aviso de vencido.
- Melhoria: nos contatos, a **finalidade** (cobrança, compras ou financeiro); escolher cobrança já marca o contato para receber boletos.
- Melhoria: endereço com **número e complemento** em campos próprios, como o banco exige no boleto.

## 2.2 (25/11/2026)
- Novo: tela **Versões** (Sistema › Monitoramento). A aba **Notas** mostra, versão por versão, o que é novo, o que melhorou e o que foi corrigido, com busca e exportação; a aba **Histórico** (só administrador) mostra quando cada atualização foi feita, de qual versão para qual e quanto tempo o sistema ficou fora do ar.
- Novo: aviso **O que há de novo**. Depois de uma atualização, cada usuário vê uma vez, logo depois de entrar, o resumo das novidades, com os botões **Entendi** e **Ver todas as versões**.
- Novo: a versão mostrada no topo das telas passa a abrir a tela de Versões.
- Novo: quando o sistema é atualizado, a nota da versão é enviada por e-mail ao grupo de aviso de versões.
- Melhoria: a tela de casos da migração mostra o rótulo **abatimento de parcela** nos créditos que abatem a parcela.

## 2.1 (23/11/2026)
- Novo: tela **Lixeira** (Sistema › Monitoramento). Mostra o que foi excluído em cada tela, agrupado por módulo, com **Recuperar**, **Manter mais dias** e **Esvaziar agora**, e a aba **Prazos por tela** (quanto tempo cada tela guarda na lixeira).
- Novo: tela **Auditoria** (Sistema › Monitoramento), o histórico geral do sistema, com filtros por período, usuário, tabela, registro, operação e lote, e os botões **Desfazer esta operação** e **Desfazer o lote**.
- Melhoria: a aba **Histórico** das fichas de Pessoa, Usuário e Perfil agora agrupa o que foi gravado junto, tem filtros e os botões **Voltar para como estava aqui** e **Desfazer esta operação**, sempre com prévia e motivo. O histórico da pessoa inclui contatos, dados bancários e vínculos (inclusive os já apagados); o do perfil e do usuário, as permissões.
- Melhoria: a ficha de Pessoa tem os botões **Desativar** (sai das listas, sem prazo) e **Excluir** (vai para a lixeira); a lista de Pessoas tem o atalho **Lixeira de Pessoas**.

## 2.0 (22/11/2026)
- Novo: **lixeira**. O botão Excluir das telas manda o registro para a lixeira, de onde ele pode ser recuperado; depois do prazo (90 dias, ajustável por tela) ele é apagado de vez. Só vai para a lixeira o que não é usado em nenhum lugar; o resto pode ser desativado, como antes.
- Novo: aviso por e-mail, um dia antes, do que vai ser apagado de vez da lixeira, com a opção de manter por mais alguns dias.
- Novo: **desfazer pelo histórico**. Dá para voltar um cadastro para como estava num ponto do histórico, desfazer uma alteração ou desfazer tudo o que um lote fez, sempre com prévia, motivo e registro de quem fez. Nada é desfeito se alguém mexeu depois no mesmo campo.
- Melhoria: o antigo botão Excluir passa a se chamar Desativar (o registro continua no histórico e nas movimentações).

## 1.9 (22/11/2026)
- Novo: tela de **Usuários** (Sistema › Segurança). Cada pessoa tem o seu usuário; o administrador inclui, muda o perfil, desativa, reinicia a senha de quem esqueceu e desbloqueia quem errou a senha várias vezes. O histórico mostra quem mudou o quê.
- Novo: tela de **Perfis e permissões**. O administrador marca, tela por tela, o que cada perfil pode fazer (ver, incluir, alterar, excluir, exportar e as ações especiais). Também dá para fazer exceções só para uma pessoa.
- Novo: perfis prontos **Financeiro** e **Consulta**, para começar (podem ser ajustados).
- Melhoria: a senha provisória (dada a um usuário novo ou ao reiniciar a senha) vale por 24 horas; depois disso é preciso reiniciar de novo.

## 1.8 (22/11/2026)
- Novo: atualização em um clique. O administrador roda um único arquivo (`atualizar.cmd`), que faz um backup de segurança, atualiza o banco e o programa, confere se ficou tudo funcionando e, se algo der errado, volta sozinho para a versão anterior.
- Novo: o sistema guarda o histórico das atualizações (quando, de qual versão para qual, quanto tempo ficou fora do ar e estas notas).
- Melhoria: o menu mostra só as telas que já estão prontas.
- Novo (só para o administrador geral): ajuda técnica com instalação, licença, parâmetros, backup, comandos e recuperação.
