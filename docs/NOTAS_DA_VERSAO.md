# Notas da versão do SisCMJ

Fonte única das notas de cada versão (o que foi corrigido e o que é novo), em linguagem simples, para a CMJ ler.
O `api\publicar.cmd` copia a seção da versão do pacote para `NOTAS_DA_VERSAO.txt`; o `atualizar.cmd` mostra e grava no banco (`SIS.Atualizacao`), base da futura tela **Sistema › Versões** (pedido P22).
**Regra**: toda versão nova ganha a sua seção aqui **antes** de publicar (o publicar recusa pacote sem nota). Título da seção = versão do banco (`## 1.8 (22/11/2026)`). Itens começam por **Novo:**, **Melhoria:** ou **Correção:**.

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
