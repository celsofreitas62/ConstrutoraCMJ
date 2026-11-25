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
-- Arquivo: sql/objetos/SIS/Carga_SIS_Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros de fábrica da base SIS. Só insere o que falta
                (PADRAO_SQL regra 39): valor já alterado pelo administrador
                nunca é sobrescrito. VALOR_PADRAO recebe o mesmo valor de
                fábrica. Cada etapa seguinte acrescenta os seus parâmetros
                (multa, juros, régua de cobrança...) neste arquivo.
                EDITAVEL_ADMIN = 0: só o instalador muda, por script.
                Depende de Carga_SIS_Modulo.sql.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: SENHA_PBKDF2_ITERACOES.
    v1.2 (15/11/2026) - Identidade visual por cliente: pasta, logomarcas e
                        cores (valores de fábrica = CMJ).
    v1.3 (16/11/2026) - Etapa 02d: e-mail (domínio interno, minutos preso),
                        pastas de backup e de atualizações.
    v1.4 (17/11/2026) - Etapa 03c: EMAIL_LOCAL_LIBERADOS (exceção controlada do
                        banco de teste, pedido do Celso) e SISTEMA_NOME
                        (nome do sistema por cliente, pedido do Celso: SisCMJ);
                        EMAIL_LOGO_MODO, EMAIL_LOGO_ENDERECO e
                        EMAIL_LOGO_NOME_ARQUIVO (como a logomarca vai no e-mail).
    v1.5 (20/11/2026) - Etapa 03d: EMAIL_RODAPE_CNPJ (CNPJ no rodapé dos e-mails
                        a clientes e terceiros; fábrica N, pedido do Celso).
    v1.6 (20/11/2026) - Etapa 03d: LOGIN_COMPUTADOR_TENTATIVAS e
                        LOGIN_COMPUTADOR_MINUTOS (limite de tentativas por computador).
    v1.7 (20/11/2026) - Etapa 03d: BACKUP_DIAS_MANTER, BACKUP_NUVEM_MANTER e os
                        avisos de atraso (BACKUP_HORAS_ALERTA_COMPLETO/_LOG,
                        BACKUP_DIAS_ALERTA_TESTE).
    v1.8 (20/11/2026) - Etapa 03d2: BACKUP_RESTAURACAO_MOTIVO_MINIMO (restauração
                        pela tela).
    v1.9 (22/11/2026) - Etapa 04a: SENHA_PROVISORIA_PADRAO e SENHA_PROVISORIA_HORAS
                        (botão Reiniciar senha da tela de Usuários; decisão do
                        Celso de 16/11/2026, PADRAO_TELAS regra 13).
    v2.0 (22/11/2026) - Etapa 04b (P20): LIXEIRA_ATIVA, LIXEIRA_DIAS_GUARDA (90),
                        LIXEIRA_AVISO_DIAS, LIXEIRA_AVISO_GRUPO e
                        LIXEIRA_LIMPEZA_ATIVA.
    v2.1 (23/11/2026) - Etapa 04c (P22): NOVIDADES_AVISO_ATIVO,
                        NOVIDADES_VERSOES_MAX (3), VERSAO_AVISO_EMAIL_ATIVO e
                        VERSAO_AVISO_GRUPO.
    v2.2 (25/11/2026) - Etapa 04d (P12, P10): PARCEIRO_ROTULO, PARCEIRO_ROTULO_PLURAL,
                        CEP_CONSULTA_ATIVA, CEP_URL_PRINCIPAL, CEP_URL_RESERVA,
                        CEP_CACHE_DIAS, CNPJ_CONSULTA_ATIVA, CNPJ_URL,
                        CONSULTA_TEMPO_LIMITE_SEG e COBRANCA_APTO_EXIGE_*.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN)
SELECT v.CHAVE, v.VALOR, v.VALOR, v.TIPO, v.DESCRICAO, m.ID_MODULO, v.EDITAVEL_ADMIN
FROM (VALUES
        (CAST('EMAIL_TESTE' AS VARCHAR(60)), CAST(N'celsofreitas62@gmail.com' AS NVARCHAR(4000)), CAST('EMAIL' AS VARCHAR(10)),
         CAST(N'Endereço que recebe TODOS os e-mails quando o sistema roda em modo teste (banco _LOCAL).' AS NVARCHAR(400)), CAST('SIS' AS VARCHAR(10)), CAST(0 AS BIT)),
        ('EMAIL_ADMIN_ALERTA', N'', 'EMAIL',
         N'Endereço que recebe os alertas técnicos (falha no envio de e-mail, rotina com erro). Vazio = sem alerta.', 'SIS', 1),
        ('EMAIL_TENTATIVAS_MAX', N'5', 'INTEIRO',
         N'Quantas vezes o serviço tenta reenviar um e-mail com falha temporária antes de desistir.', 'SIS', 1),
        ('SENHA_TAMANHO_MINIMO', N'8', 'INTEIRO',
         N'Quantidade mínima de caracteres da senha dos usuários.', 'SIS', 1),
        ('SENHA_TENTATIVAS_BLOQUEIO', N'5', 'INTEIRO',
         N'Tentativas de senha errada seguidas até o usuário ser bloqueado.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_TENTATIVAS', N'10', 'INTEIRO',
         N'Tentativas de login erradas seguidas, de um mesmo computador (com qualquer usuário), até ele ficar em espera. Mínimo 5.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_MINUTOS', N'15', 'INTEIRO',
         N'Minutos que o computador fica em espera depois de errar o login demais, e janela de contagem das tentativas.', 'SIS', 1),
        ('SESSAO_MINUTOS_INATIVIDADE', N'30', 'INTEIRO',
         N'Minutos sem uso até a sessão expirar e pedir login de novo.', 'SIS', 1),
        ('ANEXO_PASTA_RAIZ', N'C:\SistemaCMJ_Arquivos\Anexos', 'TEXTO',
         N'Pasta do servidor onde os anexos são gravados (o banco guarda só a referência).', 'SIS', 0),
        ('ANEXO_TAMANHO_MAX_MB', N'20', 'INTEIRO',
         N'Tamanho máximo de cada anexo, em MB.', 'SIS', 1),
        ('LOG_PASSO_DIAS_RETENCAO', N'90', 'INTEIRO',
         N'Dias que o log passo a passo das rotinas é guardado (mínimo 7). O log de erros não é apagado.', 'SIS', 1),
        ('SENHA_PBKDF2_ITERACOES', N'600000', 'INTEIRO',
         N'Iterações do PBKDF2-SHA256 usadas pela API ao gravar senha (mínimo aceito: 100000).', 'SIS', 0),
        ('IDENTIDADE_PASTA', N'C:\SistemaCMJ_Arquivos\Identidade', 'TEXTO',
         N'Pasta do servidor com os arquivos de identidade visual do cliente (logomarcas).', 'SIS', 0),
        ('EMPRESA_LOGO', N'logo.png', 'ARQUIVO',
         N'Logomarca vertical completa (documentos, contratos, telas grandes). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_HORIZONTAL', N'logo_horizontal.png', 'ARQUIVO',
         N'Logomarca horizontal (cabeçalho do sistema e dos relatórios). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_EMAIL', N'logo_email.png', 'ARQUIVO',
         N'Logomarca pequena do cabeçalho dos e-mails. Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_SIMBOLO', N'logo_simbolo.png', 'ARQUIVO',
         N'Só o símbolo da logomarca (menu recolhido, ícone). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_COR_PRINCIPAL', N'#D43414', 'COR',
         N'Cor principal do cliente: cabeçalhos do sistema, dos relatórios e dos e-mails informativos.', 'SIS', 1),
        ('EMPRESA_COR_SECUNDARIA', N'#A8A8A8', 'COR',
         N'Cor secundária do cliente (detalhes, linhas, textos de apoio).', 'SIS', 1),
        ('EMAIL_COR_ALERTA', N'#E65100', 'COR',
         N'Cor dos avisos de alerta (vencido, falha, divergência). Diferente da cor principal.', 'SIS', 1),
        ('EMAIL_COR_SUCESSO', N'#2E7D32', 'COR',
         N'Cor das confirmações (pagamento recebido, envio concluído).', 'SIS', 1),
        ('EMAIL_DOMINIO_INTERNO', N'', 'TEXTO',
         N'Domínio(s) do e-mail da empresa (ex.: cmj.com.br), separados por vírgula. Esses endereços saem pela conta interna; os demais pela externa. Vazio = todos pela interna.', 'SIS', 1),
        ('SISTEMA_NOME', N'SisCMJ', 'TEXTO',
         N'Nome do sistema mostrado nas telas, nos e-mails (rodapé e remetente) e nos relatórios. Só o administrador geral altera.', 'SIS', 0),
        ('EMAIL_LOGO_MODO', N'EMBUTIDA', 'TEXTO',
         N'Logomarca nos e-mails: EMBUTIDA (vai dentro do e-mail), ENDERECO (puxada do endereço público EMAIL_LOGO_ENDERECO, não aparece como anexo) ou SEM_IMAGEM (só a faixa colorida).', 'SIS', 0),
        ('EMAIL_LOGO_ENDERECO', N'', 'TEXTO',
         N'Endereço público (https://...) da logomarca, usado quando EMAIL_LOGO_MODO = ENDERECO.', 'SIS', 0),
        ('EMAIL_LOGO_NOME_ARQUIVO', N'CMJ.png', 'TEXTO',
         N'Nome com que a logomarca embutida aparece para quem recebe o e-mail (ex.: CMJ.png).', 'SIS', 0),
        ('EMAIL_LOCAL_LIBERADOS', N'', 'TEXTO',
         N'Só no banco de teste (_LOCAL): tipos de e-mail que saem para os destinatários reais em vez de irem para o EMAIL_TESTE, separados por vírgula (ex.: COMUNICADO). Vazio = todos desviados. Não tem efeito em produção.', 'SIS', 0),
        ('EMAIL_MINUTOS_PRESO', N'15', 'INTEIRO',
         N'Minutos que um e-mail pode ficar "processando" antes de voltar para a fila (serviço parou no meio). Mínimo 5.', 'SIS', 1),
        ('BACKUP_PASTA', N'C:\SistemaCMJ_Arquivos\Backup', 'TEXTO',
         N'Pasta do servidor onde ficam os backups do banco.', 'SIS', 0),
        ('BACKUP_PASTA_EXTERNA', N'', 'TEXTO',
         N'Pasta fora do servidor (disco externo ou pasta sincronizada com a nuvem) para onde os backups são copiados. Vazio = não copia.', 'SIS', 0),
        ('BACKUP_DIAS_MANTER', N'7', 'INTEIRO',
         N'Dias de backup guardados na pasta do servidor (completos e do log); os mais antigos são apagados.', 'SIS', 0),
        ('BACKUP_NUVEM_MANTER', N'1', 'INTEIRO',
         N'Quantos backups completos ficam na pasta da nuvem (BACKUP_PASTA_EXTERNA). 0 = não copia.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_COMPLETO', N'26', 'INTEIRO',
         N'Avisa por e-mail se o último backup completo sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_LOG', N'3', 'INTEIRO',
         N'Avisa por e-mail se o último backup do log (de hora em hora) sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_DIAS_ALERTA_TESTE', N'8', 'INTEIRO',
         N'Avisa por e-mail se o último teste de restauração sem erro tiver mais dias que isto.', 'SIS', 0),
        ('BACKUP_RESTAURACAO_MOTIVO_MINIMO', N'10', 'INTEIRO',
         N'Quantidade mínima de letras do motivo obrigatório ao pedir uma restauração de backup pela tela.', 'SIS', 0),
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('EMAIL_RODAPE_CNPJ', N'N', 'SN',
         N'Mostrar o CNPJ da empresa no rodapé dos e-mails enviados a clientes e terceiros (S/N).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1),
        ('SENHA_PROVISORIA_PADRAO', N'@12345', 'TEXTO',
         N'Senha provisória dada pelo botão Reiniciar senha da tela de Usuários. O usuário é obrigado a trocá-la no primeiro acesso.', 'SIS', 0),
        ('SENHA_PROVISORIA_HORAS', N'24', 'INTEIRO',
         N'Horas que a senha provisória vale. Passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar a senha de novo. 0 = não vence. Não vale para o administrador geral.', 'SIS', 1),
        ('LIXEIRA_ATIVA', N'S', 'SN',
         N'S = o botão Excluir das telas manda o registro para a lixeira (recuperável). N = a lixeira fica desligada e só é possível desativar.', 'SIS', 1),
        ('LIXEIRA_DIAS_GUARDA', N'90', 'INTEIRO',
         N'Dias que um registro excluído fica na lixeira antes de ser apagado de vez (mínimo 1). Cada tela pode ter prazo próprio na configuração das tabelas; vazio = vale este.', 'SIS', 1),
        ('LIXEIRA_AVISO_DIAS', N'1', 'INTEIRO',
         N'Com quantos dias de antecedência o e-mail avisa o que será apagado de vez da lixeira. 0 = sem aviso.', 'SIS', 1),
        ('LIXEIRA_AVISO_GRUPO', N'LIXEIRA_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe o aviso do que será apagado da lixeira (tela Grupos de e-mail).', 'SIS', 1),
        ('LIXEIRA_LIMPEZA_ATIVA', N'S', 'SN',
         N'S = a rotina diária apaga de vez o que passou do prazo da lixeira. N = nada é apagado (o aviso continua saindo).', 'SIS', 1),
        ('NOVIDADES_AVISO_ATIVO', N'S', 'SN',
         N'S = depois de cada atualização, cada usuário vê uma vez a janela "O que há de novo" com as notas da versão. N = não mostra (as notas continuam em Sistema › Versões).', 'SIS', 1),
        ('NOVIDADES_VERSOES_MAX', N'3', 'INTEIRO',
         N'Quantas versões, no máximo, a janela "O que há de novo" mostra de uma vez (as mais novas); as outras ficam em Sistema › Versões.', 'SIS', 1),
        ('VERSAO_AVISO_EMAIL_ATIVO', N'S', 'SN',
         N'S = cada atualização concluída manda a nota da versão por e-mail ao grupo do parâmetro VERSAO_AVISO_GRUPO. N = não manda.', 'SIS', 1),
        ('VERSAO_AVISO_GRUPO', N'VERSAO_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe a nota da versão depois de cada atualização (tela Grupos de e-mail).', 'SIS', 1),
        ('PARCEIRO_ROTULO', N'Parceiro', 'TEXTO',
         N'Nome do cadastro de pessoas nas telas e menus (singular). Ex.: Parceiro.', 'CAD', 0),
        ('PARCEIRO_ROTULO_PLURAL', N'Parceiros', 'TEXTO',
         N'Nome do cadastro de pessoas nas telas e menus (plural). Ex.: Parceiros.', 'CAD', 0),
        ('CEP_CONSULTA_ATIVA', N'S', 'SN',
         N'S = ao digitar o CEP, o servidor consulta o endereço na internet (ViaCEP; reserva BrasilAPI). N = digitação manual.', 'CAD', 1),
        ('CEP_URL_PRINCIPAL', N'https://viacep.com.br/ws/{cep}/json/', 'TEXTO',
         N'Endereço da consulta principal de CEP ({cep} = 8 dígitos). Formato de resposta do ViaCEP.', 'CAD', 0),
        ('CEP_URL_RESERVA', N'https://brasilapi.com.br/api/cep/v1/{cep}', 'TEXTO',
         N'Endereço da consulta de CEP usada quando a principal falha ({cep} = 8 dígitos). Formato da BrasilAPI. Vazio = sem reserva.', 'CAD', 0),
        ('CEP_CACHE_DIAS', N'180', 'INTEIRO',
         N'Dias que um endereço consultado fica guardado antes de consultar de novo na internet.', 'CAD', 1),
        ('CNPJ_CONSULTA_ATIVA', N'S', 'SN',
         N'S = ao digitar o CNPJ, o servidor consulta razão social, nome fantasia, endereço e situação na Receita (BrasilAPI). N = digitação manual.', 'CAD', 1),
        ('CNPJ_URL', N'https://brasilapi.com.br/api/cnpj/v1/{cnpj}', 'TEXTO',
         N'Endereço da consulta de CNPJ ({cnpj} = 14 caracteres). Formato da BrasilAPI.', 'CAD', 0),
        ('CONSULTA_TEMPO_LIMITE_SEG', N'8', 'INTEIRO',
         N'Segundos de espera de cada consulta na internet (CEP, CNPJ) antes de desistir e deixar digitar à mão.', 'CAD', 0),
        ('COBRANCA_APTO_EXIGE_DOCUMENTO', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige CPF ou CNPJ válido.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_ENDERECO', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige CEP, logradouro, número, bairro, cidade e UF.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_EMAIL', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige e-mail principal (ou de cobrança) válido.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_TELEFONE', N'N', 'SN',
         N'Cadastro apto para cobrança (boleto): exige celular ou telefone.', 'CAD', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Pessoa_Pendencia_Cobranca.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Pessoa_Pendencia_Cobranca]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : P10 - cadastro apto para cobrança (boleto). Devolve uma linha
                com APTO (1/0) e PENDENCIA (texto do que falta, separado por
                "; "; vazio = apto). Exigências em parâmetros
                COBRANCA_APTO_EXIGE_DOCUMENTO / _ENDERECO / _EMAIL / _TELEFONE.
                E-mail: contato ativo principal ou de finalidade COBRANCA, com
                formato válido. Usada pela lista e ficha de Parceiros (aviso)
                e, na fase 6, pela trava da emissão do boleto.
                Função em linha (sem custo por linha nas listas).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).

  Homologação (LOCAL):
    -- SELECT p.ID_PESSOA, f.* FROM CAD.Pessoa p CROSS APPLY CAD.fn_CAD_Pessoa_Pendencia_Cobranca(p.ID_PESSOA) f WHERE f.APTO = 0;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Pessoa_Pendencia_Cobranca] (@IdPessoa INT)
