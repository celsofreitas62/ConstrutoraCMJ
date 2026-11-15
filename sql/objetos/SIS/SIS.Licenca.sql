/*******************************************************************************
  Objeto      : [SIS].[Licenca]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Licença de uso (seção 3.5 do CLAUDE.md). Guarda a chave
                assinada pelo desenvolvedor exatamente como foi recebida
                (CHAVE_LICENCA) e uma cópia legível do que ela libera.
                QUEM CONFERE A ASSINATURA É A API (o SQL não verifica
                assinatura digital); a API só grava por SIS_Licenca_Gravar
                depois de validar a chave, e confere de novo a cada início e
                login. Só uma licença ativa por vez (índice único filtrado);
                as anteriores ficam guardadas, inativas.
                MODULOS: códigos liberados separados por vírgula (ex.: CAD,FIN).
                Empresas (CNPJ/razão social): SIS.Licenca_Empresa.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Licenca]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Licenca]
    (
        ID_LICENCA         INT            IDENTITY(1,1) NOT NULL,
        CHAVE_LICENCA      NVARCHAR(MAX)  NOT NULL,
        ID_SERVIDOR        VARCHAR(200)   NOT NULL CONSTRAINT DF_Licenca_ID_SERVIDOR     DEFAULT (''),
        DT_EMISSAO         DATE           NOT NULL,
        DT_VALIDADE        DATE           NULL,
        MODULOS            VARCHAR(400)   NOT NULL CONSTRAINT DF_Licenca_MODULOS         DEFAULT (''),
        ATIVA              BIT            NOT NULL CONSTRAINT DF_Licenca_ATIVA           DEFAULT (1),
        DT_DESATIVACAO     DATETIME2(0)   NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Licenca_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Licenca_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Licenca          PRIMARY KEY CLUSTERED (ID_LICENCA),
        CONSTRAINT CK_Licenca_VALIDADE CHECK (DT_VALIDADE IS NULL OR DT_VALIDADE >= DT_EMISSAO)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Licenca]') AND i.name = N'UQ_Licenca_ATIVA')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Licenca_ATIVA ON [SIS].[Licenca] (ATIVA) WHERE ATIVA = 1;
GO
