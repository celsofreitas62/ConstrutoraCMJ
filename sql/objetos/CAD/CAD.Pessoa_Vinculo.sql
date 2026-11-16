/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Vinculo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Vínculos entre pessoas: cônjuge/coobrigado, sócio, representante,
                procurador. A pessoa vinculada também é uma CAD.Pessoa.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Vinculo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Vinculo]
    (
        ID_PESSOA_VINCULO    INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA            INT            NOT NULL,
        ID_PESSOA_VINCULADA  INT            NOT NULL,
        TIPO                 VARCHAR(15)    NOT NULL,
        OBSERVACAO           NVARCHAR(200)  NOT NULL CONSTRAINT DF_Pessoa_Vinculo_OBSERVACAO DEFAULT (N''),
        ATIVO                BIT            NOT NULL CONSTRAINT DF_Pessoa_Vinculo_ATIVO      DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Vinculo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Vinculo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Vinculo           PRIMARY KEY CLUSTERED (ID_PESSOA_VINCULO),
        CONSTRAINT UQ_Pessoa_Vinculo           UNIQUE (ID_PESSOA, ID_PESSOA_VINCULADA, TIPO),
        CONSTRAINT FK_Pessoa_Vinculo_Pessoa    FOREIGN KEY (ID_PESSOA)           REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Pessoa_Vinculo_Vinculada FOREIGN KEY (ID_PESSOA_VINCULADA) REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT CK_Pessoa_Vinculo_TIPO      CHECK (TIPO IN ('CONJUGE', 'SOCIO', 'REPRESENTANTE', 'PROCURADOR')),
        CONSTRAINT CK_Pessoa_Vinculo_PROPRIA   CHECK (ID_PESSOA <> ID_PESSOA_VINCULADA)
    );
END;
GO
