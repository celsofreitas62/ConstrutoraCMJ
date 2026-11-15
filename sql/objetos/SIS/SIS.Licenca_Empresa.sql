/*******************************************************************************
  Objeto      : [SIS].[Licenca_Empresa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Empresas (CNPJ e razão social) liberadas por uma licença:
                uma ou mais (CMJ e eventuais SPEs). A marcada como PRINCIPAL
                é a que aparece nos rodapés de e-mail e relatórios quando a
                rotina não é de uma empresa específica.
                Ninguém altera por tela: vem da chave assinada.
                CNPJ: 14 posições, só dígitos e letras maiúsculas (aceita o
                CNPJ alfanumérico).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Licenca_Empresa]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Licenca_Empresa]
    (
        ID_LICENCA_EMPRESA INT            IDENTITY(1,1) NOT NULL,
        ID_LICENCA         INT            NOT NULL,
        CNPJ               VARCHAR(14)    NOT NULL,
        RAZAO_SOCIAL       NVARCHAR(150)  NOT NULL,
        NOME_FANTASIA      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Licenca_Empresa_NOME_FANTASIA   DEFAULT (N''),
        PRINCIPAL          BIT            NOT NULL CONSTRAINT DF_Licenca_Empresa_PRINCIPAL       DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Licenca_Empresa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Licenca_Empresa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Licenca_Empresa         PRIMARY KEY CLUSTERED (ID_LICENCA_EMPRESA),
        CONSTRAINT FK_Licenca_Empresa_Licenca FOREIGN KEY (ID_LICENCA) REFERENCES [SIS].[Licenca] (ID_LICENCA),
        CONSTRAINT UQ_Licenca_Empresa_CNPJ    UNIQUE (ID_LICENCA, CNPJ),
        CONSTRAINT CK_Licenca_Empresa_CNPJ    CHECK (LEN(CNPJ) = 14 AND CNPJ NOT LIKE '%[^0-9A-Z]%')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Licenca_Empresa]') AND i.name = N'UQ_Licenca_Empresa_PRINCIPAL')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Licenca_Empresa_PRINCIPAL ON [SIS].[Licenca_Empresa] (ID_LICENCA) WHERE PRINCIPAL = 1;
GO
