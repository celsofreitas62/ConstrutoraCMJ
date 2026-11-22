/*******************************************************************************
  Objeto      : [SIS].[Tabela_Config]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Configuração, por tabela, do desfazer pelo histórico e da
                lixeira (P20, docs/requisitos/Lixeira_Desfazer.md). Nada fixo
                no código: cada tabela diz o que pode e o que não pode.
                  PERMITE_DESFAZER   voltar campos pelo histórico
                  PERMITE_LIXEIRA    botão Excluir manda para a lixeira (a
                                     tabela precisa ter ATIVO, DT_EXCLUSAO e
                                     USUARIO_EXCLUSAO)
                  DIAS_GUARDA        prazo próprio da lixeira (NULL = vale o
                                     parâmetro LIXEIRA_DIAS_GUARDA); única
                                     coluna que a CMJ muda (tela da Lixeira)
                  CAMPOS_BLOQUEADOS  campos que nunca são desfeitos (saldos,
                                     calculados, senha), separados por vírgula
                  CAMPOS_UNICOS      conferidos na recuperação contra os
                                     registros vivos (ex.: CPF_CNPJ)
                  TABELAS_FILHAS     registros que "vão junto":
                                     SCHEMA.Tabela.COLUNA_FK, separados por
                                     vírgula (voltar a uma data e apagar de vez)
                  DESFAZER_INCLUSAO  o que fazer ao desfazer uma inclusão:
                                     LIXEIRA, DESATIVAR (ATIVO = 0), APAGAR
                                     (só tabelas de ligação, ex.: permissões)
                                     ou RECUSAR
                  DESFAZER_EXCLUSAO  o que fazer ao desfazer uma exclusão
                                     definitiva: REINSERIR (só tabelas de
                                     ligação: volta com a foto da auditoria,
                                     com ID novo) ou RECUSAR
                  DESCRICAO_SQL      expressão com as colunas da tabela que
                                     descreve o registro na lixeira e na prévia
                                     (só pela carga da instalação, nunca pela
                                     tela)
                  COLUNA_EMPRESA +
                  COLUNA_DATA_MES    trava de mês fechado (FIN.Mes_Fechado)
                  PROC_VALIDAR       procedure própria de trava (ex.: boleto no
                                     banco, P16): recebe @Tabela, @IdRegistro,
                                     @Operacao e devolve @Mensagem OUTPUT
                                     (vazia = pode)
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b, P20).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Tabela_Config]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Tabela_Config]
    (
        ID_TABELA_CONFIG   INT            IDENTITY(1,1) NOT NULL,
        TABELA             NVARCHAR(256)  NOT NULL,
        PERMITE_DESFAZER   BIT            NOT NULL CONSTRAINT DF_Tabela_Config_PERMITE_DESFAZER  DEFAULT (1),
        PERMITE_LIXEIRA    BIT            NOT NULL CONSTRAINT DF_Tabela_Config_PERMITE_LIXEIRA   DEFAULT (0),
        DIAS_GUARDA        INT            NULL,
        CAMPOS_BLOQUEADOS  NVARCHAR(1000) NOT NULL CONSTRAINT DF_Tabela_Config_CAMPOS_BLOQUEADOS DEFAULT (N''),
        CAMPOS_UNICOS      NVARCHAR(400)  NOT NULL CONSTRAINT DF_Tabela_Config_CAMPOS_UNICOS     DEFAULT (N''),
        TABELAS_FILHAS     NVARCHAR(1000) NOT NULL CONSTRAINT DF_Tabela_Config_TABELAS_FILHAS    DEFAULT (N''),
        DESFAZER_INCLUSAO  VARCHAR(10)    NOT NULL CONSTRAINT DF_Tabela_Config_DESFAZER_INCLUSAO DEFAULT ('RECUSAR'),
        DESFAZER_EXCLUSAO  VARCHAR(10)    NOT NULL CONSTRAINT DF_Tabela_Config_DESFAZER_EXCLUSAO DEFAULT ('RECUSAR'),
        DESCRICAO_SQL      NVARCHAR(1000) NOT NULL CONSTRAINT DF_Tabela_Config_DESCRICAO_SQL     DEFAULT (N''),
        COLUNA_EMPRESA     NVARCHAR(128)  NOT NULL CONSTRAINT DF_Tabela_Config_COLUNA_EMPRESA    DEFAULT (N''),
        COLUNA_DATA_MES    NVARCHAR(128)  NOT NULL CONSTRAINT DF_Tabela_Config_COLUNA_DATA_MES   DEFAULT (N''),
        PROC_VALIDAR       NVARCHAR(256)  NOT NULL CONSTRAINT DF_Tabela_Config_PROC_VALIDAR      DEFAULT (N''),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Tabela_Config_ATIVO             DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Tabela_Config_DT_CRIACAO        DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Tabela_Config_USUARIO_CRIACAO   DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Tabela_Config                   PRIMARY KEY CLUSTERED (ID_TABELA_CONFIG),
        CONSTRAINT UQ_Tabela_Config_TABELA            UNIQUE (TABELA),
        CONSTRAINT CK_Tabela_Config_DESFAZER_INCLUSAO CHECK (DESFAZER_INCLUSAO IN ('LIXEIRA', 'DESATIVAR', 'APAGAR', 'RECUSAR')),
        CONSTRAINT CK_Tabela_Config_DESFAZER_EXCLUSAO CHECK (DESFAZER_EXCLUSAO IN ('REINSERIR', 'RECUSAR')),
        CONSTRAINT CK_Tabela_Config_DIAS_GUARDA       CHECK (DIAS_GUARDA IS NULL OR DIAS_GUARDA BETWEEN 1 AND 3650)
    );
END;
GO
