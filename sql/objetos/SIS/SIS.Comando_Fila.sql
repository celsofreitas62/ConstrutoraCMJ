/*******************************************************************************
  Objeto      : [SIS].[Comando_Fila]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Pedidos de execução dos comandos de instalação e manutenção
                (SIS.Comando). Quem pediu, de onde, quando começou e
                terminou, código de saída e a saída do comando. Os comandos
                rodam um de cada vez, na ordem dos pedidos.
                STATUS: PENDENTE > EXECUTANDO > CONCLUIDO | ERRO; CANCELADO
                (só enquanto pendente). Não é apagado.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comando_Fila]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comando_Fila]
    (
        ID_PEDIDO             BIGINT          IDENTITY(1,1) NOT NULL,
        ID_COMANDO            INT             NOT NULL,
        PARAMETRO             NVARCHAR(400)   NOT NULL CONSTRAINT DF_Comando_Fila_PARAMETRO      DEFAULT (N''),
        STATUS                VARCHAR(12)     NOT NULL CONSTRAINT DF_Comando_Fila_STATUS         DEFAULT ('PENDENTE'),
        DT_PEDIDO             DATETIME2(0)    NOT NULL CONSTRAINT DF_Comando_Fila_DT_PEDIDO      DEFAULT (SYSDATETIME()),
        USUARIO_PEDIDO        NVARCHAR(100)   NOT NULL,
        ESTACAO_PEDIDO        NVARCHAR(128)   NOT NULL CONSTRAINT DF_Comando_Fila_ESTACAO        DEFAULT (N''),
        DT_INICIO             DATETIME2(0)    NULL,
        DT_FIM                DATETIME2(0)    NULL,
        SERVIDOR              NVARCHAR(128)   NOT NULL CONSTRAINT DF_Comando_Fila_SERVIDOR       DEFAULT (N''),
        CODIGO_SAIDA          INT             NULL,
        SAIDA                 NVARCHAR(MAX)   NOT NULL CONSTRAINT DF_Comando_Fila_SAIDA          DEFAULT (N''),
        DT_CANCELAMENTO       DATETIME2(0)    NULL,
        USUARIO_CANCELAMENTO  NVARCHAR(100)   NOT NULL CONSTRAINT DF_Comando_Fila_USUARIO_CANC   DEFAULT (N''),
        CONSTRAINT PK_Comando_Fila         PRIMARY KEY CLUSTERED (ID_PEDIDO),
        CONSTRAINT FK_Comando_Fila_Comando FOREIGN KEY (ID_COMANDO) REFERENCES [SIS].[Comando] (ID_COMANDO),
        CONSTRAINT CK_Comando_Fila_STATUS  CHECK (STATUS IN ('PENDENTE', 'EXECUTANDO', 'CONCLUIDO', 'ERRO', 'CANCELADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Comando_Fila]') AND i.name = N'IX_Comando_Fila_STATUS')
    CREATE NONCLUSTERED INDEX IX_Comando_Fila_STATUS ON [SIS].[Comando_Fila] (STATUS, ID_PEDIDO);
GO
