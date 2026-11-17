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
