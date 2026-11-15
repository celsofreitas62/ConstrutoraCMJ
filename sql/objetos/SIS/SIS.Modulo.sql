/*******************************************************************************
  Objeto      : [SIS].[Modulo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Módulos do sistema (CAD, FIN, VENDA...). Base do menu lateral,
                das permissões e da licença: LIBERADO_LICENCA é atualizado só
                pela procedure da licença (etapa 02b), nunca por tela.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Modulo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Modulo]
    (
        ID_MODULO          INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(10)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        ORDEM_MENU         SMALLINT       NOT NULL CONSTRAINT DF_Modulo_ORDEM_MENU       DEFAULT (0),
        ICONE              VARCHAR(40)    NOT NULL CONSTRAINT DF_Modulo_ICONE            DEFAULT (''),
        LIBERADO_LICENCA   BIT            NOT NULL CONSTRAINT DF_Modulo_LIBERADO_LICENCA DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Modulo_ATIVO            DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Modulo_DT_CRIACAO       DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Modulo_USUARIO_CRIACAO  DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Modulo        PRIMARY KEY CLUSTERED (ID_MODULO),
        CONSTRAINT UQ_Modulo_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Modulo_CODIGO CHECK (CODIGO <> '' AND CODIGO NOT LIKE '%[^A-Z]%')
    );
END;
GO
