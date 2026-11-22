<!-- pagina: backup | titulo: Backup e restauração (técnico) | resumo: Como o backup do servidor funciona por dentro: tarefas, script, arquivos, parâmetros, avisos, restauração pela tela e restauração manual pelo SSMS. | palavras: backup restaurar restauracao log trn bak completo seguranca teste checkdb tarefa agendada system backup_servidor.ps1 stopat drive nuvem -->

A tela **Sistema › Backups › Backups e restauração** é o lado do usuário (ajuda "?" dela). Esta página é o lado técnico.

## Quem faz o quê

| Tarefa do Windows (como SYSTEM) | Quando | O que faz |
|---|---|---|
| `SisCMJ (SisCMJ) - Backup completo` | todo dia às 23h (`-HoraBackupCompleto` do instalador) | põe o banco em recuperação FULL, BACKUP com CHECKSUM, RESTORE VERIFYONLY, cópia para a nuvem, limpeza |
| `... - Backup do log` | de hora em hora (:30) | backup do log: perda máxima de 1 hora |
| `... - Teste de restauração` | domingos às 4h | restaura o último completo e os logs num banco `_RESTORE_TESTE`, roda DBCC CHECKDB, conta as tabelas e apaga a cópia |
| `... - Restauração (pedidos)` | a cada minuto | faz as restaurações pedidas pela tela |

- Todas rodam o mesmo script, `instalacao\backup_servidor.ps1` (modos `COMPLETO`, `LOG`, `TESTE`, `RESTAURAR`), copiado pelo instalador para `C:\SisCMJ\scripts`. **Nunca rodam duas ao mesmo tempo** (trava única).
- Cada execução fica em **`SIS.Backup_Execucao`** e, passo a passo, em **`<BACKUP_PASTA>\backup.log`**. Erro manda e-mail para `EMAIL_ADMIN_ALERTA`.
- A API **não consegue** fazer backup nem restaurar: as rotinas do script têm DENY para o papel da API. A tela só registra o pedido.
- **Aviso de atraso**: a rotina `BACKUP_CONFERIR` (de hora em hora) avisa por e-mail quando atrasam o completo, o log ou o teste (no máximo um aviso por dia). Desligada no banco de desenvolvimento.

## Arquivos

| Arquivo | O que é |
|---|---|
| `SISTEMACMJ_COMPLETO_<data>.bak` | backup completo (base de qualquer restauração) |
| `SISTEMACMJ_LOG_<data>.trn` | backup do log de hora em hora |
| `SISTEMACMJ_SEGURANCA_<data>.bak` | feito logo antes de cada restauração, para desfazer um engano |

- Pasta: parâmetro `BACKUP_PASTA` (na CMJ, `D:\SisCMJ_Backup`, no HD de 1 TB). Limpeza: `BACKUP_DIAS_MANTER` dias. **Nunca** apaga o último completo nem os logs depois dele.
- Nuvem: `BACKUP_PASTA_EXTERNA` (pasta sincronizada com o Google Drive), guardando `BACKUP_NUVEM_MANTER` completos. Vai **sem senha** (o Express não cifra backup; decisão do Celso de 20/11/2026).

## Restauração pela tela, por dentro

1. O pedido (`SIS.Backup_Restauracao`) passa de PENDENTE a EXECUTANDO. Antes de tirar o sistema do ar, o script confere os arquivos do plano (existem e passam no VERIFYONLY).
2. Para o serviço SisCMJ → SINGLE_USER → backup de **segurança** (COPY_ONLY) e final do log.
3. Restaura o completo e os logs até o ponto (STOPAT) → MULTI_USER.
4. Registra de novo os backups que o banco restaurado não conhece (pelo `msdb`), faz um **completo novo** (base dos logs seguintes) e religa o serviço.
5. Grava o resultado no banco restaurado e manda e-mail para o administrador e para quem pediu.
6. Erro: tenta deixar o banco on-line; se não der, volta o backup de segurança; religa o serviço e grava ERRO.

⚠️ **Limite de versão**: a tela não volta para antes da última atualização do banco (`SIS.fn_SIS_Backup_Limite_Versao`): o banco ficaria numa versão diferente do programa e o sistema pararia. Voltar para antes só pelo SSMS, com o Celso, rodando o MASTER de novo depois.

## Restauração manual pelo SSMS (sem a tela)

Quando o serviço não sobe ou é preciso um ponto que a tela não oferece:

1. `Stop-Service SisCMJ` (PowerShell como administrador).
2. SSMS › banco **SISTEMACMJ** › Tarefas › Restaurar › Banco de dados › Dispositivo: o `_COMPLETO_*.bak` e os `_LOG_*.trn` seguintes (opção de ponto no tempo, se quiser). Marcar "Fechar conexões existentes" e fazer antes o backup do final do log, se o SSMS oferecer.
3. Conferir a versão (`SELECT SIS.fn_SIS_Versao_Banco()`). Se for mais velha que a do programa, rodar o MASTER do pacote instalado.
4. `Start-Service SisCMJ` e conferir `/api/saude` e a tela de backups.

## Parâmetros do backup

Valores atuais na página **Parâmetros** (chaves `BACKUP_*` e `EMAIL_ADMIN_ALERTA`).
