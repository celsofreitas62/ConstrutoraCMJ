/*******************************************************************************
  Objeto      : [SIS].[Email_Fila]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Fila de e-mails (PADRAO_EMAIL seção 1). As rotinas só gravam
                aqui (SIS_Email_Enfileirar); o serviço do sistema captura
                (SIS_Email_Capturar), envia por SMTP e grava o resultado
                (SIS_Email_Resultado_Gravar). Falha de envio nunca desfaz a
                operação de negócio.
                STATUS: PENDENTE > PROCESSANDO > ENVIADO | ERRO; CANCELADO
                pela tela.
                CHAVE_ORIGEM: impede o mesmo aviso duas vezes (ex.:
                'BOLETO:12345'); índice único só quando informada.
                ID_EMAIL numérico (aparece na tela); a idempotência fica na
                CHAVE_ORIGEM.
                CONTA: INTERNA (avisos da CMJ) ou EXTERNA (clientes e
                terceiros); o serviço escolhe a conta SMTP por ela.
                MODO_TESTE = 1: gravado no banco _LOCAL; PARA foi trocado pelo
                EMAIL_TESTE e o endereço pedido ficou em PARA_ORIGINAL.
                Anexos em SIS.Email_Fila_Anexo; histórico em SIS.Email_Log.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Fila]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Fila]
    (
        ID_EMAIL           BIGINT         IDENTITY(1,1) NOT NULL,
        CHAVE_ORIGEM       NVARCHAR(200)  NULL,
        TIPO               VARCHAR(30)    NOT NULL,
        CONTA              VARCHAR(10)    NOT NULL CONSTRAINT DF_Email_Fila_CONTA             DEFAULT ('INTERNA'),
        GRUPO              VARCHAR(30)    NOT NULL CONSTRAINT DF_Email_Fila_GRUPO             DEFAULT (''),
        PARA               NVARCHAR(2000) NOT NULL,
        CC                 NVARCHAR(2000) NOT NULL CONSTRAINT DF_Email_Fila_CC                DEFAULT (N''),
        CCO                NVARCHAR(2000) NOT NULL CONSTRAINT DF_Email_Fila_CCO               DEFAULT (N''),
        PARA_ORIGINAL      NVARCHAR(4000) NOT NULL CONSTRAINT DF_Email_Fila_PARA_ORIGINAL     DEFAULT (N''),
        ASSUNTO            NVARCHAR(400)  NOT NULL,
        CORPO_HTML         NVARCHAR(MAX)  NOT NULL,
        STATUS             VARCHAR(12)    NOT NULL CONSTRAINT DF_Email_Fila_STATUS            DEFAULT ('PENDENTE'),
        TENTATIVAS         INT            NOT NULL CONSTRAINT DF_Email_Fila_TENTATIVAS        DEFAULT (0),
        PROXIMA_TENTATIVA  DATETIME2(0)   NOT NULL CONSTRAINT DF_Email_Fila_PROXIMA_TENTATIVA DEFAULT (SYSDATETIME()),
        DT_CAPTURA         DATETIME2(0)   NULL,
        SERVIDOR           NVARCHAR(128)  NOT NULL CONSTRAINT DF_Email_Fila_SERVIDOR          DEFAULT (N''),
        DT_ENVIO           DATETIME2(0)   NULL,
        ULTIMO_ERRO        NVARCHAR(1000) NOT NULL CONSTRAINT DF_Email_Fila_ULTIMO_ERRO       DEFAULT (N''),
        ORIGEM             NVARCHAR(256)  NOT NULL CONSTRAINT DF_Email_Fila_ORIGEM            DEFAULT (N''),
        ID_LOTE            BIGINT         NULL,
        MODO_TESTE         BIT            NOT NULL CONSTRAINT DF_Email_Fila_MODO_TESTE        DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Email_Fila_DT_CRIACAO        DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Email_Fila_USUARIO_CRIACAO   DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Email_Fila        PRIMARY KEY CLUSTERED (ID_EMAIL),
        CONSTRAINT CK_Email_Fila_STATUS CHECK (STATUS IN ('PENDENTE', 'PROCESSANDO', 'ENVIADO', 'ERRO', 'CANCELADO')),
        CONSTRAINT CK_Email_Fila_CONTA  CHECK (CONTA IN ('INTERNA', 'EXTERNA')),
        CONSTRAINT CK_Email_Fila_TIPO   CHECK (TIPO <> '' AND REPLACE(TIPO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'UX_Email_Fila_CHAVE_ORIGEM')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Email_Fila_CHAVE_ORIGEM ON [SIS].[Email_Fila] (CHAVE_ORIGEM) WHERE CHAVE_ORIGEM IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'IX_Email_Fila_STATUS')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_STATUS ON [SIS].[Email_Fila] (STATUS, PROXIMA_TENTATIVA);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'IX_Email_Fila_DT_CRIACAO')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_DT_CRIACAO ON [SIS].[Email_Fila] (DT_CRIACAO) INCLUDE (STATUS, TIPO);
GO
