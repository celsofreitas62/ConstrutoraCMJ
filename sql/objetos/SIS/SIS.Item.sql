/*******************************************************************************
  Objeto      : [SIS].[Item]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Itens do menu de cada módulo (seção 3.6 e menu lateral em
                drill-down, seção 3 item 8):
                  TIPO = 'MENU' : agrupador (abre subníveis), sem tela;
                  TIPO = 'TELA' : abre a página CAMINHO (relativo ao wwwroot).
                ID_ITEM_PAI: item agrupador acima (NULL = direto no módulo).
                CODIGO: único no banco, prefixado pelo módulo (ex.: SIS_USUARIO);
                é por ele que as procedures conferem a permissão.
                EXCLUSIVO_GERAL = 1: tela só do administrador geral (nível 2):
                não aparece para mais ninguém e não pode ser dada a perfil nem
                a usuário (ex.: Licença, Parâmetros).
                Itens e ações são criados só por carga (script), nunca por tela.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - EXCLUSIVO_GERAL (dois níveis de administrador).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Item]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Item]
    (
        ID_ITEM            INT            IDENTITY(1,1) NOT NULL,
        ID_MODULO          INT            NOT NULL,
        ID_ITEM_PAI        INT            NULL,
        CODIGO             VARCHAR(40)    NOT NULL,
        NOME               NVARCHAR(80)   NOT NULL,
        TIPO               VARCHAR(10)    NOT NULL CONSTRAINT DF_Item_TIPO            DEFAULT ('TELA'),
        CAMINHO            VARCHAR(200)   NOT NULL CONSTRAINT DF_Item_CAMINHO         DEFAULT (''),
        ICONE              VARCHAR(40)    NOT NULL CONSTRAINT DF_Item_ICONE           DEFAULT (''),
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Item_ORDEM           DEFAULT (0),
        EXCLUSIVO_GERAL    BIT            NOT NULL CONSTRAINT DF_Item_EXCLUSIVO_GERAL DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Item_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Item_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Item_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Item         PRIMARY KEY CLUSTERED (ID_ITEM),
        CONSTRAINT UQ_Item_CODIGO  UNIQUE (CODIGO),
        CONSTRAINT FK_Item_Modulo  FOREIGN KEY (ID_MODULO)   REFERENCES [SIS].[Modulo] (ID_MODULO),
        CONSTRAINT FK_Item_Item    FOREIGN KEY (ID_ITEM_PAI) REFERENCES [SIS].[Item] (ID_ITEM),
        CONSTRAINT CK_Item_TIPO    CHECK (TIPO IN ('MENU', 'TELA')),
        CONSTRAINT CK_Item_CODIGO  CHECK (CODIGO <> '' AND CODIGO NOT LIKE '%[^A-Z0-9_]%'),
        CONSTRAINT CK_Item_PAI     CHECK (ID_ITEM_PAI IS NULL OR ID_ITEM_PAI <> ID_ITEM)
    );
END;
GO

IF COL_LENGTH(N'SIS.Item', N'EXCLUSIVO_GERAL') IS NULL
    ALTER TABLE [SIS].[Item] ADD EXCLUSIVO_GERAL BIT NOT NULL CONSTRAINT DF_Item_EXCLUSIVO_GERAL DEFAULT (0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Item]') AND i.name = N'IX_Item_ID_MODULO')
    CREATE NONCLUSTERED INDEX IX_Item_ID_MODULO ON [SIS].[Item] (ID_MODULO, ID_ITEM_PAI);
GO
