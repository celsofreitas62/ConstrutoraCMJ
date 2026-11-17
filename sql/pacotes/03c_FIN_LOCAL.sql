/*******************************************************************************
  Pacote      : 03c - financeiro (FIN: lançamento, parcela, baixa, transferência, fechamento de mês, arquivo morto), movimento e extrato do BANCO, boletim semanal (comunicados)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 17/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 02d e 03a já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/FIN/03c_Homologacao_FIN.sql e depois
                03a e 02d, para conferir que nada quebrou.
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
-- Arquivo: sql/objetos/CAD/CAD.Empresa_Pasta_OFX.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Empresa].PASTA_OFX
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Pasta onde a empresa guarda os extratos OFX do banco (pedido do
                Celso, 17/11/2026). Caminho editável no cadastro da empresa; vazio =
                a empresa não importa OFX. A conta é identificada pelo conteúdo do
                arquivo (banco/agência/conta), não pelo nome.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'CAD.Empresa', N'PASTA_OFX') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD PASTA_OFX NVARCHAR(260) NOT NULL CONSTRAINT DF_Empresa_PASTA_OFX DEFAULT (N'');
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Historico_Padrao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Historico_Padrao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Históricos padrão do lançamento (Pgto efetuado, NF nº, Salário,
                impostos...). Ajudam a digitar e a filtrar; o texto livre continua
                no HISTORICO do lançamento.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Historico_Padrao]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Historico_Padrao]
    (
        ID_HISTORICO_PADRAO  INT            IDENTITY(1,1) NOT NULL,
        DESCRICAO            NVARCHAR(80)   NOT NULL,
        ATIVO                BIT            NOT NULL CONSTRAINT DF_Historico_Padrao_ATIVO DEFAULT (1),
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Historico_Padrao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Historico_Padrao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Historico_Padrao           PRIMARY KEY CLUSTERED (ID_HISTORICO_PADRAO),
        CONSTRAINT UQ_Historico_Padrao_DESCRICAO UNIQUE (DESCRICAO),
        CONSTRAINT CK_Historico_Padrao_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Mes_Fechado.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Mes_Fechado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Fechamento de mês por empresa (item 10 da seção 3.3 e pedido 10).
                Mês fechado bloqueia incluir, alterar, baixar e estornar só os
                lançamentos em conta do plano marcada como CONTABIL. Reabrir exige
                permissão e fica na auditoria. MES = primeiro dia do mês.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Mes_Fechado]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Mes_Fechado]
    (
        ID_MES_FECHADO     INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA         INT            NOT NULL,
        MES                DATE           NOT NULL,
        FECHADO            BIT            NOT NULL CONSTRAINT DF_Mes_Fechado_FECHADO DEFAULT (1),
        OBSERVACAO         NVARCHAR(400)  NOT NULL CONSTRAINT DF_Mes_Fechado_OBSERVACAO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Mes_Fechado_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Mes_Fechado_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Mes_Fechado          PRIMARY KEY CLUSTERED (ID_MES_FECHADO),
        CONSTRAINT UQ_Mes_Fechado_MES      UNIQUE (ID_EMPRESA, MES),
        CONSTRAINT FK_Mes_Fechado_Empresa  FOREIGN KEY (ID_EMPRESA) REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT CK_Mes_Fechado_MES      CHECK (DAY(MES) = 1)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.Extrato_Arquivo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[Extrato_Arquivo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Cada arquivo de extrato (OFX) importado. O HASH impede importar o
                mesmo arquivo duas vezes. Mês sem movimento não tem arquivo (não é
                erro). Pedido do Celso, 17/11/2026; leitura e tela na fase 4.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Extrato_Arquivo]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Extrato_Arquivo]
    (
        ID_EXTRATO_ARQUIVO  BIGINT         IDENTITY(1,1) NOT NULL,
        ID_CONTA            INT            NOT NULL,
        NOME_ARQUIVO        NVARCHAR(260)  NOT NULL,
        HASH_SHA256         VARCHAR(64)    NOT NULL,
        DT_INICIO           DATE           NULL,
        DT_FIM              DATE           NULL,
        SALDO_FINAL         DECIMAL(18,2)  NULL,
        QTD_LINHAS          INT            NOT NULL CONSTRAINT DF_Extrato_Arquivo_QTD_LINHAS DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Extrato_Arquivo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Extrato_Arquivo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Extrato_Arquivo       PRIMARY KEY CLUSTERED (ID_EXTRATO_ARQUIVO),
        CONSTRAINT UQ_Extrato_Arquivo_HASH  UNIQUE (HASH_SHA256),
        CONSTRAINT FK_Extrato_Arquivo_Conta FOREIGN KEY (ID_CONTA) REFERENCES [BANCO].[Conta] (ID_CONTA)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.Extrato_Linha.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[Extrato_Linha]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Linhas do extrato OFX. FITID (identificador do banco) é único
                por conta. VALOR: positivo entrou, negativo saiu. SITUACAO: PENDENTE
                (sem par no sistema), CONCILIADA (ligada a um BANCO.Movimento) ou
                IGNORADA (decisão do usuário).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Extrato_Linha]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Extrato_Linha]
    (
        ID_EXTRATO_LINHA    BIGINT         IDENTITY(1,1) NOT NULL,
        ID_EXTRATO_ARQUIVO  BIGINT         NOT NULL,
        ID_CONTA            INT            NOT NULL,
        FITID               VARCHAR(100)   NOT NULL,
        DT_LANCAMENTO       DATE           NOT NULL,
        VALOR               DECIMAL(18,2)  NOT NULL,
        TIPO_OFX            VARCHAR(20)    NOT NULL CONSTRAINT DF_Extrato_Linha_TIPO_OFX  DEFAULT (''),
        DOCUMENTO           NVARCHAR(40)   NOT NULL CONSTRAINT DF_Extrato_Linha_DOCUMENTO DEFAULT (N''),
        HISTORICO           NVARCHAR(255)  NOT NULL CONSTRAINT DF_Extrato_Linha_HISTORICO DEFAULT (N''),
        SITUACAO            VARCHAR(10)    NOT NULL CONSTRAINT DF_Extrato_Linha_SITUACAO  DEFAULT ('PENDENTE'),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Extrato_Linha_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Extrato_Linha_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Extrato_Linha          PRIMARY KEY CLUSTERED (ID_EXTRATO_LINHA),
        CONSTRAINT UQ_Extrato_Linha_FITID    UNIQUE (ID_CONTA, FITID),
        CONSTRAINT FK_Extrato_Linha_Arquivo  FOREIGN KEY (ID_EXTRATO_ARQUIVO) REFERENCES [BANCO].[Extrato_Arquivo] (ID_EXTRATO_ARQUIVO),
        CONSTRAINT FK_Extrato_Linha_Conta    FOREIGN KEY (ID_CONTA) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT CK_Extrato_Linha_SITUACAO CHECK (SITUACAO IN ('PENDENTE', 'CONCILIADA', 'IGNORADA'))
    );
    CREATE INDEX IX_Extrato_Linha_CONTA_DATA ON [BANCO].[Extrato_Linha] (ID_CONTA, DT_LANCAMENTO, SITUACAO);
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Transferencia.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Transferencia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Transferência entre contas (da mesma empresa ou entre empresas do
                grupo). Gera dois BANCO.Movimento (saída na origem, entrada no
                destino) com o mesmo ID_TRANSFERENCIA.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Transferencia]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Transferencia]
    (
        ID_TRANSFERENCIA    BIGINT         IDENTITY(1,1) NOT NULL,
        DT_TRANSFERENCIA    DATE           NOT NULL,
        ID_CONTA_ORIGEM     INT            NOT NULL,
        ID_CONTA_DESTINO    INT            NOT NULL,
        VALOR               DECIMAL(18,2)  NOT NULL,
        HISTORICO           NVARCHAR(200)  NOT NULL CONSTRAINT DF_Transferencia_HISTORICO DEFAULT (N''),
        SITUACAO            VARCHAR(10)    NOT NULL CONSTRAINT DF_Transferencia_SITUACAO  DEFAULT ('ATIVA'),
        ID_LOTE             BIGINT         NULL,
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Transferencia_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Transferencia_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Transferencia          PRIMARY KEY CLUSTERED (ID_TRANSFERENCIA),
        CONSTRAINT FK_Transferencia_Origem   FOREIGN KEY (ID_CONTA_ORIGEM)  REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Transferencia_Destino  FOREIGN KEY (ID_CONTA_DESTINO) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Transferencia_Lote     FOREIGN KEY (ID_LOTE) REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Transferencia_CONTAS   CHECK (ID_CONTA_ORIGEM <> ID_CONTA_DESTINO),
        CONSTRAINT CK_Transferencia_VALOR    CHECK (VALOR > 0),
        CONSTRAINT CK_Transferencia_SITUACAO CHECK (SITUACAO IN ('ATIVA', 'ESTORNADA'))
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.Movimento.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[Movimento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : O que passa em cada conta (banco, caixa, permuta). VALOR positivo
                entrou, negativo saiu. Gerado pelas rotinas (baixa, transferência,
                tarifa, ajuste, saldo inicial), nunca digitado solto. Um pagamento
                em lote (várias baixas) gera UM movimento pelo total, para bater com
                o extrato. CONCILIADO + ID_EXTRATO_LINHA: conciliação (fase 4).
                Saldo da conta = SALDO_INICIAL da conta + soma dos movimentos.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Movimento]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Movimento]
    (
        ID_MOVIMENTO        BIGINT         IDENTITY(1,1) NOT NULL,
        ID_CONTA            INT            NOT NULL,
        DT_MOVIMENTO        DATE           NOT NULL,
        VALOR               DECIMAL(18,2)  NOT NULL,
        TIPO                VARCHAR(15)    NOT NULL,
        HISTORICO           NVARCHAR(200)  NOT NULL CONSTRAINT DF_Movimento_HISTORICO  DEFAULT (N''),
        DOCUMENTO           NVARCHAR(40)   NOT NULL CONSTRAINT DF_Movimento_DOCUMENTO  DEFAULT (N''),
        ID_TRANSFERENCIA    BIGINT         NULL,
        CONCILIADO          BIT            NOT NULL CONSTRAINT DF_Movimento_CONCILIADO DEFAULT (0),
        ID_EXTRATO_LINHA    BIGINT         NULL,
        SITUACAO            VARCHAR(10)    NOT NULL CONSTRAINT DF_Movimento_SITUACAO   DEFAULT ('ATIVO'),
        ID_LOTE             BIGINT         NULL,
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Movimento_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Movimento_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Movimento               PRIMARY KEY CLUSTERED (ID_MOVIMENTO),
        CONSTRAINT FK_Movimento_Conta         FOREIGN KEY (ID_CONTA)         REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Movimento_Transferencia FOREIGN KEY (ID_TRANSFERENCIA) REFERENCES [FIN].[Transferencia] (ID_TRANSFERENCIA),
        CONSTRAINT FK_Movimento_Extrato_Linha FOREIGN KEY (ID_EXTRATO_LINHA) REFERENCES [BANCO].[Extrato_Linha] (ID_EXTRATO_LINHA),
        CONSTRAINT FK_Movimento_Lote          FOREIGN KEY (ID_LOTE)          REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Movimento_TIPO          CHECK (TIPO IN ('BAIXA', 'TRANSFERENCIA', 'TARIFA', 'AJUSTE', 'SALDO_INICIAL')),
        CONSTRAINT CK_Movimento_SITUACAO      CHECK (SITUACAO IN ('ATIVO', 'ESTORNADO')),
        CONSTRAINT CK_Movimento_CONCILIADO    CHECK (CONCILIADO = 0 OR ID_EXTRATO_LINHA IS NOT NULL)
    );
    CREATE INDEX IX_Movimento_CONTA_DATA ON [BANCO].[Movimento] (ID_CONTA, DT_MOVIMENTO) INCLUDE (VALOR, CONCILIADO, SITUACAO);
    CREATE INDEX IX_Movimento_LOTE       ON [BANCO].[Movimento] (ID_LOTE) WHERE ID_LOTE IS NOT NULL;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Lancamento.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Lancamento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : O documento: uma obrigação a pagar (P) ou a receber (R), lançada
                uma vez (modelo de lançamento único, seção 3.2). Parcelas em
                FIN.Parcela, pagamentos em FIN.Baixa. Empresa vem do centro de custo
                (a rotina de gravação confere). INTEGRACAO (respostas do Celso,
                17/11/2026): COMPLETA = contabilidade + custo + banco; SO_CONTABIL =
                só relatórios da contabilidade, sem banco nem custo; NENHUMA.
                PREVISAO: compromisso previsto, sem documento (fluxo projetado).
                ID_PEDIDO_COMPRA: FK ligada quando o COMP existir. CODIGO_ACCESS +
                ORIGEM_ACCESS: rastreio da migração.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Lancamento]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Lancamento]
    (
        ID_LANCAMENTO        BIGINT         IDENTITY(1,1) NOT NULL,
        TIPO                 CHAR(1)        NOT NULL,
        ID_EMPRESA           INT            NOT NULL,
        ID_CENTRO_CUSTO      INT            NULL,
        ID_PESSOA            INT            NULL,
        ID_PLANO_CONTA       INT            NULL,
        ID_HISTORICO_PADRAO  INT            NULL,
        DOCUMENTO            NVARCHAR(40)   NOT NULL CONSTRAINT DF_Lancamento_DOCUMENTO     DEFAULT (N''),
        DT_EMISSAO           DATE           NOT NULL,
        DT_COMPETENCIA       DATE           NOT NULL,
        HISTORICO            NVARCHAR(200)  NOT NULL CONSTRAINT DF_Lancamento_HISTORICO     DEFAULT (N''),
        OBSERVACAO           NVARCHAR(2000) NOT NULL CONSTRAINT DF_Lancamento_OBSERVACAO    DEFAULT (N''),
        VALOR_TOTAL          DECIMAL(18,2)  NOT NULL,
        ORIGEM               VARCHAR(15)    NOT NULL CONSTRAINT DF_Lancamento_ORIGEM        DEFAULT ('MANUAL'),
        ID_ORIGEM            BIGINT         NULL,
        ID_LOTE              BIGINT         NULL,
        SITUACAO             VARCHAR(10)    NOT NULL CONSTRAINT DF_Lancamento_SITUACAO      DEFAULT ('ATIVO'),
        PREVISAO             BIT            NOT NULL CONSTRAINT DF_Lancamento_PREVISAO      DEFAULT (0),
        INTEGRACAO           VARCHAR(12)    NOT NULL CONSTRAINT DF_Lancamento_INTEGRACAO    DEFAULT ('COMPLETA'),
        ID_PEDIDO_COMPRA     BIGINT         NULL,
        CODIGO_ACCESS        INT            NULL,
        ORIGEM_ACCESS        VARCHAR(20)    NOT NULL CONSTRAINT DF_Lancamento_ORIGEM_ACCESS DEFAULT (''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Lancamento_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lancamento_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lancamento               PRIMARY KEY CLUSTERED (ID_LANCAMENTO),
        CONSTRAINT FK_Lancamento_Empresa       FOREIGN KEY (ID_EMPRESA)          REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Lancamento_Centro_Custo  FOREIGN KEY (ID_CENTRO_CUSTO)     REFERENCES [CAD].[Centro_Custo] (ID_CENTRO_CUSTO),
        CONSTRAINT FK_Lancamento_Pessoa        FOREIGN KEY (ID_PESSOA)           REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Lancamento_Plano_Conta   FOREIGN KEY (ID_PLANO_CONTA)      REFERENCES [CAD].[Plano_Conta] (ID_PLANO_CONTA),
        CONSTRAINT FK_Lancamento_Historico     FOREIGN KEY (ID_HISTORICO_PADRAO) REFERENCES [FIN].[Historico_Padrao] (ID_HISTORICO_PADRAO),
        CONSTRAINT FK_Lancamento_Lote          FOREIGN KEY (ID_LOTE)             REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Lancamento_TIPO          CHECK (TIPO IN ('P', 'R')),
        CONSTRAINT CK_Lancamento_VALOR_TOTAL   CHECK (VALOR_TOTAL >= 0),
        CONSTRAINT CK_Lancamento_COMPETENCIA   CHECK (DAY(DT_COMPETENCIA) = 1),
        CONSTRAINT CK_Lancamento_ORIGEM        CHECK (ORIGEM IN ('MANUAL', 'VENDA', 'COMPRA', 'MEDICAO', 'RECORRENTE', 'CONCILIACAO', 'ACORDO', 'MIGRACAO')),
        CONSTRAINT CK_Lancamento_SITUACAO      CHECK (SITUACAO IN ('ATIVO', 'CANCELADO')),
        CONSTRAINT CK_Lancamento_INTEGRACAO    CHECK (INTEGRACAO IN ('COMPLETA', 'SO_CONTABIL', 'NENHUMA'))
    );
    CREATE INDEX IX_Lancamento_PESSOA       ON [FIN].[Lancamento] (ID_PESSOA) WHERE ID_PESSOA IS NOT NULL;
    CREATE INDEX IX_Lancamento_CENTRO_CUSTO ON [FIN].[Lancamento] (ID_CENTRO_CUSTO, DT_COMPETENCIA);
    CREATE INDEX IX_Lancamento_LOTE         ON [FIN].[Lancamento] (ID_LOTE) WHERE ID_LOTE IS NOT NULL;
    CREATE INDEX IX_Lancamento_ACCESS       ON [FIN].[Lancamento] (ORIGEM_ACCESS, CODIGO_ACCESS) WHERE CODIGO_ACCESS IS NOT NULL;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Parcela.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Parcela]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Um vencimento do lançamento. VALOR_BAIXADO é mantido pela trigger
                FIN.tg_FIN_Baixa_Saldo (soma do VALOR_PRINCIPAL das baixas, regra 9);
                SALDO = VALOR - VALOR_BAIXADO. SITUACAO: ABERTA, PARCIAL, PAGA (pela
                trigger) ou CANCELADA (pela rotina). ID_CONTA_PREVISTA: conta em que
                se espera pagar/receber (fluxo de caixa).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Parcela]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Parcela]
    (
        ID_PARCELA           BIGINT         IDENTITY(1,1) NOT NULL,
        ID_LANCAMENTO        BIGINT         NOT NULL,
        NUMERO               SMALLINT       NOT NULL,
        QTD_PARCELAS         SMALLINT       NOT NULL,
        DT_VENCIMENTO        DATE           NOT NULL,
        VALOR                DECIMAL(18,2)  NOT NULL,
        VALOR_BAIXADO        DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Parcela_VALOR_BAIXADO DEFAULT (0),
        SALDO                AS (CAST(VALOR - VALOR_BAIXADO AS DECIMAL(18,2))) PERSISTED,
        SITUACAO             VARCHAR(10)    NOT NULL CONSTRAINT DF_Parcela_SITUACAO      DEFAULT ('ABERTA'),
        ID_CONTA_PREVISTA    INT            NULL,
        ID_LOTE              BIGINT         NULL,
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Parcela_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Parcela_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Parcela                PRIMARY KEY CLUSTERED (ID_PARCELA),
        CONSTRAINT UQ_Parcela_NUMERO         UNIQUE (ID_LANCAMENTO, NUMERO),
        CONSTRAINT FK_Parcela_Lancamento     FOREIGN KEY (ID_LANCAMENTO)     REFERENCES [FIN].[Lancamento] (ID_LANCAMENTO),
        CONSTRAINT FK_Parcela_Conta_Prevista FOREIGN KEY (ID_CONTA_PREVISTA) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Parcela_Lote           FOREIGN KEY (ID_LOTE)           REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Parcela_NUMERO         CHECK (NUMERO >= 1 AND NUMERO <= QTD_PARCELAS),
        CONSTRAINT CK_Parcela_VALOR          CHECK (VALOR >= 0),
        CONSTRAINT CK_Parcela_SITUACAO       CHECK (SITUACAO IN ('ABERTA', 'PARCIAL', 'PAGA', 'CANCELADA'))
    );
    CREATE INDEX IX_Parcela_VENCIMENTO ON [FIN].[Parcela] (DT_VENCIMENTO, SITUACAO) INCLUDE (ID_LANCAMENTO, VALOR, VALOR_BAIXADO);
    CREATE INDEX IX_Parcela_LANCAMENTO ON [FIN].[Parcela] (ID_LANCAMENTO);
    CREATE INDEX IX_Parcela_LOTE       ON [FIN].[Parcela] (ID_LOTE) WHERE ID_LOTE IS NOT NULL;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Baixa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Baixa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Cada pagamento/recebimento (total ou parcial) de uma parcela.
                Um campo para cada valor (pedido 8). VALOR_PRINCIPAL = quanto da
                parcela foi quitado (abate o saldo). VALOR_LIQUIDO = o que passou na
                conta: principal + juros + multa + correção - desconto - abatimento
                - retenção (a TARIFA do banco gera movimento próprio). ID_MOVIMENTO:
                movimento bancário (um só para várias baixas do mesmo pagamento em
                lote). Estorno = nova baixa com valores negativos apontando para a
                original (ID_BAIXA_ESTORNADA); nada é apagado. COMPENSADO = 0:
                pago com cheque ainda não compensado (o "Efetuado" do Access).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Baixa]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Baixa]
    (
        ID_BAIXA             BIGINT         IDENTITY(1,1) NOT NULL,
        ID_PARCELA           BIGINT         NOT NULL,
        DT_PAGAMENTO         DATE           NOT NULL,
        ID_CONTA             INT            NOT NULL,
        FORMA                VARCHAR(12)    NOT NULL CONSTRAINT DF_Baixa_FORMA           DEFAULT ('OUTRA'),
        VALOR_PRINCIPAL      DECIMAL(18,2)  NOT NULL,
        JUROS                DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_JUROS           DEFAULT (0),
        MULTA                DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_MULTA           DEFAULT (0),
        CORRECAO             DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_CORRECAO        DEFAULT (0),
        DESCONTO             DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_DESCONTO        DEFAULT (0),
        ABATIMENTO           DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_ABATIMENTO      DEFAULT (0),
        TARIFA               DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_TARIFA          DEFAULT (0),
        RETENCAO             DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_RETENCAO        DEFAULT (0),
        VALOR_LIQUIDO        AS (CAST(VALOR_PRINCIPAL + JUROS + MULTA + CORRECAO - DESCONTO - ABATIMENTO - RETENCAO AS DECIMAL(18,2))) PERSISTED,
        ID_MOVIMENTO         BIGINT         NULL,
        COMPENSADO           BIT            NOT NULL CONSTRAINT DF_Baixa_COMPENSADO      DEFAULT (1),
        DT_COMPENSACAO       DATE           NULL,
        ID_BAIXA_ESTORNADA   BIGINT         NULL,
        OBSERVACAO           NVARCHAR(400)  NOT NULL CONSTRAINT DF_Baixa_OBSERVACAO      DEFAULT (N''),
        ID_LOTE              BIGINT         NULL,
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Baixa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Baixa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Baixa               PRIMARY KEY CLUSTERED (ID_BAIXA),
        CONSTRAINT FK_Baixa_Parcela       FOREIGN KEY (ID_PARCELA)         REFERENCES [FIN].[Parcela] (ID_PARCELA),
        CONSTRAINT FK_Baixa_Conta         FOREIGN KEY (ID_CONTA)           REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Baixa_Movimento     FOREIGN KEY (ID_MOVIMENTO)       REFERENCES [BANCO].[Movimento] (ID_MOVIMENTO),
        CONSTRAINT FK_Baixa_Estornada     FOREIGN KEY (ID_BAIXA_ESTORNADA) REFERENCES [FIN].[Baixa] (ID_BAIXA),
        CONSTRAINT FK_Baixa_Lote          FOREIGN KEY (ID_LOTE)            REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Baixa_FORMA         CHECK (FORMA IN ('PIX', 'BOLETO', 'TED', 'DOC', 'DEBITO', 'DINHEIRO', 'CHEQUE', 'PERMUTA', 'CARTAO', 'OUTRA')),
        CONSTRAINT CK_Baixa_SINAL         CHECK ((ID_BAIXA_ESTORNADA IS NULL AND VALOR_PRINCIPAL >= 0) OR (ID_BAIXA_ESTORNADA IS NOT NULL AND VALOR_PRINCIPAL <= 0)),
        CONSTRAINT CK_Baixa_COMPENSACAO   CHECK (COMPENSADO = 0 OR DT_COMPENSACAO IS NOT NULL OR FORMA <> 'CHEQUE')
    );
    CREATE INDEX IX_Baixa_PARCELA      ON [FIN].[Baixa] (ID_PARCELA);
    CREATE INDEX IX_Baixa_DATA         ON [FIN].[Baixa] (DT_PAGAMENTO, ID_CONTA);
    CREATE INDEX IX_Baixa_MOVIMENTO    ON [FIN].[Baixa] (ID_MOVIMENTO) WHERE ID_MOVIMENTO IS NOT NULL;
    CREATE UNIQUE INDEX UQ_Baixa_ESTORNO ON [FIN].[Baixa] (ID_BAIXA_ESTORNADA) WHERE ID_BAIXA_ESTORNADA IS NOT NULL;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Arquivo_Morto.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Arquivo_Morto]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Lançamentos antigos do Access (antes de 2018, decisão do Celso de
                16 e 17/11/2026), guardados como eram, já em texto legível, só para
                consulta (sem manutenção nenhuma). Sem FK para o modelo novo: o que
                mudar no cadastro novo não altera o passado; ID_PESSOA/ID_EMPRESA/
                ID_CONTA só ajudam a busca quando há de-para. Carga pela migração.
                Saldos de cada conta na data do corte: FIN.Arquivo_Morto_Saldo.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Arquivo_Morto]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Arquivo_Morto]
    (
        ID_ARQUIVO_MORTO    BIGINT         IDENTITY(1,1) NOT NULL,
        ORIGEM_ACCESS       VARCHAR(20)    NOT NULL,
        CODIGO_ACCESS       INT            NOT NULL,
        EMPRESA             NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_EMPRESA     DEFAULT (N''),
        OBRA                NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_OBRA        DEFAULT (N''),
        PESSOA              NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_PESSOA      DEFAULT (N''),
        CONTA               NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_CONTA       DEFAULT (N''),
        PLANO1              NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO1      DEFAULT (N''),
        PLANO2              NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO2      DEFAULT (N''),
        PLANO3              NVARCHAR(120)  NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO3      DEFAULT (N''),
        HISTORICO           NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_HISTORICO   DEFAULT (N''),
        COMPLEMENTO         NVARCHAR(255)  NOT NULL CONSTRAINT DF_Arquivo_Morto_COMPLEMENTO DEFAULT (N''),
        DOCUMENTO           NVARCHAR(60)   NOT NULL CONSTRAINT DF_Arquivo_Morto_DOCUMENTO   DEFAULT (N''),
        NOTA_FISCAL         NVARCHAR(60)   NOT NULL CONSTRAINT DF_Arquivo_Morto_NOTA_FISCAL DEFAULT (N''),
        IMOVEL              NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_IMOVEL      DEFAULT (N''),
        OBSERVACAO          NVARCHAR(2000) NOT NULL CONSTRAINT DF_Arquivo_Morto_OBSERVACAO  DEFAULT (N''),
        VALOR_DEBITO        DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Arquivo_Morto_DEBITO      DEFAULT (0),
        VALOR_CREDITO       DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Arquivo_Morto_CREDITO     DEFAULT (0),
        DT_MOVIMENTO        DATE           NULL,
        DT_VENCIMENTO       DATE           NULL,
        DT_PAGAMENTO        DATE           NULL,
        CONFIRMADO          BIT            NOT NULL CONSTRAINT DF_Arquivo_Morto_CONFIRMADO  DEFAULT (0),
        EFETUADO            BIT            NOT NULL CONSTRAINT DF_Arquivo_Morto_EFETUADO    DEFAULT (0),
        ID_EMPRESA          INT            NULL,
        ID_PESSOA           INT            NULL,
        ID_CONTA            INT            NULL,
        DT_CARGA            DATETIME2(0)   NOT NULL CONSTRAINT DF_Arquivo_Morto_DT_CARGA    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Arquivo_Morto        PRIMARY KEY CLUSTERED (ID_ARQUIVO_MORTO),
        CONSTRAINT UQ_Arquivo_Morto_ACCESS UNIQUE (ORIGEM_ACCESS, CODIGO_ACCESS)
    );
    CREATE INDEX IX_Arquivo_Morto_DATA   ON [FIN].[Arquivo_Morto] (DT_MOVIMENTO);
    CREATE INDEX IX_Arquivo_Morto_PESSOA ON [FIN].[Arquivo_Morto] (PESSOA);
END;
GO

IF OBJECT_ID(N'[FIN].[Arquivo_Morto_Saldo]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Arquivo_Morto_Saldo]
    (
        ID_ARQUIVO_MORTO_SALDO  INT            IDENTITY(1,1) NOT NULL,
        CONTA                   NVARCHAR(80)   NOT NULL,
        ID_CONTA                INT            NULL,
        DT_SALDO                DATE           NOT NULL,
        SALDO                   DECIMAL(18,2)  NOT NULL,
        DT_CARGA                DATETIME2(0)   NOT NULL CONSTRAINT DF_Arquivo_Morto_Saldo_DT_CARGA DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Arquivo_Morto_Saldo       PRIMARY KEY CLUSTERED (ID_ARQUIVO_MORTO_SALDO),
        CONSTRAINT UQ_Arquivo_Morto_Saldo_CONTA UNIQUE (CONTA, DT_SALDO)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Comunicado.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Comunicado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Comunicado periódico por e-mail (pedido do Celso, 17/11/2026). O
                primeiro é o BOLETIM_IMPLANTACAO (andamento da implantação). Depois
                da implantação, o mesmo mecanismo serve a outros comunicados da
                empresa, trocando só os itens. Destinatários oficiais e de
                aprovação em grupos de e-mail (SIS.Grupo_Email). EXIGE_APROVACAO:
                a rotina só manda a prévia; o envio oficial depende de alguém
                clicar em "Aprovar e enviar". INTRODUCAO: parágrafo de abertura.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado]
    (
        ID_COMUNICADO             INT            IDENTITY(1,1) NOT NULL,
        CODIGO                    VARCHAR(30)    NOT NULL,
        TITULO                    NVARCHAR(150)  NOT NULL,
        INTRODUCAO                NVARCHAR(1000) NOT NULL CONSTRAINT DF_Comunicado_INTRODUCAO      DEFAULT (N''),
        ID_GRUPO_EMAIL            INT            NOT NULL,
        ID_GRUPO_EMAIL_APROVACAO  INT            NOT NULL,
        EXIGE_APROVACAO           BIT            NOT NULL CONSTRAINT DF_Comunicado_EXIGE_APROVACAO DEFAULT (1),
        ATIVO                     BIT            NOT NULL CONSTRAINT DF_Comunicado_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado           PRIMARY KEY CLUSTERED (ID_COMUNICADO),
        CONSTRAINT UQ_Comunicado_CODIGO    UNIQUE (CODIGO),
        CONSTRAINT FK_Comunicado_Grupo     FOREIGN KEY (ID_GRUPO_EMAIL)           REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL),
        CONSTRAINT FK_Comunicado_Aprovacao FOREIGN KEY (ID_GRUPO_EMAIL_APROVACAO) REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL),
        CONSTRAINT CK_Comunicado_CODIGO    CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Comunicado_Item.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Comunicado_Item]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Itens do comunicado, em linguagem simples e sem dados técnicos,
                cada um numa seção: IMPLANTADO (em uso na CMJ), EM_TESTE e
                PROXIMA_FASE. O Claude atualiza no fim de cada fase; o Celso ajusta
                pela tela Comunicados.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado_Item]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado_Item]
    (
        ID_COMUNICADO_ITEM  INT            IDENTITY(1,1) NOT NULL,
        ID_COMUNICADO       INT            NOT NULL,
        SECAO               VARCHAR(15)    NOT NULL,
        TEXTO               NVARCHAR(300)  NOT NULL,
        ORDEM               SMALLINT       NOT NULL CONSTRAINT DF_Comunicado_Item_ORDEM DEFAULT (0),
        ATIVO               BIT            NOT NULL CONSTRAINT DF_Comunicado_Item_ATIVO DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_Item_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Item_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado_Item            PRIMARY KEY CLUSTERED (ID_COMUNICADO_ITEM),
        CONSTRAINT FK_Comunicado_Item_Comunicado FOREIGN KEY (ID_COMUNICADO) REFERENCES [SIS].[Comunicado] (ID_COMUNICADO),
        CONSTRAINT CK_Comunicado_Item_SECAO      CHECK (SECAO IN ('IMPLANTADO', 'EM_TESTE', 'PROXIMA_FASE')),
        CONSTRAINT CK_Comunicado_Item_TEXTO      CHECK (TEXTO <> N'')
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Comunicado_Edicao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Comunicado_Edicao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Cada edição semanal do comunicado: período (segunda a sexta),
                assunto e HTML montados na prévia. O e-mail oficial leva
                exatamente o que foi aprovado. SITUACAO: PREVIA (aguardando
                aprovação) -> ENVIADA, ou DESCARTADA (substituída por prévia nova ou
                descartada na tela). Uma edição ENVIADA por comunicado e semana.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado_Edicao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado_Edicao]
    (
        ID_COMUNICADO_EDICAO  BIGINT         IDENTITY(1,1) NOT NULL,
        ID_COMUNICADO         INT            NOT NULL,
        DT_INICIO             DATE           NOT NULL,
        DT_FIM                DATE           NOT NULL,
        ASSUNTO               NVARCHAR(400)  NOT NULL,
        CORPO_HTML            NVARCHAR(MAX)  NOT NULL,
        SITUACAO              VARCHAR(10)    NOT NULL CONSTRAINT DF_Comunicado_Edicao_SITUACAO DEFAULT ('PREVIA'),
        ID_EMAIL_PREVIA       BIGINT         NULL,
        ID_EMAIL_OFICIAL      BIGINT         NULL,
        DT_APROVACAO          DATETIME2(0)   NULL,
        USUARIO_APROVACAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Edicao_USUARIO_APROVACAO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_Edicao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Edicao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado_Edicao            PRIMARY KEY CLUSTERED (ID_COMUNICADO_EDICAO),
        CONSTRAINT FK_Comunicado_Edicao_Comunicado FOREIGN KEY (ID_COMUNICADO) REFERENCES [SIS].[Comunicado] (ID_COMUNICADO),
        CONSTRAINT CK_Comunicado_Edicao_SITUACAO   CHECK (SITUACAO IN ('PREVIA', 'ENVIADA', 'DESCARTADA')),
        CONSTRAINT CK_Comunicado_Edicao_PERIODO    CHECK (DT_FIM >= DT_INICIO)
    );
    CREATE UNIQUE INDEX UQ_Comunicado_Edicao_ENVIADA ON [SIS].[Comunicado_Edicao] (ID_COMUNICADO, DT_INICIO) WHERE SITUACAO = 'ENVIADA';
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Comunicado_Conteudo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Comunicado_Conteudo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Miolo HTML do comunicado (vai dentro da moldura de
                SIS.fn_SIS_Email_HTML): introdução + as três seções (Implantado, Em
                teste, Próxima fase) com os itens ativos em lista. Seção vazia mostra
                "Nada nesta semana." Texto escapado (PADRAO_EMAIL regra 12); cor dos
                títulos pelo parâmetro EMPRESA_COR_PRINCIPAL. Nunca devolve NULL.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Comunicado_Conteudo(1);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Comunicado_Conteudo] (@IdComunicado INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Cor     VARCHAR(7)    = ISNULL(NULLIF(SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL'), ''), '#333333');
    DECLARE @Intro   NVARCHAR(MAX) = N'';
    DECLARE @Html    NVARCHAR(MAX) = N'';

    SELECT @Intro = SIS.fn_SIS_Texto_HTML(ISNULL(c.INTRODUCAO, N''))
    FROM SIS.Comunicado c
    WHERE c.ID_COMUNICADO = @IdComunicado;

    IF ISNULL(@Intro, N'') <> N''
        SET @Html = N'<p style="margin:0 0 16px 0;">' + REPLACE(@Intro, NCHAR(10), N'<br>') + N'</p>';

    SET @Html = @Html + ISNULL((
        SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),
                   N'<div style="margin:0 0 16px 0;">'
                 + N'<div style="font-weight:bold;color:' + @Cor + N';border-bottom:2px solid ' + @Cor + N';padding-bottom:4px;margin-bottom:8px;">' + s.TITULO + N'</div>'
                 + ISNULL(l.LISTA, N'<div style="color:#777777;">Nada nesta semana.</div>')
                 + N'</div>'), N'') WITHIN GROUP (ORDER BY s.ORDEM)
        FROM (VALUES (CAST('IMPLANTADO' AS VARCHAR(15)), CAST(N'Implantado (em uso na empresa)' AS NVARCHAR(60)), 1),
                     ('EM_TESTE',     N'Em teste',      2),
                     ('PROXIMA_FASE', N'Próxima fase',  3)) s (SECAO, TITULO, ORDEM)
        OUTER APPLY (SELECT N'<ul style="margin:0;padding-left:20px;">'
                          + STRING_AGG(CONVERT(NVARCHAR(MAX), N'<li style="margin-bottom:4px;">' + SIS.fn_SIS_Texto_HTML(i.TEXTO) + N'</li>'), N'')
                            WITHIN GROUP (ORDER BY i.ORDEM, i.ID_COMUNICADO_ITEM)
                          + N'</ul>' AS LISTA
                     FROM SIS.Comunicado_Item i
                     WHERE i.ID_COMUNICADO = @IdComunicado AND i.SECAO = s.SECAO AND i.ATIVO = 1
                     HAVING COUNT(*) > 0) l
    ), N'');

    RETURN ISNULL(@Html, N'');
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Arquivo_Morto_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Arquivo_Morto_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Consulta do arquivo morto (só leitura): período, conta, busca por
                parte do texto (pessoa, obra, empresa, complemento, documento, nota
                ou plano) e valor exato. Permissão: VER em FIN_ARQUIVO_MORTO.
                Devolve até @Limite linhas, mais recentes primeiro.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Arquivo_Morto_Listar @IdUsuario = 2, @Busca = N'pintor', @DtInicio = '2010-01-01', @DtFim = '2010-12-31';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Arquivo_Morto_Listar]
    @IdUsuario  INT,
    @Busca      NVARCHAR(100) = NULL,
    @DtInicio   DATE          = NULL,
    @DtFim      DATE          = NULL,
    @Conta      NVARCHAR(80)  = NULL,
    @Limite     INT           = 1000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Arquivo_Morto_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Like       NVARCHAR(110);
    DECLARE @Valor      DECIMAL(18,2);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_ARQUIVO_MORTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para consultar o arquivo morto.', 1;

        SET @Busca  = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Conta  = LTRIM(RTRIM(ISNULL(@Conta, N'')));
        SET @Limite = CASE WHEN ISNULL(@Limite, 0) BETWEEN 1 AND 20000 THEN @Limite ELSE 1000 END;
        SET @Like   = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Valor  = TRY_CONVERT(DECIMAL(18,2), REPLACE(REPLACE(@Busca, N'.', N''), N',', N'.'));

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@Limite)
               a.ID_ARQUIVO_MORTO, a.DT_MOVIMENTO, a.DT_VENCIMENTO, a.DT_PAGAMENTO,
               a.EMPRESA, a.OBRA, a.PESSOA, a.CONTA, a.PLANO1, a.PLANO2, a.PLANO3,
               a.HISTORICO, a.COMPLEMENTO, a.DOCUMENTO, a.NOTA_FISCAL, a.IMOVEL,
               a.VALOR_DEBITO, a.VALOR_CREDITO, a.CONFIRMADO, a.ORIGEM_ACCESS, a.CODIGO_ACCESS
        FROM FIN.Arquivo_Morto a WITH (NOLOCK)
        WHERE (@DtInicio IS NULL OR a.DT_MOVIMENTO >= @DtInicio)
          AND (@DtFim    IS NULL OR a.DT_MOVIMENTO <= @DtFim)
          AND (@Conta = N'' OR a.CONTA = @Conta)
          AND (   @Busca = N''
               OR a.PESSOA LIKE @Like OR a.OBRA LIKE @Like OR a.EMPRESA LIKE @Like
               OR a.COMPLEMENTO LIKE @Like OR a.DOCUMENTO LIKE @Like OR a.NOTA_FISCAL LIKE @Like
               OR a.PLANO3 LIKE @Like OR a.HISTORICO LIKE @Like
               OR (@Valor IS NOT NULL AND (a.VALOR_DEBITO = @Valor OR a.VALOR_CREDITO = @Valor)))
        ORDER BY a.DT_MOVIMENTO DESC, a.ID_ARQUIVO_MORTO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível consultar o arquivo morto. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Previa_Gerar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Previa_Gerar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Monta a edição da semana (segunda a sexta da data de hoje) com os
                itens ativos e manda a PRÉVIA só para o grupo de aprovação. Prévias
                anteriores ainda pendentes viram DESCARTADA (não acumulam). Semana
                que já teve envio oficial: recusa. Chamada pela rotina (@IdUsuario
                NULL, sem conferir permissão) ou pelo botão "Gerar prévia agora"
                (permissão ENVIAR em SIS_COMUNICADO). Devolve SUCESSO, MENSAGEM, ID
                (ID = ID_COMUNICADO_EDICAO).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = 2, @IdComunicado = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Previa_Gerar]
    @IdUsuario     INT = NULL,
    @IdComunicado  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Previa_Gerar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Hoje       DATE          = CAST(SYSDATETIME() AS DATE);
    DECLARE @Inicio     DATE;
    DECLARE @Fim        DATE;
    DECLARE @Titulo     NVARCHAR(150);
    DECLARE @GrupoAprov VARCHAR(30);
    DECLARE @Para       NVARCHAR(MAX);
    DECLARE @Assunto    NVARCHAR(400);
    DECLARE @AssuntoPv  NVARCHAR(400);
    DECLARE @Conteudo   NVARCHAR(MAX);
    DECLARE @Corpo      NVARCHAR(MAX);
    DECLARE @CorpoPv    NVARCHAR(MAX);
    DECLARE @Aviso      NVARCHAR(MAX);
    DECLARE @IdEdicao   BIGINT;
    DECLARE @IdEmail    BIGINT;
    DECLARE @Chave      NVARCHAR(200);
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        -- segunda-feira da semana, sem depender de SET DATEFIRST (01/01/1900 foi segunda)
        SET @Inicio = DATEADD(DAY, -(DATEDIFF(DAY, '19000101', @Hoje) % 7), @Hoje);
        SET @Fim    = DATEADD(DAY, 4, @Inicio);

        IF @IdUsuario IS NOT NULL AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'ENVIAR') = 0
            SET @Recusa = N'Você não tem permissão para gerar a prévia do comunicado.';

        SELECT @Titulo = c.TITULO, @GrupoAprov = g.CODIGO
        FROM SIS.Comunicado c
        INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL_APROVACAO
        WHERE c.ID_COMUNICADO = @IdComunicado AND c.ATIVO = 1;

        IF @Recusa = N'' AND @Titulo IS NULL
            SET @Recusa = N'Comunicado não encontrado ou desligado.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM SIS.Comunicado_Edicao e
                                     WHERE e.ID_COMUNICADO = @IdComunicado AND e.DT_INICIO = @Inicio AND e.SITUACAO = 'ENVIADA')
            SET @Recusa = N'O comunicado desta semana já foi enviado.';
        SET @Para = ISNULL(SIS.fn_SIS_Emails_Do_Grupo(@GrupoAprov), N'');
        IF @Recusa = N'' AND @Para = N''
            SET @Recusa = N'O grupo de aprovação do comunicado não tem e-mail ativo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Montagem';
        SET @Usuario   = ISNULL(SIS.fn_SIS_Usuario_Login(@IdUsuario), N'rotina');
        SET @Assunto   = N'CMJ - ' + @Titulo + N' - semana de ' + LEFT(SIS.fn_SIS_Formatar_Data(@Inicio), 5)
                       + N' a ' + SIS.fn_SIS_Formatar_Data(@Fim);
        SET @Conteudo  = SIS.fn_SIS_Comunicado_Conteudo(@IdComunicado);
        SET @Corpo     = SIS.fn_SIS_Email_HTML(@Titulo, 'INFO', @Conteudo, NULL, NULL, 1);
        SET @AssuntoPv = N'[PRÉVIA] ' + @Assunto;
        SET @Aviso     = N'<div style="background:#FFF3E0;border-left:4px solid #E65100;padding:10px 14px;margin-bottom:16px;">'
                       + N'<b>Prévia para aprovação.</b> Este e-mail ainda não foi enviado aos destinatários. '
                       + N'Para liberar, abra o SistemaCMJ, menu Sistema &gt; E-mails &gt; Comunicados, e clique em "Aprovar e enviar".</div>';
        SET @CorpoPv   = SIS.fn_SIS_Email_HTML(N'Prévia - ' + @Titulo, 'INFO', @Aviso + @Conteudo, @NomeProc, @GrupoAprov, 0);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE e
           SET e.SITUACAO = 'DESCARTADA', e.DT_ALTERACAO = SYSDATETIME(), e.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Edicao e WITH (UPDLOCK, HOLDLOCK)
        WHERE e.ID_COMUNICADO = @IdComunicado AND e.SITUACAO = 'PREVIA';

        INSERT INTO SIS.Comunicado_Edicao (ID_COMUNICADO, DT_INICIO, DT_FIM, ASSUNTO, CORPO_HTML, SITUACAO, USUARIO_CRIACAO)
        VALUES (@IdComunicado, @Inicio, @Fim, @Assunto, @Corpo, 'PREVIA', @Usuario);
        SET @IdEdicao = SCOPE_IDENTITY();

        SET @Chave = N'COMUNICADO_PREVIA:' + CONVERT(NVARCHAR(30), @IdEdicao);
        EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @AssuntoPv, @CorpoHTML = @CorpoPv, @Tipo = 'COMUNICADO_PREVIA',
             @Origem = @NomeProc, @ChaveOrigem = @Chave, @Grupo = @GrupoAprov, @Conta = 'INTERNA', @IdEmail = @IdEmail OUTPUT;

        IF @IdEmail IS NULL
            THROW 50001, N'A prévia não entrou na fila de e-mails (veja o log de erros).', 1;

        UPDATE SIS.Comunicado_Edicao SET ID_EMAIL_PREVIA = @IdEmail WHERE ID_COMUNICADO_EDICAO = @IdEdicao;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia gerada e enviada para aprovação.' AS NVARCHAR(400)) AS MENSAGEM, @IdEdicao AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gerar a prévia do comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Previa_Processar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Previa_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Rotina semanal (SIS.Rotina COMUNICADO_PREVIA, sexta 9h): gera a
                prévia de cada comunicado ativo. Um comunicado com problema não
                impede os outros (laço isolado, regra 13); no fim, se algum falhou,
                relança um erro agregado para a rotina registrar ERRO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Previa_Processar]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Previa_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Laço';
    DECLARE @Id         INT           = 0;
    DECLARE @Proximo    INT;
    DECLARE @Falhas     NVARCHAR(MAX) = N'';
    DECLARE @Res        TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);

    WHILE 1 = 1
    BEGIN
        SET @Proximo = NULL;
        SELECT TOP (1) @Proximo = c.ID_COMUNICADO
        FROM SIS.Comunicado c
        WHERE c.ATIVO = 1 AND c.ID_COMUNICADO > @Id
        ORDER BY c.ID_COMUNICADO;
        IF @Proximo IS NULL BREAK;
        SET @Id = @Proximo;

        BEGIN TRY
            DELETE FROM @Res;
            INSERT INTO @Res (SUCESSO, MENSAGEM, ID)
            EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = NULL, @IdComunicado = @Id;

            SELECT @Falhas = @Falhas + N' [' + CONVERT(NVARCHAR(10), @Id) + N'] ' + r.MENSAGEM
            FROM @Res r
            WHERE r.SUCESSO = 0;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SET @Falhas = @Falhas + N' [' + CONVERT(NVARCHAR(10), @Id) + N'] ' + ERROR_MESSAGE();
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;
    END;

    IF @Falhas <> N''
    BEGIN
        SET @Falhas = LEFT(N'Comunicados com problema:' + @Falhas, 2000);
        THROW 50001, @Falhas, 1;
    END;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Dados da tela Comunicados: o comunicado (o primeiro, ativo antes,
                quando @IdComunicado vier vazio), os itens (ITENS_JSON), as últimas
                20 edições (EDICOES_JSON, sem o HTML), os destinatários dos dois
                grupos e a agenda da rotina. Permissão: VER em SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Obter]
    @IdUsuario     INT,
    @IdComunicado  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os comunicados.', 1;

        IF @IdComunicado IS NULL
            SELECT TOP (1) @IdComunicado = c.ID_COMUNICADO FROM SIS.Comunicado c ORDER BY c.ATIVO DESC, c.ID_COMUNICADO;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_COMUNICADO, c.CODIGO, c.TITULO, c.INTRODUCAO, c.EXIGE_APROVACAO, c.ATIVO,
               g.CODIGO AS GRUPO, ga.CODIGO AS GRUPO_APROVACAO,
               ISNULL(SIS.fn_SIS_Emails_Do_Grupo(g.CODIGO), N'')  AS DESTINATARIOS,
               ISNULL(SIS.fn_SIS_Emails_Do_Grupo(ga.CODIGO), N'') AS DESTINATARIOS_APROVACAO,
               ISNULL(CONVERT(VARCHAR(5), r.HORARIO, 108), '') AS ROTINA_HORARIO, ISNULL(r.DIAS_SEMANA, '') AS ROTINA_DIAS,
               r.PROXIMA_EXECUCAO AS ROTINA_PROXIMA, ISNULL(r.ATIVA, CAST(0 AS BIT)) AS ROTINA_ATIVA,
               ISNULL((SELECT i.ID_COMUNICADO_ITEM AS id, i.SECAO AS secao, i.TEXTO AS texto, i.ORDEM AS ordem, i.ATIVO AS ativo
                       FROM SIS.Comunicado_Item i
                       WHERE i.ID_COMUNICADO = c.ID_COMUNICADO AND i.ATIVO = 1
                       ORDER BY i.SECAO, i.ORDEM, i.ID_COMUNICADO_ITEM
                       FOR JSON PATH), N'[]') AS ITENS_JSON,
               ISNULL((SELECT TOP (20) e.ID_COMUNICADO_EDICAO AS id, e.DT_INICIO AS inicio, e.DT_FIM AS fim, e.ASSUNTO AS assunto,
                              e.SITUACAO AS situacao, e.DT_CRIACAO AS criada, e.DT_APROVACAO AS aprovada, e.USUARIO_APROVACAO AS aprovadaPor
                       FROM SIS.Comunicado_Edicao e
                       WHERE e.ID_COMUNICADO = c.ID_COMUNICADO
                       ORDER BY e.ID_COMUNICADO_EDICAO DESC
                       FOR JSON PATH), N'[]') AS EDICOES_JSON
        FROM SIS.Comunicado c
        INNER JOIN SIS.Grupo_Email g  ON g.ID_GRUPO_EMAIL  = c.ID_GRUPO_EMAIL
        INNER JOIN SIS.Grupo_Email ga ON ga.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL_APROVACAO
        LEFT  JOIN SIS.Rotina r ON r.CODIGO = 'COMUNICADO_PREVIA'
        WHERE c.ID_COMUNICADO = @IdComunicado;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o comunicado. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Edicao_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Uma edição com o HTML, para a tela mostrar exatamente o que será
                (ou foi) enviado. Permissão: VER em SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Obter]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'VER') = 0
        THROW 50001, N'Você não tem permissão para ver os comunicados.', 1;

    SELECT e.ID_COMUNICADO_EDICAO, e.ID_COMUNICADO, e.DT_INICIO, e.DT_FIM, e.ASSUNTO, e.CORPO_HTML, e.SITUACAO,
           e.DT_APROVACAO, e.USUARIO_APROVACAO, e.DT_CRIACAO, e.USUARIO_CRIACAO
    FROM SIS.Comunicado_Edicao e WITH (NOLOCK)
    WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Grava a introdução e a lista inteira de itens do comunicado
                (tudo-ou-nada). @ItensJson: [{"id":null|n,"secao":"EM_TESTE",
                "texto":"...","ordem":1}]. Item que sumiu da lista é DESATIVADO
                (nunca apagado). Permissão: ALTERAR em SIS_COMUNICADO. Não gera
                prévia: a tela oferece "Gerar prévia agora".

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Gravar @IdUsuario = 2, @IdComunicado = 1, @Introducao = N'Olá', @ItensJson = N'[{"secao":"EM_TESTE","texto":"Teste","ordem":1}]';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Gravar]
    @IdUsuario     INT,
    @IdComunicado  INT,
    @Introducao    NVARCHAR(1000) = NULL,
    @ItensJson     NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        DROP TABLE IF EXISTS #Itens;
        SET @Introducao = LTRIM(RTRIM(ISNULL(@Introducao, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para alterar comunicados.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado c WHERE c.ID_COMUNICADO = @IdComunicado)
            SET @Recusa = N'Comunicado não encontrado.';
        IF @Recusa = N'' AND ISJSON(ISNULL(@ItensJson, N'')) = 0
            SET @Recusa = N'Lista de itens inválida.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
            RETURN;
        END;

        SELECT j.id AS ID_ITEM, UPPER(LTRIM(RTRIM(ISNULL(j.secao, '')))) AS SECAO,
               LTRIM(RTRIM(ISNULL(j.texto, N''))) AS TEXTO, ISNULL(j.ordem, 0) AS ORDEM
        INTO #Itens
        FROM OPENJSON(@ItensJson) WITH (id INT '$.id', secao VARCHAR(15) '$.secao', texto NVARCHAR(400) '$.texto', ordem SMALLINT '$.ordem') j;

        IF EXISTS (SELECT 1 FROM #Itens WHERE SECAO NOT IN ('IMPLANTADO', 'EM_TESTE', 'PROXIMA_FASE'))
            SET @Recusa = N'Seção inválida num dos itens.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens WHERE TEXTO = N'')
            SET @Recusa = N'Há item sem texto. Preencha ou remova a linha.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens WHERE LEN(TEXTO) > 300)
            SET @Recusa = N'Cada item pode ter no máximo 300 caracteres.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens i WHERE i.ID_ITEM IS NOT NULL
                                     AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Item ci WHERE ci.ID_COMUNICADO_ITEM = i.ID_ITEM AND ci.ID_COMUNICADO = @IdComunicado))
            SET @Recusa = N'Um dos itens não pertence a este comunicado.';
        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Itens;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE c
           SET c.INTRODUCAO = @Introducao, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado c
        WHERE c.ID_COMUNICADO = @IdComunicado AND c.INTRODUCAO <> @Introducao;

        UPDATE ci
           SET ci.SECAO = i.SECAO, ci.TEXTO = i.TEXTO, ci.ORDEM = i.ORDEM, ci.ATIVO = 1,
               ci.DT_ALTERACAO = SYSDATETIME(), ci.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Item ci
        INNER JOIN #Itens i ON i.ID_ITEM = ci.ID_COMUNICADO_ITEM
        WHERE ci.SECAO <> i.SECAO OR ci.TEXTO <> i.TEXTO OR ci.ORDEM <> i.ORDEM OR ci.ATIVO = 0;

        UPDATE ci
           SET ci.ATIVO = 0, ci.DT_ALTERACAO = SYSDATETIME(), ci.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Item ci
        WHERE ci.ID_COMUNICADO = @IdComunicado AND ci.ATIVO = 1
          AND NOT EXISTS (SELECT 1 FROM #Itens i WHERE i.ID_ITEM = ci.ID_COMUNICADO_ITEM);

        INSERT INTO SIS.Comunicado_Item (ID_COMUNICADO, SECAO, TEXTO, ORDEM, USUARIO_CRIACAO)
        SELECT @IdComunicado, i.SECAO, i.TEXTO, i.ORDEM, @Usuario
        FROM #Itens i
        WHERE i.ID_ITEM IS NULL;

        COMMIT TRANSACTION;
        DROP TABLE IF EXISTS #Itens;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Comunicado gravado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Itens;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Edicao_Aprovar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Aprovar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : "Aprovar e enviar": manda ao grupo oficial exatamente o que foi
                aprovado na prévia (assunto e HTML da edição) e marca ENVIADA, tudo
                na mesma transação. Só edição em PREVIA. Permissão: APROVAR em
                SIS_COMUNICADO. Conta EXTERNA (destinatários de fora). No banco
                _LOCAL a fila manda para o EMAIL_TESTE (proteção da 02d).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Edicao_Aprovar @IdUsuario = 2, @IdEdicao = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Aprovar]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Edicao_Aprovar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Situacao   VARCHAR(10);
    DECLARE @Grupo      VARCHAR(30);
    DECLARE @Para       NVARCHAR(MAX);
    DECLARE @Assunto    NVARCHAR(400);
    DECLARE @Corpo      NVARCHAR(MAX);
    DECLARE @IdEmail    BIGINT;
    DECLARE @Chave      NVARCHAR(200);
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'APROVAR') = 0
            SET @Recusa = N'Você não tem permissão para aprovar comunicados.';

        SET @EtapaAtual = 'Envio';
        BEGIN TRANSACTION;

        SELECT @Situacao = e.SITUACAO, @Grupo = g.CODIGO, @Assunto = e.ASSUNTO, @Corpo = e.CORPO_HTML
        FROM SIS.Comunicado_Edicao e WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = e.ID_COMUNICADO
        INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL
        WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao;

        IF @Recusa = N'' AND @Situacao IS NULL
            SET @Recusa = N'Edição do comunicado não encontrada.';
        IF @Recusa = N'' AND @Situacao <> 'PREVIA'
            SET @Recusa = CASE @Situacao WHEN 'ENVIADA' THEN N'Este comunicado já foi enviado.'
                                         ELSE N'Esta prévia foi descartada. Gere uma prévia nova.' END;
        SET @Para = ISNULL(SIS.fn_SIS_Emails_Do_Grupo(@Grupo), N'');
        IF @Recusa = N'' AND @Para = N''
            SET @Recusa = N'O grupo de destinatários do comunicado não tem e-mail ativo.';
        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi alterado; COMMIT (e não ROLLBACK) funciona também dentro de INSERT-EXEC
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Chave   = N'COMUNICADO:' + CONVERT(NVARCHAR(30), @IdEdicao);
        EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @Assunto, @CorpoHTML = @Corpo, @Tipo = 'COMUNICADO',
             @Origem = @NomeProc, @ChaveOrigem = @Chave, @Grupo = @Grupo, @Conta = 'EXTERNA', @IdEmail = @IdEmail OUTPUT;

        IF @IdEmail IS NULL
            THROW 50001, N'O comunicado não entrou na fila de e-mails (veja o log de erros).', 1;

        UPDATE SIS.Comunicado_Edicao
           SET SITUACAO = 'ENVIADA', ID_EMAIL_OFICIAL = @IdEmail, DT_APROVACAO = SYSDATETIME(), USUARIO_APROVACAO = @Usuario,
               DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_COMUNICADO_EDICAO = @IdEdicao;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Comunicado aprovado. O e-mail foi para a fila de envio.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível aprovar o comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Edicao_Descartar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Descartar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Descarta uma prévia (nada é enviado). Permissão: APROVAR em
                SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Descartar]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Edicao_Descartar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'APROVAR') = 0
            SET @Recusa = N'Você não tem permissão para descartar comunicados.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Edicao e WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao AND e.SITUACAO = 'PREVIA')
            SET @Recusa = N'Só uma prévia pendente pode ser descartada.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        UPDATE SIS.Comunicado_Edicao
           SET SITUACAO = 'DESCARTADA', DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_COMUNICADO_EDICAO = @IdEdicao AND SITUACAO = 'PREVIA';

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia descartada. Nada foi enviado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível descartar a prévia. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.tg_FIN_Baixa_Saldo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[tg_FIN_Baixa_Saldo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Mantém FIN.Parcela.VALOR_BAIXADO e a SITUACAO (ABERTA, PARCIAL,
                PAGA) a cada inclusão/alteração/exclusão de baixa, por delta
                (regra 9: UNION ALL de inserted positivo e deleted negativo).
                Parcela CANCELADA não muda de situação. Sem recursão: só atualiza
                o que muda (regra 20).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER TRIGGER [FIN].[tg_FIN_Baixa_Saldo]
ON [FIN].[Baixa]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    ;WITH Delta AS
    (
        SELECT d.ID_PARCELA, SUM(d.VALOR) AS VALOR
        FROM (
                SELECT i.ID_PARCELA, i.VALOR_PRINCIPAL AS VALOR FROM inserted i
                UNION ALL
                SELECT x.ID_PARCELA, -x.VALOR_PRINCIPAL FROM deleted x
             ) d
        GROUP BY d.ID_PARCELA
    )
    UPDATE p
       SET p.VALOR_BAIXADO = p.VALOR_BAIXADO + dl.VALOR
    FROM FIN.Parcela p
    INNER JOIN Delta dl ON dl.ID_PARCELA = p.ID_PARCELA
    WHERE dl.VALOR <> 0;

    UPDATE p
       SET p.SITUACAO = CASE WHEN p.VALOR_BAIXADO <= 0 THEN 'ABERTA'
                             WHEN p.VALOR_BAIXADO >= p.VALOR THEN 'PAGA'
                             ELSE 'PARCIAL' END
    FROM FIN.Parcela p
    WHERE p.ID_PARCELA IN (SELECT i.ID_PARCELA FROM inserted i UNION SELECT x.ID_PARCELA FROM deleted x)
      AND p.SITUACAO <> 'CANCELADA'
      AND p.SITUACAO <> CASE WHEN p.VALOR_BAIXADO <= 0 THEN 'ABERTA'
                             WHEN p.VALOR_BAIXADO >= p.VALOR THEN 'PAGA'
                             ELSE 'PARCIAL' END;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Item.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Item] e [SIS].[Item_Acao] do módulo FIN
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Tela "Arquivo morto" (só consulta: VER e EXPORTAR, sem incluir,
                alterar ou excluir). Nasce DESABILITADA, como toda tela de módulo
                novo. As telas de lançamento, baixa e conciliação entram na fase 4.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_ARQUIVO_MORTO', N'Arquivo morto', 'TELA', 'fin/arquivo-morto.html', 90, 0, 0, 'FIN.Arquivo_Morto'
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_ARQUIVO_MORTO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_ARQUIVO_MORTO' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))), ('FIN_ARQUIVO_MORTO', 'EXPORTAR')) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Comunicado.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga do boletim semanal da implantação
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Grupos de e-mail, comunicado BOLETIM_IMPLANTACAO com os itens
                iniciais aprovados pelo Celso em 17/11/2026, tela Comunicados (menu
                Sistema > E-mails; administrador geral e administrador da CMJ) e a
                rotina COMUNICADO_PREVIA (sexta-feira, 9h). Só insere o que falta
                (regra 39): o que o Celso mudar pela tela não é sobrescrito.
                Destinatários oficiais (17/11/2026): escritório Construtora Marcílio
                Judice e Danielle M. Judice Daher. Aprovação: Celso.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT v.CODIGO, v.NOME, v.DESCRICAO, N'instalacao'
FROM (VALUES
        (CAST('BOLETIM_IMPLANTACAO' AS VARCHAR(30)), CAST(N'Boletim da implantação' AS NVARCHAR(80)),
         CAST(N'Recebem o boletim semanal do andamento da implantação do SistemaCMJ.' AS NVARCHAR(400))),
        ('BOLETIM_APROVACAO', N'Aprovação do boletim', N'Recebem a prévia do boletim para aprovar antes do envio oficial.')
     ) v (CODIGO, NOME, DESCRICAO)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = v.CODIGO);
GO

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, v.EMAIL, v.NOME, N'instalacao'
FROM (VALUES
        (CAST('BOLETIM_IMPLANTACAO' AS VARCHAR(30)), CAST(N'construtora.m.judice@gmail.com' AS NVARCHAR(256)), CAST(N'Escritório Construtora Marcílio Judice' AS NVARCHAR(100))),
        ('BOLETIM_IMPLANTACAO', N'dmjdaher@gmail.com',       N'Danielle M. Judice Daher'),
        ('BOLETIM_APROVACAO',   N'celsofreitas62@gmail.com', N'Celso de Freitas')
     ) v (GRUPO, EMAIL, NOME)
INNER JOIN SIS.Grupo_Email g ON g.CODIGO = v.GRUPO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.EMAIL = v.EMAIL);
GO

INSERT INTO SIS.Comunicado (CODIGO, TITULO, INTRODUCAO, ID_GRUPO_EMAIL, ID_GRUPO_EMAIL_APROVACAO, EXIGE_APROVACAO, USUARIO_CRIACAO)
SELECT 'BOLETIM_IMPLANTACAO', N'Boletim da implantação do SistemaCMJ',
       N'Segue o resumo semanal do andamento da implantação do novo sistema de gestão da Construtora.',
       g.ID_GRUPO_EMAIL, ga.ID_GRUPO_EMAIL, 1, N'instalacao'
FROM SIS.Grupo_Email g
INNER JOIN SIS.Grupo_Email ga ON ga.CODIGO = 'BOLETIM_APROVACAO'
WHERE g.CODIGO = 'BOLETIM_IMPLANTACAO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado c WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO');
GO

IF NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Item i INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = i.ID_COMUNICADO WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO')
    INSERT INTO SIS.Comunicado_Item (ID_COMUNICADO, SECAO, TEXTO, ORDEM, USUARIO_CRIACAO)
    SELECT c.ID_COMUNICADO, v.SECAO, v.TEXTO, v.ORDEM, N'instalacao'
    FROM (VALUES
            (CAST('IMPLANTADO' AS VARCHAR(15)), CAST(N'Nenhum módulo em uso na empresa ainda. A instalação no servidor da Construtora vem logo depois da fase atual.' AS NVARCHAR(300)), CAST(1 AS SMALLINT)),
            ('EM_TESTE',     N'Entrada no sistema com usuário e senha, e menu.', 1),
            ('EM_TESTE',     N'Cadastro de clientes e fornecedores.', 2),
            ('PROXIMA_FASE', N'Financeiro: contas a pagar e a receber.', 1),
            ('PROXIMA_FASE', N'Preparação da migração dos dados do sistema antigo.', 2)
         ) v (SECAO, TEXTO, ORDEM)
    CROSS JOIN SIS.Comunicado c
    WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO';
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'SIS_COMUNICADO', N'Comunicados', 'TELA', 'sis/comunicados.html', 30, 0, 1,
       'SIS.Comunicado,SIS.Comunicado_Item'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_EMAILS'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_COMUNICADO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('ALTERAR'), ('ENVIAR'), ('APROVAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'SIS_COMUNICADO'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT 'COMUNICADO_PREVIA', N'Prévia dos comunicados semanais',
       N'Monta o comunicado da semana (boletim da implantação) e manda a prévia para aprovação. O envio oficial só sai depois de "Aprovar e enviar" na tela Comunicados.',
       N'SIS.SIS_Comunicado_Previa_Processar', m.ID_MODULO, 'SEMANAL', 0, '09:00', '6', 0, 30, 1,
       SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '09:00', '6', 0, SYSDATETIME()), N'instalacao'
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = 'COMUNICADO_PREVIA');
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comunicado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comunicado_Item', @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do FIN e do BANCO (03c)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de negócio da 03c. Não
                entram: Arquivo_Morto (só consulta, carga da migração) e as linhas
                do extrato (vêm do arquivo do banco). CAD.Empresa é regerada por
                causa da coluna nova PASTA_OFX.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Historico_Padrao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Mes_Fechado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Transferencia',    @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Movimento',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Lancamento',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Parcela',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Baixa',            @Criar = 1;
GO

PRINT N'Pacote 03c concluído sem erro.';
GO

SET NOEXEC OFF;
GO
