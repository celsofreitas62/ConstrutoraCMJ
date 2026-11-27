/*******************************************************************************
  Objeto      : [SIS].[Preferencia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Catálogo das preferências que cada usuário pode escolher para
                si (tela Preferências; P03 e P06): como a tela inicial abre,
                período padrão, tema claro/escuro etc. Cada preferência tem o
                seu padrão num parâmetro (CHAVE_PARAMETRO em SIS.Parametro),
                que a administradora muda pela tela Parâmetros de uso; o
                usuário que não escolheu nada segue o padrão. TIPO e OPCOES
                seguem as mesmas regras de SIS.Parametro. Criadas só por carga
                (Carga_SIS_Preferencia.sql), nunca por tela.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Preferencia]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Preferencia]
    (
        ID_PREFERENCIA     INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(40)    NOT NULL,
        NOME               NVARCHAR(80)   NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Preferencia_DESCRICAO       DEFAULT (N''),
        GRUPO              NVARCHAR(60)   NOT NULL,
        TIPO               VARCHAR(10)    NOT NULL CONSTRAINT DF_Preferencia_TIPO            DEFAULT ('TEXTO'),
        OPCOES             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Preferencia_OPCOES          DEFAULT (N''),
        VALOR_MINIMO       INT            NULL,
        VALOR_MAXIMO       INT            NULL,
        CHAVE_PARAMETRO    VARCHAR(60)    NOT NULL,
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Preferencia_ORDEM           DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Preferencia_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Preferencia_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Preferencia_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Preferencia        PRIMARY KEY CLUSTERED (ID_PREFERENCIA),
        CONSTRAINT UQ_Preferencia_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Preferencia_TIPO   CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'SN'))
    );
END;
GO
