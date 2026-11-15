/*******************************************************************************
  Objeto      : [SIS].[Log_Passo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Rastreamento passo a passo de rotinas críticas (PADRAO_SQL
                regra 47): retorno bancário, remessa, geração de parcelas.
                Cada execução tem um RUN_ID. Limpo por SIS_Log_Limpar_Processar
                conforme o parâmetro LOG_PASSO_DIAS_RETENCAO.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Log_Passo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Log_Passo]
    (
        ID_LOG_PASSO  BIGINT            IDENTITY(1,1) NOT NULL,
        RUN_ID        UNIQUEIDENTIFIER  NOT NULL,
        ROTINA        NVARCHAR(256)     NOT NULL CONSTRAINT DF_Log_Passo_ROTINA   DEFAULT (N''),
        ETAPA         NVARCHAR(200)     NOT NULL CONSTRAINT DF_Log_Passo_ETAPA    DEFAULT (N''),
        STATUS        VARCHAR(10)       NOT NULL CONSTRAINT DF_Log_Passo_STATUS   DEFAULT ('OK'),
        DETALHE       NVARCHAR(4000)    NOT NULL CONSTRAINT DF_Log_Passo_DETALHE  DEFAULT (N''),
        DT_PASSO      DATETIME2(0)      NOT NULL CONSTRAINT DF_Log_Passo_DT_PASSO DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Log_Passo        PRIMARY KEY CLUSTERED (ID_LOG_PASSO),
        CONSTRAINT CK_Log_Passo_STATUS CHECK (STATUS IN ('INICIO', 'OK', 'AVISO', 'ERRO', 'FIM'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Log_Passo]') AND i.name = N'IX_Log_Passo_RUN_ID')
    CREATE NONCLUSTERED INDEX IX_Log_Passo_RUN_ID ON [SIS].[Log_Passo] (RUN_ID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Log_Passo]') AND i.name = N'IX_Log_Passo_DT_PASSO')
    CREATE NONCLUSTERED INDEX IX_Log_Passo_DT_PASSO ON [SIS].[Log_Passo] (DT_PASSO);
GO
