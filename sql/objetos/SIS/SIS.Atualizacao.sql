/*******************************************************************************
  Objeto      : [SIS].[Atualizacao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Histórico das atualizações de versão feitas pelo atualizar.cmd do
                pacote (atualização em um clique, conversa 03h): versões de/para
                do programa e do banco, quando, quanto tempo o sistema ficou fora,
                resultado (CONCLUIDA, DESFEITA = deu erro e voltou sozinho,
                ERRO = deu erro e não conseguiu voltar) e a nota da versão
                (NOTAS_DA_VERSAO.txt do pacote: o que foi corrigido e o que é
                novo). Base da futura tela Sistema › Versões (pedido P22).
                Gravado só por SIS.SIS_Atualizacao_Registrar. Nunca é apagado.

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 03h, banco 1.8).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Atualizacao]', N'U') IS NULL
    CREATE TABLE [SIS].[Atualizacao]
    (
        ID_ATUALIZACAO        INT             IDENTITY(1,1) NOT NULL,
        VERSAO_PROGRAMA_DE    VARCHAR(20)     NOT NULL CONSTRAINT DF_Atualizacao_VERSAO_PROGRAMA_DE DEFAULT (''),
        VERSAO_PROGRAMA_PARA  VARCHAR(20)     NOT NULL,
        VERSAO_BANCO_DE       VARCHAR(20)     NOT NULL CONSTRAINT DF_Atualizacao_VERSAO_BANCO_DE    DEFAULT (''),
        VERSAO_BANCO_PARA     VARCHAR(20)     NOT NULL,
        DT_INICIO             DATETIME2(0)    NOT NULL,
        DT_FIM                DATETIME2(0)    NOT NULL,
        SEGUNDOS_FORA         INT             NOT NULL CONSTRAINT DF_Atualizacao_SEGUNDOS_FORA      DEFAULT (0),
        SITUACAO              VARCHAR(10)     NOT NULL,
        MENSAGEM              NVARCHAR(2000)  NOT NULL CONSTRAINT DF_Atualizacao_MENSAGEM           DEFAULT (N''),
        NOTAS                 NVARCHAR(MAX)   NOT NULL CONSTRAINT DF_Atualizacao_NOTAS              DEFAULT (N''),
        PACOTE                NVARCHAR(260)   NOT NULL CONSTRAINT DF_Atualizacao_PACOTE             DEFAULT (N''),
        USUARIO               NVARCHAR(128)   NOT NULL CONSTRAINT DF_Atualizacao_USUARIO            DEFAULT (SUSER_SNAME()),
        ESTACAO               NVARCHAR(128)   NOT NULL CONSTRAINT DF_Atualizacao_ESTACAO            DEFAULT (ISNULL(HOST_NAME(), N'')),
        DT_REGISTRO           DATETIME2(0)    NOT NULL CONSTRAINT DF_Atualizacao_DT_REGISTRO        DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Atualizacao          PRIMARY KEY CLUSTERED (ID_ATUALIZACAO),
        CONSTRAINT CK_Atualizacao_SITUACAO CHECK (SITUACAO IN ('CONCLUIDA', 'DESFEITA', 'ERRO'))
    );
GO
