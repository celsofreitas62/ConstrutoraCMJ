/*******************************************************************************
  Objeto      : [SIS].[Email_Fila_Anexo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Anexos de cada e-mail da fila (PADRAO_EMAIL regras 23 e 24):
                o arquivo fica em disco e aqui só o caminho. O serviço confere
                se o arquivo existe antes de enviar; se não existir, o e-mail
                vai para ERRO (nunca sai sem o anexo).
                NOME_EXIBICAO: nome que o destinatário vê (sem acento e sem
                espaço). CID preenchido = imagem embutida no corpo
                (<img src="cid:...">) em vez de anexo comum.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Fila_Anexo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Fila_Anexo]
    (
        ID_EMAIL_ANEXO  BIGINT          IDENTITY(1,1) NOT NULL,
        ID_EMAIL        BIGINT          NOT NULL,
        CAMINHO         NVARCHAR(1000)  NOT NULL,
        NOME_EXIBICAO   NVARCHAR(260)   NOT NULL,
        CID             VARCHAR(60)     NOT NULL CONSTRAINT DF_Email_Fila_Anexo_CID   DEFAULT (''),
        ORDEM           SMALLINT        NOT NULL CONSTRAINT DF_Email_Fila_Anexo_ORDEM DEFAULT (0),
        CONSTRAINT PK_Email_Fila_Anexo       PRIMARY KEY CLUSTERED (ID_EMAIL_ANEXO),
        CONSTRAINT FK_Email_Fila_Anexo_Email FOREIGN KEY (ID_EMAIL) REFERENCES [SIS].[Email_Fila] (ID_EMAIL),
        CONSTRAINT CK_Email_Fila_Anexo_CAMINHO CHECK (CAMINHO <> N'')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila_Anexo]') AND i.name = N'IX_Email_Fila_Anexo_ID_EMAIL')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_Anexo_ID_EMAIL ON [SIS].[Email_Fila_Anexo] (ID_EMAIL, ORDEM);
GO
