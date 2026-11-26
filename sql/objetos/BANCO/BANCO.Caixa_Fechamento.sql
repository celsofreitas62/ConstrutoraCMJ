/*******************************************************************************
  Objeto      : [BANCO].[Caixa_Fechamento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Fechamento de caixa por conta e data (aprovado em 26/11/2026,
                04g). Guarda o saldo do sistema no fim do dia, o saldo contado
                e a diferença (motivo obrigatório quando houver; pode gerar um
                movimento de AJUSTE, ID_MOVIMENTO_AJUSTE). Fechado (SITUACAO
                FECHADO) bloqueia baixa, estorno e transferência na conta com
                data até DT_FECHAMENTO. Reabrir (REABERTO) exige a ação REABRIR
                e motivo; o registro fica para a auditoria. Tipos de conta que
                usam o fechamento: parâmetro FIN_CAIXA_FECHAMENTO_TIPOS.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Caixa_Fechamento]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Caixa_Fechamento]
    (
        ID_CAIXA_FECHAMENTO  BIGINT         IDENTITY(1,1) NOT NULL,
        ID_CONTA             INT            NOT NULL,
        DT_FECHAMENTO        DATE           NOT NULL,
        SALDO_SISTEMA        DECIMAL(18,2)  NOT NULL,
        SALDO_CONTADO        DECIMAL(18,2)  NOT NULL,
        DIFERENCA            AS (CAST(SALDO_CONTADO - SALDO_SISTEMA AS DECIMAL(18,2))) PERSISTED,
        MOTIVO_DIFERENCA     NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caixa_Fechamento_MOTIVO_DIFERENCA DEFAULT (N''),
        ID_MOVIMENTO_AJUSTE  BIGINT         NULL,
        OBSERVACAO           NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caixa_Fechamento_OBSERVACAO DEFAULT (N''),
        SITUACAO             VARCHAR(10)    NOT NULL CONSTRAINT DF_Caixa_Fechamento_SITUACAO DEFAULT ('FECHADO'),
        DT_REABERTURA        DATETIME2(0)   NULL,
        USUARIO_REABERTURA   NVARCHAR(100)  NULL,
        MOTIVO_REABERTURA    NVARCHAR(400)  NULL,
        DT_CRIACAO           DATETIME2(0)   NOT NULL CONSTRAINT DF_Caixa_Fechamento_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Caixa_Fechamento_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)   NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)  NULL,
        CONSTRAINT PK_Caixa_Fechamento           PRIMARY KEY CLUSTERED (ID_CAIXA_FECHAMENTO),
        CONSTRAINT FK_Caixa_Fechamento_Conta     FOREIGN KEY (ID_CONTA)            REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Caixa_Fechamento_Movimento FOREIGN KEY (ID_MOVIMENTO_AJUSTE) REFERENCES [BANCO].[Movimento] (ID_MOVIMENTO),
        CONSTRAINT CK_Caixa_Fechamento_SITUACAO  CHECK (SITUACAO IN ('FECHADO', 'REABERTO')),
        CONSTRAINT CK_Caixa_Fechamento_MOTIVO    CHECK (SALDO_CONTADO = SALDO_SISTEMA OR LEN(MOTIVO_DIFERENCA) > 0),
        CONSTRAINT CK_Caixa_Fechamento_REABERTO  CHECK (SITUACAO = 'FECHADO' OR (DT_REABERTURA IS NOT NULL AND LEN(ISNULL(MOTIVO_REABERTURA, N'')) > 0))
    );

    CREATE UNIQUE INDEX UQ_Caixa_Fechamento_FECHADO ON [BANCO].[Caixa_Fechamento] (ID_CONTA, DT_FECHAMENTO) WHERE SITUACAO = 'FECHADO';
END;
GO
