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
    v1.1 (27/11/2026) - Etapa 04g2: DOCUMENTO e dados do estorno (DT_ESTORNO =
                        data do estorno no banco/caixa, MOTIVO_ESTORNO,
                        USUARIO_ESTORNO, DT_HORA_ESTORNO, ID_LOTE_ESTORNO);
                        índice pela data.
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

IF COL_LENGTH(N'FIN.Transferencia', N'DOCUMENTO') IS NULL
    ALTER TABLE [FIN].[Transferencia] ADD DOCUMENTO NVARCHAR(40) NOT NULL CONSTRAINT DF_Transferencia_DOCUMENTO DEFAULT (N'');
GO
IF COL_LENGTH(N'FIN.Transferencia', N'DT_ESTORNO') IS NULL
    ALTER TABLE [FIN].[Transferencia] ADD DT_ESTORNO DATE NULL;
GO
IF COL_LENGTH(N'FIN.Transferencia', N'MOTIVO_ESTORNO') IS NULL
    ALTER TABLE [FIN].[Transferencia] ADD MOTIVO_ESTORNO NVARCHAR(400) NULL;
GO
IF COL_LENGTH(N'FIN.Transferencia', N'USUARIO_ESTORNO') IS NULL
    ALTER TABLE [FIN].[Transferencia] ADD USUARIO_ESTORNO NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'FIN.Transferencia', N'DT_HORA_ESTORNO') IS NULL
    ALTER TABLE [FIN].[Transferencia] ADD DT_HORA_ESTORNO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'FIN.Transferencia', N'ID_LOTE_ESTORNO') IS NULL
    ALTER TABLE [FIN].[Transferencia] ADD ID_LOTE_ESTORNO BIGINT NULL
        CONSTRAINT FK_Transferencia_Lote_Estorno FOREIGN KEY REFERENCES [SIS].[Lote] (ID_LOTE);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[FIN].[Transferencia]') AND i.name = N'IX_Transferencia_DATA')
    CREATE NONCLUSTERED INDEX IX_Transferencia_DATA ON [FIN].[Transferencia] (DT_TRANSFERENCIA) INCLUDE (ID_CONTA_ORIGEM, ID_CONTA_DESTINO, VALOR, SITUACAO);
GO
