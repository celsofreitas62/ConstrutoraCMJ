/*******************************************************************************
  Objeto      : [BANCO].[Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Lista de bancos (código COMPE de 3 dígitos e ISPB de 8 dígitos,
                usado no PIX). Usada nas contas da empresa (BANCO.Conta) e nos dados
                bancários das pessoas (CAD.Pessoa_Dado_Bancario). Carga inicial com os
                principais bancos; o administrador acrescenta outros.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Banco]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Banco]
    (
        ID_BANCO           INT            IDENTITY(1,1) NOT NULL,
        CODIGO             CHAR(3)        NOT NULL,
        ISPB               VARCHAR(8)     NOT NULL CONSTRAINT DF_Banco_ISPB  DEFAULT (''),
        NOME               NVARCHAR(80)   NOT NULL,
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Banco_ATIVO DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Banco_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Banco_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Banco        PRIMARY KEY CLUSTERED (ID_BANCO),
        CONSTRAINT UQ_Banco_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Banco_CODIGO CHECK (CODIGO NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_Banco_ISPB   CHECK (ISPB = '' OR (LEN(ISPB) = 8 AND ISPB NOT LIKE '%[^0-9]%'))
    );
END;
GO
