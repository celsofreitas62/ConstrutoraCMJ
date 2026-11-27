/*******************************************************************************
  Objeto      : [SIS].[Usuario_Preferencia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : O que cada usuário escolheu para si em cada preferência do
                catálogo SIS.Preferencia (P03 e P06). Sem linha = segue o
                padrão (parâmetro da preferência). VALOR no formato canônico
                do TIPO (SN = 'S'/'N'; INTEIRO sem separador; opção em
                maiúsculas). Preferência do próprio usuário, não dado do
                negócio: só ele grava (SIS_Preferencia_Gravar), sem lixeira e
                sem auditoria (como SIS.Filtro_Salvo).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Usuario_Preferencia]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Usuario_Preferencia]
    (
        ID_USUARIO_PREFERENCIA INT            IDENTITY(1,1) NOT NULL,
        ID_USUARIO             INT            NOT NULL,
        ID_PREFERENCIA         INT            NOT NULL,
        VALOR                  NVARCHAR(400)  NOT NULL,
        DT_CRIACAO             DATETIME2(0)   NOT NULL CONSTRAINT DF_Usuario_Preferencia_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO        NVARCHAR(100)  NOT NULL CONSTRAINT DF_Usuario_Preferencia_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO           DATETIME2(0)   NULL,
        USUARIO_ALTERACAO      NVARCHAR(100)  NULL,
        CONSTRAINT PK_Usuario_Preferencia            PRIMARY KEY CLUSTERED (ID_USUARIO_PREFERENCIA),
        CONSTRAINT UQ_Usuario_Preferencia            UNIQUE (ID_USUARIO, ID_PREFERENCIA),
        CONSTRAINT FK_Usuario_Preferencia_Usuario    FOREIGN KEY (ID_USUARIO)     REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT FK_Usuario_Preferencia_Preferencia FOREIGN KEY (ID_PREFERENCIA) REFERENCES [SIS].[Preferencia] (ID_PREFERENCIA)
    );
END;
GO
