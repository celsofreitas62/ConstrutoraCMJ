/*******************************************************************************
  Objeto      : [SIS].[Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Ações que podem ser permitidas numa tela (seção 3.6): VER,
                INCLUIR, ALTERAR, EXCLUIR e as especiais (BAIXAR, ESTORNAR,
                REABRIR...). Quais ações cada tela tem: SIS.Item_Acao.
                Criadas só por carga.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Acao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Acao]
    (
        ID_ACAO            INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(20)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Acao_ORDEM           DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Acao_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Acao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Acao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Acao        PRIMARY KEY CLUSTERED (ID_ACAO),
        CONSTRAINT UQ_Acao_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Acao_CODIGO CHECK (CODIGO <> '' AND CODIGO NOT LIKE '%[^A-Z_]%')
    );
END;
GO
