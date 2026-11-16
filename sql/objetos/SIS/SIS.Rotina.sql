/*******************************************************************************
  Objeto      : [SIS].[Rotina]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Agenda das rotinas automáticas (SQL Server Express não tem
                Agent). O serviço do sistema chama SIS_Rotina_Processar a
                cada minuto; ela roda, uma de cada vez, as rotinas vencidas.
                As rotinas são cadastradas só por carga (lista fixa de
                procedures, sem parâmetro): pela tela muda-se apenas a agenda,
                ligar/desligar e "executar agora".
                FREQUENCIA: MINUTOS (INTERVALO_MINUTOS), DIARIA (HORARIO),
                SEMANAL (DIAS_SEMANA '2,3,4,5,6', 1 = domingo, e HORARIO),
                MENSAL (DIA_MES; 31 = último dia do mês, e HORARIO).
                Só roda se o módulo da rotina estiver na licença e
                habilitado.
                Colunas de execução (PROXIMA_EXECUCAO em diante) não entram
                na auditoria (mudam a cada execução); o histórico de cada
                execução fica em SIS.Rotina_Execucao.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Rotina]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Rotina]
    (
        ID_ROTINA             INT            IDENTITY(1,1) NOT NULL,
        CODIGO                VARCHAR(40)    NOT NULL,
        NOME                  NVARCHAR(80)   NOT NULL,
        DESCRICAO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Rotina_DESCRICAO       DEFAULT (N''),
        PROCEDIMENTO          NVARCHAR(256)  NOT NULL,
        ID_MODULO             INT            NOT NULL,
        FREQUENCIA            VARCHAR(10)    NOT NULL,
        INTERVALO_MINUTOS     INT            NOT NULL CONSTRAINT DF_Rotina_INTERVALO       DEFAULT (0),
        HORARIO               TIME(0)        NOT NULL CONSTRAINT DF_Rotina_HORARIO         DEFAULT ('00:00'),
        DIAS_SEMANA           VARCHAR(20)    NOT NULL CONSTRAINT DF_Rotina_DIAS_SEMANA     DEFAULT (''),
        DIA_MES               TINYINT        NOT NULL CONSTRAINT DF_Rotina_DIA_MES         DEFAULT (0),
        TEMPO_LIMITE_MINUTOS  INT            NOT NULL CONSTRAINT DF_Rotina_TEMPO_LIMITE    DEFAULT (60),
        ATIVA                 BIT            NOT NULL CONSTRAINT DF_Rotina_ATIVA           DEFAULT (1),
        PROXIMA_EXECUCAO      DATETIME2(0)   NULL,
        SOLICITADA_POR        NVARCHAR(100)  NOT NULL CONSTRAINT DF_Rotina_SOLICITADA_POR  DEFAULT (N''),
        EM_EXECUCAO           BIT            NOT NULL CONSTRAINT DF_Rotina_EM_EXECUCAO     DEFAULT (0),
        DT_INICIO_EXECUCAO    DATETIME2(0)   NULL,
        ULTIMA_EXECUCAO       DATETIME2(0)   NULL,
        ULTIMO_RESULTADO      VARCHAR(10)    NOT NULL CONSTRAINT DF_Rotina_ULTIMO_RESULTADO DEFAULT (''),
        ULTIMA_MENSAGEM       NVARCHAR(1000) NOT NULL CONSTRAINT DF_Rotina_ULTIMA_MENSAGEM  DEFAULT (N''),
        DT_CRIACAO            DATETIME2(0)   NOT NULL CONSTRAINT DF_Rotina_DT_CRIACAO       DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO       NVARCHAR(100)  NOT NULL CONSTRAINT DF_Rotina_USUARIO_CRIACAO  DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO          DATETIME2(0)   NULL,
        USUARIO_ALTERACAO     NVARCHAR(100)  NULL,
        CONSTRAINT PK_Rotina            PRIMARY KEY CLUSTERED (ID_ROTINA),
        CONSTRAINT UQ_Rotina_CODIGO     UNIQUE (CODIGO),
        CONSTRAINT FK_Rotina_Modulo     FOREIGN KEY (ID_MODULO) REFERENCES [SIS].[Modulo] (ID_MODULO),
        CONSTRAINT CK_Rotina_CODIGO     CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Rotina_FREQUENCIA CHECK (FREQUENCIA IN ('MINUTOS', 'DIARIA', 'SEMANAL', 'MENSAL')),
        CONSTRAINT CK_Rotina_AGENDA     CHECK (   (FREQUENCIA = 'MINUTOS' AND INTERVALO_MINUTOS BETWEEN 1 AND 1440)
                                               OR (FREQUENCIA = 'DIARIA')
                                               OR (FREQUENCIA = 'SEMANAL' AND DIAS_SEMANA <> '' AND DIAS_SEMANA NOT LIKE '%[^1-7,]%')
                                               OR (FREQUENCIA = 'MENSAL'  AND DIA_MES BETWEEN 1 AND 31)),
        CONSTRAINT CK_Rotina_TEMPO_LIMITE CHECK (TEMPO_LIMITE_MINUTOS BETWEEN 1 AND 1440)
    );
END;
GO
