/*******************************************************************************
  Objeto      : [CAD].[Plano_Conta]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas, nível 3: a única que recebe lançamento. O lançamento
                grava só ID_PLANO_CONTA; subgrupo e grupo vêm pela árvore (FK), então
                nunca ficam desalinhados (pedido 11). CONTABIL: o fechamento de mês
                bloqueia (pedido 10); CONTA_CONTABIL_REF: código na contabilidade
                (preenchidos depois, pela tela). Código mostrado: CAD.vw_CAD_Plano_Conta.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Plano_Conta]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Plano_Conta]
    (
        ID_PLANO_CONTA      INT            IDENTITY(1,1) NOT NULL,
        ID_PLANO_SUBGRUPO   INT            NOT NULL,
        NUMERO              SMALLINT       NOT NULL,
        DESCRICAO           NVARCHAR(80)   NOT NULL,
        CONTABIL            BIT            NOT NULL CONSTRAINT DF_Plano_Conta_CONTABIL           DEFAULT (0),
        CONTA_CONTABIL_REF  VARCHAR(30)    NOT NULL CONSTRAINT DF_Plano_Conta_CONTA_CONTABIL_REF DEFAULT (''),
        ATIVO               BIT            NOT NULL CONSTRAINT DF_Plano_Conta_ATIVO              DEFAULT (1),
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Plano_Conta_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Plano_Conta_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Plano_Conta           PRIMARY KEY CLUSTERED (ID_PLANO_CONTA),
        CONSTRAINT UQ_Plano_Conta_NUMERO    UNIQUE (ID_PLANO_SUBGRUPO, NUMERO),
        CONSTRAINT UQ_Plano_Conta_DESCRICAO UNIQUE (ID_PLANO_SUBGRUPO, DESCRICAO),
        CONSTRAINT FK_Plano_Conta_Subgrupo  FOREIGN KEY (ID_PLANO_SUBGRUPO) REFERENCES [CAD].[Plano_Subgrupo] (ID_PLANO_SUBGRUPO),
        CONSTRAINT CK_Plano_Conta_NUMERO    CHECK (NUMERO BETWEEN 1 AND 999),
        CONSTRAINT CK_Plano_Conta_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO

IF COL_LENGTH(N'CAD.Plano_Conta', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Plano_Conta] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Plano_Conta', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Plano_Conta] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO
