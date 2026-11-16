/*******************************************************************************
  Objeto      : [CAD].[Pessoa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Cadastro único de pessoas: clientes, fornecedores, funcionários,
                corretores e clientes de obra por administração (uma pessoa pode ter
                vários papéis). CPF/CNPJ PODE REPETIR (decisão do Celso, 16/11/2026): a
                identificação única é o ID_PESSOA (código mostrado na tela); a tela só
                avisa quando já existe outra pessoa com o mesmo documento.
                Contatos, vínculos e dados bancários em tabelas próprias.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa]
    (
        ID_PESSOA            INT            IDENTITY(1,1) NOT NULL,
        TIPO_PESSOA          CHAR(1)        NOT NULL,
        NOME                 NVARCHAR(150)  NOT NULL,
        NOME_FANTASIA        NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_NOME_FANTASIA       DEFAULT (N''),
        CPF_CNPJ             VARCHAR(14)    NOT NULL CONSTRAINT DF_Pessoa_CPF_CNPJ            DEFAULT (''),
        RG                   VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_RG                  DEFAULT (''),
        ORGAO_EMISSOR        VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_ORGAO_EMISSOR       DEFAULT (''),
        INSCRICAO_ESTADUAL   VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_INSCRICAO_ESTADUAL  DEFAULT (''),
        INSCRICAO_MUNICIPAL  VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_INSCRICAO_MUNICIPAL DEFAULT (''),
        DT_NASCIMENTO        DATE           NULL,
        NACIONALIDADE        NVARCHAR(40)   NOT NULL CONSTRAINT DF_Pessoa_NACIONALIDADE       DEFAULT (N''),
        PROFISSAO            NVARCHAR(60)   NOT NULL CONSTRAINT DF_Pessoa_PROFISSAO           DEFAULT (N''),
        ESTADO_CIVIL         VARCHAR(15)    NOT NULL CONSTRAINT DF_Pessoa_ESTADO_CIVIL        DEFAULT (''),
        REGIME_BENS          VARCHAR(25)    NOT NULL CONSTRAINT DF_Pessoa_REGIME_BENS         DEFAULT (''),
        CEP                  VARCHAR(8)     NOT NULL CONSTRAINT DF_Pessoa_CEP                 DEFAULT (''),
        LOGRADOURO           NVARCHAR(150)  NOT NULL CONSTRAINT DF_Pessoa_LOGRADOURO          DEFAULT (N''),
        NUMERO               NVARCHAR(20)   NOT NULL CONSTRAINT DF_Pessoa_NUMERO              DEFAULT (N''),
        COMPLEMENTO          NVARCHAR(60)   NOT NULL CONSTRAINT DF_Pessoa_COMPLEMENTO         DEFAULT (N''),
        BAIRRO               NVARCHAR(60)   NOT NULL CONSTRAINT DF_Pessoa_BAIRRO              DEFAULT (N''),
        CIDADE               NVARCHAR(60)   NOT NULL CONSTRAINT DF_Pessoa_CIDADE              DEFAULT (N''),
        UF                   CHAR(2)        NOT NULL CONSTRAINT DF_Pessoa_UF                  DEFAULT (''),
        CLIENTE              BIT            NOT NULL CONSTRAINT DF_Pessoa_CLIENTE             DEFAULT (0),
        FORNECEDOR           BIT            NOT NULL CONSTRAINT DF_Pessoa_FORNECEDOR          DEFAULT (0),
        FUNCIONARIO          BIT            NOT NULL CONSTRAINT DF_Pessoa_FUNCIONARIO         DEFAULT (0),
        CORRETOR             BIT            NOT NULL CONSTRAINT DF_Pessoa_CORRETOR            DEFAULT (0),
        OBSERVACAO           NVARCHAR(2000) NOT NULL CONSTRAINT DF_Pessoa_OBSERVACAO          DEFAULT (N''),
        ATIVO                BIT            NOT NULL CONSTRAINT DF_Pessoa_ATIVO               DEFAULT (1),
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa              PRIMARY KEY CLUSTERED (ID_PESSOA),
        CONSTRAINT CK_Pessoa_TIPO_PESSOA  CHECK (TIPO_PESSOA IN ('F', 'J')),
        CONSTRAINT CK_Pessoa_CPF_CNPJ     CHECK (CPF_CNPJ NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Pessoa_ESTADO_CIVIL CHECK (ESTADO_CIVIL IN ('', 'SOLTEIRO', 'CASADO', 'DIVORCIADO', 'VIUVO', 'SEPARADO', 'UNIAO_ESTAVEL')),
        CONSTRAINT CK_Pessoa_REGIME_BENS  CHECK (REGIME_BENS IN ('', 'COMUNHAO_PARCIAL', 'COMUNHAO_UNIVERSAL', 'SEPARACAO_TOTAL', 'PARTICIPACAO_AQUESTOS')),
        CONSTRAINT CK_Pessoa_CEP          CHECK (CEP = '' OR (LEN(CEP) = 8 AND CEP NOT LIKE '%[^0-9]%')),
        CONSTRAINT CK_Pessoa_UF           CHECK (UF = '' OR UF NOT LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_NOME' AND object_id = OBJECT_ID(N'[CAD].[Pessoa]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_NOME ON [CAD].[Pessoa] (NOME) INCLUDE (ATIVO, CPF_CNPJ);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_CPF_CNPJ' AND object_id = OBJECT_ID(N'[CAD].[Pessoa]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_CPF_CNPJ ON [CAD].[Pessoa] (CPF_CNPJ) WHERE CPF_CNPJ <> '';
GO
