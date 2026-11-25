/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Contato]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contatos de cada pessoa (vários e-mails e telefones). RECEBE_COBRANCA:
                recebe boleto, régua de cobrança e extrato. Telefones gravados só com
                dígitos. Contato removido na tela é desativado (não apagado).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (25/11/2026) - Etapa 04d (P12): FINALIDADE (COBRANCA, COMPRAS, FINANCEIRO ou vazio)
                        e um só PRINCIPAL ativo por pessoa e tipo (índice único filtrado;
                        duplicados antigos: fica principal o de menor código).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Contato]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Contato]
    (
        ID_PESSOA_CONTATO  INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA          INT            NOT NULL,
        TIPO               VARCHAR(10)    NOT NULL,
        VALOR              NVARCHAR(256)  NOT NULL,
        NOME_CONTATO       NVARCHAR(80)   NOT NULL CONSTRAINT DF_Pessoa_Contato_NOME_CONTATO    DEFAULT (N''),
        PRINCIPAL          BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_PRINCIPAL       DEFAULT (0),
        RECEBE_COBRANCA    BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_RECEBE_COBRANCA DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Contato_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Contato_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Contato        PRIMARY KEY CLUSTERED (ID_PESSOA_CONTATO),
        CONSTRAINT FK_Pessoa_Contato_Pessoa FOREIGN KEY (ID_PESSOA) REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT CK_Pessoa_Contato_TIPO   CHECK (TIPO IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP')),
        CONSTRAINT CK_Pessoa_Contato_VALOR  CHECK (VALOR <> N'')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_Contato_Pessoa' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Contato]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_Contato_Pessoa ON [CAD].[Pessoa_Contato] (ID_PESSOA);
GO

IF COL_LENGTH(N'CAD.Pessoa_Contato', N'FINALIDADE') IS NULL
    ALTER TABLE [CAD].[Pessoa_Contato] ADD FINALIDADE VARCHAR(15) NOT NULL CONSTRAINT DF_Pessoa_Contato_FINALIDADE DEFAULT ('');
GO
IF OBJECT_ID(N'[CAD].[CK_Pessoa_Contato_FINALIDADE]', N'C') IS NULL
    ALTER TABLE [CAD].[Pessoa_Contato] ADD CONSTRAINT CK_Pessoa_Contato_FINALIDADE CHECK (FINALIDADE IN ('', 'COBRANCA', 'COMPRAS', 'FINANCEIRO'));
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_Pessoa_Contato_Principal' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Contato]'))
BEGIN
    WITH d AS (SELECT c.PRINCIPAL, ROW_NUMBER() OVER (PARTITION BY c.ID_PESSOA, c.TIPO ORDER BY c.ID_PESSOA_CONTATO) AS N
               FROM CAD.Pessoa_Contato c WHERE c.PRINCIPAL = 1 AND c.ATIVO = 1)
    UPDATE d SET PRINCIPAL = 0 WHERE N > 1;
    CREATE UNIQUE NONCLUSTERED INDEX UX_Pessoa_Contato_Principal ON [CAD].[Pessoa_Contato] (ID_PESSOA, TIPO) WHERE PRINCIPAL = 1 AND ATIVO = 1;
END;
GO
