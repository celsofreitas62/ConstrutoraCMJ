/*******************************************************************************
  Objeto      : [SIS].[Log_Erro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Log de erros técnicos do SQL, da API e do serviço (PADRAO_SQL
                regra 13). Nunca é apagado. As colunas que os gabaritos usam
                (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO) bastam;
                ORIGEM, USUARIO e ESTACAO têm valor padrão.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Log_Erro]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Log_Erro]
    (
        ID_LOG_ERRO   BIGINT         IDENTITY(1,1) NOT NULL,
        ROTINA        NVARCHAR(256)  NOT NULL CONSTRAINT DF_Log_Erro_ROTINA      DEFAULT (N''),
        ETAPA         NVARCHAR(200)  NOT NULL CONSTRAINT DF_Log_Erro_ETAPA       DEFAULT (N''),
        NUMERO_ERRO   INT            NOT NULL CONSTRAINT DF_Log_Erro_NUMERO_ERRO DEFAULT (0),
        MENSAGEM      NVARCHAR(4000) NOT NULL CONSTRAINT DF_Log_Erro_MENSAGEM    DEFAULT (N''),
        LINHA         INT            NOT NULL CONSTRAINT DF_Log_Erro_LINHA       DEFAULT (0),
        ORIGEM        VARCHAR(10)    NOT NULL CONSTRAINT DF_Log_Erro_ORIGEM      DEFAULT ('SQL'),
        USUARIO       NVARCHAR(100)  NOT NULL CONSTRAINT DF_Log_Erro_USUARIO     DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        ESTACAO       NVARCHAR(128)  NOT NULL CONSTRAINT DF_Log_Erro_ESTACAO     DEFAULT (ISNULL(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'ESTACAO')), ISNULL(HOST_NAME(), N''))),
        DETALHE       NVARCHAR(MAX)  NULL,
        DT_ERRO       DATETIME2(0)   NOT NULL CONSTRAINT DF_Log_Erro_DT_ERRO     DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Log_Erro        PRIMARY KEY CLUSTERED (ID_LOG_ERRO),
        CONSTRAINT CK_Log_Erro_ORIGEM CHECK (ORIGEM IN ('SQL', 'API', 'SERVICO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Log_Erro]') AND i.name = N'IX_Log_Erro_DT_ERRO')
    CREATE NONCLUSTERED INDEX IX_Log_Erro_DT_ERRO ON [SIS].[Log_Erro] (DT_ERRO) INCLUDE (ORIGEM, ROTINA);
GO
