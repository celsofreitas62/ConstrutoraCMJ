/*******************************************************************************
  Objeto      : [FIN].[Arquivo_Morto]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Lançamentos antigos do Access (antes de 2018, decisão do Celso de
                16 e 17/11/2026), guardados como eram, já em texto legível, só para
                consulta (sem manutenção nenhuma). Sem FK para o modelo novo: o que
                mudar no cadastro novo não altera o passado; ID_PESSOA/ID_EMPRESA/
                ID_CONTA só ajudam a busca quando há de-para. Carga pela migração.
                Saldos de cada conta na data do corte: FIN.Arquivo_Morto_Saldo.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Arquivo_Morto]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Arquivo_Morto]
    (
        ID_ARQUIVO_MORTO    BIGINT         IDENTITY(1,1) NOT NULL,
        ORIGEM_ACCESS       VARCHAR(20)    NOT NULL,
        CODIGO_ACCESS       INT            NOT NULL,
        EMPRESA             NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_EMPRESA     DEFAULT (N''),
        OBRA                NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_OBRA        DEFAULT (N''),
        PESSOA              NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_PESSOA      DEFAULT (N''),
        CONTA               NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_CONTA       DEFAULT (N''),
        PLANO1              NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO1      DEFAULT (N''),
        PLANO2              NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO2      DEFAULT (N''),
        PLANO3              NVARCHAR(120)  NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO3      DEFAULT (N''),
        HISTORICO           NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_HISTORICO   DEFAULT (N''),
        COMPLEMENTO         NVARCHAR(255)  NOT NULL CONSTRAINT DF_Arquivo_Morto_COMPLEMENTO DEFAULT (N''),
        DOCUMENTO           NVARCHAR(60)   NOT NULL CONSTRAINT DF_Arquivo_Morto_DOCUMENTO   DEFAULT (N''),
        NOTA_FISCAL         NVARCHAR(60)   NOT NULL CONSTRAINT DF_Arquivo_Morto_NOTA_FISCAL DEFAULT (N''),
        IMOVEL              NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_IMOVEL      DEFAULT (N''),
        OBSERVACAO          NVARCHAR(2000) NOT NULL CONSTRAINT DF_Arquivo_Morto_OBSERVACAO  DEFAULT (N''),
        VALOR_DEBITO        DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Arquivo_Morto_DEBITO      DEFAULT (0),
        VALOR_CREDITO       DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Arquivo_Morto_CREDITO     DEFAULT (0),
        DT_MOVIMENTO        DATE           NULL,
        DT_VENCIMENTO       DATE           NULL,
        DT_PAGAMENTO        DATE           NULL,
        CONFIRMADO          BIT            NOT NULL CONSTRAINT DF_Arquivo_Morto_CONFIRMADO  DEFAULT (0),
        EFETUADO            BIT            NOT NULL CONSTRAINT DF_Arquivo_Morto_EFETUADO    DEFAULT (0),
        ID_EMPRESA          INT            NULL,
        ID_PESSOA           INT            NULL,
        ID_CONTA            INT            NULL,
        DT_CARGA            DATETIME2(0)   NOT NULL CONSTRAINT DF_Arquivo_Morto_DT_CARGA    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Arquivo_Morto        PRIMARY KEY CLUSTERED (ID_ARQUIVO_MORTO),
        CONSTRAINT UQ_Arquivo_Morto_ACCESS UNIQUE (ORIGEM_ACCESS, CODIGO_ACCESS)
    );
    CREATE INDEX IX_Arquivo_Morto_DATA   ON [FIN].[Arquivo_Morto] (DT_MOVIMENTO);
    CREATE INDEX IX_Arquivo_Morto_PESSOA ON [FIN].[Arquivo_Morto] (PESSOA);
END;
GO

IF OBJECT_ID(N'[FIN].[Arquivo_Morto_Saldo]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Arquivo_Morto_Saldo]
    (
        ID_ARQUIVO_MORTO_SALDO  INT            IDENTITY(1,1) NOT NULL,
        CONTA                   NVARCHAR(80)   NOT NULL,
        ID_CONTA                INT            NULL,
        DT_SALDO                DATE           NOT NULL,
        SALDO                   DECIMAL(18,2)  NOT NULL,
        DT_CARGA                DATETIME2(0)   NOT NULL CONSTRAINT DF_Arquivo_Morto_Saldo_DT_CARGA DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Arquivo_Morto_Saldo       PRIMARY KEY CLUSTERED (ID_ARQUIVO_MORTO_SALDO),
        CONSTRAINT UQ_Arquivo_Morto_Saldo_CONTA UNIQUE (CONTA, DT_SALDO)
    );
END;
GO
