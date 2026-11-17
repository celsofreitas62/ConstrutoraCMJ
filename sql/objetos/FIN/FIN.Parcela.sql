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
