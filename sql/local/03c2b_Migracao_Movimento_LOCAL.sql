/*******************************************************************************
  Script      : transformação do movimento do Access (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026 (etapa 03c2, parte B)
  Descrição   : 1) prévia (nada é gravado no financeiro);
                2) gravação (apaga a carga anterior da migração e grava de novo);
                3) conferência Access x sistema novo.
                Pré-requisito: pacote 03c2b rodado; cadastros migrados
                (sql/local/03c2_Migracao_Cadastros_LOCAL.sql).
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5. Leva alguns minutos.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Este script só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

-- triggers de auditoria ainda no formato antigo (lento em carga grande): tem de dar 0
SELECT 'TRIGGERS_ANTIGAS' AS GRADE, COUNT(*) AS QTD FROM sys.sql_modules m INNER JOIN sys.triggers t ON t.object_id = m.object_id
WHERE t.name LIKE N'tg[_]%[_]Auditoria' AND m.definition LIKE N'%FROM inserted x WHERE%';
GO
EXEC MIG.MIG_Movimento_Transformar @Executar = 0;
GO
EXEC MIG.MIG_Movimento_Transformar @Executar = 1;
GO
EXEC MIG.MIG_Movimento_Conferencia_Listar;
GO

SET NOEXEC OFF;
GO
