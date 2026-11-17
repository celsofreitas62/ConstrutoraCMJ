/*******************************************************************************
  Objeto      : [SIS].[Comunicado_Item]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Itens do comunicado, em linguagem simples e sem dados técnicos,
                cada um numa seção: IMPLANTADO (em uso na CMJ), EM_TESTE e
                PROXIMA_FASE. O Claude atualiza no fim de cada fase; o Celso ajusta
                pela tela Comunicados.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado_Item]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado_Item]
    (
        ID_COMUNICADO_ITEM  INT            IDENTITY(1,1) NOT NULL,
        ID_COMUNICADO       INT            NOT NULL,
        SECAO               VARCHAR(15)    NOT NULL,
        TEXTO               NVARCHAR(300)  NOT NULL,
        ORDEM               SMALLINT       NOT NULL CONSTRAINT DF_Comunicado_Item_ORDEM DEFAULT (0),
        ATIVO               BIT            NOT NULL CONSTRAINT DF_Comunicado_Item_ATIVO DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_Item_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Item_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado_Item            PRIMARY KEY CLUSTERED (ID_COMUNICADO_ITEM),
        CONSTRAINT FK_Comunicado_Item_Comunicado FOREIGN KEY (ID_COMUNICADO) REFERENCES [SIS].[Comunicado] (ID_COMUNICADO),
        CONSTRAINT CK_Comunicado_Item_SECAO      CHECK (SECAO IN ('IMPLANTADO', 'EM_TESTE', 'PROXIMA_FASE')),
        CONSTRAINT CK_Comunicado_Item_TEXTO      CHECK (TEXTO <> N'')
    );
END;
GO
