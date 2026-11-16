/*******************************************************************************
  Objeto      : [SIS].[Comando]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Catálogo dos comandos de instalação e manutenção (pedidos 2 e
                4 do Celso, 16/11/2026): cada linha vira um botão da tela
                "Instalação e manutenção", exclusiva do administrador geral.
                O SQL nunca executa comando do Windows: o botão grava um
                pedido em SIS.Comando_Fila e o serviço do sistema executa o
                que estiver na SUA lista fixa para aquele CODIGO (nada de
                texto de comando vindo do banco).
                PERIGOSO = 1: a API pede a senha de novo e uma confirmação
                antes de gravar o pedido.
                ACEITA_PARAMETRO = 1: o botão pede um valor (ex.: nome do
                arquivo do pacote), validado aqui e de novo pelo serviço.
                Cadastrado só por carga (Carga_SIS_Comando.sql).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comando]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comando]
    (
        ID_COMANDO           INT             IDENTITY(1,1) NOT NULL,
        CODIGO               VARCHAR(40)     NOT NULL,
        NOME                 NVARCHAR(80)    NOT NULL,
        DESCRICAO            NVARCHAR(1000)  NOT NULL CONSTRAINT DF_Comando_DESCRICAO           DEFAULT (N''),
        GRUPO                VARCHAR(20)     NOT NULL,
        ORDEM                SMALLINT        NOT NULL CONSTRAINT DF_Comando_ORDEM               DEFAULT (0),
        PERIGOSO             BIT             NOT NULL CONSTRAINT DF_Comando_PERIGOSO            DEFAULT (0),
        ACEITA_PARAMETRO     BIT             NOT NULL CONSTRAINT DF_Comando_ACEITA_PARAMETRO    DEFAULT (0),
        PARAMETRO_DESCRICAO  NVARCHAR(200)   NOT NULL CONSTRAINT DF_Comando_PARAMETRO_DESCRICAO DEFAULT (N''),
        ATIVO                BIT             NOT NULL CONSTRAINT DF_Comando_ATIVO               DEFAULT (1),
        DT_CRIACAO           DATETIME2(0)    NOT NULL CONSTRAINT DF_Comando_DT_CRIACAO          DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)   NOT NULL CONSTRAINT DF_Comando_USUARIO_CRIACAO     DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)    NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)   NULL,
        CONSTRAINT PK_Comando        PRIMARY KEY CLUSTERED (ID_COMANDO),
        CONSTRAINT UQ_Comando_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Comando_CODIGO CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Comando_GRUPO  CHECK (GRUPO IN ('INSTALACAO', 'ATUALIZACAO', 'BACKUP', 'SERVICO', 'DIAGNOSTICO'))
    );
END;
GO
