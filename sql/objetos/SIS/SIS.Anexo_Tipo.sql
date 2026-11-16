/*******************************************************************************
  Objeto      : [SIS].[Anexo_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tipos de anexo (contrato, nota fiscal, comprovante, acordo,
                boleto, logomarca, outro) e as extensões aceitas em cada um
                (EXTENSOES: lista separada por vírgula, minúsculas, sem ponto).
                Criados por carga; o administrador pode desativar.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Anexo_Tipo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Anexo_Tipo]
    (
        ID_ANEXO_TIPO      INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(30)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        EXTENSOES          VARCHAR(200)   NOT NULL CONSTRAINT DF_Anexo_Tipo_EXTENSOES       DEFAULT (''),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Anexo_Tipo_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Anexo_Tipo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Anexo_Tipo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Anexo_Tipo        PRIMARY KEY CLUSTERED (ID_ANEXO_TIPO),
        CONSTRAINT UQ_Anexo_Tipo_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Anexo_Tipo_CODIGO CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO
