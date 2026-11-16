/*******************************************************************************
  Objeto      : [SIS].[Grupo_Email]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Grupos de destinatários dos e-mails do sistema (PADRAO_EMAIL
                regra 10): nenhum e-mail fica fixo no código; a rotina pede
                o grupo (ex.: FIN_PAGAR) e a function devolve os endereços.
                Um grupo pode misturar e-mails internos e externos.
                Os endereços ficam em SIS.Grupo_Email_Destinatario.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Grupo_Email]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Grupo_Email]
    (
        ID_GRUPO_EMAIL     INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(30)    NOT NULL,
        NOME               NVARCHAR(80)   NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Grupo_Email_DESCRICAO       DEFAULT (N''),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Grupo_Email_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Grupo_Email_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Grupo_Email        PRIMARY KEY CLUSTERED (ID_GRUPO_EMAIL),
        CONSTRAINT UQ_Grupo_Email_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Grupo_Email_CODIGO CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO
