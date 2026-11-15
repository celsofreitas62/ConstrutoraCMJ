/*******************************************************************************
  Objeto      : [SIS].[Usuario_Permissao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Exceções individuais em relação ao perfil do usuário:
                  TIPO = 'C' concede uma ação que o perfil não tem;
                  TIPO = 'R' retira uma ação que o perfil tem.
                Sem linha = vale o perfil. Retirada não se aplica a usuário de
                perfil de administrador (para ninguém trancar o administrador).
                Tela EXCLUSIVO_GERAL nunca entra aqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Usuario_Permissao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Usuario_Permissao]
    (
        ID_USUARIO_PERMISSAO INT            IDENTITY(1,1) NOT NULL,
        ID_USUARIO           INT            NOT NULL,
        ID_ITEM_ACAO         INT            NOT NULL,
        TIPO                 CHAR(1)        NOT NULL,
        DT_CRIACAO           DATETIME2(0)   NOT NULL CONSTRAINT DF_Usuario_Permissao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Usuario_Permissao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)   NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)  NULL,
        CONSTRAINT PK_Usuario_Permissao           PRIMARY KEY CLUSTERED (ID_USUARIO_PERMISSAO),
        CONSTRAINT UQ_Usuario_Permissao           UNIQUE (ID_USUARIO, ID_ITEM_ACAO),
        CONSTRAINT FK_Usuario_Permissao_Usuario   FOREIGN KEY (ID_USUARIO)   REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT FK_Usuario_Permissao_Item_Acao FOREIGN KEY (ID_ITEM_ACAO) REFERENCES [SIS].[Item_Acao] (ID_ITEM_ACAO),
        CONSTRAINT CK_Usuario_Permissao_TIPO      CHECK (TIPO IN ('C', 'R'))
    );
END;
GO
