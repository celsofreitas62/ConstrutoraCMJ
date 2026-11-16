/*******************************************************************************
  Objeto      : [CAD].[Plano_Subgrupo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas, nível 2 (subgrupo), sempre dentro de um grupo (FK).
                Número e descrição não se repetem dentro do mesmo grupo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Plano_Subgrupo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Plano_Subgrupo]
    (
        ID_PLANO_SUBGRUPO  INT            IDENTITY(1,1) NOT NULL,
        ID_PLANO_GRUPO     INT            NOT NULL,
        NUMERO             SMALLINT       NOT NULL,
        DESCRICAO          NVARCHAR(80)   NOT NULL,
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Plano_Subgrupo_ORDEM DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Plano_Subgrupo_ATIVO DEFAULT (1),
        CODIGO_ACCESS      INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Plano_Subgrupo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Plano_Subgrupo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Plano_Subgrupo           PRIMARY KEY CLUSTERED (ID_PLANO_SUBGRUPO),
        CONSTRAINT UQ_Plano_Subgrupo_NUMERO    UNIQUE (ID_PLANO_GRUPO, NUMERO),
        CONSTRAINT UQ_Plano_Subgrupo_DESCRICAO UNIQUE (ID_PLANO_GRUPO, DESCRICAO),
        CONSTRAINT FK_Plano_Subgrupo_Grupo     FOREIGN KEY (ID_PLANO_GRUPO) REFERENCES [CAD].[Plano_Grupo] (ID_PLANO_GRUPO),
        CONSTRAINT CK_Plano_Subgrupo_NUMERO    CHECK (NUMERO BETWEEN 1 AND 99),
        CONSTRAINT CK_Plano_Subgrupo_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO
