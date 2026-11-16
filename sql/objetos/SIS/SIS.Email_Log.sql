/*******************************************************************************
  Objeto      : [SIS].[Email_Log]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico de cada e-mail da fila: cada tentativa de envio e
                cada ação da tela (reenviar, cancelar) ou da rotina que solta
                os presos. Não é apagado.
                RESULTADO: ENVIADO, ERRO_TEMPORARIO, ERRO_PERMANENTE,
                LIBERADO, REENVIO, CANCELADO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Log]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Log]
    (
        ID_EMAIL_LOG  BIGINT          IDENTITY(1,1) NOT NULL,
        ID_EMAIL      BIGINT          NOT NULL,
        TENTATIVA     INT             NOT NULL CONSTRAINT DF_Email_Log_TENTATIVA   DEFAULT (0),
        RESULTADO     VARCHAR(20)     NOT NULL,
        MENSAGEM      NVARCHAR(1000)  NOT NULL CONSTRAINT DF_Email_Log_MENSAGEM    DEFAULT (N''),
        SERVIDOR      NVARCHAR(128)   NOT NULL CONSTRAINT DF_Email_Log_SERVIDOR    DEFAULT (N''),
        USUARIO       NVARCHAR(100)   NOT NULL CONSTRAINT DF_Email_Log_USUARIO     DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_REGISTRO   DATETIME2(0)    NOT NULL CONSTRAINT DF_Email_Log_DT_REGISTRO DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Email_Log          PRIMARY KEY CLUSTERED (ID_EMAIL_LOG),
        CONSTRAINT FK_Email_Log_Email    FOREIGN KEY (ID_EMAIL) REFERENCES [SIS].[Email_Fila] (ID_EMAIL),
        CONSTRAINT CK_Email_Log_RESULTADO CHECK (RESULTADO IN ('ENVIADO', 'ERRO_TEMPORARIO', 'ERRO_PERMANENTE', 'LIBERADO', 'REENVIO', 'CANCELADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Log]') AND i.name = N'IX_Email_Log_ID_EMAIL')
    CREATE NONCLUSTERED INDEX IX_Email_Log_ID_EMAIL ON [SIS].[Email_Log] (ID_EMAIL, ID_EMAIL_LOG);
GO
