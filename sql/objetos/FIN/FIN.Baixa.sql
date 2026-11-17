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
