/*******************************************************************************
  Objeto      : [SIS].[Lixeira]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Registros mandados para a lixeira pelo botão Excluir das telas
                (P20). O registro continua na tabela dele, desativado e com
                DT_EXCLUSAO preenchida; esta tabela guarda de onde veio (tela),
                quem excluiu, o motivo, como estava o ATIVO antes e até quando
                fica guardado (DT_APAGAR).
                SITUACAO: LIXEIRA (pode recuperar), RECUPERADO (voltou) ou
                APAGADO (apagado de vez pela rotina diária ou pelo botão
                Esvaziar agora; a cópia completa fica em SIS.Auditoria).
                DT_AVISO: quando saiu o e-mail avisando que vai ser apagado.
                Nunca é apagada: é o histórico da lixeira.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b, P20).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Lixeira]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Lixeira]
    (
        ID_LIXEIRA           BIGINT         IDENTITY(1,1) NOT NULL,
        TABELA               NVARCHAR(256)  NOT NULL,
        ID_REGISTRO          BIGINT         NOT NULL,
        ITEM_CODIGO          VARCHAR(40)    NOT NULL,
        DESCRICAO            NVARCHAR(400)  NOT NULL CONSTRAINT DF_Lixeira_DESCRICAO       DEFAULT (N''),
        MOTIVO               NVARCHAR(400)  NOT NULL CONSTRAINT DF_Lixeira_MOTIVO          DEFAULT (N''),
        ATIVO_ANTES          BIT            NOT NULL CONSTRAINT DF_Lixeira_ATIVO_ANTES     DEFAULT (1),
        DT_EXCLUSAO          DATETIME2(0)   NOT NULL CONSTRAINT DF_Lixeira_DT_EXCLUSAO     DEFAULT (SYSDATETIME()),
        USUARIO_EXCLUSAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lixeira_USUARIO_EXCLUSAO DEFAULT (N''),
        ID_USUARIO_EXCLUSAO  INT            NULL,
        DT_APAGAR            DATE           NOT NULL,
        SITUACAO             VARCHAR(12)    NOT NULL CONSTRAINT DF_Lixeira_SITUACAO        DEFAULT ('LIXEIRA'),
        DT_SITUACAO          DATETIME2(0)   NULL,
        USUARIO_SITUACAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lixeira_USUARIO_SITUACAO DEFAULT (N''),
        MOTIVO_SITUACAO      NVARCHAR(400)  NOT NULL CONSTRAINT DF_Lixeira_MOTIVO_SITUACAO DEFAULT (N''),
        DT_AVISO             DATETIME2(0)   NULL,
        DT_CRIACAO           DATETIME2(0)   NOT NULL CONSTRAINT DF_Lixeira_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lixeira_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)   NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lixeira          PRIMARY KEY CLUSTERED (ID_LIXEIRA),
        CONSTRAINT CK_Lixeira_SITUACAO CHECK (SITUACAO IN ('LIXEIRA', 'RECUPERADO', 'APAGADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Lixeira]') AND i.name = N'UQ_Lixeira_TABELA_REGISTRO')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Lixeira_TABELA_REGISTRO ON [SIS].[Lixeira] (TABELA, ID_REGISTRO) WHERE SITUACAO = 'LIXEIRA';
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Lixeira]') AND i.name = N'IX_Lixeira_SITUACAO_DT_APAGAR')
    CREATE NONCLUSTERED INDEX IX_Lixeira_SITUACAO_DT_APAGAR ON [SIS].[Lixeira] (SITUACAO, DT_APAGAR) INCLUDE (TABELA, ID_REGISTRO, ITEM_CODIGO);
GO
