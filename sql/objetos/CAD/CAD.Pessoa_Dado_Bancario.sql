/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Dado_Bancario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Dados bancários da pessoa para pagamento por TED ou PIX (várias contas,
                uma principal). TED exige banco, agência e conta; PIX exige tipo e
                chave. Titular só quando for outra pessoa.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Dado_Bancario]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Dado_Bancario]
    (
        ID_PESSOA_DADO_BANCARIO  INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA                INT            NOT NULL,
        TIPO                     VARCHAR(3)     NOT NULL,
        ID_BANCO                 INT            NULL,
        AGENCIA                  VARCHAR(10)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_AGENCIA           DEFAULT (''),
        AGENCIA_DV               VARCHAR(2)     NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_AGENCIA_DV        DEFAULT (''),
        CONTA                    VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_CONTA             DEFAULT (''),
        CONTA_DV                 VARCHAR(2)     NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_CONTA_DV          DEFAULT (''),
        TIPO_CONTA               VARCHAR(10)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_TIPO_CONTA        DEFAULT (''),
        TITULAR_NOME             NVARCHAR(150)  NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_TITULAR_NOME      DEFAULT (N''),
        TITULAR_DOCUMENTO        VARCHAR(14)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_TITULAR_DOCUMENTO DEFAULT (''),
        PIX_TIPO                 VARCHAR(10)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_PIX_TIPO          DEFAULT (''),
        PIX_CHAVE                NVARCHAR(140)  NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_PIX_CHAVE         DEFAULT (N''),
        PRINCIPAL                BIT            NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_PRINCIPAL         DEFAULT (0),
        ATIVO                    BIT            NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_ATIVO             DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Dado_Bancario            PRIMARY KEY CLUSTERED (ID_PESSOA_DADO_BANCARIO),
        CONSTRAINT FK_Pessoa_Dado_Bancario_Pessoa     FOREIGN KEY (ID_PESSOA) REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Pessoa_Dado_Bancario_Banco      FOREIGN KEY (ID_BANCO)  REFERENCES [BANCO].[Banco] (ID_BANCO),
        CONSTRAINT CK_Pessoa_Dado_Bancario_TIPO       CHECK (TIPO IN ('TED', 'PIX')),
        CONSTRAINT CK_Pessoa_Dado_Bancario_TIPO_CONTA CHECK (TIPO_CONTA IN ('', 'CORRENTE', 'POUPANCA', 'PAGAMENTO')),
        CONSTRAINT CK_Pessoa_Dado_Bancario_PIX_TIPO   CHECK (PIX_TIPO IN ('', 'DOCUMENTO', 'EMAIL', 'CELULAR', 'ALEATORIA')),
        CONSTRAINT CK_Pessoa_Dado_Bancario_TED        CHECK (TIPO <> 'TED' OR (ID_BANCO IS NOT NULL AND AGENCIA <> '' AND CONTA <> '')),
        CONSTRAINT CK_Pessoa_Dado_Bancario_PIX        CHECK (TIPO <> 'PIX' OR (PIX_TIPO <> '' AND PIX_CHAVE <> N''))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_Dado_Bancario_Pessoa' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Dado_Bancario]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_Dado_Bancario_Pessoa ON [CAD].[Pessoa_Dado_Bancario] (ID_PESSOA);
GO
