/*******************************************************************************
  Objeto      : [SIS].[Sessao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Sessões de uso (login até logout/expiração).
                TOKEN_HASH: a API gera um token aleatório (32 bytes) que fica
                só no cookie do navegador; o banco guarda apenas o SHA-256
                dele. Quem ler a tabela não consegue usar a sessão de outro.
                DT_FIM preenchida = sessão encerrada; MOTIVO_FIM diz por quê.
                A expiração por inatividade usa SESSAO_MINUTOS_INATIVIDADE.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Sessao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Sessao]
    (
        ID_SESSAO          BIGINT          IDENTITY(1,1) NOT NULL,
        ID_USUARIO         INT             NOT NULL,
        TOKEN_HASH         VARBINARY(32)   NOT NULL,
        DT_LOGIN           DATETIME2(0)    NOT NULL CONSTRAINT DF_Sessao_DT_LOGIN         DEFAULT (SYSDATETIME()),
        DT_ULTIMO_ACESSO   DATETIME2(0)    NOT NULL CONSTRAINT DF_Sessao_DT_ULTIMO_ACESSO DEFAULT (SYSDATETIME()),
        DT_FIM             DATETIME2(0)    NULL,
        MOTIVO_FIM         VARCHAR(20)     NOT NULL CONSTRAINT DF_Sessao_MOTIVO_FIM       DEFAULT (''),
        IP                 VARCHAR(45)     NOT NULL CONSTRAINT DF_Sessao_IP               DEFAULT (''),
        ESTACAO            NVARCHAR(128)   NOT NULL CONSTRAINT DF_Sessao_ESTACAO          DEFAULT (N''),
        NAVEGADOR          NVARCHAR(300)   NOT NULL CONSTRAINT DF_Sessao_NAVEGADOR        DEFAULT (N''),
        CONSTRAINT PK_Sessao            PRIMARY KEY CLUSTERED (ID_SESSAO),
        CONSTRAINT UQ_Sessao_TOKEN_HASH UNIQUE (TOKEN_HASH),
        CONSTRAINT FK_Sessao_Usuario    FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Sessao_TOKEN_HASH CHECK (DATALENGTH(TOKEN_HASH) = 32),
        CONSTRAINT CK_Sessao_MOTIVO_FIM CHECK (MOTIVO_FIM IN ('', 'LOGOUT', 'EXPIRADA', 'BLOQUEIO', 'INATIVADO', 'SENHA_ALTERADA', 'ADMIN'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Sessao]') AND i.name = N'IX_Sessao_ID_USUARIO_ABERTA')
    CREATE NONCLUSTERED INDEX IX_Sessao_ID_USUARIO_ABERTA ON [SIS].[Sessao] (ID_USUARIO) WHERE DT_FIM IS NULL;
GO
