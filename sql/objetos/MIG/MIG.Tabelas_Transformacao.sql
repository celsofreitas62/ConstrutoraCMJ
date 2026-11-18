/*******************************************************************************
  Objeto      : tabelas da transformação do movimento (schema MIG)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Etapa 03c2, parte B.
                MIG.Caso                 documentos do Access (unidades: lote,
                                         venda ou avulso) que não se encaixam em
                                         nenhuma regra; refeita a cada rodada.
                MIG.Caso_Correcao        decisão por documento, gravada pela
                                         tela de casos: IGNORAR (não migra) ou
                                         ARQUIVO_MORTO (vai para o arquivo morto).
                MIG.Caso_Correcao_Linha  correção por linha do Access (obra,
                                         pessoa, conta, plano, datas, valores,
                                         confirmado, ignorar a linha), aplicada a
                                         cada rodada antes da classificação.
                MIG.Linha_Destino        para cada linha do Access, o que ela
                                         virou no sistema novo (conferência).
                MIG.DePara_Venda         parcelas de venda: ligação com o imóvel
                                         e o contrato do Access (fase 5).
                As correções ficam guardadas pelo código do Access (origem +
                número), então valem em toda nova rodada até a virada.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[MIG].[Caso]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso]
    (
        UNIDADE        VARCHAR(40)    NOT NULL CONSTRAINT PK_Caso PRIMARY KEY,
        PADRAO         VARCHAR(200)   NOT NULL CONSTRAINT DF_Caso_PADRAO DEFAULT (''),
        MOTIVO         NVARCHAR(400)  NOT NULL,
        DETALHE        NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_DETALHE DEFAULT (N''),
        LINHAS         INT            NOT NULL,
        VALOR_DEBITO   DECIMAL(18,2)  NOT NULL,
        VALOR_CREDITO  DECIMAL(18,2)  NOT NULL,
        DT_DOCUMENTO   DATE           NULL,
        DT_CALCULO     DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_DT DEFAULT (SYSDATETIME())
    );
GO

IF COL_LENGTH(N'MIG.Caso', N'DETALHE') IS NULL
    ALTER TABLE [MIG].[Caso] ADD DETALHE NVARCHAR(400) NOT NULL CONSTRAINT DF_Caso_DETALHE DEFAULT (N'');
GO

IF OBJECT_ID(N'[MIG].[Caso_Correcao]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso_Correcao]
    (
        UNIDADE        VARCHAR(40)    NOT NULL CONSTRAINT PK_Caso_Correcao PRIMARY KEY,
        ACAO           VARCHAR(15)    NOT NULL,
        MOTIVO         NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_Correcao_MOTIVO  DEFAULT (N''),
        USUARIO        NVARCHAR(100)  NOT NULL CONSTRAINT DF_Caso_Correcao_USUARIO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_DECISAO     DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_Correcao_DT      DEFAULT (SYSDATETIME()),
        CONSTRAINT CK_Caso_Correcao_ACAO CHECK (ACAO IN ('IGNORAR', 'ARQUIVO_MORTO'))
    );
GO

IF OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso_Correcao_Linha]
    (
        ORIGEM         VARCHAR(20)    NOT NULL,
        NUM            INT            NOT NULL,
        EMP_VINCULADA  INT            NULL,
        PARCEIRO       INT            NULL,
        CONTA          INT            NULL,
        PLANO3         INT            NULL,
        DT_MOVTO       DATE           NULL,
        DT_VENCTO      DATE           NULL,
        DT_PAGTO       DATE           NULL,
        VALOR_DEBITO   DECIMAL(18,2)  NULL,
        VALOR_CREDITO  DECIMAL(18,2)  NULL,
        CONFIRMADO     BIT            NULL,
        IGNORAR_LINHA  BIT            NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_IGN     DEFAULT (0),
        MOTIVO         NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_MOTIVO  DEFAULT (N''),
        USUARIO        NVARCHAR(100)  NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_USUARIO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_DECISAO     DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_DT      DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Caso_Correcao_Linha PRIMARY KEY (ORIGEM, NUM),
        CONSTRAINT CK_Caso_Correcao_Linha_VALOR CHECK (ISNULL(VALOR_DEBITO, 0) >= 0 AND ISNULL(VALOR_CREDITO, 0) >= 0)
    );
GO

IF OBJECT_ID(N'[MIG].[Linha_Destino]', N'U') IS NULL
    CREATE TABLE [MIG].[Linha_Destino]
    (
        ORIGEM            VARCHAR(20)    NOT NULL,
        NUM               INT            NOT NULL,
        UNIDADE           VARCHAR(40)    NOT NULL,
        REGRA             VARCHAR(12)    NOT NULL,
        PAPEL             VARCHAR(15)    NOT NULL,     -- TITULO / PAGAMENTO / CONTRAPARTIDA / TRANSFERENCIA
        ID_LANCAMENTO     BIGINT         NULL,
        ID_MOVIMENTO      BIGINT         NULL,
        ID_TRANSFERENCIA  BIGINT         NULL,
        ID_CONTA          INT            NULL,
        VALOR             DECIMAL(18,2)  NOT NULL,
        CONSTRAINT PK_Linha_Destino PRIMARY KEY (ORIGEM, NUM)
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Venda]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Venda]
    (
        ID_LANCAMENTO  BIGINT         NOT NULL CONSTRAINT PK_DePara_Venda PRIMARY KEY,
        ORIGEM         VARCHAR(20)    NOT NULL,
        NUM            INT            NOT NULL,
        LINK_VENDA     INT            NOT NULL,
        IMOVEL         INT            NULL,
        PARCEIRO       INT            NULL,
        CONTRATO       VARCHAR(40)    NOT NULL,
        NUM_DOC        NVARCHAR(100)  NOT NULL
    );
GO
