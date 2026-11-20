/*******************************************************************************
  Teste       : 03d2 - restauração de backup pela tela (banco)
                (fn_SIS_Backup_Plano, SIS_Backup_Listar, _Situacao_Obter,
                 SIS_Backup_Restauracao_Solicitar, _Cancelar, _Listar,
                 _Capturar, _Resultado)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 20/11/2026 (v1.0). Roda no LOCAL ou no ensaio. Tudo numa
                transação desfeita (ROLLBACK): nada fica gravado. Backups
                fictícios (nenhum arquivo de verdade é usado).
                Usuários: celso (nível 2), renata (administradora, nível 1),
                claude (só consulta: sem RESTAURAR). No ensaio: admin no lugar
                da renata; sem o claude, o caso "sem permissão" usa usuário inexistente.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @R TABLE (CASO VARCHAR(90), ESPERADO VARCHAR(60), OBTIDO VARCHAR(400));
DECLARE @S TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_RESTAURACAO INT);
DECLARE @C TABLE (ID_RESTAURACAO INT, TIPO_PONTO VARCHAR(10), DT_PONTO DATETIME2(0), ID_BACKUP BIGINT, MOTIVO NVARCHAR(400), USUARIO_PEDIDO NVARCHAR(100),
                  ID_USUARIO_PEDIDO INT, DT_PEDIDO DATETIME2(0), DT_INICIO DATETIME2(0), ORDEM INT, ID_BACKUP_ARQUIVO BIGINT, TIPO VARCHAR(10),
                  ARQUIVO NVARCHAR(400), DT_INICIO_ARQUIVO DATETIME2(0), DT_FIM_ARQUIVO DATETIME2(0), ULTIMO BIT);
DECLARE @X TABLE (ID_RESTAURACAO INT, SITUACAO VARCHAR(12));
DECLARE @Antes BIGINT = ISNULL((SELECT MAX(ID_EMAIL) FROM SIS.Email_Fila), 0);
DECLARE @T0 DATETIME2(0) = DATEADD(HOUR, -30, CAST(SYSDATETIME() AS DATETIME2(0)));
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Renata INT = ISNULL((SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'renata'), (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'admin'));   -- no ensaio: admin
DECLARE @LoginAdm VARCHAR(40) = (SELECT LOGIN FROM SIS.Usuario WHERE ID_USUARIO = @Renata);
DECLARE @Claude INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'claude');
DECLARE @P DATETIME2(0), @Id INT, @Id2 INT, @IdS1 BIGINT, @IdL2 BIGINT;

BEGIN TRANSACTION;
UPDATE SIS.Parametro SET VALOR = N'celsofreitas62@gmail.com' WHERE CHAVE = 'EMAIL_ADMIN_ALERTA';
DELETE FROM SIS.Backup_Restauracao;   -- (desfeito no fim)
DELETE FROM SIS.Backup_Execucao;

-- Backups fictícios: completo F1 em T0 com logs L1..L5 (L2 apagado), completo F2 em T0+10h com logs L6..L8, segurança S1 em T0+14h
INSERT INTO SIS.Backup_Execucao (TIPO, ARQUIVO, DT_INICIO, DT_FIM, TAMANHO_MB, SITUACAO, ARQUIVO_EXISTE)
SELECT v.TIPO, v.ARQ, DATEADD(MINUTE, v.MIN, @T0), DATEADD(MINUTE, v.MIN + 1, @T0), 1, 'OK', v.EXISTE
FROM (VALUES ('COMPLETO', N'C:\t\F1.bak', 0, 1), ('LOG', N'C:\t\L1.trn', 60, 1), ('LOG', N'C:\t\L2.trn', 120, 0), ('LOG', N'C:\t\L3.trn', 180, 1),
             ('LOG', N'C:\t\L4.trn', 240, 1), ('LOG', N'C:\t\L5.trn', 300, 1), ('COMPLETO', N'C:\t\F2.bak', 600, 1), ('LOG', N'C:\t\L6.trn', 660, 1),
             ('LOG', N'C:\t\L7.trn', 720, 1), ('LOG', N'C:\t\L8.trn', 780, 1), ('SEGURANCA', N'C:\t\S1.bak', 840, 1)) v (TIPO, ARQ, MIN, EXISTE);
SELECT @IdS1 = ID_BACKUP FROM SIS.Backup_Execucao WHERE ARQUIVO = N'C:\t\S1.bak';
SELECT @IdL2 = ID_BACKUP FROM SIS.Backup_Execucao WHERE ARQUIVO = N'C:\t\L2.trn';

-- 1) plano para um dia e hora: completo F2 + L6 + L7 (o último passa do ponto)
SET @P = DATEADD(MINUTE, 690, @T0);
INSERT @R SELECT 'plano 11h30: arquivos na ordem', 'F2.bak,L6.trn,L7.trn',
       STUFF((SELECT ',' + REPLACE(CAST(ARQUIVO AS VARCHAR(400)), 'C:\t\', '') FROM SIS.fn_SIS_Backup_Plano(NULL, @P) ORDER BY ORDEM FOR XML PATH('')), 1, 1, '');
INSERT @R SELECT 'plano 11h30: alcança o ponto', '1', CAST(MAX(CAST(ALCANCA_PONTO AS INT)) AS VARCHAR(1)) FROM SIS.fn_SIS_Backup_Plano(NULL, @P);
INSERT @R SELECT 'plano de um backup escolhido: 1 arquivo', '1', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.fn_SIS_Backup_Plano(@IdS1, NULL);
INSERT @R SELECT 'log não serve como backup escolhido', '0', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.fn_SIS_Backup_Plano(@IdL2, NULL);

-- 2) recusas do pedido
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Claude, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
INSERT @R SELECT 'sem permissão RESTAURAR: recusa', 'Você não tem permissão para restaurar backup.', MENSAGEM FROM @S; DELETE @S;
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Renata, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 0;
INSERT @R SELECT 'senha não conferida: recusa', 'A senha não confere.', MENSAGEM FROM @S; DELETE @S;
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Renata, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'teste de homologação', @Confirmacao = N'sim', @SenhaConferida = 1;
INSERT @R SELECT 'sem a palavra RESTAURAR: recusa', '0', CAST(SUCESSO AS VARCHAR(1)) FROM @S; DELETE @S;
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Renata, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'curto', @Confirmacao = N'restaurar', @SenhaConferida = 1;
INSERT @R SELECT 'motivo curto: recusa', 'SIM', CASE WHEN MENSAGEM LIKE N'Informe o motivo%' THEN 'SIM' ELSE CAST(MENSAGEM AS VARCHAR(400)) END FROM @S; DELETE @S;
SET @P = DATEADD(MINUTE, 210, @T0);
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Renata, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
INSERT @R SELECT 'ponto que precisa de arquivo apagado: recusa', 'SIM', CASE WHEN MENSAGEM LIKE N'%apagado pela limpeza%' THEN 'SIM' ELSE CAST(MENSAGEM AS VARCHAR(400)) END FROM @S; DELETE @S;
SET @P = DATEADD(MINUTE, 810, @T0);
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Renata, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
INSERT @R SELECT 'ponto depois do último log: recusa', 'SIM', CASE WHEN MENSAGEM LIKE N'Ainda não há backup de hora em hora%' THEN 'SIM' ELSE CAST(MENSAGEM AS VARCHAR(400)) END FROM @S; DELETE @S;
SET @P = DATEADD(MINUTE, -60, @T0);
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Renata, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
INSERT @R SELECT 'ponto antes do 1º completo: recusa', 'SIM', CASE WHEN MENSAGEM LIKE N'Não há backup completo antes%' THEN 'SIM' ELSE CAST(MENSAGEM AS VARCHAR(400)) END FROM @S; DELETE @S;
SET @P = DATEADD(MINUTE, 60, SYSDATETIME());
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Renata, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
INSERT @R SELECT 'ponto no futuro: recusa', 'O dia e a hora para voltar precisam estar no passado.', MENSAGEM FROM @S; DELETE @S;

-- 3) pedido válido (Renata, administradora da CMJ)
SET @P = DATEADD(MINUTE, 690, @T0);
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Renata, @TipoPonto = 'DATA_HORA', @DtPonto = @P, @Motivo = N'teste de homologação', @Confirmacao = N' restaurar ', @SenhaConferida = 1;
SELECT @Id = ID_RESTAURACAO FROM @S;
INSERT @R SELECT 'pedido válido: sucesso', '1', CAST(SUCESSO AS VARCHAR(1)) FROM @S; DELETE @S;
INSERT @R SELECT 'pedido: PENDENTE, quem pediu e plano com 3 arquivos', 'PENDENTE ' + @LoginAdm + ' 3', SITUACAO + ' ' + USUARIO_PEDIDO + ' ' + CAST(LEN(PLANO) - LEN(REPLACE(PLANO, '|', '')) + 1 AS VARCHAR(5)) FROM SIS.Backup_Restauracao WHERE ID_RESTAURACAO = @Id;
INSERT @R SELECT 'pedido: aviso por e-mail na fila', '1', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.Email_Fila WHERE ID_EMAIL > @Antes AND ASSUNTO LIKE N'%pedido de restauração%';
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Celso, @TipoPonto = 'BACKUP', @IdBackup = @IdS1, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
INSERT @R SELECT 'segundo pedido com um em aberto: recusa', 'SIM', CASE WHEN MENSAGEM LIKE N'Já existe um pedido%' THEN 'SIM' ELSE CAST(MENSAGEM AS VARCHAR(400)) END FROM @S; DELETE @S;

-- 4) situação e listas da tela
DECLARE @Sit TABLE (DE DATETIME2(0), ATE DATETIME2(0), UC DATETIME2(0), UL DATETIME2(0), UT DATETIME2(0), ERROS INT, ID_ABERTA INT, SIT_ABERTA VARCHAR(12), PODE BIT, BANCO NVARCHAR(128), AGORA DATETIME2(0));
INSERT @Sit EXEC SIS.SIS_Backup_Situacao_Obter @IdUsuario = @Renata;
INSERT @R SELECT 'dá para voltar de (fim do F1)', CONVERT(VARCHAR(19), DATEADD(MINUTE, 1, @T0), 120), CONVERT(VARCHAR(19), DE, 120) FROM @Sit;
INSERT @R SELECT 'dá para voltar até (fim do L8)', CONVERT(VARCHAR(19), DATEADD(MINUTE, 781, @T0), 120), CONVERT(VARCHAR(19), ATE, 120) FROM @Sit;
INSERT @R SELECT 'situação: pedido em aberto e pode restaurar', CAST(@Id AS VARCHAR(10)) + ' PENDENTE 1', CAST(ID_ABERTA AS VARCHAR(10)) + ' ' + SIT_ABERTA + ' ' + CAST(PODE AS VARCHAR(1)) FROM @Sit;
DECLARE @L TABLE (ID_BACKUP BIGINT, TIPO VARCHAR(10), TIPO_NOME NVARCHAR(40), ARQUIVO NVARCHAR(400), ARQUIVO_NOME NVARCHAR(260), DT_INICIO DATETIME2(0), DT_FIM DATETIME2(0),
                  TAMANHO_MB DECIMAL(12,1), SITUACAO VARCHAR(10), MENSAGEM NVARCHAR(2000), COPIA_NUVEM BIT, ARQUIVO_EXISTE BIT, PODE_ESCOLHER BIT, SERVIDOR NVARCHAR(128));
INSERT @L EXEC SIS.SIS_Backup_Listar @IdUsuario = @Renata;
INSERT @R SELECT 'lista: 11 backups, 3 podem ser escolhidos', '11 3', CAST(COUNT(*) AS VARCHAR(5)) + ' ' + CAST(SUM(CAST(PODE_ESCOLHER AS INT)) AS VARCHAR(5)) FROM @L;
INSERT @R SELECT 'lista: nome do arquivo sem a pasta', 'F1.bak', ARQUIVO_NOME FROM @L WHERE ARQUIVO = N'C:\t\F1.bak';

-- 5) captura pelo script: plano, um por vez, sem cancelar depois de começar
INSERT @C EXEC SIS.SIS_Backup_Restauracao_Capturar;
INSERT @R SELECT 'captura: 3 arquivos, último = L7', '3 L7.trn', CAST(COUNT(*) AS VARCHAR(5)) + ' ' + MAX(CASE WHEN ULTIMO = 1 THEN REPLACE(CAST(ARQUIVO AS VARCHAR(400)), 'C:\t\', '') END) FROM @C;
INSERT @R SELECT 'captura: pedido EXECUTANDO', 'EXECUTANDO', SITUACAO FROM SIS.Backup_Restauracao WHERE ID_RESTAURACAO = @Id;
DELETE @C;
INSERT @C EXEC SIS.SIS_Backup_Restauracao_Capturar;
INSERT @R SELECT 'captura com outro executando: nada', '0', CAST(COUNT(*) AS VARCHAR(5)) FROM @C;
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Cancelar @IdUsuario = @Renata, @IdRestauracao = @Id;
INSERT @R SELECT 'cancelar depois de começar: recusa', '0', CAST(SUCESSO AS VARCHAR(1)) FROM @S; DELETE @S;

-- 6) resultado; e o pedido regravado com o mesmo ID depois de "voltar ao passado"
DECLARE @Antes2 BIGINT = ISNULL((SELECT MAX(ID_EMAIL) FROM SIS.Email_Fila), 0);
DECLARE @Ped TABLE (TIPO_PONTO VARCHAR(10), DT_PONTO DATETIME2(0), MOTIVO NVARCHAR(400), IDU INT, USU NVARCHAR(100), DTP DATETIME2(0), DTI DATETIME2(0), PLANO NVARCHAR(4000));
INSERT @Ped SELECT TIPO_PONTO, DT_PONTO, MOTIVO, ID_USUARIO_PEDIDO, USUARIO_PEDIDO, DT_PEDIDO, DT_INICIO, PLANO FROM SIS.Backup_Restauracao WHERE ID_RESTAURACAO = @Id;
DELETE FROM SIS.Backup_Restauracao WHERE ID_RESTAURACAO = @Id;   -- simula o banco restaurado sem o pedido
DECLARE @tp VARCHAR(10), @dp DATETIME2(0), @mo NVARCHAR(400), @iu INT, @us NVARCHAR(100), @dtp DATETIME2(0), @dti DATETIME2(0), @pl NVARCHAR(4000);
SELECT @tp = TIPO_PONTO, @dp = DT_PONTO, @mo = MOTIVO, @iu = IDU, @us = USU, @dtp = DTP, @dti = DTI, @pl = PLANO FROM @Ped;
INSERT @X EXEC SIS.SIS_Backup_Restauracao_Resultado @IdRestauracao = @Id, @Situacao = 'OK', @Mensagem = N'Restaurado (teste).', @TipoPonto = @tp, @DtPonto = @dp,
     @Motivo = @mo, @IdUsuarioPedido = @iu, @UsuarioPedido = @us, @DtPedido = @dtp, @DtInicio = @dti, @Plano = @pl, @ArquivoSeguranca = N'C:\t\S2.bak';
INSERT @R SELECT 'resultado: pedido regravado com o mesmo ID, OK', CAST(@Id AS VARCHAR(10)) + ' OK ' + @LoginAdm, CAST(ID_RESTAURACAO AS VARCHAR(10)) + ' ' + SITUACAO + ' ' + USUARIO_PEDIDO FROM SIS.Backup_Restauracao WHERE ID_RESTAURACAO = @Id;
INSERT @R SELECT 'resultado: aviso por e-mail', '1', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.Email_Fila WHERE ID_EMAIL > @Antes2 AND ASSUNTO LIKE N'%restauração do banco concluída%';

-- 7) pedido de um backup escolhido (Celso) e cancelamento antes de começar
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Celso, @TipoPonto = 'BACKUP', @IdBackup = @IdS1, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
SELECT @Id2 = ID_RESTAURACAO FROM @S;
INSERT @R SELECT 'backup escolhido: aceito, ID novo maior', '1 SIM', CAST(SUCESSO AS VARCHAR(1)) + ' ' + CASE WHEN ID_RESTAURACAO > @Id THEN 'SIM' ELSE 'NAO' END FROM @S; DELETE @S;
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Cancelar @IdUsuario = @Renata, @IdRestauracao = @Id2;
INSERT @R SELECT 'cancelar pedido aguardando', '1 CANCELADO', CAST((SELECT SUCESSO FROM @S) AS VARCHAR(1)) + ' ' + SITUACAO FROM SIS.Backup_Restauracao WHERE ID_RESTAURACAO = @Id2; DELETE @S;

-- 8) plano que deixou de fechar até a captura: ERRO, sem restaurar
INSERT @S EXEC SIS.SIS_Backup_Restauracao_Solicitar @IdUsuario = @Celso, @TipoPonto = 'BACKUP', @IdBackup = @IdS1, @Motivo = N'teste de homologação', @Confirmacao = N'RESTAURAR', @SenhaConferida = 1;
SELECT @Id2 = ID_RESTAURACAO FROM @S; DELETE @S;
UPDATE SIS.Backup_Execucao SET ARQUIVO_EXISTE = 0 WHERE ID_BACKUP = @IdS1;
EXEC SIS.SIS_Backup_Restauracao_Capturar;
INSERT @R SELECT 'arquivo apagado antes da captura: pedido ERRO', 'ERRO', SITUACAO FROM SIS.Backup_Restauracao WHERE ID_RESTAURACAO = @Id2;

-- 9) lista de pedidos e segurança
DECLARE @LR TABLE (ID INT, TP VARCHAR(10), TPN NVARCHAR(30), IDB BIGINT, ARQ NVARCHAR(400), VOLTA DATETIME2(0), MOTIVO NVARCHAR(400), SIT VARCHAR(12), SITN NVARCHAR(20),
                   USU NVARCHAR(100), DTP DATETIME2(0), DTI DATETIME2(0), DTF DATETIME2(0), PLANO NVARCHAR(4000), SEG NVARCHAR(400), MSG NVARCHAR(2000), PODE BIT);
INSERT @LR EXEC SIS.SIS_Backup_Restauracao_Listar @IdUsuario = @Renata;
INSERT @R SELECT 'lista de pedidos: 3', '3', CAST(COUNT(*) AS VARCHAR(5)) FROM @LR;
INSERT @R SELECT 'administrador nível 1 (' + @LoginAdm + ') pode RESTAURAR', '1', CAST(SIS.fn_SIS_Tem_Permissao(@Renata, 'SIS_BACKUP', 'RESTAURAR') AS VARCHAR(1));
INSERT @R SELECT 'celso (nível 2) pode RESTAURAR', '1', CAST(SIS.fn_SIS_Tem_Permissao(@Celso, 'SIS_BACKUP', 'RESTAURAR') AS VARCHAR(1));
INSERT @R SELECT 'claude (consulta) não pode RESTAURAR', '0', CAST(SIS.fn_SIS_Tem_Permissao(@Claude, 'SIS_BACKUP', 'RESTAURAR') AS VARCHAR(1));
INSERT @R SELECT 'papel da API sem EXECUTE em ' + o.n, 'NEGADO',
       CASE WHEN EXISTS (SELECT 1 FROM sys.database_permissions p JOIN sys.database_principals r ON r.principal_id = p.grantee_principal_id
                         WHERE r.name = 'rl_sistemacmj_api' AND p.major_id = OBJECT_ID('SIS.' + o.n) AND p.state_desc = 'DENY') THEN 'NEGADO' ELSE 'LIBERADO' END
FROM (VALUES ('SIS_Backup_Restauracao_Capturar'), ('SIS_Backup_Restauracao_Resultado')) o (n);
ROLLBACK TRANSACTION;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @R;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @R;
GO
