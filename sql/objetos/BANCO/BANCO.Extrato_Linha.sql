/*******************************************************************************
  Objeto      : [BANCO].[Extrato_Linha]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Linhas do extrato OFX. FITID (identificador do banco) é único
                por conta. VALOR: positivo entrou, negativo saiu. SITUACAO: PENDENTE
                (sem par no sistema), CONCILIADA (ligada a um BANCO.Movimento) ou
                IGNORADA (decisão do usuário).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Extrato_Linha]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Extrato_Linha]
    (
        ID_EXTRATO_LINHA    BIGINT         IDENTITY(1,1) NOT NULL,
        ID_EXTRATO_ARQUIVO  BIGINT         NOT NULL,
        ID_CONTA            INT            NOT NULL,
        FITID               VARCHAR(100)   NOT NULL,
        DT_LANCAMENTO       DATE           NOT NULL,
        VALOR               DECIMAL(18,2)  NOT NULL,
        TIPO_OFX            VARCHAR(20)    NOT NULL CONSTRAINT DF_Extrato_Linha_TIPO_OFX  DEFAULT (''),
        DOCUMENTO           NVARCHAR(40)   NOT NULL CONSTRAINT DF_Extrato_Linha_DOCUMENTO DEFAULT (N''),
        HISTORICO           NVARCHAR(255)  NOT NULL CONSTRAINT DF_Extrato_Linha_HISTORICO DEFAULT (N''),
        SITUACAO            VARCHAR(10)    NOT NULL CONSTRAINT DF_Extrato_Linha_SITUACAO  DEFAULT ('PENDENTE'),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Extrato_Linha_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Extrato_Linha_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Extrato_Linha          PRIMARY KEY CLUSTERED (ID_EXTRATO_LINHA),
        CONSTRAINT UQ_Extrato_Linha_FITID    UNIQUE (ID_CONTA, FITID),
        CONSTRAINT FK_Extrato_Linha_Arquivo  FOREIGN KEY (ID_EXTRATO_ARQUIVO) REFERENCES [BANCO].[Extrato_Arquivo] (ID_EXTRATO_ARQUIVO),
        CONSTRAINT FK_Extrato_Linha_Conta    FOREIGN KEY (ID_CONTA) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT CK_Extrato_Linha_SITUACAO CHECK (SITUACAO IN ('PENDENTE', 'CONCILIADA', 'IGNORADA'))
    );
    CREATE INDEX IX_Extrato_Linha_CONTA_DATA ON [BANCO].[Extrato_Linha] (ID_CONTA, DT_LANCAMENTO, SITUACAO);
END;
GO
