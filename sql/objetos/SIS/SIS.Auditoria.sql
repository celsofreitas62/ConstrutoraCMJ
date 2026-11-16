/*******************************************************************************
  Objeto      : [SIS].[Auditoria]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico de toda inclusão, alteração e exclusão nas tabelas
                auditadas (seção 3.7 do CLAUDE.md). Gravado só pelas triggers
                geradas por SIS_Auditoria_Trigger_Gerar.
                  OPERACAO 'I' (inclusão) e 'E' (exclusão): uma linha, com a
                  "foto" do registro inteiro em JSON (VALOR_DEPOIS na inclusão,
                  VALOR_ANTES na exclusão); CAMPO vazio.
                  OPERACAO 'A' (alteração): uma linha por campo que mudou, com
                  o valor antes e depois.
                  Campos sigilosos (senha) aparecem como "***".
                USUARIO, ESTACAO, ORIGEM e ID_LOTE vêm do SESSION_CONTEXT
                (SIS_Contexto_Gravar); TRANSACAO agrupa o que foi gravado junto.
                NINGUÉM ALTERA NEM APAGA: a trigger tg_SIS_Auditoria_Protecao
                recusa UPDATE e DELETE, e o papel da API (02d) recebe DENY.
                Limite honesto: um administrador do Windows/SQL Server consegue
                desligar a trigger (seção 3.5).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Auditoria]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Auditoria]
    (
        ID_AUDITORIA  BIGINT          IDENTITY(1,1) NOT NULL,
        TABELA        NVARCHAR(256)   NOT NULL,
        ID_REGISTRO   BIGINT          NOT NULL,
        OPERACAO      CHAR(1)         NOT NULL,
        CAMPO         NVARCHAR(128)   NOT NULL CONSTRAINT DF_Auditoria_CAMPO       DEFAULT (N''),
        VALOR_ANTES   NVARCHAR(MAX)   NULL,
        VALOR_DEPOIS  NVARCHAR(MAX)   NULL,
        USUARIO       NVARCHAR(100)   NOT NULL CONSTRAINT DF_Auditoria_USUARIO     DEFAULT (N''),
        ID_USUARIO    INT             NULL,
        ESTACAO       NVARCHAR(128)   NOT NULL CONSTRAINT DF_Auditoria_ESTACAO     DEFAULT (N''),
        ORIGEM        NVARCHAR(256)   NOT NULL CONSTRAINT DF_Auditoria_ORIGEM      DEFAULT (N''),
        ID_LOTE       BIGINT          NULL,
        TRANSACAO     BIGINT          NULL,
        DT_OPERACAO   DATETIME2(0)    NOT NULL CONSTRAINT DF_Auditoria_DT_OPERACAO DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Auditoria          PRIMARY KEY CLUSTERED (ID_AUDITORIA),
        CONSTRAINT CK_Auditoria_OPERACAO CHECK (OPERACAO IN ('I', 'A', 'E'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Auditoria]') AND i.name = N'IX_Auditoria_TABELA_ID_REGISTRO')
    CREATE NONCLUSTERED INDEX IX_Auditoria_TABELA_ID_REGISTRO ON [SIS].[Auditoria] (TABELA, ID_REGISTRO, ID_AUDITORIA);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Auditoria]') AND i.name = N'IX_Auditoria_DT_OPERACAO')
    CREATE NONCLUSTERED INDEX IX_Auditoria_DT_OPERACAO ON [SIS].[Auditoria] (DT_OPERACAO) INCLUDE (USUARIO, TABELA, OPERACAO);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Auditoria]') AND i.name = N'IX_Auditoria_ID_LOTE')
    CREATE NONCLUSTERED INDEX IX_Auditoria_ID_LOTE ON [SIS].[Auditoria] (ID_LOTE) WHERE ID_LOTE IS NOT NULL;
GO
