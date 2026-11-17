/*******************************************************************************
  Objeto      : [FIN].[Historico_Padrao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Históricos padrão do lançamento (Pgto efetuado, NF nº, Salário,
                impostos...). Ajudam a digitar e a filtrar; o texto livre continua
                no HISTORICO do lançamento.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Historico_Padrao]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Historico_Padrao]
    (
        ID_HISTORICO_PADRAO  INT            IDENTITY(1,1) NOT NULL,
        DESCRICAO            NVARCHAR(80)   NOT NULL,
        ATIVO                BIT            NOT NULL CONSTRAINT DF_Historico_Padrao_ATIVO DEFAULT (1),
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Historico_Padrao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Historico_Padrao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Historico_Padrao           PRIMARY KEY CLUSTERED (ID_HISTORICO_PADRAO),
        CONSTRAINT UQ_Historico_Padrao_DESCRICAO UNIQUE (DESCRICAO),
        CONSTRAINT CK_Historico_Padrao_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO
