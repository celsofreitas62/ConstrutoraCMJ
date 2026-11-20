/*******************************************************************************
  Objeto      : [SIS].[Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Histórico das instalações do banco: cada vez que o MASTER (ou o
                pacote do desenvolvimento) roda, grava a versão instalada, quando
                e por quem. A versão atual é a do registro mais recente
                (SIS.fn_SIS_Versao_Banco). A API confere essa versão ao subir:
                programa e banco têm de estar na mesma versão (CLAUDE.md seção 7,
                fase 3d). Nunca é apagado.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Versao_Banco]', N'U') IS NULL
    CREATE TABLE [SIS].[Versao_Banco]
    (
        ID_VERSAO_BANCO  INT            IDENTITY(1,1) NOT NULL,
        VERSAO           VARCHAR(20)    NOT NULL,
        ORIGEM           VARCHAR(20)    NOT NULL,
        DT_INSTALACAO    DATETIME2(0)   NOT NULL CONSTRAINT DF_Versao_Banco_DT_INSTALACAO DEFAULT (SYSDATETIME()),
        USUARIO          NVARCHAR(128)  NOT NULL CONSTRAINT DF_Versao_Banco_USUARIO       DEFAULT (SUSER_SNAME()),
        ESTACAO          NVARCHAR(128)  NOT NULL CONSTRAINT DF_Versao_Banco_ESTACAO       DEFAULT (ISNULL(HOST_NAME(), N'')),
        CONSTRAINT PK_Versao_Banco        PRIMARY KEY CLUSTERED (ID_VERSAO_BANCO),
        CONSTRAINT CK_Versao_Banco_ORIGEM CHECK (ORIGEM IN ('MASTER', 'PACOTE_LOCAL'))
    );
GO
