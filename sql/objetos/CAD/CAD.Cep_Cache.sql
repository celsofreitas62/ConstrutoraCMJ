/*******************************************************************************
  Objeto      : [CAD].[Cep_Cache]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Endereços já consultados pelo CEP (ViaCEP / BrasilAPI), para
                não repetir a consulta na internet. Gravado pela API depois de
                uma consulta bem-sucedida; validade em parâmetro (CEP_CACHE_DIAS).
                Dado público (Correios): não é dado pessoal.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Cep_Cache]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Cep_Cache]
    (
        CEP                VARCHAR(8)     NOT NULL,
        LOGRADOURO         NVARCHAR(150)  NOT NULL CONSTRAINT DF_Cep_Cache_LOGRADOURO DEFAULT (N''),
        COMPLEMENTO        NVARCHAR(60)   NOT NULL CONSTRAINT DF_Cep_Cache_COMPLEMENTO DEFAULT (N''),
        BAIRRO             NVARCHAR(60)   NOT NULL CONSTRAINT DF_Cep_Cache_BAIRRO     DEFAULT (N''),
        CIDADE             NVARCHAR(60)   NOT NULL,
        UF                 CHAR(2)        NOT NULL,
        CODIGO_IBGE        VARCHAR(7)     NOT NULL CONSTRAINT DF_Cep_Cache_IBGE       DEFAULT (''),
        FONTE              VARCHAR(20)    NOT NULL,
        DT_CONSULTA        DATETIME2(0)   NOT NULL CONSTRAINT DF_Cep_Cache_DT         DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Cep_Cache     PRIMARY KEY CLUSTERED (CEP),
        CONSTRAINT CK_Cep_Cache_CEP CHECK (LEN(CEP) = 8 AND CEP NOT LIKE '%[^0-9]%')
    );
END;
GO
