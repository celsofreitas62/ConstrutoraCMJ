/*******************************************************************************
  Objeto      : carga do backup do servidor
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Rotina BACKUP_CONFERIR (de hora em hora; avisa atraso de backup
                por e-mail): nasce ATIVA no servidor e DESLIGADA no banco de
                desenvolvimento (_LOCAL), onde o backup é outro (backup\ do
                notebook) e não se registra em SIS.Backup.
                Segurança: o login da API não pode registrar backup (DENY).
                Só insere o que falta (regra 39).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
    v1.1 (20/11/2026) - Etapa 03d2: menu Backups e tela SIS_BACKUP (ações VER e
                        RESTAURAR); DENY para a API nas rotinas só do script
                        (SIS_Backup_Restauracao_Capturar e _Resultado).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT 'BACKUP_CONFERIR', N'Conferir o backup',
       N'Avisa por e-mail (EMAIL_ADMIN_ALERTA) quando o backup completo, o do log ou o teste de restauração atrasam (parâmetros BACKUP_*_ALERTA_*).',
       N'SIS.SIS_Backup_Conferir_Processar', m.ID_MODULO, 'MINUTOS', 60, '00:00', '', 0, 10,
       CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 0 ELSE 1 END,
       SIS.fn_SIS_Rotina_Proxima('MINUTOS', 60, '00:00', '', 0, SYSDATETIME()), N'instalacao'
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = 'BACKUP_CONFERIR');
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'SIS_BACKUPS', N'Backups', 'MENU', '', 35, 0, 1, ''
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_BACKUPS');
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'SIS_BACKUP', N'Backups e restauração', 'TELA', 'sis/backups.html', 10, 0, 1, 'SIS.Backup_Restauracao'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_BACKUPS'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_BACKUP');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('RESTAURAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'SIS_BACKUP'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

IF DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NOT NULL
BEGIN
    DENY EXECUTE ON [SIS].[SIS_Backup_Registrar] TO [rl_sistemacmj_api];
    DENY EXECUTE ON [SIS].[SIS_Backup_Restauracao_Capturar] TO [rl_sistemacmj_api];
    DENY EXECUTE ON [SIS].[SIS_Backup_Restauracao_Resultado] TO [rl_sistemacmj_api];
END;
GO
