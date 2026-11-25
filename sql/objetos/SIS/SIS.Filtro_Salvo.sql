/*******************************************************************************
  Objeto      : [SIS].[Filtro_Salvo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Filtros salvos pelo usuário nas listas (ex.: "Vencidos da CMJ"
                em Contas a receber). Um nome por usuário e tela; FILTRO é o
                JSON montado pela tela (a tela sabe ler o próprio filtro).
                PADRAO = 1: a lista já abre com este filtro (no máximo um por
                usuário e tela). Preferência de uso, não dado do negócio: só
                o próprio usuário grava e apaga (SIS_Filtro_Salvo_Gravar /
                _Excluir), sem lixeira e sem auditoria.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Filtro_Salvo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Filtro_Salvo]
    (
        ID_FILTRO_SALVO    INT            IDENTITY(1,1) NOT NULL,
        ID_USUARIO         INT            NOT NULL,
        ITEM               VARCHAR(40)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        FILTRO             NVARCHAR(2000) NOT NULL,
        PADRAO             BIT            NOT NULL CONSTRAINT DF_Filtro_Salvo_PADRAO DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Filtro_Salvo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Filtro_Salvo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Filtro_Salvo         PRIMARY KEY CLUSTERED (ID_FILTRO_SALVO),
        CONSTRAINT FK_Filtro_Salvo_Usuario FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT UQ_Filtro_Salvo_NOME    UNIQUE (ID_USUARIO, ITEM, NOME),
        CONSTRAINT CK_Filtro_Salvo_FILTRO  CHECK (ISJSON(FILTRO) = 1)
    );
    CREATE UNIQUE INDEX UX_Filtro_Salvo_PADRAO ON [SIS].[Filtro_Salvo] (ID_USUARIO, ITEM) WHERE PADRAO = 1;
END;
GO
