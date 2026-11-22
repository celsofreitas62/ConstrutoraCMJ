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
- Ao fim de cada etapa, atualiza a **seção 0** (estado atual) e o **diário de decisões** (`docs/DIARIO_DECISOES.md`).
- Ao fim de cada etapa, **lembra você de abrir uma conversa nova** para a próxima.

## 3. Uma conversa por etapa (nomes sugeridos)

| Nº | Nome da conversa | Fase do plano |
|---|---|---|
| 01 | Git e levantamento do Access (concluída em 14/11/2026) | 1 |
| 01b | Levantamento do Access (concluída em 15/11/2026) | 1 |
| 02 | Base SIS (concluída em 16/11/2026) | 2 |
| 03 | Modelo de dados: plano de contas, CAD e BANCO (03a concluída em 16/11/2026) | 3a |
| 03b | API e primeira tela (concluída em 16/11/2026) | 3b |
| 03c | Financeiro e ensaio da migração do movimento (FIN, boletim semanal e arquivo morto prontos em 17/11/2026) | 3c |
| 03c2 | Migração: cadastros e transformação do movimento | 3c |
| 03d / 03d2 | Ensaio da instalação: executor, licença, backup e restauração pela tela, roteiro (concluídas em 20/11/2026) | 3d |
| 03e | Ensaio na máquina virtual (3d-C, concluída em 22/11/2026) | 3d |
| 03f | Migração: 3ª rodada com o Access novo (22/11/2026) | 3c |
| 03g | Ajuda do administrador geral (concluída em 22/11/2026; banco 1.7) | 3d |
| 04 | Telas dos cadastros e do financeiro | 4 |
| 05 | Imóveis e vendas (espelho, contrato, parcelas, reajuste) | 5 |
| 06 | Cobrança Sicredi | 6 |
| 07 | Relatórios essenciais e ajuda | 7 |
| 08 | Migração final, instalação e virada | 8 |
| 09 em diante | Itens de depois da virada (Compras, medição, custo de obra, painel...) | 1.x |

Lista revista em 16/11/2026, junto com o novo plano de fases (CLAUDE.md, seção 7). Se uma etapa ficar grande, abra outra com o mesmo número e uma letra (ex.: `07b - Conciliação bancária`).

## 4. Frases úteis

- **Vamos continuar o SistemaCMJ.**: início de toda conversa.
- **Fechar a etapa.**: o Claude atualiza o CLAUDE.md e diz o nome da próxima conversa.
- **Anote no diário: ...**: registra uma decisão sua no diário (`docs/DIARIO_DECISOES.md`).
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

**Cópia no GitHub** (desde 16/11/2026): o repositório privado `https://github.com/celsofreitas62/ConstrutoraCMJ` guarda uma cópia de todo o histórico. Para enviar os commits para lá (no primeiro envio abre uma janela do GitHub pedindo para autorizar: é só autorizar uma vez):

```powershell
Set-Location C:\SistemaCMJ
git push -u origin main
```

Depois do primeiro, basta `git push`. Dados pessoais e material de outras empresas nunca vão para lá (o `.gitignore` já impede).

**Sempre comece pelo `Set-Location C:\SistemaCMJ`**: o PowerShell abre em `C:\Users\celso`, e lá o Git responde `fatal: not a git repository`. Se aparecer esse erro, rode o `Set-Location` e repita os comandos.

Cuidados: a pasta é sincronizada com o Google Drive. Não edite o projeto em dois computadores ao mesmo tempo. Nunca coloque senha, chave ou certificado na pasta fora dos lugares que o `.gitignore` já protege.

## 7. Se algo der errado

- O Claude não achou a pasta: abra o app Claude no notebook (precisa estar aberto e com internet) e mande a mensagem de novo.
- O Claude parece não lembrar do projeto: confira se a conversa está **dentro do projeto SistemaCMJ** e escreva "Leia o CLAUDE.md".
- Script SQL deu erro: copie a mensagem de erro inteira do SSMS e cole na conversa.

## 7. Rodar o sistema no notebook (desde 16/11/2026)

- **Subir**: dois cliques em `C:\SistemaCMJ\api\rodar.cmd`, deixar a janela aberta e abrir **https://localhost:5443** no navegador. Para parar, feche a janela.
- **Compilar** (quando o Claude mudar algo em C#): dois cliques em `C:\SistemaCMJ\api\compilar.cmd` e avisar o Claude (ele lê o `compilar.log`). Mudança só em tela (HTML/CSS/JS) não precisa compilar: basta Ctrl+F5 no navegador.
- **Primeira senha** de um usuário sem senha: no PowerShell, `Set-Location C:\SistemaCMJ\api\SistemaCMJ.Api` e `dotnet run -- senha-inicial <login>`.
- O notebook precisa do **.NET 10 (Hosting Bundle)**, instalado em 16/11/2026, e do certificado confiável (`dotnet dev-certs https --trust`, uma vez só).
