/*******************************************************************************
  Arquivo     : SISTEMACMJ_00_Criar_Banco.sql
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026 (etapa 03d)
  Descrição   : Cria o banco SISTEMACMJ no servidor (passo anterior ao MASTER).
                Collation Latin1_General_CI_AS (a mesma do desenvolvimento).
                Arquivos do banco na pasta padrão da instância (SSD).
                Modelo de recuperação SIMPLE por enquanto: a decisão sobre
                backup do log (perda máxima de 1 hora) é da etapa 3d-B.
                Idempotente: se o banco já existe, nada é alterado.
                AUTO_CLOSE desligado (o Express cria ligado).
                Não usa "USE master": roda conectado em qualquer banco.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, ensaio do MASTER).

  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5. Depois, abrir o
                SISTEMACMJ_MASTER_Instalacao.sql com o banco SISTEMACMJ selecionado.
*******************************************************************************/
IF DB_ID(N'SISTEMACMJ') IS NULL
BEGIN
    CREATE DATABASE [SISTEMACMJ] COLLATE Latin1_General_CI_AS;
    PRINT N'Banco SISTEMACMJ criado.';
END
ELSE
    PRINT N'Banco SISTEMACMJ já existia: nada alterado.';
GO

IF EXISTS (SELECT 1 FROM sys.databases d WHERE d.name = N'SISTEMACMJ' AND d.recovery_model_desc <> N'SIMPLE')
   AND NOT EXISTS (SELECT 1 FROM msdb.dbo.backupset b WHERE b.database_name = N'SISTEMACMJ')
    ALTER DATABASE [SISTEMACMJ] SET RECOVERY SIMPLE;
GO

-- SQL Server Express cria o banco com AUTO_CLOSE ligado (fecha e reabre a cada uso): desligar.
IF EXISTS (SELECT 1 FROM sys.databases d WHERE d.name = N'SISTEMACMJ' AND d.is_auto_close_on = 1)
    ALTER DATABASE [SISTEMACMJ] SET AUTO_CLOSE OFF;
GO

SELECT d.name AS BANCO, d.collation_name AS COLLATION, d.recovery_model_desc AS RECUPERACAO,
       d.compatibility_level AS COMPATIBILIDADE, d.is_auto_close_on AS AUTO_CLOSE, d.create_date AS CRIADO_EM
FROM sys.databases d
WHERE d.name = N'SISTEMACMJ';
GO
