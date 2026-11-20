/*******************************************************************************
  Objeto      : tabelas da transformação do movimento (schema MIG)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Etapa 03c2, parte B.
                MIG.Caso                 documentos do Access (unidades: lote,
                                         venda ou avulso) que não se encaixam em
                                         nenhuma regra, mais os que já têm
                                         correção da tela (REGRA_ATUAL mostra
                                         como ficaram; MOTIVO_ORIGINAL guarda o
                                         motivo da primeira vez). Atualizada a
                                         cada rodada.
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
    v1.1 (18/11/2026) - Tela de casos: MIG.Caso ganha REGRA_ATUAL e
                        MOTIVO_ORIGINAL; tabelas de correção ganham chave
                        numérica (ID) e campos padrão de criação/alteração, para
                        a auditoria (SIS.Auditoria) registrar quem corrigiu o
                        quê; Caso_Correcao_Linha ganha UNIDADE. As tabelas de
                        correção vazias no formato antigo são refeitas.
    v1.2 (18/11/2026) - Aviso de mudança no Access: HASH_ACCESS nas correções
                        (impressão digital da linha ou do documento no momento
                        da correção) e MIG.Caso.REVISAR (texto do aviso quando
                        o Access mudou ou apagou o que foi corrigido).
    v1.3 (18/11/2026) - Caso_Correcao_Linha.LOTE: troca do lote da linha pela
                        tela (0 = sai do lote; NULL = mantém o do Access).
    v1.4 (20/11/2026) - Etapa 03d (instalação no servidor): teste do formato
                        antigo de Caso_Correcao/_Linha com IF aninhado; em banco
                        novo o SELECT na tabela ainda inexistente dava erro 208.

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
IF COL_LENGTH(N'MIG.Caso', N'REGRA_ATUAL') IS NULL
    ALTER TABLE [MIG].[Caso] ADD REGRA_ATUAL VARCHAR(15) NOT NULL CONSTRAINT DF_Caso_REGRA_ATUAL DEFAULT ('CASO');
GO
IF COL_LENGTH(N'MIG.Caso', N'MOTIVO_ORIGINAL') IS NULL
    ALTER TABLE [MIG].[Caso] ADD MOTIVO_ORIGINAL NVARCHAR(400) NOT NULL CONSTRAINT DF_Caso_MOTIVO_ORIGINAL DEFAULT (N'');
GO

-- formato antigo (sem ID) e vazio: refaz (a auditoria precisa de chave numérica)
-- (IF aninhado: o SELECT só é compilado quando a tabela existe; banco novo não dá erro)
IF OBJECT_ID(N'[MIG].[Caso_Correcao]', N'U') IS NOT NULL AND COL_LENGTH(N'MIG.Caso_Correcao', N'ID_CASO_CORRECAO') IS NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao)
        DROP TABLE [MIG].[Caso_Correcao];
END;
IF OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]', N'U') IS NOT NULL AND COL_LENGTH(N'MIG.Caso_Correcao_Linha', N'ID_CASO_CORRECAO_LINHA') IS NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha)
        DROP TABLE [MIG].[Caso_Correcao_Linha];
END;
GO

IF OBJECT_ID(N'[MIG].[Caso_Correcao]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso_Correcao]
    (
        ID_CASO_CORRECAO   INT            IDENTITY(1,1) NOT NULL CONSTRAINT PK_Caso_Correcao PRIMARY KEY,
        UNIDADE            VARCHAR(40)    NOT NULL,
        ACAO               VARCHAR(15)    NOT NULL,
        MOTIVO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_Correcao_MOTIVO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_Correcao_DT_CRIACAO DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL,
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT UQ_Caso_Correcao_UNIDADE UNIQUE (UNIDADE),
        CONSTRAINT CK_Caso_Correcao_ACAO CHECK (ACAO IN ('IGNORAR', 'ARQUIVO_MORTO'))
    );
GO

IF OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso_Correcao_Linha]
    (
        ID_CASO_CORRECAO_LINHA INT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_Caso_Correcao_Linha PRIMARY KEY,
        ORIGEM             VARCHAR(20)    NOT NULL,
        NUM                INT            NOT NULL,
        UNIDADE            VARCHAR(40)    NOT NULL,
        EMP_VINCULADA      INT            NULL,       -- NULL = mantém o valor do Access
        PARCEIRO           INT            NULL,
        CONTA              INT            NULL,
        PLANO3             INT            NULL,
        DT_MOVTO           DATE           NULL,
        DT_VENCTO          DATE           NULL,
        DT_PAGTO           DATE           NULL,
        VALOR_DEBITO       DECIMAL(18,2)  NULL,
        VALOR_CREDITO      DECIMAL(18,2)  NULL,
        CONFIRMADO         BIT            NULL,
        IGNORAR_LINHA      BIT            NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_IGN    DEFAULT (0),
        MOTIVO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_MOTIVO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_DT_CRIACAO DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL,
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT UQ_Caso_Correcao_Linha UNIQUE (ORIGEM, NUM),
        CONSTRAINT CK_Caso_Correcao_Linha_VALOR CHECK (ISNULL(VALOR_DEBITO, 0) >= 0 AND ISNULL(VALOR_CREDITO, 0) >= 0)
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]') AND name = N'IX_Caso_Correcao_Linha_UNIDADE')
    CREATE NONCLUSTERED INDEX IX_Caso_Correcao_Linha_UNIDADE ON [MIG].[Caso_Correcao_Linha] (UNIDADE);
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

IF COL_LENGTH(N'MIG.Caso', N'REVISAR') IS NULL
    ALTER TABLE [MIG].[Caso] ADD REVISAR NVARCHAR(400) NOT NULL CONSTRAINT DF_Caso_REVISAR DEFAULT (N'');
IF COL_LENGTH(N'MIG.Caso_Correcao', N'HASH_ACCESS') IS NULL
    ALTER TABLE [MIG].[Caso_Correcao] ADD HASH_ACCESS VARBINARY(32) NULL;
IF COL_LENGTH(N'MIG.Caso_Correcao_Linha', N'HASH_ACCESS') IS NULL
    ALTER TABLE [MIG].[Caso_Correcao_Linha] ADD HASH_ACCESS VARBINARY(32) NULL;
IF COL_LENGTH(N'MIG.Caso_Correcao_Linha', N'LOTE') IS NULL
    ALTER TABLE [MIG].[Caso_Correcao_Linha] ADD LOTE INT NULL CONSTRAINT CK_Caso_Correcao_Linha_LOTE CHECK (LOTE >= 0);
GO

-- busca de linha do Access pelo código (tela de casos e migração); MIG_Movimento_Preparar também cria
IF OBJECT_ID(N'[MIG].[Movimento]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[MIG].[Movimento]') AND name = N'IX_MIG_Movimento_ORIGEM_NUM')
    CREATE INDEX IX_MIG_Movimento_ORIGEM_NUM ON MIG.Movimento (ORIGEM, NUM) INCLUDE (UNIDADE, DESTINO, LINK_VENDA, LOTE);
GO

-- auditoria das correções feitas pela tela (quem, quando, antes e depois)
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'MIG.Caso_Correcao',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'MIG.Caso_Correcao_Linha', @Criar = 1;
GO
