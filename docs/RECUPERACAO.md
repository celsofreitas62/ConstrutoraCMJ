# Recuperação: montar o SisCMJ de novo do zero

Versão 1.0 (22/11/2026, conversa 03g). Previsto no plano de continuidade de 20/11/2026 (CLAUDE.md, seção 7, fase 3d). **Manter atualizado** quando mudar onde as coisas ficam guardadas. Aparece também na ajuda do administrador geral (página Recuperação).

Regra: este documento diz **onde** cada coisa está, nunca a senha ou a chave em si.

## 1. O que existe e onde está guardado

| O quê | Onde fica | Cópia de segurança |
|---|---|---|
| Código, documentos, padrões, scripts | `C:\SistemaCMJ` no notebook | Google Drive (pasta sincronizada) e GitHub privado `celsofreitas62/ConstrutoraCMJ` |
| Banco de desenvolvimento `SISTEMACMJ_LOCAL` (inclui as correções da Renata na migração) | SQL Server `.\SQL2025` do notebook | backup diário às 19h: 7 cópias em `C:\Backup_SisCMJ` e as últimas em `C:\Recover SistemaCMJ\backup_db` (sincronizada com o Drive) |
| Banco da CMJ `SISTEMACMJ` | servidor da CMJ | backups em `D:\SisCMJ_Backup` (HD do servidor) e o último completo na pasta do Drive (`BACKUP_PASTA_EXTERNA`) |
| Chave privada da licença | `%USERPROFILE%\SisCMJ_Chave\chave_privada_siscmj.pem` no notebook | Google Drive do Celso |
| Licenças emitidas | `%USERPROFILE%\SisCMJ_Chave\licencas\` | Google Drive do Celso (junto com a chave) |
| Configuração do servidor (conexão, e-mail) | `C:\ProgramData\SisCMJ\appsettings.Servidor.json` no servidor | nenhuma de propósito: se perder, o instalador cria de novo e o e-mail é preenchido de novo (roteiro, item 9) |
| Pacotes de instalação | `C:\SisCMJ_Publicacao\` no notebook (fora do Drive) | gerados de novo a qualquer momento pelo `api\publicar.cmd` |
| Máquina virtual de ensaio | Hyper-V do notebook (`SisCMJ-Servidor-Ensaio`) | nenhuma: `instalacao\ensaio\criar_vm_hyperv.cmd` cria outra |

## 2. Senhas e chaves (gerenciador de senhas do Celso)

Guardar no gerenciador de senhas, **nunca em arquivo na pasta do Drive nem no Git**:

- conta do GitHub e os **códigos de recuperação** da verificação em duas etapas;
- **senha da chave privada da licença**;
- **chave de recuperação do BitLocker** do servidor da CMJ (regra de ouro 3 do roteiro: junto com a da licença; cópia impressa com a CMJ);
- administrador do Windows do servidor da CMJ;
- senha de app do Gmail da CMJ (`construtora.m.judice@gmail.com`, app "SisCMJ"): só vai no arquivo de configuração do servidor;
- senha de app do Gmail do Celso usada pelo notebook (`Smtp__Interna__Senha`, boletim semanal);
- senhas dos administradores do SisCMJ (`celso` e `admin`).

## 3. Perdi o notebook (ou o disco dele)

1. Instalar no computador novo: **SQL Server 2025 Express** com a instância **`SQL2025`** (cuidado com o ID da instância, roteiro item 3), **SSMS**, **.NET 10 SDK**, **Git** e o **Google Drive para computador**.
2. Recuperar a pasta do projeto: pelo Drive (sincronizar `C:\SistemaCMJ`) ou `git clone` do GitHub para `C:\SistemaCMJ`.
3. Recuperar o banco de desenvolvimento: SSMS › Restaurar banco › o `.bak` mais novo de `C:\Recover SistemaCMJ\backup_db` (do Drive) › nome **`SISTEMACMJ_LOCAL`**.
4. Copiar a pasta da chave da licença do Drive para `%USERPROFILE%\SisCMJ_Chave`. Conferir com `api\gerar_licenca.cmd` › opção 4 numa licença emitida.
5. Certificado do navegador: `dotnet dev-certs https --trust` (uma vez). Licença de desenvolvimento: o código do computador muda, então gerar uma nova (gerador, opção 2, instalar neste notebook).
6. Reinstalar as tarefas do notebook, como administrador: `backup\instalar_backup.cmd` (backup diário do LOCAL) e `executor_sql\instalar_executor.cmd` (executor do Claude).
7. Subir com `api\rodar.cmd` e conferir `https://localhost:5443/api/saude`.

## 4. Perdi o servidor da CMJ

1. Máquina nova (ou a mesma, formatada): seguir o **roteiro de instalação** do item 2 ao 6, com o pacote da versão que estava em uso.
2. **Antes do instalador**, restaurar o banco em vez de criá-lo vazio: SSMS › Restaurar banco › o último `_COMPLETO_*.bak` (da pasta de backup, se o HD sobreviveu, ou da pasta do Drive) e os `_LOG_*.trn` seguintes, com o nome **`SISTEMACMJ`**. Conferir a versão: `SELECT SIS.fn_SIS_Versao_Banco()`. Se for mais velha que a do pacote, rodar o MASTER do pacote por cima.
3. Rodar o instalador (item 6 do roteiro).
4. **Licença nova**: o código do servidor muda (roteiro item 7; página Licença).
5. E-mail (item 9), computadores dos usuários com o **certificado novo** (item 10) e conferências finais (item 11).
6. O que foi lançado depois do último backup que sobrou é perdido: com o HD de backup, no máximo 1 hora; só com o Drive, desde o último completo (23h do dia anterior).

## 5. Perdi a chave privada da licença (e a cópia do Drive)

As licenças já instaladas continuam valendo, mas não dá para gerar licença nova. Para voltar a gerar: criar um par de chaves novo (gerador, opção 1, depois de tirar a pasta antiga do lugar), o Claude compila o programa com a chave pública nova, **gerar e instalar licença nova em todo cliente** e publicar a versão nova.

## 6. O GitHub sumiu ou o histórico estragou

O Drive tem a pasta inteira, inclusive o `.git`. Criar um repositório privado novo, apontar o `origin` para ele e enviar (`enviar_github.cmd`). Nunca apagar histórico nem forçar envio sem o Celso pedir.
