/*******************************************************************************
  Objeto      : [SIS].[Aviso_Confirmado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Registro de cada aviso que o usuário confirmou ("Gravar mesmo
                assim") e de cada exceção usada com motivo (ex.: lançamento
                retroativo), P17. Uma linha por aviso: tabela e registro
                gravados, código da regra, texto mostrado ao usuário, motivo
                (quando a regra pede), quem e quando. Base também do check-up
                diário (P25). Só a procedure que grava inclui linhas; ninguém
                altera nem apaga (sem tela de manutenção).
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Aviso_Confirmado]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Aviso_Confirmado]
    (
        ID_AVISO_CONFIRMADO  BIGINT         IDENTITY(1,1) NOT NULL,
        TABELA               NVARCHAR(256)  NOT NULL,
        ID_REGISTRO          BIGINT         NOT NULL,
        CODIGO_REGRA         VARCHAR(40)    NOT NULL,
        NIVEL                VARCHAR(12)    NOT NULL,
        MENSAGEM             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Aviso_Confirmado_MENSAGEM DEFAULT (N''),
        MOTIVO               NVARCHAR(400)  NOT NULL CONSTRAINT DF_Aviso_Confirmado_MOTIVO   DEFAULT (N''),
        ID_REFERENCIA        BIGINT         NULL,
        ID_USUARIO           INT            NULL,
        DT_CRIACAO           DATETIME2(0)   NOT NULL CONSTRAINT DF_Aviso_Confirmado_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Aviso_Confirmado_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        CONSTRAINT PK_Aviso_Confirmado        PRIMARY KEY CLUSTERED (ID_AVISO_CONFIRMADO),
        CONSTRAINT FK_Aviso_Confirmado_Usuario FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Aviso_Confirmado_NIVEL  CHECK (NIVEL IN ('AVISO', 'MOTIVO'))
    );
    CREATE INDEX IX_Aviso_Confirmado_REGISTRO ON [SIS].[Aviso_Confirmado] (TABELA, ID_REGISTRO);
    CREATE INDEX IX_Aviso_Confirmado_DATA     ON [SIS].[Aviso_Confirmado] (DT_CRIACAO);
END;
GO
