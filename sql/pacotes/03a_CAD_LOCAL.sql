/*******************************************************************************
  Pacote      : 03a - cadastros (CAD: empresas, pessoas, centros de custo, plano de contas) e cadastro do BANCO (bancos e contas)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 16/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 02d já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/CAD/03a_Homologacao_CAD.sql e depois
                02d, 02c e 02b, para conferir que nada quebrou.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Banco errado: este pacote só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.Banco.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Lista de bancos (código COMPE de 3 dígitos e ISPB de 8 dígitos,
                usado no PIX). Usada nas contas da empresa (BANCO.Conta) e nos dados
                bancários das pessoas (CAD.Pessoa_Dado_Bancario). Carga inicial com os
                principais bancos; o administrador acrescenta outros.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Banco]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Banco]
    (
        ID_BANCO           INT            IDENTITY(1,1) NOT NULL,
        CODIGO             CHAR(3)        NOT NULL,
        ISPB               VARCHAR(8)     NOT NULL CONSTRAINT DF_Banco_ISPB  DEFAULT (''),
        NOME               NVARCHAR(80)   NOT NULL,
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Banco_ATIVO DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Banco_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Banco_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Banco        PRIMARY KEY CLUSTERED (ID_BANCO),
        CONSTRAINT UQ_Banco_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Banco_CODIGO CHECK (CODIGO NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_Banco_ISPB   CHECK (ISPB = '' OR (LEN(ISPB) = 8 AND ISPB NOT LIKE '%[^0-9]%'))
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Empresa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Empresa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Empresas do grupo (Construtora, SPEs, Holding), cadastro livre do
                administrador (decisão do Celso, 16/11/2026). O CNPJ da licença só
                registra o software; documentos de uma empresa/obra usam a razão social
                e o CNPJ daqui. CNPJ: só dígitos/letras (aceita o alfanumérico), único
                quando preenchido (a migração pode trazer empresa sem CNPJ).
                ID_CONTA_BANCARIA_PADRAO: FK para BANCO.Conta criada em
                CAD.FK_Conta_Padrao.sql (a conta é criada depois desta tabela).
                Logomarca: anexo do tipo LOGOMARCA (SIS.Anexo).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Empresa]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Empresa]
    (
        ID_EMPRESA                 INT            IDENTITY(1,1) NOT NULL,
        RAZAO_SOCIAL               NVARCHAR(150)  NOT NULL,
        NOME_FANTASIA              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Empresa_NOME_FANTASIA       DEFAULT (N''),
        CNPJ                       VARCHAR(14)    NOT NULL CONSTRAINT DF_Empresa_CNPJ                DEFAULT (''),
        TIPO                       VARCHAR(12)    NOT NULL CONSTRAINT DF_Empresa_TIPO                DEFAULT ('OUTRA'),
        INSCRICAO_ESTADUAL         VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_INSCRICAO_ESTADUAL  DEFAULT (''),
        INSCRICAO_MUNICIPAL        VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_INSCRICAO_MUNICIPAL DEFAULT (''),
        REGIME_TRIBUTARIO          VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_REGIME_TRIBUTARIO   DEFAULT (''),
        CEP                        VARCHAR(8)     NOT NULL CONSTRAINT DF_Empresa_CEP                 DEFAULT (''),
        LOGRADOURO                 NVARCHAR(150)  NOT NULL CONSTRAINT DF_Empresa_LOGRADOURO          DEFAULT (N''),
        NUMERO                     NVARCHAR(20)   NOT NULL CONSTRAINT DF_Empresa_NUMERO              DEFAULT (N''),
        COMPLEMENTO                NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_COMPLEMENTO         DEFAULT (N''),
        BAIRRO                     NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_BAIRRO              DEFAULT (N''),
        CIDADE                     NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_CIDADE              DEFAULT (N''),
        UF                         CHAR(2)        NOT NULL CONSTRAINT DF_Empresa_UF                  DEFAULT (''),
        EMAIL                      NVARCHAR(256)  NOT NULL CONSTRAINT DF_Empresa_EMAIL               DEFAULT (N''),
        TELEFONE                   VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_TELEFONE            DEFAULT (''),
        ID_CONTA_BANCARIA_PADRAO   INT            NULL,
        ATIVO                      BIT            NOT NULL CONSTRAINT DF_Empresa_ATIVO               DEFAULT (1),
        CODIGO_ACCESS              INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Empresa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Empresa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Empresa                   PRIMARY KEY CLUSTERED (ID_EMPRESA),
        CONSTRAINT CK_Empresa_TIPO              CHECK (TIPO IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')),
        CONSTRAINT CK_Empresa_REGIME_TRIBUTARIO CHECK (REGIME_TRIBUTARIO IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')),
        CONSTRAINT CK_Empresa_CNPJ              CHECK (CNPJ = '' OR (LEN(CNPJ) = 14 AND CNPJ NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2)),
        CONSTRAINT CK_Empresa_CEP               CHECK (CEP = '' OR (LEN(CEP) = 8 AND CEP NOT LIKE '%[^0-9]%')),
        CONSTRAINT CK_Empresa_UF                CHECK (UF = '' OR UF NOT LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_Empresa_CNPJ' AND object_id = OBJECT_ID(N'[CAD].[Empresa]'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Empresa_CNPJ ON [CAD].[Empresa] (CNPJ) WHERE CNPJ <> '';
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.Conta.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[Conta]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contas da empresa: corrente, poupança, aplicação, CAIXA (dinheiro) e
                PERMUTA (quitação sem dinheiro). Conta de banco exige o banco; caixa e
                permuta não. SALDO_INICIAL + DT_SALDO_INICIAL: saldo de abertura.
                CONCILIA: entra na conciliação; MOSTRA_SALDO: aparece no resumo de
                saldos e no fluxo de caixa. Dados de cobrança do Sicredi ficam no COBR.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Conta]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Conta]
    (
        ID_CONTA            INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA          INT            NOT NULL,
        DESCRICAO           NVARCHAR(60)   NOT NULL,
        TIPO                VARCHAR(10)    NOT NULL,
        ID_BANCO            INT            NULL,
        AGENCIA             VARCHAR(10)    NOT NULL CONSTRAINT DF_Conta_AGENCIA            DEFAULT (''),
        AGENCIA_DV          VARCHAR(2)     NOT NULL CONSTRAINT DF_Conta_AGENCIA_DV         DEFAULT (''),
        NUMERO              VARCHAR(20)    NOT NULL CONSTRAINT DF_Conta_NUMERO             DEFAULT (''),
        NUMERO_DV           VARCHAR(2)     NOT NULL CONSTRAINT DF_Conta_NUMERO_DV          DEFAULT (''),
        LIMITE_CREDITO      DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Conta_LIMITE_CREDITO     DEFAULT (0),
        SALDO_INICIAL       DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Conta_SALDO_INICIAL      DEFAULT (0),
        DT_SALDO_INICIAL    DATE           NULL,
        CONCILIA            BIT            NOT NULL CONSTRAINT DF_Conta_CONCILIA           DEFAULT (0),
        MOSTRA_SALDO        BIT            NOT NULL CONSTRAINT DF_Conta_MOSTRA_SALDO       DEFAULT (1),
        CONTA_CONTABIL_REF  VARCHAR(30)    NOT NULL CONSTRAINT DF_Conta_CONTA_CONTABIL_REF DEFAULT (''),
        ORDEM               SMALLINT       NOT NULL CONSTRAINT DF_Conta_ORDEM              DEFAULT (0),
        ATIVO               BIT            NOT NULL CONSTRAINT DF_Conta_ATIVO              DEFAULT (1),
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Conta_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Conta_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Conta               PRIMARY KEY CLUSTERED (ID_CONTA),
        CONSTRAINT UQ_Conta_DESCRICAO     UNIQUE (ID_EMPRESA, DESCRICAO),
        CONSTRAINT FK_Conta_Empresa       FOREIGN KEY (ID_EMPRESA) REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Conta_Banco         FOREIGN KEY (ID_BANCO)   REFERENCES [BANCO].[Banco] (ID_BANCO),
        CONSTRAINT CK_Conta_TIPO          CHECK (TIPO IN ('CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA')),
        CONSTRAINT CK_Conta_BANCO         CHECK (TIPO IN ('CAIXA', 'PERMUTA') OR ID_BANCO IS NOT NULL),
        CONSTRAINT CK_Conta_SALDO_INICIAL CHECK (SALDO_INICIAL = 0 OR DT_SALDO_INICIAL IS NOT NULL)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.FK_Conta_Padrao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : FK de CAD.Empresa para BANCO.Conta
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a conta bancária padrão da empresa (BANCO.Conta é criada
                depois de CAD.Empresa, por isso a FK fica neste arquivo).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[FK_Empresa_Conta_Padrao]', N'F') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CONSTRAINT FK_Empresa_Conta_Padrao
        FOREIGN KEY (ID_CONTA_BANCARIA_PADRAO) REFERENCES [BANCO].[Conta] (ID_CONTA);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Centro_Custo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Centro_Custo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Onde o dinheiro é aplicado ou gerado: OBRA, ADMINISTRATIVO (escritório),
                IMOVEL_PROPRIO (salas, aptos de aluguel) e PARTICULAR. Todo lançamento
                leva conta do plano + centro de custo; a empresa do lançamento vem daqui.
                CONTABIL = 0: obra/centro que não vai para a contabilidade (o fechamento
                de mês só bloqueia conta contábil em centro contábil).
                ID_CONTA_BANCARIA_PADRAO: se vazio, vale a da empresa.
                Dados próprios da obra ficam em OBRA.Obra (proposta seguinte).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Centro_Custo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Centro_Custo]
    (
        ID_CENTRO_CUSTO            INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA                 INT            NOT NULL,
        CODIGO                     VARCHAR(20)    NOT NULL,
        DESCRICAO                  NVARCHAR(100)  NOT NULL,
        TIPO                       VARCHAR(15)    NOT NULL,
        CONTABIL                   BIT            NOT NULL CONSTRAINT DF_Centro_Custo_CONTABIL DEFAULT (1),
        ID_CONTA_BANCARIA_PADRAO   INT            NULL,
        ATIVO                      BIT            NOT NULL CONSTRAINT DF_Centro_Custo_ATIVO    DEFAULT (1),
        CODIGO_ACCESS              INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Centro_Custo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Centro_Custo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Centro_Custo              PRIMARY KEY CLUSTERED (ID_CENTRO_CUSTO),
        CONSTRAINT UQ_Centro_Custo_CODIGO       UNIQUE (CODIGO),
        CONSTRAINT FK_Centro_Custo_Empresa      FOREIGN KEY (ID_EMPRESA)               REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Centro_Custo_Conta_Padrao FOREIGN KEY (ID_CONTA_BANCARIA_PADRAO) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT CK_Centro_Custo_TIPO         CHECK (TIPO IN ('OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR')),
        CONSTRAINT CK_Centro_Custo_CODIGO       CHECK (CODIGO <> '')
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Pessoa.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Pessoa_Contato.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Contato]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contatos de cada pessoa (vários e-mails e telefones). RECEBE_COBRANCA:
                recebe boleto, régua de cobrança e extrato. Telefones gravados só com
                dígitos. Contato removido na tela é desativado (não apagado).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Contato]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Contato]
    (
        ID_PESSOA_CONTATO  INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA          INT            NOT NULL,
        TIPO               VARCHAR(10)    NOT NULL,
        VALOR              NVARCHAR(256)  NOT NULL,
        NOME_CONTATO       NVARCHAR(80)   NOT NULL CONSTRAINT DF_Pessoa_Contato_NOME_CONTATO    DEFAULT (N''),
        PRINCIPAL          BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_PRINCIPAL       DEFAULT (0),
        RECEBE_COBRANCA    BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_RECEBE_COBRANCA DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Contato_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Contato_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Contato        PRIMARY KEY CLUSTERED (ID_PESSOA_CONTATO),
        CONSTRAINT FK_Pessoa_Contato_Pessoa FOREIGN KEY (ID_PESSOA) REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT CK_Pessoa_Contato_TIPO   CHECK (TIPO IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP')),
        CONSTRAINT CK_Pessoa_Contato_VALOR  CHECK (VALOR <> N'')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_Contato_Pessoa' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Contato]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_Contato_Pessoa ON [CAD].[Pessoa_Contato] (ID_PESSOA);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Pessoa_Vinculo.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Pessoa_Dado_Bancario.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Plano_Grupo.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Plano_Subgrupo.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Plano_Conta.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Somente_Digitos.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Somente_Digitos]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Devolve só os dígitos de um texto (telefone, CEP, agência). Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Somente_Digitos(N'(41) 99999-1234');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Somente_Digitos] (@Texto NVARCHAR(400))
RETURNS VARCHAR(400)
AS
BEGIN
    DECLARE @R VARCHAR(400) = '';
    DECLARE @I INT = 1;
    DECLARE @T NVARCHAR(400) = ISNULL(@Texto, N'');
    DECLARE @C NCHAR(1);

    WHILE @I <= LEN(@T)
    BEGIN
        SET @C = SUBSTRING(@T, @I, 1);
        IF @C LIKE N'[0-9]' SET @R = @R + CONVERT(VARCHAR(1), @C);
        SET @I = @I + 1;
    END;

    RETURN @R;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Documento_Limpo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Limpo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : CPF/CNPJ sem pontuação e em maiúsculas (aceita o CNPJ alfanumérico).
                Tira ponto, traço, barra e espaços. Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Documento_Limpo(N'12.abc.345/01de-35');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Limpo] (@Documento NVARCHAR(30))
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN CONVERT(VARCHAR(30), UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@Documento, N''))),
                   N'.', N''), N'-', N''), N'/', N''), N' ', N''), NCHAR(9), N'')));
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Documento_Valido.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Valido]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Confere os dígitos verificadores de CPF (11 dígitos) e de CNPJ (14
                posições, aceitando o CNPJ alfanumérico: as 12 primeiras posições
                podem ter letras, valor = código ASCII - 48; os 2 dígitos finais são
                numéricos). Recusa todos os caracteres iguais. Vazio ou outro tamanho
                devolve 0. Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Documento_Valido('529.982.247-25'), CAD.fn_CAD_Documento_Valido('12.ABC.345/01DE-35');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Valido] (@Documento NVARCHAR(30))
RETURNS BIT
AS
BEGIN
    DECLARE @D  VARCHAR(30) = CAD.fn_CAD_Documento_Limpo(@Documento);
    DECLARE @S1 INT;
    DECLARE @S2 INT;
    DECLARE @V1 INT;
    DECLARE @V2 INT;

    IF @D = '' OR REPLACE(@D, LEFT(@D, 1), '') = '' RETURN 0;

    IF LEN(@D) = 11
    BEGIN
        IF @D LIKE '%[^0-9]%' RETURN 0;
        SELECT @S1 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * (11 - v.N)) FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9)) v (N);
        SET @V1 = CASE WHEN @S1 % 11 < 2 THEN 0 ELSE 11 - @S1 % 11 END;
        SELECT @S2 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * (12 - v.N)) FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) v (N);
        SET @V2 = CASE WHEN @S2 % 11 < 2 THEN 0 ELSE 11 - @S2 % 11 END;
        RETURN CASE WHEN @V1 = ASCII(SUBSTRING(@D, 10, 1)) - 48 AND @V2 = ASCII(SUBSTRING(@D, 11, 1)) - 48 THEN 1 ELSE 0 END;
    END;

    IF LEN(@D) = 14
    BEGIN
        IF LEFT(@D, 12) LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2 OR RIGHT(@D, 2) LIKE '%[^0-9]%' RETURN 0;
        SELECT @S1 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * CASE WHEN v.N <= 4 THEN 6 - v.N ELSE 14 - v.N END)
        FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) v (N);
        SET @V1 = CASE WHEN @S1 % 11 < 2 THEN 0 ELSE 11 - @S1 % 11 END;
        SELECT @S2 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * CASE WHEN v.N <= 5 THEN 7 - v.N ELSE 15 - v.N END)
        FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13)) v (N);
        SET @V2 = CASE WHEN @S2 % 11 < 2 THEN 0 ELSE 11 - @S2 % 11 END;
        RETURN CASE WHEN @V1 = ASCII(SUBSTRING(@D, 13, 1)) - 48 AND @V2 = ASCII(SUBSTRING(@D, 14, 1)) - 48 THEN 1 ELSE 0 END;
    END;

    RETURN 0;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.vw_CAD_Plano_Conta.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[vw_CAD_Plano_Conta]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas achatado: uma linha por conta (nível 3) com o
                subgrupo e o grupo. CODIGO no formato 09.1.05 (grupo com 2 dígitos,
                subgrupo, conta com 2 ou 3 dígitos). ATIVO_EFETIVO: conta, subgrupo e
                grupo ativos (só essas aparecem para escolher no lançamento).
                ORDEM_ARVORE: texto para ordenar na sequência numérica.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT * FROM CAD.vw_CAD_Plano_Conta ORDER BY ORDEM_ARVORE;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW [CAD].[vw_CAD_Plano_Conta]
AS
SELECT c.ID_PLANO_CONTA,
       CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + CONVERT(VARCHAR(3), s.NUMERO) + '.'
             + CASE WHEN c.NUMERO < 10 THEN '0' ELSE '' END + CONVERT(VARCHAR(4), c.NUMERO)) AS CODIGO,
       c.DESCRICAO,
       c.NUMERO          AS NUMERO_CONTA,
       c.CONTABIL,
       c.CONTA_CONTABIL_REF,
       c.ATIVO           AS CONTA_ATIVA,
       s.ID_PLANO_SUBGRUPO,
       s.NUMERO          AS NUMERO_SUBGRUPO,
       s.DESCRICAO       AS SUBGRUPO_DESCRICAO,
       g.ID_PLANO_GRUPO,
       g.NUMERO          AS NUMERO_GRUPO,
       g.DESCRICAO       AS GRUPO_DESCRICAO,
       g.TIPO,
       g.CUSTO_OBRA,
       CAST(CASE WHEN c.ATIVO = 1 AND s.ATIVO = 1 AND g.ATIVO = 1 THEN 1 ELSE 0 END AS BIT) AS ATIVO_EFETIVO,
       CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + RIGHT('00' + CONVERT(VARCHAR(3), s.NUMERO), 2) + '.'
             + RIGHT('000' + CONVERT(VARCHAR(4), c.NUMERO), 3)) AS ORDEM_ARVORE
FROM CAD.Plano_Conta c
INNER JOIN CAD.Plano_Subgrupo s ON s.ID_PLANO_SUBGRUPO = c.ID_PLANO_SUBGRUPO
INNER JOIN CAD.Plano_Grupo    g ON g.ID_PLANO_GRUPO    = s.ID_PLANO_GRUPO;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Banco_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Banco_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Lista de bancos (tela Bancos e escolha do banco nas contas e nos
                dados bancários das pessoas). Permissão: VER em BANCO_BANCO,
                BANCO_CONTA ou CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Banco_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Banco_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Banco_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_BANCO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a lista de bancos.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT b.ID_BANCO, b.CODIGO, b.ISPB, b.NOME, b.ATIVO, b.DT_ALTERACAO, ISNULL(b.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM BANCO.Banco b WITH (NOLOCK)
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR b.ATIVO = 1)
        ORDER BY b.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a lista de bancos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Banco_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Banco_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdBanco NULL) ou altera um banco da lista. Código COMPE com
                3 dígitos (único); ISPB com 8 dígitos ou vazio.
                Permissão: INCLUIR ou ALTERAR em BANCO_BANCO. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Banco_Gravar @IdUsuario = 2, @Codigo = '748', @Ispb = '01181521', @Nome = N'Sicredi';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Banco_Gravar]
    @IdUsuario  INT,
    @IdBanco    INT          = NULL,
    @Codigo     VARCHAR(3),
    @Ispb       VARCHAR(8)   = NULL,
    @Nome       NVARCHAR(80),
    @Ativo      BIT          = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Banco_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Codigo = LTRIM(RTRIM(ISNULL(@Codigo, '')));
        SET @Ispb   = CAD.fn_CAD_Somente_Digitos(@Ispb);
        SET @Nome   = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Ativo  = ISNULL(@Ativo, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_BANCO', CASE WHEN @IdBanco IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar bancos.';
        IF @Recusa = N'' AND @IdBanco IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.ID_BANCO = @IdBanco)
            SET @Recusa = N'Banco não encontrado.';
        IF @Recusa = N'' AND (LEN(@Codigo) <> 3 OR @Codigo LIKE '%[^0-9]%')
            SET @Recusa = N'Código do banco inválido: informe os 3 dígitos (ex.: 748).';
        IF @Recusa = N'' AND @Ispb <> '' AND LEN(@Ispb) <> 8
            SET @Recusa = N'ISPB inválido: são 8 dígitos (ou deixe em branco).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome do banco.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.CODIGO = @Codigo AND b.ID_BANCO <> ISNULL(@IdBanco, 0))
            SET @Recusa = N'Já existe um banco com este código.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdBanco IS NULL
        BEGIN
            INSERT INTO BANCO.Banco (CODIGO, ISPB, NOME, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Ispb, @Nome, @Ativo, @Usuario);
            SET @IdBanco = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE b
               SET b.CODIGO = @Codigo, b.ISPB = @Ispb, b.NOME = @Nome, b.ATIVO = @Ativo,
                   b.DT_ALTERACAO = SYSDATETIME(), b.USUARIO_ALTERACAO = @Usuario
            FROM BANCO.Banco b
            WHERE b.ID_BANCO = @IdBanco;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Banco gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o banco. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contas da empresa (tela Contas bancárias e escolha da conta padrão da
                empresa e do centro de custo). @IdEmpresa NULL = todas.
                Permissão: VER em BANCO_CONTA, CAD_EMPRESA ou CAD_CENTRO_CUSTO.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Listar]
    @IdUsuario     INT,
    @IdEmpresa     INT = NULL,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as contas bancárias.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_CONTA, c.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               c.DESCRICAO, c.TIPO, c.ID_BANCO, ISNULL(b.CODIGO, '') AS BANCO_CODIGO, ISNULL(b.NOME, N'') AS BANCO_NOME,
               c.AGENCIA, c.AGENCIA_DV, c.NUMERO, c.NUMERO_DV, c.LIMITE_CREDITO, c.SALDO_INICIAL, c.DT_SALDO_INICIAL,
               c.CONCILIA, c.MOSTRA_SALDO, c.CONTA_CONTABIL_REF, c.ORDEM, c.ATIVO, c.CODIGO_ACCESS,
               c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM BANCO.Conta c WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
        LEFT  JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = c.ID_BANCO
        WHERE (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa)
          AND (ISNULL(@SomenteAtivos, 0) = 0 OR c.ATIVO = 1)
        ORDER BY e.RAZAO_SOCIAL, c.ORDEM, c.DESCRICAO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as contas bancárias. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdConta NULL) ou altera uma conta da empresa. Conta de banco
                (corrente, poupança, aplicação) exige banco, agência e número; caixa e
                permuta não usam banco. Descrição única dentro da empresa. Saldo
                inicial diferente de zero exige a data.
                Permissão: INCLUIR ou ALTERAR em BANCO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = 2, @IdEmpresa = 1, @Descricao = N'Caixa Construtora', @Tipo = 'CAIXA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Gravar]
    @IdUsuario         INT,
    @IdConta           INT           = NULL,
    @IdEmpresa         INT,
    @Descricao         NVARCHAR(60),
    @Tipo              VARCHAR(10),
    @IdBanco           INT           = NULL,
    @Agencia           VARCHAR(10)   = NULL,
    @AgenciaDv         VARCHAR(2)    = NULL,
    @Numero            VARCHAR(20)   = NULL,
    @NumeroDv          VARCHAR(2)    = NULL,
    @LimiteCredito     DECIMAL(18,2) = 0,
    @SaldoInicial      DECIMAL(18,2) = 0,
    @DtSaldoInicial    DATE          = NULL,
    @Concilia          BIT           = 0,
    @MostraSaldo       BIT           = 1,
    @ContaContabilRef  VARCHAR(30)   = NULL,
    @Ordem             SMALLINT      = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao        = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo             = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Agencia          = CAD.fn_CAD_Somente_Digitos(@Agencia);
        SET @AgenciaDv        = UPPER(LTRIM(RTRIM(ISNULL(@AgenciaDv, ''))));
        SET @Numero           = CAD.fn_CAD_Somente_Digitos(@Numero);
        SET @NumeroDv         = UPPER(LTRIM(RTRIM(ISNULL(@NumeroDv, ''))));
        SET @LimiteCredito    = ISNULL(@LimiteCredito, 0);
        SET @SaldoInicial     = ISNULL(@SaldoInicial, 0);
        SET @Concilia         = ISNULL(@Concilia, 0);
        SET @MostraSaldo      = ISNULL(@MostraSaldo, 1);
        SET @ContaContabilRef = LTRIM(RTRIM(ISNULL(@ContaContabilRef, '')));
        SET @Ordem            = ISNULL(@Ordem, 0);
        IF @Tipo IN ('CAIXA', 'PERMUTA')
            SELECT @IdBanco = NULL, @Agencia = '', @AgenciaDv = '', @Numero = '', @NumeroDv = '';

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', CASE WHEN @IdConta IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar contas bancárias.';
        IF @Recusa = N'' AND @IdConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta)
            SET @Recusa = N'Conta não encontrada.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa AND e.ATIVO = 1)
            SET @Recusa = N'Escolha uma empresa ativa como titular da conta.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição da conta (ex.: Sicredi Orion).';
        IF @Recusa = N'' AND @Tipo NOT IN ('CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA')
            SET @Recusa = N'Tipo de conta inválido.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CAIXA', 'PERMUTA')
           AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.ID_BANCO = @IdBanco AND b.ATIVO = 1)
            SET @Recusa = N'Escolha o banco da conta.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CAIXA', 'PERMUTA') AND (@Agencia = '' OR @Numero = '')
            SET @Recusa = N'Informe a agência e o número da conta.';
        IF @Recusa = N'' AND @SaldoInicial <> 0 AND @DtSaldoInicial IS NULL
            SET @Recusa = N'Informe a data do saldo inicial.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_EMPRESA = @IdEmpresa AND c.DESCRICAO = @Descricao AND c.ID_CONTA <> ISNULL(@IdConta, 0))
            SET @Recusa = N'Esta empresa já tem uma conta com esta descrição.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdConta IS NULL
        BEGIN
            INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, NUMERO, NUMERO_DV, LIMITE_CREDITO,
                                     SALDO_INICIAL, DT_SALDO_INICIAL, CONCILIA, MOSTRA_SALDO, CONTA_CONTABIL_REF, ORDEM, USUARIO_CRIACAO)
            VALUES (@IdEmpresa, @Descricao, @Tipo, @IdBanco, @Agencia, @AgenciaDv, @Numero, @NumeroDv, @LimiteCredito,
                    @SaldoInicial, @DtSaldoInicial, @Concilia, @MostraSaldo, @ContaContabilRef, @Ordem, @Usuario);
            SET @IdConta = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE c
               SET c.ID_EMPRESA = @IdEmpresa, c.DESCRICAO = @Descricao, c.TIPO = @Tipo, c.ID_BANCO = @IdBanco,
                   c.AGENCIA = @Agencia, c.AGENCIA_DV = @AgenciaDv, c.NUMERO = @Numero, c.NUMERO_DV = @NumeroDv,
                   c.LIMITE_CREDITO = @LimiteCredito, c.SALDO_INICIAL = @SaldoInicial, c.DT_SALDO_INICIAL = @DtSaldoInicial,
                   c.CONCILIA = @Concilia, c.MOSTRA_SALDO = @MostraSaldo, c.CONTA_CONTABIL_REF = @ContaContabilRef, c.ORDEM = @Ordem,
                   c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM BANCO.Conta c
            WHERE c.ID_CONTA = @IdConta;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Conta gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a conta. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma conta. Nada é apagado.
                Não desativa a conta que é padrão de empresa ou centro de custo ativo
                (troque a conta padrão antes). Permissão: EXCLUIR em BANCO_CONTA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Excluir @IdUsuario = 2, @IdConta = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Excluir]
    @IdUsuario  INT,
    @IdConta  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar contas bancárias.';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM BANCO.Conta t WHERE t.ID_CONTA = @IdConta;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa = N'' AND @Reativar = 0
           AND (   EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_CONTA_BANCARIA_PADRAO = @IdConta AND e.ATIVO = 1)
                OR EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.ID_CONTA_BANCARIA_PADRAO = @IdConta AND cc.ATIVO = 1))
            SET @Recusa = N'Esta conta é a conta padrão de uma empresa ou centro de custo ativo. Troque a conta padrão antes de desativar.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM BANCO.Conta t
        WHERE t.ID_CONTA = @IdConta
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Empresas" (e escolha da empresa nos outros cadastros): todas as
                colunas, CNPJ formatado e a conta padrão.
                Permissão: VER em CAD_EMPRESA, CAD_CENTRO_CUSTO ou BANCO_CONTA.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as empresas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT e.ID_EMPRESA, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ, 0) AS CNPJ_FORMATADO,
               e.TIPO, e.INSCRICAO_ESTADUAL, e.INSCRICAO_MUNICIPAL, e.REGIME_TRIBUTARIO,
               e.CEP, e.LOGRADOURO, e.NUMERO, e.COMPLEMENTO, e.BAIRRO, e.CIDADE, e.UF, e.EMAIL, e.TELEFONE,
               e.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               e.ATIVO, e.CODIGO_ACCESS, e.DT_ALTERACAO, ISNULL(e.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Empresa e WITH (NOLOCK)
        LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR e.ATIVO = 1)
        ORDER BY e.RAZAO_SOCIAL;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as empresas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdEmpresa NULL) ou altera uma empresa do grupo. Pela tela o
                CNPJ é obrigatório e conferido (dígitos verificadores, aceita o
                alfanumérico); não pode repetir. CEP com 8 dígitos, UF com 2 letras,
                e-mail válido. Conta padrão: qualquer conta ativa (escolha no cadastro,
                decisão do Celso).
                Permissão: INCLUIR ou ALTERAR em CAD_EMPRESA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Gravar @IdUsuario = 2, @RazaoSocial = N'Construtora Teste Ltda', @Cnpj = '11.222.333/0001-81', @Tipo = 'CONSTRUTORA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Gravar]
    @IdUsuario               INT,
    @IdEmpresa               INT           = NULL,
    @RazaoSocial             NVARCHAR(150),
    @NomeFantasia            NVARCHAR(100) = NULL,
    @Cnpj                    VARCHAR(20),
    @Tipo                    VARCHAR(12)   = 'OUTRA',
    @InscricaoEstadual       VARCHAR(20)   = NULL,
    @InscricaoMunicipal      VARCHAR(20)   = NULL,
    @RegimeTributario        VARCHAR(20)   = NULL,
    @Cep                     VARCHAR(10)   = NULL,
    @Logradouro              NVARCHAR(150) = NULL,
    @Numero                  NVARCHAR(20)  = NULL,
    @Complemento             NVARCHAR(60)  = NULL,
    @Bairro                  NVARCHAR(60)  = NULL,
    @Cidade                  NVARCHAR(60)  = NULL,
    @Uf                      CHAR(2)       = NULL,
    @Email                   NVARCHAR(256) = NULL,
    @Telefone                VARCHAR(30)   = NULL,
    @IdContaBancariaPadrao   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @RazaoSocial        = LTRIM(RTRIM(ISNULL(@RazaoSocial, N'')));
        SET @NomeFantasia       = LTRIM(RTRIM(ISNULL(@NomeFantasia, N'')));
        SET @Cnpj               = CAD.fn_CAD_Documento_Limpo(@Cnpj);
        SET @Tipo               = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, 'OUTRA'))));
        SET @InscricaoEstadual  = LTRIM(RTRIM(ISNULL(@InscricaoEstadual, '')));
        SET @InscricaoMunicipal = LTRIM(RTRIM(ISNULL(@InscricaoMunicipal, '')));
        SET @RegimeTributario   = UPPER(LTRIM(RTRIM(ISNULL(@RegimeTributario, ''))));
        SET @Cep                = CAD.fn_CAD_Somente_Digitos(@Cep);
        SET @Logradouro         = LTRIM(RTRIM(ISNULL(@Logradouro, N'')));
        SET @Numero             = LTRIM(RTRIM(ISNULL(@Numero, N'')));
        SET @Complemento        = LTRIM(RTRIM(ISNULL(@Complemento, N'')));
        SET @Bairro             = LTRIM(RTRIM(ISNULL(@Bairro, N'')));
        SET @Cidade             = LTRIM(RTRIM(ISNULL(@Cidade, N'')));
        SET @Uf                 = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));
        SET @Email              = LOWER(LTRIM(RTRIM(ISNULL(@Email, N''))));
        SET @Telefone           = CAD.fn_CAD_Somente_Digitos(@Telefone);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', CASE WHEN @IdEmpresa IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar empresas.';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa)
            SET @Recusa = N'Empresa não encontrada.';
        IF @Recusa = N'' AND @RazaoSocial = N''
            SET @Recusa = N'Informe a razão social.';
        IF @Recusa = N'' AND (LEN(@Cnpj) <> 14 OR CAD.fn_CAD_Documento_Valido(@Cnpj) = 0)
            SET @Recusa = N'CNPJ inválido. Confira os números (o CNPJ alfanumérico também é aceito).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.CNPJ = @Cnpj AND e.ID_EMPRESA <> ISNULL(@IdEmpresa, 0))
            SET @Recusa = N'Já existe uma empresa cadastrada com este CNPJ.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')
            SET @Recusa = N'Tipo de empresa inválido.';
        IF @Recusa = N'' AND @RegimeTributario NOT IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')
            SET @Recusa = N'Regime tributário inválido.';
        IF @Recusa = N'' AND @Cep <> '' AND LEN(@Cep) <> 8
            SET @Recusa = N'CEP inválido: são 8 dígitos.';
        IF @Recusa = N'' AND @Uf <> '' AND (LEN(@Uf) <> 2 OR @Uf LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'UF inválida: use a sigla com 2 letras (ex.: PR).';
        IF @Recusa = N'' AND @Email <> N'' AND SIS.fn_SIS_Email_Valido(@Email) = 0
            SET @Recusa = N'E-mail inválido.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'A conta padrão escolhida não existe ou está desativada.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdEmpresa IS NULL
        BEGIN
            INSERT INTO CAD.Empresa (RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, TIPO, INSCRICAO_ESTADUAL, INSCRICAO_MUNICIPAL, REGIME_TRIBUTARIO,
                                     CEP, LOGRADOURO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF, EMAIL, TELEFONE, ID_CONTA_BANCARIA_PADRAO, USUARIO_CRIACAO)
            VALUES (@RazaoSocial, @NomeFantasia, @Cnpj, @Tipo, @InscricaoEstadual, @InscricaoMunicipal, @RegimeTributario,
                    @Cep, @Logradouro, @Numero, @Complemento, @Bairro, @Cidade, @Uf, @Email, @Telefone, @IdContaBancariaPadrao, @Usuario);
            SET @IdEmpresa = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE e
               SET e.RAZAO_SOCIAL = @RazaoSocial, e.NOME_FANTASIA = @NomeFantasia, e.CNPJ = @Cnpj, e.TIPO = @Tipo,
                   e.INSCRICAO_ESTADUAL = @InscricaoEstadual, e.INSCRICAO_MUNICIPAL = @InscricaoMunicipal, e.REGIME_TRIBUTARIO = @RegimeTributario,
                   e.CEP = @Cep, e.LOGRADOURO = @Logradouro, e.NUMERO = @Numero, e.COMPLEMENTO = @Complemento, e.BAIRRO = @Bairro,
                   e.CIDADE = @Cidade, e.UF = @Uf, e.EMAIL = @Email, e.TELEFONE = @Telefone, e.ID_CONTA_BANCARIA_PADRAO = @IdContaBancariaPadrao,
                   e.DT_ALTERACAO = SYSDATETIME(), e.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Empresa e
            WHERE e.ID_EMPRESA = @IdEmpresa;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Empresa gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a empresa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma empresa. Nada é apagado.
                Não desativa empresa com conta ou centro de custo ativo (desative-os
                antes). Permissão: EXCLUIR em CAD_EMPRESA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Excluir @IdUsuario = 2, @IdEmpresa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Excluir]
    @IdUsuario  INT,
    @IdEmpresa  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar empresas.';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM CAD.Empresa t WHERE t.ID_EMPRESA = @IdEmpresa;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa = N'' AND @Reativar = 0
           AND (   EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_EMPRESA = @IdEmpresa AND c.ATIVO = 1)
                OR EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.ID_EMPRESA = @IdEmpresa AND cc.ATIVO = 1))
            SET @Recusa = N'A empresa ainda tem conta bancária ou centro de custo ativo. Desative-os antes.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Empresa t
        WHERE t.ID_EMPRESA = @IdEmpresa
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdEmpresa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Centros de custo" (e escolha do centro nos lançamentos).
                @IdEmpresa NULL = todas. CONTA_EFETIVA: a conta do centro ou, se vazia,
                a da empresa. Permissão: VER em CAD_CENTRO_CUSTO.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Listar]
    @IdUsuario     INT,
    @IdEmpresa     INT = NULL,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os centros de custo.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT cc.ID_CENTRO_CUSTO, cc.CODIGO, cc.DESCRICAO, cc.TIPO, cc.CONTABIL,
               cc.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               cc.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               ISNULL(cc.ID_CONTA_BANCARIA_PADRAO, e.ID_CONTA_BANCARIA_PADRAO) AS ID_CONTA_EFETIVA,
               ISNULL(c.DESCRICAO, ISNULL(ce.DESCRICAO, N'')) AS CONTA_EFETIVA_DESCRICAO,
               cc.ATIVO, cc.CODIGO_ACCESS, cc.DT_ALTERACAO, ISNULL(cc.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Centro_Custo cc WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
        LEFT  JOIN BANCO.Conta c  WITH (NOLOCK) ON c.ID_CONTA  = cc.ID_CONTA_BANCARIA_PADRAO
        LEFT  JOIN BANCO.Conta ce WITH (NOLOCK) ON ce.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE (@IdEmpresa IS NULL OR cc.ID_EMPRESA = @IdEmpresa)
          AND (ISNULL(@SomenteAtivos, 0) = 0 OR cc.ATIVO = 1)
        ORDER BY cc.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os centros de custo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdCentroCusto NULL) ou altera um centro de custo. Código
                curto, único, em maiúsculas (letras, números, "_" e "-"). Empresa e
                conta padrão têm de estar ativas (conta vazia = vale a da empresa).
                Permissão: INCLUIR ou ALTERAR em CAD_CENTRO_CUSTO. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = 2, @IdEmpresa = 1, @Codigo = 'ESC', @Descricao = N'Escritório', @Tipo = 'ADMINISTRATIVO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Gravar]
    @IdUsuario              INT,
    @IdCentroCusto          INT           = NULL,
    @IdEmpresa              INT,
    @Codigo                 VARCHAR(20),
    @Descricao              NVARCHAR(100),
    @Tipo                   VARCHAR(15),
    @Contabil               BIT           = 1,
    @IdContaBancariaPadrao  INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo      = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Contabil  = ISNULL(@Contabil, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', CASE WHEN @IdCentroCusto IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar centros de custo.';
        IF @Recusa = N'' AND @IdCentroCusto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto)
            SET @Recusa = N'Centro de custo não encontrado.';
        IF @Recusa = N'' AND (@Codigo = '' OR REPLACE(REPLACE(@Codigo, '_', ''), '-', '') LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras sem acento, números, "_" ou "-" (ex.: 62 ou ESC).';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição do centro de custo.';
        IF @Recusa = N'' AND @Tipo NOT IN ('OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR')
            SET @Recusa = N'Tipo inválido: obra, administrativo, imóvel próprio ou particular.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa AND e.ATIVO = 1)
            SET @Recusa = N'Escolha uma empresa ativa.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'A conta padrão escolhida não existe ou está desativada.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.CODIGO = @Codigo AND cc.ID_CENTRO_CUSTO <> ISNULL(@IdCentroCusto, 0))
            SET @Recusa = N'Já existe um centro de custo com este código.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdCentroCusto IS NULL
        BEGIN
            INSERT INTO CAD.Centro_Custo (ID_EMPRESA, CODIGO, DESCRICAO, TIPO, CONTABIL, ID_CONTA_BANCARIA_PADRAO, USUARIO_CRIACAO)
            VALUES (@IdEmpresa, @Codigo, @Descricao, @Tipo, @Contabil, @IdContaBancariaPadrao, @Usuario);
            SET @IdCentroCusto = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE cc
               SET cc.ID_EMPRESA = @IdEmpresa, cc.CODIGO = @Codigo, cc.DESCRICAO = @Descricao, cc.TIPO = @Tipo, cc.CONTABIL = @Contabil,
                   cc.ID_CONTA_BANCARIA_PADRAO = @IdContaBancariaPadrao, cc.DT_ALTERACAO = SYSDATETIME(), cc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Centro_Custo cc
            WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Centro de custo gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o centro de custo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) um centro de custo. Nada é
                apagado. Reativar exige a empresa ativa.
                Permissão: EXCLUIR em CAD_CENTRO_CUSTO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Excluir @IdUsuario = 2, @IdCentroCusto = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Excluir]
    @IdUsuario  INT,
    @IdCentroCusto  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar centros de custo.';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM CAD.Centro_Custo t WHERE t.ID_CENTRO_CUSTO = @IdCentroCusto;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa = N'' AND @Reativar = 1
           AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo cc INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = cc.ID_EMPRESA
                           WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto AND e.ATIVO = 1)
            SET @Recusa = N'A empresa deste centro de custo está desativada. Reative a empresa antes.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Centro_Custo t
        WHERE t.ID_CENTRO_CUSTO = @IdCentroCusto
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdCentroCusto AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Pessoas" e busca de pessoa nos outros cadastros. @Busca procura
                por parte do nome ou do nome fantasia, pelo início do CPF/CNPJ (com ou
                sem pontuação) e pelo código da pessoa. @Papel: CLIENTE, FORNECEDOR,
                FUNCIONARIO ou CORRETOR (vazio = todos). CPF sai MASCARADO na lista
                (LGPD); completo só no CAD_Pessoa_Obter.
                Permissão: VER em CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Listar @IdUsuario = 2, @Busca = N'silva';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Listar]
    @IdUsuario     INT,
    @Busca         NVARCHAR(100) = NULL,
    @Papel         VARCHAR(12)   = NULL,
    @SomenteAtivos BIT           = 1,
    @Limite        INT           = 500
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Like       NVARCHAR(110);
    DECLARE @Doc        VARCHAR(30);
    DECLARE @BuscaId    INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as pessoas.', 1;

        SET @Busca  = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Papel  = UPPER(LTRIM(RTRIM(ISNULL(@Papel, ''))));
        SET @Limite = CASE WHEN ISNULL(@Limite, 0) BETWEEN 1 AND 5000 THEN @Limite ELSE 500 END;
        IF @Papel NOT IN ('', 'CLIENTE', 'FORNECEDOR', 'FUNCIONARIO', 'CORRETOR')
            THROW 50001, N'Papel inválido para o filtro.', 1;

        SET @Like    = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Doc     = CAD.fn_CAD_Documento_Limpo(@Busca);
        SET @BuscaId = TRY_CONVERT(INT, @Busca);

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@Limite)
               p.ID_PESSOA, p.TIPO_PESSOA, p.NOME, p.NOME_FANTASIA,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(p.CPF_CNPJ, CASE WHEN p.TIPO_PESSOA = 'F' THEN 1 ELSE 0 END) AS DOCUMENTO,
               p.CLIENTE, p.FORNECEDOR, p.FUNCIONARIO, p.CORRETOR, p.CIDADE, p.UF,
               ISNULL((SELECT TOP 1 pc.VALOR FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1 AND pc.TIPO = 'EMAIL'
                       ORDER BY pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO), N'') AS EMAIL_PRINCIPAL,
               ISNULL((SELECT TOP 1 pc.VALOR FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1 AND pc.TIPO <> 'EMAIL'
                       ORDER BY pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO), N'') AS TELEFONE_PRINCIPAL,
               p.ATIVO, p.DT_ALTERACAO, ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Pessoa p WITH (NOLOCK)
        WHERE (ISNULL(@SomenteAtivos, 1) = 0 OR p.ATIVO = 1)
          AND (   @Papel = ''
               OR (@Papel = 'CLIENTE' AND p.CLIENTE = 1) OR (@Papel = 'FORNECEDOR' AND p.FORNECEDOR = 1)
               OR (@Papel = 'FUNCIONARIO' AND p.FUNCIONARIO = 1) OR (@Papel = 'CORRETOR' AND p.CORRETOR = 1))
          AND (   @Busca = N''
               OR p.NOME LIKE @Like
               OR p.NOME_FANTASIA LIKE @Like
               OR (LEN(@Doc) >= 3 AND p.CPF_CNPJ LIKE @Doc + '%')
               OR p.ID_PESSOA = @BuscaId)
        ORDER BY p.NOME, p.ID_PESSOA;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as pessoas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Ficha completa de uma pessoa (uma linha), com CPF/CNPJ completo e
                formatado, e os ativos de contatos, vínculos e dados bancários em
                colunas JSON (CONTATOS, VINCULOS, DADOS_BANCARIOS), no mesmo formato
                que o CAD_Pessoa_Gravar recebe. DOCUMENTO_REPETIDO: quantas outras
                pessoas têm o mesmo documento (só aviso).
                Permissão: VER em CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Obter @IdUsuario = 2, @IdPessoa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Obter]
    @IdUsuario  INT,
    @IdPessoa   INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as pessoas.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WITH (NOLOCK) WHERE p.ID_PESSOA = @IdPessoa)
            THROW 50001, N'Pessoa não encontrada.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT p.ID_PESSOA, p.TIPO_PESSOA, p.NOME, p.NOME_FANTASIA, p.CPF_CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(p.CPF_CNPJ, 0) AS DOCUMENTO_FORMATADO,
               p.RG, p.ORGAO_EMISSOR, p.INSCRICAO_ESTADUAL, p.INSCRICAO_MUNICIPAL, p.DT_NASCIMENTO,
               p.NACIONALIDADE, p.PROFISSAO, p.ESTADO_CIVIL, p.REGIME_BENS,
               p.CEP, p.LOGRADOURO, p.NUMERO, p.COMPLEMENTO, p.BAIRRO, p.CIDADE, p.UF,
               p.CLIENTE, p.FORNECEDOR, p.FUNCIONARIO, p.CORRETOR, p.OBSERVACAO, p.ATIVO, p.CODIGO_ACCESS,
               p.DT_CRIACAO, p.USUARIO_CRIACAO, p.DT_ALTERACAO, ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO,
               CASE WHEN p.CPF_CNPJ = '' THEN 0
                    ELSE (SELECT COUNT(*) FROM CAD.Pessoa o WITH (NOLOCK) WHERE o.CPF_CNPJ = p.CPF_CNPJ AND o.ID_PESSOA <> p.ID_PESSOA) END AS DOCUMENTO_REPETIDO,
               ISNULL((SELECT pc.ID_PESSOA_CONTATO AS id, pc.TIPO AS tipo, pc.VALOR AS valor, pc.NOME_CONTATO AS nome,
                              pc.PRINCIPAL AS principal, pc.RECEBE_COBRANCA AS recebeCobranca
                       FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1
                       ORDER BY pc.TIPO, pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO
                       FOR JSON PATH), N'[]') AS CONTATOS,
               ISNULL((SELECT pv.ID_PESSOA_VINCULADA AS idPessoaVinculada, v.NOME AS nome, pv.TIPO AS tipo, pv.OBSERVACAO AS observacao
                       FROM CAD.Pessoa_Vinculo pv WITH (NOLOCK)
                       INNER JOIN CAD.Pessoa v WITH (NOLOCK) ON v.ID_PESSOA = pv.ID_PESSOA_VINCULADA
                       WHERE pv.ID_PESSOA = p.ID_PESSOA AND pv.ATIVO = 1
                       ORDER BY pv.TIPO, v.NOME
                       FOR JSON PATH), N'[]') AS VINCULOS,
               ISNULL((SELECT d.ID_PESSOA_DADO_BANCARIO AS id, d.TIPO AS tipo, d.ID_BANCO AS idBanco, ISNULL(b.CODIGO, '') AS bancoCodigo,
                              ISNULL(b.NOME, N'') AS bancoNome, d.AGENCIA AS agencia, d.AGENCIA_DV AS agenciaDv, d.CONTA AS conta,
                              d.CONTA_DV AS contaDv, d.TIPO_CONTA AS tipoConta, d.TITULAR_NOME AS titularNome,
                              d.TITULAR_DOCUMENTO AS titularDocumento, d.PIX_TIPO AS pixTipo, d.PIX_CHAVE AS pixChave, d.PRINCIPAL AS principal
                       FROM CAD.Pessoa_Dado_Bancario d WITH (NOLOCK)
                       LEFT JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = d.ID_BANCO
                       WHERE d.ID_PESSOA = p.ID_PESSOA AND d.ATIVO = 1
                       ORDER BY d.PRINCIPAL DESC, d.ID_PESSOA_DADO_BANCARIO
                       FOR JSON PATH), N'[]') AS DADOS_BANCARIOS
        FROM CAD.Pessoa p WITH (NOLOCK)
        WHERE p.ID_PESSOA = @IdPessoa;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a pessoa. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPessoa NULL) ou altera uma pessoa, junto com os contatos,
                vínculos e dados bancários, tudo ou nada.
                Regras: nome e pelo menos um papel obrigatórios; CPF (F) ou CNPJ (J)
                conferido quando informado (aceita o CNPJ alfanumérico); documento PODE
                repetir: grava e avisa na MENSAGEM (decisão do Celso, 16/11/2026).
                Listas em JSON (mesmo formato do CAD_Pessoa_Obter); NULL = não mexe;
                informada = a lista gravada fica igual (o que saiu é DESATIVADO):
                  @Contatos       [{"id":null,"tipo":"EMAIL","valor":"a@b.com","nome":"","principal":true,"recebeCobranca":true}]
                                  tipos EMAIL, CELULAR, TELEFONE, WHATSAPP (telefone só dígitos, 10 a 13)
                  @Vinculos       [{"idPessoaVinculada":5,"tipo":"CONJUGE","observacao":""}]
                                  tipos CONJUGE, SOCIO, REPRESENTANTE, PROCURADOR
                  @DadosBancarios [{"id":null,"tipo":"TED","idBanco":3,"agencia":"0217","agenciaDv":"","conta":"123456",
                                    "contaDv":"7","tipoConta":"CORRENTE","titularNome":"","titularDocumento":"","principal":true},
                                   {"tipo":"PIX","pixTipo":"EMAIL","pixChave":"a@b.com"}]
                                  PIX: DOCUMENTO, EMAIL, CELULAR, ALEATORIA (chave conferida)
                Recusa com a linha do item errado (nada é gravado).
                Permissão: INCLUIR ou ALTERAR em CAD_PESSOA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = 2, @TipoPessoa = 'F', @Nome = N'Maria Teste', @CpfCnpj = '529.982.247-25', @Cliente = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Gravar]
    @IdUsuario           INT,
    @IdPessoa            INT            = NULL,
    @TipoPessoa          CHAR(1),
    @Nome                NVARCHAR(150),
    @NomeFantasia        NVARCHAR(100)  = NULL,
    @CpfCnpj             VARCHAR(30)    = NULL,
    @Rg                  VARCHAR(20)    = NULL,
    @OrgaoEmissor        VARCHAR(20)    = NULL,
    @InscricaoEstadual   VARCHAR(20)    = NULL,
    @InscricaoMunicipal  VARCHAR(20)    = NULL,
    @DtNascimento        DATE           = NULL,
    @Nacionalidade       NVARCHAR(40)   = NULL,
    @Profissao           NVARCHAR(60)   = NULL,
    @EstadoCivil         VARCHAR(15)    = NULL,
    @RegimeBens          VARCHAR(25)    = NULL,
    @Cep                 VARCHAR(10)    = NULL,
    @Logradouro          NVARCHAR(150)  = NULL,
    @Numero              NVARCHAR(20)   = NULL,
    @Complemento         NVARCHAR(60)   = NULL,
    @Bairro              NVARCHAR(60)   = NULL,
    @Cidade              NVARCHAR(60)   = NULL,
    @Uf                  CHAR(2)        = NULL,
    @Cliente             BIT            = 0,
    @Fornecedor          BIT            = 0,
    @Funcionario         BIT            = 0,
    @Corretor            BIT            = 0,
    @Observacao          NVARCHAR(2000) = NULL,
    @Contatos            NVARCHAR(MAX)  = NULL,
    @Vinculos            NVARCHAR(MAX)  = NULL,
    @DadosBancarios      NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Repetidos  INT           = 0;
    DECLARE @Mensagem   NVARCHAR(400);
    DECLARE @Cont  TABLE (LINHA INT, ID INT, TIPO VARCHAR(20), VALOR NVARCHAR(256), NOME NVARCHAR(80), PRINCIPAL BIT, RECEBE BIT);
    DECLARE @Vinc  TABLE (LINHA INT, ID_VINCULADA INT, TIPO VARCHAR(20), OBSERVACAO NVARCHAR(200));
    DECLARE @Banc  TABLE (LINHA INT, ID INT, TIPO VARCHAR(10), ID_BANCO INT, AGENCIA VARCHAR(20), AGENCIA_DV VARCHAR(5), CONTA VARCHAR(30),
                          CONTA_DV VARCHAR(5), TIPO_CONTA VARCHAR(20), TITULAR_NOME NVARCHAR(150), TITULAR_DOC VARCHAR(30),
                          PIX_TIPO VARCHAR(20), PIX_CHAVE NVARCHAR(140), PRINCIPAL BIT);

    BEGIN TRY
        SET @TipoPessoa         = UPPER(LTRIM(RTRIM(ISNULL(@TipoPessoa, ''))));
        SET @Nome               = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @NomeFantasia       = LTRIM(RTRIM(ISNULL(@NomeFantasia, N'')));
        SET @CpfCnpj            = CAD.fn_CAD_Documento_Limpo(@CpfCnpj);
        SET @Rg                 = LTRIM(RTRIM(ISNULL(@Rg, '')));
        SET @OrgaoEmissor       = UPPER(LTRIM(RTRIM(ISNULL(@OrgaoEmissor, ''))));
        SET @InscricaoEstadual  = LTRIM(RTRIM(ISNULL(@InscricaoEstadual, '')));
        SET @InscricaoMunicipal = LTRIM(RTRIM(ISNULL(@InscricaoMunicipal, '')));
        SET @Nacionalidade      = LTRIM(RTRIM(ISNULL(@Nacionalidade, N'')));
        SET @Profissao          = LTRIM(RTRIM(ISNULL(@Profissao, N'')));
        SET @EstadoCivil        = UPPER(LTRIM(RTRIM(ISNULL(@EstadoCivil, ''))));
        SET @RegimeBens         = UPPER(LTRIM(RTRIM(ISNULL(@RegimeBens, ''))));
        SET @Cep                = CAD.fn_CAD_Somente_Digitos(@Cep);
        SET @Logradouro         = LTRIM(RTRIM(ISNULL(@Logradouro, N'')));
        SET @Numero             = LTRIM(RTRIM(ISNULL(@Numero, N'')));
        SET @Complemento        = LTRIM(RTRIM(ISNULL(@Complemento, N'')));
        SET @Bairro             = LTRIM(RTRIM(ISNULL(@Bairro, N'')));
        SET @Cidade             = LTRIM(RTRIM(ISNULL(@Cidade, N'')));
        SET @Uf                 = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));
        SET @Cliente            = ISNULL(@Cliente, 0);
        SET @Fornecedor         = ISNULL(@Fornecedor, 0);
        SET @Funcionario        = ISNULL(@Funcionario, 0);
        SET @Corretor           = ISNULL(@Corretor, 0);
        SET @Observacao         = LTRIM(RTRIM(ISNULL(@Observacao, N'')));

        -- Pessoa
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', CASE WHEN @IdPessoa IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar pessoas.';
        IF @Recusa = N'' AND @IdPessoa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa)
            SET @Recusa = N'Pessoa não encontrada.';
        IF @Recusa = N'' AND @TipoPessoa NOT IN ('F', 'J')
            SET @Recusa = N'Escolha pessoa física (F) ou jurídica (J).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome.';
        IF @Recusa = N'' AND @CpfCnpj <> '' AND @TipoPessoa = 'F' AND (LEN(@CpfCnpj) <> 11 OR CAD.fn_CAD_Documento_Valido(@CpfCnpj) = 0)
            SET @Recusa = N'CPF inválido. Confira os números.';
        IF @Recusa = N'' AND @CpfCnpj <> '' AND @TipoPessoa = 'J' AND (LEN(@CpfCnpj) <> 14 OR CAD.fn_CAD_Documento_Valido(@CpfCnpj) = 0)
            SET @Recusa = N'CNPJ inválido. Confira os números (o CNPJ alfanumérico também é aceito).';
        IF @Recusa = N'' AND @Cliente = 0 AND @Fornecedor = 0 AND @Funcionario = 0 AND @Corretor = 0
            SET @Recusa = N'Marque pelo menos um papel: cliente, fornecedor, funcionário ou corretor.';
        IF @Recusa = N'' AND @EstadoCivil NOT IN ('', 'SOLTEIRO', 'CASADO', 'DIVORCIADO', 'VIUVO', 'SEPARADO', 'UNIAO_ESTAVEL')
            SET @Recusa = N'Estado civil inválido.';
        IF @Recusa = N'' AND @RegimeBens NOT IN ('', 'COMUNHAO_PARCIAL', 'COMUNHAO_UNIVERSAL', 'SEPARACAO_TOTAL', 'PARTICIPACAO_AQUESTOS')
            SET @Recusa = N'Regime de bens inválido.';
        IF @Recusa = N'' AND @Cep <> '' AND LEN(@Cep) <> 8
            SET @Recusa = N'CEP inválido: são 8 dígitos.';
        IF @Recusa = N'' AND @Uf <> '' AND (LEN(@Uf) <> 2 OR @Uf LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'UF inválida: use a sigla com 2 letras (ex.: PR).';
        IF @Recusa = N'' AND @DtNascimento IS NOT NULL AND (@DtNascimento < '1900-01-01' OR @DtNascimento > CONVERT(DATE, @Agora))
            SET @Recusa = N'Data de nascimento inválida.';
        IF @Recusa = N'' AND (   (@Contatos IS NOT NULL AND ISJSON(@Contatos) = 0)
                              OR (@Vinculos IS NOT NULL AND ISJSON(@Vinculos) = 0)
                              OR (@DadosBancarios IS NOT NULL AND ISJSON(@DadosBancarios) = 0))
            SET @Recusa = N'Lista de contatos, vínculos ou dados bancários em formato inválido.';

        -- Contatos
        IF @Recusa = N'' AND @Contatos IS NOT NULL
        BEGIN
            INSERT INTO @Cont (LINHA, ID, TIPO, VALOR, NOME, PRINCIPAL, RECEBE)
            SELECT CONVERT(INT, k.[key]) + 1, j.id, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), LTRIM(RTRIM(ISNULL(j.valor, N''))),
                   LTRIM(RTRIM(ISNULL(j.nome, N''))), ISNULL(j.principal, 0), ISNULL(j.recebeCobranca, 0)
            FROM OPENJSON(@Contatos) k
            CROSS APPLY OPENJSON(k.value) WITH (id INT '$.id', tipo VARCHAR(20) '$.tipo', valor NVARCHAR(256) '$.valor',
                                               nome NVARCHAR(80) '$.nome', principal BIT '$.principal', recebeCobranca BIT '$.recebeCobranca') j
            WHERE k.[type] = 5;

            UPDATE c SET c.VALOR = CASE WHEN c.TIPO = 'EMAIL' THEN LOWER(c.VALOR) ELSE CONVERT(NVARCHAR(256), CAD.fn_CAD_Somente_Digitos(c.VALOR)) END
            FROM @Cont c;

            SELECT TOP 1 @Recusa = N'Contato ' + CONVERT(NVARCHAR(5), c.LINHA) + N': ' +
                   CASE WHEN c.TIPO NOT IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP') THEN N'tipo inválido (e-mail, celular, telefone ou WhatsApp).'
                        WHEN c.TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(c.VALOR) = 0 THEN N'e-mail inválido.'
                        WHEN c.TIPO <> 'EMAIL' AND LEN(c.VALOR) NOT BETWEEN 10 AND 13 THEN N'telefone inválido (informe DDD + número).'
                        ELSE N'não pertence a esta pessoa.' END
            FROM @Cont c
            WHERE c.TIPO NOT IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP')
               OR (c.TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(c.VALOR) = 0)
               OR (c.TIPO <> 'EMAIL' AND LEN(c.VALOR) NOT BETWEEN 10 AND 13)
               OR (c.ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato pc WHERE pc.ID_PESSOA_CONTATO = c.ID AND pc.ID_PESSOA = ISNULL(@IdPessoa, 0)))
            ORDER BY c.LINHA;

            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM @Cont c WHERE c.PRINCIPAL = 1 GROUP BY c.TIPO HAVING COUNT(*) > 1)
                SET @Recusa = N'Marque só um contato principal de cada tipo.';
        END;

        -- Vínculos
        IF @Recusa = N'' AND @Vinculos IS NOT NULL
        BEGIN
            INSERT INTO @Vinc (LINHA, ID_VINCULADA, TIPO, OBSERVACAO)
            SELECT CONVERT(INT, k.[key]) + 1, j.idPessoaVinculada, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), LTRIM(RTRIM(ISNULL(j.observacao, N'')))
            FROM OPENJSON(@Vinculos) k
            CROSS APPLY OPENJSON(k.value) WITH (idPessoaVinculada INT '$.idPessoaVinculada', tipo VARCHAR(20) '$.tipo', observacao NVARCHAR(200) '$.observacao') j
            WHERE k.[type] = 5;

            SELECT TOP 1 @Recusa = N'Vínculo ' + CONVERT(NVARCHAR(5), v.LINHA) + N': ' +
                   CASE WHEN v.TIPO NOT IN ('CONJUGE', 'SOCIO', 'REPRESENTANTE', 'PROCURADOR') THEN N'tipo inválido (cônjuge, sócio, representante ou procurador).'
                        WHEN v.ID_VINCULADA = ISNULL(@IdPessoa, 0) THEN N'a pessoa não pode ser vinculada a ela mesma.'
                        ELSE N'pessoa vinculada não encontrada.' END
            FROM @Vinc v
            WHERE v.TIPO NOT IN ('CONJUGE', 'SOCIO', 'REPRESENTANTE', 'PROCURADOR')
               OR v.ID_VINCULADA = ISNULL(@IdPessoa, 0)
               OR NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = v.ID_VINCULADA)
            ORDER BY v.LINHA;

            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM @Vinc v GROUP BY v.ID_VINCULADA, v.TIPO HAVING COUNT(*) > 1)
                SET @Recusa = N'O mesmo vínculo foi informado duas vezes.';
        END;

        -- Dados bancários
        IF @Recusa = N'' AND @DadosBancarios IS NOT NULL
        BEGIN
            INSERT INTO @Banc (LINHA, ID, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, CONTA, CONTA_DV, TIPO_CONTA, TITULAR_NOME, TITULAR_DOC, PIX_TIPO, PIX_CHAVE, PRINCIPAL)
            SELECT CONVERT(INT, k.[key]) + 1, j.id, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), j.idBanco,
                   CAD.fn_CAD_Somente_Digitos(j.agencia), UPPER(LTRIM(RTRIM(ISNULL(j.agenciaDv, '')))),
                   CAD.fn_CAD_Somente_Digitos(j.conta), UPPER(LTRIM(RTRIM(ISNULL(j.contaDv, '')))),
                   UPPER(LTRIM(RTRIM(ISNULL(j.tipoConta, '')))), LTRIM(RTRIM(ISNULL(j.titularNome, N''))),
                   CAD.fn_CAD_Documento_Limpo(j.titularDocumento), UPPER(LTRIM(RTRIM(ISNULL(j.pixTipo, '')))),
                   LTRIM(RTRIM(ISNULL(j.pixChave, N''))), ISNULL(j.principal, 0)
            FROM OPENJSON(@DadosBancarios) k
            CROSS APPLY OPENJSON(k.value) WITH (id INT '$.id', tipo VARCHAR(10) '$.tipo', idBanco INT '$.idBanco', agencia NVARCHAR(20) '$.agencia',
                                               agenciaDv VARCHAR(5) '$.agenciaDv', conta NVARCHAR(30) '$.conta', contaDv VARCHAR(5) '$.contaDv',
                                               tipoConta VARCHAR(20) '$.tipoConta', titularNome NVARCHAR(150) '$.titularNome',
                                               titularDocumento NVARCHAR(30) '$.titularDocumento', pixTipo VARCHAR(20) '$.pixTipo',
                                               pixChave NVARCHAR(140) '$.pixChave', principal BIT '$.principal') j
            WHERE k.[type] = 5;

            -- Cada tipo guarda só os seus campos; chave PIX normalizada
            UPDATE b
               SET b.ID_BANCO   = CASE WHEN b.TIPO = 'TED' THEN b.ID_BANCO END,
                   b.AGENCIA    = CASE WHEN b.TIPO = 'TED' THEN b.AGENCIA ELSE '' END,
                   b.AGENCIA_DV = CASE WHEN b.TIPO = 'TED' THEN b.AGENCIA_DV ELSE '' END,
                   b.CONTA      = CASE WHEN b.TIPO = 'TED' THEN b.CONTA ELSE '' END,
                   b.CONTA_DV   = CASE WHEN b.TIPO = 'TED' THEN b.CONTA_DV ELSE '' END,
                   b.TIPO_CONTA = CASE WHEN b.TIPO = 'TED' THEN b.TIPO_CONTA ELSE '' END,
                   b.PIX_TIPO   = CASE WHEN b.TIPO = 'PIX' THEN b.PIX_TIPO ELSE '' END,
                   b.PIX_CHAVE  = CASE WHEN b.TIPO <> 'PIX' THEN N''
                                       WHEN b.PIX_TIPO = 'DOCUMENTO' THEN CONVERT(NVARCHAR(140), CAD.fn_CAD_Documento_Limpo(b.PIX_CHAVE))
                                       WHEN b.PIX_TIPO = 'CELULAR'   THEN CONVERT(NVARCHAR(140), CAD.fn_CAD_Somente_Digitos(b.PIX_CHAVE))
                                       ELSE LOWER(b.PIX_CHAVE) END
            FROM @Banc b;

            SELECT TOP 1 @Recusa = N'Dado bancário ' + CONVERT(NVARCHAR(5), b.LINHA) + N': ' +
                   CASE WHEN b.TIPO NOT IN ('TED', 'PIX') THEN N'escolha TED ou PIX.'
                        WHEN b.TIPO = 'TED' AND NOT EXISTS (SELECT 1 FROM BANCO.Banco x WHERE x.ID_BANCO = b.ID_BANCO AND x.ATIVO = 1) THEN N'escolha o banco.'
                        WHEN b.TIPO = 'TED' AND (b.AGENCIA = '' OR b.CONTA = '' OR LEN(b.AGENCIA) > 10 OR LEN(b.CONTA) > 20) THEN N'informe a agência e a conta.'
                        WHEN b.TIPO = 'TED' AND b.TIPO_CONTA NOT IN ('', 'CORRENTE', 'POUPANCA', 'PAGAMENTO') THEN N'tipo de conta inválido.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO NOT IN ('DOCUMENTO', 'EMAIL', 'CELULAR', 'ALEATORIA') THEN N'escolha o tipo da chave PIX.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'DOCUMENTO' AND CAD.fn_CAD_Documento_Valido(b.PIX_CHAVE) = 0 THEN N'chave PIX (CPF/CNPJ) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(b.PIX_CHAVE) = 0 THEN N'chave PIX (e-mail) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'CELULAR' AND LEN(b.PIX_CHAVE) NOT BETWEEN 10 AND 13 THEN N'chave PIX (celular) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'ALEATORIA' AND (LEN(REPLACE(b.PIX_CHAVE, N'-', N'')) <> 32 OR REPLACE(b.PIX_CHAVE, N'-', N'') LIKE N'%[^0-9a-f]%') THEN N'chave PIX aleatória inválida.'
                        WHEN b.TITULAR_DOC <> '' AND CAD.fn_CAD_Documento_Valido(b.TITULAR_DOC) = 0 THEN N'documento do titular inválido.'
                        ELSE N'não pertence a esta pessoa.' END
            FROM @Banc b
            WHERE b.TIPO NOT IN ('TED', 'PIX')
               OR (b.TIPO = 'TED' AND (   NOT EXISTS (SELECT 1 FROM BANCO.Banco x WHERE x.ID_BANCO = b.ID_BANCO AND x.ATIVO = 1)
                                       OR b.AGENCIA = '' OR b.CONTA = '' OR LEN(b.AGENCIA) > 10 OR LEN(b.CONTA) > 20
                                       OR b.TIPO_CONTA NOT IN ('', 'CORRENTE', 'POUPANCA', 'PAGAMENTO')))
               OR (b.TIPO = 'PIX' AND (   b.PIX_TIPO NOT IN ('DOCUMENTO', 'EMAIL', 'CELULAR', 'ALEATORIA')
                                       OR (b.PIX_TIPO = 'DOCUMENTO' AND CAD.fn_CAD_Documento_Valido(b.PIX_CHAVE) = 0)
                                       OR (b.PIX_TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(b.PIX_CHAVE) = 0)
                                       OR (b.PIX_TIPO = 'CELULAR' AND LEN(b.PIX_CHAVE) NOT BETWEEN 10 AND 13)
                                       OR (b.PIX_TIPO = 'ALEATORIA' AND (LEN(REPLACE(b.PIX_CHAVE, N'-', N'')) <> 32 OR REPLACE(b.PIX_CHAVE, N'-', N'') LIKE N'%[^0-9a-f]%'))))
               OR (b.TITULAR_DOC <> '' AND CAD.fn_CAD_Documento_Valido(b.TITULAR_DOC) = 0)
               OR (b.ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Dado_Bancario d WHERE d.ID_PESSOA_DADO_BANCARIO = b.ID AND d.ID_PESSOA = ISNULL(@IdPessoa, 0)))
            ORDER BY b.LINHA;

            IF @Recusa = N'' AND (SELECT COUNT(*) FROM @Banc b WHERE b.PRINCIPAL = 1) > 1
                SET @Recusa = N'Marque só um dado bancário como principal.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        IF @CpfCnpj <> ''
            SELECT @Repetidos = COUNT(*) FROM CAD.Pessoa p WHERE p.CPF_CNPJ = @CpfCnpj AND p.ID_PESSOA <> ISNULL(@IdPessoa, 0);

        SET @EtapaAtual = 'Gravação da pessoa';
        BEGIN TRANSACTION;

        IF @IdPessoa IS NULL
        BEGIN
            INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, NOME_FANTASIA, CPF_CNPJ, RG, ORGAO_EMISSOR, INSCRICAO_ESTADUAL, INSCRICAO_MUNICIPAL,
                                    DT_NASCIMENTO, NACIONALIDADE, PROFISSAO, ESTADO_CIVIL, REGIME_BENS, CEP, LOGRADOURO, NUMERO, COMPLEMENTO,
                                    BAIRRO, CIDADE, UF, CLIENTE, FORNECEDOR, FUNCIONARIO, CORRETOR, OBSERVACAO, USUARIO_CRIACAO)
            VALUES (@TipoPessoa, @Nome, @NomeFantasia, @CpfCnpj, @Rg, @OrgaoEmissor, @InscricaoEstadual, @InscricaoMunicipal,
                    @DtNascimento, @Nacionalidade, @Profissao, @EstadoCivil, @RegimeBens, @Cep, @Logradouro, @Numero, @Complemento,
                    @Bairro, @Cidade, @Uf, @Cliente, @Fornecedor, @Funcionario, @Corretor, @Observacao, @Usuario);
            SET @IdPessoa = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE p
               SET p.TIPO_PESSOA = @TipoPessoa, p.NOME = @Nome, p.NOME_FANTASIA = @NomeFantasia, p.CPF_CNPJ = @CpfCnpj, p.RG = @Rg,
                   p.ORGAO_EMISSOR = @OrgaoEmissor, p.INSCRICAO_ESTADUAL = @InscricaoEstadual, p.INSCRICAO_MUNICIPAL = @InscricaoMunicipal,
                   p.DT_NASCIMENTO = @DtNascimento, p.NACIONALIDADE = @Nacionalidade, p.PROFISSAO = @Profissao, p.ESTADO_CIVIL = @EstadoCivil,
                   p.REGIME_BENS = @RegimeBens, p.CEP = @Cep, p.LOGRADOURO = @Logradouro, p.NUMERO = @Numero, p.COMPLEMENTO = @Complemento,
                   p.BAIRRO = @Bairro, p.CIDADE = @Cidade, p.UF = @Uf, p.CLIENTE = @Cliente, p.FORNECEDOR = @Fornecedor,
                   p.FUNCIONARIO = @Funcionario, p.CORRETOR = @Corretor, p.OBSERVACAO = @Observacao,
                   p.DT_ALTERACAO = @Agora, p.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa p
            WHERE p.ID_PESSOA = @IdPessoa;

        -- Listas: NULL = não mexe; informada = fica igual à lista (o que saiu é desativado, não apagado)
        IF @Contatos IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos contatos';
            UPDATE pc
               SET pc.TIPO = c.TIPO, pc.VALOR = c.VALOR, pc.NOME_CONTATO = c.NOME, pc.PRINCIPAL = c.PRINCIPAL, pc.RECEBE_COBRANCA = c.RECEBE,
                   pc.ATIVO = 1, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            INNER JOIN @Cont c ON c.ID = pc.ID_PESSOA_CONTATO
            WHERE pc.ID_PESSOA = @IdPessoa;

            UPDATE pc
               SET pc.ATIVO = 0, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            WHERE pc.ID_PESSOA = @IdPessoa AND pc.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Cont c WHERE c.ID = pc.ID_PESSOA_CONTATO);

            INSERT INTO CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR, NOME_CONTATO, PRINCIPAL, RECEBE_COBRANCA, USUARIO_CRIACAO)
            SELECT @IdPessoa, c.TIPO, c.VALOR, c.NOME, c.PRINCIPAL, c.RECEBE, @Usuario
            FROM @Cont c
            WHERE c.ID IS NULL
            ORDER BY c.LINHA;
        END;

        IF @Vinculos IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos vínculos';
            UPDATE pv
               SET pv.OBSERVACAO = v.OBSERVACAO, pv.ATIVO = 1, pv.DT_ALTERACAO = @Agora, pv.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Vinculo pv
            INNER JOIN @Vinc v ON v.ID_VINCULADA = pv.ID_PESSOA_VINCULADA AND v.TIPO = pv.TIPO
            WHERE pv.ID_PESSOA = @IdPessoa;

            UPDATE pv
               SET pv.ATIVO = 0, pv.DT_ALTERACAO = @Agora, pv.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Vinculo pv
            WHERE pv.ID_PESSOA = @IdPessoa AND pv.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Vinc v WHERE v.ID_VINCULADA = pv.ID_PESSOA_VINCULADA AND v.TIPO = pv.TIPO);

            INSERT INTO CAD.Pessoa_Vinculo (ID_PESSOA, ID_PESSOA_VINCULADA, TIPO, OBSERVACAO, USUARIO_CRIACAO)
            SELECT @IdPessoa, v.ID_VINCULADA, v.TIPO, v.OBSERVACAO, @Usuario
            FROM @Vinc v
            WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Vinculo pv WHERE pv.ID_PESSOA = @IdPessoa AND pv.ID_PESSOA_VINCULADA = v.ID_VINCULADA AND pv.TIPO = v.TIPO)
            ORDER BY v.LINHA;
        END;

        IF @DadosBancarios IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos dados bancários';
            UPDATE d
               SET d.TIPO = b.TIPO, d.ID_BANCO = b.ID_BANCO, d.AGENCIA = b.AGENCIA, d.AGENCIA_DV = b.AGENCIA_DV, d.CONTA = b.CONTA,
                   d.CONTA_DV = b.CONTA_DV, d.TIPO_CONTA = b.TIPO_CONTA, d.TITULAR_NOME = b.TITULAR_NOME, d.TITULAR_DOCUMENTO = b.TITULAR_DOC,
                   d.PIX_TIPO = b.PIX_TIPO, d.PIX_CHAVE = b.PIX_CHAVE, d.PRINCIPAL = b.PRINCIPAL, d.ATIVO = 1,
                   d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Dado_Bancario d
            INNER JOIN @Banc b ON b.ID = d.ID_PESSOA_DADO_BANCARIO
            WHERE d.ID_PESSOA = @IdPessoa;

            UPDATE d
               SET d.ATIVO = 0, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Dado_Bancario d
            WHERE d.ID_PESSOA = @IdPessoa AND d.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Banc b WHERE b.ID = d.ID_PESSOA_DADO_BANCARIO);

            INSERT INTO CAD.Pessoa_Dado_Bancario (ID_PESSOA, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, CONTA, CONTA_DV, TIPO_CONTA, TITULAR_NOME,
                                                  TITULAR_DOCUMENTO, PIX_TIPO, PIX_CHAVE, PRINCIPAL, USUARIO_CRIACAO)
            SELECT @IdPessoa, b.TIPO, b.ID_BANCO, b.AGENCIA, b.AGENCIA_DV, b.CONTA, b.CONTA_DV, b.TIPO_CONTA, b.TITULAR_NOME,
                   b.TITULAR_DOC, b.PIX_TIPO, b.PIX_CHAVE, b.PRINCIPAL, @Usuario
            FROM @Banc b
            WHERE b.ID IS NULL
            ORDER BY b.LINHA;
        END;

        COMMIT TRANSACTION;

        SET @Mensagem = N'Pessoa gravada (código ' + CONVERT(NVARCHAR(10), @IdPessoa) + N').'
                      + CASE WHEN @Repetidos > 0
                             THEN N' Atenção: já existe(m) ' + CONVERT(NVARCHAR(10), @Repetidos) + N' outra(s) pessoa(s) com este CPF/CNPJ.'
                             ELSE N'' END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(@Mensagem AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a pessoa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma pessoa. Nada é apagado: a
                pessoa some das listas de escolha, mas continua nos lançamentos e no
                histórico. Permissão: EXCLUIR em CAD_PESSOA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Excluir @IdUsuario = 2, @IdPessoa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Excluir]
    @IdUsuario  INT,
    @IdPessoa  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar pessoas.';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM CAD.Pessoa t WHERE t.ID_PESSOA = @IdPessoa;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Pessoa t
        WHERE t.ID_PESSOA = @IdPessoa
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPessoa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Conta_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Conta_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Plano de contas": a árvore inteira, uma linha por nível
                (NIVEL 1 grupo, 2 subgrupo, 3 conta), na ordem numérica (ORDEM_ARVORE),
                com ID_PAI para montar a árvore. TIPO e CUSTO_OBRA vêm do grupo;
                CONTABIL e CONTA_CONTABIL_REF só na conta. ATIVO_EFETIVO: o registro e
                todos os de cima ativos. @SomenteAtivos = 1: só ATIVO_EFETIVO.
                Permissão: VER em CAD_PLANO_CONTA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Plano_Conta_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Conta_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Conta_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver o plano de contas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT x.NIVEL, x.ID, x.ID_PAI, x.NUMERO, x.CODIGO, x.DESCRICAO, x.TIPO, x.CUSTO_OBRA, x.CONTABIL, x.CONTA_CONTABIL_REF,
               x.ORDEM, x.ATIVO, x.ATIVO_EFETIVO, x.ORDEM_ARVORE, x.DT_ALTERACAO, x.USUARIO_ALTERACAO
        FROM (
            SELECT CAST(1 AS TINYINT) AS NIVEL, g.ID_PLANO_GRUPO AS ID, CAST(NULL AS INT) AS ID_PAI, g.NUMERO,
                   CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2)) AS CODIGO,
                   g.DESCRICAO, g.TIPO, g.CUSTO_OBRA, CAST(0 AS BIT) AS CONTABIL, CONVERT(VARCHAR(30), '') AS CONTA_CONTABIL_REF,
                   g.ORDEM, g.ATIVO, g.ATIVO AS ATIVO_EFETIVO,
                   CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.00.000') AS ORDEM_ARVORE,
                   g.DT_ALTERACAO, ISNULL(g.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
            FROM CAD.Plano_Grupo g WITH (NOLOCK)
            UNION ALL
            SELECT CAST(2 AS TINYINT), s.ID_PLANO_SUBGRUPO, s.ID_PLANO_GRUPO, s.NUMERO,
                   CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + CONVERT(VARCHAR(3), s.NUMERO)),
                   s.DESCRICAO, g.TIPO, g.CUSTO_OBRA, CAST(0 AS BIT), CONVERT(VARCHAR(30), ''),
                   s.ORDEM, s.ATIVO, CAST(CASE WHEN s.ATIVO = 1 AND g.ATIVO = 1 THEN 1 ELSE 0 END AS BIT),
                   CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + RIGHT('00' + CONVERT(VARCHAR(3), s.NUMERO), 2) + '.000'),
                   s.DT_ALTERACAO, ISNULL(s.USUARIO_ALTERACAO, N'')
            FROM CAD.Plano_Subgrupo s WITH (NOLOCK)
            INNER JOIN CAD.Plano_Grupo g WITH (NOLOCK) ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO
            UNION ALL
            SELECT CAST(3 AS TINYINT), v.ID_PLANO_CONTA, v.ID_PLANO_SUBGRUPO, v.NUMERO_CONTA, v.CODIGO,
                   v.DESCRICAO, v.TIPO, v.CUSTO_OBRA, v.CONTABIL, v.CONTA_CONTABIL_REF,
                   CAST(0 AS SMALLINT), v.CONTA_ATIVA, v.ATIVO_EFETIVO, v.ORDEM_ARVORE,
                   c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'')
            FROM CAD.vw_CAD_Plano_Conta v WITH (NOLOCK)
            INNER JOIN CAD.Plano_Conta c WITH (NOLOCK) ON c.ID_PLANO_CONTA = v.ID_PLANO_CONTA
        ) x
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR x.ATIVO_EFETIVO = 1)
        ORDER BY x.ORDEM_ARVORE;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o plano de contas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Grupo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Grupo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoGrupo NULL) ou altera um grupo (nível 1) do plano de
                contas. @Numero NULL = próximo número livre. Número (0 a 99) e
                descrição não repetem. TIPO: RECEITA, DESPESA, NAO_OPERACIONAL.
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Grupo_Gravar]
    @IdUsuario     INT,
    @IdPlanoGrupo  INT          = NULL,
    @Numero        SMALLINT     = NULL,
    @Descricao     NVARCHAR(80),
    @Tipo          VARCHAR(15),
    @CustoObra     BIT          = 0,
    @Ordem         SMALLINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Grupo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo      = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @CustoObra = ISNULL(@CustoObra, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoGrupo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoGrupo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Grupo x WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND @Tipo NOT IN ('RECEITA', 'DESPESA', 'NAO_OPERACIONAL')
            SET @Recusa = N'Tipo do grupo inválido: receita, despesa ou não operacional.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Grupo g WHERE g.DESCRICAO = @Descricao AND g.ID_PLANO_GRUPO <> ISNULL(@IdPlanoGrupo, 0))
            SET @Recusa = N'Já existe um grupo com esta descrição.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Grupo x WITH (UPDLOCK, HOLDLOCK);

        IF @Numero NOT BETWEEN 0 AND 99
            SET @Recusa = N'Número do grupo fora da faixa (0 a 99).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Grupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.NUMERO = @Numero AND x.ID_PLANO_GRUPO <> ISNULL(@IdPlanoGrupo, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
            RETURN;
        END;

        IF @IdPlanoGrupo IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Grupo (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ORDEM, USUARIO_CRIACAO)
            VALUES (@Numero, @Descricao, @Tipo, @CustoObra, ISNULL(@Ordem, @Numero), @Usuario);
            SET @IdPlanoGrupo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE g
               SET g.NUMERO = @Numero, g.DESCRICAO = @Descricao, g.TIPO = @Tipo, g.CUSTO_OBRA = @CustoObra, g.ORDEM = ISNULL(@Ordem, g.ORDEM),
                   g.DT_ALTERACAO = SYSDATETIME(), g.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Grupo g
            WHERE g.ID_PLANO_GRUPO = @IdPlanoGrupo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Subgrupo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Subgrupo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoSubgrupo NULL) ou altera um subgrupo (nível 2),
                sempre dentro de um grupo. @Numero NULL = próximo livre no grupo.
                Número (1 a 99) e descrição não repetem dentro do grupo. Mudar de grupo
                é permitido (fica na auditoria).
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Subgrupo_Gravar]
    @IdUsuario     INT,
    @IdPlanoSubgrupo  INT          = NULL,
    @IdPlanoGrupo     INT,
    @Numero           SMALLINT     = NULL,
    @Descricao        NVARCHAR(80),
    @Ordem            SMALLINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Subgrupo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));


        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoSubgrupo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoSubgrupo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo x WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @IdPlanoGrupo)
            SET @Recusa = N'Escolha o grupo do subgrupo.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_GRUPO = @IdPlanoGrupo AND s.DESCRICAO = @Descricao
                                     AND s.ID_PLANO_SUBGRUPO <> ISNULL(@IdPlanoSubgrupo, 0))
            SET @Recusa = N'Já existe um subgrupo com esta descrição neste grupo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Subgrupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo;

        IF @Numero NOT BETWEEN 1 AND 99
            SET @Recusa = N'Número do subgrupo fora da faixa (1 a 99).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo AND x.NUMERO = @Numero AND x.ID_PLANO_SUBGRUPO <> ISNULL(@IdPlanoSubgrupo, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
            RETURN;
        END;

        IF @IdPlanoSubgrupo IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Subgrupo (ID_PLANO_GRUPO, NUMERO, DESCRICAO, ORDEM, USUARIO_CRIACAO)
            VALUES (@IdPlanoGrupo, @Numero, @Descricao, ISNULL(@Ordem, @Numero), @Usuario);
            SET @IdPlanoSubgrupo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE s
               SET s.ID_PLANO_GRUPO = @IdPlanoGrupo, s.NUMERO = @Numero, s.DESCRICAO = @Descricao, s.ORDEM = ISNULL(@Ordem, s.ORDEM),
                   s.DT_ALTERACAO = SYSDATETIME(), s.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Subgrupo s
            WHERE s.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Conta_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Conta_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoConta NULL) ou altera uma conta (nível 3, a que recebe
                lançamento), sempre dentro de um subgrupo. @Numero NULL = próximo livre
                no subgrupo. Número (1 a 999) e descrição não repetem dentro do
                subgrupo. CONTABIL e CONTA_CONTABIL_REF: pedido 10 / contabilidade.
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Conta_Gravar]
    @IdUsuario     INT,
    @IdPlanoConta      INT          = NULL,
    @IdPlanoSubgrupo   INT,
    @Numero            SMALLINT     = NULL,
    @Descricao         NVARCHAR(80),
    @Contabil          BIT          = 0,
    @ContaContabilRef  VARCHAR(30)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Conta_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Contabil         = ISNULL(@Contabil, 0);
        SET @ContaContabilRef = LTRIM(RTRIM(ISNULL(@ContaContabilRef, '')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoConta IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Conta x WHERE x.ID_PLANO_CONTA = @IdPlanoConta)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo)
            SET @Recusa = N'Escolha o subgrupo da conta.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Conta c WHERE c.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo AND c.DESCRICAO = @Descricao
                                     AND c.ID_PLANO_CONTA <> ISNULL(@IdPlanoConta, 0))
            SET @Recusa = N'Já existe uma conta com esta descrição neste subgrupo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Conta x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo;

        IF @Numero NOT BETWEEN 1 AND 999
            SET @Recusa = N'Número do conta fora da faixa (1 a 999).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Conta x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo AND x.NUMERO = @Numero AND x.ID_PLANO_CONTA <> ISNULL(@IdPlanoConta, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
            RETURN;
        END;

        IF @IdPlanoConta IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Conta (ID_PLANO_SUBGRUPO, NUMERO, DESCRICAO, CONTABIL, CONTA_CONTABIL_REF, USUARIO_CRIACAO)
            VALUES (@IdPlanoSubgrupo, @Numero, @Descricao, @Contabil, @ContaContabilRef, @Usuario);
            SET @IdPlanoConta = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE c
               SET c.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo, c.NUMERO = @Numero, c.DESCRICAO = @Descricao, c.CONTABIL = @Contabil,
                   c.CONTA_CONTABIL_REF = @ContaContabilRef, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Conta c
            WHERE c.ID_PLANO_CONTA = @IdPlanoConta;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) um grupo (@Nivel 1), subgrupo (2)
                ou conta (3) do plano. Nada é apagado: desativar o grupo ou o subgrupo
                esconde tudo abaixo dele das listas de escolha (ATIVO_EFETIVO), sem
                mexer nos filhos. Permissão: EXCLUIR em CAD_PLANO_CONTA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Plano_Excluir @IdUsuario = 2, @Nivel = 3, @Id = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Excluir]
    @IdUsuario  INT,
    @Nivel      TINYINT,
    @Id         INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar o plano de contas.';
        IF @Recusa = N'' AND ISNULL(@Nivel, 0) NOT IN (1, 2, 3)
            SET @Recusa = N'Nível inválido (1 grupo, 2 subgrupo, 3 conta).';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = CASE @Nivel WHEN 1 THEN (SELECT g.ATIVO FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @Id)
                                        WHEN 2 THEN (SELECT s.ATIVO FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @Id)
                                        ELSE (SELECT c.ATIVO FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @Id) END;
            IF @Ativo IS NULL SET @Recusa = N'Registro do plano de contas não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @Nivel = 1
            UPDATE g SET g.ATIVO = @Reativar, g.DT_ALTERACAO = SYSDATETIME(), g.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @Id AND g.ATIVO <> @Reativar;
        IF @Nivel = 2
            UPDATE s SET s.ATIVO = @Reativar, s.DT_ALTERACAO = SYSDATETIME(), s.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @Id AND s.ATIVO <> @Reativar;
        IF @Nivel = 3
            UPDATE c SET c.ATIVO = @Reativar, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @Id AND c.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @Id AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/Carga_BANCO_Banco.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [BANCO].[Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Principais bancos (código COMPE e ISPB). Só insere o que falta
                (regra 39): banco já cadastrado não é alterado. O administrador
                acrescenta outros pela tela "Bancos" (conferir o ISPB antes de usar
                em PIX).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO BANCO.Banco (CODIGO, ISPB, NOME, USUARIO_CRIACAO)
SELECT v.CODIGO, v.ISPB, v.NOME, N'instalacao'
FROM (VALUES
        (CAST('001' AS CHAR(3)), CAST('00000000' AS VARCHAR(8)), CAST(N'Banco do Brasil' AS NVARCHAR(80))),
        ('033', '90400888', N'Santander'),
        ('041', '92702067', N'Banrisul'),
        ('077', '00416968', N'Banco Inter'),
        ('104', '00360305', N'Caixa Econômica Federal'),
        ('208', '30306294', N'BTG Pactual'),
        ('237', '60746948', N'Bradesco'),
        ('260', '18236120', N'Nubank'),
        ('290', '08561701', N'PagBank (PagSeguro)'),
        ('323', '10573521', N'Mercado Pago'),
        ('336', '31872495', N'C6 Bank'),
        ('341', '60701190', N'Itaú Unibanco'),
        ('422', '58160789', N'Safra'),
        ('748', '01181521', N'Sicredi'),
        ('756', '02038232', N'Sicoob')
     ) v (CODIGO, ISPB, NOME)
WHERE NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.CODIGO = v.CODIGO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/Carga_CAD_Item.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Item] e [SIS].[Item_Acao] dos módulos CAD e BANCO
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Telas da etapa 03a no menu: Cadastros (Empresas, Pessoas, Centros de
                custo, Plano de contas) e Bancos (Contas bancárias, Bancos), com as
                ações de cada tela. Só insere o que falta (regra 39). Telas de módulo
                novo nascem DESABILITADAS (HABILITADO = 0): o administrador geral liga
                na tela "Módulos e telas" quando quiser liberar. Acertado também em
                item já existente: TABELAS_DA_TELA (itens só mudam por carga).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaItem;

SELECT v.MODULO, v.CODIGO, v.NOME, v.CAMINHO, v.ORDEM, v.TABELAS
INTO #CargaItem
FROM (VALUES
        (CAST('CAD' AS VARCHAR(10)), CAST('CAD_EMPRESA' AS VARCHAR(40)), CAST(N'Empresas' AS NVARCHAR(80)), CAST('cad/empresas.html' AS VARCHAR(200)),
         CAST(10 AS SMALLINT), CAST('CAD.Empresa' AS VARCHAR(500))),
        ('CAD',   'CAD_PESSOA',       N'Pessoas',          'cad/pessoas.html',        20, 'CAD.Pessoa,CAD.Pessoa_Contato,CAD.Pessoa_Vinculo,CAD.Pessoa_Dado_Bancario'),
        ('CAD',   'CAD_CENTRO_CUSTO', N'Centros de custo', 'cad/centros-custo.html',  30, 'CAD.Centro_Custo'),
        ('CAD',   'CAD_PLANO_CONTA',  N'Plano de contas',  'cad/plano-contas.html',   40, 'CAD.Plano_Grupo,CAD.Plano_Subgrupo,CAD.Plano_Conta'),
        ('BANCO', 'BANCO_CONTA',      N'Contas bancárias', 'banco/contas.html',       10, 'BANCO.Conta'),
        ('BANCO', 'BANCO_BANCO',      N'Bancos',           'banco/bancos.html',       20, 'BANCO.Banco')
     ) v (MODULO, CODIGO, NOME, CAMINHO, ORDEM, TABELAS);

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, c.CODIGO, c.NOME, 'TELA', c.CAMINHO, c.ORDEM, 0, 0, c.TABELAS
FROM #CargaItem c
INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = c.CODIGO);

UPDATE i
   SET i.TABELAS_DA_TELA = c.TABELAS, i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
INNER JOIN #CargaItem c ON c.CODIGO = i.CODIGO
WHERE i.TABELAS_DA_TELA <> c.TABELAS;

DROP TABLE IF EXISTS #CargaItem;
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES
        (CAST('CAD_EMPRESA' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))),
        ('CAD_EMPRESA', 'INCLUIR'), ('CAD_EMPRESA', 'ALTERAR'), ('CAD_EMPRESA', 'EXCLUIR'), ('CAD_EMPRESA', 'EXPORTAR'),
        ('CAD_PESSOA', 'VER'), ('CAD_PESSOA', 'INCLUIR'), ('CAD_PESSOA', 'ALTERAR'), ('CAD_PESSOA', 'EXCLUIR'), ('CAD_PESSOA', 'EXPORTAR'),
        ('CAD_CENTRO_CUSTO', 'VER'), ('CAD_CENTRO_CUSTO', 'INCLUIR'), ('CAD_CENTRO_CUSTO', 'ALTERAR'), ('CAD_CENTRO_CUSTO', 'EXCLUIR'), ('CAD_CENTRO_CUSTO', 'EXPORTAR'),
        ('CAD_PLANO_CONTA', 'VER'), ('CAD_PLANO_CONTA', 'INCLUIR'), ('CAD_PLANO_CONTA', 'ALTERAR'), ('CAD_PLANO_CONTA', 'EXCLUIR'), ('CAD_PLANO_CONTA', 'EXPORTAR'),
        ('BANCO_CONTA', 'VER'), ('BANCO_CONTA', 'INCLUIR'), ('BANCO_CONTA', 'ALTERAR'), ('BANCO_CONTA', 'EXCLUIR'), ('BANCO_CONTA', 'EXPORTAR'),
        ('BANCO_BANCO', 'VER'), ('BANCO_BANCO', 'INCLUIR'), ('BANCO_BANCO', 'ALTERAR'), ('BANCO_BANCO', 'EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/Carga_CAD_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do CAD e do BANCO
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas 11 tabelas da etapa 03a, gerando cada
                trigger com SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas. No MASTER
                fica na parte 8 (triggers).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Banco',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Conta',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Centro_Custo',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa',                @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Contato',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Vinculo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Dado_Bancario',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Grupo',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Subgrupo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Conta',           @Criar = 1;
GO

PRINT N'Pacote 03a concluído sem erro.';
GO

SET NOEXEC OFF;
GO
