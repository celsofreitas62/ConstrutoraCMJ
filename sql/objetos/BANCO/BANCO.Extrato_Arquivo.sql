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
