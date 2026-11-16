/*******************************************************************************
  Objeto      : [BANCO].[Conta]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contas da empresa: corrente, poupança, aplicação, CAIXA (dinheiro) e
                PERMUTA (quitação sem dinheiro). Conta de banco exige o banco; caixa e
                permuta não. SALDO_INICIAL + DT_SALDO_INICIAL: saldo de abertura.
                CONCILIA: entra na conciliação; MOSTRA_SALDO: aparece no resumo de
                saldos e no fluxo de caixa. Dados de cobrança do Sicredi ficam no COBR.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Conta]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Conta]
    (
        ID_CONTA            INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA          INT            NOT NULL,
        DESCRICAO           NVARCHAR(60)   NOT NULL,
        TIPO                VARCHAR(10)    NOT NULL,
        ID_BANCO            INT            NULL,
        AGENCIA             VARCHAR(10)    NOT NULL CONSTRAINT DF_Conta_AGENCIA            DEFAULT (''),
        AGENCIA_DV          VARCHAR(2)     NOT NULL CONSTRAINT DF_Conta_AGENCIA_DV         DEFAULT (''),
        NUMERO              VARCHAR(20)    NOT NULL CONSTRAINT DF_Conta_NUMERO             DEFAULT (''),
        NUMERO_DV           VARCHAR(2)     NOT NULL CONSTRAINT DF_Conta_NUMERO_DV          DEFAULT (''),
        LIMITE_CREDITO      DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Conta_LIMITE_CREDITO     DEFAULT (0),
        SALDO_INICIAL       DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Conta_SALDO_INICIAL      DEFAULT (0),
        DT_SALDO_INICIAL    DATE           NULL,
        CONCILIA            BIT            NOT NULL CONSTRAINT DF_Conta_CONCILIA           DEFAULT (0),
        MOSTRA_SALDO        BIT            NOT NULL CONSTRAINT DF_Conta_MOSTRA_SALDO       DEFAULT (1),
        CONTA_CONTABIL_REF  VARCHAR(30)    NOT NULL CONSTRAINT DF_Conta_CONTA_CONTABIL_REF DEFAULT (''),
        ORDEM               SMALLINT       NOT NULL CONSTRAINT DF_Conta_ORDEM              DEFAULT (0),
        ATIVO               BIT            NOT NULL CONSTRAINT DF_Conta_ATIVO              DEFAULT (1),
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Conta_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Conta_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Conta               PRIMARY KEY CLUSTERED (ID_CONTA),
        CONSTRAINT UQ_Conta_DESCRICAO     UNIQUE (ID_EMPRESA, DESCRICAO),
        CONSTRAINT FK_Conta_Empresa       FOREIGN KEY (ID_EMPRESA) REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Conta_Banco         FOREIGN KEY (ID_BANCO)   REFERENCES [BANCO].[Banco] (ID_BANCO),
        CONSTRAINT CK_Conta_TIPO          CHECK (TIPO IN ('CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA')),
        CONSTRAINT CK_Conta_BANCO         CHECK (TIPO IN ('CAIXA', 'PERMUTA') OR ID_BANCO IS NOT NULL),
        CONSTRAINT CK_Conta_SALDO_INICIAL CHECK (SALDO_INICIAL = 0 OR DT_SALDO_INICIAL IS NOT NULL)
    );
END;
GO
