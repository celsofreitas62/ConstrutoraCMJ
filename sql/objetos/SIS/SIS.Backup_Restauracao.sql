/*******************************************************************************
  Objeto      : [SIS].[Backup_Restauracao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Pedidos de restauração do banco feitos pela tela Sistema >
                Backups (SIS_BACKUP, ação RESTAURAR). A tela só registra o
                pedido (PENDENTE); quem restaura é a tarefa do Windows
                "Restauração (pedidos)" (instalacao\backup_servidor.ps1, como
                SYSTEM), que captura o pedido (EXECUTANDO), faz o backup de
                segurança, restaura e grava o resultado (OK ou ERRO).
                Como a restauração volta esta tabela ao passado, o script
                regrava o pedido no banco restaurado com o mesmo ID
                (SIS_Backup_Restauracao_Resultado, IDENTITY_INSERT).
                TIPO_PONTO: BACKUP (volta para um backup completo ou de
                segurança, ID_BACKUP) ou DATA_HORA (volta para um dia e hora,
                DT_PONTO, com os backups do log de hora em hora).
                Nunca é apagado.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Backup_Restauracao]', N'U') IS NULL
    CREATE TABLE [SIS].[Backup_Restauracao]
    (
        ID_RESTAURACAO       INT             IDENTITY(1,1) NOT NULL,
        TIPO_PONTO           VARCHAR(10)     NOT NULL,
        ID_BACKUP            BIGINT          NULL,
        DT_PONTO             DATETIME2(0)    NULL,
        MOTIVO               NVARCHAR(400)   NOT NULL,
        SITUACAO             VARCHAR(12)     NOT NULL CONSTRAINT DF_Backup_Restauracao_SITUACAO  DEFAULT ('PENDENTE'),
        ID_USUARIO_PEDIDO    INT             NOT NULL,
        USUARIO_PEDIDO       NVARCHAR(100)   NOT NULL CONSTRAINT DF_Backup_Restauracao_USUARIO_PEDIDO DEFAULT (N''),
        DT_PEDIDO            DATETIME2(0)    NOT NULL CONSTRAINT DF_Backup_Restauracao_DT_PEDIDO DEFAULT (SYSDATETIME()),
        DT_INICIO            DATETIME2(0)    NULL,
        DT_FIM               DATETIME2(0)    NULL,
        PLANO                NVARCHAR(4000)  NOT NULL CONSTRAINT DF_Backup_Restauracao_PLANO     DEFAULT (N''),
        ARQUIVO_SEGURANCA    NVARCHAR(400)   NOT NULL CONSTRAINT DF_Backup_Restauracao_ARQUIVO_SEGURANCA DEFAULT (N''),
        MENSAGEM             NVARCHAR(2000)  NOT NULL CONSTRAINT DF_Backup_Restauracao_MENSAGEM  DEFAULT (N''),
        SERVIDOR             NVARCHAR(128)   NOT NULL CONSTRAINT DF_Backup_Restauracao_SERVIDOR  DEFAULT (ISNULL(HOST_NAME(), N'')),
        DT_CRIACAO           DATETIME2(0)    NOT NULL CONSTRAINT DF_Backup_Restauracao_DT_CRIACAO DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)   NOT NULL CONSTRAINT DF_Backup_Restauracao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)    NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)   NULL,
        CONSTRAINT PK_Backup_Restauracao            PRIMARY KEY CLUSTERED (ID_RESTAURACAO),
        CONSTRAINT FK_Backup_Restauracao_Backup     FOREIGN KEY (ID_BACKUP) REFERENCES [SIS].[Backup_Execucao] (ID_BACKUP),
        CONSTRAINT CK_Backup_Restauracao_TIPO_PONTO CHECK (TIPO_PONTO IN ('BACKUP', 'DATA_HORA')),
        CONSTRAINT CK_Backup_Restauracao_PONTO      CHECK ((TIPO_PONTO = 'BACKUP' AND ID_BACKUP IS NOT NULL) OR (TIPO_PONTO = 'DATA_HORA' AND DT_PONTO IS NOT NULL)),
        CONSTRAINT CK_Backup_Restauracao_SITUACAO   CHECK (SITUACAO IN ('PENDENTE', 'EXECUTANDO', 'OK', 'ERRO', 'CANCELADO'))
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Backup_Restauracao]') AND i.name = N'IX_Backup_Restauracao_SITUACAO')
    CREATE NONCLUSTERED INDEX IX_Backup_Restauracao_SITUACAO ON [SIS].[Backup_Restauracao] (SITUACAO, DT_PEDIDO);
GO
