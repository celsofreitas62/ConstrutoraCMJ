/*******************************************************************************
  Objeto      : [FIN].[Lancamento_Pendencia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Pendências manuais dos lançamentos (P27): "aguardando nota
                fiscal", "conferir com o contador", "veio da migração –
                conferir" etc. Uma linha por pendência; ID_PARCELA preenchido
                quando a pendência é só de uma parcela.
                SITUACAO  ABERTA ou RESOLVIDA (com quem, quando e a nota da
                          resolução). Reabrir volta para ABERTA e limpa a
                          resolução (o histórico guarda o antes/depois).
                ATIVO = 0: pendência lançada por engano (desativada); não
                          conta em lugar nenhum.
                ORIGEM    MANUAL (pela tela) ou MIGRACAO (rodada da virada).
                Filha de FIN.Lancamento na lixeira e no histórico
                (SIS.Tabela_Config). Auditoria pela trigger padrão.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c, P27).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Lancamento_Pendencia]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Lancamento_Pendencia]
    (
        ID_LANCAMENTO_PENDENCIA BIGINT         IDENTITY(1,1) NOT NULL,
        ID_LANCAMENTO           BIGINT         NOT NULL,
        ID_PARCELA              BIGINT         NULL,
        ID_PENDENCIA_TIPO       INT            NOT NULL,
        OBSERVACAO              NVARCHAR(1000) NOT NULL CONSTRAINT DF_Lancamento_Pendencia_OBSERVACAO      DEFAULT (N''),
        ID_USUARIO_RESPONSAVEL  INT            NULL,
        DT_PREVISAO             DATE           NULL,
        SITUACAO                VARCHAR(10)    NOT NULL CONSTRAINT DF_Lancamento_Pendencia_SITUACAO        DEFAULT ('ABERTA'),
        DT_RESOLUCAO            DATETIME2(0)   NULL,
        USUARIO_RESOLUCAO       NVARCHAR(100)  NULL,
        RESOLUCAO               NVARCHAR(1000) NOT NULL CONSTRAINT DF_Lancamento_Pendencia_RESOLUCAO       DEFAULT (N''),
        ORIGEM                  VARCHAR(15)    NOT NULL CONSTRAINT DF_Lancamento_Pendencia_ORIGEM          DEFAULT ('MANUAL'),
        ATIVO                   BIT            NOT NULL CONSTRAINT DF_Lancamento_Pendencia_ATIVO           DEFAULT (1),
        DT_CRIACAO              DATETIME2(0)   NOT NULL CONSTRAINT DF_Lancamento_Pendencia_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO         NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lancamento_Pendencia_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO            DATETIME2(0)   NULL,
        USUARIO_ALTERACAO       NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lancamento_Pendencia             PRIMARY KEY CLUSTERED (ID_LANCAMENTO_PENDENCIA),
        CONSTRAINT FK_Lancamento_Pendencia_Lancamento  FOREIGN KEY (ID_LANCAMENTO)          REFERENCES [FIN].[Lancamento] (ID_LANCAMENTO),
        CONSTRAINT FK_Lancamento_Pendencia_Parcela     FOREIGN KEY (ID_PARCELA)             REFERENCES [FIN].[Parcela] (ID_PARCELA),
        CONSTRAINT FK_Lancamento_Pendencia_Tipo        FOREIGN KEY (ID_PENDENCIA_TIPO)      REFERENCES [FIN].[Pendencia_Tipo] (ID_PENDENCIA_TIPO),
        CONSTRAINT FK_Lancamento_Pendencia_Responsavel FOREIGN KEY (ID_USUARIO_RESPONSAVEL) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Lancamento_Pendencia_SITUACAO    CHECK (SITUACAO IN ('ABERTA', 'RESOLVIDA')),
        CONSTRAINT CK_Lancamento_Pendencia_ORIGEM      CHECK (ORIGEM IN ('MANUAL', 'MIGRACAO')),
        CONSTRAINT CK_Lancamento_Pendencia_RESOLVIDA   CHECK (SITUACAO = 'ABERTA' OR DT_RESOLUCAO IS NOT NULL)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Lancamento_Pendencia_Lancamento' AND object_id = OBJECT_ID(N'[FIN].[Lancamento_Pendencia]'))
    CREATE NONCLUSTERED INDEX IX_Lancamento_Pendencia_Lancamento
        ON [FIN].[Lancamento_Pendencia] (ID_LANCAMENTO)
        INCLUDE (ID_PENDENCIA_TIPO, SITUACAO, ATIVO, ID_USUARIO_RESPONSAVEL, DT_PREVISAO);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Lancamento_Pendencia_Aberta' AND object_id = OBJECT_ID(N'[FIN].[Lancamento_Pendencia]'))
    CREATE NONCLUSTERED INDEX IX_Lancamento_Pendencia_Aberta
        ON [FIN].[Lancamento_Pendencia] (ID_PENDENCIA_TIPO, ID_LANCAMENTO)
        INCLUDE (ID_USUARIO_RESPONSAVEL, DT_PREVISAO)
        WHERE SITUACAO = 'ABERTA' AND ATIVO = 1;
GO