RETURNS TABLE
AS
RETURN
(
    SELECT CASE WHEN x.PENDENCIA = N'' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS APTO,
           x.PENDENCIA
    FROM (
        SELECT CONCAT_WS(N'; ',
                 CASE WHEN SIS.fn_SIS_Parametro_SN('COBRANCA_APTO_EXIGE_DOCUMENTO') = 1
                           AND (p.CPF_CNPJ = '' OR CAD.fn_CAD_Documento_Valido(p.CPF_CNPJ) = 0
                                OR LEN(p.CPF_CNPJ) <> CASE p.TIPO_PESSOA WHEN 'F' THEN 11 ELSE 14 END)
                      THEN CASE p.TIPO_PESSOA WHEN 'F' THEN N'CPF ausente ou inválido' ELSE N'CNPJ ausente ou inválido' END END,
                 CASE WHEN SIS.fn_SIS_Parametro_SN('COBRANCA_APTO_EXIGE_ENDERECO') = 1
                           AND (LEN(p.CEP) <> 8 OR p.LOGRADOURO = N'' OR p.NUMERO = N'' OR p.BAIRRO = N'' OR p.CIDADE = N'' OR LEN(p.UF) <> 2)
                      THEN N'endereço incompleto (CEP, logradouro, número, bairro, cidade e UF)' END,
                 CASE WHEN SIS.fn_SIS_Parametro_SN('COBRANCA_APTO_EXIGE_EMAIL') = 1
                           AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c
                                           WHERE c.ID_PESSOA = p.ID_PESSOA AND c.ATIVO = 1 AND c.TIPO = 'EMAIL'
                                             AND (c.PRINCIPAL = 1 OR c.FINALIDADE = 'COBRANCA')
                                             AND c.VALOR LIKE N'_%@_%._%' AND c.VALOR NOT LIKE N'% %' AND c.VALOR NOT LIKE N'%@%@%')
                      THEN N'sem e-mail principal ou de cobrança válido' END,
                 CASE WHEN SIS.fn_SIS_Parametro_SN('COBRANCA_APTO_EXIGE_TELEFONE') = 1
                           AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c
                                           WHERE c.ID_PESSOA = p.ID_PESSOA AND c.ATIVO = 1 AND c.TIPO IN ('CELULAR', 'TELEFONE', 'WHATSAPP'))
                      THEN N'sem telefone' END) AS PENDENCIA
        FROM CAD.Pessoa p
        WHERE p.ID_PESSOA = @IdPessoa
    ) x
);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Parceiro_Tipo_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Parceiro_Tipo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Lista os tipos de parceiro (tela Tipos de parceiro e filtros
                das telas de Parceiros), com a quantidade de parceiros ativos
                de cada tipo. Não mostra o que está na lixeira.
                Permissão: VER em CAD_PARCEIRO_TIPO ou em CAD_PESSOA (a ficha do
                parceiro precisa da lista para marcar os tipos).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Parceiro_Tipo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Parceiro_Tipo_Listar]
    @IdUsuario      INT,
    @Busca          NVARCHAR(60) = NULL,
    @SomenteAtivos  BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PARCEIRO_TIPO', 'VER') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
    BEGIN
        SELECT TOP (0) CAST(NULL AS INT) AS ID_PARCEIRO_TIPO;
        RETURN;
    END;

    SET @Busca = NULLIF(LTRIM(RTRIM(ISNULL(@Busca, N''))), N'');

    SELECT t.ID_PARCEIRO_TIPO, t.CODIGO, t.DESCRICAO, t.SISTEMA, t.ORDEM, t.ATIVO,
           ISNULL(q.QTD, 0) AS QTD_PARCEIROS
    FROM CAD.Parceiro_Tipo t
    OUTER APPLY (SELECT COUNT(*) AS QTD
                 FROM CAD.Pessoa_Tipo x
                 INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = x.ID_PESSOA AND p.ATIVO = 1
                 WHERE x.ID_PARCEIRO_TIPO = t.ID_PARCEIRO_TIPO AND x.ATIVO = 1) q
    WHERE t.DT_EXCLUSAO IS NULL
      AND (@SomenteAtivos = 0 OR t.ATIVO = 1)
      AND (@Busca IS NULL OR t.DESCRICAO LIKE N'%' + @Busca + N'%' OR t.CODIGO LIKE @Busca + '%')
    ORDER BY t.ORDEM, t.DESCRICAO;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Parceiro_Tipo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Parceiro_Tipo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Inclui (@IdParceiroTipo NULL) ou altera um tipo de parceiro.
                Código: letras, números e "_" (maiúsculas), único. Tipos do
                sistema (SISTEMA = 1): só a descrição e a ordem mudam (código e
                situação não). Desativar um tipo em uso: avisa quantos
                parceiros têm o tipo (eles continuam com ele).
                Permissão: INCLUIR ou ALTERAR em CAD_PARCEIRO_TIPO (desativar
                ou reativar: DESATIVAR). Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Parceiro_Tipo_Gravar @IdUsuario = 2, @Codigo = 'EMPREITEIRO', @Descricao = N'Empreiteiro';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Parceiro_Tipo_Gravar]
    @IdUsuario        INT,
    @IdParceiroTipo   INT           = NULL,
    @Codigo           VARCHAR(20),
    @Descricao        NVARCHAR(60),
    @Ordem            INT           = NULL,
    @Ativo            BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Parceiro_Tipo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @Sistema    BIT           = 0;
    DECLARE @CodigoAtual VARCHAR(20);
    DECLARE @AtivoAtual BIT;
    DECLARE @EmUso      INT           = 0;

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Ativo     = ISNULL(@Ativo, 1);

        SELECT @Sistema = t.SISTEMA, @CodigoAtual = t.CODIGO, @AtivoAtual = t.ATIVO
        FROM CAD.Parceiro_Tipo t WHERE t.ID_PARCEIRO_TIPO = @IdParceiroTipo;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PARCEIRO_TIPO', CASE WHEN @IdParceiroTipo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar tipos de parceiro.';
        IF @Recusa = N'' AND @IdParceiroTipo IS NOT NULL AND @CodigoAtual IS NULL
            SET @Recusa = N'Tipo de parceiro não encontrado.';
        IF @Recusa = N'' AND @IdParceiroTipo IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Parceiro_Tipo', @IdParceiroTipo) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @Sistema = 1 AND @Codigo <> @CodigoAtual
            SET @Recusa = N'O código de um tipo do sistema não pode ser mudado (só a descrição e a ordem).';
        IF @Recusa = N'' AND @Sistema = 1 AND @Ativo = 0
            SET @Recusa = N'Um tipo do sistema não pode ser desativado.';
        IF @Recusa = N'' AND (@Codigo = '' OR @Codigo LIKE '%[^A-Z0-9_]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras sem acento, números e "_" (ex.: EMPREITEIRO).';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = @Codigo AND t.ID_PARCEIRO_TIPO <> ISNULL(@IdParceiroTipo, 0))
            SET @Recusa = N'Já existe um tipo de parceiro com este código (confira também a lixeira).';
        IF @Recusa = N'' AND @IdParceiroTipo IS NOT NULL AND @Ativo <> @AtivoAtual
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PARCEIRO_TIPO', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar tipos de parceiro.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdParceiroTipo AS ID;
            RETURN;
        END;

        IF @IdParceiroTipo IS NOT NULL AND @Ativo = 0 AND @AtivoAtual = 1
            SELECT @EmUso = COUNT(*) FROM CAD.Pessoa_Tipo x WHERE x.ID_PARCEIRO_TIPO = @IdParceiroTipo AND x.ATIVO = 1;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdParceiroTipo IS NULL
        BEGIN
            INSERT INTO CAD.Parceiro_Tipo (CODIGO, DESCRICAO, SISTEMA, ORDEM, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Descricao, 0, ISNULL(@Ordem, 100), @Ativo, @Usuario);
            SET @IdParceiroTipo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE CAD.Parceiro_Tipo
               SET CODIGO = @Codigo, DESCRICAO = @Descricao, ORDEM = ISNULL(@Ordem, ORDEM), ATIVO = @Ativo,
                   DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
             WHERE ID_PARCEIRO_TIPO = @IdParceiroTipo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Tipo de parceiro gravado.'
                    + CASE WHEN @EmUso > 0 THEN N' Atenção: ' + CONVERT(NVARCHAR(10), @EmUso)
                                + N' parceiro(s) continuam com este tipo; ele só não aparece mais para novas marcações.' ELSE N'' END
                    AS NVARCHAR(400)) AS MENSAGEM,
               @IdParceiroTipo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o tipo de parceiro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdParceiroTipo AS ID;
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
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira e escolher registro ligado que está na lixeira.
    v1.2 (25/11/2026) - Etapa 04d (P12, P17): @Tipos (JSON [2,6] com os ID_PARCEIRO_TIPO; NULL = tipos
                        do sistema pelas marcas @Cliente.. + os outros tipos que o parceiro já tem);
                        sem tipo = N/A; N/A some quando há outro tipo; as marcas CLIENTE/FORNECEDOR/
                        FUNCIONARIO/CORRETOR são acertadas pelos tipos do sistema. Contato com
                        "finalidade" (COBRANCA, COMPRAS, FINANCEIRO); contatos retirados são desativados
                        antes de gravar os demais (um só principal ativo por tipo). @IdPlanoContaPadrao e
                        @IdCentroCustoPadrao (NULL = não mexe, 0 = limpa).

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
    @DadosBancarios      NVARCHAR(MAX)  = NULL,
    @Tipos               NVARCHAR(MAX)  = NULL,
    @IdPlanoContaPadrao  INT            = NULL,
    @IdCentroCustoPadrao INT            = NULL
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
    DECLARE @Cont  TABLE (LINHA INT, ID INT, TIPO VARCHAR(20), VALOR NVARCHAR(256), NOME NVARCHAR(80), PRINCIPAL BIT, RECEBE BIT, FINALIDADE VARCHAR(20));
    DECLARE @Tip   TABLE (ID INT PRIMARY KEY, CODIGO VARCHAR(20), SISTEMA BIT);
    DECLARE @IdNA  INT = (SELECT t.ID_PARCEIRO_TIPO FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = 'NA');
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
        IF @Recusa = N'' AND @IdPessoa IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Pessoa', @IdPessoa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
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
        IF @Recusa = N'' AND @Tipos IS NOT NULL AND ISJSON(@Tipos) = 0
            SET @Recusa = N'Lista de tipos de parceiro em formato inválido.';
        IF @Recusa = N'' AND ISNULL(@IdPlanoContaPadrao, 0) > 0
           AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @IdPlanoContaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'Conta do plano padrão não encontrada ou inativa.';
        IF @Recusa = N'' AND ISNULL(@IdCentroCustoPadrao, 0) > 0
           AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCentroCustoPadrao AND c.ATIVO = 1)
            SET @Recusa = N'Centro de custo padrão não encontrado ou inativo.';

        -- Tipos de parceiro (P12): lista informada, ou marcas antigas + outros tipos que já tem
        IF @Recusa = N''
        BEGIN
            IF @Tipos IS NOT NULL
                INSERT INTO @Tip (ID, CODIGO, SISTEMA)
                SELECT DISTINCT t.ID_PARCEIRO_TIPO, t.CODIGO, t.SISTEMA
                FROM OPENJSON(@Tipos) k
                INNER JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = TRY_CONVERT(INT, k.value)
                WHERE t.DT_EXCLUSAO IS NULL
                  AND (t.ATIVO = 1 OR EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = ISNULL(@IdPessoa, 0)
                                                AND x.ID_PARCEIRO_TIPO = t.ID_PARCEIRO_TIPO AND x.ATIVO = 1));
            ELSE
            BEGIN
                INSERT INTO @Tip (ID, CODIGO, SISTEMA)
                SELECT t.ID_PARCEIRO_TIPO, t.CODIGO, t.SISTEMA
                FROM (VALUES ('CLIENTE', @Cliente), ('FORNECEDOR', @Fornecedor), ('FUNCIONARIO', @Funcionario), ('CORRETOR', @Corretor)) m (CODIGO, MARCA)
                INNER JOIN CAD.Parceiro_Tipo t ON t.CODIGO = m.CODIGO
                WHERE m.MARCA = 1;
                INSERT INTO @Tip (ID, CODIGO, SISTEMA)
                SELECT t.ID_PARCEIRO_TIPO, t.CODIGO, t.SISTEMA
                FROM CAD.Pessoa_Tipo x
                INNER JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO
                WHERE x.ID_PESSOA = ISNULL(@IdPessoa, 0) AND x.ATIVO = 1
                  AND t.CODIGO NOT IN ('CLIENTE', 'FORNECEDOR', 'FUNCIONARIO', 'CORRETOR', 'NA');
            END;

            IF @Tipos IS NOT NULL AND (SELECT COUNT(*) FROM @Tip) <> (SELECT COUNT(DISTINCT k.value) FROM OPENJSON(@Tipos) k)
                SET @Recusa = N'Tipo de parceiro não encontrado, inativo ou na lixeira. Atualize a tela e marque de novo.';

            IF EXISTS (SELECT 1 FROM @Tip WHERE CODIGO <> 'NA') DELETE FROM @Tip WHERE CODIGO = 'NA';
            IF NOT EXISTS (SELECT 1 FROM @Tip) INSERT INTO @Tip (ID, CODIGO, SISTEMA) VALUES (@IdNA, 'NA', 1);

            SELECT @Cliente     = CASE WHEN EXISTS (SELECT 1 FROM @Tip WHERE CODIGO = 'CLIENTE')     THEN 1 ELSE 0 END,
                   @Fornecedor  = CASE WHEN EXISTS (SELECT 1 FROM @Tip WHERE CODIGO = 'FORNECEDOR')  THEN 1 ELSE 0 END,
                   @Funcionario = CASE WHEN EXISTS (SELECT 1 FROM @Tip WHERE CODIGO = 'FUNCIONARIO') THEN 1 ELSE 0 END,
                   @Corretor    = CASE WHEN EXISTS (SELECT 1 FROM @Tip WHERE CODIGO = 'CORRETOR')    THEN 1 ELSE 0 END;
        END;
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
            INSERT INTO @Cont (LINHA, ID, TIPO, VALOR, NOME, PRINCIPAL, RECEBE, FINALIDADE)
            SELECT CONVERT(INT, k.[key]) + 1, j.id, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), LTRIM(RTRIM(ISNULL(j.valor, N''))),
                   LTRIM(RTRIM(ISNULL(j.nome, N''))), ISNULL(j.principal, 0), ISNULL(j.recebeCobranca, 0), UPPER(LTRIM(RTRIM(ISNULL(j.finalidade, ''))))
            FROM OPENJSON(@Contatos) k
            CROSS APPLY OPENJSON(k.value) WITH (id INT '$.id', tipo VARCHAR(20) '$.tipo', valor NVARCHAR(256) '$.valor',
                                               nome NVARCHAR(80) '$.nome', principal BIT '$.principal', recebeCobranca BIT '$.recebeCobranca',
                                               finalidade VARCHAR(20) '$.finalidade') j
            WHERE k.[type] = 5;

            UPDATE c SET c.VALOR = CASE WHEN c.TIPO = 'EMAIL' THEN LOWER(c.VALOR) ELSE CONVERT(NVARCHAR(256), CAD.fn_CAD_Somente_Digitos(c.VALOR)) END
            FROM @Cont c;

            SELECT TOP 1 @Recusa = N'Contato ' + CONVERT(NVARCHAR(5), c.LINHA) + N': ' +
                   CASE WHEN c.TIPO NOT IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP') THEN N'tipo inválido (e-mail, celular, telefone ou WhatsApp).'
                        WHEN c.TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(c.VALOR) = 0 THEN N'e-mail inválido.'
                        WHEN c.TIPO <> 'EMAIL' AND LEN(c.VALOR) NOT BETWEEN 10 AND 13 THEN N'telefone inválido (informe DDD + número).'
                        WHEN c.FINALIDADE NOT IN ('', 'COBRANCA', 'COMPRAS', 'FINANCEIRO') THEN N'finalidade inválida (cobrança, compras ou financeiro).'
                        ELSE N'não pertence a esta pessoa.' END
            FROM @Cont c
            WHERE c.TIPO NOT IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP')
               OR (c.TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(c.VALOR) = 0)
               OR (c.TIPO <> 'EMAIL' AND LEN(c.VALOR) NOT BETWEEN 10 AND 13)
               OR c.FINALIDADE NOT IN ('', 'COBRANCA', 'COMPRAS', 'FINANCEIRO')
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
               OR NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = v.ID_VINCULADA AND p.DT_EXCLUSAO IS NULL)
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
                                    BAIRRO, CIDADE, UF, CLIENTE, FORNECEDOR, FUNCIONARIO, CORRETOR, OBSERVACAO,
                                    ID_PLANO_CONTA_PADRAO, ID_CENTRO_CUSTO_PADRAO, USUARIO_CRIACAO)
            VALUES (@TipoPessoa, @Nome, @NomeFantasia, @CpfCnpj, @Rg, @OrgaoEmissor, @InscricaoEstadual, @InscricaoMunicipal,
                    @DtNascimento, @Nacionalidade, @Profissao, @EstadoCivil, @RegimeBens, @Cep, @Logradouro, @Numero, @Complemento,
                    @Bairro, @Cidade, @Uf, @Cliente, @Fornecedor, @Funcionario, @Corretor, @Observacao,
                    NULLIF(@IdPlanoContaPadrao, 0), NULLIF(@IdCentroCustoPadrao, 0), @Usuario);
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
                   p.ID_PLANO_CONTA_PADRAO  = CASE WHEN @IdPlanoContaPadrao  IS NULL THEN p.ID_PLANO_CONTA_PADRAO  ELSE NULLIF(@IdPlanoContaPadrao, 0)  END,
                   p.ID_CENTRO_CUSTO_PADRAO = CASE WHEN @IdCentroCustoPadrao IS NULL THEN p.ID_CENTRO_CUSTO_PADRAO ELSE NULLIF(@IdCentroCustoPadrao, 0) END,
                   p.DT_ALTERACAO = @Agora, p.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa p
            WHERE p.ID_PESSOA = @IdPessoa;

        SET @EtapaAtual = 'Gravação dos tipos';
        UPDATE x SET x.ATIVO = 0, x.DT_ALTERACAO = @Agora, x.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Pessoa_Tipo x
        WHERE x.ID_PESSOA = @IdPessoa AND x.ATIVO = 1 AND NOT EXISTS (SELECT 1 FROM @Tip t WHERE t.ID = x.ID_PARCEIRO_TIPO);
        UPDATE x SET x.ATIVO = 1, x.DT_ALTERACAO = @Agora, x.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Pessoa_Tipo x
        INNER JOIN @Tip t ON t.ID = x.ID_PARCEIRO_TIPO
        WHERE x.ID_PESSOA = @IdPessoa AND x.ATIVO = 0;
        INSERT INTO CAD.Pessoa_Tipo (ID_PESSOA, ID_PARCEIRO_TIPO, USUARIO_CRIACAO)
        SELECT @IdPessoa, t.ID, @Usuario
        FROM @Tip t
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WHERE x.ID_PESSOA = @IdPessoa AND x.ID_PARCEIRO_TIPO = t.ID);

        -- Listas: NULL = não mexe; informada = fica igual à lista (o que saiu é desativado, não apagado)
        IF @Contatos IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos contatos';
            -- primeiro os retirados (um só principal ativo por tipo: índice único)
            UPDATE pc
               SET pc.ATIVO = 0, pc.PRINCIPAL = 0, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            WHERE pc.ID_PESSOA = @IdPessoa AND pc.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Cont c WHERE c.ID = pc.ID_PESSOA_CONTATO);
            UPDATE pc
               SET pc.TIPO = c.TIPO, pc.VALOR = c.VALOR, pc.NOME_CONTATO = c.NOME, pc.PRINCIPAL = c.PRINCIPAL, pc.RECEBE_COBRANCA = c.RECEBE, pc.FINALIDADE = c.FINALIDADE,
                   pc.ATIVO = 1, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            INNER JOIN @Cont c ON c.ID = pc.ID_PESSOA_CONTATO
            WHERE pc.ID_PESSOA = @IdPessoa;

            UPDATE pc
               SET pc.ATIVO = 0, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            WHERE pc.ID_PESSOA = @IdPessoa AND pc.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Cont c WHERE c.ID = pc.ID_PESSOA_CONTATO);

            INSERT INTO CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR, NOME_CONTATO, PRINCIPAL, RECEBE_COBRANCA, FINALIDADE, USUARIO_CRIACAO)
            SELECT @IdPessoa, c.TIPO, c.VALOR, c.NOME, c.PRINCIPAL, c.RECEBE, c.FINALIDADE, @Usuario
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
    v1.1 (22/11/2026) - Etapa 04b (P20): ações DESATIVAR (o antigo Excluir) e
                        DESFAZER nas telas de cadastro; DESATIVAR nasce com
                        quem já tinha EXCLUIR (perfil e exceção do usuário),
                        porque até aqui o Excluir só desativava.
    v1.2 (25/11/2026) - Etapa 04d (P12): tela CAD_PARCEIRO_TIPO (Tipos de
                        parceiro) e CAD.Pessoa_Tipo nas tabelas da tela CAD_PESSOA.
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
        ('CAD',   'CAD_PESSOA',       N'Pessoas',          'cad/pessoas.html',        20, 'CAD.Pessoa,CAD.Pessoa_Contato,CAD.Pessoa_Vinculo,CAD.Pessoa_Dado_Bancario,CAD.Pessoa_Tipo'),
        ('CAD',   'CAD_PARCEIRO_TIPO', N'Tipos de parceiro', 'cad/parceiro-tipos.html', 25, 'CAD.Parceiro_Tipo'),
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
        ('BANCO_BANCO', 'VER'), ('BANCO_BANCO', 'INCLUIR'), ('BANCO_BANCO', 'ALTERAR'), ('BANCO_BANCO', 'EXPORTAR'),
        ('CAD_PARCEIRO_TIPO', 'VER'), ('CAD_PARCEIRO_TIPO', 'INCLUIR'), ('CAD_PARCEIRO_TIPO', 'ALTERAR'), ('CAD_PARCEIRO_TIPO', 'EXCLUIR'),
        ('CAD_PARCEIRO_TIPO', 'DESATIVAR'), ('CAD_PARCEIRO_TIPO', 'EXPORTAR'), ('CAD_PARCEIRO_TIPO', 'DESFAZER')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

