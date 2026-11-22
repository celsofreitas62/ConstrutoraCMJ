/*******************************************************************************
  Objeto      : [SIS].[Desfazer]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Registro de cada desfazer feito pelo histórico (P20): o que foi
                pedido, por quem, com que motivo (obrigatório) e o que mudou.
                TIPO: REGISTRO (voltar um registro, com os filhos que vão
                junto, para como estava depois de uma operação ou numa
                data/hora), OPERACAO (desfazer uma operação = uma transação) ou
                LOTE (desfazer tudo o que um lote fez).
                TRANSACAO: a transação do próprio desfazer, que liga este
                registro às linhas novas da SIS.Auditoria.
                Nunca é alterada nem apagada.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b, P20).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Desfazer]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Desfazer]
    (
        ID_DESFAZER     BIGINT         IDENTITY(1,1) NOT NULL,
        TIPO            VARCHAR(10)    NOT NULL,
        ITEM_CODIGO     VARCHAR(40)    NOT NULL CONSTRAINT DF_Desfazer_ITEM_CODIGO   DEFAULT (''),
        TABELA          NVARCHAR(256)  NOT NULL CONSTRAINT DF_Desfazer_TABELA        DEFAULT (N''),
        ID_REGISTRO     BIGINT         NULL,
        ID_AUDITORIA    BIGINT         NULL,
        DT_ALVO         DATETIME2(0)   NULL,
        TRANSACAO_ALVO  BIGINT         NULL,
        ID_LOTE_ALVO    BIGINT         NULL,
        MOTIVO          NVARCHAR(400)  NOT NULL,
        QTD_REGISTROS   INT            NOT NULL CONSTRAINT DF_Desfazer_QTD_REGISTROS DEFAULT (0),
        QTD_CAMPOS      INT            NOT NULL CONSTRAINT DF_Desfazer_QTD_CAMPOS    DEFAULT (0),
        QTD_LIXEIRA     INT            NOT NULL CONSTRAINT DF_Desfazer_QTD_LIXEIRA   DEFAULT (0),
        TRANSACAO       BIGINT         NULL,
        ID_USUARIO      INT            NULL,
        USUARIO         NVARCHAR(100)  NOT NULL CONSTRAINT DF_Desfazer_USUARIO       DEFAULT (N''),
        DT_CRIACAO      DATETIME2(0)   NOT NULL CONSTRAINT DF_Desfazer_DT_CRIACAO    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Desfazer      PRIMARY KEY CLUSTERED (ID_DESFAZER),
        CONSTRAINT CK_Desfazer_TIPO CHECK (TIPO IN ('REGISTRO', 'OPERACAO', 'LOTE'))
    );
END;
GO
