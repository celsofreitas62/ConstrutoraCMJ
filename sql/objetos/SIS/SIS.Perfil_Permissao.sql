/*******************************************************************************
  Objeto      : [SIS].[Perfil_Permissao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Ações permitidas a cada perfil. Linha existe = permitido.
                Tirar a permissão apaga a linha (é configuração, não
                movimento; a auditoria da etapa 02c registra quem tirou).
                Perfil de administrador (NIVEL_ADMIN 1 ou 2) não usa esta tabela.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Perfil_Permissao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Perfil_Permissao]
    (
        ID_PERFIL_PERMISSAO INT            IDENTITY(1,1) NOT NULL,
        ID_PERFIL           INT            NOT NULL,
        ID_ITEM_ACAO        INT            NOT NULL,
        DT_CRIACAO          DATETIME2(0)   NOT NULL CONSTRAINT DF_Perfil_Permissao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Perfil_Permissao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO        DATETIME2(0)   NULL,
        USUARIO_ALTERACAO   NVARCHAR(100)  NULL,
        CONSTRAINT PK_Perfil_Permissao           PRIMARY KEY CLUSTERED (ID_PERFIL_PERMISSAO),
        CONSTRAINT UQ_Perfil_Permissao           UNIQUE (ID_PERFIL, ID_ITEM_ACAO),
        CONSTRAINT FK_Perfil_Permissao_Perfil    FOREIGN KEY (ID_PERFIL)    REFERENCES [SIS].[Perfil] (ID_PERFIL),
        CONSTRAINT FK_Perfil_Permissao_Item_Acao FOREIGN KEY (ID_ITEM_ACAO) REFERENCES [SIS].[Item_Acao] (ID_ITEM_ACAO)
    );
END;
GO
