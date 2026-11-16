/*******************************************************************************
  Objeto      : [SIS].[Rotina_Execucao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico de cada execução das rotinas automáticas: quando,
                por quê (AGENDA ou MANUAL, com quem pediu), quanto tempo
                levou e o resultado (OK / ERRO, com a mensagem). O erro
                detalhado fica também em SIS.Log_Erro (gravado pela própria
                rotina ou pela SIS_Rotina_Processar).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Rotina_Execucao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Rotina_Execucao]
    (
        ID_EXECUCAO   BIGINT          IDENTITY(1,1) NOT NULL,
        ID_ROTINA     INT             NOT NULL,
        ORIGEM        VARCHAR(10)     NOT NULL,
        SOLICITANTE   NVARCHAR(100)   NOT NULL CONSTRAINT DF_Rotina_Execucao_SOLICITANTE DEFAULT (N''),
        SERVIDOR      NVARCHAR(128)   NOT NULL CONSTRAINT DF_Rotina_Execucao_SERVIDOR    DEFAULT (N''),
        DT_INICIO     DATETIME2(0)    NOT NULL CONSTRAINT DF_Rotina_Execucao_DT_INICIO   DEFAULT (SYSDATETIME()),
        DT_FIM        DATETIME2(0)    NULL,
        RESULTADO     VARCHAR(10)     NOT NULL CONSTRAINT DF_Rotina_Execucao_RESULTADO   DEFAULT ('EXECUTANDO'),
        MENSAGEM      NVARCHAR(1000)  NOT NULL CONSTRAINT DF_Rotina_Execucao_MENSAGEM    DEFAULT (N''),
        CONSTRAINT PK_Rotina_Execucao          PRIMARY KEY CLUSTERED (ID_EXECUCAO),
        CONSTRAINT FK_Rotina_Execucao_Rotina   FOREIGN KEY (ID_ROTINA) REFERENCES [SIS].[Rotina] (ID_ROTINA),
        CONSTRAINT CK_Rotina_Execucao_ORIGEM   CHECK (ORIGEM IN ('AGENDA', 'MANUAL')),
        CONSTRAINT CK_Rotina_Execucao_RESULTADO CHECK (RESULTADO IN ('EXECUTANDO', 'OK', 'ERRO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Rotina_Execucao]') AND i.name = N'IX_Rotina_Execucao_ID_ROTINA')
    CREATE NONCLUSTERED INDEX IX_Rotina_Execucao_ID_ROTINA ON [SIS].[Rotina_Execucao] (ID_ROTINA, ID_EXECUCAO);
GO
