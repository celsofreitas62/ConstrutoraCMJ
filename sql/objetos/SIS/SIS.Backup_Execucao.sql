/*******************************************************************************
  Objeto      : [SIS].[Backup_Execucao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Registro de cada backup feito pelo script do servidor
                (instalacao\backup_servidor.ps1, tarefas agendadas do Windows):
                COMPLETO (diário), LOG (de hora em hora), TESTE (restauração de
                conferência, semanal) e SEGURANCA (feito logo antes de uma
                restauração pedida pela tela). Serve para a tela de backups e
                restauração, para os avisos de atraso/falha
                (SIS_Backup_Conferir_Processar) e para a auditoria.
                Os arquivos ficam no disco (parâmetro BACKUP_PASTA); aqui só a
                referência. Nunca é apagado (o arquivo pode ser, pela retenção:
                ARQUIVO_EXISTE = 0).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor). Nome com sufixo:
                        BACKUP é palavra reservada do SQL Server.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Nome antigo (BACKUP é palavra reservada do SQL): apaga se ficou vazio de um ensaio de 20/11/2026
IF OBJECT_ID(N'[SIS].[Backup]', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM [SIS].[Backup])
        DROP TABLE [SIS].[Backup];
END;
GO

IF OBJECT_ID(N'[SIS].[Backup_Execucao]', N'U') IS NULL
    CREATE TABLE [SIS].[Backup_Execucao]
    (
        ID_BACKUP        BIGINT          IDENTITY(1,1) NOT NULL,
        TIPO             VARCHAR(10)     NOT NULL,
        ARQUIVO          NVARCHAR(400)   NOT NULL CONSTRAINT DF_Backup_Execucao_ARQUIVO        DEFAULT (N''),
        DT_INICIO        DATETIME2(0)    NOT NULL,
        DT_FIM           DATETIME2(0)    NULL,
        TAMANHO_MB       DECIMAL(12,1)   NOT NULL CONSTRAINT DF_Backup_Execucao_TAMANHO_MB     DEFAULT (0),
        SITUACAO         VARCHAR(10)     NOT NULL,
        MENSAGEM         NVARCHAR(2000)  NOT NULL CONSTRAINT DF_Backup_Execucao_MENSAGEM       DEFAULT (N''),
        COPIA_NUVEM      BIT             NOT NULL CONSTRAINT DF_Backup_Execucao_COPIA_NUVEM    DEFAULT (0),
        ARQUIVO_EXISTE   BIT             NOT NULL CONSTRAINT DF_Backup_Execucao_ARQUIVO_EXISTE DEFAULT (1),
        SERVIDOR         NVARCHAR(128)   NOT NULL CONSTRAINT DF_Backup_Execucao_SERVIDOR       DEFAULT (ISNULL(HOST_NAME(), N'')),
        DT_REGISTRO      DATETIME2(0)    NOT NULL CONSTRAINT DF_Backup_Execucao_DT_REGISTRO    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Backup_Execucao          PRIMARY KEY CLUSTERED (ID_BACKUP),
        CONSTRAINT CK_Backup_Execucao_TIPO     CHECK (TIPO IN ('COMPLETO', 'LOG', 'TESTE', 'SEGURANCA')),
        CONSTRAINT CK_Backup_Execucao_SITUACAO CHECK (SITUACAO IN ('OK', 'ERRO'))
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Backup_Execucao]') AND i.name = N'IX_Backup_Execucao_TIPO_DT')
    CREATE NONCLUSTERED INDEX IX_Backup_Execucao_TIPO_DT ON [SIS].[Backup_Execucao] (TIPO, SITUACAO, DT_INICIO);
GO
