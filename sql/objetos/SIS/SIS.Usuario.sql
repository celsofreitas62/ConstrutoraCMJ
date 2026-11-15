/*******************************************************************************
  Objeto      : [SIS].[Usuario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Usuários do sistema (seção 3.6).
                SENHA: o banco NUNCA recebe a senha. A API calcula o hash
                PBKDF2-SHA256 (salt aleatório por usuário, iterações do
                parâmetro SENHA_PBKDF2_ITERACOES) e grava hash + salt +
                iterações + algoritmo por SIS_Usuario_Senha_Gravar. No login a
                API lê esses dados (SIS_Usuario_Login_Obter), confere a senha
                digitada e informa o resultado (SIS_Usuario_Login_Processar).
                SENHA_HASH NULL = senha ainda não definida (não entra).
                TROCAR_SENHA = 1: obriga a trocar no próximo acesso.
                INTERNO = 1: usuário técnico SISTEMA (rotinas automáticas e
                migração); nunca faz login.
                Usuário não é apagado: desativa (ATIVO = 0).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Usuario]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Usuario]
    (
        ID_USUARIO          INT             IDENTITY(1,1) NOT NULL,
        LOGIN               VARCHAR(40)     NOT NULL,
        NOME                NVARCHAR(100)   NOT NULL,
        EMAIL               NVARCHAR(200)   NOT NULL CONSTRAINT DF_Usuario_EMAIL              DEFAULT (N''),
        ID_PERFIL           INT             NOT NULL,
        SENHA_HASH          VARBINARY(64)   NULL,
        SENHA_SALT          VARBINARY(64)   NULL,
        SENHA_ITERACOES     INT             NOT NULL CONSTRAINT DF_Usuario_SENHA_ITERACOES    DEFAULT (0),
        SENHA_ALGORITMO     VARCHAR(30)     NOT NULL CONSTRAINT DF_Usuario_SENHA_ALGORITMO    DEFAULT (''),
        DT_SENHA            DATETIME2(0)    NULL,
        TROCAR_SENHA        BIT             NOT NULL CONSTRAINT DF_Usuario_TROCAR_SENHA       DEFAULT (1),
        TENTATIVAS_ERRADAS  SMALLINT        NOT NULL CONSTRAINT DF_Usuario_TENTATIVAS_ERRADAS DEFAULT (0),
        BLOQUEADO           BIT             NOT NULL CONSTRAINT DF_Usuario_BLOQUEADO          DEFAULT (0),
        DT_BLOQUEIO         DATETIME2(0)    NULL,
        DT_ULTIMO_LOGIN     DATETIME2(0)    NULL,
        INTERNO             BIT             NOT NULL CONSTRAINT DF_Usuario_INTERNO            DEFAULT (0),
        ATIVO               BIT             NOT NULL CONSTRAINT DF_Usuario_ATIVO              DEFAULT (1),
        DT_CRIACAO          DATETIME2(0)    NOT NULL CONSTRAINT DF_Usuario_DT_CRIACAO         DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO     NVARCHAR(100)   NOT NULL CONSTRAINT DF_Usuario_USUARIO_CRIACAO    DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO        DATETIME2(0)    NULL,
        USUARIO_ALTERACAO   NVARCHAR(100)   NULL,
        CONSTRAINT PK_Usuario        PRIMARY KEY CLUSTERED (ID_USUARIO),
        CONSTRAINT UQ_Usuario_LOGIN  UNIQUE (LOGIN),
        CONSTRAINT FK_Usuario_Perfil FOREIGN KEY (ID_PERFIL) REFERENCES [SIS].[Perfil] (ID_PERFIL),
        CONSTRAINT CK_Usuario_LOGIN  CHECK (LEN(LOGIN) >= 3 AND LOGIN NOT LIKE '%[^a-z0-9._-]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Usuario_NOME   CHECK (NOME <> N'')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Usuario]') AND i.name = N'IX_Usuario_ID_PERFIL')
    CREATE NONCLUSTERED INDEX IX_Usuario_ID_PERFIL ON [SIS].[Usuario] (ID_PERFIL);
GO
