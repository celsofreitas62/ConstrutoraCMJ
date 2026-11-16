/*******************************************************************************
  Objeto      : [SIS].[Grupo_Email_Destinatario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Endereços de cada grupo de e-mail. O mesmo endereço não se
                repete no mesmo grupo. Mantidos pela tela "Grupos de e-mail"
                (SIS_Grupo_Email_Gravar).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Grupo_Email_Destinatario]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Grupo_Email_Destinatario]
    (
        ID_GRUPO_EMAIL_DESTINATARIO  INT            IDENTITY(1,1) NOT NULL,
        ID_GRUPO_EMAIL               INT            NOT NULL,
        EMAIL                        NVARCHAR(256)  NOT NULL,
        NOME                         NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_NOME            DEFAULT (N''),
        ATIVO                        BIT            NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_ATIVO           DEFAULT (1),
        DT_CRIACAO                   DATETIME2(0)   NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO                 DATETIME2(0)   NULL,
        USUARIO_ALTERACAO            NVARCHAR(100)  NULL,
        CONSTRAINT PK_Grupo_Email_Destinatario       PRIMARY KEY CLUSTERED (ID_GRUPO_EMAIL_DESTINATARIO),
        CONSTRAINT UQ_Grupo_Email_Destinatario_EMAIL UNIQUE (ID_GRUPO_EMAIL, EMAIL),
        CONSTRAINT FK_Grupo_Email_Destinatario_Grupo FOREIGN KEY (ID_GRUPO_EMAIL) REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL)
    );
END;
GO
