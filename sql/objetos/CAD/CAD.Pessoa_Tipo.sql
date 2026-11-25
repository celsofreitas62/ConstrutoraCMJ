/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Tipos de cada parceiro (P12; vários por parceiro). Tipo
                retirado na tela é desativado (não apagado), como os contatos.
                As marcas CLIENTE/FORNECEDOR/FUNCIONARIO/CORRETOR de CAD.Pessoa
                continuam e são acertadas pelo CAD_Pessoa_Gravar a partir dos
                tipos do sistema (compatibilidade com as regras e a migração).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Tipo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Tipo]
    (
        ID_PESSOA_TIPO     INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA          INT            NOT NULL,
        ID_PARCEIRO_TIPO   INT            NOT NULL,
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Pessoa_Tipo_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Tipo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Tipo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Tipo          PRIMARY KEY CLUSTERED (ID_PESSOA_TIPO),
        CONSTRAINT FK_Pessoa_Tipo_Pessoa   FOREIGN KEY (ID_PESSOA)        REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Pessoa_Tipo_Tipo     FOREIGN KEY (ID_PARCEIRO_TIPO) REFERENCES [CAD].[Parceiro_Tipo] (ID_PARCEIRO_TIPO),
        CONSTRAINT UQ_Pessoa_Tipo          UNIQUE (ID_PESSOA, ID_PARCEIRO_TIPO)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_Tipo_Tipo' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Tipo]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_Tipo_Tipo ON [CAD].[Pessoa_Tipo] (ID_PARCEIRO_TIPO, ATIVO) INCLUDE (ID_PESSOA);
GO
