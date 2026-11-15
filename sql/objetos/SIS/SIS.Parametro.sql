/*******************************************************************************
  Objeto      : [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros do sistema (seção 3.4 do CLAUDE.md, PADRAO_SQL
                regra 33): nada de valor de negócio fixo no código.
                - CHAVE: maiúsculas, dígitos e "_", no formato MODULO_ASSUNTO.
                - VALOR: sempre gravado no formato canônico do TIPO
                  (INTEIRO "15", DECIMAL "2.5" com ponto, DATA "2026-11-15",
                  SN "S"/"N", EMAIL um endereço só, ARQUIVO nome do arquivo
                  sem pasta (ex.: logo.png; a pasta vem de outro parâmetro),
                  COR "#RRGGBB"; vazio = não configurado).
                - VALOR_PADRAO: valor de fábrica, para "restaurar padrão".
                - EDITAVEL_ADMIN = 0: só o instalador altera (por script).
                A auditoria (antes/depois) entra com a trigger da etapa 02c.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Tipos ARQUIVO e COR (identidade visual por cliente:
                        logomarca e cores sem mexer no sistema).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Parametro]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Parametro]
    (
        ID_PARAMETRO       INT            IDENTITY(1,1) NOT NULL,
        CHAVE              VARCHAR(60)    NOT NULL,
        VALOR              NVARCHAR(4000) NOT NULL CONSTRAINT DF_Parametro_VALOR           DEFAULT (N''),
        VALOR_PADRAO       NVARCHAR(4000) NOT NULL CONSTRAINT DF_Parametro_VALOR_PADRAO    DEFAULT (N''),
        TIPO               VARCHAR(10)    NOT NULL CONSTRAINT DF_Parametro_TIPO            DEFAULT ('TEXTO'),
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Parametro_DESCRICAO       DEFAULT (N''),
        ID_MODULO          INT            NOT NULL,
        EDITAVEL_ADMIN     BIT            NOT NULL CONSTRAINT DF_Parametro_EDITAVEL_ADMIN  DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Parametro_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Parametro_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Parametro        PRIMARY KEY CLUSTERED (ID_PARAMETRO),
        CONSTRAINT UQ_Parametro_CHAVE  UNIQUE (CHAVE),
        CONSTRAINT FK_Parametro_Modulo FOREIGN KEY (ID_MODULO) REFERENCES [SIS].[Modulo] (ID_MODULO),
        CONSTRAINT CK_Parametro_CHAVE  CHECK (CHAVE <> '' AND CHAVE NOT LIKE '%[^A-Z0-9_]%'),
        CONSTRAINT CK_Parametro_TIPO   CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'SN', 'EMAIL', 'ARQUIVO', 'COR'))
    );
END;
GO

-- Ajuste de banco criado com a v1.0 (CHECK sem ARQUIVO e COR)
IF EXISTS (SELECT 1 FROM sys.check_constraints c
           WHERE c.name = N'CK_Parametro_TIPO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Parametro]')
             AND c.definition NOT LIKE N'%ARQUIVO%')
BEGIN
    ALTER TABLE [SIS].[Parametro] DROP CONSTRAINT CK_Parametro_TIPO;
    ALTER TABLE [SIS].[Parametro] ADD CONSTRAINT CK_Parametro_TIPO CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'SN', 'EMAIL', 'ARQUIVO', 'COR'));
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Parametro]') AND i.name = N'IX_Parametro_ID_MODULO')
    CREATE NONCLUSTERED INDEX IX_Parametro_ID_MODULO ON [SIS].[Parametro] (ID_MODULO);
GO
