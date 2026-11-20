/*******************************************************************************
  Teste       : 03d - registro e avisos do backup do servidor
                (SIS_Backup_Registrar, SIS_Backup_Conferir_Processar)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 20/11/2026 (v1.0). Roda no LOCAL ou no ensaio. Tudo numa
                transação desfeita (ROLLBACK): nada fica gravado. E-mail de
                alerta para um endereço de teste (desviado no _LOCAL).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @R TABLE (CASO VARCHAR(90), ESPERADO VARCHAR(40), OBTIDO VARCHAR(400));
DECLARE @I TABLE (ID_BACKUP BIGINT);
DECLARE @Antes BIGINT = ISNULL((SELECT MAX(ID_EMAIL) FROM SIS.Email_Fila), 0);
DECLARE @Agora DATETIME2(0) = SYSDATETIME();

BEGIN TRANSACTION;
UPDATE SIS.Parametro SET VALOR = N'celsofreitas62@gmail.com' WHERE CHAVE = 'EMAIL_ADMIN_ALERTA';
DELETE FROM SIS.Backup_Execucao;   -- (desfeito no fim)

-- 1) backup OK: registra, sem e-mail
INSERT @I EXEC SIS.SIS_Backup_Registrar @Tipo = 'COMPLETO', @Arquivo = N'C:\x\a.bak', @DtInicio = @Agora, @DtFim = @Agora, @TamanhoMb = 12.3, @Situacao = 'OK';
INSERT @R SELECT 'completo OK registrado', '1', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.Backup_Execucao WHERE TIPO = 'COMPLETO' AND SITUACAO = 'OK';
INSERT @R SELECT 'completo OK: sem e-mail', '0', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.Email_Fila WHERE ID_EMAIL > @Antes;

-- 2) backup com ERRO: registra e manda alerta (uma vez)
INSERT @I EXEC SIS.SIS_Backup_Registrar @Tipo = 'LOG', @Arquivo = N'', @DtInicio = @Agora, @Situacao = 'ERRO', @Mensagem = N'disco cheio (teste)';
INSERT @R SELECT 'erro: alerta na fila', '1', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.Email_Fila WHERE ID_EMAIL > @Antes AND ASSUNTO LIKE N'%falha no backup%';

-- 3) arquivos que sumiram da pasta ficam marcados
INSERT @I EXEC SIS.SIS_Backup_Registrar @Tipo = 'LOG', @Arquivo = N'C:\x\b.trn', @DtInicio = @Agora, @Situacao = 'OK', @ArquivosExistentes = N'C:\x\b.trn';
INSERT @R SELECT 'arquivo apagado pela retencao: ARQUIVO_EXISTE 0', '0', CAST(ARQUIVO_EXISTE AS VARCHAR(1)) FROM SIS.Backup_Execucao WHERE ARQUIVO = N'C:\x\a.bak';

-- 4) conferencia: tudo em dia = sem aviso
EXEC SIS.SIS_Backup_Conferir_Processar;
INSERT @R SELECT 'em dia: sem aviso de atraso', '0', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.Email_Fila WHERE ID_EMAIL > @Antes AND ASSUNTO LIKE N'%atrasado%';

-- 5) completo velho (30 h) e log velho (5 h): aviso, uma vez por dia
UPDATE SIS.Backup_Execucao SET DT_INICIO = DATEADD(HOUR, -30, @Agora) WHERE TIPO = 'COMPLETO';
UPDATE SIS.Backup_Execucao SET DT_INICIO = DATEADD(HOUR, -5, @Agora) WHERE TIPO = 'LOG';
EXEC SIS.SIS_Backup_Conferir_Processar;
EXEC SIS.SIS_Backup_Conferir_Processar;
INSERT @R SELECT 'atrasado: um aviso (nao repete no dia)', '1', CAST(COUNT(*) AS VARCHAR(5)) FROM SIS.Email_Fila WHERE ID_EMAIL > @Antes AND ASSUNTO LIKE N'%atrasado%';
INSERT @R SELECT 'aviso cita completo e log', 'SIM', CASE WHEN EXISTS (SELECT 1 FROM SIS.Email_Fila WHERE ID_EMAIL > @Antes AND ASSUNTO LIKE N'%atrasado%' AND CORPO_HTML LIKE N'%Backup completo%' AND CORPO_HTML LIKE N'%log%') THEN 'SIM' ELSE 'NAO' END;

-- 6) a API nao pode registrar backup
INSERT @R SELECT 'papel da API sem EXECUTE no registrar', 'NEGADO',
       CASE WHEN EXISTS (SELECT 1 FROM sys.database_permissions p JOIN sys.database_principals r ON r.principal_id = p.grantee_principal_id
                         WHERE r.name = 'rl_sistemacmj_api' AND p.major_id = OBJECT_ID('SIS.SIS_Backup_Registrar') AND p.state_desc = 'DENY') THEN 'NEGADO' ELSE 'LIBERADO' END;
INSERT @R SELECT 'rotina BACKUP_CONFERIR (' + DB_NAME() + ')', CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'DESLIGADA' ELSE 'LIGADA' END,
       CASE WHEN ATIVA = 1 THEN 'LIGADA' ELSE 'DESLIGADA' END FROM SIS.Rotina WHERE CODIGO = 'BACKUP_CONFERIR';
ROLLBACK TRANSACTION;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @R;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @R;
GO
