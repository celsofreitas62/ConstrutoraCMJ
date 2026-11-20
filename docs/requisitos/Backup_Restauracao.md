# Backup do servidor e restauração pela tela (fase 3d)

Criado em 20/11/2026. Pedidos do Celso: backup do log de hora em hora (aprovado) e, a pedido da CMJ, **restaurar backup pelo sistema quando for preciso**. O desenho da restauração (seção 3) foi aprovado pelo Celso em 20/11/2026 ("tudo aprovado").

## 1. Pronto e ensaiado (20/11/2026)

- **Script** `instalacao/backup_servidor.ps1`, rodado por tarefas do Windows como **SYSTEM**, criadas pelo `instalar_servico.ps1`, passo 10:
  - `SisCMJ (<serviço>) - Backup completo`: todo dia às 23h (parâmetro `-HoraBackupCompleto`). Põe o banco no modo de recuperação FULL, faz o BACKUP com CHECKSUM e o RESTORE VERIFYONLY, copia para a nuvem (`BACKUP_PASTA_EXTERNA`, guardando `BACKUP_NUVEM_MANTER`) e aplica a retenção (`BACKUP_DIAS_MANTER`, nunca apaga o último completo nem os logs depois dele).
  - `... - Backup do log`: de hora em hora, a partir do primeiro completo (perda máxima de 1 hora).
  - `... - Teste de restauração`: domingos às 4h. Restaura o último completo e os logs seguintes num banco `_RESTORE_TESTE`, roda DBCC CHECKDB, conta as tabelas e apaga a cópia.
- **Registro** em `SIS.Backup_Execucao`, pela `SIS_Backup_Registrar`, que só o script pode rodar (DENY para a API). Erro gera e-mail para `EMAIL_ADMIN_ALERTA`.
- **Aviso de atraso**: a rotina `BACKUP_CONFERIR`, de hora em hora (`SIS_Backup_Conferir_Processar`), avisa quando atrasam o completo (26 h), o log (3 h) ou o teste (8 dias). Sai no máximo um aviso por dia. A rotina fica desligada no `_LOCAL`.
- **Ensaio no notebook** (serviço `SisCMJ_Ensaio`, banco `SISTEMACMJ`): primeiro completo de 13,8 MB OK; teste de restauração OK (CHECKSUM, CHECKDB, 81 tabelas, versão 1.5). Teste de banco `03d_Homologacao_Backup.sql`: 9/0.

## 2. Pendências do motor

- Conferir o primeiro **backup do log** de hora em hora no ensaio (tarefa às :30) e um teste de restauração **com logs**.
- **Cópia na nuvem com dados pessoais (LGPD)**: o Express não cifra o backup. **Decidido pelo Celso em 20/11/2026: a cópia vai para o Google Drive sem senha** (como está hoje).

## 3. Restauração pela tela (APROVADO, a fazer)

- **Tela** Sistema › Backups (item `SIS_BACKUP`, ações VER e **RESTAURAR**):
  - lista os backups (completos, de hora em hora, testes e segurança), mostrando se o arquivo ainda existe;
  - mostra até onde dá para voltar, do completo mais antigo que ainda existe até o último backup;
  - lista os pedidos de restauração e o resultado de cada um.
- **Quem restaura**: o administrador geral e o administrador da CMJ, com a permissão RESTAURAR.
- **O que se escolhe**: um backup completo, ou **um dia e hora** (ponto no tempo, usando os backups de hora em hora).
- **Confirmação forte**: a pessoa digita a senha dela (conferida pela API), escreve "RESTAURAR" e informa o motivo, que é obrigatório.
- **Quem executa**: uma tarefa do Windows como SYSTEM, `... - Restauração (pedidos)`, que confere os pedidos a cada minuto. A tela só registra o pedido; a API não tem permissão para restaurar.
- **Passos da execução**:
  1. Marca o pedido como EXECUTANDO.
  2. Faz o **backup de segurança**: um completo COPY_ONLY e o final do log (tail), para dar para voltar se a restauração for um engano.
  3. Para o serviço do SisCMJ, e os usuários ficam sem acesso por alguns minutos.
  4. Põe o banco em SINGLE_USER, restaura o completo e os logs até o ponto (STOPAT) e faz o RECOVERY.
  5. Volta o banco para MULTI_USER e religa o serviço.
  6. Depois da restauração, a tabela do pedido volta ao passado, então o script **regrava no banco restaurado** o pedido com o resultado, o backup de segurança e os backups da pasta que faltarem (pelo `msdb.backupset`). Também avisa por e-mail.
  7. Se der erro: tenta deixar o banco on-line (RECOVERY), religa o serviço, registra ERRO e avisa. O backup de segurança fica disponível.
- **Banco**: tabela `SIS.Backup_Restauracao` e as rotinas Solicitar (tela, com permissão), Listar e Capturar/Resultado (só o script, com DENY para a API).
- **Ensaio** no notebook (porta 5445) antes do servidor.

## 4. Restauração: parte do banco pronta (20/11/2026, conversa 03d2)

- Tabela `SIS.Backup_Restauracao` (pedido, situação PENDENTE → EXECUTANDO → OK/ERRO, ou CANCELADO; plano; backup de segurança; resultado).
- `SIS.fn_SIS_Backup_Plano`: quais arquivos aplicar (completo + logs até o primeiro que passa do ponto); recusa plano com arquivo apagado.
- Tela (API repassa): `SIS_Backup_Listar`, `SIS_Backup_Situacao_Obter` (dá para voltar de/até, pedido em aberto, pode restaurar), `SIS_Backup_Restauracao_Listar`, `SIS_Backup_Restauracao_Solicitar` (senha conferida pela API, palavra RESTAURAR, motivo com mínimo no parâmetro `BACKUP_RESTAURACAO_MOTIVO_MINIMO` = 10, um pedido por vez, e-mail ao `EMAIL_ADMIN_ALERTA`), `SIS_Backup_Restauracao_Cancelar` (só enquanto aguarda).
- Só o script (DENY para a API): `SIS_Backup_Restauracao_Capturar` (marca EXECUTANDO e devolve o plano; plano que não fecha mais vira ERRO) e `SIS_Backup_Restauracao_Resultado` (regrava o pedido com o mesmo ID no banco restaurado; e-mail para o admin e para quem pediu).
- Menu **Backups › Backups e restauração** (`SIS_BACKUP`, ações VER e RESTAURAR; administradores nível 1 e 2 têm as duas).
- Teste `sql/testes/SIS/03d2_Homologacao_Restauracao.sql`: **36/0** no LOCAL; `03d_Homologacao_Backup.sql` segue 9/0.
- **API e tela prontas (compiladas, 0 avisos)**: `Endpoints/BackupEndpoints.cs` (`GET /api/sis/backups` = situação + backups + pedidos; `POST /api/sis/backups/restaurar`, que confere a senha pelo mesmo caminho da troca de senha; `POST /api/sis/backups/cancelar`), tela `sis/backups.html` + `js/sis/backups.js` (topo "dá para voltar de/até", abas Backups, Restaurar e Pedidos; atualiza sozinha a cada 20 s com pedido em aberto) e ajuda `ajuda/sis-backups.html`. **Banco e API 1.6.**
- **Falta**: conferir a tela no navegador (Celso), a parte do script (`backup_servidor.ps1`: tarefa "Restauração (pedidos)", backup de segurança, parar o serviço, RESTORE com STOPAT, novo completo depois, regravar pedido e backups) e o ensaio no notebook.
