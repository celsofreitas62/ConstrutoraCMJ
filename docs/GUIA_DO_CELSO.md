# Guia do Celso: como trabalhar com o Claude no SistemaCMJ

Atualizado em 15/11/2026. Guia de bolso: o que fazer, em que ordem, e o que dizer ao Claude.

---

## 1. Começar uma conversa (toda vez)

1. Abra o Claude e entre no projeto **SistemaCMJ** (menu lateral, "Projects"). A conversa tem de ser aberta **dentro do projeto**.
2. Dê à conversa o nome da etapa (lista na seção 3), por exemplo `02 - Base SIS`.
3. Escreva: **Vamos continuar o SistemaCMJ.**
4. Quando aparecer o pedido de acesso à pasta `C:\SistemaCMJ`, clique em **aprovar**.
5. O Claude lê o `CLAUDE.md` e os `padroes/` sozinho e diz em que ponto o projeto está. Você não precisa explicar de novo.

## 2. O que o Claude já faz sem você pedir

- Responde em português do Brasil.
- Segue o padrão SQL, o padrão de e-mail, os gabaritos e as boas práticas da pasta `padroes/`.
- Ao fim de cada etapa, atualiza a **seção 0** (estado atual) e o **diário de decisões** do `CLAUDE.md`.
- Ao fim de cada etapa, **lembra você de abrir uma conversa nova** para a próxima.

## 3. Uma conversa por etapa (nomes sugeridos)

| Nº | Nome da conversa | Fase do plano |
|---|---|---|
| 01 | Git e levantamento do Access (Git concluído em 14/11/2026) | 1 |
| 01b | Levantamento do Access (concluído em 15/11/2026) | 1 |
| 02 | Base SIS (licença, parâmetros, usuários, auditoria, lote, anexo, log, fila de e-mail) | 2 |
| 03 | Modelo de dados (cadastros, imóveis, vendas, financeiro) | 2 |
| 04 | API ASP.NET Core (esqueleto, login, fila de e-mail, agendador) | 3 |
| 05 | Cadastros (telas + procedures) | 4 |
| 06 | Vendas e geração de parcelas | 5 |
| 07 | Financeiro (pagar, receber, baixas, conciliação) | 6 |
| 08 | Cobrança Sicredi | 7 |
| 09 | Custos de obra | 8 |
| 10 | Painel e relatórios | 9 |
| 11 | Migração do Access e virada | 10 |

Se uma etapa ficar grande, abra outra com o mesmo número e uma letra (ex.: `07b - Conciliação bancária`).

## 4. Frases úteis

- **Vamos continuar o SistemaCMJ.**: início de toda conversa.
- **Fechar a etapa.**: o Claude atualiza o CLAUDE.md e diz o nome da próxima conversa.
- **Anote no diário: ...**: registra uma decisão sua no CLAUDE.md.
- **A CMJ respondeu: ...**: o Claude tira o item das pendências (seção 6) e registra no diário.
- **Regra nova: ...**: vira regra no arquivo certo de `padroes/`.
- **Onde paramos?**: resumo do estado atual.

## 5. O que só você faz

- **Confirmar o próximo passo**: o Claude sempre propõe e espera o seu OK antes de desenvolver (o sistema é modernizado, nada do Access é copiado sem você aprovar).

- **Aprovar** o acesso à pasta (o Claude não aprova por você).
- **Rodar os scripts SQL** no SSMS: Arquivo → Abrir → escolher o `.sql` → conferir o banco no alto da tela → **F5**. Sempre no `SISTEMACMJ_LOCAL` primeiro.
- **Produção** (`SISTEMACMJ`, servidor da CMJ): só você roda, e só o que já foi aprovado e está no arquivo MASTER.
- **Gravar no Git** ao fim de cada etapa (seção 6).
- Responder as pendências da CMJ quando tiver as respostas (seção 6 do `CLAUDE.md`).

## 6. Git: guardar o trabalho

**Desde 16/11/2026 o Claude faz os commits sozinho**, a cada etapa ou ajuste homologado (e depois de registrar decisões), com a mensagem já pronta. Para isso, em cada conversa nova ele pede uma vez a permissão de apagar arquivos na pasta (o Git apaga arquivos temporários a cada commit): é só aprovar a janela. Ele avisa o código de cada commit. Os comandos abaixo continuam valendo se você quiser fazer na mão.


No PowerShell, ao fim de cada etapa (o Claude sugere a mensagem):

```powershell
Set-Location C:\SistemaCMJ
git add .
git status
git commit -m "mensagem que o Claude sugerir"
```

Para ver o histórico: `git log --oneline`.

**Sempre comece pelo `Set-Location C:\SistemaCMJ`**: o PowerShell abre em `C:\Users\celso`, e lá o Git responde `fatal: not a git repository`. Se aparecer esse erro, rode o `Set-Location` e repita os comandos.

Cuidados: a pasta é sincronizada com o Google Drive. Não edite o projeto em dois computadores ao mesmo tempo. Nunca coloque senha, chave ou certificado na pasta fora dos lugares que o `.gitignore` já protege.

## 7. Se algo der errado

- O Claude não achou a pasta: abra o app Claude no notebook (precisa estar aberto e com internet) e mande a mensagem de novo.
- O Claude parece não lembrar do projeto: confira se a conversa está **dentro do projeto SistemaCMJ** e escreva "Leia o CLAUDE.md".
- Script SQL deu erro: copie a mensagem de erro inteira do SSMS e cole na conversa.
