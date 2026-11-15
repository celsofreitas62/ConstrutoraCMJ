/*******************************************************************************
  Objeto      : banco [SISTEMACMJ_LOCAL] (somente desenvolvimento)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Cria o banco de desenvolvimento SISTEMACMJ_LOCAL na instância
                .\SQL2025 do notebook do Celso, se ainda não existir.
                Não faz parte do MASTER: em produção o banco SISTEMACMJ é criado
                pelo roteiro de instalação do servidor.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Como rodar: SSMS conectado em .\SQL2025 > Arquivo > Abrir > este arquivo > F5.
  Pode rodar de novo: se o banco já existir, nada é alterado.
*******************************************************************************/
USE [master];
GO

IF ISNULL(CONVERT(NVARCHAR(128), SERVERPROPERTY('InstanceName')), N'') <> N'SQL2025'
    PRINT N'ATENÇÃO: você não está na instância .\SQL2025. Confira a conexão antes de seguir.';
GO

IF DB_ID(N'SISTEMACMJ_LOCAL') IS NULL
BEGIN
    CREATE DATABASE [SISTEMACMJ_LOCAL];
    PRINT N'Banco SISTEMACMJ_LOCAL criado.';
END
ELSE
    PRINT N'Banco SISTEMACMJ_LOCAL já existia: nada alterado.';
GO

-- Desenvolvimento: sem backup de log, então modelo de recuperação simples.
IF EXISTS (SELECT 1 FROM sys.databases d WHERE d.name = N'SISTEMACMJ_LOCAL' AND d.recovery_model_desc <> N'SIMPLE')
    ALTER DATABASE [SISTEMACMJ_LOCAL] SET RECOVERY SIMPLE;
GO

SELECT d.name AS BANCO, d.collation_name AS COLLATION, d.recovery_model_desc AS RECUPERACAO, d.compatibility_level AS COMPATIBILIDADE
FROM sys.databases d
WHERE d.name = N'SISTEMACMJ_LOCAL';
GO
