/*******************************************************************************
  Objeto      : [FIN].[Mes_Fechado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Fechamento de mês por empresa (item 10 da seção 3.3 e pedido 10).
                Mês fechado bloqueia incluir, alterar, baixar e estornar só os
                lançamentos em conta do plano marcada como CONTABIL. Reabrir exige
                permissão e fica na auditoria. MES = primeiro dia do mês.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Mes_Fechado]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Mes_Fechado]
    (
        ID_MES_FECHADO     INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA         INT            NOT NULL,
        MES                DATE           NOT NULL,
        FECHADO            BIT            NOT NULL CONSTRAINT DF_Mes_Fechado_FECHADO DEFAULT (1),
        OBSERVACAO         NVARCHAR(400)  NOT NULL CONSTRAINT DF_Mes_Fechado_OBSERVACAO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Mes_Fechado_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Mes_Fechado_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Mes_Fechado          PRIMARY KEY CLUSTERED (ID_MES_FECHADO),
        CONSTRAINT UQ_Mes_Fechado_MES      UNIQUE (ID_EMPRESA, MES),
        CONSTRAINT FK_Mes_Fechado_Empresa  FOREIGN KEY (ID_EMPRESA) REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT CK_Mes_Fechado_MES      CHECK (DAY(MES) = 1)
    );
END;
GO