DECLARE @NovosDesativar TABLE (ID_ITEM_ACAO INT NOT NULL, ID_ITEM INT NOT NULL);
DECLARE @IdExcluir INT = (SELECT a.ID_ACAO FROM SIS.Acao a WHERE a.CODIGO = 'EXCLUIR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, inserted.ID_ITEM INTO @NovosDesativar (ID_ITEM_ACAO, ID_ITEM)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('CAD_EMPRESA' AS VARCHAR(40))), ('CAD_PESSOA'), ('CAD_CENTRO_CUSTO'), ('CAD_PLANO_CONTA'), ('BANCO_CONTA')) v (ITEM)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = 'DESATIVAR'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

-- quem tinha EXCLUIR (que desativava) recebe DESATIVAR, só quando a ação nasce
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosDesativar n
INNER JOIN SIS.Item_Acao ie ON ie.ID_ITEM = n.ID_ITEM AND ie.ID_ACAO = @IdExcluir
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = ie.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosDesativar n
INNER JOIN SIS.Item_Acao ie ON ie.ID_ITEM = n.ID_ITEM AND ie.ID_ACAO = @IdExcluir
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = ie.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('CAD_EMPRESA' AS VARCHAR(40))), ('CAD_PESSOA'), ('CAD_CENTRO_CUSTO'), ('CAD_PLANO_CONTA'), ('BANCO_CONTA'), ('BANCO_BANCO')) v (ITEM)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = 'DESFAZER'
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
