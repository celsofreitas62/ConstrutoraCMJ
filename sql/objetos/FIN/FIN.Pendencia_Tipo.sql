/*******************************************************************************
  Objeto      : [FIN].[Pendencia_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Tipos de pendência manual dos lançamentos (P27). Cadastrados
                pela CMJ na tela Financeiro › Tipos de pendência.
                APLICA_A      P = só contas a pagar, R = só a receber, A = ambos.
                BLOQUEIA_BAIXA 1 = enquanto houver pendência aberta deste tipo
                              o lançamento não pode ser baixado (a baixa, na
                              04g, confere por FIN.fn_FIN_Pendencia_Bloqueia);
                              0 = só avisa.
                ORIENTACAO    texto de ajuda: o que fazer para resolver.
                SISTEMA = 1: tipo usado pelo próprio sistema (MIGRACAO, "Veio
                da migração – conferir"); não pode ser excluído nem ter o
                código mudado.
                As pendências automáticas (sem centro, sem conta etc.) não
                usam esta tabela: são calculadas na hora por
                FIN.fn_FIN_Lancamento_Pendencias.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c, P27).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Pendencia_Tipo]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Pendencia_Tipo]
    (
        ID_PENDENCIA_TIPO  INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(20)    NOT NULL,
        DESCRICAO          NVARCHAR(60)   NOT NULL,
        ORIENTACAO         NVARCHAR(400)  NOT NULL CONSTRAINT DF_Pendencia_Tipo_ORIENTACAO      DEFAULT (N''),
        APLICA_A           CHAR(1)        NOT NULL CONSTRAINT DF_Pendencia_Tipo_APLICA_A        DEFAULT ('A'),
        BLOQUEIA_BAIXA     BIT            NOT NULL CONSTRAINT DF_Pendencia_Tipo_BLOQUEIA_BAIXA  DEFAULT (0),
        SISTEMA            BIT            NOT NULL CONSTRAINT DF_Pendencia_Tipo_SISTEMA         DEFAULT (0),
        ORDEM              INT            NOT NULL CONSTRAINT DF_Pendencia_Tipo_ORDEM           DEFAULT (100),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Pendencia_Tipo_ATIVO           DEFAULT (1),
        DT_EXCLUSAO        DATETIME2(0)   NULL,
        USUARIO_EXCLUSAO   NVARCHAR(100)  NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pendencia_Tipo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pendencia_Tipo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pendencia_Tipo          PRIMARY KEY CLUSTERED (ID_PENDENCIA_TIPO),
        CONSTRAINT UQ_Pendencia_Tipo_CODIGO   UNIQUE (CODIGO),
        CONSTRAINT CK_Pendencia_Tipo_CODIGO   CHECK (CODIGO <> ''),
        CONSTRAINT CK_Pendencia_Tipo_DESC     CHECK (DESCRICAO <> N''),
        CONSTRAINT CK_Pendencia_Tipo_APLICA_A CHECK (APLICA_A IN ('P', 'R', 'A'))
    );
END;
GO
