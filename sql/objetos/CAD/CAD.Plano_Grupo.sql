/*******************************************************************************
  Objeto      : [CAD].[Plano_Grupo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas, nível 1 (grupo). TIPO: RECEITA, DESPESA ou
                NAO_OPERACIONAL (empréstimos, amortizações, aportes, distribuição de
                lucros). CUSTO_OBRA: entra no custo da obra e no painel; o orçamento da
                obra é feito por grupo/subgrupo (decisão do Celso, 16/11/2026).
                Plano antigo do Access migra como grupos inativos (só consulta).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Plano_Grupo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Plano_Grupo]
    (
        ID_PLANO_GRUPO     INT            IDENTITY(1,1) NOT NULL,
        NUMERO             SMALLINT       NOT NULL,
        DESCRICAO          NVARCHAR(80)   NOT NULL,
        TIPO               VARCHAR(15)    NOT NULL,
        CUSTO_OBRA         BIT            NOT NULL CONSTRAINT DF_Plano_Grupo_CUSTO_OBRA DEFAULT (0),
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Plano_Grupo_ORDEM      DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Plano_Grupo_ATIVO      DEFAULT (1),
        CODIGO_ACCESS      INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Plano_Grupo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Plano_Grupo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Plano_Grupo           PRIMARY KEY CLUSTERED (ID_PLANO_GRUPO),
        CONSTRAINT UQ_Plano_Grupo_NUMERO    UNIQUE (NUMERO),
        CONSTRAINT UQ_Plano_Grupo_DESCRICAO UNIQUE (DESCRICAO),
        CONSTRAINT CK_Plano_Grupo_NUMERO    CHECK (NUMERO BETWEEN 0 AND 99),
        CONSTRAINT CK_Plano_Grupo_TIPO      CHECK (TIPO IN ('RECEITA', 'DESPESA', 'NAO_OPERACIONAL')),
        CONSTRAINT CK_Plano_Grupo_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO
