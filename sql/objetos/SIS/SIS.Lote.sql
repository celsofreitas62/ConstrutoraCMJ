/*******************************************************************************
  Objeto      : [SIS].[Lote]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Número de lote de tudo que é gerado junto (seção 3.1 item 2 e
                pedido 9): uma venda que gera 30 parcelas = 1 lote; um retorno
                bancário, uma importação de extrato, uma medição aprovada...
                O número do lote é o próprio ID_LOTE (mostrado ao usuário).
                Os registros gerados guardam ID_LOTE; a auditoria também
                (SESSION_CONTEXT 'ID_LOTE'). Lote não é apagado: o processo que
                desfaz um lote marca SITUACAO = 'CANCELADO'.
                ORIGEM: código do processo (VENDA_PARCELAS, ACORDO, RECORRENTE,
                OFX, RETORNO_SICREDI, MEDICAO, MIGRACAO, TESTE...).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Lote]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Lote]
    (
        ID_LOTE            BIGINT         IDENTITY(1,1) NOT NULL,
        ORIGEM             VARCHAR(30)    NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Lote_DESCRICAO         DEFAULT (N''),
        TABELA_REFERENCIA  NVARCHAR(256)  NOT NULL CONSTRAINT DF_Lote_TABELA_REFERENCIA DEFAULT (N''),
        ID_REFERENCIA      BIGINT         NULL,
        QTD_REGISTROS      INT            NOT NULL CONSTRAINT DF_Lote_QTD_REGISTROS     DEFAULT (0),
        SITUACAO           VARCHAR(10)    NOT NULL CONSTRAINT DF_Lote_SITUACAO          DEFAULT ('ATIVO'),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Lote_DT_CRIACAO        DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lote_USUARIO_CRIACAO   DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lote          PRIMARY KEY CLUSTERED (ID_LOTE),
        CONSTRAINT CK_Lote_ORIGEM   CHECK (ORIGEM <> '' AND REPLACE(ORIGEM, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Lote_SITUACAO CHECK (SITUACAO IN ('ATIVO', 'CANCELADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Lote]') AND i.name = N'IX_Lote_ORIGEM')
    CREATE NONCLUSTERED INDEX IX_Lote_ORIGEM ON [SIS].[Lote] (ORIGEM, DT_CRIACAO);
GO
