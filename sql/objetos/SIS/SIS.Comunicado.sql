/*******************************************************************************
  Objeto      : [SIS].[Comunicado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Comunicado periódico por e-mail (pedido do Celso, 17/11/2026). O
                primeiro é o BOLETIM_IMPLANTACAO (andamento da implantação). Depois
                da implantação, o mesmo mecanismo serve a outros comunicados da
                empresa, trocando só os itens. Destinatários oficiais e de
                aprovação em grupos de e-mail (SIS.Grupo_Email). EXIGE_APROVACAO:
                a rotina só manda a prévia; o envio oficial depende de alguém
                clicar em "Aprovar e enviar". INTRODUCAO: parágrafo de abertura.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado]
    (
        ID_COMUNICADO             INT            IDENTITY(1,1) NOT NULL,
        CODIGO                    VARCHAR(30)    NOT NULL,
        TITULO                    NVARCHAR(150)  NOT NULL,
        INTRODUCAO                NVARCHAR(1000) NOT NULL CONSTRAINT DF_Comunicado_INTRODUCAO      DEFAULT (N''),
        ID_GRUPO_EMAIL            INT            NOT NULL,
        ID_GRUPO_EMAIL_APROVACAO  INT            NOT NULL,
        EXIGE_APROVACAO           BIT            NOT NULL CONSTRAINT DF_Comunicado_EXIGE_APROVACAO DEFAULT (1),
        ATIVO                     BIT            NOT NULL CONSTRAINT DF_Comunicado_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado           PRIMARY KEY CLUSTERED (ID_COMUNICADO),
        CONSTRAINT UQ_Comunicado_CODIGO    UNIQUE (CODIGO),
        CONSTRAINT FK_Comunicado_Grupo     FOREIGN KEY (ID_GRUPO_EMAIL)           REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL),
        CONSTRAINT FK_Comunicado_Aprovacao FOREIGN KEY (ID_GRUPO_EMAIL_APROVACAO) REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL),
        CONSTRAINT CK_Comunicado_CODIGO    CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO
