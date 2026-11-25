/*******************************************************************************
  Objeto      : [CAD].[Parceiro_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Tipos de parceiro (P12). Um parceiro pode ter vários tipos
                (CAD.Pessoa_Tipo). SISTEMA = 1: tipo de fábrica usado pelas
                regras (NA, CLIENTE, FORNECEDOR, FUNCIONARIO, CORRETOR); não
                pode ser excluído nem ter o código mudado. Os demais são
                criados pela CMJ (empreiteiro, imobiliária etc.).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Parceiro_Tipo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Parceiro_Tipo]
    (
        ID_PARCEIRO_TIPO   INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(20)    NOT NULL,
        DESCRICAO          NVARCHAR(60)   NOT NULL,
        SISTEMA            BIT            NOT NULL CONSTRAINT DF_Parceiro_Tipo_SISTEMA         DEFAULT (0),
        ORDEM              INT            NOT NULL CONSTRAINT DF_Parceiro_Tipo_ORDEM           DEFAULT (100),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Parceiro_Tipo_ATIVO           DEFAULT (1),
        DT_EXCLUSAO        DATETIME2(0)   NULL,
        USUARIO_EXCLUSAO   NVARCHAR(100)  NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Parceiro_Tipo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Parceiro_Tipo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Parceiro_Tipo        PRIMARY KEY CLUSTERED (ID_PARCEIRO_TIPO),
        CONSTRAINT UQ_Parceiro_Tipo_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Parceiro_Tipo_CODIGO CHECK (CODIGO <> ''),
        CONSTRAINT CK_Parceiro_Tipo_DESC   CHECK (DESCRICAO <> N'')
    );
END;
GO
