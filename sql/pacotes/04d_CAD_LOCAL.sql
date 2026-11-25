/*******************************************************************************
  Pacote      : 04d - Parceiros (P12, P10): tipos de parceiro, finalidade e principal unico nos contatos, validade do anexo, conta/centro padrao, cache de CEP
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 25/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04c2 já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/CAD/04d_Homologacao_Parceiros.sql, 03a e 04b.
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
-- Arquivo: sql/objetos/CAD/CAD.Parceiro_Tipo.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Pessoa_Tipo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Tipos de cada parceiro (P12; vários por parceiro). Tipo
                retirado na tela é desativado (não apagado), como os contatos.
                As marcas CLIENTE/FORNECEDOR/FUNCIONARIO/CORRETOR de CAD.Pessoa
                continuam e são acertadas pelo CAD_Pessoa_Gravar a partir dos
                tipos do sistema (compatibilidade com as regras e a migração).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Tipo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Tipo]
    (
        ID_PESSOA_TIPO     INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA          INT            NOT NULL,
        ID_PARCEIRO_TIPO   INT            NOT NULL,
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Pessoa_Tipo_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Tipo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Tipo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Tipo          PRIMARY KEY CLUSTERED (ID_PESSOA_TIPO),
        CONSTRAINT FK_Pessoa_Tipo_Pessoa   FOREIGN KEY (ID_PESSOA)        REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Pessoa_Tipo_Tipo     FOREIGN KEY (ID_PARCEIRO_TIPO) REFERENCES [CAD].[Parceiro_Tipo] (ID_PARCEIRO_TIPO),
        CONSTRAINT UQ_Pessoa_Tipo          UNIQUE (ID_PESSOA, ID_PARCEIRO_TIPO)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_Tipo_Tipo' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Tipo]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_Tipo_Tipo ON [CAD].[Pessoa_Tipo] (ID_PARCEIRO_TIPO, ATIVO) INCLUDE (ID_PESSOA);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Cep_Cache.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Cep_Cache]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Endereços já consultados pelo CEP (ViaCEP / BrasilAPI), para
                não repetir a consulta na internet. Gravado pela API depois de
                uma consulta bem-sucedida; validade em parâmetro (CEP_CACHE_DIAS).
                Dado público (Correios): não é dado pessoal.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Cep_Cache]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Cep_Cache]
    (
        CEP                VARCHAR(8)     NOT NULL,
        LOGRADOURO         NVARCHAR(150)  NOT NULL CONSTRAINT DF_Cep_Cache_LOGRADOURO DEFAULT (N''),
        COMPLEMENTO        NVARCHAR(60)   NOT NULL CONSTRAINT DF_Cep_Cache_COMPLEMENTO DEFAULT (N''),
        BAIRRO             NVARCHAR(60)   NOT NULL CONSTRAINT DF_Cep_Cache_BAIRRO     DEFAULT (N''),
        CIDADE             NVARCHAR(60)   NOT NULL,
        UF                 CHAR(2)        NOT NULL,
        CODIGO_IBGE        VARCHAR(7)     NOT NULL CONSTRAINT DF_Cep_Cache_IBGE       DEFAULT (''),
        FONTE              VARCHAR(20)    NOT NULL,
        DT_CONSULTA        DATETIME2(0)   NOT NULL CONSTRAINT DF_Cep_Cache_DT         DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Cep_Cache     PRIMARY KEY CLUSTERED (CEP),
        CONSTRAINT CK_Cep_Cache_CEP CHECK (LEN(CEP) = 8 AND CEP NOT LIKE '%[^0-9]%')
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
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
    v1.2 (25/11/2026) - Etapa 04d: ID_PLANO_CONTA_PADRAO e ID_CENTRO_CUSTO_PADRAO (P17, vêm no lançamento).
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

IF COL_LENGTH(N'CAD.Pessoa', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Pessoa] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Pessoa', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Pessoa] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

IF COL_LENGTH(N'CAD.Pessoa', N'ID_PLANO_CONTA_PADRAO') IS NULL
    ALTER TABLE [CAD].[Pessoa] ADD ID_PLANO_CONTA_PADRAO INT NULL;
GO
IF COL_LENGTH(N'CAD.Pessoa', N'ID_CENTRO_CUSTO_PADRAO') IS NULL
    ALTER TABLE [CAD].[Pessoa] ADD ID_CENTRO_CUSTO_PADRAO INT NULL;
GO
IF OBJECT_ID(N'[CAD].[FK_Pessoa_Plano_Conta_Padrao]', N'F') IS NULL
    ALTER TABLE [CAD].[Pessoa] ADD CONSTRAINT FK_Pessoa_Plano_Conta_Padrao FOREIGN KEY (ID_PLANO_CONTA_PADRAO) REFERENCES [CAD].[Plano_Conta] (ID_PLANO_CONTA);
GO
IF OBJECT_ID(N'[CAD].[FK_Pessoa_Centro_Custo_Padrao]', N'F') IS NULL
    ALTER TABLE [CAD].[Pessoa] ADD CONSTRAINT FK_Pessoa_Centro_Custo_Padrao FOREIGN KEY (ID_CENTRO_CUSTO_PADRAO) REFERENCES [CAD].[Centro_Custo] (ID_CENTRO_CUSTO);
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
    v1.1 (25/11/2026) - Etapa 04d (P12): FINALIDADE (COBRANCA, COMPRAS, FINANCEIRO ou vazio)
                        e um só PRINCIPAL ativo por pessoa e tipo (índice único filtrado;
                        duplicados antigos: fica principal o de menor código).
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

IF COL_LENGTH(N'CAD.Pessoa_Contato', N'FINALIDADE') IS NULL
    ALTER TABLE [CAD].[Pessoa_Contato] ADD FINALIDADE VARCHAR(15) NOT NULL CONSTRAINT DF_Pessoa_Contato_FINALIDADE DEFAULT ('');
GO
IF OBJECT_ID(N'[CAD].[CK_Pessoa_Contato_FINALIDADE]', N'C') IS NULL
    ALTER TABLE [CAD].[Pessoa_Contato] ADD CONSTRAINT CK_Pessoa_Contato_FINALIDADE CHECK (FINALIDADE IN ('', 'COBRANCA', 'COMPRAS', 'FINANCEIRO'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Pessoa_Contato_Principal' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Contato]'))
BEGIN
    WITH d AS (SELECT c.PRINCIPAL, ROW_NUMBER() OVER (PARTITION BY c.ID_PESSOA, c.TIPO ORDER BY c.ID_PESSOA_CONTATO) AS N
               FROM CAD.Pessoa_Contato c WHERE c.PRINCIPAL = 1 AND c.ATIVO = 1)
    UPDATE d SET PRINCIPAL = 0 WHERE N > 1;
    CREATE UNIQUE NONCLUSTERED INDEX UX_Pessoa_Contato_Principal ON [CAD].[Pessoa_Contato] (ID_PESSOA, TIPO) WHERE PRINCIPAL = 1 AND ATIVO = 1;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Anexo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Anexo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Anexos de qualquer registro (seção 3.1 item 6 e 3.2):
                lançamento, parcela, venda, contrato, cliente, obra (logomarca
                da obra)... O arquivo fica em disco, na pasta do parâmetro
                ANEXO_PASTA_RAIZ + PASTA_RELATIVA (ano\mês); o banco guarda só
                a referência.
                  TABELA_REFERENCIA + ID_REFERENCIA: de qual registro é
                  NOME_ORIGINAL : nome que o usuário enviou (para baixar)
                  NOME_ARQUIVO  : nome gerado pela API (GUID + extensão), sem
                                  acento e sem espaço (regra 51)
                  HASH_SHA256   : calculado pela API; impede anexar o mesmo
                                  arquivo duas vezes no mesmo registro
                Excluir = desativar (SITUACAO 'EXCLUIDO' + quem, quando e
                motivo); o arquivo continua em disco (regra 56).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (25/11/2026) - Etapa 04d (P12): DT_VALIDADE opcional (certidões, contratos).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Anexo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Anexo]
    (
        ID_ANEXO           BIGINT          IDENTITY(1,1) NOT NULL,
        TABELA_REFERENCIA  NVARCHAR(256)   NOT NULL,
        ID_REFERENCIA      BIGINT          NOT NULL,
        ID_ANEXO_TIPO      INT             NOT NULL,
        NOME_ORIGINAL      NVARCHAR(260)   NOT NULL,
        NOME_ARQUIVO       VARCHAR(100)    NOT NULL,
        PASTA_RELATIVA     VARCHAR(50)     NOT NULL CONSTRAINT DF_Anexo_PASTA_RELATIVA  DEFAULT (''),
        EXTENSAO           VARCHAR(10)     NOT NULL,
        TAMANHO_BYTES      BIGINT          NOT NULL,
        HASH_SHA256        VARBINARY(32)   NOT NULL,
        DESCRICAO          NVARCHAR(400)   NOT NULL CONSTRAINT DF_Anexo_DESCRICAO       DEFAULT (N''),
        SITUACAO           VARCHAR(10)     NOT NULL CONSTRAINT DF_Anexo_SITUACAO        DEFAULT ('ATIVO'),
        DT_EXCLUSAO        DATETIME2(0)    NULL,
        USUARIO_EXCLUSAO   NVARCHAR(100)   NULL,
        MOTIVO_EXCLUSAO    NVARCHAR(400)   NULL,
        DT_CRIACAO         DATETIME2(0)    NOT NULL CONSTRAINT DF_Anexo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)   NOT NULL CONSTRAINT DF_Anexo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)    NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)   NULL,
        CONSTRAINT PK_Anexo              PRIMARY KEY CLUSTERED (ID_ANEXO),
        CONSTRAINT UQ_Anexo_NOME_ARQUIVO UNIQUE (NOME_ARQUIVO),
        CONSTRAINT FK_Anexo_Anexo_Tipo   FOREIGN KEY (ID_ANEXO_TIPO) REFERENCES [SIS].[Anexo_Tipo] (ID_ANEXO_TIPO),
        CONSTRAINT CK_Anexo_SITUACAO     CHECK (SITUACAO IN ('ATIVO', 'EXCLUIDO')),
        CONSTRAINT CK_Anexo_TAMANHO      CHECK (TAMANHO_BYTES > 0),
        CONSTRAINT CK_Anexo_HASH         CHECK (DATALENGTH(HASH_SHA256) = 32)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Anexo]') AND i.name = N'IX_Anexo_REFERENCIA')
    CREATE NONCLUSTERED INDEX IX_Anexo_REFERENCIA ON [SIS].[Anexo] (TABELA_REFERENCIA, ID_REFERENCIA, SITUACAO);
GO

IF COL_LENGTH(N'SIS.Anexo', N'DT_VALIDADE') IS NULL
    ALTER TABLE [SIS].[Anexo] ADD DT_VALIDADE DATE NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/Carga_CAD_Parceiro_Tipo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [CAD].[Parceiro_Tipo] e [CAD].[Pessoa_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Tipos de fábrica (SISTEMA = 1): NA ("N/A", para classificar
                depois), CLIENTE, FORNECEDOR, FUNCIONARIO e CORRETOR. Nunca
                muda a descrição que a CMJ editou.
                Completa os tipos de cada parceiro a partir das marcas antigas
                de CAD.Pessoa (só o que falta) e põe N/A em quem ficou sem tipo
                ativo. Idempotente.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d, P12).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO CAD.Parceiro_Tipo (CODIGO, DESCRICAO, SISTEMA, ORDEM, USUARIO_CRIACAO)
SELECT v.CODIGO, v.DESCRICAO, 1, v.ORDEM, N'instalacao'
FROM (VALUES ('NA', N'N/A (a classificar)', 1),
             ('CLIENTE', N'Cliente', 10),
             ('FORNECEDOR', N'Fornecedor', 20),
             ('FUNCIONARIO', N'Funcionário', 30),
             ('CORRETOR', N'Corretor', 40)) v (CODIGO, DESCRICAO, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = v.CODIGO);

UPDATE CAD.Parceiro_Tipo SET SISTEMA = 1, ATIVO = 1
WHERE CODIGO IN ('NA', 'CLIENTE', 'FORNECEDOR', 'FUNCIONARIO', 'CORRETOR') AND (SISTEMA = 0 OR ATIVO = 0);
GO

INSERT INTO CAD.Pessoa_Tipo (ID_PESSOA, ID_PARCEIRO_TIPO, USUARIO_CRIACAO)
SELECT p.ID_PESSOA, t.ID_PARCEIRO_TIPO, N'instalacao'
FROM CAD.Pessoa p
CROSS APPLY (VALUES ('CLIENTE', p.CLIENTE), ('FORNECEDOR', p.FORNECEDOR), ('FUNCIONARIO', p.FUNCIONARIO), ('CORRETOR', p.CORRETOR)) m (CODIGO, MARCA)
INNER JOIN CAD.Parceiro_Tipo t ON t.CODIGO = m.CODIGO
WHERE m.MARCA = 1
  AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ID_PARCEIRO_TIPO = t.ID_PARCEIRO_TIPO);

INSERT INTO CAD.Pessoa_Tipo (ID_PESSOA, ID_PARCEIRO_TIPO, USUARIO_CRIACAO)
SELECT p.ID_PESSOA, t.ID_PARCEIRO_TIPO, N'instalacao'
FROM CAD.Pessoa p
INNER JOIN CAD.Parceiro_Tipo t ON t.CODIGO = 'NA'
WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ATIVO = 1)
  AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ID_PARCEIRO_TIPO = t.ID_PARCEIRO_TIPO);
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
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Tipo',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Parceiro_Tipo',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Grupo',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Subgrupo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Conta',           @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Tabela_Config.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Tabela_Config] e do grupo de e-mail da lixeira
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Configuração do desfazer e da lixeira por tabela (P20,
                docs/requisitos/Lixeira_Desfazer.md). Inclui o que falta e
                acerta a parte técnica (filhas, campos, descrição) das que já
                existem; o prazo próprio (DIAS_GUARDA) é da CMJ e nunca é
                mudado por aqui.
                Grupo de e-mail LIXEIRA_AVISO (aviso do que será apagado):
                nasce com o e-mail interno do sistema; a CMJ ajusta na tela
                Grupos de e-mail.
                Idempotente.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
    v1.1 (25/11/2026) - Etapa 04d: CAD.Pessoa_Tipo (filha da Pessoa) e CAD.Parceiro_Tipo.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaConfig;

SELECT v.TABELA, v.DESFAZER, v.LIXEIRA, v.BLOQUEADOS, v.UNICOS, v.FILHAS, v.INCLUSAO, v.EXCLUSAO, v.DESCRICAO
INTO #CargaConfig
FROM (VALUES
        (CAST(N'CAD.Pessoa' AS NVARCHAR(256)), CAST(1 AS BIT), CAST(1 AS BIT), CAST(N'' AS NVARCHAR(1000)), CAST(N'CPF_CNPJ' AS NVARCHAR(400)),
         CAST(N'CAD.Pessoa_Contato.ID_PESSOA,CAD.Pessoa_Vinculo.ID_PESSOA,CAD.Pessoa_Dado_Bancario.ID_PESSOA,CAD.Pessoa_Tipo.ID_PESSOA' AS NVARCHAR(1000)),
         CAST('LIXEIRA' AS VARCHAR(10)), CAST('RECUSAR' AS VARCHAR(10)),
         CAST(N't.NOME + CASE WHEN t.CPF_CNPJ <> '''' THEN N'' ('' + CONVERT(NVARCHAR(20), t.CPF_CNPJ) + N'')'' ELSE N'''' END' AS NVARCHAR(1000))),
        (N'CAD.Pessoa_Contato',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(20), t.TIPO) + N'': '' + t.VALOR'),
        (N'CAD.Pessoa_Tipo',          1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Tipo '' + CAST(t.ID_PARCEIRO_TIPO AS NVARCHAR(10))'),
        (N'CAD.Parceiro_Tipo',        1, 1, N'SISTEMA', N'CODIGO', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Pessoa_Vinculo',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Vínculo '' + CONVERT(NVARCHAR(30), t.TIPO)'),
        (N'CAD.Pessoa_Dado_Bancario', 1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Conta '' + CONVERT(NVARCHAR(20), t.AGENCIA) + N'' / '' + CONVERT(NVARCHAR(30), t.CONTA)'),
        (N'CAD.Empresa',              1, 1, N'', N'CNPJ', N'', 'LIXEIRA', 'RECUSAR', N't.RAZAO_SOCIAL'),
        (N'CAD.Centro_Custo',         1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N'CONVERT(NVARCHAR(30), t.CODIGO) + N'' - '' + t.DESCRICAO'),
        (N'CAD.Plano_Grupo',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Subgrupo',       1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Conta',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Conta',              1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Banco',              1, 0, N'', N'', N'', 'RECUSAR', 'RECUSAR', N'CONVERT(NVARCHAR(10), t.CODIGO) + N'' - '' + t.NOME'),
        (N'SIS.Usuario',              1, 0, N'SENHA_HASH,SENHA_SALT,SENHA_ITERACOES,SENHA_ALGORITMO,DT_SENHA,TROCAR_SENHA,TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN,BLOQUEADO,DT_BLOQUEIO,INTERNO',
         N'', N'SIS.Usuario_Permissao.ID_USUARIO', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(100), t.LOGIN) + N'' - '' + t.NOME'),
        (N'SIS.Usuario_Permissao',    1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))'),
        (N'SIS.Perfil',               1, 0, N'NIVEL_ADMIN', N'', N'SIS.Perfil_Permissao.ID_PERFIL', 'DESATIVAR', 'RECUSAR', N't.NOME'),
        (N'SIS.Perfil_Permissao',     1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))')
     ) v (TABELA, DESFAZER, LIXEIRA, BLOQUEADOS, UNICOS, FILHAS, INCLUSAO, EXCLUSAO, DESCRICAO);

INSERT INTO SIS.Tabela_Config (TABELA, PERMITE_DESFAZER, PERMITE_LIXEIRA, CAMPOS_BLOQUEADOS, CAMPOS_UNICOS, TABELAS_FILHAS, DESFAZER_INCLUSAO, DESFAZER_EXCLUSAO, DESCRICAO_SQL, USUARIO_CRIACAO)
SELECT c.TABELA, c.DESFAZER, c.LIXEIRA, c.BLOQUEADOS, c.UNICOS, c.FILHAS, c.INCLUSAO, c.EXCLUSAO, c.DESCRICAO, N'instalacao'
FROM #CargaConfig c
WHERE OBJECT_ID(c.TABELA, N'U') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config t WHERE t.TABELA = c.TABELA);

UPDATE t
   SET t.PERMITE_DESFAZER = c.DESFAZER, t.PERMITE_LIXEIRA = c.LIXEIRA, t.CAMPOS_BLOQUEADOS = c.BLOQUEADOS, t.CAMPOS_UNICOS = c.UNICOS,
       t.TABELAS_FILHAS = c.FILHAS, t.DESFAZER_INCLUSAO = c.INCLUSAO, t.DESFAZER_EXCLUSAO = c.EXCLUSAO, t.DESCRICAO_SQL = c.DESCRICAO,
       t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Tabela_Config t
INNER JOIN #CargaConfig c ON c.TABELA = t.TABELA
WHERE t.PERMITE_DESFAZER <> c.DESFAZER OR t.PERMITE_LIXEIRA <> c.LIXEIRA OR t.CAMPOS_BLOQUEADOS <> c.BLOQUEADOS OR t.CAMPOS_UNICOS <> c.UNICOS
   OR t.TABELAS_FILHAS <> c.FILHAS OR t.DESFAZER_INCLUSAO <> c.INCLUSAO OR t.DESFAZER_EXCLUSAO <> c.EXCLUSAO OR t.DESCRICAO_SQL <> c.DESCRICAO;

DROP TABLE IF EXISTS #CargaConfig;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT 'LIXEIRA_AVISO', N'Aviso da lixeira', N'Recebem o aviso diário do que será apagado de vez da lixeira (Sistema › Lixeira).', N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = 'LIXEIRA_AVISO');

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, N'construtora.m.judice@gmail.com', N'Administração do sistema', N'instalacao'
FROM SIS.Grupo_Email g
WHERE g.CODIGO = 'LIXEIRA_AVISO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL);
GO

PRINT N'Pacote 04d concluído sem erro.';
GO

SET NOEXEC OFF;
GO
