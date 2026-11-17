/*******************************************************************************
  Script      : migração dos cadastros do Access (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026 (etapa 03c2, parte A)
  Descrição   : 1) migra os cadastros (MIG.MIG_Cadastros_Processar);
                2) roda de novo para provar que é repetível: a 2ª rodada não
                   pode alterar nada (grade REPETIVEL, ALTERACOES = 0);
                3) conferência (MIG.MIG_Cadastros_Conferencia_Listar).
                Pré-requisito: pacote 03c2 rodado e o ensaio do movimento
                (sql/local/03c_Ensaio_Migracao_LOCAL.sql) já feito, para
                existir o MIG.Movimento.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Este script só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

EXEC MIG.MIG_Cadastros_Processar;
GO

DECLARE @Aud BIGINT = ISNULL((SELECT MAX(a.ID_AUDITORIA) FROM SIS.Auditoria a), 0);
DECLARE @Resumo TABLE (ORDEM INT, CADASTRO NVARCHAR(200), NO_SISTEMA_NOVO INT, ATIVOS INT);
INSERT INTO @Resumo EXEC MIG.MIG_Cadastros_Processar;
SELECT 'REPETIVEL' AS GRADE, COUNT(*) AS ALTERACOES_NA_SEGUNDA_RODADA
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @Aud;
GO

EXEC MIG.MIG_Cadastros_Conferencia_Listar;
GO

SET NOEXEC OFF;
GO
