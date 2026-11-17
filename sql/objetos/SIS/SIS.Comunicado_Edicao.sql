/*******************************************************************************
  Objeto      : [SIS].[Comunicado_Edicao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Cada edição semanal do comunicado: período (segunda a sexta),
                assunto e HTML montados na prévia. O e-mail oficial leva
                exatamente o que foi aprovado. SITUACAO: PREVIA (aguardando
                aprovação) -> ENVIADA, ou DESCARTADA (substituída por prévia nova ou
                descartada na tela). Uma edição ENVIADA por comunicado e semana.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado_Edicao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado_Edicao]
    (
        ID_COMUNICADO_EDICAO  BIGINT         IDENTITY(1,1) NOT NULL,
        ID_COMUNICADO         INT            NOT NULL,
        DT_INICIO             DATE           NOT NULL,
        DT_FIM                DATE           NOT NULL,
        ASSUNTO               NVARCHAR(400)  NOT NULL,
        CORPO_HTML            NVARCHAR(MAX)  NOT NULL,
        SITUACAO              VARCHAR(10)    NOT NULL CONSTRAINT DF_Comunicado_Edicao_SITUACAO DEFAULT ('PREVIA'),
        ID_EMAIL_PREVIA       BIGINT         NULL,
        ID_EMAIL_OFICIAL      BIGINT         NULL,
        DT_APROVACAO          DATETIME2(0)   NULL,
        USUARIO_APROVACAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Edicao_USUARIO_APROVACAO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_Edicao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Edicao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado_Edicao            PRIMARY KEY CLUSTERED (ID_COMUNICADO_EDICAO),
        CONSTRAINT FK_Comunicado_Edicao_Comunicado FOREIGN KEY (ID_COMUNICADO) REFERENCES [SIS].[Comunicado] (ID_COMUNICADO),
        CONSTRAINT CK_Comunicado_Edicao_SITUACAO   CHECK (SITUACAO IN ('PREVIA', 'ENVIADA', 'DESCARTADA')),
        CONSTRAINT CK_Comunicado_Edicao_PERIODO    CHECK (DT_FIM >= DT_INICIO)
    );
    CREATE UNIQUE INDEX UQ_Comunicado_Edicao_ENVIADA ON [SIS].[Comunicado_Edicao] (ID_COMUNICADO, DT_INICIO) WHERE SITUACAO = 'ENVIADA';
END;
GO
