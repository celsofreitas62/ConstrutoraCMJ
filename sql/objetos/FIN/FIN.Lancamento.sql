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
    v1.1 (25/11/2026) - Etapa 04f: ATIVO, DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira, P20); DT_CANCELAMENTO, USUARIO_CANCELAMENTO e
                        MOTIVO_CANCELAMENTO (Cancelar com motivo); índices da
                        conferência de duplicidade (P17) e da lista por tipo.
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

IF COL_LENGTH(N'FIN.Lancamento', N'ATIVO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD ATIVO BIT NOT NULL CONSTRAINT DF_Lancamento_ATIVO DEFAULT (1);
GO
IF COL_LENGTH(N'FIN.Lancamento', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'FIN.Lancamento', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'FIN.Lancamento', N'DT_CANCELAMENTO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD DT_CANCELAMENTO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'FIN.Lancamento', N'USUARIO_CANCELAMENTO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD USUARIO_CANCELAMENTO NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'FIN.Lancamento', N'MOTIVO_CANCELAMENTO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD MOTIVO_CANCELAMENTO NVARCHAR(400) NOT NULL CONSTRAINT DF_Lancamento_MOTIVO_CANCELAMENTO DEFAULT (N'');
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[FIN].[Lancamento]') AND i.name = N'IX_Lancamento_DOCUMENTO')
    CREATE INDEX IX_Lancamento_DOCUMENTO ON [FIN].[Lancamento] (ID_PESSOA, TIPO, DOCUMENTO) INCLUDE (SITUACAO, DT_EXCLUSAO) WHERE DOCUMENTO <> N'';
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[FIN].[Lancamento]') AND i.name = N'IX_Lancamento_PESSOA_PLANO')
    CREATE INDEX IX_Lancamento_PESSOA_PLANO ON [FIN].[Lancamento] (ID_PESSOA, ID_PLANO_CONTA, TIPO, DT_EMISSAO) INCLUDE (VALOR_TOTAL, SITUACAO);
GO
