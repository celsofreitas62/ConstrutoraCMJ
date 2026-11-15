/*******************************************************************************
  Objeto      : [SIS].[Item_Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Quais ações existem em cada tela (ex.: "Títulos a pagar" tem
                BAIXAR e ESTORNAR; "Clientes" não). É sobre estas linhas que
                as permissões de perfil e de usuário são dadas.
                Criadas só por carga.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Item_Acao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Item_Acao]
    (
        ID_ITEM_ACAO       INT            IDENTITY(1,1) NOT NULL,
        ID_ITEM            INT            NOT NULL,
        ID_ACAO            INT            NOT NULL,
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Item_Acao_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Item_Acao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Item_Acao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Item_Acao      PRIMARY KEY CLUSTERED (ID_ITEM_ACAO),
        CONSTRAINT UQ_Item_Acao      UNIQUE (ID_ITEM, ID_ACAO),
        CONSTRAINT FK_Item_Acao_Item FOREIGN KEY (ID_ITEM) REFERENCES [SIS].[Item] (ID_ITEM),
        CONSTRAINT FK_Item_Acao_Acao FOREIGN KEY (ID_ACAO) REFERENCES [SIS].[Acao] (ID_ACAO)
    );
END;
GO
