# Boas Práticas de Trabalho (Celso + Claude)

Como o trabalho é conduzido neste projeto. Mesmo modo de trabalhar que o Celso usa profissionalmente; vale tanto quanto as regras de SQL e de e-mail.

## Ambientes e banco

1. **Desenvolvo e testo no `SISTEMACMJ_LOCAL`**. Produção (`SISTEMACMJ`, servidor da CMJ) é sempre promovida pelo Celso.
2. **Nunca executar nada no banco de produção sem autorização explícita do Celso**, nem consulta "rápida". Em ambiente a que eu não tenho acesso, entrego um **script somente-leitura** para ele rodar e colar o resultado, em vez de dizer que não dá para conferir.
3. **Script de produção**: sem `EXEC` de teste no final; as linhas de homologação/teste vão comentadas no cabeçalho (uma linha cada). Execução sempre pelo **SSMS: Arquivo → Abrir → selecionar o .sql → conferir o banco → F5**. Comando `sqlcmd` só se o Celso pedir (pedido feito para a atualização em um clique, 22/11/2026: o `atualizar.cmd` roda o MASTER pelo `sqlcmd`; ver PADRAO_SQL regra 37).
4. `.sql` entregue: CRLF em todas as linhas; sem BOM se for ASCII puro; com BOM se tiver acento. Conferir antes de entregar.
5. **Antes de assumir nome ou tipo de campo, ler o DDL real** (`sql/`) ou o levantamento do Access (`legado/`).
5a. **Testes antes de publicar** (22/11/2026, 04a): testes SQL de homologação (`sql/testes/`) no LOCAL e no ensaio, e os **testes automáticos das telas** (`testes/telas`, pedido `testar_telas.pedido` do executor). O `publicar` só gera pacote com o último teste das telas OK e mais novo que o código.

## E-mail em teste

6. Nunca usar e-mail real de cliente, fornecedor ou funcionário em teste (a fila envia de verdade). Teste externo: `celsofreitas62@gmail.com`.
7. O teste de e-mail passa pelo caminho completo: procedure → fila → serviço → SMTP.

## Código e arquivos

8. **Controle de versão** (Git ou SVN/Tortoise): os fontes ficam versionados; editar direto nos arquivos do projeto, sem criar cópias `_old`, `_bkp`. O rollback é feito pelo controle de versão.
9. **PowerShell**: chamar sempre os cmdlets pelo nome completo (`Remove-Item`, `Get-Content`, `Set-Content`...), nunca por apelido nem criar função com nome que colida com apelido (ex.: `Rd` = `Remove-Item` já apagou arquivo por engano). Ao ler/gravar texto com acento: `-Encoding UTF8` explícito na leitura e na escrita; para gravar sem BOM, `[System.IO.File]::WriteAllText(caminho, texto, [System.Text.UTF8Encoding]::new($false))`.
10. **Perguntar antes** de mexer em biblioteca de terceiros, em qualquer coisa compartilhada por várias rotinas, ou de desviar de um padrão.
11. Corrigir na origem quando uma function/rotina compartilhada tiver defeito (desde que o contrato não mude), em vez de remendar cada chamador.

## Documentação e decisões

12. Toda decisão, regra nova ou etapa concluída vai para o diário (`docs/DIARIO_DECISOES.md`) na hora, e o estado atual para a seção 0 do `CLAUDE.md`. Regra nova de padrão vai também para o arquivo de `padroes/` correspondente.
13. Nota que ainda não é regra (algo visto uma vez só) fica marcada como **"ainda não é regra oficial"** até se repetir.
14. Responder e documentar em português do Brasil, linguagem direta.
15. **Sempre perguntar o próximo passo antes de desenvolver** e esperar a confirmação do Celso. O sistema é **modernizado**: o Access serve para entender dados e regras, não como modelo a copiar. Avisar quando for hora de abrir uma conversa nova (fim de etapa).
