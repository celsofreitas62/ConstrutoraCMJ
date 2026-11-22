/*******************************************************************************
  Pacote      : 04b - historico padrao: desfazer pela auditoria e lixeira (P20); banco 2.0
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 22/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04a já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/04b_Homologacao_Lixeira_Desfazer.sql, 04a, 03a e 02b.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Banco errado: este pacote só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Auditoria.sql
-- =============================================================================
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
    v1.1 (22/11/2026) - Etapa 04b (P20): índice por TRANSACAO (desfazer uma
                        operação inteira pelo histórico).
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
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Auditoria]') AND i.name = N'IX_Auditoria_TRANSACAO')
    CREATE NONCLUSTERED INDEX IX_Auditoria_TRANSACAO ON [SIS].[Auditoria] (TRANSACAO, ID_AUDITORIA) WHERE TRANSACAO IS NOT NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Tabela_Config.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Lixeira.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Lixeira]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Registros mandados para a lixeira pelo botão Excluir das telas
                (P20). O registro continua na tabela dele, desativado e com
                DT_EXCLUSAO preenchida; esta tabela guarda de onde veio (tela),
                quem excluiu, o motivo, como estava o ATIVO antes e até quando
                fica guardado (DT_APAGAR).
                SITUACAO: LIXEIRA (pode recuperar), RECUPERADO (voltou) ou
                APAGADO (apagado de vez pela rotina diária ou pelo botão
                Esvaziar agora; a cópia completa fica em SIS.Auditoria).
                DT_AVISO: quando saiu o e-mail avisando que vai ser apagado.
                Nunca é apagada: é o histórico da lixeira.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b, P20).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Lixeira]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Lixeira]
    (
        ID_LIXEIRA           BIGINT         IDENTITY(1,1) NOT NULL,
        TABELA               NVARCHAR(256)  NOT NULL,
        ID_REGISTRO          BIGINT         NOT NULL,
        ITEM_CODIGO          VARCHAR(40)    NOT NULL,
        DESCRICAO            NVARCHAR(400)  NOT NULL CONSTRAINT DF_Lixeira_DESCRICAO       DEFAULT (N''),
        MOTIVO               NVARCHAR(400)  NOT NULL CONSTRAINT DF_Lixeira_MOTIVO          DEFAULT (N''),
        ATIVO_ANTES          BIT            NOT NULL CONSTRAINT DF_Lixeira_ATIVO_ANTES     DEFAULT (1),
        DT_EXCLUSAO          DATETIME2(0)   NOT NULL CONSTRAINT DF_Lixeira_DT_EXCLUSAO     DEFAULT (SYSDATETIME()),
        USUARIO_EXCLUSAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lixeira_USUARIO_EXCLUSAO DEFAULT (N''),
        ID_USUARIO_EXCLUSAO  INT            NULL,
        DT_APAGAR            DATE           NOT NULL,
        SITUACAO             VARCHAR(12)    NOT NULL CONSTRAINT DF_Lixeira_SITUACAO        DEFAULT ('LIXEIRA'),
        DT_SITUACAO          DATETIME2(0)   NULL,
        USUARIO_SITUACAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lixeira_USUARIO_SITUACAO DEFAULT (N''),
        MOTIVO_SITUACAO      NVARCHAR(400)  NOT NULL CONSTRAINT DF_Lixeira_MOTIVO_SITUACAO DEFAULT (N''),
        DT_AVISO             DATETIME2(0)   NULL,
        DT_CRIACAO           DATETIME2(0)   NOT NULL CONSTRAINT DF_Lixeira_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lixeira_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)   NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lixeira          PRIMARY KEY CLUSTERED (ID_LIXEIRA),
        CONSTRAINT CK_Lixeira_SITUACAO CHECK (SITUACAO IN ('LIXEIRA', 'RECUPERADO', 'APAGADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Lixeira]') AND i.name = N'UQ_Lixeira_TABELA_REGISTRO')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Lixeira_TABELA_REGISTRO ON [SIS].[Lixeira] (TABELA, ID_REGISTRO) WHERE SITUACAO = 'LIXEIRA';
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Lixeira]') AND i.name = N'IX_Lixeira_SITUACAO_DT_APAGAR')
    CREATE NONCLUSTERED INDEX IX_Lixeira_SITUACAO_DT_APAGAR ON [SIS].[Lixeira] (SITUACAO, DT_APAGAR) INCLUDE (TABELA, ID_REGISTRO, ITEM_CODIGO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Desfazer.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Desfazer]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Registro de cada desfazer feito pelo histórico (P20): o que foi
                pedido, por quem, com que motivo (obrigatório) e o que mudou.
                TIPO: REGISTRO (voltar um registro, com os filhos que vão
                junto, para como estava depois de uma operação ou numa
                data/hora), OPERACAO (desfazer uma operação = uma transação) ou
                LOTE (desfazer tudo o que um lote fez).
                TRANSACAO: a transação do próprio desfazer, que liga este
                registro às linhas novas da SIS.Auditoria.
                Nunca é alterada nem apagada.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b, P20).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Desfazer]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Desfazer]
    (
        ID_DESFAZER     BIGINT         IDENTITY(1,1) NOT NULL,
        TIPO            VARCHAR(10)    NOT NULL,
        ITEM_CODIGO     VARCHAR(40)    NOT NULL CONSTRAINT DF_Desfazer_ITEM_CODIGO   DEFAULT (''),
        TABELA          NVARCHAR(256)  NOT NULL CONSTRAINT DF_Desfazer_TABELA        DEFAULT (N''),
        ID_REGISTRO     BIGINT         NULL,
        ID_AUDITORIA    BIGINT         NULL,
        DT_ALVO         DATETIME2(0)   NULL,
        TRANSACAO_ALVO  BIGINT         NULL,
        ID_LOTE_ALVO    BIGINT         NULL,
        MOTIVO          NVARCHAR(400)  NOT NULL,
        QTD_REGISTROS   INT            NOT NULL CONSTRAINT DF_Desfazer_QTD_REGISTROS DEFAULT (0),
        QTD_CAMPOS      INT            NOT NULL CONSTRAINT DF_Desfazer_QTD_CAMPOS    DEFAULT (0),
        QTD_LIXEIRA     INT            NOT NULL CONSTRAINT DF_Desfazer_QTD_LIXEIRA   DEFAULT (0),
        TRANSACAO       BIGINT         NULL,
        ID_USUARIO      INT            NULL,
        USUARIO         NVARCHAR(100)  NOT NULL CONSTRAINT DF_Desfazer_USUARIO       DEFAULT (N''),
        DT_CRIACAO      DATETIME2(0)   NOT NULL CONSTRAINT DF_Desfazer_DT_CRIACAO    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Desfazer      PRIMARY KEY CLUSTERED (ID_DESFAZER),
        CONSTRAINT CK_Desfazer_TIPO CHECK (TIPO IN ('REGISTRO', 'OPERACAO', 'LOTE'))
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Pessoa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Pessoa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Cadastro único de pessoas: clientes, fornecedores, funcionários,
                corretores e clientes de obra por administração (uma pessoa pode ter
                vários papéis). CPF/CNPJ PODE REPETIR (decisão do Celso, 16/11/2026): a
                identificação única é o ID_PESSOA (código mostrado na tela); a tela só
                avisa quando já existe outra pessoa com o mesmo documento.
                Contatos, vínculos e dados bancários em tabelas próprias.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa]
    (
        ID_PESSOA            INT            IDENTITY(1,1) NOT NULL,
        TIPO_PESSOA          CHAR(1)        NOT NULL,
        NOME                 NVARCHAR(150)  NOT NULL,
        NOME_FANTASIA        NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_NOME_FANTASIA       DEFAULT (N''),
        CPF_CNPJ             VARCHAR(14)    NOT NULL CONSTRAINT DF_Pessoa_CPF_CNPJ            DEFAULT (''),
        RG                   VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_RG                  DEFAULT (''),
        ORGAO_EMISSOR        VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_ORGAO_EMISSOR       DEFAULT (''),
        INSCRICAO_ESTADUAL   VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_INSCRICAO_ESTADUAL  DEFAULT (''),
        INSCRICAO_MUNICIPAL  VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_INSCRICAO_MUNICIPAL DEFAULT (''),
        DT_NASCIMENTO        DATE           NULL,
        NACIONALIDADE        NVARCHAR(40)   NOT NULL CONSTRAINT DF_Pessoa_NACIONALIDADE       DEFAULT (N''),
        PROFISSAO            NVARCHAR(60)   NOT NULL CONSTRAINT DF_Pessoa_PROFISSAO           DEFAULT (N''),
        ESTADO_CIVIL         VARCHAR(15)    NOT NULL CONSTRAINT DF_Pessoa_ESTADO_CIVIL        DEFAULT (''),
        REGIME_BENS          VARCHAR(25)    NOT NULL CONSTRAINT DF_Pessoa_REGIME_BENS         DEFAULT (''),
        CEP                  VARCHAR(8)     NOT NULL CONSTRAINT DF_Pessoa_CEP                 DEFAULT (''),
        LOGRADOURO           NVARCHAR(150)  NOT NULL CONSTRAINT DF_Pessoa_LOGRADOURO          DEFAULT (N''),
        NUMERO               NVARCHAR(20)   NOT NULL CONSTRAINT DF_Pessoa_NUMERO              DEFAULT (N''),
        COMPLEMENTO          NVARCHAR(60)   NOT NULL CONSTRAINT DF_Pessoa_COMPLEMENTO         DEFAULT (N''),
        BAIRRO               NVARCHAR(60)   NOT NULL CONSTRAINT DF_Pessoa_BAIRRO              DEFAULT (N''),
        CIDADE               NVARCHAR(60)   NOT NULL CONSTRAINT DF_Pessoa_CIDADE              DEFAULT (N''),
        UF                   CHAR(2)        NOT NULL CONSTRAINT DF_Pessoa_UF                  DEFAULT (''),
        CLIENTE              BIT            NOT NULL CONSTRAINT DF_Pessoa_CLIENTE             DEFAULT (0),
        FORNECEDOR           BIT            NOT NULL CONSTRAINT DF_Pessoa_FORNECEDOR          DEFAULT (0),
        FUNCIONARIO          BIT            NOT NULL CONSTRAINT DF_Pessoa_FUNCIONARIO         DEFAULT (0),
        CORRETOR             BIT            NOT NULL CONSTRAINT DF_Pessoa_CORRETOR            DEFAULT (0),
        OBSERVACAO           NVARCHAR(2000) NOT NULL CONSTRAINT DF_Pessoa_OBSERVACAO          DEFAULT (N''),
        ATIVO                BIT            NOT NULL CONSTRAINT DF_Pessoa_ATIVO               DEFAULT (1),
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa              PRIMARY KEY CLUSTERED (ID_PESSOA),
        CONSTRAINT CK_Pessoa_TIPO_PESSOA  CHECK (TIPO_PESSOA IN ('F', 'J')),
        CONSTRAINT CK_Pessoa_CPF_CNPJ     CHECK (CPF_CNPJ NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Pessoa_ESTADO_CIVIL CHECK (ESTADO_CIVIL IN ('', 'SOLTEIRO', 'CASADO', 'DIVORCIADO', 'VIUVO', 'SEPARADO', 'UNIAO_ESTAVEL')),
        CONSTRAINT CK_Pessoa_REGIME_BENS  CHECK (REGIME_BENS IN ('', 'COMUNHAO_PARCIAL', 'COMUNHAO_UNIVERSAL', 'SEPARACAO_TOTAL', 'PARTICIPACAO_AQUESTOS')),
        CONSTRAINT CK_Pessoa_CEP          CHECK (CEP = '' OR (LEN(CEP) = 8 AND CEP NOT LIKE '%[^0-9]%')),
        CONSTRAINT CK_Pessoa_UF           CHECK (UF = '' OR UF NOT LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_NOME' AND object_id = OBJECT_ID(N'[CAD].[Pessoa]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_NOME ON [CAD].[Pessoa] (NOME) INCLUDE (ATIVO, CPF_CNPJ);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_CPF_CNPJ' AND object_id = OBJECT_ID(N'[CAD].[Pessoa]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_CPF_CNPJ ON [CAD].[Pessoa] (CPF_CNPJ) WHERE CPF_CNPJ <> '';
GO

IF COL_LENGTH(N'CAD.Pessoa', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Pessoa] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Pessoa', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Pessoa] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Empresa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Empresa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Empresas do grupo (Construtora, SPEs, Holding), cadastro livre do
                administrador (decisão do Celso, 16/11/2026). O CNPJ da licença só
                registra o software; documentos de uma empresa/obra usam a razão social
                e o CNPJ daqui. CNPJ: só dígitos/letras (aceita o alfanumérico), único
                quando preenchido (a migração pode trazer empresa sem CNPJ).
                ID_CONTA_BANCARIA_PADRAO: FK para BANCO.Conta criada em
                CAD.FK_Conta_Padrao.sql (a conta é criada depois desta tabela).
                Logomarca: anexo do tipo LOGOMARCA (SIS.Anexo).
                CNPJ_COMPRAS: segundo CNPJ, opcional, para notas de compra e DDA
                (ex.: SPE no RET, em que a Receita cria um CNPJ só para isso;
                decisão da CMJ, 17/11/2026). Cobrança e relatórios usam o CNPJ.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - CNPJ_COMPRAS (CNPJ para notas de compra e DDA), etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Empresa]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Empresa]
    (
        ID_EMPRESA                 INT            IDENTITY(1,1) NOT NULL,
        RAZAO_SOCIAL               NVARCHAR(150)  NOT NULL,
        NOME_FANTASIA              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Empresa_NOME_FANTASIA       DEFAULT (N''),
        CNPJ                       VARCHAR(14)    NOT NULL CONSTRAINT DF_Empresa_CNPJ                DEFAULT (''),
        CNPJ_COMPRAS               VARCHAR(14)    NOT NULL CONSTRAINT DF_Empresa_CNPJ_COMPRAS        DEFAULT (''),
        TIPO                       VARCHAR(12)    NOT NULL CONSTRAINT DF_Empresa_TIPO                DEFAULT ('OUTRA'),
        INSCRICAO_ESTADUAL         VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_INSCRICAO_ESTADUAL  DEFAULT (''),
        INSCRICAO_MUNICIPAL        VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_INSCRICAO_MUNICIPAL DEFAULT (''),
        REGIME_TRIBUTARIO          VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_REGIME_TRIBUTARIO   DEFAULT (''),
        CEP                        VARCHAR(8)     NOT NULL CONSTRAINT DF_Empresa_CEP                 DEFAULT (''),
        LOGRADOURO                 NVARCHAR(150)  NOT NULL CONSTRAINT DF_Empresa_LOGRADOURO          DEFAULT (N''),
        NUMERO                     NVARCHAR(20)   NOT NULL CONSTRAINT DF_Empresa_NUMERO              DEFAULT (N''),
        COMPLEMENTO                NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_COMPLEMENTO         DEFAULT (N''),
        BAIRRO                     NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_BAIRRO              DEFAULT (N''),
        CIDADE                     NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_CIDADE              DEFAULT (N''),
        UF                         CHAR(2)        NOT NULL CONSTRAINT DF_Empresa_UF                  DEFAULT (''),
        EMAIL                      NVARCHAR(256)  NOT NULL CONSTRAINT DF_Empresa_EMAIL               DEFAULT (N''),
        TELEFONE                   VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_TELEFONE            DEFAULT (''),
        ID_CONTA_BANCARIA_PADRAO   INT            NULL,
        ATIVO                      BIT            NOT NULL CONSTRAINT DF_Empresa_ATIVO               DEFAULT (1),
        CODIGO_ACCESS              INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Empresa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Empresa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Empresa                   PRIMARY KEY CLUSTERED (ID_EMPRESA),
        CONSTRAINT CK_Empresa_TIPO              CHECK (TIPO IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')),
        CONSTRAINT CK_Empresa_REGIME_TRIBUTARIO CHECK (REGIME_TRIBUTARIO IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')),
        CONSTRAINT CK_Empresa_CNPJ              CHECK (CNPJ = '' OR (LEN(CNPJ) = 14 AND CNPJ NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2)),
        CONSTRAINT CK_Empresa_CNPJ_COMPRAS      CHECK (CNPJ_COMPRAS = '' OR (LEN(CNPJ_COMPRAS) = 14 AND CNPJ_COMPRAS NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2)),
        CONSTRAINT CK_Empresa_CEP               CHECK (CEP = '' OR (LEN(CEP) = 8 AND CEP NOT LIKE '%[^0-9]%')),
        CONSTRAINT CK_Empresa_UF                CHECK (UF = '' OR UF NOT LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

-- v1.1: coluna nova em tabela já existente (regra 59)
IF COL_LENGTH(N'CAD.Empresa', N'CNPJ_COMPRAS') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CNPJ_COMPRAS VARCHAR(14) NOT NULL CONSTRAINT DF_Empresa_CNPJ_COMPRAS DEFAULT ('');
GO
IF OBJECT_ID(N'CAD.CK_Empresa_CNPJ_COMPRAS', N'C') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CONSTRAINT CK_Empresa_CNPJ_COMPRAS
        CHECK (CNPJ_COMPRAS = '' OR (LEN(CNPJ_COMPRAS) = 14 AND CNPJ_COMPRAS NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2));
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_Empresa_CNPJ' AND object_id = OBJECT_ID(N'[CAD].[Empresa]'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Empresa_CNPJ ON [CAD].[Empresa] (CNPJ) WHERE CNPJ <> '';
GO

IF COL_LENGTH(N'CAD.Empresa', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Empresa', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Centro_Custo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Centro_Custo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Onde o dinheiro é aplicado ou gerado: OBRA, ADMINISTRATIVO (escritório),
                IMOVEL_PROPRIO (salas, aptos de aluguel) e PARTICULAR. Todo lançamento
                leva conta do plano + centro de custo; a empresa do lançamento vem daqui.
                CONTABIL = 0: obra/centro que não vai para a contabilidade (o fechamento
                de mês só bloqueia conta contábil em centro contábil).
                ID_CONTA_BANCARIA_PADRAO: se vazio, vale a da empresa.
                Dados próprios da obra ficam em OBRA.Obra (proposta seguinte).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Centro_Custo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Centro_Custo]
    (
        ID_CENTRO_CUSTO            INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA                 INT            NOT NULL,
        CODIGO                     VARCHAR(20)    NOT NULL,
        DESCRICAO                  NVARCHAR(100)  NOT NULL,
        TIPO                       VARCHAR(15)    NOT NULL,
        CONTABIL                   BIT            NOT NULL CONSTRAINT DF_Centro_Custo_CONTABIL DEFAULT (1),
        ID_CONTA_BANCARIA_PADRAO   INT            NULL,
        ATIVO                      BIT            NOT NULL CONSTRAINT DF_Centro_Custo_ATIVO    DEFAULT (1),
        CODIGO_ACCESS              INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Centro_Custo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Centro_Custo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Centro_Custo              PRIMARY KEY CLUSTERED (ID_CENTRO_CUSTO),
        CONSTRAINT UQ_Centro_Custo_CODIGO       UNIQUE (CODIGO),
        CONSTRAINT FK_Centro_Custo_Empresa      FOREIGN KEY (ID_EMPRESA)               REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Centro_Custo_Conta_Padrao FOREIGN KEY (ID_CONTA_BANCARIA_PADRAO) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT CK_Centro_Custo_TIPO         CHECK (TIPO IN ('OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR')),
        CONSTRAINT CK_Centro_Custo_CODIGO       CHECK (CODIGO <> '')
    );
END;
GO

IF COL_LENGTH(N'CAD.Centro_Custo', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Centro_Custo] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Centro_Custo', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Centro_Custo] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Plano_Grupo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Plano_Grupo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas, nível 1 (grupo). TIPO: RECEITA, DESPESA ou
                NAO_OPERACIONAL (empréstimos, amortizações, aportes, distribuição de
                lucros). CUSTO_OBRA: entra no custo da obra e no painel; o orçamento da
                obra é feito por grupo/subgrupo (decisão do Celso, 16/11/2026).
                Plano antigo do Access migra como grupos inativos (só consulta).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Plano_Grupo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Plano_Grupo]
    (
        ID_PLANO_GRUPO     INT            IDENTITY(1,1) NOT NULL,
        NUMERO             SMALLINT       NOT NULL,
        DESCRICAO          NVARCHAR(80)   NOT NULL,
        TIPO               VARCHAR(15)    NOT NULL,
        CUSTO_OBRA         BIT            NOT NULL CONSTRAINT DF_Plano_Grupo_CUSTO_OBRA DEFAULT (0),
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Plano_Grupo_ORDEM      DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Plano_Grupo_ATIVO      DEFAULT (1),
        CODIGO_ACCESS      INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Plano_Grupo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Plano_Grupo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Plano_Grupo           PRIMARY KEY CLUSTERED (ID_PLANO_GRUPO),
        CONSTRAINT UQ_Plano_Grupo_NUMERO    UNIQUE (NUMERO),
        CONSTRAINT UQ_Plano_Grupo_DESCRICAO UNIQUE (DESCRICAO),
        CONSTRAINT CK_Plano_Grupo_NUMERO    CHECK (NUMERO BETWEEN 0 AND 99),
        CONSTRAINT CK_Plano_Grupo_TIPO      CHECK (TIPO IN ('RECEITA', 'DESPESA', 'NAO_OPERACIONAL')),
        CONSTRAINT CK_Plano_Grupo_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO

IF COL_LENGTH(N'CAD.Plano_Grupo', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Plano_Grupo] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Plano_Grupo', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Plano_Grupo] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Plano_Subgrupo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Plano_Subgrupo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas, nível 2 (subgrupo), sempre dentro de um grupo (FK).
                Número e descrição não se repetem dentro do mesmo grupo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Plano_Subgrupo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Plano_Subgrupo]
    (
        ID_PLANO_SUBGRUPO  INT            IDENTITY(1,1) NOT NULL,
        ID_PLANO_GRUPO     INT            NOT NULL,
        NUMERO             SMALLINT       NOT NULL,
        DESCRICAO          NVARCHAR(80)   NOT NULL,
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Plano_Subgrupo_ORDEM DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Plano_Subgrupo_ATIVO DEFAULT (1),
        CODIGO_ACCESS      INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Plano_Subgrupo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Plano_Subgrupo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Plano_Subgrupo           PRIMARY KEY CLUSTERED (ID_PLANO_SUBGRUPO),
        CONSTRAINT UQ_Plano_Subgrupo_NUMERO    UNIQUE (ID_PLANO_GRUPO, NUMERO),
        CONSTRAINT UQ_Plano_Subgrupo_DESCRICAO UNIQUE (ID_PLANO_GRUPO, DESCRICAO),
        CONSTRAINT FK_Plano_Subgrupo_Grupo     FOREIGN KEY (ID_PLANO_GRUPO) REFERENCES [CAD].[Plano_Grupo] (ID_PLANO_GRUPO),
        CONSTRAINT CK_Plano_Subgrupo_NUMERO    CHECK (NUMERO BETWEEN 1 AND 99),
        CONSTRAINT CK_Plano_Subgrupo_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO

IF COL_LENGTH(N'CAD.Plano_Subgrupo', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Plano_Subgrupo] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Plano_Subgrupo', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Plano_Subgrupo] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.Plano_Conta.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Plano_Conta]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas, nível 3: a única que recebe lançamento. O lançamento
                grava só ID_PLANO_CONTA; subgrupo e grupo vêm pela árvore (FK), então
                nunca ficam desalinhados (pedido 11). CONTABIL: o fechamento de mês
                bloqueia (pedido 10); CONTA_CONTABIL_REF: código na contabilidade
                (preenchidos depois, pela tela). Código mostrado: CAD.vw_CAD_Plano_Conta.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Plano_Conta]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Plano_Conta]
    (
        ID_PLANO_CONTA      INT            IDENTITY(1,1) NOT NULL,
        ID_PLANO_SUBGRUPO   INT            NOT NULL,
        NUMERO              SMALLINT       NOT NULL,
        DESCRICAO           NVARCHAR(80)   NOT NULL,
        CONTABIL            BIT            NOT NULL CONSTRAINT DF_Plano_Conta_CONTABIL           DEFAULT (0),
        CONTA_CONTABIL_REF  VARCHAR(30)    NOT NULL CONSTRAINT DF_Plano_Conta_CONTA_CONTABIL_REF DEFAULT (''),
        ATIVO               BIT            NOT NULL CONSTRAINT DF_Plano_Conta_ATIVO              DEFAULT (1),
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Plano_Conta_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Plano_Conta_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Plano_Conta           PRIMARY KEY CLUSTERED (ID_PLANO_CONTA),
        CONSTRAINT UQ_Plano_Conta_NUMERO    UNIQUE (ID_PLANO_SUBGRUPO, NUMERO),
        CONSTRAINT UQ_Plano_Conta_DESCRICAO UNIQUE (ID_PLANO_SUBGRUPO, DESCRICAO),
        CONSTRAINT FK_Plano_Conta_Subgrupo  FOREIGN KEY (ID_PLANO_SUBGRUPO) REFERENCES [CAD].[Plano_Subgrupo] (ID_PLANO_SUBGRUPO),
        CONSTRAINT CK_Plano_Conta_NUMERO    CHECK (NUMERO BETWEEN 1 AND 999),
        CONSTRAINT CK_Plano_Conta_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO

IF COL_LENGTH(N'CAD.Plano_Conta', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Plano_Conta] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Plano_Conta', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Plano_Conta] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.Conta.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[Conta]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contas da empresa: corrente, poupança, aplicação, CAIXA (dinheiro) e
                PERMUTA (quitação sem dinheiro). Conta de banco exige o banco; caixa e
                permuta não. SALDO_INICIAL + DT_SALDO_INICIAL: saldo de abertura.
                CONCILIA: entra na conciliação; MOSTRA_SALDO: aparece no resumo de
                saldos e no fluxo de caixa. Dados de cobrança do Sicredi ficam no COBR.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Conta]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Conta]
    (
        ID_CONTA            INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA          INT            NOT NULL,
        DESCRICAO           NVARCHAR(60)   NOT NULL,
        TIPO                VARCHAR(10)    NOT NULL,
        ID_BANCO            INT            NULL,
        AGENCIA             VARCHAR(10)    NOT NULL CONSTRAINT DF_Conta_AGENCIA            DEFAULT (''),
        AGENCIA_DV          VARCHAR(2)     NOT NULL CONSTRAINT DF_Conta_AGENCIA_DV         DEFAULT (''),
        NUMERO              VARCHAR(20)    NOT NULL CONSTRAINT DF_Conta_NUMERO             DEFAULT (''),
        NUMERO_DV           VARCHAR(2)     NOT NULL CONSTRAINT DF_Conta_NUMERO_DV          DEFAULT (''),
        LIMITE_CREDITO      DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Conta_LIMITE_CREDITO     DEFAULT (0),
        SALDO_INICIAL       DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Conta_SALDO_INICIAL      DEFAULT (0),
        DT_SALDO_INICIAL    DATE           NULL,
        CONCILIA            BIT            NOT NULL CONSTRAINT DF_Conta_CONCILIA           DEFAULT (0),
        MOSTRA_SALDO        BIT            NOT NULL CONSTRAINT DF_Conta_MOSTRA_SALDO       DEFAULT (1),
        CONTA_CONTABIL_REF  VARCHAR(30)    NOT NULL CONSTRAINT DF_Conta_CONTA_CONTABIL_REF DEFAULT (''),
        ORDEM               SMALLINT       NOT NULL CONSTRAINT DF_Conta_ORDEM              DEFAULT (0),
        ATIVO               BIT            NOT NULL CONSTRAINT DF_Conta_ATIVO              DEFAULT (1),
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Conta_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Conta_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Conta               PRIMARY KEY CLUSTERED (ID_CONTA),
        CONSTRAINT UQ_Conta_DESCRICAO     UNIQUE (ID_EMPRESA, DESCRICAO),
        CONSTRAINT FK_Conta_Empresa       FOREIGN KEY (ID_EMPRESA) REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Conta_Banco         FOREIGN KEY (ID_BANCO)   REFERENCES [BANCO].[Banco] (ID_BANCO),
        CONSTRAINT CK_Conta_TIPO          CHECK (TIPO IN ('CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA')),
        CONSTRAINT CK_Conta_BANCO         CHECK (TIPO IN ('CAIXA', 'PERMUTA') OR ID_BANCO IS NOT NULL),
        CONSTRAINT CK_Conta_SALDO_INICIAL CHECK (SALDO_INICIAL = 0 OR DT_SALDO_INICIAL IS NOT NULL)
    );
END;
GO

IF COL_LENGTH(N'BANCO.Conta', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [BANCO].[Conta] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'BANCO.Conta', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [BANCO].[Conta] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Tabela_PK.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Tabela_PK]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Nome da coluna da chave primária de uma tabela ('SCHEMA.Tabela').
                Devolve '' se a tabela não existir ou se a chave tiver mais de
                uma coluna. Usada pelo desfazer e pela lixeira (P20).
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Tabela_PK(N'CAD.Pessoa');  -- ID_PESSOA
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Tabela_PK] (@Tabela NVARCHAR(256))
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @ObjId INT = OBJECT_ID(LTRIM(RTRIM(ISNULL(@Tabela, N''))), N'U');
    DECLARE @Pk NVARCHAR(128), @Qtd INT;

    IF @ObjId IS NULL RETURN N'';

    SELECT @Pk = MAX(c.name), @Qtd = COUNT(*)
    FROM sys.indexes ix
    INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
    INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

    IF ISNULL(@Qtd, 0) <> 1 RETURN N'';
    RETURN ISNULL(@Pk, N'');
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Coluna_Tipo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Coluna_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Tipo completo de uma coluna, pronto para CONVERT (ex.:
                NVARCHAR(200), DECIMAL(18,2), DATETIME2(0)). Devolve '' se a
                coluna não existir. Usada pelo desfazer (P20) para devolver ao
                campo o valor guardado em texto na SIS.Auditoria.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Coluna_Tipo(N'CAD.Pessoa', N'NOME');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Coluna_Tipo] (@Tabela NVARCHAR(256), @Coluna NVARCHAR(128))
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @Tipo NVARCHAR(128);

    SELECT @Tipo = UPPER(t.name)
                 + CASE WHEN t.name IN ('varchar', 'char', 'varbinary', 'binary')
                             THEN N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CAST(c.max_length AS NVARCHAR(10)) END + N')'
                        WHEN t.name IN ('nvarchar', 'nchar')
                             THEN N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CAST(c.max_length / 2 AS NVARCHAR(10)) END + N')'
                        WHEN t.name IN ('decimal', 'numeric')
                             THEN N'(' + CAST(c.precision AS NVARCHAR(5)) + N',' + CAST(c.scale AS NVARCHAR(5)) + N')'
                        WHEN t.name IN ('datetime2', 'time', 'datetimeoffset')
                             THEN N'(' + CAST(c.scale AS NVARCHAR(5)) + N')'
                        ELSE N'' END
    FROM sys.columns c
    INNER JOIN sys.types t ON t.system_type_id = c.system_type_id AND t.user_type_id = c.system_type_id
    WHERE c.object_id = OBJECT_ID(LTRIM(RTRIM(ISNULL(@Tabela, N''))), N'U')
      AND c.name = @Coluna;

    RETURN ISNULL(@Tipo, N'');
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Item_Da_Tabela.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Item_Da_Tabela]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Código da tela (SIS.Item) que mostra a tabela informada
                (coluna TABELAS_DA_TELA); a primeira, se houver mais de uma.
                Devolve '' se nenhuma tela mostrar a tabela. Usada pela lixeira
                e pelo desfazer (P20) para achar a tela, o módulo e a
                permissão de um registro.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Item_Da_Tabela(N'CAD.Plano_Grupo');  -- CAD_PLANO_CONTA
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Item_Da_Tabela] (@Tabela NVARCHAR(256))
RETURNS VARCHAR(40)
AS
BEGIN
    DECLARE @Item VARCHAR(40);

    SELECT TOP 1 @Item = i.CODIGO
    FROM SIS.Item i
    CROSS APPLY STRING_SPLIT(i.TABELAS_DA_TELA, ',') s
    WHERE i.TIPO = 'TELA'
      AND i.ATIVO = 1
      AND LTRIM(RTRIM(s.value)) = LTRIM(RTRIM(ISNULL(@Tabela, N'')))
    ORDER BY i.ID_ITEM;

    RETURN ISNULL(@Item, '');
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Na_Lixeira.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Na_Lixeira]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : 1 se o registro está na lixeira (P20), 0 se não está. Usada
                pelas procedures das telas para recusar alterar, desativar ou
                escolher um registro que está na lixeira.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Na_Lixeira(N'CAD.Pessoa', 1);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Na_Lixeira] (@Tabela NVARCHAR(256), @IdRegistro BIGINT)
RETURNS BIT
AS
BEGIN
    IF @IdRegistro IS NULL OR ISNULL(@Tabela, N'') = N'' RETURN 0;

    IF EXISTS (SELECT 1 FROM SIS.Lixeira l
               WHERE l.TABELA = @Tabela AND l.ID_REGISTRO = @IdRegistro AND l.SITUACAO = 'LIXEIRA')
        RETURN 1;

    RETURN 0;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Lixeira_Dias.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Lixeira_Dias]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Prazo da lixeira, em dias, para a tabela informada: o prazo
                próprio da tela (SIS.Tabela_Config.DIAS_GUARDA) ou, sem ele, o
                parâmetro LIXEIRA_DIAS_GUARDA. Nunca menos de 1 dia.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Lixeira_Dias(N'CAD.Pessoa');  -- 90
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Lixeira_Dias] (@Tabela NVARCHAR(256))
RETURNS INT
AS
BEGIN
    DECLARE @Dias INT;

    SELECT @Dias = c.DIAS_GUARDA FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela;
    SET @Dias = ISNULL(@Dias, SIS.fn_SIS_Parametro_Inteiro('LIXEIRA_DIAS_GUARDA'));

    RETURN CASE WHEN ISNULL(@Dias, 0) < 1 THEN 1 ELSE @Dias END;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Tabela_Trava_Conferir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Tabela_Trava_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Travas configuradas em SIS.Tabela_Config para mexer num
                registro pela lixeira ou pelo desfazer (P20):
                  1) mês fechado: com COLUNA_EMPRESA e COLUNA_DATA_MES
                     preenchidas, recusa se o mês da data do registro (ou da
                     data nova, @DataNova) estiver fechado em FIN.Mes_Fechado;
                  2) PROC_VALIDAR: chama a procedure própria da tabela
                     (@Tabela, @IdRegistro, @Operacao, @Mensagem OUTPUT).
                @Mensagem vazia = pode. Uso interno (chamada pelas procedures
                da lixeira e do desfazer); a API não chama (DENY).
                @Operacao: LIXEIRA, RECUPERAR, APAGAR ou DESFAZER.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Tabela_Trava_Conferir]
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Operacao    VARCHAR(20),
    @DataNova    DATE = NULL,
    @Mensagem    NVARCHAR(400) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ColEmpresa NVARCHAR(128), @ColData NVARCHAR(128), @Proc NVARCHAR(256);
    DECLARE @ObjId INT = OBJECT_ID(@Tabela, N'U');
    DECLARE @Pk NVARCHAR(128) = SIS.fn_SIS_Tabela_PK(@Tabela);
    DECLARE @Sql NVARCHAR(MAX), @IdEmpresa INT, @Data DATE, @Mes DATE, @Msg NVARCHAR(400);

    SET @Mensagem = N'';

    SELECT @ColEmpresa = c.COLUNA_EMPRESA, @ColData = c.COLUNA_DATA_MES, @Proc = c.PROC_VALIDAR
    FROM SIS.Tabela_Config c
    WHERE c.TABELA = @Tabela AND c.ATIVO = 1;

    IF @ObjId IS NULL OR @Pk = N'' RETURN;

    -- 1) Mês fechado
    IF ISNULL(@ColEmpresa, N'') <> N'' AND ISNULL(@ColData, N'') <> N''
    BEGIN
        SET @Sql = N'SELECT @e = TRY_CONVERT(INT, t.' + QUOTENAME(@ColEmpresa) + N'), @d = TRY_CONVERT(DATE, t.' + QUOTENAME(@ColData) + N')'
                 + N' FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N' t'
                 + N' WHERE t.' + QUOTENAME(@Pk) + N' = @Id;';
        EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @e INT OUTPUT, @d DATE OUTPUT', @Id = @IdRegistro, @e = @IdEmpresa OUTPUT, @d = @Data OUTPUT;

        SELECT TOP 1 @Mes = m.MES
        FROM FIN.Mes_Fechado m
        WHERE m.ID_EMPRESA = @IdEmpresa
          AND m.FECHADO = 1
          AND (   (@Data IS NOT NULL     AND m.MES = DATEFROMPARTS(YEAR(@Data), MONTH(@Data), 1))
               OR (@DataNova IS NOT NULL AND m.MES = DATEFROMPARTS(YEAR(@DataNova), MONTH(@DataNova), 1)))
        ORDER BY m.MES;

        IF @Mes IS NOT NULL
        BEGIN
            SET @Mensagem = N'O mês ' + RIGHT(N'0' + CAST(MONTH(@Mes) AS NVARCHAR(2)), 2) + N'/' + CAST(YEAR(@Mes) AS NVARCHAR(4))
                          + N' está fechado para esta empresa. Reabra o mês antes.';
            RETURN;
        END;
    END;

    -- 2) Trava própria da tabela
    IF ISNULL(@Proc, N'') <> N'' AND OBJECT_ID(@Proc, N'P') IS NOT NULL
    BEGIN
        SET @Sql = N'EXEC ' + QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@Proc, N'P'))) + N'.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(@Proc, N'P')))
                 + N' @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = @Operacao, @Mensagem = @Msg OUTPUT;';
        EXEC sys.sp_executesql @Sql, N'@Tabela NVARCHAR(256), @IdRegistro BIGINT, @Operacao VARCHAR(20), @Msg NVARCHAR(400) OUTPUT',
             @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = @Operacao, @Msg = @Msg OUTPUT;
        SET @Mensagem = ISNULL(@Msg, N'');
    END;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Referencias.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Referencias]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Conta onde um registro é usado, para saber se pode ir para a
                lixeira e se pode ser apagado de vez (P20). Lê as chaves
                estrangeiras do próprio banco (nada fixo no código):
                  - linhas de outras tabelas que apontam para o registro,
                    menos as tabelas filhas que "vão junto"
                    (SIS.Tabela_Config.TABELAS_FILHAS);
                  - linhas que apontam para as filhas deste registro;
                  - anexos ativos (SIS.Anexo) do registro.
                @Qtd = total de usos; @Onde = nome da tela (ou tabela) do
                primeiro uso encontrado. Uso interno (DENY para a API).
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- DECLARE @q INT, @o NVARCHAR(400);
    -- EXEC SIS.SIS_Lixeira_Referencias @Tabela = N'CAD.Empresa', @IdRegistro = 1, @Qtd = @q OUTPUT, @Onde = @o OUTPUT; SELECT @q, @o;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Referencias]
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Qtd         INT           OUTPUT,
    @Onde        NVARCHAR(400) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ObjId INT = OBJECT_ID(@Tabela, N'U');
    DECLARE @Filhas TABLE (TABELA NVARCHAR(256) NOT NULL, COLUNA NVARCHAR(128) NOT NULL, OBJ INT NULL, PK NVARCHAR(128) NULL);
    DECLARE @Refs   TABLE (ORDEM INT IDENTITY(1,1) NOT NULL, COMANDO NVARCHAR(MAX) NOT NULL, TABELA NVARCHAR(256) NOT NULL);
    DECLARE @i INT = 1, @Total INT, @n BIGINT, @Cmd NVARCHAR(MAX), @TabRef NVARCHAR(256);

    SET @Qtd = 0;
    SET @Onde = N'';
    IF @ObjId IS NULL OR @IdRegistro IS NULL RETURN;

    INSERT INTO @Filhas (TABELA, COLUNA)
    SELECT LEFT(x.v, LEN(x.v) - CHARINDEX(N'.', REVERSE(x.v))), RIGHT(x.v, CHARINDEX(N'.', REVERSE(x.v)) - 1)
    FROM SIS.Tabela_Config c
    CROSS APPLY (SELECT LTRIM(RTRIM(s.value)) AS v FROM STRING_SPLIT(c.TABELAS_FILHAS, N',') s) x
    WHERE c.TABELA = @Tabela
      AND x.v LIKE N'%_._%._%';

    UPDATE f SET f.OBJ = OBJECT_ID(f.TABELA, N'U'), f.PK = SIS.fn_SIS_Tabela_PK(f.TABELA) FROM @Filhas f;
    DELETE FROM @Filhas WHERE OBJ IS NULL OR ISNULL(PK, N'') = N'';

    -- Quem aponta direto para o registro (menos as filhas que vão junto)
    INSERT INTO @Refs (COMANDO, TABELA)
    SELECT N'SELECT @n = COUNT_BIG(*) FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
         + N' WITH (NOLOCK) WHERE ' + QUOTENAME(pc.name) + N' = @Id;',
           OBJECT_SCHEMA_NAME(fk.parent_object_id) + N'.' + OBJECT_NAME(fk.parent_object_id)
    FROM sys.foreign_keys fk
    INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
    INNER JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
    WHERE fk.referenced_object_id = @ObjId
      AND (SELECT COUNT(*) FROM sys.foreign_key_columns x WHERE x.constraint_object_id = fk.object_id) = 1
      AND NOT EXISTS (SELECT 1 FROM @Filhas f WHERE f.OBJ = fk.parent_object_id AND f.COLUNA = pc.name)
    ORDER BY fk.name;

    -- Quem aponta para as filhas deste registro
    INSERT INTO @Refs (COMANDO, TABELA)
    SELECT N'SELECT @n = COUNT_BIG(*) FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
         + N' r WITH (NOLOCK) WHERE r.' + QUOTENAME(pc.name) + N' IN (SELECT f.' + QUOTENAME(f.PK)
         + N' FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(f.OBJ)) + N'.' + QUOTENAME(OBJECT_NAME(f.OBJ)) + N' f WITH (NOLOCK) WHERE f.' + QUOTENAME(f.COLUNA) + N' = @Id);',
           OBJECT_SCHEMA_NAME(fk.parent_object_id) + N'.' + OBJECT_NAME(fk.parent_object_id)
    FROM @Filhas f
    INNER JOIN sys.foreign_keys fk ON fk.referenced_object_id = f.OBJ
    INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
    INNER JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
    WHERE (SELECT COUNT(*) FROM sys.foreign_key_columns x WHERE x.constraint_object_id = fk.object_id) = 1
      AND fk.parent_object_id <> @ObjId
    ORDER BY fk.name;

    SELECT @Total = COUNT(*) FROM @Refs;
    WHILE @i <= @Total
    BEGIN
        SELECT @Cmd = r.COMANDO, @TabRef = r.TABELA FROM @Refs r WHERE r.ORDEM = @i;
        SET @n = 0;
        EXEC sys.sp_executesql @Cmd, N'@Id BIGINT, @n BIGINT OUTPUT', @Id = @IdRegistro, @n = @n OUTPUT;
        IF ISNULL(@n, 0) > 0
        BEGIN
            IF @Onde = N''
                SET @Onde = ISNULL((SELECT TOP 1 i.NOME FROM SIS.Item i WHERE i.CODIGO = SIS.fn_SIS_Item_Da_Tabela(@TabRef)), @TabRef);
            SET @Qtd = @Qtd + CAST(@n AS INT);
        END;
        SET @i = @i + 1;
    END;

    -- Anexos ativos do registro
    SELECT @n = COUNT_BIG(*)
    FROM SIS.Anexo a WITH (NOLOCK)
    WHERE a.TABELA_REFERENCIA = @Tabela AND a.ID_REFERENCIA = @IdRegistro AND a.SITUACAO = 'ATIVO';
    IF ISNULL(@n, 0) > 0
    BEGIN
        IF @Onde = N'' SET @Onde = N'anexos';
        SET @Qtd = @Qtd + CAST(@n AS INT);
    END;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Marcar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Marcar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Manda um registro para a lixeira (P20): confere a
                configuração da tabela, o parâmetro LIXEIRA_ATIVA, se o
                registro existe e não está na lixeira, se nada usa o registro
                (SIS_Lixeira_Referencias) e as travas (mês fechado e trava
                própria); então desativa o registro, preenche DT_EXCLUSAO e
                USUARIO_EXCLUSAO e grava a linha em SIS.Lixeira com o prazo
                (fn_SIS_Lixeira_Dias).
                Recusa = @Mensagem preenchida, sem gravar nada. Quem chama
                cuida da transação. Uso interno (DENY para a API): chamada
                por SIS_Lixeira_Excluir e pelo desfazer de uma inclusão.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Marcar]
    @IdUsuario   INT,
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Item        VARCHAR(40),
    @Motivo      NVARCHAR(400),
    @IdLixeira   BIGINT        OUTPUT,
    @Mensagem    NVARCHAR(400) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ObjId INT = OBJECT_ID(@Tabela, N'U');
    DECLARE @Pk NVARCHAR(128) = SIS.fn_SIS_Tabela_PK(@Tabela);
    DECLARE @Nome NVARCHAR(300), @DescSql NVARCHAR(1000), @Sql NVARCHAR(MAX), @Usuario NVARCHAR(100);
    DECLARE @Existe INT = 0, @Ativo BIT, @JaExcluido BIT, @Descricao NVARCHAR(400), @Qtd INT, @Onde NVARCHAR(400);
    DECLARE @TemAlteracao BIT;

    SET @IdLixeira = NULL;
    SET @Mensagem = N'';

    IF NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela AND c.ATIVO = 1 AND c.PERMITE_LIXEIRA = 1)
       OR @ObjId IS NULL OR @Pk = N''
       OR COL_LENGTH(@Tabela, N'ATIVO') IS NULL OR COL_LENGTH(@Tabela, N'DT_EXCLUSAO') IS NULL OR COL_LENGTH(@Tabela, N'USUARIO_EXCLUSAO') IS NULL
    BEGIN
        SET @Mensagem = N'Este tipo de registro não vai para a lixeira: use Desativar.';
        RETURN;
    END;

    IF SIS.fn_SIS_Parametro_SN('LIXEIRA_ATIVA') = 0
    BEGIN
        SET @Mensagem = N'A lixeira está desligada (parâmetro LIXEIRA_ATIVA): use Desativar.';
        RETURN;
    END;

    SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));
    SELECT @DescSql = NULLIF(LTRIM(RTRIM(c.DESCRICAO_SQL)), N'') FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela;

    SET @Sql = N'SELECT @Existe = 1, @Ativo = t.ATIVO, @JaExcluido = CASE WHEN t.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END, '
             + N'@Descricao = LEFT(CONVERT(NVARCHAR(MAX), ' + ISNULL(@DescSql, N'CAST(t.' + QUOTENAME(@Pk) + N' AS NVARCHAR(30))') + N'), 400) '
             + N'FROM ' + @Nome + N' t WITH (UPDLOCK, HOLDLOCK) WHERE t.' + QUOTENAME(@Pk) + N' = @Id;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Existe INT OUTPUT, @Ativo BIT OUTPUT, @JaExcluido BIT OUTPUT, @Descricao NVARCHAR(400) OUTPUT',
         @Id = @IdRegistro, @Existe = @Existe OUTPUT, @Ativo = @Ativo OUTPUT, @JaExcluido = @JaExcluido OUTPUT, @Descricao = @Descricao OUTPUT;

    IF ISNULL(@Existe, 0) = 0
    BEGIN
        SET @Mensagem = N'Registro não encontrado.';
        RETURN;
    END;

    IF @JaExcluido = 1 OR SIS.fn_SIS_Na_Lixeira(@Tabela, @IdRegistro) = 1
    BEGIN
        SET @Mensagem = N'O registro já está na lixeira.';
        RETURN;
    END;

    EXEC SIS.SIS_Lixeira_Referencias @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Qtd = @Qtd OUTPUT, @Onde = @Onde OUTPUT;
    IF ISNULL(@Qtd, 0) > 0
    BEGIN
        SET @Mensagem = N'Não dá para excluir: o registro é usado em ' + ISNULL(@Onde, N'outro cadastro')
                      + CASE WHEN @Qtd > 1 THEN N' e em mais ' + CAST(@Qtd - 1 AS NVARCHAR(10)) + N' lugar(es)' ELSE N'' END
                      + N'. Use Desativar.';
        RETURN;
    END;

    EXEC SIS.SIS_Tabela_Trava_Conferir @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = 'LIXEIRA', @Mensagem = @Mensagem OUTPUT;
    IF ISNULL(@Mensagem, N'') <> N'' RETURN;
    SET @Mensagem = N'';

    SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    SET @TemAlteracao = CASE WHEN COL_LENGTH(@Tabela, N'DT_ALTERACAO') IS NOT NULL AND COL_LENGTH(@Tabela, N'USUARIO_ALTERACAO') IS NOT NULL THEN 1 ELSE 0 END;

    SET @Sql = N'UPDATE t SET t.ATIVO = 0, t.DT_EXCLUSAO = SYSDATETIME(), t.USUARIO_EXCLUSAO = @Usuario'
             + CASE WHEN @TemAlteracao = 1 THEN N', t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario' ELSE N'' END
             + N' FROM ' + @Nome + N' t WHERE t.' + QUOTENAME(@Pk) + N' = @Id AND t.DT_EXCLUSAO IS NULL;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Usuario NVARCHAR(100)', @Id = @IdRegistro, @Usuario = @Usuario;

    INSERT INTO SIS.Lixeira (TABELA, ID_REGISTRO, ITEM_CODIGO, DESCRICAO, MOTIVO, ATIVO_ANTES, DT_EXCLUSAO, USUARIO_EXCLUSAO, ID_USUARIO_EXCLUSAO, DT_APAGAR, SITUACAO)
    VALUES (@Tabela, @IdRegistro, ISNULL(NULLIF(@Item, ''), SIS.fn_SIS_Item_Da_Tabela(@Tabela)), ISNULL(@Descricao, N''), ISNULL(@Motivo, N''),
            ISNULL(@Ativo, 1), SYSDATETIME(), ISNULL(@Usuario, N''), @IdUsuario,
            DATEADD(DAY, SIS.fn_SIS_Lixeira_Dias(@Tabela), CAST(SYSDATETIME() AS DATE)), 'LIXEIRA');
    SET @IdLixeira = SCOPE_IDENTITY();
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Apagar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Apagar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Apaga de vez um registro que está na lixeira (P20), com as
                filhas que vão junto (SIS.Tabela_Config.TABELAS_FILHAS).
                Antes confere de novo se nada passou a usar o registro e as
                travas; se algo usar, não apaga e devolve o motivo. A trigger
                de auditoria guarda a cópia completa de tudo o que for apagado.
                Marca a linha da SIS.Lixeira como APAGADO.
                Recusa = @Mensagem preenchida, sem apagar nada. Quem chama
                cuida da transação. Uso interno (DENY para a API): chamada por
                SIS_Lixeira_Esvaziar e SIS_Lixeira_Processar.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Apagar]
    @IdLixeira  BIGINT,
    @Usuario    NVARCHAR(100),
    @Motivo     NVARCHAR(400),
    @Mensagem   NVARCHAR(400) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Tabela NVARCHAR(256), @IdRegistro BIGINT, @ObjId INT, @Pk NVARCHAR(128), @Nome NVARCHAR(300);
    DECLARE @Qtd INT, @Onde NVARCHAR(400), @Sql NVARCHAR(MAX), @Apagados INT;

    SET @Mensagem = N'';

    SELECT @Tabela = l.TABELA, @IdRegistro = l.ID_REGISTRO
    FROM SIS.Lixeira l WITH (UPDLOCK, HOLDLOCK)
    WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA';

    IF @Tabela IS NULL
    BEGIN
        SET @Mensagem = N'O registro não está mais na lixeira.';
        RETURN;
    END;

    SET @ObjId = OBJECT_ID(@Tabela, N'U');
    SET @Pk = SIS.fn_SIS_Tabela_PK(@Tabela);
    IF @ObjId IS NULL OR @Pk = N''
    BEGIN
        SET @Mensagem = N'Tabela do registro não encontrada.';
        RETURN;
    END;
    SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));

    EXEC SIS.SIS_Lixeira_Referencias @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Qtd = @Qtd OUTPUT, @Onde = @Onde OUTPUT;
    IF ISNULL(@Qtd, 0) > 0
    BEGIN
        SET @Mensagem = N'Não foi apagado: o registro passou a ser usado em ' + ISNULL(@Onde, N'outro cadastro') + N'. Recupere-o ou tire o uso antes.';
        RETURN;
    END;

    EXEC SIS.SIS_Tabela_Trava_Conferir @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = 'APAGAR', @Mensagem = @Mensagem OUTPUT;
    IF ISNULL(@Mensagem, N'') <> N'' RETURN;
    SET @Mensagem = N'';

    -- Filhas que vão junto
    SET @Sql = N'';
    SELECT @Sql = @Sql + N'DELETE FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(f.TABELA, N'U'))) + N'.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(f.TABELA, N'U')))
                + N' WHERE ' + QUOTENAME(f.COLUNA) + N' = @Id;' + NCHAR(13) + NCHAR(10)
    FROM (SELECT LEFT(x.v, LEN(x.v) - CHARINDEX(N'.', REVERSE(x.v))) AS TABELA, RIGHT(x.v, CHARINDEX(N'.', REVERSE(x.v)) - 1) AS COLUNA
          FROM SIS.Tabela_Config c
          CROSS APPLY (SELECT LTRIM(RTRIM(s.value)) AS v FROM STRING_SPLIT(c.TABELAS_FILHAS, N',') s) x
          WHERE c.TABELA = @Tabela AND x.v LIKE N'%_._%._%') f
    WHERE OBJECT_ID(f.TABELA, N'U') IS NOT NULL
      AND COL_LENGTH(f.TABELA, f.COLUNA) IS NOT NULL;

    IF @Sql <> N''
        EXEC sys.sp_executesql @Sql, N'@Id BIGINT', @Id = @IdRegistro;

    SET @Sql = N'DELETE FROM ' + @Nome + N' WHERE ' + QUOTENAME(@Pk) + N' = @Id AND DT_EXCLUSAO IS NOT NULL; SET @n = @@ROWCOUNT;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @n INT OUTPUT', @Id = @IdRegistro, @n = @Apagados OUTPUT;

    UPDATE l
       SET l.SITUACAO = 'APAGADO', l.DT_SITUACAO = SYSDATETIME(), l.USUARIO_SITUACAO = ISNULL(@Usuario, N''),
           l.MOTIVO_SITUACAO = LEFT(ISNULL(@Motivo, N'') + CASE WHEN ISNULL(@Apagados, 0) = 0 THEN N' (o registro já não existia)' ELSE N'' END, 400),
           l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = ISNULL(@Usuario, N'')
    FROM SIS.Lixeira l
    WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA';
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Botão Excluir das telas (P20): manda o registro para a
                lixeira, de onde pode ser recuperado até o fim do prazo
                (LIXEIRA_DIAS_GUARDA ou o prazo próprio da tela). Só exclui o
                que nada usa; senão recusa e sugere Desativar.
                Permissão: EXCLUIR na tela (@Item), e a tela precisa mostrar
                a tabela (SIS.Item.TABELAS_DA_TELA).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_LIXEIRA, DT_APAGAR.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = 2, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = 1, @Motivo = N'cadastro em dobro';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Excluir]
    @IdUsuario   INT,
    @Item        VARCHAR(40),
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Motivo      NVARCHAR(400) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @Recusa NVARCHAR(400) = N'', @IdLixeira BIGINT, @DtApagar DATE;

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para excluir nesta tela.';
        ELSE IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            SET @Recusa = N'Esta tela não exclui esse tipo de registro.';
        ELSE IF @IdRegistro IS NULL
            SET @Recusa = N'Escolha o registro a excluir.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_LIXEIRA, CAST(NULL AS DATE) AS DT_APAGAR;
            RETURN;
        END;

        SET @EtapaAtual = 'Lixeira';
        IF @TranCountEntrada = 0 BEGIN TRANSACTION;
            EXEC SIS.SIS_Lixeira_Marcar @IdUsuario = @IdUsuario, @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Item = @Item,
                 @Motivo = @Motivo, @IdLixeira = @IdLixeira OUTPUT, @Mensagem = @Recusa OUTPUT;
        IF @TranCountEntrada = 0 COMMIT TRANSACTION;

        IF ISNULL(@Recusa, N'') <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_LIXEIRA, CAST(NULL AS DATE) AS DT_APAGAR;
            RETURN;
        END;

        SELECT @DtApagar = l.DT_APAGAR FROM SIS.Lixeira l WHERE l.ID_LIXEIRA = @IdLixeira;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Registro enviado para a lixeira. Pode ser recuperado até ' + ISNULL(SIS.fn_SIS_Formatar_Data(@DtApagar), N'') + N' (Sistema › Lixeira).' AS NVARCHAR(400)) AS MENSAGEM,
               @IdLixeira AS ID_LIXEIRA, @DtApagar AS DT_APAGAR;
    END TRY
    BEGIN CATCH
        IF @TranCountEntrada = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível excluir o registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_LIXEIRA, CAST(NULL AS DATE) AS DT_APAGAR;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Recuperar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Recuperar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Botão Recuperar da tela Sistema › Lixeira (P20): o registro
                volta como estava antes de ir para a lixeira (ativo ou
                desativado). Antes confere:
                  - os campos únicos configurados (SIS.Tabela_Config.
                    CAMPOS_UNICOS, ex.: CPF/CNPJ): se outro registro vivo tiver
                    o mesmo valor, recusa e mostra qual é;
                  - se algum registro ligado (chave estrangeira) está na
                    lixeira: recupere esse antes;
                  - as travas (mês fechado e trava própria).
                Permissão: RECUPERAR em SIS_LIXEIRA e VER na tela do registro.
                Devolve 1 linha: SUCESSO, MENSAGEM, TABELA, ID_REGISTRO.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Recuperar @IdUsuario = 2, @IdLixeira = 1, @Motivo = N'excluído por engano';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Recuperar]
    @IdUsuario  INT,
    @IdLixeira  BIGINT,
    @Motivo     NVARCHAR(400) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Recuperar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @Recusa NVARCHAR(400) = N'', @Tabela NVARCHAR(256), @IdRegistro BIGINT, @Item VARCHAR(40), @AtivoAntes BIT;
    DECLARE @ObjId INT, @Pk NVARCHAR(128), @Nome NVARCHAR(300), @Sql NVARCHAR(MAX), @Usuario NVARCHAR(100);
    DECLARE @Campos TABLE (ORDEM INT IDENTITY(1,1), CAMPO NVARCHAR(128));
    DECLARE @Fks TABLE (ORDEM INT IDENTITY(1,1), COLUNA NVARCHAR(128), TABELA_REF NVARCHAR(256));
    DECLARE @i INT, @Total INT, @Campo NVARCHAR(128), @Outro BIGINT, @Ref BIGINT, @TabRef NVARCHAR(256), @DescSql NVARCHAR(1000), @DescOutro NVARCHAR(400);
    DECLARE @TemAlteracao BIT, @Linhas INT;

    BEGIN TRY
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        SELECT @Tabela = l.TABELA, @IdRegistro = l.ID_REGISTRO, @Item = l.ITEM_CODIGO, @AtivoAntes = l.ATIVO_ANTES
        FROM SIS.Lixeira l
        WHERE l.ID_LIXEIRA = @IdLixeira;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'RECUPERAR') = 0
            SET @Recusa = N'Você não tem permissão para recuperar registros da lixeira.';
        ELSE IF @Tabela IS NULL
            SET @Recusa = N'Registro da lixeira não encontrado.';
        ELSE IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            SET @Recusa = N'Você não tem permissão para ver a tela deste registro.';
        ELSE IF NOT EXISTS (SELECT 1 FROM SIS.Lixeira l WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA')
            SET @Recusa = N'O registro não está mais na lixeira.';

        SET @ObjId = OBJECT_ID(@Tabela, N'U');
        SET @Pk = SIS.fn_SIS_Tabela_PK(@Tabela);
        IF @Recusa = N'' AND (@ObjId IS NULL OR @Pk = N'')
            SET @Recusa = N'Tabela do registro não encontrada.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@Tabela AS NVARCHAR(256)) AS TABELA, @IdRegistro AS ID_REGISTRO;
            RETURN;
        END;

        SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));
        SELECT @DescSql = NULLIF(LTRIM(RTRIM(c.DESCRICAO_SQL)), N'') FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela;

        -- Campos únicos contra os registros vivos
        SET @EtapaAtual = 'Campos únicos';
        INSERT INTO @Campos (CAMPO)
        SELECT LTRIM(RTRIM(s.value))
        FROM SIS.Tabela_Config c
        CROSS APPLY STRING_SPLIT(c.CAMPOS_UNICOS, N',') s
        WHERE c.TABELA = @Tabela AND LTRIM(RTRIM(s.value)) <> N'' AND COL_LENGTH(@Tabela, LTRIM(RTRIM(s.value))) IS NOT NULL;

        SELECT @i = 1, @Total = COUNT(*) FROM @Campos;
        WHILE @i <= @Total AND @Recusa = N''
        BEGIN
            SELECT @Campo = c.CAMPO FROM @Campos c WHERE c.ORDEM = @i;
            SET @Outro = NULL;
            SET @Sql = N'SELECT TOP 1 @Outro = o.' + QUOTENAME(@Pk) + N', @Desc = LEFT(CONVERT(NVARCHAR(MAX), '
                     + ISNULL(REPLACE(@DescSql, N't.', N'o.'), N'CAST(o.' + QUOTENAME(@Pk) + N' AS NVARCHAR(30))') + N'), 400)'
                     + N' FROM ' + @Nome + N' o INNER JOIN ' + @Nome + N' t ON t.' + QUOTENAME(@Pk) + N' = @Id'
                     + N' WHERE o.' + QUOTENAME(@Pk) + N' <> @Id AND o.DT_EXCLUSAO IS NULL'
                     + N' AND ISNULL(CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(@Campo) + N'), N'''') <> N'''''
                     + N' AND o.' + QUOTENAME(@Campo) + N' = t.' + QUOTENAME(@Campo)
                     + N' ORDER BY o.' + QUOTENAME(@Pk) + N';';
            EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Outro BIGINT OUTPUT, @Desc NVARCHAR(400) OUTPUT', @Id = @IdRegistro, @Outro = @Outro OUTPUT, @Desc = @DescOutro OUTPUT;
            IF @Outro IS NOT NULL
                SET @Recusa = LEFT(N'Já existe outro cadastro com o mesmo ' + @Campo + N': ' + ISNULL(@DescOutro, N'') + N' (código ' + CAST(@Outro AS NVARCHAR(20))
                            + N'). Confira se é o mesmo antes de recuperar.', 400);
            SET @i = @i + 1;
        END;

        -- Registros ligados que estão na lixeira
        SET @EtapaAtual = 'Registros ligados';
        IF @Recusa = N''
        BEGIN
            INSERT INTO @Fks (COLUNA, TABELA_REF)
            SELECT pc.name, OBJECT_SCHEMA_NAME(fk.referenced_object_id) + N'.' + OBJECT_NAME(fk.referenced_object_id)
            FROM sys.foreign_keys fk
            INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
            INNER JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
            WHERE fk.parent_object_id = @ObjId
              AND (SELECT COUNT(*) FROM sys.foreign_key_columns x WHERE x.constraint_object_id = fk.object_id) = 1;

            SELECT @i = 1, @Total = COUNT(*) FROM @Fks;
            WHILE @i <= @Total AND @Recusa = N''
            BEGIN
                SELECT @Campo = f.COLUNA, @TabRef = f.TABELA_REF FROM @Fks f WHERE f.ORDEM = @i;
                SET @Ref = NULL;
                SET @Sql = N'SELECT @Ref = TRY_CONVERT(BIGINT, t.' + QUOTENAME(@Campo) + N') FROM ' + @Nome + N' t WHERE t.' + QUOTENAME(@Pk) + N' = @Id;';
                EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Ref BIGINT OUTPUT', @Id = @IdRegistro, @Ref = @Ref OUTPUT;
                IF @Ref IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(@TabRef, @Ref) = 1
                    SET @Recusa = LEFT(N'Este registro está ligado a outro que também está na lixeira ('
                                + ISNULL((SELECT TOP 1 l.DESCRICAO FROM SIS.Lixeira l WHERE l.TABELA = @TabRef AND l.ID_REGISTRO = @Ref AND l.SITUACAO = 'LIXEIRA'), N'')
                                + N'). Recupere aquele antes.', 400);
                SET @i = @i + 1;
            END;
        END;

        IF @Recusa = N''
        BEGIN
            EXEC SIS.SIS_Tabela_Trava_Conferir @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = 'RECUPERAR', @Mensagem = @Recusa OUTPUT;
            SET @Recusa = ISNULL(@Recusa, N'');
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@Tabela AS NVARCHAR(256)) AS TABELA, @IdRegistro AS ID_REGISTRO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @TemAlteracao = CASE WHEN COL_LENGTH(@Tabela, N'DT_ALTERACAO') IS NOT NULL AND COL_LENGTH(@Tabela, N'USUARIO_ALTERACAO') IS NOT NULL THEN 1 ELSE 0 END;
        SET @Sql = N'UPDATE t SET t.ATIVO = @Ativo, t.DT_EXCLUSAO = NULL, t.USUARIO_EXCLUSAO = NULL'
                 + CASE WHEN @TemAlteracao = 1 THEN N', t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario' ELSE N'' END
                 + N' FROM ' + @Nome + N' t WHERE t.' + QUOTENAME(@Pk) + N' = @Id AND t.DT_EXCLUSAO IS NOT NULL; SET @n = @@ROWCOUNT;';

        IF @TranCountEntrada = 0 BEGIN TRANSACTION;
            EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Ativo BIT, @Usuario NVARCHAR(100), @n INT OUTPUT',
                 @Id = @IdRegistro, @Ativo = @AtivoAntes, @Usuario = @Usuario, @n = @Linhas OUTPUT;

            UPDATE l
               SET l.SITUACAO = 'RECUPERADO', l.DT_SITUACAO = SYSDATETIME(), l.USUARIO_SITUACAO = ISNULL(@Usuario, N''),
                   l.MOTIVO_SITUACAO = @Motivo, l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = ISNULL(@Usuario, N'')
            FROM SIS.Lixeira l
            WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA';
        IF @TranCountEntrada = 0 COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @AtivoAntes = 1 THEN N'Registro recuperado: voltou ativo.' ELSE N'Registro recuperado: voltou desativado, como estava antes de ir para a lixeira.' END AS NVARCHAR(400)) AS MENSAGEM,
               CAST(@Tabela AS NVARCHAR(256)) AS TABELA, @IdRegistro AS ID_REGISTRO;
    END TRY
    BEGIN CATCH
        IF @TranCountEntrada = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível recuperar o registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(@Tabela AS NVARCHAR(256)) AS TABELA, @IdRegistro AS ID_REGISTRO;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Manter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Manter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Botão "Manter mais N dias" da tela Sistema › Lixeira (P20):
                adia a data em que o registro será apagado de vez, sem
                recuperar. Conta os dias a partir da data marcada (ou de hoje,
                se ela já passou) e libera um novo aviso por e-mail.
                Permissão: ALTERAR em SIS_LIXEIRA e VER na tela do registro.
                Devolve 1 linha: SUCESSO, MENSAGEM, DT_APAGAR.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Manter @IdUsuario = 2, @IdLixeira = 1, @Dias = 30;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Manter]
    @IdUsuario  INT,
    @IdLixeira  BIGINT,
    @Dias       INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Manter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa NVARCHAR(400) = N'', @Item VARCHAR(40), @Situacao VARCHAR(12), @DtApagar DATE, @Usuario NVARCHAR(100);

    BEGIN TRY
        SELECT @Item = l.ITEM_CODIGO, @Situacao = l.SITUACAO FROM SIS.Lixeira l WHERE l.ID_LIXEIRA = @IdLixeira;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para mudar o prazo da lixeira.';
        ELSE IF @Situacao IS NULL
            SET @Recusa = N'Registro da lixeira não encontrado.';
        ELSE IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            SET @Recusa = N'Você não tem permissão para ver a tela deste registro.';
        ELSE IF @Situacao <> 'LIXEIRA'
            SET @Recusa = N'O registro não está mais na lixeira.';
        ELSE IF ISNULL(@Dias, 0) NOT BETWEEN 1 AND 3650
            SET @Recusa = N'Informe de 1 a 3650 dias.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS DATE) AS DT_APAGAR;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        UPDATE l
           SET @DtApagar = l.DT_APAGAR = DATEADD(DAY, @Dias, CASE WHEN l.DT_APAGAR < CAST(SYSDATETIME() AS DATE) THEN CAST(SYSDATETIME() AS DATE) ELSE l.DT_APAGAR END),
               l.DT_AVISO = NULL, l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Lixeira l
        WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA';

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Prazo adiado: o registro fica na lixeira até ' + ISNULL(SIS.fn_SIS_Formatar_Data(@DtApagar), N'') + N'.' AS NVARCHAR(400)) AS MENSAGEM,
               @DtApagar AS DT_APAGAR;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível mudar o prazo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS DATE) AS DT_APAGAR;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Esvaziar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Esvaziar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Botão "Esvaziar agora" da tela Sistema › Lixeira (P20): apaga
                de vez os registros escolhidos (@Ids = lista de ID_LIXEIRA
                separados por vírgula), sem esperar o prazo. Cada registro é
                independente: se um não puder ser apagado (passou a ser usado,
                trava), os outros seguem. A cópia completa fica na auditoria.
                Permissão: ESVAZIAR em SIS_LIXEIRA e VER na tela de cada
                registro (os de telas que o usuário não vê são ignorados).
                Devolve 1 linha: SUCESSO, MENSAGEM, QTD_APAGADOS, QTD_RECUSADOS.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Esvaziar @IdUsuario = 2, @Ids = N'1,2';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Esvaziar]
    @IdUsuario  INT,
    @Ids        NVARCHAR(MAX),
    @Motivo     NVARCHAR(400) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Sem XACT_ABORT: laço isolado, um registro ruim não derruba os outros (PADRAO_SQL regras 2 e 13).

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Esvaziar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @Lista TABLE (ORDEM INT IDENTITY(1,1), ID_LIXEIRA BIGINT);
    DECLARE @i INT = 1, @Total INT, @Id BIGINT, @Msg NVARCHAR(400), @PrimeiraRecusa NVARCHAR(400) = N'';
    DECLARE @Apagados INT = 0, @Recusados INT = 0, @Usuario NVARCHAR(100);

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'ESVAZIAR') = 0
    BEGIN
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para esvaziar a lixeira.' AS NVARCHAR(400)) AS MENSAGEM, 0 AS QTD_APAGADOS, 0 AS QTD_RECUSADOS;
        RETURN;
    END;

    INSERT INTO @Lista (ID_LIXEIRA)
    SELECT DISTINCT l.ID_LIXEIRA
    FROM STRING_SPLIT(ISNULL(@Ids, N''), N',') s
    INNER JOIN SIS.Lixeira l ON l.ID_LIXEIRA = TRY_CONVERT(BIGINT, LTRIM(RTRIM(s.value)))
    WHERE l.SITUACAO = 'LIXEIRA'
      AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, l.ITEM_CODIGO, 'VER') = 1;

    SELECT @Total = COUNT(*) FROM @Lista;
    IF @Total = 0
    BEGIN
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Escolha os registros da lixeira que serão apagados de vez.' AS NVARCHAR(400)) AS MENSAGEM, 0 AS QTD_APAGADOS, 0 AS QTD_RECUSADOS;
        RETURN;
    END;

    SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    SET @Motivo = ISNULL(NULLIF(LTRIM(RTRIM(@Motivo)), N''), N'Esvaziar agora');
    SET @EtapaAtual = 'Apagando';

    WHILE @i <= @Total
    BEGIN
        SELECT @Id = l.ID_LIXEIRA FROM @Lista l WHERE l.ORDEM = @i;
        SET @Msg = N'';
        BEGIN TRY
            IF @TranCountEntrada = 0 BEGIN TRANSACTION;
                EXEC SIS.SIS_Lixeira_Apagar @IdLixeira = @Id, @Usuario = @Usuario, @Motivo = @Motivo, @Mensagem = @Msg OUTPUT;
            IF @TranCountEntrada = 0 COMMIT TRANSACTION;

            IF ISNULL(@Msg, N'') = N'' SET @Apagados = @Apagados + 1;
            ELSE
            BEGIN
                SET @Recusados = @Recusados + 1;
                IF @PrimeiraRecusa = N'' SET @PrimeiraRecusa = @Msg;
            END;
        END TRY
        BEGIN CATCH
            IF @TranCountEntrada = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            IF XACT_STATE() <> -1
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual + N' ' + CAST(@Id AS NVARCHAR(20)), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
            SET @Recusados = @Recusados + 1;
            IF @PrimeiraRecusa = N'' SET @PrimeiraRecusa = N'Um registro não pôde ser apagado (erro registrado para análise).';
            IF XACT_STATE() = -1 BREAK;
        END CATCH;
        SET @i = @i + 1;
    END;

    SELECT CAST(CASE WHEN @Apagados > 0 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
           CAST(LEFT(CAST(@Apagados AS NVARCHAR(10)) + N' registro(s) apagado(s) de vez.'
                + CASE WHEN @Recusados > 0 THEN N' ' + CAST(@Recusados AS NVARCHAR(10)) + N' não apagado(s): ' + @PrimeiraRecusa ELSE N'' END, 400) AS NVARCHAR(400)) AS MENSAGEM,
           @Apagados AS QTD_APAGADOS, @Recusados AS QTD_RECUSADOS;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Lista da tela Sistema › Lixeira (P20), uma tela só para todos
                os módulos: filtros por módulo, tela, período da exclusão,
                quem excluiu, texto e situação (padrão LIXEIRA; '' = todas,
                para ver o histórico de recuperados e apagados). Só traz os
                registros das telas que o usuário pode ver. APAGA_LOGO = 1
                quando o registro será apagado dentro do prazo do aviso
                (LIXEIRA_AVISO_DIAS, "apaga amanhã").
                Permissão: VER em SIS_LIXEIRA.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Lixeira_Listar @IdUsuario = 2, @Modulo = 'CAD', @Situacao = '';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Listar]
    @IdUsuario  INT,
    @Modulo     VARCHAR(10)   = NULL,
    @Item       VARCHAR(40)   = NULL,
    @DtInicio   DATE          = NULL,
    @DtFim      DATE          = NULL,
    @Usuario    NVARCHAR(100) = NULL,
    @Texto      NVARCHAR(100) = NULL,
    @Situacao   VARCHAR(12)   = 'LIXEIRA'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje DATE = CAST(SYSDATETIME() AS DATE);
    DECLARE @Aviso INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a lixeira.', 1;

        SET @Modulo   = NULLIF(LTRIM(RTRIM(ISNULL(@Modulo, ''))), '');
        SET @Item     = NULLIF(LTRIM(RTRIM(ISNULL(@Item, ''))), '');
        SET @Usuario  = NULLIF(LTRIM(RTRIM(ISNULL(@Usuario, N''))), N'');
        SET @Texto    = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @Situacao = NULLIF(LTRIM(RTRIM(ISNULL(@Situacao, ''))), '');
        SET @Aviso    = SIS.fn_SIS_Parametro_Inteiro('LIXEIRA_AVISO_DIAS');

        SET @EtapaAtual = 'Consulta';
        SELECT l.ID_LIXEIRA,
               m.CODIGO AS MODULO_CODIGO,
               m.NOME   AS MODULO_NOME,
               l.ITEM_CODIGO,
               i.NOME   AS TELA_NOME,
               CAST(l.TABELA AS NVARCHAR(256)) AS TABELA,
               l.ID_REGISTRO,
               l.DESCRICAO,
               l.MOTIVO,
               l.DT_EXCLUSAO,
               l.USUARIO_EXCLUSAO,
               l.DT_APAGAR,
               CAST(CASE WHEN l.SITUACAO = 'LIXEIRA' THEN DATEDIFF(DAY, @Hoje, l.DT_APAGAR) ELSE 0 END AS INT) AS DIAS_RESTANTES,
               CAST(CASE WHEN l.SITUACAO = 'LIXEIRA' AND @Aviso > 0 AND l.DT_APAGAR <= DATEADD(DAY, @Aviso, @Hoje) THEN 1 ELSE 0 END AS BIT) AS APAGA_LOGO,
               l.SITUACAO,
               l.DT_SITUACAO,
               l.USUARIO_SITUACAO,
               l.MOTIVO_SITUACAO,
               l.DT_AVISO
        FROM SIS.Lixeira l WITH (NOLOCK)
        INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.CODIGO    = l.ITEM_CODIGO
        INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
        WHERE (@Situacao IS NULL OR l.SITUACAO = @Situacao)
          AND (@Modulo   IS NULL OR m.CODIGO = @Modulo)
          AND (@Item     IS NULL OR l.ITEM_CODIGO = @Item)
          AND (@DtInicio IS NULL OR l.DT_EXCLUSAO >= @DtInicio)
          AND (@DtFim    IS NULL OR l.DT_EXCLUSAO <  DATEADD(DAY, 1, @DtFim))
          AND (@Usuario  IS NULL OR l.USUARIO_EXCLUSAO = @Usuario)
          AND (@Texto    IS NULL OR l.DESCRICAO LIKE N'%' + @Texto + N'%' OR l.MOTIVO LIKE N'%' + @Texto + N'%')
          AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, l.ITEM_CODIGO, 'VER') = 1
        ORDER BY m.ORDEM_MENU, i.ORDEM, l.DT_EXCLUSAO DESC, l.ID_LIXEIRA DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar a lixeira. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Prazo_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Prazo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Prazos da lixeira por tela (P20), para a tela Sistema ›
                Lixeira: tela, módulo, prazo próprio (vazio = vale o geral),
                prazo que vale e quantos registros estão na lixeira. Só as
                telas que o usuário pode ver.
                Permissão: VER em SIS_LIXEIRA.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Prazo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Prazo_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Prazo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a lixeira.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT CAST(c.TABELA AS NVARCHAR(256)) AS TABELA,
               x.ITEM_CODIGO,
               i.NOME AS TELA_NOME,
               m.CODIGO AS MODULO_CODIGO,
               m.NOME AS MODULO_NOME,
               c.DIAS_GUARDA,
               SIS.fn_SIS_Lixeira_Dias(c.TABELA) AS DIAS_VALE,
               SIS.fn_SIS_Parametro_Inteiro('LIXEIRA_DIAS_GUARDA') AS DIAS_GERAL,
               (SELECT COUNT(*) FROM SIS.Lixeira l WITH (NOLOCK) WHERE l.TABELA = c.TABELA AND l.SITUACAO = 'LIXEIRA') AS QTD_NA_LIXEIRA
        FROM SIS.Tabela_Config c WITH (NOLOCK)
        CROSS APPLY (SELECT SIS.fn_SIS_Item_Da_Tabela(c.TABELA) AS ITEM_CODIGO) x
        INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.CODIGO = x.ITEM_CODIGO
        INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
        WHERE c.ATIVO = 1
          AND c.PERMITE_LIXEIRA = 1
          AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, x.ITEM_CODIGO, 'VER') = 1
        ORDER BY m.ORDEM_MENU, i.ORDEM, c.TABELA;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar os prazos da lixeira. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Prazo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Prazo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Prazo próprio da lixeira para uma tela (P20). @Dias vazio
                (NULL) = volta a valer o prazo geral (LIXEIRA_DIAS_GUARDA).
                Vale para o que for excluído daqui em diante; o que já está na
                lixeira mantém a data marcada (use "Manter mais N dias").
                Permissão: ALTERAR em SIS_LIXEIRA e VER na tela.
                Devolve 1 linha: SUCESSO, MENSAGEM.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Prazo_Gravar @IdUsuario = 2, @Tabela = N'CAD.Pessoa', @Dias = 120;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Prazo_Gravar]
    @IdUsuario  INT,
    @Tabela     NVARCHAR(256),
    @Dias       INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Prazo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa NVARCHAR(400) = N'', @Usuario NVARCHAR(100);

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para mudar o prazo da lixeira.';
        ELSE IF NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela AND c.ATIVO = 1 AND c.PERMITE_LIXEIRA = 1)
            SET @Recusa = N'Esta tela não usa a lixeira.';
        ELSE IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, SIS.fn_SIS_Item_Da_Tabela(@Tabela), 'VER') = 0
            SET @Recusa = N'Você não tem permissão para ver esta tela.';
        ELSE IF @Dias IS NOT NULL AND @Dias NOT BETWEEN 1 AND 3650
            SET @Recusa = N'Informe de 1 a 3650 dias, ou deixe em branco para usar o prazo geral.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        UPDATE c
           SET c.DIAS_GUARDA = @Dias, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Tabela_Config c
        WHERE c.TABELA = @Tabela
          AND ISNULL(c.DIAS_GUARDA, -1) <> ISNULL(@Dias, -1);

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Dias IS NULL THEN N'Prazo próprio retirado: vale o prazo geral (' + CAST(SIS.fn_SIS_Lixeira_Dias(@Tabela) AS NVARCHAR(10)) + N' dias).'
                         ELSE N'Prazo gravado: ' + CAST(@Dias AS NVARCHAR(10)) + N' dias, para o que for excluído daqui em diante.' END AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o prazo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lixeira_Processar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Rotina diária da lixeira (P20; rotina LIXEIRA_LIMPEZA):
                  1) limpeza (liga/desliga LIXEIRA_LIMPEZA_ATIVA): apaga de vez
                     o que passou do prazo (DT_APAGAR até hoje). O que passou a
                     ser usado não é apagado: o motivo fica na linha da lixeira
                     e sai no aviso;
                  2) aviso: um e-mail para o grupo do parâmetro
                     LIXEIRA_AVISO_GRUPO com o que será apagado nos próximos
                     LIXEIRA_AVISO_DIAS dia(s) e ainda não foi avisado. Sem
                     nada para avisar, não sai e-mail. Em teste (@bRunLocal),
                     o aviso vai para o EMAIL_TESTE e não marca "avisado".
                Blocos independentes (regra 13): no fim, se algum falhou,
                relança um erro agregado (a rotina fica com resultado ERRO).
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Processar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Processar]
    @bRunLocal  BIT = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Sem XACT_ABORT: laço isolado na limpeza (regras 2 e 13).
    SET @bRunLocal = ISNULL(@bRunLocal, CASE WHEN DB_NAME() LIKE '%[_]LOCAL' THEN 1 ELSE 0 END);

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Limpeza';
    DECLARE @Hoje DATE = CAST(SYSDATETIME() AS DATE);
    DECLARE @Vencidos TABLE (ORDEM INT IDENTITY(1,1), ID_LIXEIRA BIGINT);
    DECLARE @Aviso TABLE (ID_LIXEIRA BIGINT PRIMARY KEY);
    DECLARE @i INT = 1, @Total INT, @Id BIGINT, @Msg NVARCHAR(400), @Falhas INT = 0;
    DECLARE @Dias INT, @Grupo VARCHAR(30), @Para NVARCHAR(MAX), @Linhas NVARCHAR(MAX), @Corpo NVARCHAR(MAX), @Assunto NVARCHAR(400), @Chave NVARCHAR(200), @IdEmail BIGINT;
    DECLARE @Qtd INT;

    -- 1) Limpeza do que venceu
    BEGIN TRY
        IF SIS.fn_SIS_Parametro_SN('LIXEIRA_LIMPEZA_ATIVA') = 1
        BEGIN
            INSERT INTO @Vencidos (ID_LIXEIRA)
            SELECT l.ID_LIXEIRA FROM SIS.Lixeira l WHERE l.SITUACAO = 'LIXEIRA' AND l.DT_APAGAR <= @Hoje ORDER BY l.ID_LIXEIRA;
            SELECT @Total = COUNT(*) FROM @Vencidos;

            WHILE @i <= @Total
            BEGIN
                SELECT @Id = v.ID_LIXEIRA FROM @Vencidos v WHERE v.ORDEM = @i;
                SET @Msg = N'';
                BEGIN TRY
                    BEGIN TRANSACTION;
                        EXEC SIS.SIS_Lixeira_Apagar @IdLixeira = @Id, @Usuario = N'rotina', @Motivo = N'Prazo da lixeira vencido', @Mensagem = @Msg OUTPUT;
                        IF ISNULL(@Msg, N'') <> N''
                            UPDATE l SET l.MOTIVO_SITUACAO = @Msg, l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = N'rotina'
                            FROM SIS.Lixeira l WHERE l.ID_LIXEIRA = @Id AND l.SITUACAO = 'LIXEIRA' AND l.MOTIVO_SITUACAO <> @Msg;
                    COMMIT TRANSACTION;
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                    INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                    VALUES (@NomeProc, N'Limpeza ' + CAST(@Id AS NVARCHAR(20)), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
                    SET @Falhas = @Falhas + 1;
                END CATCH;
                SET @i = @i + 1;
            END;
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SET @Falhas = @Falhas + 1;
    END CATCH;

    -- 2) Aviso do que vai ser apagado
    BEGIN TRY
        SET @EtapaAtual = 'Aviso';
        SET @Dias  = SIS.fn_SIS_Parametro_Inteiro('LIXEIRA_AVISO_DIAS');
        SET @Grupo = CONVERT(VARCHAR(30), LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('LIXEIRA_AVISO_GRUPO'), N''))));

        IF @Dias > 0
        BEGIN
            INSERT INTO @Aviso (ID_LIXEIRA)
            SELECT l.ID_LIXEIRA
            FROM SIS.Lixeira l
            WHERE l.SITUACAO = 'LIXEIRA'
              AND l.DT_AVISO IS NULL
              AND l.DT_APAGAR <= DATEADD(DAY, @Dias, @Hoje);
            SELECT @Qtd = COUNT(*) FROM @Aviso;

            SET @Para = CASE WHEN @Grupo = '' THEN N'' ELSE SIS.fn_SIS_Emails_Do_Grupo(@Grupo) END;
            IF @Qtd > 0 AND @Para = N''
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, 0, N'Aviso da lixeira não enviado: o grupo de e-mail do parâmetro LIXEIRA_AVISO_GRUPO está vazio ou sem destinatário.', 0, SYSDATETIME());

            IF @Qtd > 0 AND @Para <> N''
            BEGIN
                SELECT @Linhas = STRING_AGG(CONVERT(NVARCHAR(MAX),
                           N'<tr style="background:' + CASE WHEN x.N % 2 = 0 THEN N'#f5f5f5' ELSE N'#ffffff' END + N'">'
                         + N'<td style="padding:6px;border-bottom:1px solid #eeeeee">' + SIS.fn_SIS_Texto_HTML(ISNULL(x.MODULO, N'') + N' › ' + ISNULL(x.TELA, N'')) + N'</td>'
                         + N'<td style="padding:6px;border-bottom:1px solid #eeeeee">' + SIS.fn_SIS_Texto_HTML(ISNULL(x.DESCRICAO, N''))
                         + CASE WHEN ISNULL(x.MOTIVO_SITUACAO, N'') <> N'' THEN N'<br><span style="color:#E65100">' + SIS.fn_SIS_Texto_HTML(x.MOTIVO_SITUACAO) + N'</span>' ELSE N'' END + N'</td>'
                         + N'<td style="padding:6px;border-bottom:1px solid #eeeeee">' + SIS.fn_SIS_Texto_HTML(ISNULL(x.USUARIO_EXCLUSAO, N'')) + N'<br>' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(x.DT_EXCLUSAO), N'') + N'</td>'
                         + N'<td style="padding:6px;border-bottom:1px solid #eeeeee;text-align:center">' + ISNULL(SIS.fn_SIS_Formatar_Data(x.DT_APAGAR), N'') + N'</td></tr>'), N'')
                       WITHIN GROUP (ORDER BY x.N)
                FROM (SELECT ROW_NUMBER() OVER (ORDER BY l.DT_APAGAR, m.ORDEM_MENU, i.ORDEM, l.ID_LIXEIRA) AS N,
                             m.NOME AS MODULO, i.NOME AS TELA, l.DESCRICAO, l.MOTIVO_SITUACAO, l.USUARIO_EXCLUSAO, l.DT_EXCLUSAO, l.DT_APAGAR
                      FROM @Aviso a
                      INNER JOIN SIS.Lixeira l ON l.ID_LIXEIRA = a.ID_LIXEIRA
                      LEFT  JOIN SIS.Item   i ON i.CODIGO = l.ITEM_CODIGO
                      LEFT  JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO) x;

                SET @Corpo = SIS.fn_SIS_Email_HTML(N'Lixeira: registros que serão apagados de vez', 'INFO',
                    N'<p>Os registros abaixo estão na lixeira e serão <b>apagados de vez</b> na data indicada. '
                    + N'Para manter algum, abra <b>Sistema › Lixeira</b> e use <b>Recuperar</b> ou <b>Manter mais N dias</b>.</p>'
                    + N'<table style="width:100%;border-collapse:collapse;font-size:13px">'
                    + N'<tr style="background:#eeeeee"><th style="padding:6px;text-align:left">Módulo › Tela</th><th style="padding:6px;text-align:left">Registro</th>'
                    + N'<th style="padding:6px;text-align:left">Excluído por / em</th><th style="padding:6px">Apaga em</th></tr>'
                    + ISNULL(@Linhas, N'') + N'</table>',
                    @NomeProc, @Grupo, 0);

                SET @Assunto = LEFT(ISNULL(SIS.fn_SIS_Parametro('SISTEMA_NOME'), N'SisCMJ') + N' - Lixeira: ' + CAST(@Qtd AS NVARCHAR(10))
                             + N' registro(s) serão apagados de vez', 400);
                SET @Chave = N'LIXEIRA_AVISO_' + CONVERT(NVARCHAR(8), @Hoje, 112) + N'_' + CAST((SELECT MAX(a.ID_LIXEIRA) FROM @Aviso a) AS NVARCHAR(20))
                           + CASE WHEN @bRunLocal = 1 THEN N'_' + CONVERT(NVARCHAR(30), SYSDATETIME(), 126) ELSE N'' END;

                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @Assunto, @CorpoHTML = @Corpo, @Tipo = 'LIXEIRA_AVISO',
                     @Origem = @NomeProc, @ChaveOrigem = @Chave, @Grupo = @Grupo, @IdEmail = @IdEmail OUTPUT;

                IF @bRunLocal = 0 AND @IdEmail IS NOT NULL
                    UPDATE l SET l.DT_AVISO = SYSDATETIME()
                    FROM SIS.Lixeira l
                    INNER JOIN @Aviso a ON a.ID_LIXEIRA = l.ID_LIXEIRA
                    WHERE l.DT_AVISO IS NULL;
            END;
        END;
    END TRY
    BEGIN CATCH
        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SET @Falhas = @Falhas + 1;
    END CATCH;

    IF @Falhas > 0
        THROW 50002, N'Rotina da lixeira terminou com falha (ver o log de erros).', 1;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Historico_Desfazer_Montar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Historico_Desfazer_Montar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Motor do desfazer pelo histórico (P20). Monta, sem gravar
                nada, o plano do que vai mudar, na tabela #Desfazer_Plano
                criada por quem chama (SIS_Historico_Desfazer_Previa e
                SIS_Historico_Desfazer). Modos:
                  REGISTRO  voltar o registro (e as filhas que vão junto) para
                            como estava logo depois da operação @IdAuditoria,
                            ou na data/hora @DataHora;
                  OPERACAO  desfazer a operação (transação) da linha
                            @IdAuditoria;
                  LOTE      desfazer tudo o que o lote @IdLote fez.
                Para cada campo alterado: o valor novo é o "antes" da primeira
                mudança do conjunto; só muda se hoje o campo estiver igual ao
                "depois" da última (senão CONFLITO: alguém mexeu depois).
                Inclusão no conjunto: conforme SIS.Tabela_Config.
                DESFAZER_INCLUSAO (LIXEIRA, DESATIVAR, APAGAR ou RECUSAR).
                Exclusão definitiva no conjunto: conforme DESFAZER_EXCLUSAO
                (REINSERIR, só tabelas de ligação como permissões, ou RECUSAR).
                No modo REGISTRO entram também as filhas que vão junto,
                inclusive as já apagadas (achadas pela foto da auditoria).
                BLOQUEADO: tabela sem desfazer, registro apagado de vez ou na
                lixeira, mês fechado, trava própria. IGNORADO: campo sigiloso,
                bloqueado na configuração, de controle ou a marca da lixeira.
                Comparação de texto em binário, igual à trigger de auditoria.
                Uso interno (DENY para a API).
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Historico_Desfazer_Montar]
    @Modo         VARCHAR(10),
    @Tabela       NVARCHAR(256) = NULL,
    @IdRegistro   BIGINT        = NULL,
    @IdAuditoria  BIGINT        = NULL,
    @DataHora     DATETIME2(0)  = NULL,
    @IdLote       BIGINT        = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Limite BIGINT, @Transacao BIGINT, @Sql NVARCHAR(MAX), @Lista NVARCHAR(MAX);
    DECLARE @i INT, @Total INT, @T NVARCHAR(256), @ObjId INT, @Pk NVARCHAR(128), @Nome NVARCHAR(300), @DescSql NVARCHAR(1000);
    DECLARE @Id BIGINT, @Msg NVARCHAR(400), @ColData NVARCHAR(128), @DataNova DATE;

    DROP TABLE IF EXISTS #Reg;
    DROP TABLE IF EXISTS #Lin;
    DROP TABLE IF EXISTS #Campo;
    DROP TABLE IF EXISTS #Atual;
    DROP TABLE IF EXISTS #Rec;
    DROP TABLE IF EXISTS #Tab;

    CREATE TABLE #Reg  (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, PRIMARY KEY (TABELA, ID_REGISTRO));
    CREATE TABLE #Lin  (ID_AUDITORIA BIGINT NOT NULL PRIMARY KEY, TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, OPERACAO CHAR(1) NOT NULL,
                        CAMPO NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL, VALOR_ANTES NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL, VALOR_DEPOIS NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL);
    CREATE TABLE #Campo (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, CAMPO NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
                         PRIMEIRA BIGINT NOT NULL, ULTIMA BIGINT NOT NULL, VALOR_NOVO NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL, VALOR_ESPERADO NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
                         PRIMARY KEY (TABELA, ID_REGISTRO, CAMPO));
    CREATE TABLE #Atual (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, CAMPO NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL, VALOR NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
                         PRIMARY KEY (TABELA, ID_REGISTRO, CAMPO));
    CREATE TABLE #Rec  (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, TEM_I BIT NOT NULL, TEM_E BIT NOT NULL,
                        EXISTE BIT NOT NULL DEFAULT (0), DESCRICAO NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL, BLOQUEIO NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
                        ACAO VARCHAR(10) COLLATE DATABASE_DEFAULT NULL, AVISO NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL, FOTO NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
                        PRIMARY KEY (TABELA, ID_REGISTRO));
    CREATE TABLE #Tab  (ORDEM INT IDENTITY(1,1) NOT NULL, TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL);

    -- 1) Linhas da auditoria que entram no conjunto
    IF @Modo = 'REGISTRO'
    BEGIN
        IF @IdAuditoria IS NOT NULL
        BEGIN
            SELECT @Transacao = a.TRANSACAO, @Limite = a.ID_AUDITORIA FROM SIS.Auditoria a WHERE a.ID_AUDITORIA = @IdAuditoria;
            IF @Transacao IS NOT NULL
                SELECT @Limite = MAX(a.ID_AUDITORIA) FROM SIS.Auditoria a WHERE a.TRANSACAO = @Transacao;
        END;
        IF @Limite IS NULL AND @DataHora IS NOT NULL
            SELECT @Limite = ISNULL(MAX(a.ID_AUDITORIA), 0) FROM SIS.Auditoria a WHERE a.DT_OPERACAO <= @DataHora;
        IF @Limite IS NULL GOTO Fim;

        INSERT INTO #Reg (TABELA, ID_REGISTRO) VALUES (@Tabela, @IdRegistro);

        -- filhas que vão junto: as que existem hoje e as incluídas/apagadas depois do ponto (pela foto da auditoria)
        SET @Sql = N'';
        SELECT @Sql = @Sql
                    + N'INSERT INTO #Reg (TABELA, ID_REGISTRO) SELECT DISTINCT N''' + REPLACE(f.TABELA, N'''', N'''''') + N''', CAST(f.'
                    + QUOTENAME(SIS.fn_SIS_Tabela_PK(f.TABELA)) + N' AS BIGINT) FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(f.TABELA, N'U'))) + N'.'
                    + QUOTENAME(OBJECT_NAME(OBJECT_ID(f.TABELA, N'U'))) + N' f WHERE f.' + QUOTENAME(f.COLUNA) + N' = @Id'
                    + N' AND NOT EXISTS (SELECT 1 FROM #Reg r WHERE r.TABELA = N''' + REPLACE(f.TABELA, N'''', N'''''') + N''' AND r.ID_REGISTRO = f.'
                    + QUOTENAME(SIS.fn_SIS_Tabela_PK(f.TABELA)) + N');' + NCHAR(13) + NCHAR(10)
                    + N'INSERT INTO #Reg (TABELA, ID_REGISTRO) SELECT DISTINCT a.TABELA, a.ID_REGISTRO FROM SIS.Auditoria a'
                    + N' WHERE a.TABELA = N''' + REPLACE(f.TABELA, N'''', N'''''') + N''' AND a.OPERACAO IN (''I'', ''E'') AND a.ID_AUDITORIA > @Limite'
                    + N' AND JSON_VALUE(COALESCE(a.VALOR_DEPOIS, a.VALOR_ANTES), N''$.' + REPLACE(f.COLUNA, N'''', N'''''') + N''') = CAST(@Id AS NVARCHAR(30))'
                    + N' AND NOT EXISTS (SELECT 1 FROM #Reg r WHERE r.TABELA = a.TABELA AND r.ID_REGISTRO = a.ID_REGISTRO);' + NCHAR(13) + NCHAR(10)
        FROM (SELECT LEFT(x.v, LEN(x.v) - CHARINDEX(N'.', REVERSE(x.v))) AS TABELA, RIGHT(x.v, CHARINDEX(N'.', REVERSE(x.v)) - 1) AS COLUNA
              FROM SIS.Tabela_Config c
              CROSS APPLY (SELECT LTRIM(RTRIM(s.value)) AS v FROM STRING_SPLIT(c.TABELAS_FILHAS, N',') s) x
              WHERE c.TABELA = @Tabela AND x.v LIKE N'%_._%._%') f
        WHERE OBJECT_ID(f.TABELA, N'U') IS NOT NULL AND COL_LENGTH(f.TABELA, f.COLUNA) IS NOT NULL AND SIS.fn_SIS_Tabela_PK(f.TABELA) <> N'';
        IF @Sql <> N'' EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Limite BIGINT', @Id = @IdRegistro, @Limite = @Limite;

        INSERT INTO #Lin (ID_AUDITORIA, TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS)
        SELECT a.ID_AUDITORIA, a.TABELA, a.ID_REGISTRO, a.OPERACAO, a.CAMPO, a.VALOR_ANTES, a.VALOR_DEPOIS
        FROM SIS.Auditoria a
        INNER JOIN #Reg r ON r.TABELA = a.TABELA AND r.ID_REGISTRO = a.ID_REGISTRO
        WHERE a.ID_AUDITORIA > @Limite;
    END;

    IF @Modo = 'OPERACAO'
    BEGIN
        SELECT @Transacao = a.TRANSACAO FROM SIS.Auditoria a WHERE a.ID_AUDITORIA = @IdAuditoria;

        INSERT INTO #Lin (ID_AUDITORIA, TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS)
        SELECT a.ID_AUDITORIA, a.TABELA, a.ID_REGISTRO, a.OPERACAO, a.CAMPO, a.VALOR_ANTES, a.VALOR_DEPOIS
        FROM SIS.Auditoria a
        WHERE (@Transacao IS NOT NULL AND a.TRANSACAO = @Transacao)
           OR (@Transacao IS NULL AND a.ID_AUDITORIA = @IdAuditoria);
    END;

    IF @Modo = 'LOTE'
        INSERT INTO #Lin (ID_AUDITORIA, TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS)
        SELECT a.ID_AUDITORIA, a.TABELA, a.ID_REGISTRO, a.OPERACAO, a.CAMPO, a.VALOR_ANTES, a.VALOR_DEPOIS
        FROM SIS.Auditoria a
        WHERE a.ID_LOTE = @IdLote;

    IF NOT EXISTS (SELECT 1 FROM #Lin) GOTO Fim;

    -- 2) Registros e campos
    INSERT INTO #Rec (TABELA, ID_REGISTRO, TEM_I, TEM_E)
    SELECT l.TABELA, l.ID_REGISTRO,
           CAST(MAX(CASE WHEN l.OPERACAO = 'I' THEN 1 ELSE 0 END) AS BIT),
           CAST(MAX(CASE WHEN l.OPERACAO = 'E' THEN 1 ELSE 0 END) AS BIT)
    FROM #Lin l
    GROUP BY l.TABELA, l.ID_REGISTRO;

    INSERT INTO #Campo (TABELA, ID_REGISTRO, CAMPO, PRIMEIRA, ULTIMA)
    SELECT l.TABELA, l.ID_REGISTRO, l.CAMPO, MIN(l.ID_AUDITORIA), MAX(l.ID_AUDITORIA)
    FROM #Lin l
    WHERE l.OPERACAO = 'A' AND l.CAMPO <> N''
    GROUP BY l.TABELA, l.ID_REGISTRO, l.CAMPO;

    UPDATE c SET c.VALOR_NOVO = p.VALOR_ANTES, c.VALOR_ESPERADO = u.VALOR_DEPOIS
    FROM #Campo c
    INNER JOIN #Lin p ON p.ID_AUDITORIA = c.PRIMEIRA
    INNER JOIN #Lin u ON u.ID_AUDITORIA = c.ULTIMA;

    -- inclusão a desativar: o campo ATIVO entra para leitura do valor de hoje
    INSERT INTO #Campo (TABELA, ID_REGISTRO, CAMPO, PRIMEIRA, ULTIMA, VALOR_NOVO, VALOR_ESPERADO)
    SELECT r.TABELA, r.ID_REGISTRO, N'ATIVO', 0, 0, N'0', NULL
    FROM #Rec r
    INNER JOIN SIS.Tabela_Config cf ON cf.TABELA = r.TABELA AND cf.ATIVO = 1 AND cf.DESFAZER_INCLUSAO = 'DESATIVAR'
    WHERE r.TEM_I = 1 AND COL_LENGTH(r.TABELA, N'ATIVO') IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #Campo c WHERE c.TABELA = r.TABELA AND c.ID_REGISTRO = r.ID_REGISTRO AND c.CAMPO = N'ATIVO');

    -- inclusão a desativar: o valor novo do ATIVO é sempre 0 (mesmo que o ATIVO tenha mudado depois)
    UPDATE c SET c.VALOR_NOVO = N'0'
    FROM #Campo c
    INNER JOIN #Rec r ON r.TABELA = c.TABELA AND r.ID_REGISTRO = c.ID_REGISTRO
    INNER JOIN SIS.Tabela_Config cf ON cf.TABELA = r.TABELA AND cf.ATIVO = 1 AND cf.DESFAZER_INCLUSAO = 'DESATIVAR'
    WHERE r.TEM_I = 1 AND c.CAMPO = N'ATIVO';

    -- 3) Valores de hoje, existência e descrição (uma consulta por tabela)
    INSERT INTO #Tab (TABELA) SELECT DISTINCT r.TABELA FROM #Rec r WHERE OBJECT_ID(r.TABELA, N'U') IS NOT NULL AND SIS.fn_SIS_Tabela_PK(r.TABELA) <> N'';
    SELECT @i = 1, @Total = COUNT(*) FROM #Tab;
    WHILE @i <= @Total
    BEGIN
        SELECT @T = t.TABELA FROM #Tab t WHERE t.ORDEM = @i;
        SET @ObjId = OBJECT_ID(@T, N'U');
        SET @Pk = SIS.fn_SIS_Tabela_PK(@T);
        SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));
        SET @DescSql = NULL;
        SELECT @DescSql = NULLIF(LTRIM(RTRIM(cf.DESCRICAO_SQL)), N'') FROM SIS.Tabela_Config cf WHERE cf.TABELA = @T;

        SET @Sql = N'UPDATE r SET r.EXISTE = 1, r.DESCRICAO = LEFT(CONVERT(NVARCHAR(MAX), '
                 + ISNULL(@DescSql, N'CAST(t.' + QUOTENAME(@Pk) + N' AS NVARCHAR(30))') + N'), 400)'
                 + N' FROM #Rec r INNER JOIN ' + @Nome + N' t ON t.' + QUOTENAME(@Pk) + N' = r.ID_REGISTRO WHERE r.TABELA = @T;';
        EXEC sys.sp_executesql @Sql, N'@T NVARCHAR(256)', @T = @T;

        SET @Lista = NULL;
        SELECT @Lista = STRING_AGG(CONVERT(NVARCHAR(MAX),
                   N'(N''' + REPLACE(x.CAMPO, N'''', N'''''') + N''', '
                 + CASE WHEN ty.name IN ('date', 'datetime', 'datetime2', 'smalldatetime', 'datetimeoffset', 'time') THEN N'CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(x.CAMPO) + N', 121)'
                        WHEN ty.name IN ('varbinary', 'binary', 'image', 'timestamp') THEN N'CASE WHEN t.' + QUOTENAME(x.CAMPO) + N' IS NULL THEN NULL ELSE N''***'' END'
                        ELSE N'CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(x.CAMPO) + N')' END + N')'), N', ')
        FROM (SELECT DISTINCT c.CAMPO FROM #Campo c WHERE c.TABELA = @T) x
        INNER JOIN sys.columns col ON col.object_id = @ObjId AND col.name = x.CAMPO
        INNER JOIN sys.types ty ON ty.system_type_id = col.system_type_id AND ty.user_type_id = col.system_type_id
        WHERE ty.name NOT IN ('text', 'ntext', 'geography', 'geometry');

        IF @Lista IS NOT NULL
        BEGIN
            SET @Sql = N'INSERT INTO #Atual (TABELA, ID_REGISTRO, CAMPO, VALOR) SELECT @T, c.ID_REGISTRO, c.CAMPO, v.VALOR'
                     + N' FROM #Campo c INNER JOIN ' + @Nome + N' t ON t.' + QUOTENAME(@Pk) + N' = c.ID_REGISTRO'
                     + N' CROSS APPLY (VALUES ' + @Lista + N') v (CAMPO, VALOR)'
                     + N' WHERE c.TABELA = @T AND v.CAMPO = c.CAMPO;';
            EXEC sys.sp_executesql @Sql, N'@T NVARCHAR(256)', @T = @T;
        END;
        SET @i = @i + 1;
    END;

    -- 4) Decisão por registro: ACAO = CAMPOS, LIXEIRA, DESATIVAR, APAGAR, REINSERIR ou NADA; BLOQUEIO = o que impede
    UPDATE r SET r.FOTO = (SELECT TOP 1 l.VALOR_ANTES FROM #Lin l WHERE l.TABELA = r.TABELA AND l.ID_REGISTRO = r.ID_REGISTRO AND l.OPERACAO = 'E' ORDER BY l.ID_AUDITORIA)
    FROM #Rec r WHERE r.TEM_E = 1;

    UPDATE r SET
           r.BLOQUEIO = CASE
             WHEN cf.TABELA IS NULL OR cf.PERMITE_DESFAZER = 0 THEN N'Este tipo de registro não pode ser desfeito pelo histórico.'
             WHEN r.TEM_I = 1 AND r.TEM_E = 1 THEN NULL
             WHEN r.TEM_E = 1 AND r.EXISTE = 0 AND cf.DESFAZER_EXCLUSAO = 'REINSERIR' THEN NULL
             WHEN r.TEM_E = 1 AND r.EXISTE = 0 THEN N'O registro foi apagado de vez: não dá para desfazer.'
             WHEN r.EXISTE = 0 AND r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'APAGAR' THEN NULL
             WHEN r.EXISTE = 0 THEN N'O registro foi apagado de vez depois: não dá para desfazer.'
             WHEN SIS.fn_SIS_Na_Lixeira(r.TABELA, r.ID_REGISTRO) = 1 THEN N'O registro está na lixeira: recupere-o antes (Sistema › Lixeira).'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'RECUSAR' THEN N'O registro foi incluído nesta operação e este tipo de inclusão não é desfeito.'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'LIXEIRA' AND cf.PERMITE_LIXEIRA = 0 THEN N'O registro foi incluído nesta operação e não pode ir para a lixeira.'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'DESATIVAR' AND COL_LENGTH(r.TABELA, N'ATIVO') IS NULL THEN N'O registro foi incluído nesta operação e não pode ser desativado.'
             END,
           r.ACAO = CASE
             WHEN r.TEM_I = 1 AND r.TEM_E = 1 THEN 'NADA'
             WHEN r.TEM_E = 1 AND r.EXISTE = 0 THEN 'REINSERIR'
             WHEN r.EXISTE = 0 THEN 'NADA'
             WHEN r.TEM_I = 1 THEN cf.DESFAZER_INCLUSAO
             ELSE 'CAMPOS' END,
           r.AVISO = CASE
             WHEN r.TEM_I = 1 AND r.TEM_E = 1 THEN N'Incluído e apagado dentro do que será desfeito: nada a fazer.'
             WHEN r.TEM_E = 1 AND r.EXISTE = 0 THEN N'Apagado nesta operação: volta como estava (com código novo).'
             WHEN r.EXISTE = 0 THEN N'Incluído nesta operação e já não existe: nada a fazer.'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'LIXEIRA' THEN N'Incluído nesta operação: vai para a lixeira (pode ser recuperado).'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'APAGAR' THEN N'Incluído nesta operação: será retirado.'
             END
    FROM #Rec r
    LEFT JOIN SIS.Tabela_Config cf ON cf.TABELA = r.TABELA AND cf.ATIVO = 1;

    UPDATE #Rec SET BLOQUEIO = N'O registro apagado tinha campo sigiloso e não pode voltar.'
    WHERE BLOQUEIO IS NULL AND ACAO = 'REINSERIR' AND FOTO LIKE N'%"***"%';

    -- 5) Plano: registros inteiros (lixeira, apagar, reinserir, nada)
    INSERT INTO #Desfazer_Plano (TABELA, ID_REGISTRO, DESCRICAO, CAMPO, VALOR_ATUAL, VALOR_NOVO, ACAO, SITUACAO, MENSAGEM, ULTIMA_AUDITORIA)
    SELECT r.TABELA, r.ID_REGISTRO, r.DESCRICAO, N'', NULL, CASE WHEN r.ACAO = 'REINSERIR' THEN r.FOTO END,
           r.ACAO, 'OK', r.AVISO,
           (SELECT MAX(l.ID_AUDITORIA) FROM #Lin l WHERE l.TABELA = r.TABELA AND l.ID_REGISTRO = r.ID_REGISTRO)
    FROM #Rec r
    WHERE r.BLOQUEIO IS NULL AND r.ACAO IN ('LIXEIRA', 'APAGAR', 'REINSERIR', 'NADA');

    -- 6) Plano: campos (registros a alterar e inclusões a desativar)
    INSERT INTO #Desfazer_Plano (TABELA, ID_REGISTRO, DESCRICAO, CAMPO, VALOR_ATUAL, VALOR_NOVO, ACAO, SITUACAO, MENSAGEM, ULTIMA_AUDITORIA)
    SELECT c.TABELA, c.ID_REGISTRO, r.DESCRICAO, c.CAMPO, a.VALOR, c.VALOR_NOVO,
           CASE WHEN x.IGNORAR = 1 OR x.JA_ESTA = 1 THEN 'NADA'
                WHEN x.IGUAL_ESPERADO = 1 OR r.ACAO = 'DESATIVAR' THEN 'ALTERAR' ELSE 'NADA' END,
           CASE WHEN x.IGNORAR = 1 THEN 'IGNORADO'
                WHEN x.JA_ESTA = 1 OR x.IGUAL_ESPERADO = 1 OR r.ACAO = 'DESATIVAR' THEN 'OK' ELSE 'CONFLITO' END,
           CAST(CASE WHEN a.CAMPO IS NULL THEN N'O campo não existe mais.'
                     WHEN x.IGNORAR = 1 THEN N'Campo que não é desfeito (sigiloso, calculado, de controle ou marca da lixeira).'
                     WHEN x.JA_ESTA = 1 THEN N'Já está assim.'
                     WHEN r.ACAO = 'DESATIVAR' THEN N'Incluído nesta operação: vai ser desativado.'
                     WHEN x.IGUAL_ESPERADO = 1 THEN N''
                     ELSE LEFT(N'Mudou depois desta operação: hoje está "' + ISNULL(a.VALOR, N'(vazio)') + N'".', 400) END AS NVARCHAR(400)),
           NULLIF(c.ULTIMA, 0)
    FROM #Campo c
    INNER JOIN #Rec r ON r.TABELA = c.TABELA AND r.ID_REGISTRO = c.ID_REGISTRO
    LEFT  JOIN SIS.Tabela_Config cf ON cf.TABELA = c.TABELA
    LEFT  JOIN #Atual a ON a.TABELA = c.TABELA AND a.ID_REGISTRO = c.ID_REGISTRO AND a.CAMPO = c.CAMPO
    CROSS APPLY (SELECT
           CAST(CASE WHEN a.CAMPO IS NULL
                       OR c.CAMPO IN (N'DT_CRIACAO', N'USUARIO_CRIACAO', N'DT_ALTERACAO', N'USUARIO_ALTERACAO', N'DT_EXCLUSAO', N'USUARIO_EXCLUSAO')
                       OR c.CAMPO = SIS.fn_SIS_Tabela_PK(c.TABELA)
                       OR c.VALOR_NOVO = N'***' OR c.VALOR_ESPERADO = N'***' OR a.VALOR = N'***'
                       OR EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(cf.CAMPOS_BLOQUEADOS, N''), N',') s WHERE LTRIM(RTRIM(s.value)) = c.CAMPO)
                     THEN 1 ELSE 0 END AS BIT) AS IGNORAR,
           CAST(CASE WHEN (a.VALOR IS NULL AND c.VALOR_NOVO IS NULL)
                       OR (a.VALOR COLLATE Latin1_General_BIN2 = c.VALOR_NOVO COLLATE Latin1_General_BIN2) THEN 1 ELSE 0 END AS BIT) AS JA_ESTA,
           CAST(CASE WHEN (a.VALOR IS NULL AND c.VALOR_ESPERADO IS NULL)
                       OR (a.VALOR COLLATE Latin1_General_BIN2 = c.VALOR_ESPERADO COLLATE Latin1_General_BIN2) THEN 1 ELSE 0 END AS BIT) AS IGUAL_ESPERADO
        ) x
    WHERE r.BLOQUEIO IS NULL
      AND (r.ACAO = 'CAMPOS' OR (r.ACAO = 'DESATIVAR' AND c.CAMPO = N'ATIVO'));

    -- 7) Travas (mês fechado e trava própria) dos registros que vão mudar e ainda existem
    DROP TABLE IF EXISTS #Trava;
    SELECT ROW_NUMBER() OVER (ORDER BY p.TABELA, p.ID_REGISTRO) AS ORDEM, p.TABELA, p.ID_REGISTRO
    INTO #Trava
    FROM #Desfazer_Plano p
    WHERE p.ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR')
    GROUP BY p.TABELA, p.ID_REGISTRO;

    SELECT @i = 1, @Total = COUNT(*) FROM #Trava;
    WHILE @i <= @Total
    BEGIN
        SELECT @T = t.TABELA, @Id = t.ID_REGISTRO FROM #Trava t WHERE t.ORDEM = @i;
        SET @ColData = NULL;
        SELECT @ColData = NULLIF(cf.COLUNA_DATA_MES, N'') FROM SIS.Tabela_Config cf WHERE cf.TABELA = @T;
        SET @DataNova = (SELECT TOP 1 TRY_CONVERT(DATE, p.VALOR_NOVO, 121) FROM #Desfazer_Plano p
                         WHERE p.TABELA = @T AND p.ID_REGISTRO = @Id AND p.CAMPO = @ColData AND p.ACAO = 'ALTERAR' ORDER BY p.ORDEM);
        SET @Msg = N'';
        EXEC SIS.SIS_Tabela_Trava_Conferir @Tabela = @T, @IdRegistro = @Id, @Operacao = 'DESFAZER', @DataNova = @DataNova, @Mensagem = @Msg OUTPUT;
        IF ISNULL(@Msg, N'') <> N''
            UPDATE #Rec SET BLOQUEIO = @Msg WHERE TABELA = @T AND ID_REGISTRO = @Id;
        SET @i = @i + 1;
    END;
    DROP TABLE IF EXISTS #Trava;

    -- 8) Registros bloqueados: uma linha cada, sem os campos
    DELETE p FROM #Desfazer_Plano p INNER JOIN #Rec r ON r.TABELA = p.TABELA AND r.ID_REGISTRO = p.ID_REGISTRO WHERE r.BLOQUEIO IS NOT NULL;

    INSERT INTO #Desfazer_Plano (TABELA, ID_REGISTRO, DESCRICAO, CAMPO, VALOR_ATUAL, VALOR_NOVO, ACAO, SITUACAO, MENSAGEM, ULTIMA_AUDITORIA)
    SELECT r.TABELA, r.ID_REGISTRO, r.DESCRICAO, N'', NULL, NULL, 'NADA', 'BLOQUEADO', r.BLOQUEIO,
           (SELECT MAX(l.ID_AUDITORIA) FROM #Lin l WHERE l.TABELA = r.TABELA AND l.ID_REGISTRO = r.ID_REGISTRO)
    FROM #Rec r
    WHERE r.BLOQUEIO IS NOT NULL;

Fim:
    DROP TABLE IF EXISTS #Reg;
    DROP TABLE IF EXISTS #Lin;
    DROP TABLE IF EXISTS #Campo;
    DROP TABLE IF EXISTS #Atual;
    DROP TABLE IF EXISTS #Rec;
    DROP TABLE IF EXISTS #Tab;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Historico_Desfazer_Previa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Historico_Desfazer_Previa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Prévia do desfazer pelo histórico (P20), sem gravar nada: o
                que vai mudar, campo a campo (como está agora e como vai
                ficar), o que vai para a lixeira e o que impede (CONFLITO,
                BLOQUEADO). Usada pela aba Histórico das fichas e pela tela de
                Auditoria antes de confirmar. Modos e regras: ver
                SIS_Historico_Desfazer_Montar.
                Permissão: DESFAZER na tela (@Item); no modo REGISTRO a tela
                precisa mostrar a tabela; no modo LOTE, a tela é
                SIS_AUDITORIA.
                Devolve as linhas do plano, com TELA_NOME e as colunas
                PODE_DESFAZER (1 = tudo certo) e RESUMO iguais em todas.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Historico_Desfazer_Previa @IdUsuario = 2, @Item = 'CAD_PESSOA', @Modo = 'REGISTRO', @Tabela = N'CAD.Pessoa', @IdRegistro = 1, @IdAuditoria = 10;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Historico_Desfazer_Previa]
    @IdUsuario    INT,
    @Item         VARCHAR(40),
    @Modo         VARCHAR(10),
    @Tabela       NVARCHAR(256) = NULL,
    @IdRegistro   BIGINT        = NULL,
    @IdAuditoria  BIGINT        = NULL,
    @DataHora     DATETIME2(0)  = NULL,
    @IdLote       BIGINT        = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Historico_Desfazer_Previa]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Pode BIT, @Resumo NVARCHAR(400), @Muda INT, @Impede INT;

    DROP TABLE IF EXISTS #Desfazer_Plano;

    BEGIN TRY
        SET @Modo   = UPPER(LTRIM(RTRIM(ISNULL(@Modo, ''))));
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'DESFAZER') = 0
            THROW 50001, N'Você não tem permissão para desfazer nesta tela.', 1;
        IF @Modo NOT IN ('REGISTRO', 'OPERACAO', 'LOTE')
            THROW 50001, N'Modo de desfazer inválido.', 1;
        IF @Modo = 'REGISTRO' AND (SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0 OR @IdRegistro IS NULL OR (@IdAuditoria IS NULL AND @DataHora IS NULL))
            THROW 50001, N'Escolha o registro e o ponto do histórico para onde voltar.', 1;
        IF @Modo = 'OPERACAO' AND @IdAuditoria IS NULL
            THROW 50001, N'Escolha a operação a desfazer.', 1;
        IF @Modo = 'LOTE' AND (@Item <> 'SIS_AUDITORIA' OR @IdLote IS NULL)
            THROW 50001, N'Escolha o lote a desfazer (tela de Auditoria).', 1;

        SET @EtapaAtual = 'Montagem';
        CREATE TABLE #Desfazer_Plano
        (
            ORDEM             INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            TABELA            NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL,
            ID_REGISTRO       BIGINT        NOT NULL,
            DESCRICAO         NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
            CAMPO             NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
            VALOR_ATUAL       NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
            VALOR_NOVO        NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
            ACAO              VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
            SITUACAO          VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
            MENSAGEM          NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
            ULTIMA_AUDITORIA  BIGINT        NULL
        );

        EXEC SIS.SIS_Historico_Desfazer_Montar @Modo = @Modo, @Tabela = @Tabela, @IdRegistro = @IdRegistro,
             @IdAuditoria = @IdAuditoria, @DataHora = @DataHora, @IdLote = @IdLote;

        SELECT @Muda = COUNT(*) FROM #Desfazer_Plano WHERE ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR', 'REINSERIR');
        SELECT @Impede = COUNT(*) FROM #Desfazer_Plano WHERE SITUACAO IN ('CONFLITO', 'BLOQUEADO');
        SET @Pode = CASE WHEN @Muda > 0 AND @Impede = 0 THEN 1 ELSE 0 END;
        SET @Resumo = CASE WHEN @Impede > 0 THEN CAST(@Impede AS NVARCHAR(10)) + N' ponto(s) impedem desfazer: veja as linhas em vermelho.'
                           WHEN @Muda = 0 THEN N'Nada a desfazer: já está tudo como estava.'
                           ELSE CAST(@Muda AS NVARCHAR(10)) + N' mudança(s) a fazer. Confira e informe o motivo.' END;

        SELECT p.ORDEM,
               p.TABELA,
               ISNULL(i.NOME, p.TABELA) AS TELA_NOME,
               p.ID_REGISTRO,
               ISNULL(p.DESCRICAO, N'') AS DESCRICAO,
               p.CAMPO,
               ISNULL(CAST(p.VALOR_ATUAL AS NVARCHAR(4000)), N'') AS VALOR_ATUAL,
               ISNULL(CAST(p.VALOR_NOVO  AS NVARCHAR(4000)), N'') AS VALOR_NOVO,
               p.ACAO,
               p.SITUACAO,
               ISNULL(p.MENSAGEM, N'') AS MENSAGEM,
               p.ULTIMA_AUDITORIA,
               @Pode AS PODE_DESFAZER,
               @Resumo AS RESUMO
        FROM #Desfazer_Plano p
        LEFT JOIN SIS.Item i ON i.CODIGO = SIS.fn_SIS_Item_Da_Tabela(p.TABELA)
        ORDER BY CASE p.SITUACAO WHEN 'BLOQUEADO' THEN 0 WHEN 'CONFLITO' THEN 1 ELSE 2 END, p.TABELA, p.ID_REGISTRO, p.ORDEM;

        DROP TABLE IF EXISTS #Desfazer_Plano;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1 DROP TABLE IF EXISTS #Desfazer_Plano;
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível montar a prévia. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Historico_Desfazer.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Historico_Desfazer]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Desfaz pelo histórico (P20), depois da prévia
                (SIS_Historico_Desfazer_Previa): voltar um registro a um ponto
                do histórico (REGISTRO), desfazer uma operação (OPERACAO) ou
                um lote inteiro (LOTE, tela de Auditoria).
                Tudo-ou-nada: se houver qualquer CONFLITO ou BLOQUEADO, não
                faz nada. Grava como alteração nova (a auditoria registra
                tudo, com a origem "desfazer"), as inclusões desfeitas vão para
                a lixeira, são desativadas ou retiradas (tabelas de ligação),
                as exclusões de tabelas de ligação voltam com a foto da
                auditoria (código novo), e o pedido fica em SIS.Desfazer
                com o motivo (obrigatório).
                Permissão: DESFAZER na tela (@Item) e, para cada tipo de
                registro que vai mudar, DESFAZER numa tela que o mostra.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_DESFAZER, QTD_REGISTROS,
                QTD_CAMPOS, QTD_LIXEIRA.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Historico_Desfazer @IdUsuario = 2, @Item = 'CAD_PESSOA', @Modo = 'OPERACAO', @IdAuditoria = 10, @Motivo = N'alterado por engano';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Historico_Desfazer]
    @IdUsuario    INT,
    @Item         VARCHAR(40),
    @Modo         VARCHAR(10),
    @Tabela       NVARCHAR(256) = NULL,
    @IdRegistro   BIGINT        = NULL,
    @IdAuditoria  BIGINT        = NULL,
    @DataHora     DATETIME2(0)  = NULL,
    @IdLote       BIGINT        = NULL,
    @Motivo       NVARCHAR(400) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Historico_Desfazer]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @Recusa NVARCHAR(400) = N'', @Usuario NVARCHAR(100), @OrigemAntes NVARCHAR(256), @OrigemNova NVARCHAR(256);
    DECLARE @Muda INT, @Impede INT, @QtdReg INT, @QtdCampos INT, @QtdLixeira INT, @IdDesfazer BIGINT, @Transacao BIGINT;
    DECLARE @Alt TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(256), CAMPO NVARCHAR(128), QTD INT);
    DECLARE @Lix TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(256), ID_REGISTRO BIGINT);
    DECLARE @Apg TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(256), QTD INT);
    DECLARE @Rei TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(256), FOTO NVARCHAR(MAX));
    DECLARE @Foto NVARCHAR(MAX), @Cols NVARCHAR(MAX), @With NVARCHAR(MAX);
    DECLARE @i INT, @Total INT, @T NVARCHAR(256), @C NVARCHAR(128), @Qtd INT, @Feitos INT, @Id BIGINT;
    DECLARE @ObjId INT, @Pk NVARCHAR(128), @Nome NVARCHAR(300), @Tipo NVARCHAR(128), @EData BIT, @Expr NVARCHAR(400), @Sql NVARCHAR(MAX), @IdLixeira BIGINT, @Msg NVARCHAR(400);
    DECLARE @TelaSemPermissao NVARCHAR(256);

    DROP TABLE IF EXISTS #Desfazer_Plano;

    BEGIN TRY
        SET @Modo   = UPPER(LTRIM(RTRIM(ISNULL(@Modo, ''))));
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'DESFAZER') = 0
            SET @Recusa = N'Você não tem permissão para desfazer nesta tela.';
        ELSE IF @Modo NOT IN ('REGISTRO', 'OPERACAO', 'LOTE')
            SET @Recusa = N'Modo de desfazer inválido.';
        ELSE IF @Modo = 'REGISTRO' AND (SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0 OR @IdRegistro IS NULL OR (@IdAuditoria IS NULL AND @DataHora IS NULL))
            SET @Recusa = N'Escolha o registro e o ponto do histórico para onde voltar.';
        ELSE IF @Modo = 'OPERACAO' AND @IdAuditoria IS NULL
            SET @Recusa = N'Escolha a operação a desfazer.';
        ELSE IF @Modo = 'LOTE' AND (@Item <> 'SIS_AUDITORIA' OR @IdLote IS NULL)
            SET @Recusa = N'Escolha o lote a desfazer (tela de Auditoria).';
        ELSE IF LEN(@Motivo) < 3
            SET @Recusa = N'Informe o motivo do desfazer.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_DESFAZER, 0 AS QTD_REGISTROS, 0 AS QTD_CAMPOS, 0 AS QTD_LIXEIRA;
            RETURN;
        END;

        SET @EtapaAtual = 'Montagem';
        CREATE TABLE #Desfazer_Plano
        (
            ORDEM             INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            TABELA            NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL,
            ID_REGISTRO       BIGINT        NOT NULL,
            DESCRICAO         NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
            CAMPO             NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
            VALOR_ATUAL       NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
            VALOR_NOVO        NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
            ACAO              VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
            SITUACAO          VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
            MENSAGEM          NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
            ULTIMA_AUDITORIA  BIGINT        NULL
        );

        EXEC SIS.SIS_Historico_Desfazer_Montar @Modo = @Modo, @Tabela = @Tabela, @IdRegistro = @IdRegistro,
             @IdAuditoria = @IdAuditoria, @DataHora = @DataHora, @IdLote = @IdLote;

        SELECT @Muda = COUNT(*) FROM #Desfazer_Plano WHERE ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR', 'REINSERIR');
        SELECT @Impede = COUNT(*) FROM #Desfazer_Plano WHERE SITUACAO IN ('CONFLITO', 'BLOQUEADO');

        IF @Impede > 0
            SET @Recusa = LEFT(N'Nada foi desfeito: ' + CAST(@Impede AS NVARCHAR(10)) + N' ponto(s) impedem. '
                        + ISNULL((SELECT TOP 1 p.MENSAGEM FROM #Desfazer_Plano p WHERE p.SITUACAO IN ('CONFLITO', 'BLOQUEADO')
                                  ORDER BY CASE p.SITUACAO WHEN 'BLOQUEADO' THEN 0 ELSE 1 END, p.ORDEM), N''), 400);
        ELSE IF @Muda = 0
            SET @Recusa = N'Nada a desfazer: já está tudo como estava.';

        -- Permissão para cada tipo de registro que vai mudar
        IF @Recusa = N''
        BEGIN
            SELECT TOP 1 @TelaSemPermissao = p.TABELA
            FROM (SELECT DISTINCT TABELA FROM #Desfazer_Plano WHERE ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR', 'REINSERIR')) p
            WHERE NOT EXISTS (SELECT 1 FROM SIS.Item it
                              CROSS APPLY STRING_SPLIT(it.TABELAS_DA_TELA, ',') s
                              WHERE LTRIM(RTRIM(s.value)) = p.TABELA AND it.TIPO = 'TELA'
                                AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, it.CODIGO, 'DESFAZER') = 1)
            ORDER BY p.TABELA;
            IF @TelaSemPermissao IS NOT NULL
                SET @Recusa = LEFT(N'Você não tem permissão para desfazer em ' + ISNULL((SELECT i.NOME FROM SIS.Item i WHERE i.CODIGO = SIS.fn_SIS_Item_Da_Tabela(@TelaSemPermissao)), @TelaSemPermissao) + N'.', 400);
        END;

        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Desfazer_Plano;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_DESFAZER, 0 AS QTD_REGISTROS, 0 AS QTD_CAMPOS, 0 AS QTD_LIXEIRA;
            RETURN;
        END;

        INSERT INTO @Alt (TABELA, CAMPO, QTD)
        SELECT p.TABELA, p.CAMPO, COUNT(*) FROM #Desfazer_Plano p WHERE p.ACAO = 'ALTERAR' GROUP BY p.TABELA, p.CAMPO ORDER BY p.TABELA, p.CAMPO;
        INSERT INTO @Lix (TABELA, ID_REGISTRO)
        SELECT p.TABELA, p.ID_REGISTRO FROM #Desfazer_Plano p WHERE p.ACAO = 'LIXEIRA' ORDER BY p.ORDEM DESC;
        INSERT INTO @Apg (TABELA, QTD)
        SELECT p.TABELA, COUNT(*) FROM #Desfazer_Plano p WHERE p.ACAO = 'APAGAR' GROUP BY p.TABELA ORDER BY p.TABELA;
        INSERT INTO @Rei (TABELA, FOTO)
        SELECT p.TABELA, p.VALOR_NOVO FROM #Desfazer_Plano p WHERE p.ACAO = 'REINSERIR' ORDER BY p.ORDEM;

        SELECT @QtdReg = COUNT(*) FROM (SELECT DISTINCT TABELA, ID_REGISTRO FROM #Desfazer_Plano WHERE ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR', 'REINSERIR')) x;
        SELECT @QtdCampos = COUNT(*) FROM #Desfazer_Plano WHERE ACAO = 'ALTERAR';
        SELECT @QtdLixeira = COUNT(*) FROM @Lix;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @OrigemAntes = ISNULL(CONVERT(NVARCHAR(256), SESSION_CONTEXT(N'ORIGEM')), N'');
        SET @OrigemNova = LEFT(CASE WHEN @OrigemAntes = N'' THEN N'' ELSE @OrigemAntes + N' › ' END + N'desfazer', 256);

        SET @EtapaAtual = 'Gravação';
        IF @TranCountEntrada = 0 BEGIN TRANSACTION;

            EXEC sys.sp_set_session_context @key = N'ORIGEM', @value = @OrigemNova;
            SET @Transacao = CURRENT_TRANSACTION_ID();

            -- Inclusões de tabelas de ligação: retiradas
            SELECT @i = 1, @Total = COUNT(*) FROM @Apg;
            WHILE @i <= @Total
            BEGIN
                SELECT @T = a.TABELA, @Qtd = a.QTD FROM @Apg a WHERE a.ORDEM = @i;
                SET @ObjId = OBJECT_ID(@T, N'U');
                SET @Pk = SIS.fn_SIS_Tabela_PK(@T);
                SET @Sql = N'DELETE t FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N' t'
                         + N' INNER JOIN #Desfazer_Plano p ON p.ID_REGISTRO = t.' + QUOTENAME(@Pk) + N' WHERE p.TABELA = @T AND p.ACAO = ''APAGAR''; SET @n = @@ROWCOUNT;';
                SET @Feitos = 0;
                EXEC sys.sp_executesql @Sql, N'@T NVARCHAR(256), @n INT OUTPUT', @T = @T, @n = @Feitos OUTPUT;
                IF ISNULL(@Feitos, 0) <> @Qtd
                    THROW 50003, N'Nada foi desfeito: alguém mudou estes registros enquanto a prévia estava aberta. Abra a prévia de novo.', 1;
                SET @i = @i + 1;
            END;

            -- Campos: um UPDATE por tabela e campo, só onde o valor de hoje ainda é o da prévia
            SELECT @i = 1, @Total = COUNT(*) FROM @Alt;
            WHILE @i <= @Total
            BEGIN
                SELECT @T = a.TABELA, @C = a.CAMPO, @Qtd = a.QTD FROM @Alt a WHERE a.ORDEM = @i;
                SET @ObjId = OBJECT_ID(@T, N'U');
                SET @Pk = SIS.fn_SIS_Tabela_PK(@T);
                SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));
                SET @Tipo = SIS.fn_SIS_Coluna_Tipo(@T, @C);
                SET @EData = CASE WHEN @Tipo LIKE N'DATE%' OR @Tipo LIKE N'TIME%' OR @Tipo LIKE N'SMALLDATETIME%' THEN 1 ELSE 0 END;
                SET @Expr = CASE WHEN @EData = 1 THEN N'CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(@C) + N', 121)' ELSE N'CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(@C) + N')' END;

                SET @Sql = N'UPDATE t SET t.' + QUOTENAME(@C) + N' = CONVERT(' + @Tipo + N', p.VALOR_NOVO' + CASE WHEN @EData = 1 THEN N', 121' ELSE N'' END + N')'
                         + CASE WHEN COL_LENGTH(@T, N'DT_ALTERACAO') IS NOT NULL AND COL_LENGTH(@T, N'USUARIO_ALTERACAO') IS NOT NULL AND @C NOT IN (N'DT_ALTERACAO', N'USUARIO_ALTERACAO')
                                THEN N', t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario' ELSE N'' END
                         + N' FROM ' + @Nome + N' t INNER JOIN #Desfazer_Plano p ON p.ID_REGISTRO = t.' + QUOTENAME(@Pk)
                         + N' WHERE p.TABELA = @T AND p.CAMPO = @C AND p.ACAO = ''ALTERAR'''
                         + N' AND ((' + @Expr + N' IS NULL AND p.VALOR_ATUAL IS NULL) OR (' + @Expr + N' COLLATE Latin1_General_BIN2 = p.VALOR_ATUAL COLLATE Latin1_General_BIN2));'
                         + N' SET @n = @@ROWCOUNT;';
                SET @Feitos = 0;
                EXEC sys.sp_executesql @Sql, N'@T NVARCHAR(256), @C NVARCHAR(128), @Usuario NVARCHAR(100), @n INT OUTPUT', @T = @T, @C = @C, @Usuario = @Usuario, @n = @Feitos OUTPUT;
                IF ISNULL(@Feitos, 0) <> @Qtd
                    THROW 50003, N'Nada foi desfeito: alguém mudou estes registros enquanto a prévia estava aberta. Abra a prévia de novo.', 1;
                SET @i = @i + 1;
            END;

            -- Exclusões de tabelas de ligação: voltam com a foto da auditoria (código novo)
            SELECT @i = 1, @Total = COUNT(*) FROM @Rei;
            WHILE @i <= @Total
            BEGIN
                SELECT @T = r.TABELA, @Foto = r.FOTO FROM @Rei r WHERE r.ORDEM = @i;
                SET @ObjId = OBJECT_ID(@T, N'U');
                SELECT @Cols = STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), N', ') WITHIN GROUP (ORDER BY c.column_id),
                       @With = STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name) + N' ' + SIS.fn_SIS_Coluna_Tipo(@T, c.name) + N' ''$.' + REPLACE(c.name, N'''', N'''''') + N''''), N', ')
                                 WITHIN GROUP (ORDER BY c.column_id)
                FROM sys.columns c
                INNER JOIN sys.types ty ON ty.system_type_id = c.system_type_id AND ty.user_type_id = c.system_type_id
                WHERE c.object_id = @ObjId AND c.is_identity = 0 AND c.is_computed = 0
                  AND c.name NOT IN (N'DT_CRIACAO', N'USUARIO_CRIACAO', N'DT_ALTERACAO', N'USUARIO_ALTERACAO')
                  AND ty.name NOT IN ('varbinary', 'binary', 'image', 'timestamp', 'text', 'ntext', 'geography', 'geometry');
                SET @Sql = N'INSERT INTO ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N' (' + @Cols + N')'
                         + N' SELECT ' + @Cols + N' FROM OPENJSON(@Foto) WITH (' + @With + N');';
                BEGIN TRY
                    EXEC sys.sp_executesql @Sql, N'@Foto NVARCHAR(MAX)', @Foto = @Foto;
                END TRY
                BEGIN CATCH
                    IF ERROR_NUMBER() IN (2601, 2627)
                        THROW 50003, N'Nada foi desfeito: um registro apagado não pode voltar porque já existe outro igual.', 1;
                    THROW;
                END CATCH;
                SET @i = @i + 1;
            END;

            -- Inclusões desfeitas: para a lixeira (das filhas para o principal)
            SELECT @i = 1, @Total = COUNT(*) FROM @Lix;
            WHILE @i <= @Total
            BEGIN
                SELECT @T = l.TABELA, @Id = l.ID_REGISTRO FROM @Lix l WHERE l.ORDEM = @i;
                SET @Msg = N'';
                EXEC SIS.SIS_Lixeira_Marcar @IdUsuario = @IdUsuario, @Tabela = @T, @IdRegistro = @Id, @Item = NULL,
                     @Motivo = @Motivo, @IdLixeira = @IdLixeira OUTPUT, @Mensagem = @Msg OUTPUT;
                IF ISNULL(@Msg, N'') <> N''
                BEGIN
                    SET @Msg = LEFT(N'Nada foi desfeito: um registro incluído não pôde ir para a lixeira. ' + @Msg, 400);
                    THROW 50003, @Msg, 1;
                END;
                SET @i = @i + 1;
            END;

            INSERT INTO SIS.Desfazer (TIPO, ITEM_CODIGO, TABELA, ID_REGISTRO, ID_AUDITORIA, DT_ALVO, TRANSACAO_ALVO, ID_LOTE_ALVO, MOTIVO,
                                      QTD_REGISTROS, QTD_CAMPOS, QTD_LIXEIRA, TRANSACAO, ID_USUARIO, USUARIO)
            VALUES (@Modo, ISNULL(@Item, ''), @Tabela, @IdRegistro, @IdAuditoria, @DataHora,
                    CASE WHEN @Modo = 'OPERACAO' THEN (SELECT a.TRANSACAO FROM SIS.Auditoria a WHERE a.ID_AUDITORIA = @IdAuditoria) END,
                    @IdLote, @Motivo, ISNULL(@QtdReg, 0), ISNULL(@QtdCampos, 0), ISNULL(@QtdLixeira, 0), @Transacao, @IdUsuario, ISNULL(@Usuario, N''));
            SET @IdDesfazer = SCOPE_IDENTITY();

            EXEC sys.sp_set_session_context @key = N'ORIGEM', @value = @OrigemAntes;
        IF @TranCountEntrada = 0 COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Desfazer_Plano;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Desfeito: ' + CAST(ISNULL(@QtdCampos, 0) AS NVARCHAR(10)) + N' campo(s) em ' + CAST(ISNULL(@QtdReg, 0) AS NVARCHAR(10)) + N' registro(s)'
                    + CASE WHEN @QtdLixeira > 0 THEN N'; ' + CAST(@QtdLixeira AS NVARCHAR(10)) + N' registro(s) incluído(s) foram para a lixeira' ELSE N'' END
                    + CASE WHEN (SELECT ISNULL(SUM(a.QTD), 0) FROM @Apg a) > 0 THEN N'; ' + CAST((SELECT SUM(a.QTD) FROM @Apg a) AS NVARCHAR(10)) + N' retirado(s)' ELSE N'' END
                    + CASE WHEN (SELECT COUNT(*) FROM @Rei) > 0 THEN N'; ' + CAST((SELECT COUNT(*) FROM @Rei) AS NVARCHAR(10)) + N' devolvido(s)' ELSE N'' END
                    + N'. Tudo ficou no histórico.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdDesfazer AS ID_DESFAZER, ISNULL(@QtdReg, 0) AS QTD_REGISTROS, ISNULL(@QtdCampos, 0) AS QTD_CAMPOS, ISNULL(@QtdLixeira, 0) AS QTD_LIXEIRA;
    END TRY
    BEGIN CATCH
        IF @TranCountEntrada = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
        BEGIN
            EXEC sys.sp_set_session_context @key = N'ORIGEM', @value = @OrigemAntes;
            DROP TABLE IF EXISTS #Desfazer_Plano;
            IF ERROR_NUMBER() <> 50003
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(CASE WHEN ERROR_NUMBER() = 50003 THEN ERROR_MESSAGE() ELSE N'Não foi possível desfazer. Nada foi alterado; o erro foi registrado para análise.' END AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_DESFAZER, 0 AS QTD_REGISTROS, 0 AS QTD_CAMPOS, 0 AS QTD_LIXEIRA;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma pessoa. Nada é apagado: a
                pessoa some das listas de escolha, mas continua nos lançamentos e no
                histórico. Permissão: DESATIVAR em CAD_PESSOA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): permissão DESATIVAR (o botão Excluir
                        passa a mandar para a lixeira) e recusa se o registro
                        estiver na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Excluir @IdUsuario = 2, @IdPessoa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Excluir]
    @IdUsuario  INT,
    @IdPessoa  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar pessoas.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'CAD.Pessoa', @IdPessoa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes (Sistema › Lixeira).';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM CAD.Pessoa t WHERE t.ID_PESSOA = @IdPessoa;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Pessoa t
        WHERE t.ID_PESSOA = @IdPessoa
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPessoa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma empresa. Nada é apagado.
                Não desativa empresa com conta ou centro de custo ativo (desative-os
                antes). Permissão: DESATIVAR em CAD_EMPRESA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): permissão DESATIVAR (o botão Excluir
                        passa a mandar para a lixeira) e recusa se o registro
                        estiver na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Excluir @IdUsuario = 2, @IdEmpresa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Excluir]
    @IdUsuario  INT,
    @IdEmpresa  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar empresas.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'CAD.Empresa', @IdEmpresa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes (Sistema › Lixeira).';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM CAD.Empresa t WHERE t.ID_EMPRESA = @IdEmpresa;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa = N'' AND @Reativar = 0
           AND (   EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_EMPRESA = @IdEmpresa AND c.ATIVO = 1)
                OR EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.ID_EMPRESA = @IdEmpresa AND cc.ATIVO = 1))
            SET @Recusa = N'A empresa ainda tem conta bancária ou centro de custo ativo. Desative-os antes.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Empresa t
        WHERE t.ID_EMPRESA = @IdEmpresa
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdEmpresa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) um centro de custo. Nada é
                apagado. Reativar exige a empresa ativa.
                Permissão: DESATIVAR em CAD_CENTRO_CUSTO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): permissão DESATIVAR (o botão Excluir
                        passa a mandar para a lixeira) e recusa se o registro
                        estiver na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Excluir @IdUsuario = 2, @IdCentroCusto = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Excluir]
    @IdUsuario  INT,
    @IdCentroCusto  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar centros de custo.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'CAD.Centro_Custo', @IdCentroCusto) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes (Sistema › Lixeira).';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM CAD.Centro_Custo t WHERE t.ID_CENTRO_CUSTO = @IdCentroCusto;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa = N'' AND @Reativar = 1
           AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo cc INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = cc.ID_EMPRESA
                           WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto AND e.ATIVO = 1)
            SET @Recusa = N'A empresa deste centro de custo está desativada. Reative a empresa antes.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Centro_Custo t
        WHERE t.ID_CENTRO_CUSTO = @IdCentroCusto
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdCentroCusto AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) um grupo (@Nivel 1), subgrupo (2)
                ou conta (3) do plano. Nada é apagado: desativar o grupo ou o subgrupo
                esconde tudo abaixo dele das listas de escolha (ATIVO_EFETIVO), sem
                mexer nos filhos. Permissão: DESATIVAR em CAD_PLANO_CONTA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): permissão DESATIVAR (o botão Excluir
                        passa a mandar para a lixeira) e recusa se o registro
                        estiver na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Plano_Excluir @IdUsuario = 2, @Nivel = 3, @Id = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Excluir]
    @IdUsuario  INT,
    @Nivel      TINYINT,
    @Id         INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar o plano de contas.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(CASE @Nivel WHEN 1 THEN N'CAD.Plano_Grupo' WHEN 2 THEN N'CAD.Plano_Subgrupo' ELSE N'CAD.Plano_Conta' END, @Id) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes (Sistema › Lixeira).';
        IF @Recusa = N'' AND ISNULL(@Nivel, 0) NOT IN (1, 2, 3)
            SET @Recusa = N'Nível inválido (1 grupo, 2 subgrupo, 3 conta).';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = CASE @Nivel WHEN 1 THEN (SELECT g.ATIVO FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @Id)
                                        WHEN 2 THEN (SELECT s.ATIVO FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @Id)
                                        ELSE (SELECT c.ATIVO FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @Id) END;
            IF @Ativo IS NULL SET @Recusa = N'Registro do plano de contas não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @Nivel = 1
            UPDATE g SET g.ATIVO = @Reativar, g.DT_ALTERACAO = SYSDATETIME(), g.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @Id AND g.ATIVO <> @Reativar;
        IF @Nivel = 2
            UPDATE s SET s.ATIVO = @Reativar, s.DT_ALTERACAO = SYSDATETIME(), s.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @Id AND s.ATIVO <> @Reativar;
        IF @Nivel = 3
            UPDATE c SET c.ATIVO = @Reativar, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @Id AND c.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @Id AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma conta. Nada é apagado.
                Não desativa a conta que é padrão de empresa ou centro de custo ativo
                (troque a conta padrão antes). Permissão: DESATIVAR em BANCO_CONTA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): permissão DESATIVAR (o botão Excluir
                        passa a mandar para a lixeira) e recusa se o registro
                        estiver na lixeira.

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Excluir @IdUsuario = 2, @IdConta = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Excluir]
    @IdUsuario  INT,
    @IdConta  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar contas bancárias.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'BANCO.Conta', @IdConta) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes (Sistema › Lixeira).';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM BANCO.Conta t WHERE t.ID_CONTA = @IdConta;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa = N'' AND @Reativar = 0
           AND (   EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_CONTA_BANCARIA_PADRAO = @IdConta AND e.ATIVO = 1)
                OR EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.ID_CONTA_BANCARIA_PADRAO = @IdConta AND cc.ATIVO = 1))
            SET @Recusa = N'Esta conta é a conta padrão de uma empresa ou centro de custo ativo. Troque a conta padrão antes de desativar.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM BANCO.Conta t
        WHERE t.ID_CONTA = @IdConta
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Pessoas" e busca de pessoa nos outros cadastros. @Busca procura
                por parte do nome ou do nome fantasia, pelo início do CPF/CNPJ (com ou
                sem pontuação) e pelo código da pessoa. @Papel: CLIENTE, FORNECEDOR,
                FUNCIONARIO ou CORRETOR (vazio = todos). CPF sai MASCARADO na lista
                (LGPD); completo só no CAD_Pessoa_Obter.
                Permissão: VER em CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Listar @IdUsuario = 2, @Busca = N'silva';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Listar]
    @IdUsuario     INT,
    @Busca         NVARCHAR(100) = NULL,
    @Papel         VARCHAR(12)   = NULL,
    @SomenteAtivos BIT           = 1,
    @Limite        INT           = 500
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Like       NVARCHAR(110);
    DECLARE @Doc        VARCHAR(30);
    DECLARE @BuscaId    INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as pessoas.', 1;

        SET @Busca  = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Papel  = UPPER(LTRIM(RTRIM(ISNULL(@Papel, ''))));
        SET @Limite = CASE WHEN ISNULL(@Limite, 0) BETWEEN 1 AND 5000 THEN @Limite ELSE 500 END;
        IF @Papel NOT IN ('', 'CLIENTE', 'FORNECEDOR', 'FUNCIONARIO', 'CORRETOR')
            THROW 50001, N'Papel inválido para o filtro.', 1;

        SET @Like    = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Doc     = CAD.fn_CAD_Documento_Limpo(@Busca);
        SET @BuscaId = TRY_CONVERT(INT, @Busca);

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@Limite)
               p.ID_PESSOA, p.TIPO_PESSOA, p.NOME, p.NOME_FANTASIA,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(p.CPF_CNPJ, CASE WHEN p.TIPO_PESSOA = 'F' THEN 1 ELSE 0 END) AS DOCUMENTO,
               p.CLIENTE, p.FORNECEDOR, p.FUNCIONARIO, p.CORRETOR, p.CIDADE, p.UF,
               ISNULL((SELECT TOP 1 pc.VALOR FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1 AND pc.TIPO = 'EMAIL'
                       ORDER BY pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO), N'') AS EMAIL_PRINCIPAL,
               ISNULL((SELECT TOP 1 pc.VALOR FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1 AND pc.TIPO <> 'EMAIL'
                       ORDER BY pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO), N'') AS TELEFONE_PRINCIPAL,
               p.ATIVO, p.DT_ALTERACAO, ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Pessoa p WITH (NOLOCK)
        WHERE (ISNULL(@SomenteAtivos, 1) = 0 OR p.ATIVO = 1)
          AND p.DT_EXCLUSAO IS NULL
          AND (   @Papel = ''
               OR (@Papel = 'CLIENTE' AND p.CLIENTE = 1) OR (@Papel = 'FORNECEDOR' AND p.FORNECEDOR = 1)
               OR (@Papel = 'FUNCIONARIO' AND p.FUNCIONARIO = 1) OR (@Papel = 'CORRETOR' AND p.CORRETOR = 1))
          AND (   @Busca = N''
               OR p.NOME LIKE @Like
               OR p.NOME_FANTASIA LIKE @Like
               OR (LEN(@Doc) >= 3 AND p.CPF_CNPJ LIKE @Doc + '%')
               OR p.ID_PESSOA = @BuscaId)
        ORDER BY p.NOME, p.ID_PESSOA;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as pessoas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Ficha completa de uma pessoa (uma linha), com CPF/CNPJ completo e
                formatado, e os ativos de contatos, vínculos e dados bancários em
                colunas JSON (CONTATOS, VINCULOS, DADOS_BANCARIOS), no mesmo formato
                que o CAD_Pessoa_Gravar recebe. DOCUMENTO_REPETIDO: quantas outras
                pessoas têm o mesmo documento (só aviso).
                Permissão: VER em CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): coluna NA_LIXEIRA (registro na lixeira: a ficha abre só para consulta).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Obter @IdUsuario = 2, @IdPessoa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Obter]
    @IdUsuario  INT,
    @IdPessoa   INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as pessoas.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WITH (NOLOCK) WHERE p.ID_PESSOA = @IdPessoa)
            THROW 50001, N'Pessoa não encontrada.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT p.ID_PESSOA, p.TIPO_PESSOA, p.NOME, p.NOME_FANTASIA, p.CPF_CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(p.CPF_CNPJ, 0) AS DOCUMENTO_FORMATADO,
               p.RG, p.ORGAO_EMISSOR, p.INSCRICAO_ESTADUAL, p.INSCRICAO_MUNICIPAL, p.DT_NASCIMENTO,
               p.NACIONALIDADE, p.PROFISSAO, p.ESTADO_CIVIL, p.REGIME_BENS,
               p.CEP, p.LOGRADOURO, p.NUMERO, p.COMPLEMENTO, p.BAIRRO, p.CIDADE, p.UF,
               p.CLIENTE, p.FORNECEDOR, p.FUNCIONARIO, p.CORRETOR, p.OBSERVACAO, p.ATIVO, p.CODIGO_ACCESS,
               p.DT_CRIACAO, p.USUARIO_CRIACAO, p.DT_ALTERACAO, ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO,
               CAST(CASE WHEN p.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT) AS NA_LIXEIRA,
               CASE WHEN p.CPF_CNPJ = '' THEN 0
                    ELSE (SELECT COUNT(*) FROM CAD.Pessoa o WITH (NOLOCK) WHERE o.CPF_CNPJ = p.CPF_CNPJ AND o.ID_PESSOA <> p.ID_PESSOA) END AS DOCUMENTO_REPETIDO,
               ISNULL((SELECT pc.ID_PESSOA_CONTATO AS id, pc.TIPO AS tipo, pc.VALOR AS valor, pc.NOME_CONTATO AS nome,
                              pc.PRINCIPAL AS principal, pc.RECEBE_COBRANCA AS recebeCobranca
                       FROM CAD.Pessoa_Contato pc WITH (NOLOCK)
                       WHERE pc.ID_PESSOA = p.ID_PESSOA AND pc.ATIVO = 1
                       ORDER BY pc.TIPO, pc.PRINCIPAL DESC, pc.ID_PESSOA_CONTATO
                       FOR JSON PATH), N'[]') AS CONTATOS,
               ISNULL((SELECT pv.ID_PESSOA_VINCULADA AS idPessoaVinculada, v.NOME AS nome, pv.TIPO AS tipo, pv.OBSERVACAO AS observacao
                       FROM CAD.Pessoa_Vinculo pv WITH (NOLOCK)
                       INNER JOIN CAD.Pessoa v WITH (NOLOCK) ON v.ID_PESSOA = pv.ID_PESSOA_VINCULADA
                       WHERE pv.ID_PESSOA = p.ID_PESSOA AND pv.ATIVO = 1
                       ORDER BY pv.TIPO, v.NOME
                       FOR JSON PATH), N'[]') AS VINCULOS,
               ISNULL((SELECT d.ID_PESSOA_DADO_BANCARIO AS id, d.TIPO AS tipo, d.ID_BANCO AS idBanco, ISNULL(b.CODIGO, '') AS bancoCodigo,
                              ISNULL(b.NOME, N'') AS bancoNome, d.AGENCIA AS agencia, d.AGENCIA_DV AS agenciaDv, d.CONTA AS conta,
                              d.CONTA_DV AS contaDv, d.TIPO_CONTA AS tipoConta, d.TITULAR_NOME AS titularNome,
                              d.TITULAR_DOCUMENTO AS titularDocumento, d.PIX_TIPO AS pixTipo, d.PIX_CHAVE AS pixChave, d.PRINCIPAL AS principal
                       FROM CAD.Pessoa_Dado_Bancario d WITH (NOLOCK)
                       LEFT JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = d.ID_BANCO
                       WHERE d.ID_PESSOA = p.ID_PESSOA AND d.ATIVO = 1
                       ORDER BY d.PRINCIPAL DESC, d.ID_PESSOA_DADO_BANCARIO
                       FOR JSON PATH), N'[]') AS DADOS_BANCARIOS
        FROM CAD.Pessoa p WITH (NOLOCK)
        WHERE p.ID_PESSOA = @IdPessoa;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a pessoa. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Empresas" (e escolha da empresa nos outros cadastros): todas as
                colunas, CNPJ formatado e a conta padrão.
                Permissão: VER em CAD_EMPRESA, CAD_CENTRO_CUSTO ou BANCO_CONTA.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - Colunas CNPJ_COMPRAS e CNPJ_COMPRAS_FORMATADO, etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as empresas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT e.ID_EMPRESA, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ, 0) AS CNPJ_FORMATADO,
               e.CNPJ_COMPRAS, SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ_COMPRAS, 0) AS CNPJ_COMPRAS_FORMATADO,
               e.TIPO, e.INSCRICAO_ESTADUAL, e.INSCRICAO_MUNICIPAL, e.REGIME_TRIBUTARIO,
               e.CEP, e.LOGRADOURO, e.NUMERO, e.COMPLEMENTO, e.BAIRRO, e.CIDADE, e.UF, e.EMAIL, e.TELEFONE,
               e.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               e.ATIVO, e.CODIGO_ACCESS, e.DT_ALTERACAO, ISNULL(e.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Empresa e WITH (NOLOCK)
        LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR e.ATIVO = 1)
          AND e.DT_EXCLUSAO IS NULL
        ORDER BY e.RAZAO_SOCIAL;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as empresas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Centros de custo" (e escolha do centro nos lançamentos).
                @IdEmpresa NULL = todas. CONTA_EFETIVA: a conta do centro ou, se vazia,
                a da empresa. Permissão: VER em CAD_CENTRO_CUSTO.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Listar]
    @IdUsuario     INT,
    @IdEmpresa     INT = NULL,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os centros de custo.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT cc.ID_CENTRO_CUSTO, cc.CODIGO, cc.DESCRICAO, cc.TIPO, cc.CONTABIL,
               cc.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               cc.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               ISNULL(cc.ID_CONTA_BANCARIA_PADRAO, e.ID_CONTA_BANCARIA_PADRAO) AS ID_CONTA_EFETIVA,
               ISNULL(c.DESCRICAO, ISNULL(ce.DESCRICAO, N'')) AS CONTA_EFETIVA_DESCRICAO,
               cc.ATIVO, cc.CODIGO_ACCESS, cc.DT_ALTERACAO, ISNULL(cc.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Centro_Custo cc WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
        LEFT  JOIN BANCO.Conta c  WITH (NOLOCK) ON c.ID_CONTA  = cc.ID_CONTA_BANCARIA_PADRAO
        LEFT  JOIN BANCO.Conta ce WITH (NOLOCK) ON ce.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE (@IdEmpresa IS NULL OR cc.ID_EMPRESA = @IdEmpresa)
          AND (ISNULL(@SomenteAtivos, 0) = 0 OR cc.ATIVO = 1)
          AND cc.DT_EXCLUSAO IS NULL
        ORDER BY cc.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os centros de custo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Conta_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Conta_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Plano de contas": a árvore inteira, uma linha por nível
                (NIVEL 1 grupo, 2 subgrupo, 3 conta), na ordem numérica (ORDEM_ARVORE),
                com ID_PAI para montar a árvore. TIPO e CUSTO_OBRA vêm do grupo;
                CONTABIL e CONTA_CONTABIL_REF só na conta. ATIVO_EFETIVO: o registro e
                todos os de cima ativos. @SomenteAtivos = 1: só ATIVO_EFETIVO.
                Permissão: VER em CAD_PLANO_CONTA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Plano_Conta_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Conta_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Conta_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver o plano de contas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT x.NIVEL, x.ID, x.ID_PAI, x.NUMERO, x.CODIGO, x.DESCRICAO, x.TIPO, x.CUSTO_OBRA, x.CONTABIL, x.CONTA_CONTABIL_REF,
               x.ORDEM, x.ATIVO, x.ATIVO_EFETIVO, x.ORDEM_ARVORE, x.DT_ALTERACAO, x.USUARIO_ALTERACAO
        FROM (
            SELECT CAST(1 AS TINYINT) AS NIVEL, g.ID_PLANO_GRUPO AS ID, CAST(NULL AS INT) AS ID_PAI, g.NUMERO,
                   CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2)) AS CODIGO,
                   g.DESCRICAO, g.TIPO, g.CUSTO_OBRA, CAST(0 AS BIT) AS CONTABIL, CONVERT(VARCHAR(30), '') AS CONTA_CONTABIL_REF,
                   g.ORDEM, g.ATIVO, g.ATIVO AS ATIVO_EFETIVO,
                   CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.00.000') AS ORDEM_ARVORE,
                   g.DT_ALTERACAO, ISNULL(g.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
            FROM CAD.Plano_Grupo g WITH (NOLOCK)
            WHERE g.DT_EXCLUSAO IS NULL
            UNION ALL
            SELECT CAST(2 AS TINYINT), s.ID_PLANO_SUBGRUPO, s.ID_PLANO_GRUPO, s.NUMERO,
                   CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + CONVERT(VARCHAR(3), s.NUMERO)),
                   s.DESCRICAO, g.TIPO, g.CUSTO_OBRA, CAST(0 AS BIT), CONVERT(VARCHAR(30), ''),
                   s.ORDEM, s.ATIVO, CAST(CASE WHEN s.ATIVO = 1 AND g.ATIVO = 1 THEN 1 ELSE 0 END AS BIT),
                   CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + RIGHT('00' + CONVERT(VARCHAR(3), s.NUMERO), 2) + '.000'),
                   s.DT_ALTERACAO, ISNULL(s.USUARIO_ALTERACAO, N'')
            FROM CAD.Plano_Subgrupo s WITH (NOLOCK)
            INNER JOIN CAD.Plano_Grupo g WITH (NOLOCK) ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO
            WHERE s.DT_EXCLUSAO IS NULL
            UNION ALL
            SELECT CAST(3 AS TINYINT), v.ID_PLANO_CONTA, v.ID_PLANO_SUBGRUPO, v.NUMERO_CONTA, v.CODIGO,
                   v.DESCRICAO, v.TIPO, v.CUSTO_OBRA, v.CONTABIL, v.CONTA_CONTABIL_REF,
                   CAST(0 AS SMALLINT), v.CONTA_ATIVA, v.ATIVO_EFETIVO, v.ORDEM_ARVORE,
                   c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'')
            FROM CAD.vw_CAD_Plano_Conta v WITH (NOLOCK)
            INNER JOIN CAD.Plano_Conta c WITH (NOLOCK) ON c.ID_PLANO_CONTA = v.ID_PLANO_CONTA
            WHERE c.DT_EXCLUSAO IS NULL
        ) x
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR x.ATIVO_EFETIVO = 1)
        ORDER BY x.ORDEM_ARVORE;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o plano de contas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contas da empresa (tela Contas bancárias e escolha da conta padrão da
                empresa e do centro de custo). @IdEmpresa NULL = todas.
                Permissão: VER em BANCO_CONTA, CAD_EMPRESA ou CAD_CENTRO_CUSTO.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Listar]
    @IdUsuario     INT,
    @IdEmpresa     INT = NULL,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as contas bancárias.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_CONTA, c.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               c.DESCRICAO, c.TIPO, c.ID_BANCO, ISNULL(b.CODIGO, '') AS BANCO_CODIGO, ISNULL(b.NOME, N'') AS BANCO_NOME,
               c.AGENCIA, c.AGENCIA_DV, c.NUMERO, c.NUMERO_DV, c.LIMITE_CREDITO, c.SALDO_INICIAL, c.DT_SALDO_INICIAL,
               c.CONCILIA, c.MOSTRA_SALDO, c.CONTA_CONTABIL_REF, c.ORDEM, c.ATIVO, c.CODIGO_ACCESS,
               c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM BANCO.Conta c WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
        LEFT  JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = c.ID_BANCO
        WHERE (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa)
          AND (ISNULL(@SomenteAtivos, 0) = 0 OR c.ATIVO = 1)
          AND c.DT_EXCLUSAO IS NULL
        ORDER BY e.RAZAO_SOCIAL, c.ORDEM, c.DESCRICAO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as contas bancárias. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPessoa NULL) ou altera uma pessoa, junto com os contatos,
                vínculos e dados bancários, tudo ou nada.
                Regras: nome e pelo menos um papel obrigatórios; CPF (F) ou CNPJ (J)
                conferido quando informado (aceita o CNPJ alfanumérico); documento PODE
                repetir: grava e avisa na MENSAGEM (decisão do Celso, 16/11/2026).
                Listas em JSON (mesmo formato do CAD_Pessoa_Obter); NULL = não mexe;
                informada = a lista gravada fica igual (o que saiu é DESATIVADO):
                  @Contatos       [{"id":null,"tipo":"EMAIL","valor":"a@b.com","nome":"","principal":true,"recebeCobranca":true}]
                                  tipos EMAIL, CELULAR, TELEFONE, WHATSAPP (telefone só dígitos, 10 a 13)
                  @Vinculos       [{"idPessoaVinculada":5,"tipo":"CONJUGE","observacao":""}]
                                  tipos CONJUGE, SOCIO, REPRESENTANTE, PROCURADOR
                  @DadosBancarios [{"id":null,"tipo":"TED","idBanco":3,"agencia":"0217","agenciaDv":"","conta":"123456",
                                    "contaDv":"7","tipoConta":"CORRENTE","titularNome":"","titularDocumento":"","principal":true},
                                   {"tipo":"PIX","pixTipo":"EMAIL","pixChave":"a@b.com"}]
                                  PIX: DOCUMENTO, EMAIL, CELULAR, ALEATORIA (chave conferida)
                Recusa com a linha do item errado (nada é gravado).
                Permissão: INCLUIR ou ALTERAR em CAD_PESSOA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira e escolher registro ligado que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = 2, @TipoPessoa = 'F', @Nome = N'Maria Teste', @CpfCnpj = '529.982.247-25', @Cliente = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Pessoa_Gravar]
    @IdUsuario           INT,
    @IdPessoa            INT            = NULL,
    @TipoPessoa          CHAR(1),
    @Nome                NVARCHAR(150),
    @NomeFantasia        NVARCHAR(100)  = NULL,
    @CpfCnpj             VARCHAR(30)    = NULL,
    @Rg                  VARCHAR(20)    = NULL,
    @OrgaoEmissor        VARCHAR(20)    = NULL,
    @InscricaoEstadual   VARCHAR(20)    = NULL,
    @InscricaoMunicipal  VARCHAR(20)    = NULL,
    @DtNascimento        DATE           = NULL,
    @Nacionalidade       NVARCHAR(40)   = NULL,
    @Profissao           NVARCHAR(60)   = NULL,
    @EstadoCivil         VARCHAR(15)    = NULL,
    @RegimeBens          VARCHAR(25)    = NULL,
    @Cep                 VARCHAR(10)    = NULL,
    @Logradouro          NVARCHAR(150)  = NULL,
    @Numero              NVARCHAR(20)   = NULL,
    @Complemento         NVARCHAR(60)   = NULL,
    @Bairro              NVARCHAR(60)   = NULL,
    @Cidade              NVARCHAR(60)   = NULL,
    @Uf                  CHAR(2)        = NULL,
    @Cliente             BIT            = 0,
    @Fornecedor          BIT            = 0,
    @Funcionario         BIT            = 0,
    @Corretor            BIT            = 0,
    @Observacao          NVARCHAR(2000) = NULL,
    @Contatos            NVARCHAR(MAX)  = NULL,
    @Vinculos            NVARCHAR(MAX)  = NULL,
    @DadosBancarios      NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Pessoa_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Repetidos  INT           = 0;
    DECLARE @Mensagem   NVARCHAR(400);
    DECLARE @Cont  TABLE (LINHA INT, ID INT, TIPO VARCHAR(20), VALOR NVARCHAR(256), NOME NVARCHAR(80), PRINCIPAL BIT, RECEBE BIT);
    DECLARE @Vinc  TABLE (LINHA INT, ID_VINCULADA INT, TIPO VARCHAR(20), OBSERVACAO NVARCHAR(200));
    DECLARE @Banc  TABLE (LINHA INT, ID INT, TIPO VARCHAR(10), ID_BANCO INT, AGENCIA VARCHAR(20), AGENCIA_DV VARCHAR(5), CONTA VARCHAR(30),
                          CONTA_DV VARCHAR(5), TIPO_CONTA VARCHAR(20), TITULAR_NOME NVARCHAR(150), TITULAR_DOC VARCHAR(30),
                          PIX_TIPO VARCHAR(20), PIX_CHAVE NVARCHAR(140), PRINCIPAL BIT);

    BEGIN TRY
        SET @TipoPessoa         = UPPER(LTRIM(RTRIM(ISNULL(@TipoPessoa, ''))));
        SET @Nome               = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @NomeFantasia       = LTRIM(RTRIM(ISNULL(@NomeFantasia, N'')));
        SET @CpfCnpj            = CAD.fn_CAD_Documento_Limpo(@CpfCnpj);
        SET @Rg                 = LTRIM(RTRIM(ISNULL(@Rg, '')));
        SET @OrgaoEmissor       = UPPER(LTRIM(RTRIM(ISNULL(@OrgaoEmissor, ''))));
        SET @InscricaoEstadual  = LTRIM(RTRIM(ISNULL(@InscricaoEstadual, '')));
        SET @InscricaoMunicipal = LTRIM(RTRIM(ISNULL(@InscricaoMunicipal, '')));
        SET @Nacionalidade      = LTRIM(RTRIM(ISNULL(@Nacionalidade, N'')));
        SET @Profissao          = LTRIM(RTRIM(ISNULL(@Profissao, N'')));
        SET @EstadoCivil        = UPPER(LTRIM(RTRIM(ISNULL(@EstadoCivil, ''))));
        SET @RegimeBens         = UPPER(LTRIM(RTRIM(ISNULL(@RegimeBens, ''))));
        SET @Cep                = CAD.fn_CAD_Somente_Digitos(@Cep);
        SET @Logradouro         = LTRIM(RTRIM(ISNULL(@Logradouro, N'')));
        SET @Numero             = LTRIM(RTRIM(ISNULL(@Numero, N'')));
        SET @Complemento        = LTRIM(RTRIM(ISNULL(@Complemento, N'')));
        SET @Bairro             = LTRIM(RTRIM(ISNULL(@Bairro, N'')));
        SET @Cidade             = LTRIM(RTRIM(ISNULL(@Cidade, N'')));
        SET @Uf                 = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));
        SET @Cliente            = ISNULL(@Cliente, 0);
        SET @Fornecedor         = ISNULL(@Fornecedor, 0);
        SET @Funcionario        = ISNULL(@Funcionario, 0);
        SET @Corretor           = ISNULL(@Corretor, 0);
        SET @Observacao         = LTRIM(RTRIM(ISNULL(@Observacao, N'')));

        -- Pessoa
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', CASE WHEN @IdPessoa IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar pessoas.';
        IF @Recusa = N'' AND @IdPessoa IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Pessoa', @IdPessoa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdPessoa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa)
            SET @Recusa = N'Pessoa não encontrada.';
        IF @Recusa = N'' AND @TipoPessoa NOT IN ('F', 'J')
            SET @Recusa = N'Escolha pessoa física (F) ou jurídica (J).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome.';
        IF @Recusa = N'' AND @CpfCnpj <> '' AND @TipoPessoa = 'F' AND (LEN(@CpfCnpj) <> 11 OR CAD.fn_CAD_Documento_Valido(@CpfCnpj) = 0)
            SET @Recusa = N'CPF inválido. Confira os números.';
        IF @Recusa = N'' AND @CpfCnpj <> '' AND @TipoPessoa = 'J' AND (LEN(@CpfCnpj) <> 14 OR CAD.fn_CAD_Documento_Valido(@CpfCnpj) = 0)
            SET @Recusa = N'CNPJ inválido. Confira os números (o CNPJ alfanumérico também é aceito).';
        IF @Recusa = N'' AND @Cliente = 0 AND @Fornecedor = 0 AND @Funcionario = 0 AND @Corretor = 0
            SET @Recusa = N'Marque pelo menos um papel: cliente, fornecedor, funcionário ou corretor.';
        IF @Recusa = N'' AND @EstadoCivil NOT IN ('', 'SOLTEIRO', 'CASADO', 'DIVORCIADO', 'VIUVO', 'SEPARADO', 'UNIAO_ESTAVEL')
            SET @Recusa = N'Estado civil inválido.';
        IF @Recusa = N'' AND @RegimeBens NOT IN ('', 'COMUNHAO_PARCIAL', 'COMUNHAO_UNIVERSAL', 'SEPARACAO_TOTAL', 'PARTICIPACAO_AQUESTOS')
            SET @Recusa = N'Regime de bens inválido.';
        IF @Recusa = N'' AND @Cep <> '' AND LEN(@Cep) <> 8
            SET @Recusa = N'CEP inválido: são 8 dígitos.';
        IF @Recusa = N'' AND @Uf <> '' AND (LEN(@Uf) <> 2 OR @Uf LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'UF inválida: use a sigla com 2 letras (ex.: PR).';
        IF @Recusa = N'' AND @DtNascimento IS NOT NULL AND (@DtNascimento < '1900-01-01' OR @DtNascimento > CONVERT(DATE, @Agora))
            SET @Recusa = N'Data de nascimento inválida.';
        IF @Recusa = N'' AND (   (@Contatos IS NOT NULL AND ISJSON(@Contatos) = 0)
                              OR (@Vinculos IS NOT NULL AND ISJSON(@Vinculos) = 0)
                              OR (@DadosBancarios IS NOT NULL AND ISJSON(@DadosBancarios) = 0))
            SET @Recusa = N'Lista de contatos, vínculos ou dados bancários em formato inválido.';

        -- Contatos
        IF @Recusa = N'' AND @Contatos IS NOT NULL
        BEGIN
            INSERT INTO @Cont (LINHA, ID, TIPO, VALOR, NOME, PRINCIPAL, RECEBE)
            SELECT CONVERT(INT, k.[key]) + 1, j.id, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), LTRIM(RTRIM(ISNULL(j.valor, N''))),
                   LTRIM(RTRIM(ISNULL(j.nome, N''))), ISNULL(j.principal, 0), ISNULL(j.recebeCobranca, 0)
            FROM OPENJSON(@Contatos) k
            CROSS APPLY OPENJSON(k.value) WITH (id INT '$.id', tipo VARCHAR(20) '$.tipo', valor NVARCHAR(256) '$.valor',
                                               nome NVARCHAR(80) '$.nome', principal BIT '$.principal', recebeCobranca BIT '$.recebeCobranca') j
            WHERE k.[type] = 5;

            UPDATE c SET c.VALOR = CASE WHEN c.TIPO = 'EMAIL' THEN LOWER(c.VALOR) ELSE CONVERT(NVARCHAR(256), CAD.fn_CAD_Somente_Digitos(c.VALOR)) END
            FROM @Cont c;

            SELECT TOP 1 @Recusa = N'Contato ' + CONVERT(NVARCHAR(5), c.LINHA) + N': ' +
                   CASE WHEN c.TIPO NOT IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP') THEN N'tipo inválido (e-mail, celular, telefone ou WhatsApp).'
                        WHEN c.TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(c.VALOR) = 0 THEN N'e-mail inválido.'
                        WHEN c.TIPO <> 'EMAIL' AND LEN(c.VALOR) NOT BETWEEN 10 AND 13 THEN N'telefone inválido (informe DDD + número).'
                        ELSE N'não pertence a esta pessoa.' END
            FROM @Cont c
            WHERE c.TIPO NOT IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP')
               OR (c.TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(c.VALOR) = 0)
               OR (c.TIPO <> 'EMAIL' AND LEN(c.VALOR) NOT BETWEEN 10 AND 13)
               OR (c.ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato pc WHERE pc.ID_PESSOA_CONTATO = c.ID AND pc.ID_PESSOA = ISNULL(@IdPessoa, 0)))
            ORDER BY c.LINHA;

            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM @Cont c WHERE c.PRINCIPAL = 1 GROUP BY c.TIPO HAVING COUNT(*) > 1)
                SET @Recusa = N'Marque só um contato principal de cada tipo.';
        END;

        -- Vínculos
        IF @Recusa = N'' AND @Vinculos IS NOT NULL
        BEGIN
            INSERT INTO @Vinc (LINHA, ID_VINCULADA, TIPO, OBSERVACAO)
            SELECT CONVERT(INT, k.[key]) + 1, j.idPessoaVinculada, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), LTRIM(RTRIM(ISNULL(j.observacao, N'')))
            FROM OPENJSON(@Vinculos) k
            CROSS APPLY OPENJSON(k.value) WITH (idPessoaVinculada INT '$.idPessoaVinculada', tipo VARCHAR(20) '$.tipo', observacao NVARCHAR(200) '$.observacao') j
            WHERE k.[type] = 5;

            SELECT TOP 1 @Recusa = N'Vínculo ' + CONVERT(NVARCHAR(5), v.LINHA) + N': ' +
                   CASE WHEN v.TIPO NOT IN ('CONJUGE', 'SOCIO', 'REPRESENTANTE', 'PROCURADOR') THEN N'tipo inválido (cônjuge, sócio, representante ou procurador).'
                        WHEN v.ID_VINCULADA = ISNULL(@IdPessoa, 0) THEN N'a pessoa não pode ser vinculada a ela mesma.'
                        ELSE N'pessoa vinculada não encontrada.' END
            FROM @Vinc v
            WHERE v.TIPO NOT IN ('CONJUGE', 'SOCIO', 'REPRESENTANTE', 'PROCURADOR')
               OR v.ID_VINCULADA = ISNULL(@IdPessoa, 0)
               OR NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = v.ID_VINCULADA AND p.DT_EXCLUSAO IS NULL)
            ORDER BY v.LINHA;

            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM @Vinc v GROUP BY v.ID_VINCULADA, v.TIPO HAVING COUNT(*) > 1)
                SET @Recusa = N'O mesmo vínculo foi informado duas vezes.';
        END;

        -- Dados bancários
        IF @Recusa = N'' AND @DadosBancarios IS NOT NULL
        BEGIN
            INSERT INTO @Banc (LINHA, ID, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, CONTA, CONTA_DV, TIPO_CONTA, TITULAR_NOME, TITULAR_DOC, PIX_TIPO, PIX_CHAVE, PRINCIPAL)
            SELECT CONVERT(INT, k.[key]) + 1, j.id, UPPER(LTRIM(RTRIM(ISNULL(j.tipo, '')))), j.idBanco,
                   CAD.fn_CAD_Somente_Digitos(j.agencia), UPPER(LTRIM(RTRIM(ISNULL(j.agenciaDv, '')))),
                   CAD.fn_CAD_Somente_Digitos(j.conta), UPPER(LTRIM(RTRIM(ISNULL(j.contaDv, '')))),
                   UPPER(LTRIM(RTRIM(ISNULL(j.tipoConta, '')))), LTRIM(RTRIM(ISNULL(j.titularNome, N''))),
                   CAD.fn_CAD_Documento_Limpo(j.titularDocumento), UPPER(LTRIM(RTRIM(ISNULL(j.pixTipo, '')))),
                   LTRIM(RTRIM(ISNULL(j.pixChave, N''))), ISNULL(j.principal, 0)
            FROM OPENJSON(@DadosBancarios) k
            CROSS APPLY OPENJSON(k.value) WITH (id INT '$.id', tipo VARCHAR(10) '$.tipo', idBanco INT '$.idBanco', agencia NVARCHAR(20) '$.agencia',
                                               agenciaDv VARCHAR(5) '$.agenciaDv', conta NVARCHAR(30) '$.conta', contaDv VARCHAR(5) '$.contaDv',
                                               tipoConta VARCHAR(20) '$.tipoConta', titularNome NVARCHAR(150) '$.titularNome',
                                               titularDocumento NVARCHAR(30) '$.titularDocumento', pixTipo VARCHAR(20) '$.pixTipo',
                                               pixChave NVARCHAR(140) '$.pixChave', principal BIT '$.principal') j
            WHERE k.[type] = 5;

            -- Cada tipo guarda só os seus campos; chave PIX normalizada
            UPDATE b
               SET b.ID_BANCO   = CASE WHEN b.TIPO = 'TED' THEN b.ID_BANCO END,
                   b.AGENCIA    = CASE WHEN b.TIPO = 'TED' THEN b.AGENCIA ELSE '' END,
                   b.AGENCIA_DV = CASE WHEN b.TIPO = 'TED' THEN b.AGENCIA_DV ELSE '' END,
                   b.CONTA      = CASE WHEN b.TIPO = 'TED' THEN b.CONTA ELSE '' END,
                   b.CONTA_DV   = CASE WHEN b.TIPO = 'TED' THEN b.CONTA_DV ELSE '' END,
                   b.TIPO_CONTA = CASE WHEN b.TIPO = 'TED' THEN b.TIPO_CONTA ELSE '' END,
                   b.PIX_TIPO   = CASE WHEN b.TIPO = 'PIX' THEN b.PIX_TIPO ELSE '' END,
                   b.PIX_CHAVE  = CASE WHEN b.TIPO <> 'PIX' THEN N''
                                       WHEN b.PIX_TIPO = 'DOCUMENTO' THEN CONVERT(NVARCHAR(140), CAD.fn_CAD_Documento_Limpo(b.PIX_CHAVE))
                                       WHEN b.PIX_TIPO = 'CELULAR'   THEN CONVERT(NVARCHAR(140), CAD.fn_CAD_Somente_Digitos(b.PIX_CHAVE))
                                       ELSE LOWER(b.PIX_CHAVE) END
            FROM @Banc b;

            SELECT TOP 1 @Recusa = N'Dado bancário ' + CONVERT(NVARCHAR(5), b.LINHA) + N': ' +
                   CASE WHEN b.TIPO NOT IN ('TED', 'PIX') THEN N'escolha TED ou PIX.'
                        WHEN b.TIPO = 'TED' AND NOT EXISTS (SELECT 1 FROM BANCO.Banco x WHERE x.ID_BANCO = b.ID_BANCO AND x.ATIVO = 1) THEN N'escolha o banco.'
                        WHEN b.TIPO = 'TED' AND (b.AGENCIA = '' OR b.CONTA = '' OR LEN(b.AGENCIA) > 10 OR LEN(b.CONTA) > 20) THEN N'informe a agência e a conta.'
                        WHEN b.TIPO = 'TED' AND b.TIPO_CONTA NOT IN ('', 'CORRENTE', 'POUPANCA', 'PAGAMENTO') THEN N'tipo de conta inválido.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO NOT IN ('DOCUMENTO', 'EMAIL', 'CELULAR', 'ALEATORIA') THEN N'escolha o tipo da chave PIX.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'DOCUMENTO' AND CAD.fn_CAD_Documento_Valido(b.PIX_CHAVE) = 0 THEN N'chave PIX (CPF/CNPJ) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(b.PIX_CHAVE) = 0 THEN N'chave PIX (e-mail) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'CELULAR' AND LEN(b.PIX_CHAVE) NOT BETWEEN 10 AND 13 THEN N'chave PIX (celular) inválida.'
                        WHEN b.TIPO = 'PIX' AND b.PIX_TIPO = 'ALEATORIA' AND (LEN(REPLACE(b.PIX_CHAVE, N'-', N'')) <> 32 OR REPLACE(b.PIX_CHAVE, N'-', N'') LIKE N'%[^0-9a-f]%') THEN N'chave PIX aleatória inválida.'
                        WHEN b.TITULAR_DOC <> '' AND CAD.fn_CAD_Documento_Valido(b.TITULAR_DOC) = 0 THEN N'documento do titular inválido.'
                        ELSE N'não pertence a esta pessoa.' END
            FROM @Banc b
            WHERE b.TIPO NOT IN ('TED', 'PIX')
               OR (b.TIPO = 'TED' AND (   NOT EXISTS (SELECT 1 FROM BANCO.Banco x WHERE x.ID_BANCO = b.ID_BANCO AND x.ATIVO = 1)
                                       OR b.AGENCIA = '' OR b.CONTA = '' OR LEN(b.AGENCIA) > 10 OR LEN(b.CONTA) > 20
                                       OR b.TIPO_CONTA NOT IN ('', 'CORRENTE', 'POUPANCA', 'PAGAMENTO')))
               OR (b.TIPO = 'PIX' AND (   b.PIX_TIPO NOT IN ('DOCUMENTO', 'EMAIL', 'CELULAR', 'ALEATORIA')
                                       OR (b.PIX_TIPO = 'DOCUMENTO' AND CAD.fn_CAD_Documento_Valido(b.PIX_CHAVE) = 0)
                                       OR (b.PIX_TIPO = 'EMAIL' AND SIS.fn_SIS_Email_Valido(b.PIX_CHAVE) = 0)
                                       OR (b.PIX_TIPO = 'CELULAR' AND LEN(b.PIX_CHAVE) NOT BETWEEN 10 AND 13)
                                       OR (b.PIX_TIPO = 'ALEATORIA' AND (LEN(REPLACE(b.PIX_CHAVE, N'-', N'')) <> 32 OR REPLACE(b.PIX_CHAVE, N'-', N'') LIKE N'%[^0-9a-f]%'))))
               OR (b.TITULAR_DOC <> '' AND CAD.fn_CAD_Documento_Valido(b.TITULAR_DOC) = 0)
               OR (b.ID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Dado_Bancario d WHERE d.ID_PESSOA_DADO_BANCARIO = b.ID AND d.ID_PESSOA = ISNULL(@IdPessoa, 0)))
            ORDER BY b.LINHA;

            IF @Recusa = N'' AND (SELECT COUNT(*) FROM @Banc b WHERE b.PRINCIPAL = 1) > 1
                SET @Recusa = N'Marque só um dado bancário como principal.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        IF @CpfCnpj <> ''
            SELECT @Repetidos = COUNT(*) FROM CAD.Pessoa p WHERE p.CPF_CNPJ = @CpfCnpj AND p.ID_PESSOA <> ISNULL(@IdPessoa, 0);

        SET @EtapaAtual = 'Gravação da pessoa';
        BEGIN TRANSACTION;

        IF @IdPessoa IS NULL
        BEGIN
            INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, NOME_FANTASIA, CPF_CNPJ, RG, ORGAO_EMISSOR, INSCRICAO_ESTADUAL, INSCRICAO_MUNICIPAL,
                                    DT_NASCIMENTO, NACIONALIDADE, PROFISSAO, ESTADO_CIVIL, REGIME_BENS, CEP, LOGRADOURO, NUMERO, COMPLEMENTO,
                                    BAIRRO, CIDADE, UF, CLIENTE, FORNECEDOR, FUNCIONARIO, CORRETOR, OBSERVACAO, USUARIO_CRIACAO)
            VALUES (@TipoPessoa, @Nome, @NomeFantasia, @CpfCnpj, @Rg, @OrgaoEmissor, @InscricaoEstadual, @InscricaoMunicipal,
                    @DtNascimento, @Nacionalidade, @Profissao, @EstadoCivil, @RegimeBens, @Cep, @Logradouro, @Numero, @Complemento,
                    @Bairro, @Cidade, @Uf, @Cliente, @Fornecedor, @Funcionario, @Corretor, @Observacao, @Usuario);
            SET @IdPessoa = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE p
               SET p.TIPO_PESSOA = @TipoPessoa, p.NOME = @Nome, p.NOME_FANTASIA = @NomeFantasia, p.CPF_CNPJ = @CpfCnpj, p.RG = @Rg,
                   p.ORGAO_EMISSOR = @OrgaoEmissor, p.INSCRICAO_ESTADUAL = @InscricaoEstadual, p.INSCRICAO_MUNICIPAL = @InscricaoMunicipal,
                   p.DT_NASCIMENTO = @DtNascimento, p.NACIONALIDADE = @Nacionalidade, p.PROFISSAO = @Profissao, p.ESTADO_CIVIL = @EstadoCivil,
                   p.REGIME_BENS = @RegimeBens, p.CEP = @Cep, p.LOGRADOURO = @Logradouro, p.NUMERO = @Numero, p.COMPLEMENTO = @Complemento,
                   p.BAIRRO = @Bairro, p.CIDADE = @Cidade, p.UF = @Uf, p.CLIENTE = @Cliente, p.FORNECEDOR = @Fornecedor,
                   p.FUNCIONARIO = @Funcionario, p.CORRETOR = @Corretor, p.OBSERVACAO = @Observacao,
                   p.DT_ALTERACAO = @Agora, p.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa p
            WHERE p.ID_PESSOA = @IdPessoa;

        -- Listas: NULL = não mexe; informada = fica igual à lista (o que saiu é desativado, não apagado)
        IF @Contatos IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos contatos';
            UPDATE pc
               SET pc.TIPO = c.TIPO, pc.VALOR = c.VALOR, pc.NOME_CONTATO = c.NOME, pc.PRINCIPAL = c.PRINCIPAL, pc.RECEBE_COBRANCA = c.RECEBE,
                   pc.ATIVO = 1, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            INNER JOIN @Cont c ON c.ID = pc.ID_PESSOA_CONTATO
            WHERE pc.ID_PESSOA = @IdPessoa;

            UPDATE pc
               SET pc.ATIVO = 0, pc.DT_ALTERACAO = @Agora, pc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Contato pc
            WHERE pc.ID_PESSOA = @IdPessoa AND pc.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Cont c WHERE c.ID = pc.ID_PESSOA_CONTATO);

            INSERT INTO CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR, NOME_CONTATO, PRINCIPAL, RECEBE_COBRANCA, USUARIO_CRIACAO)
            SELECT @IdPessoa, c.TIPO, c.VALOR, c.NOME, c.PRINCIPAL, c.RECEBE, @Usuario
            FROM @Cont c
            WHERE c.ID IS NULL
            ORDER BY c.LINHA;
        END;

        IF @Vinculos IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos vínculos';
            UPDATE pv
               SET pv.OBSERVACAO = v.OBSERVACAO, pv.ATIVO = 1, pv.DT_ALTERACAO = @Agora, pv.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Vinculo pv
            INNER JOIN @Vinc v ON v.ID_VINCULADA = pv.ID_PESSOA_VINCULADA AND v.TIPO = pv.TIPO
            WHERE pv.ID_PESSOA = @IdPessoa;

            UPDATE pv
               SET pv.ATIVO = 0, pv.DT_ALTERACAO = @Agora, pv.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Vinculo pv
            WHERE pv.ID_PESSOA = @IdPessoa AND pv.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Vinc v WHERE v.ID_VINCULADA = pv.ID_PESSOA_VINCULADA AND v.TIPO = pv.TIPO);

            INSERT INTO CAD.Pessoa_Vinculo (ID_PESSOA, ID_PESSOA_VINCULADA, TIPO, OBSERVACAO, USUARIO_CRIACAO)
            SELECT @IdPessoa, v.ID_VINCULADA, v.TIPO, v.OBSERVACAO, @Usuario
            FROM @Vinc v
            WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Vinculo pv WHERE pv.ID_PESSOA = @IdPessoa AND pv.ID_PESSOA_VINCULADA = v.ID_VINCULADA AND pv.TIPO = v.TIPO)
            ORDER BY v.LINHA;
        END;

        IF @DadosBancarios IS NOT NULL
        BEGIN
            SET @EtapaAtual = 'Gravação dos dados bancários';
            UPDATE d
               SET d.TIPO = b.TIPO, d.ID_BANCO = b.ID_BANCO, d.AGENCIA = b.AGENCIA, d.AGENCIA_DV = b.AGENCIA_DV, d.CONTA = b.CONTA,
                   d.CONTA_DV = b.CONTA_DV, d.TIPO_CONTA = b.TIPO_CONTA, d.TITULAR_NOME = b.TITULAR_NOME, d.TITULAR_DOCUMENTO = b.TITULAR_DOC,
                   d.PIX_TIPO = b.PIX_TIPO, d.PIX_CHAVE = b.PIX_CHAVE, d.PRINCIPAL = b.PRINCIPAL, d.ATIVO = 1,
                   d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Dado_Bancario d
            INNER JOIN @Banc b ON b.ID = d.ID_PESSOA_DADO_BANCARIO
            WHERE d.ID_PESSOA = @IdPessoa;

            UPDATE d
               SET d.ATIVO = 0, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Dado_Bancario d
            WHERE d.ID_PESSOA = @IdPessoa AND d.ATIVO = 1
              AND NOT EXISTS (SELECT 1 FROM @Banc b WHERE b.ID = d.ID_PESSOA_DADO_BANCARIO);

            INSERT INTO CAD.Pessoa_Dado_Bancario (ID_PESSOA, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, CONTA, CONTA_DV, TIPO_CONTA, TITULAR_NOME,
                                                  TITULAR_DOCUMENTO, PIX_TIPO, PIX_CHAVE, PRINCIPAL, USUARIO_CRIACAO)
            SELECT @IdPessoa, b.TIPO, b.ID_BANCO, b.AGENCIA, b.AGENCIA_DV, b.CONTA, b.CONTA_DV, b.TIPO_CONTA, b.TITULAR_NOME,
                   b.TITULAR_DOC, b.PIX_TIPO, b.PIX_CHAVE, b.PRINCIPAL, @Usuario
            FROM @Banc b
            WHERE b.ID IS NULL
            ORDER BY b.LINHA;
        END;

        COMMIT TRANSACTION;

        SET @Mensagem = N'Pessoa gravada (código ' + CONVERT(NVARCHAR(10), @IdPessoa) + N').'
                      + CASE WHEN @Repetidos > 0
                             THEN N' Atenção: já existe(m) ' + CONVERT(NVARCHAR(10), @Repetidos) + N' outra(s) pessoa(s) com este CPF/CNPJ.'
                             ELSE N'' END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(@Mensagem AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a pessoa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPessoa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdEmpresa NULL) ou altera uma empresa do grupo. Pela tela o
                CNPJ é obrigatório e conferido (dígitos verificadores, aceita o
                alfanumérico); não pode repetir. CEP com 8 dígitos, UF com 2 letras,
                e-mail válido. Conta padrão: qualquer conta ativa (escolha no cadastro,
                decisão do Celso).
                CNPJ para notas de compra e DDA (@CnpjCompras): opcional; NULL
                mantém o que está gravado (na inclusão, fica vazio); '' apaga.
                Permissão: INCLUIR ou ALTERAR em CAD_EMPRESA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - @CnpjCompras (CNPJ para notas de compra e DDA), etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Gravar @IdUsuario = 2, @RazaoSocial = N'Construtora Teste Ltda', @Cnpj = '11.222.333/0001-81', @Tipo = 'CONSTRUTORA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Gravar]
    @IdUsuario               INT,
    @IdEmpresa               INT           = NULL,
    @RazaoSocial             NVARCHAR(150),
    @NomeFantasia            NVARCHAR(100) = NULL,
    @Cnpj                    VARCHAR(20),
    @Tipo                    VARCHAR(12)   = 'OUTRA',
    @InscricaoEstadual       VARCHAR(20)   = NULL,
    @InscricaoMunicipal      VARCHAR(20)   = NULL,
    @RegimeTributario        VARCHAR(20)   = NULL,
    @Cep                     VARCHAR(10)   = NULL,
    @Logradouro              NVARCHAR(150) = NULL,
    @Numero                  NVARCHAR(20)  = NULL,
    @Complemento             NVARCHAR(60)  = NULL,
    @Bairro                  NVARCHAR(60)  = NULL,
    @Cidade                  NVARCHAR(60)  = NULL,
    @Uf                      CHAR(2)       = NULL,
    @Email                   NVARCHAR(256) = NULL,
    @Telefone                VARCHAR(30)   = NULL,
    @IdContaBancariaPadrao   INT           = NULL,
    @CnpjCompras             VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @RazaoSocial        = LTRIM(RTRIM(ISNULL(@RazaoSocial, N'')));
        SET @NomeFantasia       = LTRIM(RTRIM(ISNULL(@NomeFantasia, N'')));
        SET @Cnpj               = CAD.fn_CAD_Documento_Limpo(@Cnpj);
        SET @Tipo               = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, 'OUTRA'))));
        SET @InscricaoEstadual  = LTRIM(RTRIM(ISNULL(@InscricaoEstadual, '')));
        SET @InscricaoMunicipal = LTRIM(RTRIM(ISNULL(@InscricaoMunicipal, '')));
        SET @RegimeTributario   = UPPER(LTRIM(RTRIM(ISNULL(@RegimeTributario, ''))));
        SET @Cep                = CAD.fn_CAD_Somente_Digitos(@Cep);
        SET @Logradouro         = LTRIM(RTRIM(ISNULL(@Logradouro, N'')));
        SET @Numero             = LTRIM(RTRIM(ISNULL(@Numero, N'')));
        SET @Complemento        = LTRIM(RTRIM(ISNULL(@Complemento, N'')));
        SET @Bairro             = LTRIM(RTRIM(ISNULL(@Bairro, N'')));
        SET @Cidade             = LTRIM(RTRIM(ISNULL(@Cidade, N'')));
        SET @Uf                 = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));
        SET @Email              = LOWER(LTRIM(RTRIM(ISNULL(@Email, N''))));
        SET @Telefone           = CAD.fn_CAD_Somente_Digitos(@Telefone);
        IF @CnpjCompras IS NOT NULL SET @CnpjCompras = CAD.fn_CAD_Documento_Limpo(@CnpjCompras);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', CASE WHEN @IdEmpresa IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar empresas.';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Empresa', @IdEmpresa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa)
            SET @Recusa = N'Empresa não encontrada.';
        IF @Recusa = N'' AND @RazaoSocial = N''
            SET @Recusa = N'Informe a razão social.';
        IF @Recusa = N'' AND (LEN(@Cnpj) <> 14 OR CAD.fn_CAD_Documento_Valido(@Cnpj) = 0)
            SET @Recusa = N'CNPJ inválido. Confira os números (o CNPJ alfanumérico também é aceito).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.CNPJ = @Cnpj AND e.ID_EMPRESA <> ISNULL(@IdEmpresa, 0))
            SET @Recusa = N'Já existe uma empresa cadastrada com este CNPJ.';
        IF @Recusa = N'' AND ISNULL(@CnpjCompras, '') <> '' AND (LEN(@CnpjCompras) <> 14 OR CAD.fn_CAD_Documento_Valido(@CnpjCompras) = 0)
            SET @Recusa = N'CNPJ para notas de compra e DDA inválido. Confira os números.';
        IF @Recusa = N'' AND ISNULL(@CnpjCompras, '') <> '' AND @CnpjCompras = @Cnpj
            SET @Recusa = N'O CNPJ para notas de compra e DDA é igual ao CNPJ da empresa: deixe em branco.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')
            SET @Recusa = N'Tipo de empresa inválido.';
        IF @Recusa = N'' AND @RegimeTributario NOT IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')
            SET @Recusa = N'Regime tributário inválido.';
        IF @Recusa = N'' AND @Cep <> '' AND LEN(@Cep) <> 8
            SET @Recusa = N'CEP inválido: são 8 dígitos.';
        IF @Recusa = N'' AND @Uf <> '' AND (LEN(@Uf) <> 2 OR @Uf LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'UF inválida: use a sigla com 2 letras (ex.: PR).';
        IF @Recusa = N'' AND @Email <> N'' AND SIS.fn_SIS_Email_Valido(@Email) = 0
            SET @Recusa = N'E-mail inválido.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'A conta padrão escolhida não existe ou está desativada.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdEmpresa IS NULL
        BEGIN
            INSERT INTO CAD.Empresa (RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, TIPO, INSCRICAO_ESTADUAL, INSCRICAO_MUNICIPAL, REGIME_TRIBUTARIO,
                                     CEP, LOGRADOURO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF, EMAIL, TELEFONE, ID_CONTA_BANCARIA_PADRAO, USUARIO_CRIACAO)
            VALUES (@RazaoSocial, @NomeFantasia, @Cnpj, ISNULL(@CnpjCompras, ''), @Tipo, @InscricaoEstadual, @InscricaoMunicipal, @RegimeTributario,
                    @Cep, @Logradouro, @Numero, @Complemento, @Bairro, @Cidade, @Uf, @Email, @Telefone, @IdContaBancariaPadrao, @Usuario);
            SET @IdEmpresa = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE e
               SET e.RAZAO_SOCIAL = @RazaoSocial, e.NOME_FANTASIA = @NomeFantasia, e.CNPJ = @Cnpj, e.CNPJ_COMPRAS = ISNULL(@CnpjCompras, e.CNPJ_COMPRAS), e.TIPO = @Tipo,
                   e.INSCRICAO_ESTADUAL = @InscricaoEstadual, e.INSCRICAO_MUNICIPAL = @InscricaoMunicipal, e.REGIME_TRIBUTARIO = @RegimeTributario,
                   e.CEP = @Cep, e.LOGRADOURO = @Logradouro, e.NUMERO = @Numero, e.COMPLEMENTO = @Complemento, e.BAIRRO = @Bairro,
                   e.CIDADE = @Cidade, e.UF = @Uf, e.EMAIL = @Email, e.TELEFONE = @Telefone, e.ID_CONTA_BANCARIA_PADRAO = @IdContaBancariaPadrao,
                   e.DT_ALTERACAO = SYSDATETIME(), e.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Empresa e
            WHERE e.ID_EMPRESA = @IdEmpresa;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Empresa gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a empresa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdCentroCusto NULL) ou altera um centro de custo. Código
                curto, único, em maiúsculas (letras, números, "_" e "-"). Empresa e
                conta padrão têm de estar ativas (conta vazia = vale a da empresa).
                Permissão: INCLUIR ou ALTERAR em CAD_CENTRO_CUSTO. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = 2, @IdEmpresa = 1, @Codigo = 'ESC', @Descricao = N'Escritório', @Tipo = 'ADMINISTRATIVO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Gravar]
    @IdUsuario              INT,
    @IdCentroCusto          INT           = NULL,
    @IdEmpresa              INT,
    @Codigo                 VARCHAR(20),
    @Descricao              NVARCHAR(100),
    @Tipo                   VARCHAR(15),
    @Contabil               BIT           = 1,
    @IdContaBancariaPadrao  INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo      = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Contabil  = ISNULL(@Contabil, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', CASE WHEN @IdCentroCusto IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar centros de custo.';
        IF @Recusa = N'' AND @IdCentroCusto IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Centro_Custo', @IdCentroCusto) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdCentroCusto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto)
            SET @Recusa = N'Centro de custo não encontrado.';
        IF @Recusa = N'' AND (@Codigo = '' OR REPLACE(REPLACE(@Codigo, '_', ''), '-', '') LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras sem acento, números, "_" ou "-" (ex.: 62 ou ESC).';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição do centro de custo.';
        IF @Recusa = N'' AND @Tipo NOT IN ('OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR')
            SET @Recusa = N'Tipo inválido: obra, administrativo, imóvel próprio ou particular.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa AND e.ATIVO = 1)
            SET @Recusa = N'Escolha uma empresa ativa.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'A conta padrão escolhida não existe ou está desativada.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WHERE cc.CODIGO = @Codigo AND cc.ID_CENTRO_CUSTO <> ISNULL(@IdCentroCusto, 0))
            SET @Recusa = N'Já existe um centro de custo com este código.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdCentroCusto IS NULL
        BEGIN
            INSERT INTO CAD.Centro_Custo (ID_EMPRESA, CODIGO, DESCRICAO, TIPO, CONTABIL, ID_CONTA_BANCARIA_PADRAO, USUARIO_CRIACAO)
            VALUES (@IdEmpresa, @Codigo, @Descricao, @Tipo, @Contabil, @IdContaBancariaPadrao, @Usuario);
            SET @IdCentroCusto = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE cc
               SET cc.ID_EMPRESA = @IdEmpresa, cc.CODIGO = @Codigo, cc.DESCRICAO = @Descricao, cc.TIPO = @Tipo, cc.CONTABIL = @Contabil,
                   cc.ID_CONTA_BANCARIA_PADRAO = @IdContaBancariaPadrao, cc.DT_ALTERACAO = SYSDATETIME(), cc.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Centro_Custo cc
            WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Centro de custo gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o centro de custo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Grupo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Grupo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoGrupo NULL) ou altera um grupo (nível 1) do plano de
                contas. @Numero NULL = próximo número livre. Número (0 a 99) e
                descrição não repetem. TIPO: RECEITA, DESPESA, NAO_OPERACIONAL.
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Grupo_Gravar]
    @IdUsuario     INT,
    @IdPlanoGrupo  INT          = NULL,
    @Numero        SMALLINT     = NULL,
    @Descricao     NVARCHAR(80),
    @Tipo          VARCHAR(15),
    @CustoObra     BIT          = 0,
    @Ordem         SMALLINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Grupo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo      = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @CustoObra = ISNULL(@CustoObra, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoGrupo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoGrupo IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Plano_Grupo', @IdPlanoGrupo) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdPlanoGrupo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Grupo x WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND @Tipo NOT IN ('RECEITA', 'DESPESA', 'NAO_OPERACIONAL')
            SET @Recusa = N'Tipo do grupo inválido: receita, despesa ou não operacional.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Grupo g WHERE g.DESCRICAO = @Descricao AND g.ID_PLANO_GRUPO <> ISNULL(@IdPlanoGrupo, 0))
            SET @Recusa = N'Já existe um grupo com esta descrição.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Grupo x WITH (UPDLOCK, HOLDLOCK);

        IF @Numero NOT BETWEEN 0 AND 99
            SET @Recusa = N'Número do grupo fora da faixa (0 a 99).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Grupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.NUMERO = @Numero AND x.ID_PLANO_GRUPO <> ISNULL(@IdPlanoGrupo, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
            RETURN;
        END;

        IF @IdPlanoGrupo IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Grupo (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ORDEM, USUARIO_CRIACAO)
            VALUES (@Numero, @Descricao, @Tipo, @CustoObra, ISNULL(@Ordem, @Numero), @Usuario);
            SET @IdPlanoGrupo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE g
               SET g.NUMERO = @Numero, g.DESCRICAO = @Descricao, g.TIPO = @Tipo, g.CUSTO_OBRA = @CustoObra, g.ORDEM = ISNULL(@Ordem, g.ORDEM),
                   g.DT_ALTERACAO = SYSDATETIME(), g.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Grupo g
            WHERE g.ID_PLANO_GRUPO = @IdPlanoGrupo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Subgrupo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Subgrupo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoSubgrupo NULL) ou altera um subgrupo (nível 2),
                sempre dentro de um grupo. @Numero NULL = próximo livre no grupo.
                Número (1 a 99) e descrição não repetem dentro do grupo. Mudar de grupo
                é permitido (fica na auditoria).
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira e escolher registro ligado que está na lixeira.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Subgrupo_Gravar]
    @IdUsuario     INT,
    @IdPlanoSubgrupo  INT          = NULL,
    @IdPlanoGrupo     INT,
    @Numero           SMALLINT     = NULL,
    @Descricao        NVARCHAR(80),
    @Ordem            SMALLINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Subgrupo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));


        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoSubgrupo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoSubgrupo IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Plano_Subgrupo', @IdPlanoSubgrupo) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdPlanoSubgrupo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo x WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @IdPlanoGrupo AND g.DT_EXCLUSAO IS NULL)
            SET @Recusa = N'Escolha o grupo do subgrupo.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_GRUPO = @IdPlanoGrupo AND s.DESCRICAO = @Descricao
                                     AND s.ID_PLANO_SUBGRUPO <> ISNULL(@IdPlanoSubgrupo, 0))
            SET @Recusa = N'Já existe um subgrupo com esta descrição neste grupo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Subgrupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo;

        IF @Numero NOT BETWEEN 1 AND 99
            SET @Recusa = N'Número do subgrupo fora da faixa (1 a 99).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo AND x.NUMERO = @Numero AND x.ID_PLANO_SUBGRUPO <> ISNULL(@IdPlanoSubgrupo, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
            RETURN;
        END;

        IF @IdPlanoSubgrupo IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Subgrupo (ID_PLANO_GRUPO, NUMERO, DESCRICAO, ORDEM, USUARIO_CRIACAO)
            VALUES (@IdPlanoGrupo, @Numero, @Descricao, ISNULL(@Ordem, @Numero), @Usuario);
            SET @IdPlanoSubgrupo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE s
               SET s.ID_PLANO_GRUPO = @IdPlanoGrupo, s.NUMERO = @Numero, s.DESCRICAO = @Descricao, s.ORDEM = ISNULL(@Ordem, s.ORDEM),
                   s.DT_ALTERACAO = SYSDATETIME(), s.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Subgrupo s
            WHERE s.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Conta_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Conta_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoConta NULL) ou altera uma conta (nível 3, a que recebe
                lançamento), sempre dentro de um subgrupo. @Numero NULL = próximo livre
                no subgrupo. Número (1 a 999) e descrição não repetem dentro do
                subgrupo. CONTABIL e CONTA_CONTABIL_REF: pedido 10 / contabilidade.
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira e escolher registro ligado que está na lixeira.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Conta_Gravar]
    @IdUsuario     INT,
    @IdPlanoConta      INT          = NULL,
    @IdPlanoSubgrupo   INT,
    @Numero            SMALLINT     = NULL,
    @Descricao         NVARCHAR(80),
    @Contabil          BIT          = 0,
    @ContaContabilRef  VARCHAR(30)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Conta_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Contabil         = ISNULL(@Contabil, 0);
        SET @ContaContabilRef = LTRIM(RTRIM(ISNULL(@ContaContabilRef, '')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoConta IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoConta IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Plano_Conta', @IdPlanoConta) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdPlanoConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Conta x WHERE x.ID_PLANO_CONTA = @IdPlanoConta)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo AND s.DT_EXCLUSAO IS NULL)
            SET @Recusa = N'Escolha o subgrupo da conta.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Conta c WHERE c.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo AND c.DESCRICAO = @Descricao
                                     AND c.ID_PLANO_CONTA <> ISNULL(@IdPlanoConta, 0))
            SET @Recusa = N'Já existe uma conta com esta descrição neste subgrupo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Conta x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo;

        IF @Numero NOT BETWEEN 1 AND 999
            SET @Recusa = N'Número do conta fora da faixa (1 a 999).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Conta x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo AND x.NUMERO = @Numero AND x.ID_PLANO_CONTA <> ISNULL(@IdPlanoConta, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
            RETURN;
        END;

        IF @IdPlanoConta IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Conta (ID_PLANO_SUBGRUPO, NUMERO, DESCRICAO, CONTABIL, CONTA_CONTABIL_REF, USUARIO_CRIACAO)
            VALUES (@IdPlanoSubgrupo, @Numero, @Descricao, @Contabil, @ContaContabilRef, @Usuario);
            SET @IdPlanoConta = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE c
               SET c.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo, c.NUMERO = @Numero, c.DESCRICAO = @Descricao, c.CONTABIL = @Contabil,
                   c.CONTA_CONTABIL_REF = @ContaContabilRef, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Conta c
            WHERE c.ID_PLANO_CONTA = @IdPlanoConta;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdConta NULL) ou altera uma conta da empresa. Conta de banco
                (corrente, poupança, aplicação) exige banco, agência e número; caixa e
                permuta não usam banco. Descrição única dentro da empresa. Saldo
                inicial diferente de zero exige a data.
                Permissão: INCLUIR ou ALTERAR em BANCO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = 2, @IdEmpresa = 1, @Descricao = N'Caixa Construtora', @Tipo = 'CAIXA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Gravar]
    @IdUsuario         INT,
    @IdConta           INT           = NULL,
    @IdEmpresa         INT,
    @Descricao         NVARCHAR(60),
    @Tipo              VARCHAR(10),
    @IdBanco           INT           = NULL,
    @Agencia           VARCHAR(10)   = NULL,
    @AgenciaDv         VARCHAR(2)    = NULL,
    @Numero            VARCHAR(20)   = NULL,
    @NumeroDv          VARCHAR(2)    = NULL,
    @LimiteCredito     DECIMAL(18,2) = 0,
    @SaldoInicial      DECIMAL(18,2) = 0,
    @DtSaldoInicial    DATE          = NULL,
    @Concilia          BIT           = 0,
    @MostraSaldo       BIT           = 1,
    @ContaContabilRef  VARCHAR(30)   = NULL,
    @Ordem             SMALLINT      = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao        = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo             = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Agencia          = CAD.fn_CAD_Somente_Digitos(@Agencia);
        SET @AgenciaDv        = UPPER(LTRIM(RTRIM(ISNULL(@AgenciaDv, ''))));
        SET @Numero           = CAD.fn_CAD_Somente_Digitos(@Numero);
        SET @NumeroDv         = UPPER(LTRIM(RTRIM(ISNULL(@NumeroDv, ''))));
        SET @LimiteCredito    = ISNULL(@LimiteCredito, 0);
        SET @SaldoInicial     = ISNULL(@SaldoInicial, 0);
        SET @Concilia         = ISNULL(@Concilia, 0);
        SET @MostraSaldo      = ISNULL(@MostraSaldo, 1);
        SET @ContaContabilRef = LTRIM(RTRIM(ISNULL(@ContaContabilRef, '')));
        SET @Ordem            = ISNULL(@Ordem, 0);
        IF @Tipo IN ('CAIXA', 'PERMUTA')
            SELECT @IdBanco = NULL, @Agencia = '', @AgenciaDv = '', @Numero = '', @NumeroDv = '';

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', CASE WHEN @IdConta IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar contas bancárias.';
        IF @Recusa = N'' AND @IdConta IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'BANCO.Conta', @IdConta) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta)
            SET @Recusa = N'Conta não encontrada.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa AND e.ATIVO = 1)
            SET @Recusa = N'Escolha uma empresa ativa como titular da conta.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição da conta (ex.: Sicredi Orion).';
        IF @Recusa = N'' AND @Tipo NOT IN ('CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA')
            SET @Recusa = N'Tipo de conta inválido.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CAIXA', 'PERMUTA')
           AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.ID_BANCO = @IdBanco AND b.ATIVO = 1)
            SET @Recusa = N'Escolha o banco da conta.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CAIXA', 'PERMUTA') AND (@Agencia = '' OR @Numero = '')
            SET @Recusa = N'Informe a agência e o número da conta.';
        IF @Recusa = N'' AND @SaldoInicial <> 0 AND @DtSaldoInicial IS NULL
            SET @Recusa = N'Informe a data do saldo inicial.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_EMPRESA = @IdEmpresa AND c.DESCRICAO = @Descricao AND c.ID_CONTA <> ISNULL(@IdConta, 0))
            SET @Recusa = N'Esta empresa já tem uma conta com esta descrição.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdConta IS NULL
        BEGIN
            INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, ID_BANCO, AGENCIA, AGENCIA_DV, NUMERO, NUMERO_DV, LIMITE_CREDITO,
                                     SALDO_INICIAL, DT_SALDO_INICIAL, CONCILIA, MOSTRA_SALDO, CONTA_CONTABIL_REF, ORDEM, USUARIO_CRIACAO)
            VALUES (@IdEmpresa, @Descricao, @Tipo, @IdBanco, @Agencia, @AgenciaDv, @Numero, @NumeroDv, @LimiteCredito,
                    @SaldoInicial, @DtSaldoInicial, @Concilia, @MostraSaldo, @ContaContabilRef, @Ordem, @Usuario);
            SET @IdConta = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE c
               SET c.ID_EMPRESA = @IdEmpresa, c.DESCRICAO = @Descricao, c.TIPO = @Tipo, c.ID_BANCO = @IdBanco,
                   c.AGENCIA = @Agencia, c.AGENCIA_DV = @AgenciaDv, c.NUMERO = @Numero, c.NUMERO_DV = @NumeroDv,
                   c.LIMITE_CREDITO = @LimiteCredito, c.SALDO_INICIAL = @SaldoInicial, c.DT_SALDO_INICIAL = @DtSaldoInicial,
                   c.CONCILIA = @Concilia, c.MOSTRA_SALDO = @MostraSaldo, c.CONTA_CONTABIL_REF = @ContaContabilRef, c.ORDEM = @Ordem,
                   c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM BANCO.Conta c
            WHERE c.ID_CONTA = @IdConta;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Conta gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a conta. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdConta AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.rl_sistemacmj_api.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : papel [rl_sistemacmj_api]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Papel do banco usado pelo login da API e do serviço do
                sistema (CLAUDE.md seção 2): só EXECUTA procedures e
                functions dos schemas do sistema; não lê nem grava tabela
                direto (as procedures fazem isso por encadeamento de dono).
                Proteções a mais:
                  - DENY de INSERT/UPDATE/DELETE em SIS.Auditoria (além da
                    trigger de proteção);
                  - DENY de EXECUTE no gerador de triggers (só instalação);
                  - DENY de EXECUTE no registro de atualização (só o atualizar.cmd);
                  - DENY de EXECUTE nas procedures internas da lixeira e do
                    desfazer (só chamadas por dentro, pelas procedures das
                    telas, com EXECUTE AS OWNER).
                O login e o usuário do banco (ex.: sistemacmj_api) são
                criados na instalação do servidor (instalador / MASTER), que
                também coloca o usuário neste papel: a senha nunca fica em
                arquivo do projeto.
                Idempotente: pode rodar de novo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (22/11/2026) - DENY em SIS_Atualizacao_Registrar (etapa 03h).
    v1.2 (22/11/2026) - Etapa 04b (P20): DENY nas procedures internas da
                        lixeira e do desfazer.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NULL
    CREATE ROLE [rl_sistemacmj_api] AUTHORIZATION [dbo];
GO

DECLARE @Sql NVARCHAR(MAX) = N'';

SELECT @Sql = @Sql + N'GRANT EXECUTE ON SCHEMA::' + QUOTENAME(s.name) + N' TO [rl_sistemacmj_api];' + NCHAR(13) + NCHAR(10)
FROM sys.schemas s
WHERE s.name IN (N'SIS', N'CAD', N'BANCO', N'IMOB', N'VENDA', N'FIN', N'COBR', N'OBRA', N'GER', N'COMP');

EXEC sys.sp_executesql @Sql;
GO

DENY INSERT, UPDATE, DELETE ON [SIS].[Auditoria] TO [rl_sistemacmj_api];
DENY EXECUTE ON [SIS].[SIS_Auditoria_Trigger_Gerar] TO [rl_sistemacmj_api];
IF OBJECT_ID(N'[SIS].[SIS_Atualizacao_Registrar]', N'P') IS NOT NULL
    DENY EXECUTE ON [SIS].[SIS_Atualizacao_Registrar] TO [rl_sistemacmj_api];
GO

DECLARE @Internas NVARCHAR(MAX) = N'';
SELECT @Internas = @Internas + N'DENY EXECUTE ON ' + QUOTENAME(OBJECT_SCHEMA_NAME(o.object_id)) + N'.' + QUOTENAME(o.name) + N' TO [rl_sistemacmj_api];' + NCHAR(13) + NCHAR(10)
FROM sys.objects o
WHERE o.type = 'P'
  AND o.object_id IN (OBJECT_ID(N'[SIS].[SIS_Lixeira_Marcar]'), OBJECT_ID(N'[SIS].[SIS_Lixeira_Apagar]'), OBJECT_ID(N'[SIS].[SIS_Lixeira_Referencias]'),
                      OBJECT_ID(N'[SIS].[SIS_Tabela_Trava_Conferir]'), OBJECT_ID(N'[SIS].[SIS_Historico_Desfazer_Montar]'));
EXEC sys.sp_executesql @Internas;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros de fábrica da base SIS. Só insere o que falta
                (PADRAO_SQL regra 39): valor já alterado pelo administrador
                nunca é sobrescrito. VALOR_PADRAO recebe o mesmo valor de
                fábrica. Cada etapa seguinte acrescenta os seus parâmetros
                (multa, juros, régua de cobrança...) neste arquivo.
                EDITAVEL_ADMIN = 0: só o instalador muda, por script.
                Depende de Carga_SIS_Modulo.sql.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: SENHA_PBKDF2_ITERACOES.
    v1.2 (15/11/2026) - Identidade visual por cliente: pasta, logomarcas e
                        cores (valores de fábrica = CMJ).
    v1.3 (16/11/2026) - Etapa 02d: e-mail (domínio interno, minutos preso),
                        pastas de backup e de atualizações.
    v1.4 (17/11/2026) - Etapa 03c: EMAIL_LOCAL_LIBERADOS (exceção controlada do
                        banco de teste, pedido do Celso) e SISTEMA_NOME
                        (nome do sistema por cliente, pedido do Celso: SisCMJ);
                        EMAIL_LOGO_MODO, EMAIL_LOGO_ENDERECO e
                        EMAIL_LOGO_NOME_ARQUIVO (como a logomarca vai no e-mail).
    v1.5 (20/11/2026) - Etapa 03d: EMAIL_RODAPE_CNPJ (CNPJ no rodapé dos e-mails
                        a clientes e terceiros; fábrica N, pedido do Celso).
    v1.6 (20/11/2026) - Etapa 03d: LOGIN_COMPUTADOR_TENTATIVAS e
                        LOGIN_COMPUTADOR_MINUTOS (limite de tentativas por computador).
    v1.7 (20/11/2026) - Etapa 03d: BACKUP_DIAS_MANTER, BACKUP_NUVEM_MANTER e os
                        avisos de atraso (BACKUP_HORAS_ALERTA_COMPLETO/_LOG,
                        BACKUP_DIAS_ALERTA_TESTE).
    v1.8 (20/11/2026) - Etapa 03d2: BACKUP_RESTAURACAO_MOTIVO_MINIMO (restauração
                        pela tela).
    v1.9 (22/11/2026) - Etapa 04a: SENHA_PROVISORIA_PADRAO e SENHA_PROVISORIA_HORAS
                        (botão Reiniciar senha da tela de Usuários; decisão do
                        Celso de 16/11/2026, PADRAO_TELAS regra 13).
    v2.0 (22/11/2026) - Etapa 04b (P20): LIXEIRA_ATIVA, LIXEIRA_DIAS_GUARDA (90),
                        LIXEIRA_AVISO_DIAS, LIXEIRA_AVISO_GRUPO e
                        LIXEIRA_LIMPEZA_ATIVA.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN)
SELECT v.CHAVE, v.VALOR, v.VALOR, v.TIPO, v.DESCRICAO, m.ID_MODULO, v.EDITAVEL_ADMIN
FROM (VALUES
        (CAST('EMAIL_TESTE' AS VARCHAR(60)), CAST(N'celsofreitas62@gmail.com' AS NVARCHAR(4000)), CAST('EMAIL' AS VARCHAR(10)),
         CAST(N'Endereço que recebe TODOS os e-mails quando o sistema roda em modo teste (banco _LOCAL).' AS NVARCHAR(400)), CAST('SIS' AS VARCHAR(10)), CAST(0 AS BIT)),
        ('EMAIL_ADMIN_ALERTA', N'', 'EMAIL',
         N'Endereço que recebe os alertas técnicos (falha no envio de e-mail, rotina com erro). Vazio = sem alerta.', 'SIS', 1),
        ('EMAIL_TENTATIVAS_MAX', N'5', 'INTEIRO',
         N'Quantas vezes o serviço tenta reenviar um e-mail com falha temporária antes de desistir.', 'SIS', 1),
        ('SENHA_TAMANHO_MINIMO', N'8', 'INTEIRO',
         N'Quantidade mínima de caracteres da senha dos usuários.', 'SIS', 1),
        ('SENHA_TENTATIVAS_BLOQUEIO', N'5', 'INTEIRO',
         N'Tentativas de senha errada seguidas até o usuário ser bloqueado.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_TENTATIVAS', N'10', 'INTEIRO',
         N'Tentativas de login erradas seguidas, de um mesmo computador (com qualquer usuário), até ele ficar em espera. Mínimo 5.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_MINUTOS', N'15', 'INTEIRO',
         N'Minutos que o computador fica em espera depois de errar o login demais, e janela de contagem das tentativas.', 'SIS', 1),
        ('SESSAO_MINUTOS_INATIVIDADE', N'30', 'INTEIRO',
         N'Minutos sem uso até a sessão expirar e pedir login de novo.', 'SIS', 1),
        ('ANEXO_PASTA_RAIZ', N'C:\SistemaCMJ_Arquivos\Anexos', 'TEXTO',
         N'Pasta do servidor onde os anexos são gravados (o banco guarda só a referência).', 'SIS', 0),
        ('ANEXO_TAMANHO_MAX_MB', N'20', 'INTEIRO',
         N'Tamanho máximo de cada anexo, em MB.', 'SIS', 1),
        ('LOG_PASSO_DIAS_RETENCAO', N'90', 'INTEIRO',
         N'Dias que o log passo a passo das rotinas é guardado (mínimo 7). O log de erros não é apagado.', 'SIS', 1),
        ('SENHA_PBKDF2_ITERACOES', N'600000', 'INTEIRO',
         N'Iterações do PBKDF2-SHA256 usadas pela API ao gravar senha (mínimo aceito: 100000).', 'SIS', 0),
        ('IDENTIDADE_PASTA', N'C:\SistemaCMJ_Arquivos\Identidade', 'TEXTO',
         N'Pasta do servidor com os arquivos de identidade visual do cliente (logomarcas).', 'SIS', 0),
        ('EMPRESA_LOGO', N'logo.png', 'ARQUIVO',
         N'Logomarca vertical completa (documentos, contratos, telas grandes). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_HORIZONTAL', N'logo_horizontal.png', 'ARQUIVO',
         N'Logomarca horizontal (cabeçalho do sistema e dos relatórios). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_EMAIL', N'logo_email.png', 'ARQUIVO',
         N'Logomarca pequena do cabeçalho dos e-mails. Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_SIMBOLO', N'logo_simbolo.png', 'ARQUIVO',
         N'Só o símbolo da logomarca (menu recolhido, ícone). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_COR_PRINCIPAL', N'#D43414', 'COR',
         N'Cor principal do cliente: cabeçalhos do sistema, dos relatórios e dos e-mails informativos.', 'SIS', 1),
        ('EMPRESA_COR_SECUNDARIA', N'#A8A8A8', 'COR',
         N'Cor secundária do cliente (detalhes, linhas, textos de apoio).', 'SIS', 1),
        ('EMAIL_COR_ALERTA', N'#E65100', 'COR',
         N'Cor dos avisos de alerta (vencido, falha, divergência). Diferente da cor principal.', 'SIS', 1),
        ('EMAIL_COR_SUCESSO', N'#2E7D32', 'COR',
         N'Cor das confirmações (pagamento recebido, envio concluído).', 'SIS', 1),
        ('EMAIL_DOMINIO_INTERNO', N'', 'TEXTO',
         N'Domínio(s) do e-mail da empresa (ex.: cmj.com.br), separados por vírgula. Esses endereços saem pela conta interna; os demais pela externa. Vazio = todos pela interna.', 'SIS', 1),
        ('SISTEMA_NOME', N'SisCMJ', 'TEXTO',
         N'Nome do sistema mostrado nas telas, nos e-mails (rodapé e remetente) e nos relatórios. Só o administrador geral altera.', 'SIS', 0),
        ('EMAIL_LOGO_MODO', N'EMBUTIDA', 'TEXTO',
         N'Logomarca nos e-mails: EMBUTIDA (vai dentro do e-mail), ENDERECO (puxada do endereço público EMAIL_LOGO_ENDERECO, não aparece como anexo) ou SEM_IMAGEM (só a faixa colorida).', 'SIS', 0),
        ('EMAIL_LOGO_ENDERECO', N'', 'TEXTO',
         N'Endereço público (https://...) da logomarca, usado quando EMAIL_LOGO_MODO = ENDERECO.', 'SIS', 0),
        ('EMAIL_LOGO_NOME_ARQUIVO', N'CMJ.png', 'TEXTO',
         N'Nome com que a logomarca embutida aparece para quem recebe o e-mail (ex.: CMJ.png).', 'SIS', 0),
        ('EMAIL_LOCAL_LIBERADOS', N'', 'TEXTO',
         N'Só no banco de teste (_LOCAL): tipos de e-mail que saem para os destinatários reais em vez de irem para o EMAIL_TESTE, separados por vírgula (ex.: COMUNICADO). Vazio = todos desviados. Não tem efeito em produção.', 'SIS', 0),
        ('EMAIL_MINUTOS_PRESO', N'15', 'INTEIRO',
         N'Minutos que um e-mail pode ficar "processando" antes de voltar para a fila (serviço parou no meio). Mínimo 5.', 'SIS', 1),
        ('BACKUP_PASTA', N'C:\SistemaCMJ_Arquivos\Backup', 'TEXTO',
         N'Pasta do servidor onde ficam os backups do banco.', 'SIS', 0),
        ('BACKUP_PASTA_EXTERNA', N'', 'TEXTO',
         N'Pasta fora do servidor (disco externo ou pasta sincronizada com a nuvem) para onde os backups são copiados. Vazio = não copia.', 'SIS', 0),
        ('BACKUP_DIAS_MANTER', N'7', 'INTEIRO',
         N'Dias de backup guardados na pasta do servidor (completos e do log); os mais antigos são apagados.', 'SIS', 0),
        ('BACKUP_NUVEM_MANTER', N'1', 'INTEIRO',
         N'Quantos backups completos ficam na pasta da nuvem (BACKUP_PASTA_EXTERNA). 0 = não copia.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_COMPLETO', N'26', 'INTEIRO',
         N'Avisa por e-mail se o último backup completo sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_LOG', N'3', 'INTEIRO',
         N'Avisa por e-mail se o último backup do log (de hora em hora) sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_DIAS_ALERTA_TESTE', N'8', 'INTEIRO',
         N'Avisa por e-mail se o último teste de restauração sem erro tiver mais dias que isto.', 'SIS', 0),
        ('BACKUP_RESTAURACAO_MOTIVO_MINIMO', N'10', 'INTEIRO',
         N'Quantidade mínima de letras do motivo obrigatório ao pedir uma restauração de backup pela tela.', 'SIS', 0),
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('EMAIL_RODAPE_CNPJ', N'N', 'SN',
         N'Mostrar o CNPJ da empresa no rodapé dos e-mails enviados a clientes e terceiros (S/N).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1),
        ('SENHA_PROVISORIA_PADRAO', N'@12345', 'TEXTO',
         N'Senha provisória dada pelo botão Reiniciar senha da tela de Usuários. O usuário é obrigado a trocá-la no primeiro acesso.', 'SIS', 0),
        ('SENHA_PROVISORIA_HORAS', N'24', 'INTEIRO',
         N'Horas que a senha provisória vale. Passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar a senha de novo. 0 = não vence. Não vale para o administrador geral.', 'SIS', 1),
        ('LIXEIRA_ATIVA', N'S', 'SN',
         N'S = o botão Excluir das telas manda o registro para a lixeira (recuperável). N = a lixeira fica desligada e só é possível desativar.', 'SIS', 1),
        ('LIXEIRA_DIAS_GUARDA', N'90', 'INTEIRO',
         N'Dias que um registro excluído fica na lixeira antes de ser apagado de vez (mínimo 1). Cada tela pode ter prazo próprio na configuração das tabelas; vazio = vale este.', 'SIS', 1),
        ('LIXEIRA_AVISO_DIAS', N'1', 'INTEIRO',
         N'Com quantos dias de antecedência o e-mail avisa o que será apagado de vez da lixeira. 0 = sem aviso.', 'SIS', 1),
        ('LIXEIRA_AVISO_GRUPO', N'LIXEIRA_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe o aviso do que será apagado da lixeira (tela Grupos de e-mail).', 'SIS', 1),
        ('LIXEIRA_LIMPEZA_ATIVA', N'S', 'SN',
         N'S = a rotina diária apaga de vez o que passou do prazo da lixeira. N = nada é apagado (o aviso continua saindo).', 'SIS', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Acao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Ações que as telas podem ter. Só insere o que falta
                (regra 39). Ação nova de um módulo futuro entra aqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (16/11/2026) - Ação EXECUTAR (rotinas e comandos; etapa 02d).
    v1.2 (20/11/2026) - Ação RESTAURAR (restauração de backup pela tela; etapa 03d2).
    v1.3 (22/11/2026) - Etapa 04b (P20): DESATIVAR (o antigo "Excluir", que só
                        desativava), DESFAZER (pelo histórico), RECUPERAR e
                        ESVAZIAR (lixeira); EXCLUIR passa a mandar para a
                        lixeira (nome acertado).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Acao (CODIGO, NOME, ORDEM)
SELECT v.CODIGO, v.NOME, v.ORDEM
FROM (VALUES
        (CAST('VER' AS VARCHAR(20)), CAST(N'Ver / consultar' AS NVARCHAR(60)), CAST(10 AS SMALLINT)),
        ('INCLUIR',          N'Incluir',                     20),
        ('ALTERAR',          N'Alterar',                     30),
        ('EXCLUIR',          N'Excluir / cancelar registro', 40),
        ('EXPORTAR',         N'Exportar para Excel',         50),
        ('IMPORTAR',         N'Importar arquivo',            60),
        ('BAIXAR',           N'Baixar (pagar/receber)',      70),
        ('ESTORNAR',         N'Estornar',                    80),
        ('CANCELAR',         N'Cancelar (contrato, boleto)', 90),
        ('REABRIR',          N'Reabrir (mês, contrato)',    100),
        ('APROVAR',          N'Aprovar',                    110),
        ('ENVIAR',           N'Enviar (e-mail, remessa)',   120),
        ('DESBLOQUEAR',      N'Desbloquear usuário',        130),
        ('REDEFINIR_SENHA',  N'Definir senha provisória',   140),
        ('EXECUTAR',         N'Executar (rotina, comando)', 150),
        ('RESTAURAR',        N'Restaurar backup do banco',  160),
        ('DESATIVAR',        N'Desativar / reativar',        45),
        ('DESFAZER',         N'Desfazer pelo histórico',    170),
        ('RECUPERAR',        N'Recuperar da lixeira',       180),
        ('ESVAZIAR',         N'Esvaziar a lixeira (apagar de vez)', 190)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
GO

UPDATE a
   SET a.NOME = N'Excluir (vai para a lixeira) / cancelar', a.DT_ALTERACAO = SYSDATETIME(), a.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Acao a
WHERE a.CODIGO = 'EXCLUIR' AND a.NOME = N'Excluir / cancelar registro';
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Item.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Item] e [SIS].[Item_Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Menu do módulo SIS e as ações de cada tela. Só insere o que
                falta (regra 39). Cada etapa seguinte acrescenta aqui os itens
                do seu módulo (ou cria a carga do seu bloco).
                Itens são inseridos em passadas: primeiro os de 1º nível,
                depois os filhos cujo pai já existe (até 5 níveis).
                Caminhos das telas: relativos ao wwwroot da API (fase 4).
                Acertado também em item já existente (itens só mudam por
                carga): EXCLUSIVO_GERAL e TABELAS_DA_TELA.
                HABILITADO só é gravado na inclusão (depois é escolha do
                administrador geral). Telas do SIS nascem habilitadas; telas de
                módulos novos devem nascer com HABILITADO = 0.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - EXCLUSIVO_GERAL: Licença e Parâmetros só para o
                        administrador geral (acertado também em item já
                        existente, porque itens só mudam por carga).
    v1.2 (16/11/2026) - Etapa 02c: HABILITADO, TABELAS_DA_TELA e as telas
                        "Módulos e telas" (exclusiva), "Auditoria" e "Lotes".
    v1.3 (16/11/2026) - Etapa 02d: "Rotinas automáticas" e "Instalação e
                        manutenção" (exclusivas); agrupador "E-mails" com
                        "Grupos de e-mail" e "E-mails enviados".
    v1.4 (22/11/2026) - Etapa 04b (P20): tela "Lixeira" (Monitoramento) e ação
                        DESFAZER em Usuários, Perfis e Auditoria (lote).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaItem;

SELECT v.MODULO, v.PAI, v.CODIGO, v.NOME, v.TIPO, v.CAMINHO, v.ORDEM, v.EXCLUSIVO_GERAL, v.HABILITADO, v.TABELAS
INTO #CargaItem
FROM (VALUES
        (CAST('SIS' AS VARCHAR(10)), CAST(NULL AS VARCHAR(40)), CAST('SIS_CONFIGURACAO' AS VARCHAR(40)), CAST(N'Configuração' AS NVARCHAR(80)),
         CAST('MENU' AS VARCHAR(10)), CAST('' AS VARCHAR(200)), CAST(10 AS SMALLINT), CAST(0 AS BIT), CAST(1 AS BIT), CAST('' AS VARCHAR(500))),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_LICENCA',       N'Licença',             'TELA', 'sis/licenca.html',     10, 1, 1, 'SIS.Licenca,SIS.Licenca_Empresa'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_PARAMETRO',     N'Parâmetros',          'TELA', 'sis/parametros.html',  20, 1, 1, 'SIS.Parametro'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_MODULO',        N'Módulos e telas',     'TELA', 'sis/modulos.html',     30, 1, 1, 'SIS.Modulo,SIS.Item'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_ROTINA',        N'Rotinas automáticas', 'TELA', 'sis/rotinas.html',     40, 1, 1, 'SIS.Rotina'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_INSTALACAO',    N'Instalação e manutenção', 'TELA', 'sis/instalacao.html', 50, 1, 1, ''),
        ('SIS', NULL,                'SIS_SEGURANCA',     N'Segurança',           'MENU', '',                     20, 0, 1, ''),
        ('SIS', 'SIS_SEGURANCA',     'SIS_USUARIO',       N'Usuários',            'TELA', 'sis/usuarios.html',    10, 0, 1, 'SIS.Usuario,SIS.Usuario_Permissao'),
        ('SIS', 'SIS_SEGURANCA',     'SIS_PERFIL',        N'Perfis e permissões', 'TELA', 'sis/perfis.html',      20, 0, 1, 'SIS.Perfil,SIS.Perfil_Permissao'),
        ('SIS', NULL,                'SIS_EMAILS',        N'E-mails',             'MENU', '',                     25, 0, 1, ''),
        ('SIS', 'SIS_EMAILS',        'SIS_GRUPO_EMAIL',   N'Grupos de e-mail',    'TELA', 'sis/grupos-email.html', 10, 0, 1, 'SIS.Grupo_Email,SIS.Grupo_Email_Destinatario'),
        ('SIS', 'SIS_EMAILS',        'SIS_EMAIL_FILA',    N'E-mails enviados',    'TELA', 'sis/emails.html',      20, 0, 1, ''),
        ('SIS', NULL,                'SIS_MONITORAMENTO', N'Monitoramento',       'MENU', '',                     30, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOG_ERRO',      N'Log de erros',        'TELA', 'sis/log-erros.html',   10, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_AUDITORIA',     N'Auditoria',           'TELA', 'sis/auditoria.html',   20, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOTE',          N'Lotes',               'TELA', 'sis/lotes.html',       30, 0, 1, 'SIS.Lote'),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LIXEIRA',       N'Lixeira',             'TELA', 'sis/lixeira.html',     40, 0, 1, 'SIS.Lixeira,SIS.Tabela_Config')
     ) v (MODULO, PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS);

DECLARE @Passada INT = 1;
WHILE @Passada <= 5
BEGIN
    INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
    SELECT m.ID_MODULO, pai.ID_ITEM, c.CODIGO, c.NOME, c.TIPO, c.CAMINHO, c.ORDEM, c.EXCLUSIVO_GERAL, c.HABILITADO, c.TABELAS
    FROM #CargaItem c
    INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
    LEFT  JOIN SIS.Item pai ON pai.CODIGO = c.PAI
    WHERE (c.PAI IS NULL OR pai.ID_ITEM IS NOT NULL)
      AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = c.CODIGO);

    SET @Passada = @Passada + 1;
END;

UPDATE i
   SET i.EXCLUSIVO_GERAL   = c.EXCLUSIVO_GERAL,
       i.TABELAS_DA_TELA   = c.TABELAS,
       i.DT_ALTERACAO      = SYSDATETIME(),
       i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
INNER JOIN #CargaItem c ON c.CODIGO = i.CODIGO
WHERE i.EXCLUSIVO_GERAL <> c.EXCLUSIVO_GERAL
   OR i.TABELAS_DA_TELA <> c.TABELAS;

DROP TABLE IF EXISTS #CargaItem;
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES
        (CAST('SIS_LICENCA' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))),
        ('SIS_LICENCA',   'INCLUIR'),
        ('SIS_PARAMETRO', 'VER'),
        ('SIS_PARAMETRO', 'ALTERAR'),
        ('SIS_PARAMETRO', 'EXPORTAR'),
        ('SIS_MODULO',    'VER'),
        ('SIS_MODULO',    'ALTERAR'),
        ('SIS_USUARIO',   'VER'),
        ('SIS_USUARIO',   'INCLUIR'),
        ('SIS_USUARIO',   'ALTERAR'),
        ('SIS_USUARIO',   'DESBLOQUEAR'),
        ('SIS_USUARIO',   'REDEFINIR_SENHA'),
        ('SIS_USUARIO',   'EXPORTAR'),
        ('SIS_PERFIL',    'VER'),
        ('SIS_PERFIL',    'INCLUIR'),
        ('SIS_PERFIL',    'ALTERAR'),
        ('SIS_PERFIL',    'EXPORTAR'),
        ('SIS_LOG_ERRO',  'VER'),
        ('SIS_LOG_ERRO',  'EXPORTAR'),
        ('SIS_AUDITORIA', 'VER'),
        ('SIS_AUDITORIA', 'EXPORTAR'),
        ('SIS_LOTE',      'VER'),
        ('SIS_LOTE',      'EXPORTAR'),
        ('SIS_ROTINA',    'VER'),
        ('SIS_ROTINA',    'ALTERAR'),
        ('SIS_ROTINA',    'EXECUTAR'),
        ('SIS_INSTALACAO','VER'),
        ('SIS_INSTALACAO','EXECUTAR'),
        ('SIS_INSTALACAO','CANCELAR'),
        ('SIS_GRUPO_EMAIL','VER'),
        ('SIS_GRUPO_EMAIL','INCLUIR'),
        ('SIS_GRUPO_EMAIL','ALTERAR'),
        ('SIS_GRUPO_EMAIL','EXPORTAR'),
        ('SIS_EMAIL_FILA','VER'),
        ('SIS_EMAIL_FILA','ENVIAR'),
        ('SIS_EMAIL_FILA','CANCELAR'),
        ('SIS_EMAIL_FILA','EXPORTAR'),
        ('SIS_LIXEIRA',   'VER'),
        ('SIS_LIXEIRA',   'RECUPERAR'),
        ('SIS_LIXEIRA',   'ALTERAR'),
        ('SIS_LIXEIRA',   'ESVAZIAR'),
        ('SIS_LIXEIRA',   'EXPORTAR'),
        ('SIS_USUARIO',   'DESFAZER'),
        ('SIS_PERFIL',    'DESFAZER'),
        ('SIS_AUDITORIA', 'DESFAZER')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/Carga_CAD_Item.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Item] e [SIS].[Item_Acao] dos módulos CAD e BANCO
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Telas da etapa 03a no menu: Cadastros (Empresas, Pessoas, Centros de
                custo, Plano de contas) e Bancos (Contas bancárias, Bancos), com as
                ações de cada tela. Só insere o que falta (regra 39). Telas de módulo
                novo nascem DESABILITADAS (HABILITADO = 0): o administrador geral liga
                na tela "Módulos e telas" quando quiser liberar. Acertado também em
                item já existente: TABELAS_DA_TELA (itens só mudam por carga).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): ações DESATIVAR (o antigo Excluir) e
                        DESFAZER nas telas de cadastro; DESATIVAR nasce com
                        quem já tinha EXCLUIR (perfil e exceção do usuário),
                        porque até aqui o Excluir só desativava.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaItem;

SELECT v.MODULO, v.CODIGO, v.NOME, v.CAMINHO, v.ORDEM, v.TABELAS
INTO #CargaItem
FROM (VALUES
        (CAST('CAD' AS VARCHAR(10)), CAST('CAD_EMPRESA' AS VARCHAR(40)), CAST(N'Empresas' AS NVARCHAR(80)), CAST('cad/empresas.html' AS VARCHAR(200)),
         CAST(10 AS SMALLINT), CAST('CAD.Empresa' AS VARCHAR(500))),
        ('CAD',   'CAD_PESSOA',       N'Pessoas',          'cad/pessoas.html',        20, 'CAD.Pessoa,CAD.Pessoa_Contato,CAD.Pessoa_Vinculo,CAD.Pessoa_Dado_Bancario'),
        ('CAD',   'CAD_CENTRO_CUSTO', N'Centros de custo', 'cad/centros-custo.html',  30, 'CAD.Centro_Custo'),
        ('CAD',   'CAD_PLANO_CONTA',  N'Plano de contas',  'cad/plano-contas.html',   40, 'CAD.Plano_Grupo,CAD.Plano_Subgrupo,CAD.Plano_Conta'),
        ('BANCO', 'BANCO_CONTA',      N'Contas bancárias', 'banco/contas.html',       10, 'BANCO.Conta'),
        ('BANCO', 'BANCO_BANCO',      N'Bancos',           'banco/bancos.html',       20, 'BANCO.Banco')
     ) v (MODULO, CODIGO, NOME, CAMINHO, ORDEM, TABELAS);

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, c.CODIGO, c.NOME, 'TELA', c.CAMINHO, c.ORDEM, 0, 0, c.TABELAS
FROM #CargaItem c
INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = c.CODIGO);

UPDATE i
   SET i.TABELAS_DA_TELA = c.TABELAS, i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
INNER JOIN #CargaItem c ON c.CODIGO = i.CODIGO
WHERE i.TABELAS_DA_TELA <> c.TABELAS;

DROP TABLE IF EXISTS #CargaItem;
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES
        (CAST('CAD_EMPRESA' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))),
        ('CAD_EMPRESA', 'INCLUIR'), ('CAD_EMPRESA', 'ALTERAR'), ('CAD_EMPRESA', 'EXCLUIR'), ('CAD_EMPRESA', 'EXPORTAR'),
        ('CAD_PESSOA', 'VER'), ('CAD_PESSOA', 'INCLUIR'), ('CAD_PESSOA', 'ALTERAR'), ('CAD_PESSOA', 'EXCLUIR'), ('CAD_PESSOA', 'EXPORTAR'),
        ('CAD_CENTRO_CUSTO', 'VER'), ('CAD_CENTRO_CUSTO', 'INCLUIR'), ('CAD_CENTRO_CUSTO', 'ALTERAR'), ('CAD_CENTRO_CUSTO', 'EXCLUIR'), ('CAD_CENTRO_CUSTO', 'EXPORTAR'),
        ('CAD_PLANO_CONTA', 'VER'), ('CAD_PLANO_CONTA', 'INCLUIR'), ('CAD_PLANO_CONTA', 'ALTERAR'), ('CAD_PLANO_CONTA', 'EXCLUIR'), ('CAD_PLANO_CONTA', 'EXPORTAR'),
        ('BANCO_CONTA', 'VER'), ('BANCO_CONTA', 'INCLUIR'), ('BANCO_CONTA', 'ALTERAR'), ('BANCO_CONTA', 'EXCLUIR'), ('BANCO_CONTA', 'EXPORTAR'),
        ('BANCO_BANCO', 'VER'), ('BANCO_BANCO', 'INCLUIR'), ('BANCO_BANCO', 'ALTERAR'), ('BANCO_BANCO', 'EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

DECLARE @NovosDesativar TABLE (ID_ITEM_ACAO INT NOT NULL, ID_ITEM INT NOT NULL);
DECLARE @IdExcluir INT = (SELECT a.ID_ACAO FROM SIS.Acao a WHERE a.CODIGO = 'EXCLUIR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, inserted.ID_ITEM INTO @NovosDesativar (ID_ITEM_ACAO, ID_ITEM)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('CAD_EMPRESA' AS VARCHAR(40))), ('CAD_PESSOA'), ('CAD_CENTRO_CUSTO'), ('CAD_PLANO_CONTA'), ('BANCO_CONTA')) v (ITEM)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = 'DESATIVAR'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

-- quem tinha EXCLUIR (que desativava) recebe DESATIVAR, só quando a ação nasce
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosDesativar n
INNER JOIN SIS.Item_Acao ie ON ie.ID_ITEM = n.ID_ITEM AND ie.ID_ACAO = @IdExcluir
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = ie.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosDesativar n
INNER JOIN SIS.Item_Acao ie ON ie.ID_ITEM = n.ID_ITEM AND ie.ID_ACAO = @IdExcluir
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = ie.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('CAD_EMPRESA' AS VARCHAR(40))), ('CAD_PESSOA'), ('CAD_CENTRO_CUSTO'), ('CAD_PLANO_CONTA'), ('BANCO_CONTA'), ('BANCO_BANCO')) v (ITEM)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = 'DESFAZER'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Perfil_Padrao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial dos perfis comuns de [SIS].[Perfil]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Perfis de fábrica para o administrador da empresa começar
                (pendência 9 da seção 6 do CLAUDE.md; sugestão aprovada pelo
                Celso em 22/11/2026, conversa 04a). Depois de criados, quem
                manda é a tela Perfis e permissões: o administrador ajusta à
                vontade.
                  Financeiro: todas as ações nas telas de Cadastros,
                      Financeiro, Bancos e Cobrança, menos REABRIR (mês
                      fechado); só consulta em Imóveis, Vendas, Custos de obra
                      e Painel.
                  Consulta: só VER em todas as telas fora do módulo Sistema.
                As permissões são dadas SÓ quando o perfil nasce (neste mesmo
                lote). Perfil que já existe não é tocado: rodar o MASTER de novo
                (atualização) nunca devolve uma permissão que o administrador
                tirou. Telas novas de versões futuras entram desmarcadas: o
                administrador marca na tela.
                Telas exclusivas do administrador geral nunca entram.
                Depende das cargas de SIS.Item e SIS.Item_Acao de todos os
                módulos (vai depois delas).

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04a).
    v1.1 (22/11/2026) - Etapa 04b (P20): Financeiro não recebe DESFAZER
                        (liberável por perfil; decisão do Celso).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Novos TABLE (ID_PERFIL INT NOT NULL, NOME NVARCHAR(60) NOT NULL);

INSERT INTO SIS.Perfil (NOME, DESCRICAO, NIVEL_ADMIN, ATIVO)
OUTPUT inserted.ID_PERFIL, inserted.NOME INTO @Novos (ID_PERFIL, NOME)
SELECT v.NOME, v.DESCRICAO, 0, 1
FROM (VALUES
        (CAST(N'Financeiro' AS NVARCHAR(60)),
         CAST(N'Contas a pagar e a receber, baixas, bancos e cobrança, com os cadastros. Não reabre mês fechado. Só consulta imóveis, vendas, obras e painel.' AS NVARCHAR(400))),
        (N'Consulta',
         N'Só consulta: vê as telas dos módulos liberados, sem incluir, alterar, excluir nem exportar.')
     ) v (NOME, DESCRICAO)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil p WHERE p.NOME = v.NOME);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT n.ID_PERFIL, ia.ID_ITEM_ACAO
FROM @Novos n
CROSS JOIN SIS.Item_Acao ia
INNER JOIN SIS.Item   i ON i.ID_ITEM   = ia.ID_ITEM AND i.TIPO = 'TELA' AND i.EXCLUSIVO_GERAL = 0
INNER JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO
INNER JOIN SIS.Acao   a ON a.ID_ACAO   = ia.ID_ACAO
WHERE ia.ATIVO = 1
  AND m.CODIGO <> 'SIS'
  AND (   (n.NOME = N'Consulta'   AND a.CODIGO = 'VER')
       OR (n.NOME = N'Financeiro' AND m.CODIGO IN ('CAD', 'FIN', 'BANCO', 'COBR') AND a.CODIGO NOT IN ('REABRIR', 'DESFAZER'))
       OR (n.NOME = N'Financeiro' AND m.CODIGO NOT IN ('CAD', 'FIN', 'BANCO', 'COBR') AND a.CODIGO = 'VER'))
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = n.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Rotina.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Rotina]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Rotinas automáticas da base SIS. Só insere o que falta
                (regra 39): agenda já mudada pela tela não é desfeita.
                Cada etapa seguinte acrescenta aqui as rotinas do seu módulo
                (ex.: avisos de vencimento, retorno do banco), com a
                procedure sem parâmetros que a rotina chama.
                A próxima execução é calculada na inclusão.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d): limpeza do log passo a passo e
                        liberação de e-mails presos.
    v1.1 (22/11/2026) - Etapa 04b (P20): LIXEIRA_LIMPEZA (limpeza e aviso da
                        lixeira, todo dia às 06:40).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT v.CODIGO, v.NOME, v.DESCRICAO, v.PROCEDIMENTO, m.ID_MODULO, v.FREQUENCIA, v.INTERVALO, v.HORARIO, v.DIAS, v.DIA_MES,
       v.LIMITE, 1, SIS.fn_SIS_Rotina_Proxima(v.FREQUENCIA, v.INTERVALO, v.HORARIO, v.DIAS, v.DIA_MES, SYSDATETIME()), N'instalacao'
FROM (VALUES
        (CAST('LOG_LIMPEZA' AS VARCHAR(40)), CAST(N'Limpeza do log passo a passo' AS NVARCHAR(80)),
         CAST(N'Apaga o log passo a passo das rotinas mais antigo que o parâmetro LOG_PASSO_DIAS_RETENCAO. O log de erros não é apagado.' AS NVARCHAR(400)),
         CAST(N'SIS.SIS_Log_Limpar_Processar' AS NVARCHAR(256)), CAST('SIS' AS VARCHAR(10)), CAST('DIARIA' AS VARCHAR(10)),
         CAST(0 AS INT), CAST('03:10' AS TIME(0)), CAST('' AS VARCHAR(20)), CAST(0 AS TINYINT), CAST(60 AS INT)),
        ('EMAIL_PRESOS', N'Liberar e-mails presos',
         N'Devolve para a fila os e-mails que ficaram "processando" (o serviço parou no meio do envio), conforme o parâmetro EMAIL_MINUTOS_PRESO.',
         N'SIS.SIS_Email_Presos_Liberar', 'SIS', 'MINUTOS', 10, '00:00', '', 0, 10),
        ('LIXEIRA_LIMPEZA', N'Lixeira: limpeza e aviso',
         N'Apaga de vez o que passou do prazo da lixeira (LIXEIRA_DIAS_GUARDA ou o prazo da tela) e avisa por e-mail o que será apagado nos próximos LIXEIRA_AVISO_DIAS dia(s).',
         N'SIS.SIS_Lixeira_Processar', 'SIS', 'DIARIA', 0, '06:40', '', 0, 30)
     ) v (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, MODULO, FREQUENCIA, INTERVALO, HORARIO, DIAS, DIA_MES, LIMITE)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = v.CODIGO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Tabela_Config.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Tabela_Config] e do grupo de e-mail da lixeira
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Configuração do desfazer e da lixeira por tabela (P20,
                docs/requisitos/Lixeira_Desfazer.md). Inclui o que falta e
                acerta a parte técnica (filhas, campos, descrição) das que já
                existem; o prazo próprio (DIAS_GUARDA) é da CMJ e nunca é
                mudado por aqui.
                Grupo de e-mail LIXEIRA_AVISO (aviso do que será apagado):
                nasce com o e-mail interno do sistema; a CMJ ajusta na tela
                Grupos de e-mail.
                Idempotente.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaConfig;

SELECT v.TABELA, v.DESFAZER, v.LIXEIRA, v.BLOQUEADOS, v.UNICOS, v.FILHAS, v.INCLUSAO, v.EXCLUSAO, v.DESCRICAO
INTO #CargaConfig
FROM (VALUES
        (CAST(N'CAD.Pessoa' AS NVARCHAR(256)), CAST(1 AS BIT), CAST(1 AS BIT), CAST(N'' AS NVARCHAR(1000)), CAST(N'CPF_CNPJ' AS NVARCHAR(400)),
         CAST(N'CAD.Pessoa_Contato.ID_PESSOA,CAD.Pessoa_Vinculo.ID_PESSOA,CAD.Pessoa_Dado_Bancario.ID_PESSOA' AS NVARCHAR(1000)),
         CAST('LIXEIRA' AS VARCHAR(10)), CAST('RECUSAR' AS VARCHAR(10)),
         CAST(N't.NOME + CASE WHEN t.CPF_CNPJ <> '''' THEN N'' ('' + CONVERT(NVARCHAR(20), t.CPF_CNPJ) + N'')'' ELSE N'''' END' AS NVARCHAR(1000))),
        (N'CAD.Pessoa_Contato',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(20), t.TIPO) + N'': '' + t.VALOR'),
        (N'CAD.Pessoa_Vinculo',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Vínculo '' + CONVERT(NVARCHAR(30), t.TIPO)'),
        (N'CAD.Pessoa_Dado_Bancario', 1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Conta '' + CONVERT(NVARCHAR(20), t.AGENCIA) + N'' / '' + CONVERT(NVARCHAR(30), t.CONTA)'),
        (N'CAD.Empresa',              1, 1, N'', N'CNPJ', N'', 'LIXEIRA', 'RECUSAR', N't.RAZAO_SOCIAL'),
        (N'CAD.Centro_Custo',         1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N'CONVERT(NVARCHAR(30), t.CODIGO) + N'' - '' + t.DESCRICAO'),
        (N'CAD.Plano_Grupo',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Subgrupo',       1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Conta',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Conta',              1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Banco',              1, 0, N'', N'', N'', 'RECUSAR', 'RECUSAR', N'CONVERT(NVARCHAR(10), t.CODIGO) + N'' - '' + t.NOME'),
        (N'SIS.Usuario',              1, 0, N'SENHA_HASH,SENHA_SALT,SENHA_ITERACOES,SENHA_ALGORITMO,DT_SENHA,TROCAR_SENHA,TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN,BLOQUEADO,DT_BLOQUEIO,INTERNO',
         N'', N'SIS.Usuario_Permissao.ID_USUARIO', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(100), t.LOGIN) + N'' - '' + t.NOME'),
        (N'SIS.Usuario_Permissao',    1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))'),
        (N'SIS.Perfil',               1, 0, N'NIVEL_ADMIN', N'', N'SIS.Perfil_Permissao.ID_PERFIL', 'DESATIVAR', 'RECUSAR', N't.NOME'),
        (N'SIS.Perfil_Permissao',     1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))')
     ) v (TABELA, DESFAZER, LIXEIRA, BLOQUEADOS, UNICOS, FILHAS, INCLUSAO, EXCLUSAO, DESCRICAO);

INSERT INTO SIS.Tabela_Config (TABELA, PERMITE_DESFAZER, PERMITE_LIXEIRA, CAMPOS_BLOQUEADOS, CAMPOS_UNICOS, TABELAS_FILHAS, DESFAZER_INCLUSAO, DESFAZER_EXCLUSAO, DESCRICAO_SQL, USUARIO_CRIACAO)
SELECT c.TABELA, c.DESFAZER, c.LIXEIRA, c.BLOQUEADOS, c.UNICOS, c.FILHAS, c.INCLUSAO, c.EXCLUSAO, c.DESCRICAO, N'instalacao'
FROM #CargaConfig c
WHERE OBJECT_ID(c.TABELA, N'U') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config t WHERE t.TABELA = c.TABELA);

UPDATE t
   SET t.PERMITE_DESFAZER = c.DESFAZER, t.PERMITE_LIXEIRA = c.LIXEIRA, t.CAMPOS_BLOQUEADOS = c.BLOQUEADOS, t.CAMPOS_UNICOS = c.UNICOS,
       t.TABELAS_FILHAS = c.FILHAS, t.DESFAZER_INCLUSAO = c.INCLUSAO, t.DESFAZER_EXCLUSAO = c.EXCLUSAO, t.DESCRICAO_SQL = c.DESCRICAO,
       t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Tabela_Config t
INNER JOIN #CargaConfig c ON c.TABELA = t.TABELA
WHERE t.PERMITE_DESFAZER <> c.DESFAZER OR t.PERMITE_LIXEIRA <> c.LIXEIRA OR t.CAMPOS_BLOQUEADOS <> c.BLOQUEADOS OR t.CAMPOS_UNICOS <> c.UNICOS
   OR t.TABELAS_FILHAS <> c.FILHAS OR t.DESFAZER_INCLUSAO <> c.INCLUSAO OR t.DESFAZER_EXCLUSAO <> c.EXCLUSAO OR t.DESCRICAO_SQL <> c.DESCRICAO;

DROP TABLE IF EXISTS #CargaConfig;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT 'LIXEIRA_AVISO', N'Aviso da lixeira', N'Recebem o aviso diário do que será apagado de vez da lixeira (Sistema › Lixeira).', N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = 'LIXEIRA_AVISO');

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, N'construtora.m.judice@gmail.com', N'Administração do sistema', N'instalacao'
FROM SIS.Grupo_Email g
WHERE g.CODIGO = 'LIXEIRA_AVISO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do SIS
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de configuração e
                segurança do SIS, gerando cada trigger com
                SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas.
                No MASTER fica na parte 8 (triggers). Cada etapa seguinte
                acrescenta aqui (ou na carga do seu bloco) as suas tabelas.
                Não auditadas (são registros, não cadastros): Log_Erro,
                Log_Passo, Login_Log, Sessao, Lote e a própria Auditoria.
                SIS.Usuario: não registra contador de tentativas nem último
                login (mudam a cada acesso); hash e salt da senha saem "***".

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (16/11/2026) - Etapa 02d: grupos de e-mail, rotinas (sem as colunas
                        de execução) e comandos. Filas e logs não são
                        auditados (têm histórico próprio).
    v1.2 (22/11/2026) - Etapa 04b (P20): SIS.Lixeira e SIS.Tabela_Config.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Modulo',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Item',              @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Acao',              @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Item_Acao',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Perfil',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Perfil_Permissao',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Usuario',           @Criar = 1,
     @CamposIgnorados = N'TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN', @CamposSigilosos = N'SENHA_HASH,SENHA_SALT';
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Usuario_Permissao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Licenca',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Licenca_Empresa',   @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Anexo_Tipo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Anexo',             @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Grupo_Email',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Grupo_Email_Destinatario', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Rotina',            @Criar = 1,
     @CamposIgnorados = N'PROXIMA_EXECUCAO,SOLICITADA_POR,EM_EXECUCAO,DT_INICIO_EXECUCAO,ULTIMA_EXECUCAO,ULTIMO_RESULTADO,ULTIMA_MENSAGEM';
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comando',           @Criar = 1;
GO
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Lixeira',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Tabela_Config',     @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/Carga_CAD_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do CAD e do BANCO
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas 11 tabelas da etapa 03a, gerando cada
                trigger com SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas. No MASTER
                fica na parte 8 (triggers).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Banco',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Conta',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Centro_Custo',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa',                @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Contato',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Vinculo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Dado_Bancario',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Grupo',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Subgrupo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Conta',           @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Versao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : registro da versão do banco em [SIS].[Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : ÚLTIMA instrução do MASTER (depois da finalização): grava a
                versão que acabou de ser instalada. É a ÚNICA fonte da versão do
                banco: o montar_master.py lê o número daqui para o cabeçalho
                do MASTER, e a API exige o mesmo número
                (Infra/VersaoBanco.cs, VersaoExigida).
                REGRA: toda mudança que vai para o MASTER sobe este número e o
                da API juntos.
                Em banco de desenvolvimento (_LOCAL) grava com ORIGEM
                PACOTE_LOCAL. Rodar de novo grava outra linha (histórico).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d): versão 1.1 do banco.
    Versões do banco: 1.1 (20/11/2026) limite de login por computador e versão;
                      1.2 (20/11/2026) primeiro acesso da instalação;
                      1.3 (20/11/2026) SIS_Registro_Existe (anexos com o login da API);
                      1.4 (20/11/2026) fn_SIS_Usuario_Id (licença gravada pela API);
                      1.5 (20/11/2026) backup do servidor (SIS.Backup, avisos de atraso).
                      1.6 (20/11/2026) restauração de backup pela tela (SIS.Backup_Restauracao).
                      1.7 (22/11/2026) ajuda exclusiva do administrador geral (SIS_Ajuda_Geral_Obter, tela SIS_AJUDA_GERAL).
                      1.8 (22/11/2026) atualização em um clique (SIS.Atualizacao, SIS_Atualizacao_Registrar).
                      1.9 (22/11/2026) telas de Usuários e Perfis (senha provisória que vence, perfis Financeiro e Consulta).
                      2.0 (22/11/2026) histórico padrão: desfazer pela auditoria e lixeira (P20, etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '2.0';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO

PRINT N'Pacote 04b concluído sem erro.';
GO

SET NOEXEC OFF;
GO
