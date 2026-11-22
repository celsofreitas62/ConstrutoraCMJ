/*******************************************************************************
  Objeto      : tabelas de classificação e de-para dos cadastros (schema MIG)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Migração dos cadastros do Access (etapa 03c2).
                Tabelas de CLASSIFICAÇÃO (decisões, preenchidas pela carga
                Carga_MIG_Classificacao.sql e conferidas pela CMJ; o que não
                estiver nelas segue a regra automática da procedure e aparece
                na conferência):
                  MIG.Classif_Empresa      EmpMaster -> empresa do grupo ou não
                  MIG.Classif_Centro       EmpVinculada -> centro de custo
                  MIG.Classif_Centro_Extra centros que não existem no Access
                                           (imóveis próprios, decisão do plano)
                  MIG.Classif_Conta        F Contas Financeiras -> BANCO.Conta
                  MIG.Config_Plano_Grupo   grupos do plano (número, nome, tipo,
                                           custo de obra; grupos de histórico)
                  MIG.DePara_Plano_Excecao contas do plano que mudam de lugar
                                           (plano antigo usado desde o corte,
                                           receitas, não operacional)
                Tabelas de DE-PARA (resultado, refeitas a cada carga, usadas
                na transformação do movimento):
                  MIG.DePara_Centro        EmpVinculada -> centro, empresa, cliente
                  MIG.DePara_Plano         Plano3 -> conta do plano (+ centro do imóvel)
                Pessoas, empresas, contas e históricos: pela coluna
                CODIGO_ACCESS das próprias tabelas.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).
    v1.1 (22/11/2026) - 03f (respostas da CMJ ao 3º documento):
                        Classif_Centro.CODIGO_CONTA_PADRAO (conta padrão do
                        centro decidida pela CMJ, no lugar da do Access) e
                        Classif_Centro_Extra.ATIVO (NULL = regra automática;
                        0/1 = decisão da CMJ, ex.: imóvel vendido).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'MIG') IS NULL EXEC (N'CREATE SCHEMA [MIG] AUTHORIZATION [dbo];');
GO

IF OBJECT_ID(N'[MIG].[Classif_Empresa]', N'U') IS NULL
    CREATE TABLE [MIG].[Classif_Empresa]
    (
        CODIGO_MASTER     INT            NOT NULL CONSTRAINT PK_Classif_Empresa PRIMARY KEY,
        DESTINO           VARCHAR(12)    NOT NULL,          -- EMPRESA / CONSTRUTORA (obras ficam na empresa principal) / NAO_MIGRA
        PRINCIPAL         BIT            NOT NULL CONSTRAINT DF_Classif_Empresa_PRINCIPAL DEFAULT (0),
        TIPO              VARCHAR(12)    NOT NULL CONSTRAINT DF_Classif_Empresa_TIPO      DEFAULT ('OUTRA'),
        RAZAO_SOCIAL      NVARCHAR(150)  NOT NULL CONSTRAINT DF_Classif_Empresa_RAZAO     DEFAULT (N''),
        NOME_FANTASIA     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Classif_Empresa_FANTASIA  DEFAULT (N''),
        CNPJ              VARCHAR(14)    NOT NULL CONSTRAINT DF_Classif_Empresa_CNPJ      DEFAULT (''),
        CNPJ_COMPRAS      VARCHAR(14)    NOT NULL CONSTRAINT DF_Classif_Empresa_CNPJ_COMP DEFAULT (''),
        REGIME_TRIBUTARIO VARCHAR(20)    NOT NULL CONSTRAINT DF_Classif_Empresa_REGIME    DEFAULT (''),
        OBSERVACAO        NVARCHAR(400)  NOT NULL CONSTRAINT DF_Classif_Empresa_OBS       DEFAULT (N''),
        CONSTRAINT CK_Classif_Empresa_DESTINO CHECK (DESTINO IN ('EMPRESA', 'CONSTRUTORA', 'NAO_MIGRA'))
    );
GO

IF OBJECT_ID(N'[MIG].[Classif_Centro]', N'U') IS NULL
    CREATE TABLE [MIG].[Classif_Centro]
    (
        CODIGO_VINCULADA       INT            NOT NULL CONSTRAINT PK_Classif_Centro PRIMARY KEY,
        DESTINO                VARCHAR(10)    NOT NULL,      -- CENTRO / NAO_MIGRA
        CODIGO                 VARCHAR(20)    NOT NULL CONSTRAINT DF_Classif_Centro_CODIGO DEFAULT (''),
        DESCRICAO              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Classif_Centro_DESC   DEFAULT (N''),
        TIPO                   VARCHAR(15)    NOT NULL CONSTRAINT DF_Classif_Centro_TIPO   DEFAULT (''),
        CODIGO_MASTER_EMPRESA  INT            NULL,          -- dona do centro; NULL = regra (empresa do EmpMaster ou a principal)
        PARCEIRO_CLIENTE       INT            NULL,          -- cliente da obra por administração (código do Parceiros)
        CODIGO_CONTA_PADRAO    INT            NULL,          -- conta padrão (código do F Contas Financeiras); NULL = a do Access
        OBSERVACAO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Classif_Centro_OBS    DEFAULT (N''),
        CONSTRAINT CK_Classif_Centro_DESTINO CHECK (DESTINO IN ('CENTRO', 'NAO_MIGRA')),
        CONSTRAINT CK_Classif_Centro_TIPO    CHECK (TIPO IN ('', 'OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR'))
    );
GO

IF OBJECT_ID(N'[MIG].[Classif_Centro_Extra]', N'U') IS NULL
    CREATE TABLE [MIG].[Classif_Centro_Extra]
    (
        CODIGO                 VARCHAR(20)    NOT NULL CONSTRAINT PK_Classif_Centro_Extra PRIMARY KEY,
        DESCRICAO              NVARCHAR(100)  NOT NULL,
        TIPO                   VARCHAR(15)    NOT NULL,
        CODIGO_MASTER_EMPRESA  INT            NOT NULL,
        CONTABIL               BIT            NOT NULL CONSTRAINT DF_Classif_Centro_Extra_CONTABIL DEFAULT (1),
        ATIVO                  BIT            NULL,          -- NULL = regra (ativo se usado); 0/1 = decisão da CMJ
        OBSERVACAO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Classif_Centro_Extra_OBS      DEFAULT (N''),
        CONSTRAINT CK_Classif_Centro_Extra_TIPO CHECK (TIPO IN ('OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR'))
    );
GO

-- v1.1 (03f): colunas novas em tabela já existente
IF COL_LENGTH(N'MIG.Classif_Centro', N'CODIGO_CONTA_PADRAO') IS NULL
    ALTER TABLE [MIG].[Classif_Centro] ADD CODIGO_CONTA_PADRAO INT NULL;
GO
IF COL_LENGTH(N'MIG.Classif_Centro_Extra', N'ATIVO') IS NULL
    ALTER TABLE [MIG].[Classif_Centro_Extra] ADD ATIVO BIT NULL;
GO

IF OBJECT_ID(N'[MIG].[Classif_Conta]', N'U') IS NULL
    CREATE TABLE [MIG].[Classif_Conta]
    (
        CODIGO_CONTA           INT            NOT NULL CONSTRAINT PK_Classif_Conta PRIMARY KEY,
        DESTINO                VARCHAR(10)    NOT NULL,      -- CONTA / NAO_MIGRA
        CODIGO_MASTER_EMPRESA  INT            NULL,
        DESCRICAO              NVARCHAR(60)   NOT NULL CONSTRAINT DF_Classif_Conta_DESC    DEFAULT (N''),
        TIPO                   VARCHAR(10)    NOT NULL CONSTRAINT DF_Classif_Conta_TIPO    DEFAULT (''),
        BANCO_CODIGO           CHAR(3)        NULL,
        AGENCIA                VARCHAR(10)    NOT NULL CONSTRAINT DF_Classif_Conta_AGENCIA DEFAULT (''),
        NUMERO                 VARCHAR(20)    NOT NULL CONSTRAINT DF_Classif_Conta_NUMERO  DEFAULT (''),
        NUMERO_DV              VARCHAR(2)     NOT NULL CONSTRAINT DF_Classif_Conta_DV      DEFAULT (''),
        OBSERVACAO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Classif_Conta_OBS     DEFAULT (N''),
        CONSTRAINT CK_Classif_Conta_DESTINO CHECK (DESTINO IN ('CONTA', 'NAO_MIGRA')),
        CONSTRAINT CK_Classif_Conta_TIPO    CHECK (TIPO IN ('', 'CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA'))
    );
GO

IF OBJECT_ID(N'[MIG].[Config_Plano_Grupo]', N'U') IS NULL
    CREATE TABLE [MIG].[Config_Plano_Grupo]
    (
        NUMERO         SMALLINT       NOT NULL CONSTRAINT PK_Config_Plano_Grupo PRIMARY KEY,
        DESCRICAO      NVARCHAR(80)   NOT NULL,
        TIPO           VARCHAR(15)    NOT NULL,
        CUSTO_OBRA     BIT            NOT NULL CONSTRAINT DF_Config_Plano_Grupo_CUSTO DEFAULT (0),
        ATIVO          BIT            NOT NULL CONSTRAINT DF_Config_Plano_Grupo_ATIVO DEFAULT (1),
        PLANO1_ACCESS  INT            NULL,      -- grupo do plano ANTIGO que vira este grupo de histórico (inativo)
        CONSTRAINT CK_Config_Plano_Grupo_TIPO CHECK (TIPO IN ('RECEITA', 'DESPESA', 'NAO_OPERACIONAL'))
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Plano_Excecao]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Plano_Excecao]
    (
        PLANO3_ACCESS       INT            NOT NULL CONSTRAINT PK_DePara_Plano_Excecao PRIMARY KEY,
        ALVO_PLANO3_ACCESS  INT            NULL,       -- vai para a conta nova que veio deste Plano3 do Access, ou:
        GRUPO_NUMERO        SMALLINT       NULL,       -- ... para a conta abaixo (criada se não existir)
        SUBGRUPO_NUMERO     SMALLINT       NULL,
        SUBGRUPO_DESCRICAO  NVARCHAR(80)   NOT NULL CONSTRAINT DF_DePara_Plano_Excecao_SUB   DEFAULT (N''),
        CONTA_NUMERO        SMALLINT       NULL,
        CONTA_DESCRICAO     NVARCHAR(80)   NOT NULL CONSTRAINT DF_DePara_Plano_Excecao_CONTA DEFAULT (N''),
        CENTRO_CODIGO       VARCHAR(20)    NULL,       -- centro de custo do imóvel (Classif_Centro_Extra)
        OBSERVACAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_DePara_Plano_Excecao_OBS   DEFAULT (N''),
        CONSTRAINT CK_DePara_Plano_Excecao_ALVO CHECK (ALVO_PLANO3_ACCESS IS NOT NULL
                                                    OR (GRUPO_NUMERO IS NOT NULL AND SUBGRUPO_NUMERO IS NOT NULL AND CONTA_NUMERO IS NOT NULL
                                                        AND SUBGRUPO_DESCRICAO <> N'' AND CONTA_DESCRICAO <> N''))
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Centro]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Centro]
    (
        CODIGO_VINCULADA    INT            NOT NULL CONSTRAINT PK_DePara_Centro PRIMARY KEY,
        ID_CENTRO_CUSTO     INT            NOT NULL,
        ID_EMPRESA          INT            NOT NULL,
        ID_PESSOA_CLIENTE   INT            NULL,
        PERCENTUAL_ADM      DECIMAL(9,4)   NOT NULL CONSTRAINT DF_DePara_Centro_PERC DEFAULT (0),
        ID_CONTA_PADRAO     INT            NULL,
        CLASSIF_AUTOMATICA  BIT            NOT NULL CONSTRAINT DF_DePara_Centro_AUTO DEFAULT (0)
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Plano]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Plano]
    (
        PLANO3_ACCESS       INT            NOT NULL CONSTRAINT PK_DePara_Plano PRIMARY KEY,
        ID_PLANO_CONTA      INT            NOT NULL,
        ID_CENTRO_CUSTO     INT            NULL,       -- imóvel próprio identificado pela conta antiga
        REGRA               VARCHAR(12)    NOT NULL    -- NOVO / HISTORICO / EXCECAO / DUPLICADA
    );
GO
