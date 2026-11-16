/*******************************************************************************
  Objeto      : [SIS].[Modulo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Módulos do sistema (CAD, FIN, VENDA...). Base do menu lateral,
                das permissões e da licença: LIBERADO_LICENCA é atualizado só
                pela procedure da licença (etapa 02b), nunca por tela.
                HABILITADO: liberado para uso pelo administrador geral (tela
                "Módulos e telas"); módulo novo nasce desabilitado, para poder
                ser instalado em desenvolvimento sem aparecer. O módulo só é
                usado se estiver na licença E habilitado. SIS sempre habilitado.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (16/11/2026) - HABILITADO (pedido 5 do Celso, etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Modulo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Modulo]
    (
        ID_MODULO          INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(10)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        ORDEM_MENU         SMALLINT       NOT NULL CONSTRAINT DF_Modulo_ORDEM_MENU       DEFAULT (0),
        ICONE              VARCHAR(40)    NOT NULL CONSTRAINT DF_Modulo_ICONE            DEFAULT (''),
        LIBERADO_LICENCA   BIT            NOT NULL CONSTRAINT DF_Modulo_LIBERADO_LICENCA DEFAULT (0),
        HABILITADO         BIT            NOT NULL CONSTRAINT DF_Modulo_HABILITADO       DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Modulo_ATIVO            DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Modulo_DT_CRIACAO       DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Modulo_USUARIO_CRIACAO  DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Modulo        PRIMARY KEY CLUSTERED (ID_MODULO),
        CONSTRAINT UQ_Modulo_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Modulo_CODIGO CHECK (CODIGO <> '' AND CODIGO NOT LIKE '%[^A-Z]%')
    );
END;
GO

-- Ajuste de banco criado com a v1.0: coluna nova; SIS já nasce habilitado
IF COL_LENGTH(N'SIS.Modulo', N'HABILITADO') IS NULL
BEGIN
    ALTER TABLE [SIS].[Modulo] ADD HABILITADO BIT NOT NULL CONSTRAINT DF_Modulo_HABILITADO DEFAULT (0);
    EXEC (N'UPDATE m SET m.HABILITADO = 1 FROM SIS.Modulo m WHERE m.CODIGO = ''SIS'';');
END;
GO
