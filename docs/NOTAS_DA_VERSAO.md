# Notas da versão do SisCMJ

Fonte única das notas de cada versão (o que foi corrigido e o que é novo), em linguagem simples, para a CMJ ler.
O `api\publicar.cmd` copia a seção da versão do pacote para `NOTAS_DA_VERSAO.txt`; o `atualizar.cmd` mostra e grava no banco (`SIS.Atualizacao`), base da futura tela **Sistema › Versões** (pedido P22).
**Regra**: toda versão nova ganha a sua seção aqui **antes** de publicar (o publicar recusa pacote sem nota). Título da seção = versão do banco (`## 1.8 (22/11/2026)`). Itens começam por **Novo:**, **Melhoria:** ou **Correção:**.

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
