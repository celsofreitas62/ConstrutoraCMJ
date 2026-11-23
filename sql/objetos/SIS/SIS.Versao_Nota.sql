/*******************************************************************************
  Objeto      : [SIS].[Versao_Nota]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Notas de cada versão do sistema, um item por linha (o que é
                novo, o que melhorou, o que foi corrigido), para a tela
                Sistema › Versões, o aviso "O que há de novo" e o e-mail da
                nota depois de cada atualização (pedido P22).
                Fonte única: docs/NOTAS_DA_VERSAO.md, convertido em
                Carga_SIS_Versao_Nota.sql por sql/ferramentas/montar_notas.py
                e carregado pelo MASTER (toda instalação já nasce com o
                histórico completo das notas). Não tem tela de manutenção.
                PUBLICO: TODOS ou GERAL (só o administrador geral vê).
                TEXTO = texto puro (busca); TEXTO_HTML = com <b> e <code>,
                gerado pelo montar_notas.py (já escapado).
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Versao_Nota]', N'U') IS NULL
    CREATE TABLE [SIS].[Versao_Nota]
    (
        ID_VERSAO_NOTA  INT             IDENTITY(1,1) NOT NULL,
        VERSAO          VARCHAR(20)     NOT NULL,
        VERSAO_NUMERO   INT             NOT NULL,
        DT_VERSAO       DATE            NULL,
        ORDEM           SMALLINT        NOT NULL,
        TIPO            VARCHAR(10)     NOT NULL,
        PUBLICO         VARCHAR(10)     NOT NULL CONSTRAINT DF_Versao_Nota_PUBLICO    DEFAULT ('TODOS'),
        TEXTO           NVARCHAR(2000)  NOT NULL,
        TEXTO_HTML      NVARCHAR(4000)  NOT NULL,
        DT_CRIACAO      DATETIME2(0)    NOT NULL CONSTRAINT DF_Versao_Nota_DT_CRIACAO DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Versao_Nota               PRIMARY KEY CLUSTERED (ID_VERSAO_NOTA),
        CONSTRAINT UQ_Versao_Nota_VERSAO_ORDEM  UNIQUE (VERSAO, ORDEM),
        CONSTRAINT CK_Versao_Nota_TIPO          CHECK (TIPO IN ('NOVO', 'MELHORIA', 'CORRECAO')),
        CONSTRAINT CK_Versao_Nota_PUBLICO       CHECK (PUBLICO IN ('TODOS', 'GERAL'))
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Versao_Nota_VERSAO_NUMERO' AND object_id = OBJECT_ID(N'[SIS].[Versao_Nota]'))
    CREATE NONCLUSTERED INDEX IX_Versao_Nota_VERSAO_NUMERO ON [SIS].[Versao_Nota] (VERSAO_NUMERO DESC, ORDEM);
GO
