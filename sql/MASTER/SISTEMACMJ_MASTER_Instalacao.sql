/*******************************************************************************
  Arquivo     : SISTEMACMJ_MASTER_Instalacao.sql   (MASTER v1.5)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Gerado em   : 20/11/2026 por sql/ferramentas/montar_master.py, juntando os
                arquivos de sql/objetos aprovados (pacotes 02a a 03d), sem o schema
                MIG (regra 60). NAO EDITAR ESTE ARQUIVO: corrigir o arquivo do
                objeto e gerar o MASTER de novo.
  Descricao   : Instala (ou atualiza) TODO o banco do SisCMJ no servidor do
                cliente, de uma vez (PADRAO_SQL regras 58 a 60). Idempotente:
                roda de novo sem erro e sem perder dado.
  Ordem       : 1) conferencia do banco, 2) schemas, 3) tabelas e restricoes,
                4) sequences, 5) functions, 6) views, 7) procedures,
                8) triggers, 8b) seguranca, 9) parametros e carga inicial.
  Banco       : SISTEMACMJ (o banco ja tem de existir:
                sql/MASTER/SISTEMACMJ_00_Criar_Banco.sql).
  Depois      : criar o login da API e colocar o usuario no papel
                rl_sistemacmj_api (roteiro de instalacao; a senha nao fica em
                arquivo).
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > conferir o banco > F5.
  Objetos     : 196 arquivos.
*******************************************************************************/
-- =============================================================================
-- 1. CONFERENCIA DO BANCO
-- =============================================================================
IF DB_NAME() <> N'SISTEMACMJ'
BEGIN
    RAISERROR(N'Banco errado: o MASTER so roda no banco SISTEMACMJ. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO
PRINT N'MASTER v1.5: inicio da instalacao em ' + DB_NAME() + N' (' + CONVERT(NVARCHAR(30), SYSDATETIME(), 120) + N').';
GO

-- =============================================================================
-- 2. SCHEMAS
-- =============================================================================
PRINT N'2. SCHEMAS';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/_GERAL/Schemas.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : schemas do SistemaCMJ
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Cria os schemas por bloco (PADRAO_SQL regra 31).
                O schema MIG (migração) não é criado aqui: ele não entra no
                MASTER e é criado pelo pacote da migração.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (16/11/2026) - Schema COMP (Compras), pedido do Celso (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'CAD')   IS NULL EXEC (N'CREATE SCHEMA [CAD] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'BANCO') IS NULL EXEC (N'CREATE SCHEMA [BANCO] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'IMOB')  IS NULL EXEC (N'CREATE SCHEMA [IMOB] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'VENDA') IS NULL EXEC (N'CREATE SCHEMA [VENDA] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'FIN')   IS NULL EXEC (N'CREATE SCHEMA [FIN] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'COBR')  IS NULL EXEC (N'CREATE SCHEMA [COBR] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'OBRA')  IS NULL EXEC (N'CREATE SCHEMA [OBRA] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'COMP')  IS NULL EXEC (N'CREATE SCHEMA [COMP] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'GER')   IS NULL EXEC (N'CREATE SCHEMA [GER] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'SIS')   IS NULL EXEC (N'CREATE SCHEMA [SIS] AUTHORIZATION [dbo];');
GO
GO

-- =============================================================================
-- 3. TABELAS E RESTRICOES
-- =============================================================================
PRINT N'3. TABELAS E RESTRICOES';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Modulo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Modulo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Módulos do sistema (CAD, FIN, VENDA...). Base do menu lateral,
                das permissões e da licença: LIBERADO_LICENCA é atualizado só
                pela procedure da licença (etapa 02b), nunca por tela.
                HABILITADO: liberado para uso pelo administrador geral (tela
                "Módulos e telas"); módulo novo nasce desabilitado, para poder
                ser instalado em desenvolvimento sem aparecer. O módulo só é
                usado se estiver na licença E habilitado. SIS sempre habilitado.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (16/11/2026) - HABILITADO (pedido 5 do Celso, etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Modulo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Modulo]
    (
        ID_MODULO          INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(10)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        ORDEM_MENU         SMALLINT       NOT NULL CONSTRAINT DF_Modulo_ORDEM_MENU       DEFAULT (0),
        ICONE              VARCHAR(40)    NOT NULL CONSTRAINT DF_Modulo_ICONE            DEFAULT (''),
        LIBERADO_LICENCA   BIT            NOT NULL CONSTRAINT DF_Modulo_LIBERADO_LICENCA DEFAULT (0),
        HABILITADO         BIT            NOT NULL CONSTRAINT DF_Modulo_HABILITADO       DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Modulo_ATIVO            DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Modulo_DT_CRIACAO       DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Modulo_USUARIO_CRIACAO  DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Modulo        PRIMARY KEY CLUSTERED (ID_MODULO),
        CONSTRAINT UQ_Modulo_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Modulo_CODIGO CHECK (CODIGO <> '' AND CODIGO NOT LIKE '%[^A-Z]%')
    );
END;
GO

-- Ajuste de banco criado com a v1.0: coluna nova; SIS já nasce habilitado
IF COL_LENGTH(N'SIS.Modulo', N'HABILITADO') IS NULL
BEGIN
    ALTER TABLE [SIS].[Modulo] ADD HABILITADO BIT NOT NULL CONSTRAINT DF_Modulo_HABILITADO DEFAULT (0);
    EXEC (N'UPDATE m SET m.HABILITADO = 1 FROM SIS.Modulo m WHERE m.CODIGO = ''SIS'';');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Log_Erro.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Log_Erro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Log de erros técnicos do SQL, da API e do serviço (PADRAO_SQL
                regra 13). Nunca é apagado. As colunas que os gabaritos usam
                (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO) bastam;
                ORIGEM, USUARIO e ESTACAO têm valor padrão.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Log_Erro]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Log_Erro]
    (
        ID_LOG_ERRO   BIGINT         IDENTITY(1,1) NOT NULL,
        ROTINA        NVARCHAR(256)  NOT NULL CONSTRAINT DF_Log_Erro_ROTINA      DEFAULT (N''),
        ETAPA         NVARCHAR(200)  NOT NULL CONSTRAINT DF_Log_Erro_ETAPA       DEFAULT (N''),
        NUMERO_ERRO   INT            NOT NULL CONSTRAINT DF_Log_Erro_NUMERO_ERRO DEFAULT (0),
        MENSAGEM      NVARCHAR(4000) NOT NULL CONSTRAINT DF_Log_Erro_MENSAGEM    DEFAULT (N''),
        LINHA         INT            NOT NULL CONSTRAINT DF_Log_Erro_LINHA       DEFAULT (0),
        ORIGEM        VARCHAR(10)    NOT NULL CONSTRAINT DF_Log_Erro_ORIGEM      DEFAULT ('SQL'),
        USUARIO       NVARCHAR(100)  NOT NULL CONSTRAINT DF_Log_Erro_USUARIO     DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        ESTACAO       NVARCHAR(128)  NOT NULL CONSTRAINT DF_Log_Erro_ESTACAO     DEFAULT (ISNULL(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'ESTACAO')), ISNULL(HOST_NAME(), N''))),
        DETALHE       NVARCHAR(MAX)  NULL,
        DT_ERRO       DATETIME2(0)   NOT NULL CONSTRAINT DF_Log_Erro_DT_ERRO     DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Log_Erro        PRIMARY KEY CLUSTERED (ID_LOG_ERRO),
        CONSTRAINT CK_Log_Erro_ORIGEM CHECK (ORIGEM IN ('SQL', 'API', 'SERVICO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Log_Erro]') AND i.name = N'IX_Log_Erro_DT_ERRO')
    CREATE NONCLUSTERED INDEX IX_Log_Erro_DT_ERRO ON [SIS].[Log_Erro] (DT_ERRO) INCLUDE (ORIGEM, ROTINA);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Log_Passo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Log_Passo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Rastreamento passo a passo de rotinas críticas (PADRAO_SQL
                regra 47): retorno bancário, remessa, geração de parcelas.
                Cada execução tem um RUN_ID. Limpo por SIS_Log_Limpar_Processar
                conforme o parâmetro LOG_PASSO_DIAS_RETENCAO.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Log_Passo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Log_Passo]
    (
        ID_LOG_PASSO  BIGINT            IDENTITY(1,1) NOT NULL,
        RUN_ID        UNIQUEIDENTIFIER  NOT NULL,
        ROTINA        NVARCHAR(256)     NOT NULL CONSTRAINT DF_Log_Passo_ROTINA   DEFAULT (N''),
        ETAPA         NVARCHAR(200)     NOT NULL CONSTRAINT DF_Log_Passo_ETAPA    DEFAULT (N''),
        STATUS        VARCHAR(10)       NOT NULL CONSTRAINT DF_Log_Passo_STATUS   DEFAULT ('OK'),
        DETALHE       NVARCHAR(4000)    NOT NULL CONSTRAINT DF_Log_Passo_DETALHE  DEFAULT (N''),
        DT_PASSO      DATETIME2(0)      NOT NULL CONSTRAINT DF_Log_Passo_DT_PASSO DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Log_Passo        PRIMARY KEY CLUSTERED (ID_LOG_PASSO),
        CONSTRAINT CK_Log_Passo_STATUS CHECK (STATUS IN ('INICIO', 'OK', 'AVISO', 'ERRO', 'FIM'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Log_Passo]') AND i.name = N'IX_Log_Passo_RUN_ID')
    CREATE NONCLUSTERED INDEX IX_Log_Passo_RUN_ID ON [SIS].[Log_Passo] (RUN_ID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Log_Passo]') AND i.name = N'IX_Log_Passo_DT_PASSO')
    CREATE NONCLUSTERED INDEX IX_Log_Passo_DT_PASSO ON [SIS].[Log_Passo] (DT_PASSO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Parametro.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros do sistema (seção 3.4 do CLAUDE.md, PADRAO_SQL
                regra 33): nada de valor de negócio fixo no código.
                - CHAVE: maiúsculas, dígitos e "_", no formato MODULO_ASSUNTO.
                - VALOR: sempre gravado no formato canônico do TIPO
                  (INTEIRO "15", DECIMAL "2.5" com ponto, DATA "2026-11-15",
                  SN "S"/"N", EMAIL um endereço só, ARQUIVO nome do arquivo
                  sem pasta (ex.: logo.png; a pasta vem de outro parâmetro),
                  COR "#RRGGBB"; vazio = não configurado).
                - VALOR_PADRAO: valor de fábrica, para "restaurar padrão".
                - EDITAVEL_ADMIN = 0: só o instalador altera (por script).
                A auditoria (antes/depois) entra com a trigger da etapa 02c.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Tipos ARQUIVO e COR (identidade visual por cliente:
                        logomarca e cores sem mexer no sistema).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Parametro]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Parametro]
    (
        ID_PARAMETRO       INT            IDENTITY(1,1) NOT NULL,
        CHAVE              VARCHAR(60)    NOT NULL,
        VALOR              NVARCHAR(4000) NOT NULL CONSTRAINT DF_Parametro_VALOR           DEFAULT (N''),
        VALOR_PADRAO       NVARCHAR(4000) NOT NULL CONSTRAINT DF_Parametro_VALOR_PADRAO    DEFAULT (N''),
        TIPO               VARCHAR(10)    NOT NULL CONSTRAINT DF_Parametro_TIPO            DEFAULT ('TEXTO'),
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Parametro_DESCRICAO       DEFAULT (N''),
        ID_MODULO          INT            NOT NULL,
        EDITAVEL_ADMIN     BIT            NOT NULL CONSTRAINT DF_Parametro_EDITAVEL_ADMIN  DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Parametro_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Parametro_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Parametro        PRIMARY KEY CLUSTERED (ID_PARAMETRO),
        CONSTRAINT UQ_Parametro_CHAVE  UNIQUE (CHAVE),
        CONSTRAINT FK_Parametro_Modulo FOREIGN KEY (ID_MODULO) REFERENCES [SIS].[Modulo] (ID_MODULO),
        CONSTRAINT CK_Parametro_CHAVE  CHECK (CHAVE <> '' AND CHAVE NOT LIKE '%[^A-Z0-9_]%'),
        CONSTRAINT CK_Parametro_TIPO   CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'SN', 'EMAIL', 'ARQUIVO', 'COR'))
    );
END;
GO

-- Ajuste de banco criado com a v1.0 (CHECK sem ARQUIVO e COR)
IF EXISTS (SELECT 1 FROM sys.check_constraints c
           WHERE c.name = N'CK_Parametro_TIPO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Parametro]')
             AND c.definition NOT LIKE N'%ARQUIVO%')
BEGIN
    ALTER TABLE [SIS].[Parametro] DROP CONSTRAINT CK_Parametro_TIPO;
    ALTER TABLE [SIS].[Parametro] ADD CONSTRAINT CK_Parametro_TIPO CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'SN', 'EMAIL', 'ARQUIVO', 'COR'));
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Parametro]') AND i.name = N'IX_Parametro_ID_MODULO')
    CREATE NONCLUSTERED INDEX IX_Parametro_ID_MODULO ON [SIS].[Parametro] (ID_MODULO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Licenca.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Licenca]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Licença de uso (seção 3.5 do CLAUDE.md). Guarda a chave
                assinada pelo desenvolvedor exatamente como foi recebida
                (CHAVE_LICENCA) e uma cópia legível do que ela libera.
                QUEM CONFERE A ASSINATURA É A API (o SQL não verifica
                assinatura digital); a API só grava por SIS_Licenca_Gravar
                depois de validar a chave, e confere de novo a cada início e
                login. Só uma licença ativa por vez (índice único filtrado);
                as anteriores ficam guardadas, inativas.
                MODULOS: códigos liberados separados por vírgula (ex.: CAD,FIN).
                Empresas (CNPJ/razão social): SIS.Licenca_Empresa.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Licenca]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Licenca]
    (
        ID_LICENCA         INT            IDENTITY(1,1) NOT NULL,
        CHAVE_LICENCA      NVARCHAR(MAX)  NOT NULL,
        ID_SERVIDOR        VARCHAR(200)   NOT NULL CONSTRAINT DF_Licenca_ID_SERVIDOR     DEFAULT (''),
        DT_EMISSAO         DATE           NOT NULL,
        DT_VALIDADE        DATE           NULL,
        MODULOS            VARCHAR(400)   NOT NULL CONSTRAINT DF_Licenca_MODULOS         DEFAULT (''),
        ATIVA              BIT            NOT NULL CONSTRAINT DF_Licenca_ATIVA           DEFAULT (1),
        DT_DESATIVACAO     DATETIME2(0)   NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Licenca_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Licenca_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Licenca          PRIMARY KEY CLUSTERED (ID_LICENCA),
        CONSTRAINT CK_Licenca_VALIDADE CHECK (DT_VALIDADE IS NULL OR DT_VALIDADE >= DT_EMISSAO)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Licenca]') AND i.name = N'UQ_Licenca_ATIVA')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Licenca_ATIVA ON [SIS].[Licenca] (ATIVA) WHERE ATIVA = 1;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Licenca_Empresa.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Licenca_Empresa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Empresas (CNPJ e razão social) liberadas por uma licença:
                uma ou mais (CMJ e eventuais SPEs). A marcada como PRINCIPAL
                é a que aparece nos rodapés de e-mail e relatórios quando a
                rotina não é de uma empresa específica.
                Ninguém altera por tela: vem da chave assinada.
                CNPJ: 14 posições, só dígitos e letras maiúsculas (aceita o
                CNPJ alfanumérico).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Licenca_Empresa]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Licenca_Empresa]
    (
        ID_LICENCA_EMPRESA INT            IDENTITY(1,1) NOT NULL,
        ID_LICENCA         INT            NOT NULL,
        CNPJ               VARCHAR(14)    NOT NULL,
        RAZAO_SOCIAL       NVARCHAR(150)  NOT NULL,
        NOME_FANTASIA      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Licenca_Empresa_NOME_FANTASIA   DEFAULT (N''),
        PRINCIPAL          BIT            NOT NULL CONSTRAINT DF_Licenca_Empresa_PRINCIPAL       DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Licenca_Empresa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Licenca_Empresa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Licenca_Empresa         PRIMARY KEY CLUSTERED (ID_LICENCA_EMPRESA),
        CONSTRAINT FK_Licenca_Empresa_Licenca FOREIGN KEY (ID_LICENCA) REFERENCES [SIS].[Licenca] (ID_LICENCA),
        CONSTRAINT UQ_Licenca_Empresa_CNPJ    UNIQUE (ID_LICENCA, CNPJ),
        CONSTRAINT CK_Licenca_Empresa_CNPJ    CHECK (LEN(CNPJ) = 14 AND CNPJ NOT LIKE '%[^0-9A-Z]%')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Licenca_Empresa]') AND i.name = N'UQ_Licenca_Empresa_PRINCIPAL')
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Licenca_Empresa_PRINCIPAL ON [SIS].[Licenca_Empresa] (ID_LICENCA) WHERE PRINCIPAL = 1;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Item.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Item]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Itens do menu de cada módulo (seção 3.6 e menu lateral em
                drill-down, seção 3 item 8):
                  TIPO = 'MENU' : agrupador (abre subníveis), sem tela;
                  TIPO = 'TELA' : abre a página CAMINHO (relativo ao wwwroot).
                ID_ITEM_PAI: item agrupador acima (NULL = direto no módulo).
                CODIGO: único no banco, prefixado pelo módulo (ex.: SIS_USUARIO);
                é por ele que as procedures conferem a permissão.
                EXCLUSIVO_GERAL = 1: tela só do administrador geral (nível 2):
                não aparece para mais ninguém e não pode ser dada a perfil nem
                a usuário (ex.: Licença, Parâmetros).
                HABILITADO (só para TELA): liberada para uso pelo administrador
                geral (tela "Módulos e telas"); tela nova nasce desabilitada.
                Agrupadores (MENU) não usam a chave: aparecem se tiverem tela
                visível dentro.
                TABELAS_DA_TELA: tabelas cujos registros a tela mantém
                ("SIS.Usuario,SIS.Usuario_Permissao"); define de quais tabelas
                a tela mostra o Histórico (auditoria) e os anexos.
                Itens e ações são criados só por carga (script), nunca por tela.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - EXCLUSIVO_GERAL (dois níveis de administrador).
    v1.2 (16/11/2026) - HABILITADO (pedido 5) e TABELAS_DA_TELA (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Item]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Item]
    (
        ID_ITEM            INT            IDENTITY(1,1) NOT NULL,
        ID_MODULO          INT            NOT NULL,
        ID_ITEM_PAI        INT            NULL,
        CODIGO             VARCHAR(40)    NOT NULL,
        NOME               NVARCHAR(80)   NOT NULL,
        TIPO               VARCHAR(10)    NOT NULL CONSTRAINT DF_Item_TIPO            DEFAULT ('TELA'),
        CAMINHO            VARCHAR(200)   NOT NULL CONSTRAINT DF_Item_CAMINHO         DEFAULT (''),
        ICONE              VARCHAR(40)    NOT NULL CONSTRAINT DF_Item_ICONE           DEFAULT (''),
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Item_ORDEM           DEFAULT (0),
        EXCLUSIVO_GERAL    BIT            NOT NULL CONSTRAINT DF_Item_EXCLUSIVO_GERAL DEFAULT (0),
        HABILITADO         BIT            NOT NULL CONSTRAINT DF_Item_HABILITADO      DEFAULT (0),
        TABELAS_DA_TELA    VARCHAR(500)   NOT NULL CONSTRAINT DF_Item_TABELAS_DA_TELA DEFAULT (''),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Item_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Item_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Item_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Item         PRIMARY KEY CLUSTERED (ID_ITEM),
        CONSTRAINT UQ_Item_CODIGO  UNIQUE (CODIGO),
        CONSTRAINT FK_Item_Modulo  FOREIGN KEY (ID_MODULO)   REFERENCES [SIS].[Modulo] (ID_MODULO),
        CONSTRAINT FK_Item_Item    FOREIGN KEY (ID_ITEM_PAI) REFERENCES [SIS].[Item] (ID_ITEM),
        CONSTRAINT CK_Item_TIPO    CHECK (TIPO IN ('MENU', 'TELA')),
        CONSTRAINT CK_Item_CODIGO  CHECK (CODIGO <> '' AND CODIGO NOT LIKE '%[^A-Z0-9_]%'),
        CONSTRAINT CK_Item_PAI     CHECK (ID_ITEM_PAI IS NULL OR ID_ITEM_PAI <> ID_ITEM)
    );
END;
GO

IF COL_LENGTH(N'SIS.Item', N'EXCLUSIVO_GERAL') IS NULL
    ALTER TABLE [SIS].[Item] ADD EXCLUSIVO_GERAL BIT NOT NULL CONSTRAINT DF_Item_EXCLUSIVO_GERAL DEFAULT (0);
GO

-- Ajuste de banco criado antes da v1.2: as telas que já existiam continuam habilitadas
IF COL_LENGTH(N'SIS.Item', N'HABILITADO') IS NULL
BEGIN
    ALTER TABLE [SIS].[Item] ADD HABILITADO BIT NOT NULL CONSTRAINT DF_Item_HABILITADO DEFAULT (0);
    EXEC (N'UPDATE i SET i.HABILITADO = 1 FROM SIS.Item i;');
END;
GO

IF COL_LENGTH(N'SIS.Item', N'TABELAS_DA_TELA') IS NULL
    ALTER TABLE [SIS].[Item] ADD TABELAS_DA_TELA VARCHAR(500) NOT NULL CONSTRAINT DF_Item_TABELAS_DA_TELA DEFAULT ('');
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Item]') AND i.name = N'IX_Item_ID_MODULO')
    CREATE NONCLUSTERED INDEX IX_Item_ID_MODULO ON [SIS].[Item] (ID_MODULO, ID_ITEM_PAI);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Acao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Ações que podem ser permitidas numa tela (seção 3.6): VER,
                INCLUIR, ALTERAR, EXCLUIR e as especiais (BAIXAR, ESTORNAR,
                REABRIR...). Quais ações cada tela tem: SIS.Item_Acao.
                Criadas só por carga.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Acao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Acao]
    (
        ID_ACAO            INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(20)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Acao_ORDEM           DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Acao_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Acao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Acao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Acao        PRIMARY KEY CLUSTERED (ID_ACAO),
        CONSTRAINT UQ_Acao_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Acao_CODIGO CHECK (CODIGO <> '' AND CODIGO NOT LIKE '%[^A-Z_]%')
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Item_Acao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Item_Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Quais ações existem em cada tela (ex.: "Títulos a pagar" tem
                BAIXAR e ESTORNAR; "Clientes" não). É sobre estas linhas que
                as permissões de perfil e de usuário são dadas.
                Criadas só por carga.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Item_Acao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Item_Acao]
    (
        ID_ITEM_ACAO       INT            IDENTITY(1,1) NOT NULL,
        ID_ITEM            INT            NOT NULL,
        ID_ACAO            INT            NOT NULL,
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Item_Acao_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Item_Acao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Item_Acao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Item_Acao      PRIMARY KEY CLUSTERED (ID_ITEM_ACAO),
        CONSTRAINT UQ_Item_Acao      UNIQUE (ID_ITEM, ID_ACAO),
        CONSTRAINT FK_Item_Acao_Item FOREIGN KEY (ID_ITEM) REFERENCES [SIS].[Item] (ID_ITEM),
        CONSTRAINT FK_Item_Acao_Acao FOREIGN KEY (ID_ACAO) REFERENCES [SIS].[Acao] (ID_ACAO)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Perfil.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Perfil]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Perfis de acesso (Financeiro, Vendas, Consulta...), criados
                pelo administrador da CMJ.
                NIVEL_ADMIN (dois níveis de administrador, pedido do Celso):
                  0 = perfil comum: só o que for marcado;
                  1 = Administrador (da CMJ): todas as ações de todos os
                      módulos liberados, inclusive telas novas, MENOS as telas
                      exclusivas do administrador geral (Item.EXCLUSIVO_GERAL:
                      Licença e Parâmetros);
                  2 = Administrador geral (o criador do sistema): tudo.
                Perfis e usuários de nível 2 ficam invisíveis para quem não é
                nível 2. Só a carga cria os perfis de administrador; a tela não
                muda o nível.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - ADMINISTRADOR (BIT) vira NIVEL_ADMIN (0/1/2). Bloco de
                        ajuste converte um banco criado com a v1.0.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Perfil]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Perfil]
    (
        ID_PERFIL          INT            IDENTITY(1,1) NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Perfil_DESCRICAO       DEFAULT (N''),
        NIVEL_ADMIN        TINYINT        NOT NULL CONSTRAINT DF_Perfil_NIVEL_ADMIN     DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Perfil_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Perfil_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Perfil_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Perfil      PRIMARY KEY CLUSTERED (ID_PERFIL),
        CONSTRAINT UQ_Perfil_NOME UNIQUE (NOME),
        CONSTRAINT CK_Perfil_NOME CHECK (NOME <> N''),
        CONSTRAINT CK_Perfil_NIVEL_ADMIN CHECK (NIVEL_ADMIN IN (0, 1, 2))
    );
END;
GO

-- Ajuste de banco criado com a v1.0 (coluna ADMINISTRADOR BIT)
IF COL_LENGTH(N'SIS.Perfil', N'NIVEL_ADMIN') IS NULL
    ALTER TABLE [SIS].[Perfil] ADD NIVEL_ADMIN TINYINT NOT NULL CONSTRAINT DF_Perfil_NIVEL_ADMIN DEFAULT (0);
GO

IF COL_LENGTH(N'SIS.Perfil', N'ADMINISTRADOR') IS NOT NULL
BEGIN
    EXEC (N'UPDATE p SET p.NIVEL_ADMIN = 1 FROM SIS.Perfil p WHERE p.ADMINISTRADOR = 1 AND p.NIVEL_ADMIN = 0;');
    IF OBJECT_ID(N'[SIS].[DF_Perfil_ADMINISTRADOR]', N'D') IS NOT NULL
        ALTER TABLE [SIS].[Perfil] DROP CONSTRAINT DF_Perfil_ADMINISTRADOR;
    ALTER TABLE [SIS].[Perfil] DROP COLUMN ADMINISTRADOR;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints c WHERE c.name = N'CK_Perfil_NIVEL_ADMIN' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Perfil]'))
    ALTER TABLE [SIS].[Perfil] ADD CONSTRAINT CK_Perfil_NIVEL_ADMIN CHECK (NIVEL_ADMIN IN (0, 1, 2));
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Perfil_Permissao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Perfil_Permissao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Ações permitidas a cada perfil. Linha existe = permitido.
                Tirar a permissão apaga a linha (é configuração, não
                movimento; a auditoria da etapa 02c registra quem tirou).
                Perfil de administrador (NIVEL_ADMIN 1 ou 2) não usa esta tabela.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Perfil_Permissao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Perfil_Permissao]
    (
        ID_PERFIL_PERMISSAO INT            IDENTITY(1,1) NOT NULL,
        ID_PERFIL           INT            NOT NULL,
        ID_ITEM_ACAO        INT            NOT NULL,
        DT_CRIACAO          DATETIME2(0)   NOT NULL CONSTRAINT DF_Perfil_Permissao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Perfil_Permissao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO        DATETIME2(0)   NULL,
        USUARIO_ALTERACAO   NVARCHAR(100)  NULL,
        CONSTRAINT PK_Perfil_Permissao           PRIMARY KEY CLUSTERED (ID_PERFIL_PERMISSAO),
        CONSTRAINT UQ_Perfil_Permissao           UNIQUE (ID_PERFIL, ID_ITEM_ACAO),
        CONSTRAINT FK_Perfil_Permissao_Perfil    FOREIGN KEY (ID_PERFIL)    REFERENCES [SIS].[Perfil] (ID_PERFIL),
        CONSTRAINT FK_Perfil_Permissao_Item_Acao FOREIGN KEY (ID_ITEM_ACAO) REFERENCES [SIS].[Item_Acao] (ID_ITEM_ACAO)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Usuario.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Usuario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Usuários do sistema (seção 3.6).
                SENHA: o banco NUNCA recebe a senha. A API calcula o hash
                PBKDF2-SHA256 (salt aleatório por usuário, iterações do
                parâmetro SENHA_PBKDF2_ITERACOES) e grava hash + salt +
                iterações + algoritmo por SIS_Usuario_Senha_Gravar. No login a
                API lê esses dados (SIS_Usuario_Login_Obter), confere a senha
                digitada e informa o resultado (SIS_Usuario_Login_Processar).
                SENHA_HASH NULL = senha ainda não definida (não entra).
                TROCAR_SENHA = 1: obriga a trocar no próximo acesso.
                INTERNO = 1: usuário técnico SISTEMA (rotinas automáticas e
                migração); nunca faz login.
                Usuário não é apagado: desativa (ATIVO = 0).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Correção do CK_Usuario_LOGIN: login com "_" era
                        recusado; ajuste recria a restrição em banco já criado.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Usuario]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Usuario]
    (
        ID_USUARIO          INT             IDENTITY(1,1) NOT NULL,
        LOGIN               VARCHAR(40)     NOT NULL,
        NOME                NVARCHAR(100)   NOT NULL,
        EMAIL               NVARCHAR(200)   NOT NULL CONSTRAINT DF_Usuario_EMAIL              DEFAULT (N''),
        ID_PERFIL           INT             NOT NULL,
        SENHA_HASH          VARBINARY(64)   NULL,
        SENHA_SALT          VARBINARY(64)   NULL,
        SENHA_ITERACOES     INT             NOT NULL CONSTRAINT DF_Usuario_SENHA_ITERACOES    DEFAULT (0),
        SENHA_ALGORITMO     VARCHAR(30)     NOT NULL CONSTRAINT DF_Usuario_SENHA_ALGORITMO    DEFAULT (''),
        DT_SENHA            DATETIME2(0)    NULL,
        TROCAR_SENHA        BIT             NOT NULL CONSTRAINT DF_Usuario_TROCAR_SENHA       DEFAULT (1),
        TENTATIVAS_ERRADAS  SMALLINT        NOT NULL CONSTRAINT DF_Usuario_TENTATIVAS_ERRADAS DEFAULT (0),
        BLOQUEADO           BIT             NOT NULL CONSTRAINT DF_Usuario_BLOQUEADO          DEFAULT (0),
        DT_BLOQUEIO         DATETIME2(0)    NULL,
        DT_ULTIMO_LOGIN     DATETIME2(0)    NULL,
        INTERNO             BIT             NOT NULL CONSTRAINT DF_Usuario_INTERNO            DEFAULT (0),
        ATIVO               BIT             NOT NULL CONSTRAINT DF_Usuario_ATIVO              DEFAULT (1),
        DT_CRIACAO          DATETIME2(0)    NOT NULL CONSTRAINT DF_Usuario_DT_CRIACAO         DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO     NVARCHAR(100)   NOT NULL CONSTRAINT DF_Usuario_USUARIO_CRIACAO    DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO        DATETIME2(0)    NULL,
        USUARIO_ALTERACAO   NVARCHAR(100)   NULL,
        CONSTRAINT PK_Usuario        PRIMARY KEY CLUSTERED (ID_USUARIO),
        CONSTRAINT UQ_Usuario_LOGIN  UNIQUE (LOGIN),
        CONSTRAINT FK_Usuario_Perfil FOREIGN KEY (ID_PERFIL) REFERENCES [SIS].[Perfil] (ID_PERFIL),
        CONSTRAINT CK_Usuario_LOGIN  CHECK (LEN(LOGIN) >= 3 AND REPLACE(REPLACE(REPLACE(LOGIN, '.', ''), '_', ''), '-', '') NOT LIKE '%[^a-z0-9]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Usuario_NOME   CHECK (NOME <> N'')
    );
END;
GO

-- Ajuste de banco criado com a v1.0 (CK_Usuario_LOGIN com o padrão defeituoso)
IF EXISTS (SELECT 1 FROM sys.check_constraints c
           WHERE c.name = N'CK_Usuario_LOGIN' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Usuario]')
             AND c.definition NOT LIKE N'%replace%')
BEGIN
    ALTER TABLE [SIS].[Usuario] DROP CONSTRAINT CK_Usuario_LOGIN;
    ALTER TABLE [SIS].[Usuario] ADD CONSTRAINT CK_Usuario_LOGIN
        CHECK (LEN(LOGIN) >= 3 AND REPLACE(REPLACE(REPLACE(LOGIN, '.', ''), '_', ''), '-', '') NOT LIKE '%[^a-z0-9]%' COLLATE Latin1_General_BIN2);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Usuario]') AND i.name = N'IX_Usuario_ID_PERFIL')
    CREATE NONCLUSTERED INDEX IX_Usuario_ID_PERFIL ON [SIS].[Usuario] (ID_PERFIL);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Usuario_Permissao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Usuario_Permissao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Exceções individuais em relação ao perfil do usuário:
                  TIPO = 'C' concede uma ação que o perfil não tem;
                  TIPO = 'R' retira uma ação que o perfil tem.
                Sem linha = vale o perfil. Retirada não se aplica a usuário de
                perfil de administrador (para ninguém trancar o administrador).
                Tela EXCLUSIVO_GERAL nunca entra aqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Usuario_Permissao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Usuario_Permissao]
    (
        ID_USUARIO_PERMISSAO INT            IDENTITY(1,1) NOT NULL,
        ID_USUARIO           INT            NOT NULL,
        ID_ITEM_ACAO         INT            NOT NULL,
        TIPO                 CHAR(1)        NOT NULL,
        DT_CRIACAO           DATETIME2(0)   NOT NULL CONSTRAINT DF_Usuario_Permissao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Usuario_Permissao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)   NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)  NULL,
        CONSTRAINT PK_Usuario_Permissao           PRIMARY KEY CLUSTERED (ID_USUARIO_PERMISSAO),
        CONSTRAINT UQ_Usuario_Permissao           UNIQUE (ID_USUARIO, ID_ITEM_ACAO),
        CONSTRAINT FK_Usuario_Permissao_Usuario   FOREIGN KEY (ID_USUARIO)   REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT FK_Usuario_Permissao_Item_Acao FOREIGN KEY (ID_ITEM_ACAO) REFERENCES [SIS].[Item_Acao] (ID_ITEM_ACAO),
        CONSTRAINT CK_Usuario_Permissao_TIPO      CHECK (TIPO IN ('C', 'R'))
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Sessao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Sessao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Sessões de uso (login até logout/expiração).
                TOKEN_HASH: a API gera um token aleatório (32 bytes) que fica
                só no cookie do navegador; o banco guarda apenas o SHA-256
                dele. Quem ler a tabela não consegue usar a sessão de outro.
                DT_FIM preenchida = sessão encerrada; MOTIVO_FIM diz por quê.
                A expiração por inatividade usa SESSAO_MINUTOS_INATIVIDADE.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Sessao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Sessao]
    (
        ID_SESSAO          BIGINT          IDENTITY(1,1) NOT NULL,
        ID_USUARIO         INT             NOT NULL,
        TOKEN_HASH         VARBINARY(32)   NOT NULL,
        DT_LOGIN           DATETIME2(0)    NOT NULL CONSTRAINT DF_Sessao_DT_LOGIN         DEFAULT (SYSDATETIME()),
        DT_ULTIMO_ACESSO   DATETIME2(0)    NOT NULL CONSTRAINT DF_Sessao_DT_ULTIMO_ACESSO DEFAULT (SYSDATETIME()),
        DT_FIM             DATETIME2(0)    NULL,
        MOTIVO_FIM         VARCHAR(20)     NOT NULL CONSTRAINT DF_Sessao_MOTIVO_FIM       DEFAULT (''),
        IP                 VARCHAR(45)     NOT NULL CONSTRAINT DF_Sessao_IP               DEFAULT (''),
        ESTACAO            NVARCHAR(128)   NOT NULL CONSTRAINT DF_Sessao_ESTACAO          DEFAULT (N''),
        NAVEGADOR          NVARCHAR(300)   NOT NULL CONSTRAINT DF_Sessao_NAVEGADOR        DEFAULT (N''),
        CONSTRAINT PK_Sessao            PRIMARY KEY CLUSTERED (ID_SESSAO),
        CONSTRAINT UQ_Sessao_TOKEN_HASH UNIQUE (TOKEN_HASH),
        CONSTRAINT FK_Sessao_Usuario    FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Sessao_TOKEN_HASH CHECK (DATALENGTH(TOKEN_HASH) = 32),
        CONSTRAINT CK_Sessao_MOTIVO_FIM CHECK (MOTIVO_FIM IN ('', 'LOGOUT', 'EXPIRADA', 'BLOQUEIO', 'INATIVADO', 'SENHA_ALTERADA', 'ADMIN'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Sessao]') AND i.name = N'IX_Sessao_ID_USUARIO_ABERTA')
    CREATE NONCLUSTERED INDEX IX_Sessao_ID_USUARIO_ABERTA ON [SIS].[Sessao] (ID_USUARIO) WHERE DT_FIM IS NULL;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Login_Log.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Login_Log]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Toda tentativa de login, certa ou errada (seção 3.6).
                RESULTADO: OK, SENHA_ERRADA, BLOQUEOU (errou e foi bloqueado
                nesta tentativa), BLOQUEADO (já estava), INATIVO, SEM_SENHA,
                INEXISTENTE, ESTACAO_BLOQUEADA (o computador errou demais
                em pouco tempo e está em espera). LOGIN_INFORMADO guarda o que foi digitado
                (para ver tentativas com nomes que não existem).
                Nunca é apagado.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (20/11/2026) - Etapa 03d: resultado ESTACAO_BLOQUEADA (limite de
                        tentativas por computador) e índice por IP e data.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Login_Log]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Login_Log]
    (
        ID_LOGIN_LOG     BIGINT          IDENTITY(1,1) NOT NULL,
        LOGIN_INFORMADO  NVARCHAR(100)   NOT NULL CONSTRAINT DF_Login_Log_LOGIN_INFORMADO DEFAULT (N''),
        ID_USUARIO       INT             NULL,
        RESULTADO        VARCHAR(20)     NOT NULL,
        IP               VARCHAR(45)     NOT NULL CONSTRAINT DF_Login_Log_IP              DEFAULT (''),
        ESTACAO          NVARCHAR(128)   NOT NULL CONSTRAINT DF_Login_Log_ESTACAO         DEFAULT (N''),
        DT_TENTATIVA     DATETIME2(0)    NOT NULL CONSTRAINT DF_Login_Log_DT_TENTATIVA    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Login_Log           PRIMARY KEY CLUSTERED (ID_LOGIN_LOG),
        CONSTRAINT FK_Login_Log_Usuario   FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Login_Log_RESULTADO CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE', 'ESTACAO_BLOQUEADA'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_DT_TENTATIVA')
    CREATE NONCLUSTERED INDEX IX_Login_Log_DT_TENTATIVA ON [SIS].[Login_Log] (DT_TENTATIVA) INCLUDE (ID_USUARIO, RESULTADO);
GO

-- v1.1: novo resultado ESTACAO_BLOQUEADA (troca a restrição só se ainda não aceita)
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints c
               WHERE c.name = N'CK_Login_Log_RESULTADO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Login_Log]')
                 AND c.definition LIKE N'%ESTACAO_BLOQUEADA%')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.check_constraints c WHERE c.name = N'CK_Login_Log_RESULTADO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Login_Log]'))
        ALTER TABLE [SIS].[Login_Log] DROP CONSTRAINT CK_Login_Log_RESULTADO;
    ALTER TABLE [SIS].[Login_Log] ADD CONSTRAINT CK_Login_Log_RESULTADO
        CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE', 'ESTACAO_BLOQUEADA'));
END;
GO

-- v1.1: contagem de tentativas erradas por computador (SIS_Usuario_Login_Processar)
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_IP_DT')
    CREATE NONCLUSTERED INDEX IX_Login_Log_IP_DT ON [SIS].[Login_Log] (IP, DT_TENTATIVA) INCLUDE (RESULTADO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Auditoria.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Lote.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Lote]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Número de lote de tudo que é gerado junto (seção 3.1 item 2 e
                pedido 9): uma venda que gera 30 parcelas = 1 lote; um retorno
                bancário, uma importação de extrato, uma medição aprovada...
                O número do lote é o próprio ID_LOTE (mostrado ao usuário).
                Os registros gerados guardam ID_LOTE; a auditoria também
                (SESSION_CONTEXT 'ID_LOTE'). Lote não é apagado: o processo que
                desfaz um lote marca SITUACAO = 'CANCELADO'.
                ORIGEM: código do processo (VENDA_PARCELAS, ACORDO, RECORRENTE,
                OFX, RETORNO_SICREDI, MEDICAO, MIGRACAO, TESTE...).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Lote]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Lote]
    (
        ID_LOTE            BIGINT         IDENTITY(1,1) NOT NULL,
        ORIGEM             VARCHAR(30)    NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Lote_DESCRICAO         DEFAULT (N''),
        TABELA_REFERENCIA  NVARCHAR(256)  NOT NULL CONSTRAINT DF_Lote_TABELA_REFERENCIA DEFAULT (N''),
        ID_REFERENCIA      BIGINT         NULL,
        QTD_REGISTROS      INT            NOT NULL CONSTRAINT DF_Lote_QTD_REGISTROS     DEFAULT (0),
        SITUACAO           VARCHAR(10)    NOT NULL CONSTRAINT DF_Lote_SITUACAO          DEFAULT ('ATIVO'),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Lote_DT_CRIACAO        DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lote_USUARIO_CRIACAO   DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lote          PRIMARY KEY CLUSTERED (ID_LOTE),
        CONSTRAINT CK_Lote_ORIGEM   CHECK (ORIGEM <> '' AND REPLACE(ORIGEM, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Lote_SITUACAO CHECK (SITUACAO IN ('ATIVO', 'CANCELADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Lote]') AND i.name = N'IX_Lote_ORIGEM')
    CREATE NONCLUSTERED INDEX IX_Lote_ORIGEM ON [SIS].[Lote] (ORIGEM, DT_CRIACAO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Anexo_Tipo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Anexo_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tipos de anexo (contrato, nota fiscal, comprovante, acordo,
                boleto, logomarca, outro) e as extensões aceitas em cada um
                (EXTENSOES: lista separada por vírgula, minúsculas, sem ponto).
                Criados por carga; o administrador pode desativar.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Anexo_Tipo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Anexo_Tipo]
    (
        ID_ANEXO_TIPO      INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(30)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        EXTENSOES          VARCHAR(200)   NOT NULL CONSTRAINT DF_Anexo_Tipo_EXTENSOES       DEFAULT (''),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Anexo_Tipo_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Anexo_Tipo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Anexo_Tipo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Anexo_Tipo        PRIMARY KEY CLUSTERED (ID_ANEXO_TIPO),
        CONSTRAINT UQ_Anexo_Tipo_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Anexo_Tipo_CODIGO CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Anexo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Anexo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Anexos de qualquer registro (seção 3.1 item 6 e 3.2):
                lançamento, parcela, venda, contrato, cliente, obra (logomarca
                da obra)... O arquivo fica em disco, na pasta do parâmetro
                ANEXO_PASTA_RAIZ + PASTA_RELATIVA (ano\mês); o banco guarda só
                a referência.
                  TABELA_REFERENCIA + ID_REFERENCIA: de qual registro é
                  NOME_ORIGINAL : nome que o usuário enviou (para baixar)
                  NOME_ARQUIVO  : nome gerado pela API (GUID + extensão), sem
                                  acento e sem espaço (regra 51)
                  HASH_SHA256   : calculado pela API; impede anexar o mesmo
                                  arquivo duas vezes no mesmo registro
                Excluir = desativar (SITUACAO 'EXCLUIDO' + quem, quando e
                motivo); o arquivo continua em disco (regra 56).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Anexo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Anexo]
    (
        ID_ANEXO           BIGINT          IDENTITY(1,1) NOT NULL,
        TABELA_REFERENCIA  NVARCHAR(256)   NOT NULL,
        ID_REFERENCIA      BIGINT          NOT NULL,
        ID_ANEXO_TIPO      INT             NOT NULL,
        NOME_ORIGINAL      NVARCHAR(260)   NOT NULL,
        NOME_ARQUIVO       VARCHAR(100)    NOT NULL,
        PASTA_RELATIVA     VARCHAR(50)     NOT NULL CONSTRAINT DF_Anexo_PASTA_RELATIVA  DEFAULT (''),
        EXTENSAO           VARCHAR(10)     NOT NULL,
        TAMANHO_BYTES      BIGINT          NOT NULL,
        HASH_SHA256        VARBINARY(32)   NOT NULL,
        DESCRICAO          NVARCHAR(400)   NOT NULL CONSTRAINT DF_Anexo_DESCRICAO       DEFAULT (N''),
        SITUACAO           VARCHAR(10)     NOT NULL CONSTRAINT DF_Anexo_SITUACAO        DEFAULT ('ATIVO'),
        DT_EXCLUSAO        DATETIME2(0)    NULL,
        USUARIO_EXCLUSAO   NVARCHAR(100)   NULL,
        MOTIVO_EXCLUSAO    NVARCHAR(400)   NULL,
        DT_CRIACAO         DATETIME2(0)    NOT NULL CONSTRAINT DF_Anexo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)   NOT NULL CONSTRAINT DF_Anexo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)    NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)   NULL,
        CONSTRAINT PK_Anexo              PRIMARY KEY CLUSTERED (ID_ANEXO),
        CONSTRAINT UQ_Anexo_NOME_ARQUIVO UNIQUE (NOME_ARQUIVO),
        CONSTRAINT FK_Anexo_Anexo_Tipo   FOREIGN KEY (ID_ANEXO_TIPO) REFERENCES [SIS].[Anexo_Tipo] (ID_ANEXO_TIPO),
        CONSTRAINT CK_Anexo_SITUACAO     CHECK (SITUACAO IN ('ATIVO', 'EXCLUIDO')),
        CONSTRAINT CK_Anexo_TAMANHO      CHECK (TAMANHO_BYTES > 0),
        CONSTRAINT CK_Anexo_HASH         CHECK (DATALENGTH(HASH_SHA256) = 32)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Anexo]') AND i.name = N'IX_Anexo_REFERENCIA')
    CREATE NONCLUSTERED INDEX IX_Anexo_REFERENCIA ON [SIS].[Anexo] (TABELA_REFERENCIA, ID_REFERENCIA, SITUACAO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Grupo_Email.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Grupo_Email]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Grupos de destinatários dos e-mails do sistema (PADRAO_EMAIL
                regra 10): nenhum e-mail fica fixo no código; a rotina pede
                o grupo (ex.: FIN_PAGAR) e a function devolve os endereços.
                Um grupo pode misturar e-mails internos e externos.
                Os endereços ficam em SIS.Grupo_Email_Destinatario.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Grupo_Email]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Grupo_Email]
    (
        ID_GRUPO_EMAIL     INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(30)    NOT NULL,
        NOME               NVARCHAR(80)   NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Grupo_Email_DESCRICAO       DEFAULT (N''),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Grupo_Email_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Grupo_Email_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Grupo_Email        PRIMARY KEY CLUSTERED (ID_GRUPO_EMAIL),
        CONSTRAINT UQ_Grupo_Email_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Grupo_Email_CODIGO CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Grupo_Email_Destinatario.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Grupo_Email_Destinatario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Endereços de cada grupo de e-mail. O mesmo endereço não se
                repete no mesmo grupo. Mantidos pela tela "Grupos de e-mail"
                (SIS_Grupo_Email_Gravar).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Grupo_Email_Destinatario]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Grupo_Email_Destinatario]
    (
        ID_GRUPO_EMAIL_DESTINATARIO  INT            IDENTITY(1,1) NOT NULL,
        ID_GRUPO_EMAIL               INT            NOT NULL,
        EMAIL                        NVARCHAR(256)  NOT NULL,
        NOME                         NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_NOME            DEFAULT (N''),
        ATIVO                        BIT            NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_ATIVO           DEFAULT (1),
        DT_CRIACAO                   DATETIME2(0)   NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Grupo_Email_Destinatario_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO                 DATETIME2(0)   NULL,
        USUARIO_ALTERACAO            NVARCHAR(100)  NULL,
        CONSTRAINT PK_Grupo_Email_Destinatario       PRIMARY KEY CLUSTERED (ID_GRUPO_EMAIL_DESTINATARIO),
        CONSTRAINT UQ_Grupo_Email_Destinatario_EMAIL UNIQUE (ID_GRUPO_EMAIL, EMAIL),
        CONSTRAINT FK_Grupo_Email_Destinatario_Grupo FOREIGN KEY (ID_GRUPO_EMAIL) REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Email_Fila.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Email_Fila]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Fila de e-mails (PADRAO_EMAIL seção 1). As rotinas só gravam
                aqui (SIS_Email_Enfileirar); o serviço do sistema captura
                (SIS_Email_Capturar), envia por SMTP e grava o resultado
                (SIS_Email_Resultado_Gravar). Falha de envio nunca desfaz a
                operação de negócio.
                STATUS: PENDENTE > PROCESSANDO > ENVIADO | ERRO; CANCELADO
                pela tela.
                CHAVE_ORIGEM: impede o mesmo aviso duas vezes (ex.:
                'BOLETO:12345'); índice único só quando informada.
                ID_EMAIL numérico (aparece na tela); a idempotência fica na
                CHAVE_ORIGEM.
                CONTA: INTERNA (avisos da CMJ) ou EXTERNA (clientes e
                terceiros); o serviço escolhe a conta SMTP por ela.
                MODO_TESTE = 1: gravado no banco _LOCAL; PARA foi trocado pelo
                EMAIL_TESTE e o endereço pedido ficou em PARA_ORIGINAL.
                Anexos em SIS.Email_Fila_Anexo; histórico em SIS.Email_Log.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Fila]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Fila]
    (
        ID_EMAIL           BIGINT         IDENTITY(1,1) NOT NULL,
        CHAVE_ORIGEM       NVARCHAR(200)  NULL,
        TIPO               VARCHAR(30)    NOT NULL,
        CONTA              VARCHAR(10)    NOT NULL CONSTRAINT DF_Email_Fila_CONTA             DEFAULT ('INTERNA'),
        GRUPO              VARCHAR(30)    NOT NULL CONSTRAINT DF_Email_Fila_GRUPO             DEFAULT (''),
        PARA               NVARCHAR(2000) NOT NULL,
        CC                 NVARCHAR(2000) NOT NULL CONSTRAINT DF_Email_Fila_CC                DEFAULT (N''),
        CCO                NVARCHAR(2000) NOT NULL CONSTRAINT DF_Email_Fila_CCO               DEFAULT (N''),
        PARA_ORIGINAL      NVARCHAR(4000) NOT NULL CONSTRAINT DF_Email_Fila_PARA_ORIGINAL     DEFAULT (N''),
        ASSUNTO            NVARCHAR(400)  NOT NULL,
        CORPO_HTML         NVARCHAR(MAX)  NOT NULL,
        STATUS             VARCHAR(12)    NOT NULL CONSTRAINT DF_Email_Fila_STATUS            DEFAULT ('PENDENTE'),
        TENTATIVAS         INT            NOT NULL CONSTRAINT DF_Email_Fila_TENTATIVAS        DEFAULT (0),
        PROXIMA_TENTATIVA  DATETIME2(0)   NOT NULL CONSTRAINT DF_Email_Fila_PROXIMA_TENTATIVA DEFAULT (SYSDATETIME()),
        DT_CAPTURA         DATETIME2(0)   NULL,
        SERVIDOR           NVARCHAR(128)  NOT NULL CONSTRAINT DF_Email_Fila_SERVIDOR          DEFAULT (N''),
        DT_ENVIO           DATETIME2(0)   NULL,
        ULTIMO_ERRO        NVARCHAR(1000) NOT NULL CONSTRAINT DF_Email_Fila_ULTIMO_ERRO       DEFAULT (N''),
        ORIGEM             NVARCHAR(256)  NOT NULL CONSTRAINT DF_Email_Fila_ORIGEM            DEFAULT (N''),
        ID_LOTE            BIGINT         NULL,
        MODO_TESTE         BIT            NOT NULL CONSTRAINT DF_Email_Fila_MODO_TESTE        DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Email_Fila_DT_CRIACAO        DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Email_Fila_USUARIO_CRIACAO   DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Email_Fila        PRIMARY KEY CLUSTERED (ID_EMAIL),
        CONSTRAINT CK_Email_Fila_STATUS CHECK (STATUS IN ('PENDENTE', 'PROCESSANDO', 'ENVIADO', 'ERRO', 'CANCELADO')),
        CONSTRAINT CK_Email_Fila_CONTA  CHECK (CONTA IN ('INTERNA', 'EXTERNA')),
        CONSTRAINT CK_Email_Fila_TIPO   CHECK (TIPO <> '' AND REPLACE(TIPO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'UX_Email_Fila_CHAVE_ORIGEM')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Email_Fila_CHAVE_ORIGEM ON [SIS].[Email_Fila] (CHAVE_ORIGEM) WHERE CHAVE_ORIGEM IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'IX_Email_Fila_STATUS')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_STATUS ON [SIS].[Email_Fila] (STATUS, PROXIMA_TENTATIVA);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila]') AND i.name = N'IX_Email_Fila_DT_CRIACAO')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_DT_CRIACAO ON [SIS].[Email_Fila] (DT_CRIACAO) INCLUDE (STATUS, TIPO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Email_Fila_Anexo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Email_Fila_Anexo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Anexos de cada e-mail da fila (PADRAO_EMAIL regras 23 e 24):
                o arquivo fica em disco e aqui só o caminho. O serviço confere
                se o arquivo existe antes de enviar; se não existir, o e-mail
                vai para ERRO (nunca sai sem o anexo).
                NOME_EXIBICAO: nome que o destinatário vê (sem acento e sem
                espaço). CID preenchido = imagem embutida no corpo
                (<img src="cid:...">) em vez de anexo comum.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Fila_Anexo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Fila_Anexo]
    (
        ID_EMAIL_ANEXO  BIGINT          IDENTITY(1,1) NOT NULL,
        ID_EMAIL        BIGINT          NOT NULL,
        CAMINHO         NVARCHAR(1000)  NOT NULL,
        NOME_EXIBICAO   NVARCHAR(260)   NOT NULL,
        CID             VARCHAR(60)     NOT NULL CONSTRAINT DF_Email_Fila_Anexo_CID   DEFAULT (''),
        ORDEM           SMALLINT        NOT NULL CONSTRAINT DF_Email_Fila_Anexo_ORDEM DEFAULT (0),
        CONSTRAINT PK_Email_Fila_Anexo       PRIMARY KEY CLUSTERED (ID_EMAIL_ANEXO),
        CONSTRAINT FK_Email_Fila_Anexo_Email FOREIGN KEY (ID_EMAIL) REFERENCES [SIS].[Email_Fila] (ID_EMAIL),
        CONSTRAINT CK_Email_Fila_Anexo_CAMINHO CHECK (CAMINHO <> N'')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Fila_Anexo]') AND i.name = N'IX_Email_Fila_Anexo_ID_EMAIL')
    CREATE NONCLUSTERED INDEX IX_Email_Fila_Anexo_ID_EMAIL ON [SIS].[Email_Fila_Anexo] (ID_EMAIL, ORDEM);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Email_Log.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Email_Log]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico de cada e-mail da fila: cada tentativa de envio e
                cada ação da tela (reenviar, cancelar) ou da rotina que solta
                os presos. Não é apagado.
                RESULTADO: ENVIADO, ERRO_TEMPORARIO, ERRO_PERMANENTE,
                LIBERADO, REENVIO, CANCELADO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Email_Log]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Email_Log]
    (
        ID_EMAIL_LOG  BIGINT          IDENTITY(1,1) NOT NULL,
        ID_EMAIL      BIGINT          NOT NULL,
        TENTATIVA     INT             NOT NULL CONSTRAINT DF_Email_Log_TENTATIVA   DEFAULT (0),
        RESULTADO     VARCHAR(20)     NOT NULL,
        MENSAGEM      NVARCHAR(1000)  NOT NULL CONSTRAINT DF_Email_Log_MENSAGEM    DEFAULT (N''),
        SERVIDOR      NVARCHAR(128)   NOT NULL CONSTRAINT DF_Email_Log_SERVIDOR    DEFAULT (N''),
        USUARIO       NVARCHAR(100)   NOT NULL CONSTRAINT DF_Email_Log_USUARIO     DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_REGISTRO   DATETIME2(0)    NOT NULL CONSTRAINT DF_Email_Log_DT_REGISTRO DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Email_Log          PRIMARY KEY CLUSTERED (ID_EMAIL_LOG),
        CONSTRAINT FK_Email_Log_Email    FOREIGN KEY (ID_EMAIL) REFERENCES [SIS].[Email_Fila] (ID_EMAIL),
        CONSTRAINT CK_Email_Log_RESULTADO CHECK (RESULTADO IN ('ENVIADO', 'ERRO_TEMPORARIO', 'ERRO_PERMANENTE', 'LIBERADO', 'REENVIO', 'CANCELADO'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Email_Log]') AND i.name = N'IX_Email_Log_ID_EMAIL')
    CREATE NONCLUSTERED INDEX IX_Email_Log_ID_EMAIL ON [SIS].[Email_Log] (ID_EMAIL, ID_EMAIL_LOG);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Rotina.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Rotina_Execucao.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Comando.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Comando]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Catálogo dos comandos de instalação e manutenção (pedidos 2 e
                4 do Celso, 16/11/2026): cada linha vira um botão da tela
                "Instalação e manutenção", exclusiva do administrador geral.
                O SQL nunca executa comando do Windows: o botão grava um
                pedido em SIS.Comando_Fila e o serviço do sistema executa o
                que estiver na SUA lista fixa para aquele CODIGO (nada de
                texto de comando vindo do banco).
                PERIGOSO = 1: a API pede a senha de novo e uma confirmação
                antes de gravar o pedido.
                ACEITA_PARAMETRO = 1: o botão pede um valor (ex.: nome do
                arquivo do pacote), validado aqui e de novo pelo serviço.
                Cadastrado só por carga (Carga_SIS_Comando.sql).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comando]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comando]
    (
        ID_COMANDO           INT             IDENTITY(1,1) NOT NULL,
        CODIGO               VARCHAR(40)     NOT NULL,
        NOME                 NVARCHAR(80)    NOT NULL,
        DESCRICAO            NVARCHAR(1000)  NOT NULL CONSTRAINT DF_Comando_DESCRICAO           DEFAULT (N''),
        GRUPO                VARCHAR(20)     NOT NULL,
        ORDEM                SMALLINT        NOT NULL CONSTRAINT DF_Comando_ORDEM               DEFAULT (0),
        PERIGOSO             BIT             NOT NULL CONSTRAINT DF_Comando_PERIGOSO            DEFAULT (0),
        ACEITA_PARAMETRO     BIT             NOT NULL CONSTRAINT DF_Comando_ACEITA_PARAMETRO    DEFAULT (0),
        PARAMETRO_DESCRICAO  NVARCHAR(200)   NOT NULL CONSTRAINT DF_Comando_PARAMETRO_DESCRICAO DEFAULT (N''),
        ATIVO                BIT             NOT NULL CONSTRAINT DF_Comando_ATIVO               DEFAULT (1),
        DT_CRIACAO           DATETIME2(0)    NOT NULL CONSTRAINT DF_Comando_DT_CRIACAO          DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)   NOT NULL CONSTRAINT DF_Comando_USUARIO_CRIACAO     DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO         DATETIME2(0)    NULL,
        USUARIO_ALTERACAO    NVARCHAR(100)   NULL,
        CONSTRAINT PK_Comando        PRIMARY KEY CLUSTERED (ID_COMANDO),
        CONSTRAINT UQ_Comando_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Comando_CODIGO CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2),
        CONSTRAINT CK_Comando_GRUPO  CHECK (GRUPO IN ('INSTALACAO', 'ATUALIZACAO', 'BACKUP', 'SERVICO', 'DIAGNOSTICO'))
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Comando_Fila.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.Banco.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [BANCO].[Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Lista de bancos (código COMPE de 3 dígitos e ISPB de 8 dígitos,
                usado no PIX). Usada nas contas da empresa (BANCO.Conta) e nos dados
                bancários das pessoas (CAD.Pessoa_Dado_Bancario). Carga inicial com os
                principais bancos; o administrador acrescenta outros.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Banco]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Banco]
    (
        ID_BANCO           INT            IDENTITY(1,1) NOT NULL,
        CODIGO             CHAR(3)        NOT NULL,
        ISPB               VARCHAR(8)     NOT NULL CONSTRAINT DF_Banco_ISPB  DEFAULT (''),
        NOME               NVARCHAR(80)   NOT NULL,
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Banco_ATIVO DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Banco_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Banco_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Banco        PRIMARY KEY CLUSTERED (ID_BANCO),
        CONSTRAINT UQ_Banco_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Banco_CODIGO CHECK (CODIGO NOT LIKE '%[^0-9]%'),
        CONSTRAINT CK_Banco_ISPB   CHECK (ISPB = '' OR (LEN(ISPB) = 8 AND ISPB NOT LIKE '%[^0-9]%'))
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Empresa.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.Conta.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.FK_Conta_Padrao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : FK de CAD.Empresa para BANCO.Conta
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a conta bancária padrão da empresa (BANCO.Conta é criada
                depois de CAD.Empresa, por isso a FK fica neste arquivo).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[FK_Empresa_Conta_Padrao]', N'F') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CONSTRAINT FK_Empresa_Conta_Padrao
        FOREIGN KEY (ID_CONTA_BANCARIA_PADRAO) REFERENCES [BANCO].[Conta] (ID_CONTA);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Centro_Custo.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Pessoa.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Pessoa_Contato.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Contato]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Contatos de cada pessoa (vários e-mails e telefones). RECEBE_COBRANCA:
                recebe boleto, régua de cobrança e extrato. Telefones gravados só com
                dígitos. Contato removido na tela é desativado (não apagado).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Contato]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Contato]
    (
        ID_PESSOA_CONTATO  INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA          INT            NOT NULL,
        TIPO               VARCHAR(10)    NOT NULL,
        VALOR              NVARCHAR(256)  NOT NULL,
        NOME_CONTATO       NVARCHAR(80)   NOT NULL CONSTRAINT DF_Pessoa_Contato_NOME_CONTATO    DEFAULT (N''),
        PRINCIPAL          BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_PRINCIPAL       DEFAULT (0),
        RECEBE_COBRANCA    BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_RECEBE_COBRANCA DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Pessoa_Contato_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Contato_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Contato_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Contato        PRIMARY KEY CLUSTERED (ID_PESSOA_CONTATO),
        CONSTRAINT FK_Pessoa_Contato_Pessoa FOREIGN KEY (ID_PESSOA) REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT CK_Pessoa_Contato_TIPO   CHECK (TIPO IN ('EMAIL', 'CELULAR', 'TELEFONE', 'WHATSAPP')),
        CONSTRAINT CK_Pessoa_Contato_VALOR  CHECK (VALOR <> N'')
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_Contato_Pessoa' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Contato]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_Contato_Pessoa ON [CAD].[Pessoa_Contato] (ID_PESSOA);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Pessoa_Vinculo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Vinculo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Vínculos entre pessoas: cônjuge/coobrigado, sócio, representante,
                procurador. A pessoa vinculada também é uma CAD.Pessoa.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Vinculo]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Vinculo]
    (
        ID_PESSOA_VINCULO    INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA            INT            NOT NULL,
        ID_PESSOA_VINCULADA  INT            NOT NULL,
        TIPO                 VARCHAR(15)    NOT NULL,
        OBSERVACAO           NVARCHAR(200)  NOT NULL CONSTRAINT DF_Pessoa_Vinculo_OBSERVACAO DEFAULT (N''),
        ATIVO                BIT            NOT NULL CONSTRAINT DF_Pessoa_Vinculo_ATIVO      DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Vinculo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Vinculo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Vinculo           PRIMARY KEY CLUSTERED (ID_PESSOA_VINCULO),
        CONSTRAINT UQ_Pessoa_Vinculo           UNIQUE (ID_PESSOA, ID_PESSOA_VINCULADA, TIPO),
        CONSTRAINT FK_Pessoa_Vinculo_Pessoa    FOREIGN KEY (ID_PESSOA)           REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Pessoa_Vinculo_Vinculada FOREIGN KEY (ID_PESSOA_VINCULADA) REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT CK_Pessoa_Vinculo_TIPO      CHECK (TIPO IN ('CONJUGE', 'SOCIO', 'REPRESENTANTE', 'PROCURADOR')),
        CONSTRAINT CK_Pessoa_Vinculo_PROPRIA   CHECK (ID_PESSOA <> ID_PESSOA_VINCULADA)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Pessoa_Dado_Bancario.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[Pessoa_Dado_Bancario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Dados bancários da pessoa para pagamento por TED ou PIX (várias contas,
                uma principal). TED exige banco, agência e conta; PIX exige tipo e
                chave. Titular só quando for outra pessoa.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Pessoa_Dado_Bancario]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Pessoa_Dado_Bancario]
    (
        ID_PESSOA_DADO_BANCARIO  INT            IDENTITY(1,1) NOT NULL,
        ID_PESSOA                INT            NOT NULL,
        TIPO                     VARCHAR(3)     NOT NULL,
        ID_BANCO                 INT            NULL,
        AGENCIA                  VARCHAR(10)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_AGENCIA           DEFAULT (''),
        AGENCIA_DV               VARCHAR(2)     NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_AGENCIA_DV        DEFAULT (''),
        CONTA                    VARCHAR(20)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_CONTA             DEFAULT (''),
        CONTA_DV                 VARCHAR(2)     NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_CONTA_DV          DEFAULT (''),
        TIPO_CONTA               VARCHAR(10)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_TIPO_CONTA        DEFAULT (''),
        TITULAR_NOME             NVARCHAR(150)  NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_TITULAR_NOME      DEFAULT (N''),
        TITULAR_DOCUMENTO        VARCHAR(14)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_TITULAR_DOCUMENTO DEFAULT (''),
        PIX_TIPO                 VARCHAR(10)    NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_PIX_TIPO          DEFAULT (''),
        PIX_CHAVE                NVARCHAR(140)  NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_PIX_CHAVE         DEFAULT (N''),
        PRINCIPAL                BIT            NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_PRINCIPAL         DEFAULT (0),
        ATIVO                    BIT            NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_ATIVO             DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Pessoa_Dado_Bancario_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Pessoa_Dado_Bancario            PRIMARY KEY CLUSTERED (ID_PESSOA_DADO_BANCARIO),
        CONSTRAINT FK_Pessoa_Dado_Bancario_Pessoa     FOREIGN KEY (ID_PESSOA) REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Pessoa_Dado_Bancario_Banco      FOREIGN KEY (ID_BANCO)  REFERENCES [BANCO].[Banco] (ID_BANCO),
        CONSTRAINT CK_Pessoa_Dado_Bancario_TIPO       CHECK (TIPO IN ('TED', 'PIX')),
        CONSTRAINT CK_Pessoa_Dado_Bancario_TIPO_CONTA CHECK (TIPO_CONTA IN ('', 'CORRENTE', 'POUPANCA', 'PAGAMENTO')),
        CONSTRAINT CK_Pessoa_Dado_Bancario_PIX_TIPO   CHECK (PIX_TIPO IN ('', 'DOCUMENTO', 'EMAIL', 'CELULAR', 'ALEATORIA')),
        CONSTRAINT CK_Pessoa_Dado_Bancario_TED        CHECK (TIPO <> 'TED' OR (ID_BANCO IS NOT NULL AND AGENCIA <> '' AND CONTA <> '')),
        CONSTRAINT CK_Pessoa_Dado_Bancario_PIX        CHECK (TIPO <> 'PIX' OR (PIX_TIPO <> '' AND PIX_CHAVE <> N''))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pessoa_Dado_Bancario_Pessoa' AND object_id = OBJECT_ID(N'[CAD].[Pessoa_Dado_Bancario]'))
    CREATE NONCLUSTERED INDEX IX_Pessoa_Dado_Bancario_Pessoa ON [CAD].[Pessoa_Dado_Bancario] (ID_PESSOA);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Plano_Grupo.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Plano_Subgrupo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[Plano_Subgrupo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas, nível 2 (subgrupo), sempre dentro de um grupo (FK).
                Número e descrição não se repetem dentro do mesmo grupo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Plano_Conta.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.Empresa_Pasta_OFX.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[Empresa].PASTA_OFX
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Pasta onde a empresa guarda os extratos OFX do banco (pedido do
                Celso, 17/11/2026). Caminho editável no cadastro da empresa; vazio =
                a empresa não importa OFX. A conta é identificada pelo conteúdo do
                arquivo (banco/agência/conta), não pelo nome.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'CAD.Empresa', N'PASTA_OFX') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD PASTA_OFX NVARCHAR(260) NOT NULL CONSTRAINT DF_Empresa_PASTA_OFX DEFAULT (N'');
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.Historico_Padrao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[Historico_Padrao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Históricos padrão do lançamento (Pgto efetuado, NF nº, Salário,
                impostos...). Ajudam a digitar e a filtrar; o texto livre continua
                no HISTORICO do lançamento.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Historico_Padrao]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Historico_Padrao]
    (
        ID_HISTORICO_PADRAO  INT            IDENTITY(1,1) NOT NULL,
        DESCRICAO            NVARCHAR(80)   NOT NULL,
        ATIVO                BIT            NOT NULL CONSTRAINT DF_Historico_Padrao_ATIVO DEFAULT (1),
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Historico_Padrao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Historico_Padrao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Historico_Padrao           PRIMARY KEY CLUSTERED (ID_HISTORICO_PADRAO),
        CONSTRAINT UQ_Historico_Padrao_DESCRICAO UNIQUE (DESCRICAO),
        CONSTRAINT CK_Historico_Padrao_DESCRICAO CHECK (DESCRICAO <> N'')
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.Mes_Fechado.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[Mes_Fechado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Fechamento de mês por empresa (item 10 da seção 3.3 e pedido 10).
                Mês fechado bloqueia incluir, alterar, baixar e estornar só os
                lançamentos em conta do plano marcada como CONTABIL. Reabrir exige
                permissão e fica na auditoria. MES = primeiro dia do mês.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Mes_Fechado]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Mes_Fechado]
    (
        ID_MES_FECHADO     INT            IDENTITY(1,1) NOT NULL,
        ID_EMPRESA         INT            NOT NULL,
        MES                DATE           NOT NULL,
        FECHADO            BIT            NOT NULL CONSTRAINT DF_Mes_Fechado_FECHADO DEFAULT (1),
        OBSERVACAO         NVARCHAR(400)  NOT NULL CONSTRAINT DF_Mes_Fechado_OBSERVACAO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Mes_Fechado_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Mes_Fechado_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Mes_Fechado          PRIMARY KEY CLUSTERED (ID_MES_FECHADO),
        CONSTRAINT UQ_Mes_Fechado_MES      UNIQUE (ID_EMPRESA, MES),
        CONSTRAINT FK_Mes_Fechado_Empresa  FOREIGN KEY (ID_EMPRESA) REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT CK_Mes_Fechado_MES      CHECK (DAY(MES) = 1)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.Extrato_Arquivo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [BANCO].[Extrato_Arquivo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Cada arquivo de extrato (OFX) importado. O HASH impede importar o
                mesmo arquivo duas vezes. Mês sem movimento não tem arquivo (não é
                erro). Pedido do Celso, 17/11/2026; leitura e tela na fase 4.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Extrato_Arquivo]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Extrato_Arquivo]
    (
        ID_EXTRATO_ARQUIVO  BIGINT         IDENTITY(1,1) NOT NULL,
        ID_CONTA            INT            NOT NULL,
        NOME_ARQUIVO        NVARCHAR(260)  NOT NULL,
        HASH_SHA256         VARCHAR(64)    NOT NULL,
        DT_INICIO           DATE           NULL,
        DT_FIM              DATE           NULL,
        SALDO_FINAL         DECIMAL(18,2)  NULL,
        QTD_LINHAS          INT            NOT NULL CONSTRAINT DF_Extrato_Arquivo_QTD_LINHAS DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Extrato_Arquivo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Extrato_Arquivo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Extrato_Arquivo       PRIMARY KEY CLUSTERED (ID_EXTRATO_ARQUIVO),
        CONSTRAINT UQ_Extrato_Arquivo_HASH  UNIQUE (HASH_SHA256),
        CONSTRAINT FK_Extrato_Arquivo_Conta FOREIGN KEY (ID_CONTA) REFERENCES [BANCO].[Conta] (ID_CONTA)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.Extrato_Linha.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [BANCO].[Extrato_Linha]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Linhas do extrato OFX. FITID (identificador do banco) é único
                por conta. VALOR: positivo entrou, negativo saiu. SITUACAO: PENDENTE
                (sem par no sistema), CONCILIADA (ligada a um BANCO.Movimento) ou
                IGNORADA (decisão do usuário).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Extrato_Linha]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Extrato_Linha]
    (
        ID_EXTRATO_LINHA    BIGINT         IDENTITY(1,1) NOT NULL,
        ID_EXTRATO_ARQUIVO  BIGINT         NOT NULL,
        ID_CONTA            INT            NOT NULL,
        FITID               VARCHAR(100)   NOT NULL,
        DT_LANCAMENTO       DATE           NOT NULL,
        VALOR               DECIMAL(18,2)  NOT NULL,
        TIPO_OFX            VARCHAR(20)    NOT NULL CONSTRAINT DF_Extrato_Linha_TIPO_OFX  DEFAULT (''),
        DOCUMENTO           NVARCHAR(40)   NOT NULL CONSTRAINT DF_Extrato_Linha_DOCUMENTO DEFAULT (N''),
        HISTORICO           NVARCHAR(255)  NOT NULL CONSTRAINT DF_Extrato_Linha_HISTORICO DEFAULT (N''),
        SITUACAO            VARCHAR(10)    NOT NULL CONSTRAINT DF_Extrato_Linha_SITUACAO  DEFAULT ('PENDENTE'),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Extrato_Linha_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Extrato_Linha_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Extrato_Linha          PRIMARY KEY CLUSTERED (ID_EXTRATO_LINHA),
        CONSTRAINT UQ_Extrato_Linha_FITID    UNIQUE (ID_CONTA, FITID),
        CONSTRAINT FK_Extrato_Linha_Arquivo  FOREIGN KEY (ID_EXTRATO_ARQUIVO) REFERENCES [BANCO].[Extrato_Arquivo] (ID_EXTRATO_ARQUIVO),
        CONSTRAINT FK_Extrato_Linha_Conta    FOREIGN KEY (ID_CONTA) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT CK_Extrato_Linha_SITUACAO CHECK (SITUACAO IN ('PENDENTE', 'CONCILIADA', 'IGNORADA'))
    );
    CREATE INDEX IX_Extrato_Linha_CONTA_DATA ON [BANCO].[Extrato_Linha] (ID_CONTA, DT_LANCAMENTO, SITUACAO);
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.Transferencia.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[Transferencia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Transferência entre contas (da mesma empresa ou entre empresas do
                grupo). Gera dois BANCO.Movimento (saída na origem, entrada no
                destino) com o mesmo ID_TRANSFERENCIA.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Transferencia]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Transferencia]
    (
        ID_TRANSFERENCIA    BIGINT         IDENTITY(1,1) NOT NULL,
        DT_TRANSFERENCIA    DATE           NOT NULL,
        ID_CONTA_ORIGEM     INT            NOT NULL,
        ID_CONTA_DESTINO    INT            NOT NULL,
        VALOR               DECIMAL(18,2)  NOT NULL,
        HISTORICO           NVARCHAR(200)  NOT NULL CONSTRAINT DF_Transferencia_HISTORICO DEFAULT (N''),
        SITUACAO            VARCHAR(10)    NOT NULL CONSTRAINT DF_Transferencia_SITUACAO  DEFAULT ('ATIVA'),
        ID_LOTE             BIGINT         NULL,
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Transferencia_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Transferencia_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Transferencia          PRIMARY KEY CLUSTERED (ID_TRANSFERENCIA),
        CONSTRAINT FK_Transferencia_Origem   FOREIGN KEY (ID_CONTA_ORIGEM)  REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Transferencia_Destino  FOREIGN KEY (ID_CONTA_DESTINO) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Transferencia_Lote     FOREIGN KEY (ID_LOTE) REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Transferencia_CONTAS   CHECK (ID_CONTA_ORIGEM <> ID_CONTA_DESTINO),
        CONSTRAINT CK_Transferencia_VALOR    CHECK (VALOR > 0),
        CONSTRAINT CK_Transferencia_SITUACAO CHECK (SITUACAO IN ('ATIVA', 'ESTORNADA'))
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.Movimento.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [BANCO].[Movimento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : O que passa em cada conta (banco, caixa, permuta). VALOR positivo
                entrou, negativo saiu. Gerado pelas rotinas (baixa, transferência,
                tarifa, ajuste, saldo inicial), nunca digitado solto. Um pagamento
                em lote (várias baixas) gera UM movimento pelo total, para bater com
                o extrato. CONCILIADO + ID_EXTRATO_LINHA: conciliação (fase 4).
                Saldo da conta = SALDO_INICIAL da conta + soma dos movimentos.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[BANCO].[Movimento]', N'U') IS NULL
BEGIN
    CREATE TABLE [BANCO].[Movimento]
    (
        ID_MOVIMENTO        BIGINT         IDENTITY(1,1) NOT NULL,
        ID_CONTA            INT            NOT NULL,
        DT_MOVIMENTO        DATE           NOT NULL,
        VALOR               DECIMAL(18,2)  NOT NULL,
        TIPO                VARCHAR(15)    NOT NULL,
        HISTORICO           NVARCHAR(200)  NOT NULL CONSTRAINT DF_Movimento_HISTORICO  DEFAULT (N''),
        DOCUMENTO           NVARCHAR(40)   NOT NULL CONSTRAINT DF_Movimento_DOCUMENTO  DEFAULT (N''),
        ID_TRANSFERENCIA    BIGINT         NULL,
        CONCILIADO          BIT            NOT NULL CONSTRAINT DF_Movimento_CONCILIADO DEFAULT (0),
        ID_EXTRATO_LINHA    BIGINT         NULL,
        SITUACAO            VARCHAR(10)    NOT NULL CONSTRAINT DF_Movimento_SITUACAO   DEFAULT ('ATIVO'),
        ID_LOTE             BIGINT         NULL,
        CODIGO_ACCESS       INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Movimento_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Movimento_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Movimento               PRIMARY KEY CLUSTERED (ID_MOVIMENTO),
        CONSTRAINT FK_Movimento_Conta         FOREIGN KEY (ID_CONTA)         REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Movimento_Transferencia FOREIGN KEY (ID_TRANSFERENCIA) REFERENCES [FIN].[Transferencia] (ID_TRANSFERENCIA),
        CONSTRAINT FK_Movimento_Extrato_Linha FOREIGN KEY (ID_EXTRATO_LINHA) REFERENCES [BANCO].[Extrato_Linha] (ID_EXTRATO_LINHA),
        CONSTRAINT FK_Movimento_Lote          FOREIGN KEY (ID_LOTE)          REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Movimento_TIPO          CHECK (TIPO IN ('BAIXA', 'TRANSFERENCIA', 'TARIFA', 'AJUSTE', 'SALDO_INICIAL')),
        CONSTRAINT CK_Movimento_SITUACAO      CHECK (SITUACAO IN ('ATIVO', 'ESTORNADO')),
        CONSTRAINT CK_Movimento_CONCILIADO    CHECK (CONCILIADO = 0 OR ID_EXTRATO_LINHA IS NOT NULL)
    );
    CREATE INDEX IX_Movimento_CONTA_DATA ON [BANCO].[Movimento] (ID_CONTA, DT_MOVIMENTO) INCLUDE (VALOR, CONCILIADO, SITUACAO);
    CREATE INDEX IX_Movimento_LOTE       ON [BANCO].[Movimento] (ID_LOTE) WHERE ID_LOTE IS NOT NULL;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.Lancamento.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[Lancamento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : O documento: uma obrigação a pagar (P) ou a receber (R), lançada
                uma vez (modelo de lançamento único, seção 3.2). Parcelas em
                FIN.Parcela, pagamentos em FIN.Baixa. Empresa vem do centro de custo
                (a rotina de gravação confere). INTEGRACAO (respostas do Celso,
                17/11/2026): COMPLETA = contabilidade + custo + banco; SO_CONTABIL =
                só relatórios da contabilidade, sem banco nem custo; NENHUMA.
                PREVISAO: compromisso previsto, sem documento (fluxo projetado).
                ID_PEDIDO_COMPRA: FK ligada quando o COMP existir. CODIGO_ACCESS +
                ORIGEM_ACCESS: rastreio da migração.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Lancamento]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Lancamento]
    (
        ID_LANCAMENTO        BIGINT         IDENTITY(1,1) NOT NULL,
        TIPO                 CHAR(1)        NOT NULL,
        ID_EMPRESA           INT            NOT NULL,
        ID_CENTRO_CUSTO      INT            NULL,
        ID_PESSOA            INT            NULL,
        ID_PLANO_CONTA       INT            NULL,
        ID_HISTORICO_PADRAO  INT            NULL,
        DOCUMENTO            NVARCHAR(40)   NOT NULL CONSTRAINT DF_Lancamento_DOCUMENTO     DEFAULT (N''),
        DT_EMISSAO           DATE           NOT NULL,
        DT_COMPETENCIA       DATE           NOT NULL,
        HISTORICO            NVARCHAR(200)  NOT NULL CONSTRAINT DF_Lancamento_HISTORICO     DEFAULT (N''),
        OBSERVACAO           NVARCHAR(2000) NOT NULL CONSTRAINT DF_Lancamento_OBSERVACAO    DEFAULT (N''),
        VALOR_TOTAL          DECIMAL(18,2)  NOT NULL,
        ORIGEM               VARCHAR(15)    NOT NULL CONSTRAINT DF_Lancamento_ORIGEM        DEFAULT ('MANUAL'),
        ID_ORIGEM            BIGINT         NULL,
        ID_LOTE              BIGINT         NULL,
        SITUACAO             VARCHAR(10)    NOT NULL CONSTRAINT DF_Lancamento_SITUACAO      DEFAULT ('ATIVO'),
        PREVISAO             BIT            NOT NULL CONSTRAINT DF_Lancamento_PREVISAO      DEFAULT (0),
        INTEGRACAO           VARCHAR(12)    NOT NULL CONSTRAINT DF_Lancamento_INTEGRACAO    DEFAULT ('COMPLETA'),
        ID_PEDIDO_COMPRA     BIGINT         NULL,
        CODIGO_ACCESS        INT            NULL,
        ORIGEM_ACCESS        VARCHAR(20)    NOT NULL CONSTRAINT DF_Lancamento_ORIGEM_ACCESS DEFAULT (''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Lancamento_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lancamento_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lancamento               PRIMARY KEY CLUSTERED (ID_LANCAMENTO),
        CONSTRAINT FK_Lancamento_Empresa       FOREIGN KEY (ID_EMPRESA)          REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Lancamento_Centro_Custo  FOREIGN KEY (ID_CENTRO_CUSTO)     REFERENCES [CAD].[Centro_Custo] (ID_CENTRO_CUSTO),
        CONSTRAINT FK_Lancamento_Pessoa        FOREIGN KEY (ID_PESSOA)           REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Lancamento_Plano_Conta   FOREIGN KEY (ID_PLANO_CONTA)      REFERENCES [CAD].[Plano_Conta] (ID_PLANO_CONTA),
        CONSTRAINT FK_Lancamento_Historico     FOREIGN KEY (ID_HISTORICO_PADRAO) REFERENCES [FIN].[Historico_Padrao] (ID_HISTORICO_PADRAO),
        CONSTRAINT FK_Lancamento_Lote          FOREIGN KEY (ID_LOTE)             REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Lancamento_TIPO          CHECK (TIPO IN ('P', 'R')),
        CONSTRAINT CK_Lancamento_VALOR_TOTAL   CHECK (VALOR_TOTAL >= 0),
        CONSTRAINT CK_Lancamento_COMPETENCIA   CHECK (DAY(DT_COMPETENCIA) = 1),
        CONSTRAINT CK_Lancamento_ORIGEM        CHECK (ORIGEM IN ('MANUAL', 'VENDA', 'COMPRA', 'MEDICAO', 'RECORRENTE', 'CONCILIACAO', 'ACORDO', 'MIGRACAO')),
        CONSTRAINT CK_Lancamento_SITUACAO      CHECK (SITUACAO IN ('ATIVO', 'CANCELADO')),
        CONSTRAINT CK_Lancamento_INTEGRACAO    CHECK (INTEGRACAO IN ('COMPLETA', 'SO_CONTABIL', 'NENHUMA'))
    );
    CREATE INDEX IX_Lancamento_PESSOA       ON [FIN].[Lancamento] (ID_PESSOA) WHERE ID_PESSOA IS NOT NULL;
    CREATE INDEX IX_Lancamento_CENTRO_CUSTO ON [FIN].[Lancamento] (ID_CENTRO_CUSTO, DT_COMPETENCIA);
    CREATE INDEX IX_Lancamento_LOTE         ON [FIN].[Lancamento] (ID_LOTE) WHERE ID_LOTE IS NOT NULL;
    CREATE INDEX IX_Lancamento_ACCESS       ON [FIN].[Lancamento] (ORIGEM_ACCESS, CODIGO_ACCESS) WHERE CODIGO_ACCESS IS NOT NULL;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.Parcela.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[Parcela]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Um vencimento do lançamento. VALOR_BAIXADO é mantido pela trigger
                FIN.tg_FIN_Baixa_Saldo (soma do VALOR_PRINCIPAL das baixas, regra 9);
                SALDO = VALOR - VALOR_BAIXADO. SITUACAO: ABERTA, PARCIAL, PAGA (pela
                trigger) ou CANCELADA (pela rotina). ID_CONTA_PREVISTA: conta em que
                se espera pagar/receber (fluxo de caixa).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Parcela]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Parcela]
    (
        ID_PARCELA           BIGINT         IDENTITY(1,1) NOT NULL,
        ID_LANCAMENTO        BIGINT         NOT NULL,
        NUMERO               SMALLINT       NOT NULL,
        QTD_PARCELAS         SMALLINT       NOT NULL,
        DT_VENCIMENTO        DATE           NOT NULL,
        VALOR                DECIMAL(18,2)  NOT NULL,
        VALOR_BAIXADO        DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Parcela_VALOR_BAIXADO DEFAULT (0),
        SALDO                AS (CAST(VALOR - VALOR_BAIXADO AS DECIMAL(18,2))) PERSISTED,
        SITUACAO             VARCHAR(10)    NOT NULL CONSTRAINT DF_Parcela_SITUACAO      DEFAULT ('ABERTA'),
        ID_CONTA_PREVISTA    INT            NULL,
        ID_LOTE              BIGINT         NULL,
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Parcela_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Parcela_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Parcela                PRIMARY KEY CLUSTERED (ID_PARCELA),
        CONSTRAINT UQ_Parcela_NUMERO         UNIQUE (ID_LANCAMENTO, NUMERO),
        CONSTRAINT FK_Parcela_Lancamento     FOREIGN KEY (ID_LANCAMENTO)     REFERENCES [FIN].[Lancamento] (ID_LANCAMENTO),
        CONSTRAINT FK_Parcela_Conta_Prevista FOREIGN KEY (ID_CONTA_PREVISTA) REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Parcela_Lote           FOREIGN KEY (ID_LOTE)           REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Parcela_NUMERO         CHECK (NUMERO >= 1 AND NUMERO <= QTD_PARCELAS),
        CONSTRAINT CK_Parcela_VALOR          CHECK (VALOR >= 0),
        CONSTRAINT CK_Parcela_SITUACAO       CHECK (SITUACAO IN ('ABERTA', 'PARCIAL', 'PAGA', 'CANCELADA'))
    );
    CREATE INDEX IX_Parcela_VENCIMENTO ON [FIN].[Parcela] (DT_VENCIMENTO, SITUACAO) INCLUDE (ID_LANCAMENTO, VALOR, VALOR_BAIXADO);
    CREATE INDEX IX_Parcela_LANCAMENTO ON [FIN].[Parcela] (ID_LANCAMENTO);
    CREATE INDEX IX_Parcela_LOTE       ON [FIN].[Parcela] (ID_LOTE) WHERE ID_LOTE IS NOT NULL;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.Baixa.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[Baixa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Cada pagamento/recebimento (total ou parcial) de uma parcela.
                Um campo para cada valor (pedido 8). VALOR_PRINCIPAL = quanto da
                parcela foi quitado (abate o saldo). VALOR_LIQUIDO = o que passou na
                conta: principal + juros + multa + correção - desconto - abatimento
                - retenção (a TARIFA do banco gera movimento próprio). ID_MOVIMENTO:
                movimento bancário (um só para várias baixas do mesmo pagamento em
                lote). Estorno = nova baixa com valores negativos apontando para a
                original (ID_BAIXA_ESTORNADA); nada é apagado. COMPENSADO = 0:
                pago com cheque ainda não compensado (o "Efetuado" do Access).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Baixa]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Baixa]
    (
        ID_BAIXA             BIGINT         IDENTITY(1,1) NOT NULL,
        ID_PARCELA           BIGINT         NOT NULL,
        DT_PAGAMENTO         DATE           NOT NULL,
        ID_CONTA             INT            NOT NULL,
        FORMA                VARCHAR(12)    NOT NULL CONSTRAINT DF_Baixa_FORMA           DEFAULT ('OUTRA'),
        VALOR_PRINCIPAL      DECIMAL(18,2)  NOT NULL,
        JUROS                DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_JUROS           DEFAULT (0),
        MULTA                DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_MULTA           DEFAULT (0),
        CORRECAO             DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_CORRECAO        DEFAULT (0),
        DESCONTO             DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_DESCONTO        DEFAULT (0),
        ABATIMENTO           DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_ABATIMENTO      DEFAULT (0),
        TARIFA               DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_TARIFA          DEFAULT (0),
        RETENCAO             DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Baixa_RETENCAO        DEFAULT (0),
        VALOR_LIQUIDO        AS (CAST(VALOR_PRINCIPAL + JUROS + MULTA + CORRECAO - DESCONTO - ABATIMENTO - RETENCAO AS DECIMAL(18,2))) PERSISTED,
        ID_MOVIMENTO         BIGINT         NULL,
        COMPENSADO           BIT            NOT NULL CONSTRAINT DF_Baixa_COMPENSADO      DEFAULT (1),
        DT_COMPENSACAO       DATE           NULL,
        ID_BAIXA_ESTORNADA   BIGINT         NULL,
        OBSERVACAO           NVARCHAR(400)  NOT NULL CONSTRAINT DF_Baixa_OBSERVACAO      DEFAULT (N''),
        ID_LOTE              BIGINT         NULL,
        CODIGO_ACCESS        INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Baixa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Baixa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Baixa               PRIMARY KEY CLUSTERED (ID_BAIXA),
        CONSTRAINT FK_Baixa_Parcela       FOREIGN KEY (ID_PARCELA)         REFERENCES [FIN].[Parcela] (ID_PARCELA),
        CONSTRAINT FK_Baixa_Conta         FOREIGN KEY (ID_CONTA)           REFERENCES [BANCO].[Conta] (ID_CONTA),
        CONSTRAINT FK_Baixa_Movimento     FOREIGN KEY (ID_MOVIMENTO)       REFERENCES [BANCO].[Movimento] (ID_MOVIMENTO),
        CONSTRAINT FK_Baixa_Estornada     FOREIGN KEY (ID_BAIXA_ESTORNADA) REFERENCES [FIN].[Baixa] (ID_BAIXA),
        CONSTRAINT FK_Baixa_Lote          FOREIGN KEY (ID_LOTE)            REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Baixa_FORMA         CHECK (FORMA IN ('PIX', 'BOLETO', 'TED', 'DOC', 'DEBITO', 'DINHEIRO', 'CHEQUE', 'PERMUTA', 'CARTAO', 'OUTRA')),
        CONSTRAINT CK_Baixa_SINAL         CHECK ((ID_BAIXA_ESTORNADA IS NULL AND VALOR_PRINCIPAL >= 0) OR (ID_BAIXA_ESTORNADA IS NOT NULL AND VALOR_PRINCIPAL <= 0)),
        CONSTRAINT CK_Baixa_COMPENSACAO   CHECK (COMPENSADO = 0 OR DT_COMPENSACAO IS NOT NULL OR FORMA <> 'CHEQUE')
    );
    CREATE INDEX IX_Baixa_PARCELA      ON [FIN].[Baixa] (ID_PARCELA);
    CREATE INDEX IX_Baixa_DATA         ON [FIN].[Baixa] (DT_PAGAMENTO, ID_CONTA);
    CREATE INDEX IX_Baixa_MOVIMENTO    ON [FIN].[Baixa] (ID_MOVIMENTO) WHERE ID_MOVIMENTO IS NOT NULL;
    CREATE UNIQUE INDEX UQ_Baixa_ESTORNO ON [FIN].[Baixa] (ID_BAIXA_ESTORNADA) WHERE ID_BAIXA_ESTORNADA IS NOT NULL;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.Arquivo_Morto.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[Arquivo_Morto]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Lançamentos antigos do Access (antes de 2018, decisão do Celso de
                16 e 17/11/2026), guardados como eram, já em texto legível, só para
                consulta (sem manutenção nenhuma). Sem FK para o modelo novo: o que
                mudar no cadastro novo não altera o passado; ID_PESSOA/ID_EMPRESA/
                ID_CONTA só ajudam a busca quando há de-para. Carga pela migração.
                Saldos de cada conta na data do corte: FIN.Arquivo_Morto_Saldo.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Arquivo_Morto]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Arquivo_Morto]
    (
        ID_ARQUIVO_MORTO    BIGINT         IDENTITY(1,1) NOT NULL,
        ORIGEM_ACCESS       VARCHAR(20)    NOT NULL,
        CODIGO_ACCESS       INT            NOT NULL,
        EMPRESA             NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_EMPRESA     DEFAULT (N''),
        OBRA                NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_OBRA        DEFAULT (N''),
        PESSOA              NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_PESSOA      DEFAULT (N''),
        CONTA               NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_CONTA       DEFAULT (N''),
        PLANO1              NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO1      DEFAULT (N''),
        PLANO2              NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO2      DEFAULT (N''),
        PLANO3              NVARCHAR(120)  NOT NULL CONSTRAINT DF_Arquivo_Morto_PLANO3      DEFAULT (N''),
        HISTORICO           NVARCHAR(80)   NOT NULL CONSTRAINT DF_Arquivo_Morto_HISTORICO   DEFAULT (N''),
        COMPLEMENTO         NVARCHAR(255)  NOT NULL CONSTRAINT DF_Arquivo_Morto_COMPLEMENTO DEFAULT (N''),
        DOCUMENTO           NVARCHAR(60)   NOT NULL CONSTRAINT DF_Arquivo_Morto_DOCUMENTO   DEFAULT (N''),
        NOTA_FISCAL         NVARCHAR(60)   NOT NULL CONSTRAINT DF_Arquivo_Morto_NOTA_FISCAL DEFAULT (N''),
        IMOVEL              NVARCHAR(150)  NOT NULL CONSTRAINT DF_Arquivo_Morto_IMOVEL      DEFAULT (N''),
        OBSERVACAO          NVARCHAR(2000) NOT NULL CONSTRAINT DF_Arquivo_Morto_OBSERVACAO  DEFAULT (N''),
        VALOR_DEBITO        DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Arquivo_Morto_DEBITO      DEFAULT (0),
        VALOR_CREDITO       DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Arquivo_Morto_CREDITO     DEFAULT (0),
        DT_MOVIMENTO        DATE           NULL,
        DT_VENCIMENTO       DATE           NULL,
        DT_PAGAMENTO        DATE           NULL,
        CONFIRMADO          BIT            NOT NULL CONSTRAINT DF_Arquivo_Morto_CONFIRMADO  DEFAULT (0),
        EFETUADO            BIT            NOT NULL CONSTRAINT DF_Arquivo_Morto_EFETUADO    DEFAULT (0),
        ID_EMPRESA          INT            NULL,
        ID_PESSOA           INT            NULL,
        ID_CONTA            INT            NULL,
        DT_CARGA            DATETIME2(0)   NOT NULL CONSTRAINT DF_Arquivo_Morto_DT_CARGA    DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Arquivo_Morto        PRIMARY KEY CLUSTERED (ID_ARQUIVO_MORTO),
        CONSTRAINT UQ_Arquivo_Morto_ACCESS UNIQUE (ORIGEM_ACCESS, CODIGO_ACCESS)
    );
    CREATE INDEX IX_Arquivo_Morto_DATA   ON [FIN].[Arquivo_Morto] (DT_MOVIMENTO);
    CREATE INDEX IX_Arquivo_Morto_PESSOA ON [FIN].[Arquivo_Morto] (PESSOA);
END;
GO

IF OBJECT_ID(N'[FIN].[Arquivo_Morto_Saldo]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Arquivo_Morto_Saldo]
    (
        ID_ARQUIVO_MORTO_SALDO  INT            IDENTITY(1,1) NOT NULL,
        CONTA                   NVARCHAR(80)   NOT NULL,
        ID_CONTA                INT            NULL,
        DT_SALDO                DATE           NOT NULL,
        SALDO                   DECIMAL(18,2)  NOT NULL,
        DT_CARGA                DATETIME2(0)   NOT NULL CONSTRAINT DF_Arquivo_Morto_Saldo_DT_CARGA DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Arquivo_Morto_Saldo       PRIMARY KEY CLUSTERED (ID_ARQUIVO_MORTO_SALDO),
        CONSTRAINT UQ_Arquivo_Morto_Saldo_CONTA UNIQUE (CONTA, DT_SALDO)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Comunicado.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Comunicado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Comunicado periódico por e-mail (pedido do Celso, 17/11/2026). O
                primeiro é o BOLETIM_IMPLANTACAO (andamento da implantação). Depois
                da implantação, o mesmo mecanismo serve a outros comunicados da
                empresa, trocando só os itens. Destinatários oficiais e de
                aprovação em grupos de e-mail (SIS.Grupo_Email). EXIGE_APROVACAO:
                a rotina só manda a prévia; o envio oficial depende de alguém
                clicar em "Aprovar e enviar". INTRODUCAO: parágrafo de abertura.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado]
    (
        ID_COMUNICADO             INT            IDENTITY(1,1) NOT NULL,
        CODIGO                    VARCHAR(30)    NOT NULL,
        TITULO                    NVARCHAR(150)  NOT NULL,
        INTRODUCAO                NVARCHAR(1000) NOT NULL CONSTRAINT DF_Comunicado_INTRODUCAO      DEFAULT (N''),
        ID_GRUPO_EMAIL            INT            NOT NULL,
        ID_GRUPO_EMAIL_APROVACAO  INT            NOT NULL,
        EXIGE_APROVACAO           BIT            NOT NULL CONSTRAINT DF_Comunicado_EXIGE_APROVACAO DEFAULT (1),
        ATIVO                     BIT            NOT NULL CONSTRAINT DF_Comunicado_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado           PRIMARY KEY CLUSTERED (ID_COMUNICADO),
        CONSTRAINT UQ_Comunicado_CODIGO    UNIQUE (CODIGO),
        CONSTRAINT FK_Comunicado_Grupo     FOREIGN KEY (ID_GRUPO_EMAIL)           REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL),
        CONSTRAINT FK_Comunicado_Aprovacao FOREIGN KEY (ID_GRUPO_EMAIL_APROVACAO) REFERENCES [SIS].[Grupo_Email] (ID_GRUPO_EMAIL),
        CONSTRAINT CK_Comunicado_CODIGO    CHECK (CODIGO <> '' AND REPLACE(CODIGO, '_', '') NOT LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Comunicado_Item.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Comunicado_Item]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Itens do comunicado, em linguagem simples e sem dados técnicos,
                cada um numa seção: IMPLANTADO (em uso na CMJ), EM_TESTE e
                PROXIMA_FASE. O Claude atualiza no fim de cada fase; o Celso ajusta
                pela tela Comunicados.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado_Item]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado_Item]
    (
        ID_COMUNICADO_ITEM  INT            IDENTITY(1,1) NOT NULL,
        ID_COMUNICADO       INT            NOT NULL,
        SECAO               VARCHAR(15)    NOT NULL,
        TEXTO               NVARCHAR(300)  NOT NULL,
        ORDEM               SMALLINT       NOT NULL CONSTRAINT DF_Comunicado_Item_ORDEM DEFAULT (0),
        ATIVO               BIT            NOT NULL CONSTRAINT DF_Comunicado_Item_ATIVO DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_Item_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Item_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado_Item            PRIMARY KEY CLUSTERED (ID_COMUNICADO_ITEM),
        CONSTRAINT FK_Comunicado_Item_Comunicado FOREIGN KEY (ID_COMUNICADO) REFERENCES [SIS].[Comunicado] (ID_COMUNICADO),
        CONSTRAINT CK_Comunicado_Item_SECAO      CHECK (SECAO IN ('IMPLANTADO', 'EM_TESTE', 'PROXIMA_FASE')),
        CONSTRAINT CK_Comunicado_Item_TEXTO      CHECK (TEXTO <> N'')
    );
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Comunicado_Edicao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Comunicado_Edicao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Cada edição semanal do comunicado: período (segunda a sexta),
                assunto e HTML montados na prévia. O e-mail oficial leva
                exatamente o que foi aprovado. SITUACAO: PREVIA (aguardando
                aprovação) -> ENVIADA, ou DESCARTADA (substituída por prévia nova ou
                descartada na tela). Uma edição ENVIADA por comunicado e semana.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Comunicado_Edicao]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Comunicado_Edicao]
    (
        ID_COMUNICADO_EDICAO  BIGINT         IDENTITY(1,1) NOT NULL,
        ID_COMUNICADO         INT            NOT NULL,
        DT_INICIO             DATE           NOT NULL,
        DT_FIM                DATE           NOT NULL,
        ASSUNTO               NVARCHAR(400)  NOT NULL,
        CORPO_HTML            NVARCHAR(MAX)  NOT NULL,
        SITUACAO              VARCHAR(10)    NOT NULL CONSTRAINT DF_Comunicado_Edicao_SITUACAO DEFAULT ('PREVIA'),
        ID_EMAIL_PREVIA       BIGINT         NULL,
        ID_EMAIL_OFICIAL      BIGINT         NULL,
        DT_APROVACAO          DATETIME2(0)   NULL,
        USUARIO_APROVACAO     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Edicao_USUARIO_APROVACAO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Comunicado_Edicao_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Comunicado_Edicao_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Comunicado_Edicao            PRIMARY KEY CLUSTERED (ID_COMUNICADO_EDICAO),
        CONSTRAINT FK_Comunicado_Edicao_Comunicado FOREIGN KEY (ID_COMUNICADO) REFERENCES [SIS].[Comunicado] (ID_COMUNICADO),
        CONSTRAINT CK_Comunicado_Edicao_SITUACAO   CHECK (SITUACAO IN ('PREVIA', 'ENVIADA', 'DESCARTADA')),
        CONSTRAINT CK_Comunicado_Edicao_PERIODO    CHECK (DT_FIM >= DT_INICIO)
    );
    CREATE UNIQUE INDEX UQ_Comunicado_Edicao_ENVIADA ON [SIS].[Comunicado_Edicao] (ID_COMUNICADO, DT_INICIO) WHERE SITUACAO = 'ENVIADA';
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Versao_Banco.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Histórico das instalações do banco: cada vez que o MASTER (ou o
                pacote do desenvolvimento) roda, grava a versão instalada, quando
                e por quem. A versão atual é a do registro mais recente
                (SIS.fn_SIS_Versao_Banco). A API confere essa versão ao subir:
                programa e banco têm de estar na mesma versão (CLAUDE.md seção 7,
                fase 3d). Nunca é apagado.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Versao_Banco]', N'U') IS NULL
    CREATE TABLE [SIS].[Versao_Banco]
    (
        ID_VERSAO_BANCO  INT            IDENTITY(1,1) NOT NULL,
        VERSAO           VARCHAR(20)    NOT NULL,
        ORIGEM           VARCHAR(20)    NOT NULL,
        DT_INSTALACAO    DATETIME2(0)   NOT NULL CONSTRAINT DF_Versao_Banco_DT_INSTALACAO DEFAULT (SYSDATETIME()),
        USUARIO          NVARCHAR(128)  NOT NULL CONSTRAINT DF_Versao_Banco_USUARIO       DEFAULT (SUSER_SNAME()),
        ESTACAO          NVARCHAR(128)  NOT NULL CONSTRAINT DF_Versao_Banco_ESTACAO       DEFAULT (ISNULL(HOST_NAME(), N'')),
        CONSTRAINT PK_Versao_Banco        PRIMARY KEY CLUSTERED (ID_VERSAO_BANCO),
        CONSTRAINT CK_Versao_Banco_ORIGEM CHECK (ORIGEM IN ('MASTER', 'PACOTE_LOCAL'))
    );
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.Backup_Execucao.sql
-- -----------------------------------------------------------------------------
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
GO

-- =============================================================================
-- 5. FUNCTIONS
-- =============================================================================
PRINT N'5. FUNCTIONS';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Usuario_Atual.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Atual]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Usuário da sessão atual: o que a API gravou no SESSION_CONTEXT
                (chave USUARIO, etapa 02c) ou, na falta, o login do SQL.
                Nunca devolve NULL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Usuario_Atual();
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Atual] ()
RETURNS NVARCHAR(100)
AS
BEGIN
    RETURN ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')),
                  ISNULL(CONVERT(NVARCHAR(100), SUSER_SNAME()), N''));
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Valor (texto) de um parâmetro de SIS.Parametro.
                Parâmetro inexistente ou chave vazia: devolve '' (nunca NULL).
                Para número e S/N usar as versões tipadas
                (fn_SIS_Parametro_Inteiro, _Decimal, _SN).
                Parâmetro do tipo DATA: ler com esta function e converter com
                TRY_CONVERT(DATE, valor, 23) (não há versão tipada porque uma
                data vazia teria de virar NULL ou uma data sentinela).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro('EMAIL_TESTE');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro] (@Chave VARCHAR(60))
RETURNS NVARCHAR(4000)
AS
BEGIN
    DECLARE @Valor NVARCHAR(4000);

    SET @Chave = ISNULL(@Chave, '');
    IF @Chave = '' RETURN N'';

    SELECT @Valor = p.VALOR
    FROM SIS.Parametro p WITH (NOLOCK)
    WHERE p.CHAVE = @Chave;

    RETURN ISNULL(@Valor, N'');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_Inteiro.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Inteiro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Valor inteiro de um parâmetro. Inexistente, vazio ou inválido:
                devolve 0 (nunca NULL). Quem chama decide o que fazer com 0
                (ex.: aplicar um mínimo de segurança).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_Inteiro('SENHA_TAMANHO_MINIMO');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Inteiro] (@Chave VARCHAR(60))
RETURNS INT
AS
BEGIN
    RETURN ISNULL(TRY_CONVERT(INT, SIS.fn_SIS_Parametro(@Chave)), 0);
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_Decimal.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Decimal]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Valor decimal (percentual, taxa) de um parâmetro, em
                DECIMAL(18,6). O valor é gravado com ponto ("2.5"); por
                segurança, vírgula também é aceita na leitura.
                Inexistente, vazio ou inválido: devolve 0 (nunca NULL).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_Decimal('FIN_MULTA_PERCENTUAL');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Decimal] (@Chave VARCHAR(60))
RETURNS DECIMAL(18,6)
AS
BEGIN
    RETURN ISNULL(TRY_CONVERT(DECIMAL(18,6), REPLACE(SIS.fn_SIS_Parametro(@Chave), N',', N'.')), 0);
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_SN.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_SN]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Liga/desliga (PADRAO_SQL regra 46): 1 se o parâmetro vale "S",
                0 em qualquer outro caso (inclusive inexistente). Assim uma
                rotina nova só age depois de ligada de propósito.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_SN('COBR_REGUA_ATIVA');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_SN] (@Chave VARCHAR(60))
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN UPPER(LTRIM(RTRIM(SIS.fn_SIS_Parametro(@Chave)))) = N'S' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Texto_HTML.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Texto_HTML]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Escapa texto livre antes de entrar num HTML (PADRAO_EMAIL
                regra 12): & < > " e apóstrofo. O "&" é trocado primeiro, senão
                as entidades geradas seriam escapadas de novo.
                NULL vira '' (nunca apaga o HTML inteiro).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Texto_HTML(N'<b>A & B</b>');   -- &lt;b&gt;A &amp; B&lt;/b&gt;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Texto_HTML] (@Texto NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    RETURN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@Texto, N''),
               N'&',  N'&amp;'),
               N'<',  N'&lt;'),
               N'>',  N'&gt;'),
               N'"',  N'&quot;'),
               N'''', N'&#39;');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Formatar_Moeda.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Formatar_Moeda]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Valor em reais no formato brasileiro: "R$ 1.234,56" e
                "-R$ 1.234,56" para negativo. NULL vira "R$ 0,00".
                Usa FORMAT com cultura pt-BR fixa, independente do idioma do
                servidor. O formato "N2" é usado (e não "C") porque o "C" põe
                um espaço especial (não separável) depois do R$.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Formatar_Moeda(1234.56);   -- R$ 1.234,56
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Formatar_Moeda] (@Valor DECIMAL(18,2))
RETURNS NVARCHAR(30)
AS
BEGIN
    DECLARE @V DECIMAL(18,2) = ISNULL(@Valor, 0);

    RETURN CASE WHEN @V < 0 THEN N'-' ELSE N'' END
         + N'R$ '
         + ISNULL(FORMAT(ABS(@V), N'N2', N'pt-BR'), N'0,00');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Formatar_Data.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Formatar_Data]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Data no formato dd/MM/yyyy (estilo 103, independente do idioma
                do servidor). NULL vira '' (nunca NULL); quem monta HTML decide
                se mostra "-" no lugar.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Formatar_Data('2026-12-10');   -- 10/12/2026
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Formatar_Data] (@Data DATE)
RETURNS NVARCHAR(10)
AS
BEGIN
    IF @Data IS NULL RETURN N'';
    RETURN CONVERT(NVARCHAR(10), @Data, 103);
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Formatar_Data_Hora.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Formatar_Data_Hora]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Data e hora no formato dd/MM/yyyy HH:mm (rodapé de e-mail,
                relatórios). NULL vira '' (nunca NULL).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Formatar_Data_Hora('2026-11-15 09:05:33');   -- 15/11/2026 09:05
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Formatar_Data_Hora] (@DataHora DATETIME2(0))
RETURNS NVARCHAR(16)
AS
BEGIN
    IF @DataHora IS NULL RETURN N'';
    RETURN CONVERT(NVARCHAR(10), @DataHora, 103) + N' ' + LEFT(CONVERT(NVARCHAR(8), @DataHora, 108), 5);
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Mascarar_CPF_CNPJ.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Mascarar_CPF_CNPJ]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Formata CPF (000.000.000-00) e CNPJ (00.000.000/0000-00).
                @Ocultar = 1 esconde parte do CPF para o cliente/LGPD
                (***.456.789-**, PADRAO_EMAIL regra 21); CNPJ é de empresa e
                não é ocultado.
                Aceita o documento com ou sem pontuação e já aceita o CNPJ
                alfanumérico (letras nas 12 primeiras posições).
                Documento com tamanho diferente de 11/14: devolve como veio,
                sem pontuação. NULL vira '' (nunca NULL).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Mascarar_CPF_CNPJ('12345678901', 1);     -- ***.456.789-**
    -- SELECT SIS.fn_SIS_Mascarar_CPF_CNPJ('12345678000195', 0);  -- 12.345.678/0001-95
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Mascarar_CPF_CNPJ] (@Documento VARCHAR(20), @Ocultar BIT)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @D VARCHAR(20) = UPPER(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@Documento, ''))),
                                 '.', ''), '-', ''), '/', ''), ' ', ''));
    SET @Ocultar = ISNULL(@Ocultar, 0);

    IF LEN(@D) = 11 AND @D NOT LIKE '%[^0-9]%'
        RETURN CASE WHEN @Ocultar = 1
                    THEN '***.' + SUBSTRING(@D, 4, 3) + '.' + SUBSTRING(@D, 7, 3) + '-**'
                    ELSE SUBSTRING(@D, 1, 3) + '.' + SUBSTRING(@D, 4, 3) + '.' + SUBSTRING(@D, 7, 3) + '-' + SUBSTRING(@D, 10, 2)
               END;

    IF LEN(@D) = 14 AND @D NOT LIKE '%[^0-9A-Z]%'
        RETURN SUBSTRING(@D, 1, 2) + '.' + SUBSTRING(@D, 3, 3) + '.' + SUBSTRING(@D, 6, 3) + '/' + SUBSTRING(@D, 9, 4) + '-' + SUBSTRING(@D, 13, 2);

    RETURN @D;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Usuario_Login.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Login]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Login de um usuário pelo ID (para gravar em USUARIO_CRIACAO /
                USUARIO_ALTERACAO). ID nulo ou inexistente: devolve o usuário
                da sessão (fn_SIS_Usuario_Atual). Nunca devolve NULL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação:
    -- SELECT SIS.fn_SIS_Usuario_Login(2);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Login] (@IdUsuario INT)
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @Login NVARCHAR(100);

    SELECT @Login = CONVERT(NVARCHAR(100), u.LOGIN)
    FROM SIS.Usuario u WITH (NOLOCK)
    WHERE u.ID_USUARIO = @IdUsuario;

    RETURN ISNULL(@Login, SIS.fn_SIS_Usuario_Atual());
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Usuario_Nivel_Admin.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Nivel_Admin]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Nível de administrador de um usuário (SIS.Perfil.NIVEL_ADMIN):
                0 = comum, 1 = Administrador (CMJ), 2 = Administrador geral.
                Usuário INTERNO ativo (sistema) = 2. Usuário ou perfil inativo,
                ou inexistente = 0. Nunca NULL.
                Usada para esconder de quem não é nível 2 os usuários e perfis
                de nível 2, e para impedir que alguém dê um nível acima do seu.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b, dois níveis de administrador).

  Homologação:
    -- SELECT SIS.fn_SIS_Usuario_Nivel_Admin(2);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Nivel_Admin] (@IdUsuario INT)
RETURNS TINYINT
AS
BEGIN
    DECLARE @Nivel TINYINT;

    SELECT @Nivel = CASE WHEN u.INTERNO = 1 THEN 2 ELSE p.NIVEL_ADMIN END
    FROM SIS.Usuario u
    INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
    WHERE u.ID_USUARIO = @IdUsuario
      AND u.ATIVO = 1
      AND (p.ATIVO = 1 OR u.INTERNO = 1);

    RETURN ISNULL(@Nivel, 0);
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Tem_Permissao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Tem_Permissao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : 1 se o usuário pode fazer a ação na tela; 0 caso contrário
                (inclusive usuário, tela ou ação inexistente). Nunca NULL.
                Toda procedure chamada pela API confere logo no início:
                  IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'ALTERAR') = 0 ...
                Usuário INTERNO ativo (SISTEMA: rotinas automáticas e o
                primeiro acesso da instalação) tem permissão total.
                A API nunca usa o ID do usuário interno para quem fez login.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação:
    -- SELECT SIS.fn_SIS_Tem_Permissao(2, 'SIS_USUARIO', 'VER');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Tem_Permissao] (@IdUsuario INT, @Item VARCHAR(40), @Acao VARCHAR(20))
RETURNS BIT
AS
BEGIN
    IF @IdUsuario IS NULL OR ISNULL(@Item, '') = '' OR ISNULL(@Acao, '') = '' RETURN 0;

    IF EXISTS (SELECT 1 FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdUsuario AND u.INTERNO = 1 AND u.ATIVO = 1)
        RETURN 1;

    IF EXISTS (SELECT 1 FROM SIS.vw_SIS_Permissao_Efetiva v
               WHERE v.ID_USUARIO = @IdUsuario AND v.ITEM_CODIGO = @Item AND v.ACAO_CODIGO = @Acao)
        RETURN 1;

    RETURN 0;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Empresa_Razao_Social.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Empresa_Razao_Social]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Razão social da empresa PRINCIPAL da licença ativa (rodapé de
                e-mail, cabeçalho de relatório). Vem da licença assinada:
                ninguém altera por tela. Sem licença ativa: ''. Nunca NULL.
                Substitui o parâmetro EMPRESA_RAZAO_SOCIAL dos gabaritos.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação:
    -- SELECT SIS.fn_SIS_Empresa_Razao_Social();
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Empresa_Razao_Social] ()
RETURNS NVARCHAR(150)
AS
BEGIN
    DECLARE @Razao NVARCHAR(150);

    SELECT @Razao = e.RAZAO_SOCIAL
    FROM SIS.Licenca l WITH (NOLOCK)
    INNER JOIN SIS.Licenca_Empresa e WITH (NOLOCK) ON e.ID_LICENCA = l.ID_LICENCA
    WHERE l.ATIVA = 1
      AND e.PRINCIPAL = 1;

    RETURN ISNULL(@Razao, N'');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Empresa_CNPJ.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Empresa_CNPJ]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : CNPJ (14 posições, sem pontuação) da empresa PRINCIPAL da
                licença ativa. Para exibir: SIS.fn_SIS_Mascarar_CPF_CNPJ.
                Sem licença ativa: ''. Nunca NULL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação:
    -- SELECT SIS.fn_SIS_Mascarar_CPF_CNPJ(SIS.fn_SIS_Empresa_CNPJ(), 0);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Empresa_CNPJ] ()
RETURNS VARCHAR(14)
AS
BEGIN
    DECLARE @Cnpj VARCHAR(14);

    SELECT @Cnpj = e.CNPJ
    FROM SIS.Licenca l WITH (NOLOCK)
    INNER JOIN SIS.Licenca_Empresa e WITH (NOLOCK) ON e.ID_LICENCA = l.ID_LICENCA
    WHERE l.ATIVA = 1
      AND e.PRINCIPAL = 1;

    RETURN ISNULL(@Cnpj, '');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_Cor.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Cor]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Cor de um parâmetro do tipo COR, sempre no formato #RRGGBB,
                pronta para entrar no CSS inline dos e-mails e relatórios.
                Parâmetro inexistente, vazio ou com cor inválida: devolve
                #555555 (cinza neutro), para nunca quebrar o HTML. Nunca NULL.
                Uso: SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL')

  Changelog:
    v1.0 (15/11/2026) - Criação (identidade visual por cliente).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Cor] (@Chave VARCHAR(60))
RETURNS VARCHAR(7)
AS
BEGIN
    DECLARE @Cor VARCHAR(7) = UPPER(LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), SIS.fn_SIS_Parametro(@Chave)))), 7));

    IF LEN(@Cor) = 7 AND @Cor LIKE '#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]' COLLATE Latin1_General_BIN2
        RETURN @Cor;

    RETURN '#555555';
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Item_Tem_Tabela.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Item_Tem_Tabela]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : 1 se a tela (@Item) mantém registros da tabela (@Tabela, no
                formato 'SCHEMA.Tabela'), conforme SIS.Item.TABELAS_DA_TELA;
                0 caso contrário. Nunca NULL.
                Usada pelo Histórico (auditoria) e pelos anexos: o usuário só
                vê histórico e anexos das tabelas da tela que ele pode abrir.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação:
    -- SELECT SIS.fn_SIS_Item_Tem_Tabela('SIS_USUARIO', 'SIS.Usuario');   -- 1
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Item_Tem_Tabela] (@Item VARCHAR(40), @Tabela NVARCHAR(256))
RETURNS BIT
AS
BEGIN
    IF ISNULL(@Item, '') = '' OR ISNULL(@Tabela, N'') = N'' RETURN 0;

    IF EXISTS (SELECT 1
               FROM SIS.Item i
               CROSS APPLY STRING_SPLIT(i.TABELAS_DA_TELA, ',') s
               WHERE i.CODIGO = @Item
                 AND LTRIM(RTRIM(s.value)) = LTRIM(RTRIM(@Tabela)))
        RETURN 1;

    RETURN 0;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Email_Valido.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Email_Valido]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : 1 se o texto tem formato de UM endereço de e-mail
                (nome@dominio.ext, sem espaço, sem acento, sem dois @, sem
                ".." e sem ponto no começo/fim); 0 caso contrário.
                Não confere se a caixa existe (isso só o envio mostra).
                Caracteres aceitos: letras sem acento, números, . @ _ + -
                (conferidos com REPLACE + '[^A-Za-z0-9]' em BIN2, nunca com
                '_' ou '-' dentro de colchetes; PADRAO_SQL).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Email_Valido(N'financeiro@cmj.com.br'), SIS.fn_SIS_Email_Valido(N'sem arroba');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Email_Valido] (@Email NVARCHAR(256))
RETURNS BIT
AS
BEGIN
    DECLARE @E NVARCHAR(256) = LTRIM(RTRIM(ISNULL(@Email, N'')));
    DECLARE @Arroba INT = CHARINDEX(N'@', @E);

    IF LEN(@E) < 6 OR @Arroba < 2 RETURN 0;
    IF CHARINDEX(N'@', @E, @Arroba + 1) > 0 RETURN 0;
    IF CHARINDEX(N'..', @E) > 0 RETURN 0;
    IF LEFT(@E, 1) = N'.' OR RIGHT(@E, 1) = N'.' RETURN 0;
    IF SUBSTRING(@E, @Arroba - 1, 1) = N'.' OR SUBSTRING(@E, @Arroba + 1, 1) = N'.' RETURN 0;
    IF CHARINDEX(N'.', @E, @Arroba + 2) = 0 RETURN 0;
    IF REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@E, N'.', N''), N'@', N''), N'_', N''), N'+', N''), N'-', N'')
       LIKE N'%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN2 RETURN 0;

    RETURN 1;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Emails_Do_Grupo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Emails_Do_Grupo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Endereços ativos de um grupo de e-mail ativo, separados por
                "; ", em ordem alfabética. Nunca devolve NULL: grupo
                inexistente, inativo ou vazio devolve '' (a orquestradora
                registra o motivo e não envia; PADRAO_EMAIL regra 8).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Emails_Do_Grupo('SIS_ALERTA');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Emails_Do_Grupo] (@Grupo VARCHAR(30))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Emails NVARCHAR(MAX);

    SELECT @Emails = STRING_AGG(CONVERT(NVARCHAR(MAX), LTRIM(RTRIM(d.EMAIL))), N'; ') WITHIN GROUP (ORDER BY d.EMAIL)
    FROM SIS.Grupo_Email_Destinatario d
    INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = d.ID_GRUPO_EMAIL
    WHERE g.CODIGO = @Grupo
      AND g.ATIVO = 1
      AND d.ATIVO = 1
      AND LTRIM(RTRIM(ISNULL(d.EMAIL, N''))) <> N'';

    RETURN ISNULL(@Emails, N'');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Filtrar_Emails_Por_Dominio.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Filtrar_Emails_Por_Dominio]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Separa uma lista de e-mails em internos e externos (PADRAO_EMAIL
                regra 10), para enviar por contas diferentes sem duplicar
                grupo. Interno = domínio listado no parâmetro
                EMAIL_DOMINIO_INTERNO (pode ter vários, separados por
                vírgula; ex.: cmj.com.br). Parâmetro vazio = todos internos.
                @Interno = 1 devolve os internos; 0 devolve os externos.
                Aceita ";" ou "," como separador; devolve "; ", sem
                repetidos, na ordem em que vieram. Nunca devolve NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Filtrar_Emails_Por_Dominio(N'a@cmj.com.br; b@gmail.com', 0);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Filtrar_Emails_Por_Dominio] (@Emails NVARCHAR(MAX), @Interno BIT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Dominios NVARCHAR(4000) = LOWER(REPLACE(ISNULL(SIS.fn_SIS_Parametro('EMAIL_DOMINIO_INTERNO'), N''), N' ', N''));
    DECLARE @Saida    NVARCHAR(MAX);

    WITH e AS
    (
        SELECT LTRIM(RTRIM(s.value)) AS EMAIL, MIN(s.ordinal) AS ORDEM
        FROM STRING_SPLIT(REPLACE(ISNULL(@Emails, N''), N',', N';'), N';', 1) s
        WHERE LTRIM(RTRIM(s.value)) <> N''
        GROUP BY LTRIM(RTRIM(s.value))
    ),
    c AS
    (
        SELECT e.EMAIL, e.ORDEM,
               CASE WHEN @Dominios = N'' THEN 1
                    WHEN EXISTS (SELECT 1 FROM STRING_SPLIT(@Dominios, N',') d
                                 WHERE d.value <> N''
                                   AND LOWER(SUBSTRING(e.EMAIL, CHARINDEX(N'@', e.EMAIL) + 1, 256)) = d.value) THEN 1
                    ELSE 0 END AS INTERNO
        FROM e
    )
    SELECT @Saida = STRING_AGG(CONVERT(NVARCHAR(MAX), c.EMAIL), N'; ') WITHIN GROUP (ORDER BY c.ORDEM)
    FROM c
    WHERE c.INTERNO = ISNULL(@Interno, 1);

    RETURN ISNULL(@Saida, N'');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Email_HTML.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Email_HTML]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Moldura padrão de todo e-mail do sistema (PADRAO_EMAIL seções
                3 e 4): container branco centralizado, logomarca, cabeçalho
                colorido pela severidade, o conteúdo e o rodapé de rastreio.
                A orquestradora monta só o miolo (@Conteudo, já em HTML, com
                o texto digitado escapado por fn_SIS_Texto_HTML) e chama esta
                function: o visual fica igual em todo o sistema.
                @Severidade: INFO (cor EMPRESA_COR_PRINCIPAL), ALERTA (cor
                EMAIL_COR_ALERTA e a palavra ALERTA no título) ou SUCESSO
                (cor EMAIL_COR_SUCESSO). Cores sempre dos parâmetros.
                @Rotina: nome da procedure que gerou (variável @NomeProc).
                @Grupo : código do grupo (só em e-mail interno).
                @Externo = 1: e-mail a cliente/terceiro; rodapé sem dados
                técnicos (razão social, CNPJ se EMAIL_RODAPE_CNPJ = S, e aviso
                de não responder).
                Logomarca: <img src="cid:logo_empresa">; o serviço embute o
                arquivo do parâmetro EMPRESA_LOGO_EMAIL com esse CID sempre
                que o corpo citar "cid:logo_empresa".

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (17/11/2026) - Nome do sistema no rodapé pelo parâmetro SISTEMA_NOME.
    v1.2 (17/11/2026) - Logomarca conforme EMAIL_LOGO_MODO: EMBUTIDA (cid,
                        anexada pelo serviço), ENDERECO (EMAIL_LOGO_ENDERECO)
                        ou SEM_IMAGEM.
    v1.3 (20/11/2026) - CNPJ no rodapé do e-mail externo só se o parâmetro
                        EMAIL_RODAPE_CNPJ = S (pedido do Celso: tirar o CNPJ
                        do boletim; fábrica = N).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Email_HTML(N'Teste', 'INFO', N'<p>Olá</p>', N'[SIS].[Teste]', 'SIS_ALERTA', 0);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Email_HTML]
(
    @Titulo      NVARCHAR(200),
    @Severidade  VARCHAR(10),
    @Conteudo    NVARCHAR(MAX),
    @Rotina      NVARCHAR(256),
    @Grupo       VARCHAR(30),
    @Externo     BIT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Sev    VARCHAR(10)   = UPPER(ISNULL(@Severidade, 'INFO'));
    DECLARE @Cor    VARCHAR(7);
    DECLARE @Titul  NVARCHAR(300) = UPPER(SIS.fn_SIS_Texto_HTML(ISNULL(@Titulo, N'')));
    DECLARE @Razao  NVARCHAR(400) = SIS.fn_SIS_Texto_HTML(ISNULL(SIS.fn_SIS_Empresa_Razao_Social(), N''));
    DECLARE @Rodape NVARCHAR(MAX);
    DECLARE @Modo   VARCHAR(20)   = UPPER(ISNULL(SIS.fn_SIS_Parametro('EMAIL_LOGO_MODO'), N'EMBUTIDA'));
    DECLARE @Url    NVARCHAR(500) = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_LOGO_ENDERECO'), N'')));
    DECLARE @Logo   NVARCHAR(MAX);
    DECLARE @Sistema NVARCHAR(400) = SIS.fn_SIS_Texto_HTML(ISNULL(NULLIF(SIS.fn_SIS_Parametro('SISTEMA_NOME'), N''), N'SistemaCMJ'));

    SET @Cor = CASE @Sev WHEN 'ALERTA'  THEN SIS.fn_SIS_Parametro_Cor('EMAIL_COR_ALERTA')
                         WHEN 'SUCESSO' THEN SIS.fn_SIS_Parametro_Cor('EMAIL_COR_SUCESSO')
                         ELSE SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL') END;
    SET @Cor = ISNULL(NULLIF(@Cor, ''), '#333333');
    IF @Sev = 'ALERTA' SET @Titul = N'ALERTA - ' + @Titul;

    IF ISNULL(@Externo, 0) = 1
        SET @Rodape = N'<div style="font-weight:bold;">' + @Razao + N'</div>'
                    + CASE WHEN SIS.fn_SIS_Parametro_SN('EMAIL_RODAPE_CNPJ') = 1
                           THEN N'<div>CNPJ ' + ISNULL(SIS.fn_SIS_Mascarar_CPF_CNPJ(SIS.fn_SIS_Empresa_CNPJ(), 0), N'') + N'</div>' ELSE N'' END
                    + N'<div style="margin-top:6px;">Este e-mail foi enviado automaticamente. Por favor, não responda.</div>';
    ELSE
        SET @Rodape = N'<div>Gerado automaticamente pelo sistema ' + @Sistema + N': ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Rotina, N'')) + N'</div>'
                    + N'<div>Emitido em: ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(CAST(SYSDATETIME() AS DATETIME2(0))), N'') + N'</div>'
                    + CASE WHEN ISNULL(@Grupo, '') <> '' THEN N'<div>Grupo de Destinatários: ' + SIS.fn_SIS_Texto_HTML(@Grupo) + N'</div>' ELSE N'' END
                    + N'<div style="margin-top:6px;font-weight:bold;">' + @Razao + N'</div>';

    SET @Logo = CASE WHEN @Modo = 'SEM_IMAGEM' THEN N''
                     WHEN @Modo = 'ENDERECO' AND @Url LIKE N'https://%' AND @Url NOT LIKE N'%"%'
                          THEN N'<div style="padding:16px 20px;"><img src="' + @Url + N'" alt="' + @Razao + N'" style="max-height:60px;"></div>'
                     ELSE N'<div style="padding:16px 20px;"><img src="cid:logo_empresa" alt="' + @Razao + N'" style="max-height:60px;"></div>' END;

    RETURN N'<!DOCTYPE html><html><head><meta charset="UTF-8"></head>'
         + N'<body style="margin:0;padding:20px;background:#eeeeee;font-family:Arial,''Segoe UI'',sans-serif;color:#333333;">'
         + N'<div style="max-width:700px;margin:0 auto;background:#ffffff;box-shadow:0 1px 4px rgba(0,0,0,0.15);">'
         + @Logo
         + N'<div style="background:' + @Cor + N';color:#ffffff;font-weight:bold;padding:12px 20px;font-size:15px;">' + @Titul + N'</div>'
         + N'<div style="padding:20px;font-size:14px;line-height:1.5;">' + ISNULL(@Conteudo, N'') + N'</div>'
         + N'<div style="background:#f9f9f9;padding:12px 20px;font-size:11px;color:#777777;border-top:1px solid #eeeeee;">' + @Rodape + N'</div>'
         + N'</div></body></html>';
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Rotina_Proxima.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Rotina_Proxima]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Próxima data e hora de execução de uma rotina, depois de
                @Base (sempre maior que @Base):
                  MINUTOS : @Base + intervalo;
                  DIARIA  : próximo dia no HORARIO;
                  SEMANAL : próximo dia da lista DIAS_SEMANA (1 = domingo
                            ... 7 = sábado) no HORARIO;
                  MENSAL  : próximo mês no DIA_MES (se o mês não tem o dia,
                            ex.: 31 em abril, usa o último dia) no HORARIO.
                Dia da semana calculado sem depender do SET DATEFIRST
                (07/01/1900 foi domingo). Agenda inválida devolve NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '08:00', '2,4', 0, '2026-11-16T09:00:00');  -- 18/11 08:00
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Rotina_Proxima]
(
    @Frequencia  VARCHAR(10),
    @Intervalo   INT,
    @Horario     TIME(0),
    @DiasSemana  VARCHAR(20),
    @DiaMes      TINYINT,
    @Base        DATETIME2(0)
)
RETURNS DATETIME2(0)
AS
BEGIN
    DECLARE @Dia       DATE         = CAST(@Base AS DATE);
    DECLARE @Hora      TIME(0)      = ISNULL(@Horario, '00:00');
    DECLARE @Candidato DATETIME2(0);
    DECLARE @N         INT          = 0;
    DECLARE @Mes1      DATE;
    DECLARE @DiaUsado  INT;

    IF @Base IS NULL RETURN NULL;

    IF @Frequencia = 'MINUTOS'
    BEGIN
        IF ISNULL(@Intervalo, 0) < 1 RETURN NULL;
        RETURN DATEADD(MINUTE, @Intervalo, @Base);
    END;

    IF @Frequencia = 'DIARIA'
    BEGIN
        SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora), CAST(@Dia AS DATETIME2(0)));
        IF @Candidato <= @Base SET @Candidato = DATEADD(DAY, 1, @Candidato);
        RETURN @Candidato;
    END;

    IF @Frequencia = 'SEMANAL'
    BEGIN
        WHILE @N <= 7
        BEGIN
            IF CHARINDEX(',' + CAST(DATEDIFF(DAY, '19000107', DATEADD(DAY, @N, @Dia)) % 7 + 1 AS VARCHAR(1)) + ',', ',' + ISNULL(@DiasSemana, '') + ',') > 0
            BEGIN
                SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora), CAST(DATEADD(DAY, @N, @Dia) AS DATETIME2(0)));
                IF @Candidato > @Base RETURN @Candidato;
            END;
            SET @N = @N + 1;
        END;
        RETURN NULL;
    END;

    IF @Frequencia = 'MENSAL'
    BEGIN
        IF ISNULL(@DiaMes, 0) NOT BETWEEN 1 AND 31 RETURN NULL;
        SET @Mes1 = DATEFROMPARTS(YEAR(@Dia), MONTH(@Dia), 1);
        WHILE @N <= 2
        BEGIN
            SET @DiaUsado = CASE WHEN @DiaMes > DAY(EOMONTH(DATEADD(MONTH, @N, @Mes1))) THEN DAY(EOMONTH(DATEADD(MONTH, @N, @Mes1))) ELSE @DiaMes END;
            SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora),
                                     CAST(DATEADD(DAY, @DiaUsado - 1, DATEADD(MONTH, @N, @Mes1)) AS DATETIME2(0)));
            IF @Candidato > @Base RETURN @Candidato;
            SET @N = @N + 1;
        END;
        RETURN NULL;
    END;

    RETURN NULL;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Somente_Digitos.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Somente_Digitos]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Devolve só os dígitos de um texto (telefone, CEP, agência). Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Somente_Digitos(N'(41) 99999-1234');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Somente_Digitos] (@Texto NVARCHAR(400))
RETURNS VARCHAR(400)
AS
BEGIN
    DECLARE @R VARCHAR(400) = '';
    DECLARE @I INT = 1;
    DECLARE @T NVARCHAR(400) = ISNULL(@Texto, N'');
    DECLARE @C NCHAR(1);

    WHILE @I <= LEN(@T)
    BEGIN
        SET @C = SUBSTRING(@T, @I, 1);
        IF @C LIKE N'[0-9]' SET @R = @R + CONVERT(VARCHAR(1), @C);
        SET @I = @I + 1;
    END;

    RETURN @R;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Documento_Limpo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Limpo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : CPF/CNPJ sem pontuação e em maiúsculas (aceita o CNPJ alfanumérico).
                Tira ponto, traço, barra e espaços. Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Documento_Limpo(N'12.abc.345/01de-35');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Limpo] (@Documento NVARCHAR(30))
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN CONVERT(VARCHAR(30), UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@Documento, N''))),
                   N'.', N''), N'-', N''), N'/', N''), N' ', N''), NCHAR(9), N'')));
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.fn_CAD_Documento_Valido.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Valido]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Confere os dígitos verificadores de CPF (11 dígitos) e de CNPJ (14
                posições, aceitando o CNPJ alfanumérico: as 12 primeiras posições
                podem ter letras, valor = código ASCII - 48; os 2 dígitos finais são
                numéricos). Recusa todos os caracteres iguais. Vazio ou outro tamanho
                devolve 0. Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Documento_Valido('529.982.247-25'), CAD.fn_CAD_Documento_Valido('12.ABC.345/01DE-35');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Valido] (@Documento NVARCHAR(30))
RETURNS BIT
AS
BEGIN
    DECLARE @D  VARCHAR(30) = CAD.fn_CAD_Documento_Limpo(@Documento);
    DECLARE @S1 INT;
    DECLARE @S2 INT;
    DECLARE @V1 INT;
    DECLARE @V2 INT;

    IF @D = '' OR REPLACE(@D, LEFT(@D, 1), '') = '' RETURN 0;

    IF LEN(@D) = 11
    BEGIN
        IF @D LIKE '%[^0-9]%' RETURN 0;
        SELECT @S1 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * (11 - v.N)) FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9)) v (N);
        SET @V1 = CASE WHEN @S1 % 11 < 2 THEN 0 ELSE 11 - @S1 % 11 END;
        SELECT @S2 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * (12 - v.N)) FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) v (N);
        SET @V2 = CASE WHEN @S2 % 11 < 2 THEN 0 ELSE 11 - @S2 % 11 END;
        RETURN CASE WHEN @V1 = ASCII(SUBSTRING(@D, 10, 1)) - 48 AND @V2 = ASCII(SUBSTRING(@D, 11, 1)) - 48 THEN 1 ELSE 0 END;
    END;

    IF LEN(@D) = 14
    BEGIN
        IF LEFT(@D, 12) LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2 OR RIGHT(@D, 2) LIKE '%[^0-9]%' RETURN 0;
        SELECT @S1 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * CASE WHEN v.N <= 4 THEN 6 - v.N ELSE 14 - v.N END)
        FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) v (N);
        SET @V1 = CASE WHEN @S1 % 11 < 2 THEN 0 ELSE 11 - @S1 % 11 END;
        SELECT @S2 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * CASE WHEN v.N <= 5 THEN 7 - v.N ELSE 15 - v.N END)
        FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13)) v (N);
        SET @V2 = CASE WHEN @S2 % 11 < 2 THEN 0 ELSE 11 - @S2 % 11 END;
        RETURN CASE WHEN @V1 = ASCII(SUBSTRING(@D, 13, 1)) - 48 AND @V2 = ASCII(SUBSTRING(@D, 14, 1)) - 48 THEN 1 ELSE 0 END;
    END;

    RETURN 0;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Comunicado_Conteudo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Comunicado_Conteudo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Miolo HTML do comunicado (vai dentro da moldura de
                SIS.fn_SIS_Email_HTML): introdução + as três seções (Implantado, Em
                teste, Próxima fase) com os itens ativos em lista. Seção vazia mostra
                "Nada nesta semana." Texto escapado (PADRAO_EMAIL regra 12); cor dos
                títulos pelo parâmetro EMPRESA_COR_PRINCIPAL. Nunca devolve NULL.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Comunicado_Conteudo(1);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Comunicado_Conteudo] (@IdComunicado INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Cor     VARCHAR(7)    = ISNULL(NULLIF(SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL'), ''), '#333333');
    DECLARE @Intro   NVARCHAR(MAX) = N'';
    DECLARE @Html    NVARCHAR(MAX) = N'';

    SELECT @Intro = SIS.fn_SIS_Texto_HTML(ISNULL(c.INTRODUCAO, N''))
    FROM SIS.Comunicado c
    WHERE c.ID_COMUNICADO = @IdComunicado;

    IF ISNULL(@Intro, N'') <> N''
        SET @Html = N'<p style="margin:0 0 16px 0;">' + REPLACE(@Intro, NCHAR(10), N'<br>') + N'</p>';

    SET @Html = @Html + ISNULL((
        SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),
                   N'<div style="margin:0 0 16px 0;">'
                 + N'<div style="font-weight:bold;color:' + @Cor + N';border-bottom:2px solid ' + @Cor + N';padding-bottom:4px;margin-bottom:8px;">' + s.TITULO + N'</div>'
                 + ISNULL(l.LISTA, N'<div style="color:#777777;">Nada nesta semana.</div>')
                 + N'</div>'), N'') WITHIN GROUP (ORDER BY s.ORDEM)
        FROM (VALUES (CAST('IMPLANTADO' AS VARCHAR(15)), CAST(N'Implantado (em uso na empresa)' AS NVARCHAR(60)), 1),
                     ('EM_TESTE',     N'Em teste',      2),
                     ('PROXIMA_FASE', N'Próxima fase',  3)) s (SECAO, TITULO, ORDEM)
        OUTER APPLY (SELECT N'<ul style="margin:0;padding-left:20px;">'
                          + STRING_AGG(CONVERT(NVARCHAR(MAX), N'<li style="margin-bottom:4px;">' + SIS.fn_SIS_Texto_HTML(i.TEXTO) + N'</li>'), N'')
                            WITHIN GROUP (ORDER BY i.ORDEM, i.ID_COMUNICADO_ITEM)
                          + N'</ul>' AS LISTA
                     FROM SIS.Comunicado_Item i
                     WHERE i.ID_COMUNICADO = @IdComunicado AND i.SECAO = s.SECAO AND i.ATIVO = 1
                     HAVING COUNT(*) > 0) l
    ), N'');

    RETURN ISNULL(@Html, N'');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Versao_Banco.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Versão atual do banco (a da instalação mais recente em
                SIS.Versao_Banco). Vazio = banco sem versão registrada.
                Usada pela API ao subir e em /api/saude.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Versao_Banco();
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Versao_Banco] ()
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN ISNULL((SELECT TOP (1) v.VERSAO FROM SIS.Versao_Banco v ORDER BY v.ID_VERSAO_BANCO DESC), '');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Usuario_Id.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Id]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Código (ID_USUARIO) do usuário pelo login. NULL se não existe.
                Usada pela API para gravar em nome do usuário interno "sistema"
                (ex.: instalação da licença), sem ler tabela direto (o login da
                API só executa procedures e functions).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, licença).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Usuario_Id('sistema');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Id] (@Login VARCHAR(40))
RETURNS INT
AS
BEGIN
    RETURN (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = LOWER(LTRIM(RTRIM(@Login))));
END;
GO
GO

-- =============================================================================
-- 6. VIEWS
-- =============================================================================
PRINT N'6. VIEWS';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.vw_SIS_Permissao_Efetiva.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[vw_SIS_Permissao_Efetiva]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : O que cada usuário pode fazer de fato (uma linha por usuário +
                tela + ação permitida):
                  perfil nível 2 (administrador geral) -> todas as ações;
                  perfil nível 1 (administrador) -> todas, menos as telas
                    EXCLUSIVO_GERAL;
                  perfil comum: (ações do perfil + concessões 'C') -
                    retiradas 'R', nunca em tela EXCLUSIVO_GERAL.
                Só entram: usuário ativo, não bloqueado e não interno; perfil
                ativo; tela, ação e módulo ativos; módulo liberado na licença;
                módulo e tela HABILITADOS pelo administrador geral.
                Fonte única de permissão: fn_SIS_Tem_Permissao e
                SIS_Menu_Listar leem daqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador (NIVEL_ADMIN, EXCLUSIVO_GERAL).
    v1.2 (16/11/2026) - Módulo e tela precisam estar HABILITADOS (pedido 5).

  Homologação:
    -- SELECT * FROM SIS.vw_SIS_Permissao_Efetiva WHERE ID_USUARIO = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW [SIS].[vw_SIS_Permissao_Efetiva]
AS
SELECT u.ID_USUARIO,
       ia.ID_ITEM_ACAO,
       i.ID_ITEM,
       i.CODIGO  AS ITEM_CODIGO,
       a.ID_ACAO,
       a.CODIGO  AS ACAO_CODIGO,
       m.ID_MODULO,
       m.CODIGO  AS MODULO_CODIGO
FROM SIS.Usuario u
INNER JOIN SIS.Perfil    p  ON p.ID_PERFIL  = u.ID_PERFIL
CROSS JOIN SIS.Item_Acao ia
INNER JOIN SIS.Item      i  ON i.ID_ITEM    = ia.ID_ITEM
INNER JOIN SIS.Acao      a  ON a.ID_ACAO    = ia.ID_ACAO
INNER JOIN SIS.Modulo    m  ON m.ID_MODULO  = i.ID_MODULO
WHERE u.ATIVO = 1
  AND u.BLOQUEADO = 0
  AND u.INTERNO = 0
  AND p.ATIVO = 1
  AND ia.ATIVO = 1
  AND i.ATIVO = 1
  AND a.ATIVO = 1
  AND m.ATIVO = 1
  AND m.LIBERADO_LICENCA = 1
  AND m.HABILITADO = 1
  AND i.HABILITADO = 1
  AND (i.EXCLUSIVO_GERAL = 0 OR p.NIVEL_ADMIN = 2)
  AND (    p.NIVEL_ADMIN >= 1
       OR (    (   EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp
                           WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO)
                OR EXISTS (SELECT 1 FROM SIS.Usuario_Permissao up
                           WHERE up.ID_USUARIO = u.ID_USUARIO AND up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO AND up.TIPO = 'C'))
           AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao up
                           WHERE up.ID_USUARIO = u.ID_USUARIO AND up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO AND up.TIPO = 'R')));
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.vw_CAD_Plano_Conta.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[vw_CAD_Plano_Conta]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas achatado: uma linha por conta (nível 3) com o
                subgrupo e o grupo. CODIGO no formato 09.1.05 (grupo com 2 dígitos,
                subgrupo, conta com 2 ou 3 dígitos). ATIVO_EFETIVO: conta, subgrupo e
                grupo ativos (só essas aparecem para escolher no lançamento).
                ORDEM_ARVORE: texto para ordenar na sequência numérica.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT * FROM CAD.vw_CAD_Plano_Conta ORDER BY ORDEM_ARVORE;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW [CAD].[vw_CAD_Plano_Conta]
AS
SELECT c.ID_PLANO_CONTA,
       CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + CONVERT(VARCHAR(3), s.NUMERO) + '.'
             + CASE WHEN c.NUMERO < 10 THEN '0' ELSE '' END + CONVERT(VARCHAR(4), c.NUMERO)) AS CODIGO,
       c.DESCRICAO,
       c.NUMERO          AS NUMERO_CONTA,
       c.CONTABIL,
       c.CONTA_CONTABIL_REF,
       c.ATIVO           AS CONTA_ATIVA,
       s.ID_PLANO_SUBGRUPO,
       s.NUMERO          AS NUMERO_SUBGRUPO,
       s.DESCRICAO       AS SUBGRUPO_DESCRICAO,
       g.ID_PLANO_GRUPO,
       g.NUMERO          AS NUMERO_GRUPO,
       g.DESCRICAO       AS GRUPO_DESCRICAO,
       g.TIPO,
       g.CUSTO_OBRA,
       CAST(CASE WHEN c.ATIVO = 1 AND s.ATIVO = 1 AND g.ATIVO = 1 THEN 1 ELSE 0 END AS BIT) AS ATIVO_EFETIVO,
       CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + RIGHT('00' + CONVERT(VARCHAR(3), s.NUMERO), 2) + '.'
             + RIGHT('000' + CONVERT(VARCHAR(4), c.NUMERO), 3)) AS ORDEM_ARVORE
FROM CAD.Plano_Conta c
INNER JOIN CAD.Plano_Subgrupo s ON s.ID_PLANO_SUBGRUPO = c.ID_PLANO_SUBGRUPO
INNER JOIN CAD.Plano_Grupo    g ON g.ID_PLANO_GRUPO    = s.ID_PLANO_GRUPO;
GO
GO

-- =============================================================================
-- 7. PROCEDURES
-- =============================================================================
PRINT N'7. PROCEDURES';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Log_Erro_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Log_Erro_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Grava um erro da API ou do serviço em SIS.Log_Erro, para tudo
                ficar no mesmo lugar dos erros do SQL. As procedures do SQL não
                precisam chamar esta: gravam direto no CATCH (gabaritos).
                @Detalhe: pilha de chamadas/contexto técnico. Nunca enviar
                senha, token ou cabeçalho de autenticação (regra 53/54).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_LOG_ERRO.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Log_Erro_Gravar @Rotina = N'API/teste', @Etapa = N'Homologação', @NumeroErro = 0, @Mensagem = N'Teste de gravação de erro', @Linha = 0, @Origem = 'API';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Log_Erro_Gravar]
    @Rotina      NVARCHAR(256),
    @Etapa       NVARCHAR(200)  = NULL,
    @NumeroErro  INT            = NULL,
    @Mensagem    NVARCHAR(4000),
    @Linha       INT            = NULL,
    @Origem      VARCHAR(10)    = NULL,
    @Detalhe     NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdLogErro BIGINT;

    BEGIN TRY
        SET @Origem = UPPER(ISNULL(NULLIF(LTRIM(RTRIM(@Origem)), ''), 'API'));
        IF @Origem NOT IN ('SQL', 'API', 'SERVICO') SET @Origem = 'API';

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, ORIGEM, DETALHE)
        VALUES (ISNULL(@Rotina, N''), ISNULL(@Etapa, N''), ISNULL(@NumeroErro, 0), ISNULL(@Mensagem, N''), ISNULL(@Linha, 0), @Origem, @Detalhe);

        SET @IdLogErro = CAST(SCOPE_IDENTITY() AS BIGINT);

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Erro registrado.' AS NVARCHAR(400)) AS MENSAGEM, @IdLogErro AS ID_LOG_ERRO;
    END TRY
    BEGIN CATCH
        -- O próprio log falhou: não há onde registrar; devolve o motivo para a API gravar no arquivo de log dela.
        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível registrar o erro: ' + ISNULL(ERROR_MESSAGE(), N'') AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_LOG_ERRO;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Log_Erro_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Log_Erro_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Lista do log de erros para a tela do administrador.
                Filtros opcionais; sem datas, mostra os últimos 30 dias.
                @MaxLinhas: padrão 500, máximo 5000.
                Padrão das procedures "Listar" (proposto, ainda não é regra
                oficial): devolvem só o conjunto de dados; em recusa de filtro
                ou erro técnico fazem THROW 50001 com mensagem amigável (o erro
                técnico real vai para SIS.Log_Erro) e a API mostra a mensagem
                de erros 50001 ao usuário.
                Permissão: SIS_LOG_ERRO / VER.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: recebe @IdUsuario e confere a permissão
                        SIS_LOG_ERRO / VER.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Log_Erro_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Log_Erro_Listar @IdUsuario = 2, @DtInicio = '2026-11-01', @DtFim = '2026-11-30', @Origem = 'API', @Texto = N'teste';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Log_Erro_Listar]
    @IdUsuario  INT,
    @DtInicio   DATE           = NULL,
    @DtFim      DATE           = NULL,
    @Rotina     NVARCHAR(256)  = NULL,
    @Origem     VARCHAR(10)    = NULL,
    @Texto      NVARCHAR(200)  = NULL,
    @MaxLinhas  INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Log_Erro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação dos filtros';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LOG_ERRO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver o log de erros.', 1;

        SET @DtFim     = ISNULL(@DtFim, CAST(SYSDATETIME() AS DATE));
        SET @DtInicio  = ISNULL(@DtInicio, DATEADD(DAY, -30, @DtFim));
        SET @Rotina    = NULLIF(LTRIM(RTRIM(@Rotina)), N'');
        SET @Origem    = NULLIF(UPPER(LTRIM(RTRIM(@Origem))), '');
        SET @Texto     = NULLIF(LTRIM(RTRIM(@Texto)), N'');
        SET @MaxLinhas = ISNULL(@MaxLinhas, 500);
        IF @MaxLinhas < 1 SET @MaxLinhas = 500;
        IF @MaxLinhas > 5000 SET @MaxLinhas = 5000;

        IF @DtInicio > @DtFim
            THROW 50001, N'A data inicial não pode ser maior que a data final.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               l.ID_LOG_ERRO,
               l.DT_ERRO,
               l.ORIGEM,
               l.ROTINA,
               l.ETAPA,
               l.NUMERO_ERRO,
               l.MENSAGEM,
               l.LINHA,
               l.USUARIO,
               l.ESTACAO,
               ISNULL(CAST(l.DETALHE AS NVARCHAR(4000)), N'') AS DETALHE
        FROM SIS.Log_Erro l WITH (NOLOCK)
        WHERE l.DT_ERRO >= @DtInicio
          AND l.DT_ERRO <  DATEADD(DAY, 1, @DtFim)
          AND (@Rotina IS NULL OR l.ROTINA   LIKE N'%' + @Rotina + N'%')
          AND (@Origem IS NULL OR l.ORIGEM   = @Origem)
          AND (@Texto  IS NULL OR l.MENSAGEM LIKE N'%' + @Texto + N'%')
        ORDER BY l.ID_LOG_ERRO DESC
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;   -- recusa de filtro: a mensagem já é amigável

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o log de erros. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Parametro_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Parametro_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Lista dos parâmetros para a tela do administrador, com o módulo
                de cada um. Filtros opcionais: módulo e texto (procura na chave
                e na descrição). Os não editáveis (EDITAVEL_ADMIN = 0) também
                aparecem, só para consulta.
                Padrão "Listar": THROW 50001 com mensagem amigável em erro.
                Permissão: SIS_PARAMETRO / VER.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: recebe @IdUsuario e confere a permissão
                        SIS_PARAMETRO / VER.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Parametro_Listar @IdUsuario = 2, @Texto = N'senha';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Listar]
    @IdUsuario INT,
    @IdModulo  INT            = NULL,
    @Texto     NVARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Parametro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os parâmetros.', 1;

        SET @EtapaAtual = 'Consulta';
        SET @Texto = NULLIF(LTRIM(RTRIM(@Texto)), N'');

        SELECT p.ID_PARAMETRO,
               p.CHAVE,
               p.VALOR,
               p.VALOR_PADRAO,
               p.TIPO,
               p.DESCRICAO,
               p.ID_MODULO,
               m.CODIGO                         AS MODULO_CODIGO,
               m.NOME                           AS MODULO_NOME,
               p.EDITAVEL_ADMIN,
               p.DT_ALTERACAO,
               ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM SIS.Parametro p WITH (NOLOCK)
        INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = p.ID_MODULO
        WHERE (@IdModulo IS NULL OR p.ID_MODULO = @IdModulo)
          AND (@Texto IS NULL OR p.CHAVE LIKE N'%' + @Texto + N'%' OR p.DESCRICAO LIKE N'%' + @Texto + N'%')
        ORDER BY m.ORDEM_MENU, p.CHAVE
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os parâmetros. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Parametro_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Parametro_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Altera o valor de um parâmetro pela tela do administrador.
                Não cria nem apaga parâmetro (isso é feito só pela carga do
                MASTER). Confere se o parâmetro é editável e se o valor combina
                com o TIPO, e grava no formato canônico:
                  INTEIRO  número inteiro              ("15")
                  DECIMAL  com ponto                   ("2.5"; aceita "2,5")
                  DATA     aaaa-mm-dd                  (aceita dd/mm/aaaa)
                  SN       "S" ou "N"
                  EMAIL    um endereço só, minúsculo   (vazio = não configurado)
                  ARQUIVO  só o nome, sem pasta, sem espaço e sem acento,
                           extensão png/jpg/jpeg/svg/gif (vazio = sem
                           arquivo). A API grava o arquivo na pasta antes.
                  COR      "#RRGGBB" (gravado em maiúsculas)
                  TEXTO    livre (espaços das pontas removidos)
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_PARAMETRO.
                Antes/depois vai para SIS.Auditoria pela trigger (etapa 02c).
                Permissão: SIS_PARAMETRO / ALTERAR.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: recebe @IdUsuario (no lugar do nome) e
                        confere a permissão SIS_PARAMETRO / ALTERAR.
    v1.2 (15/11/2026) - Tipos ARQUIVO e COR (identidade visual).
    v1.3 (15/11/2026) - Correção: nome de arquivo com "_" era recusado (o
                        padrão "[^...._-]" do LIKE não funciona como
                        esperado); ". _ -" agora são retirados antes de
                        conferir se o resto é só letra e número.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Gravar @IdUsuario = 2, @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'10';
    -- EXEC SIS.SIS_Parametro_Gravar @IdUsuario = 2, @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'8';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Gravar]
    @IdUsuario  INT,
    @Chave      VARCHAR(60),
    @Valor      NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128)  = N'[SIS].[SIS_Parametro_Gravar]';
    DECLARE @EtapaAtual   VARCHAR(100)   = 'Validação';
    DECLARE @Recusa       NVARCHAR(400)  = N'';
    DECLARE @IdParametro  INT;
    DECLARE @Tipo         VARCHAR(10)    = '';
    DECLARE @Editavel     BIT            = 0;
    DECLARE @ValorAtual   NVARCHAR(4000) = N'';
    DECLARE @ValorNovo    NVARCHAR(4000) = N'';
    DECLARE @Data         DATE;
    DECLARE @Linhas       INT            = 0;
    DECLARE @Usuario      NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'ALTERAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para alterar parâmetros.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_PARAMETRO;
            RETURN;
        END;

        SET @Usuario   = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Chave     = UPPER(LTRIM(RTRIM(ISNULL(@Chave, ''))));
        SET @ValorNovo = LTRIM(RTRIM(ISNULL(@Valor, N'')));

        IF @Chave = ''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe o parâmetro.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_PARAMETRO;
            RETURN;
        END;

        SELECT @IdParametro = p.ID_PARAMETRO,
               @Tipo        = p.TIPO,
               @Editavel    = p.EDITAVEL_ADMIN,
               @ValorAtual  = p.VALOR
        FROM SIS.Parametro p
        WHERE p.CHAVE = @Chave;

        IF @IdParametro IS NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Parâmetro não encontrado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_PARAMETRO;
            RETURN;
        END;

        IF @Editavel = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Este parâmetro só pode ser alterado na instalação do sistema.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        -- Validação e formato canônico por tipo (só o primeiro problema encontrado é mostrado)
        IF @Tipo = 'INTEIRO'
        BEGIN
            IF TRY_CONVERT(INT, @ValorNovo) IS NULL
                SET @Recusa = N'Informe um número inteiro (sem casas decimais).';
            ELSE
                SET @ValorNovo = CONVERT(NVARCHAR(20), TRY_CONVERT(INT, @ValorNovo));
        END;

        IF @Tipo = 'DECIMAL'
        BEGIN
            SET @ValorNovo = REPLACE(@ValorNovo, N',', N'.');
            IF TRY_CONVERT(DECIMAL(18,6), @ValorNovo) IS NULL
                SET @Recusa = N'Informe um número (use vírgula para as casas decimais, sem ponto de milhar).';
        END;

        IF @Tipo = 'DATA'
        BEGIN
            SET @Data = ISNULL(TRY_CONVERT(DATE, @ValorNovo, 103), TRY_CONVERT(DATE, @ValorNovo, 23));
            IF @Data IS NULL
                SET @Recusa = N'Informe uma data válida (dd/mm/aaaa).';
            ELSE
                SET @ValorNovo = CONVERT(NVARCHAR(10), @Data, 23);
        END;

        IF @Tipo = 'SN'
        BEGIN
            SET @ValorNovo = UPPER(@ValorNovo);
            IF @ValorNovo NOT IN (N'S', N'N')
                SET @Recusa = N'Informe S (sim) ou N (não).';
        END;

        IF @Tipo = 'EMAIL'
        BEGIN
            SET @ValorNovo = LOWER(@ValorNovo);
            IF @ValorNovo <> N''
               AND (   @ValorNovo NOT LIKE N'%_@_%._%'
                    OR @ValorNovo LIKE N'% %'
                    OR @ValorNovo LIKE N'%;%'
                    OR @ValorNovo LIKE N'%,%'
                    OR @ValorNovo LIKE N'%@%@%')
                SET @Recusa = N'Informe um único e-mail válido (para vários destinatários, use um grupo de e-mail).';
        END;

        IF @Tipo = 'ARQUIVO' AND @ValorNovo <> N''
        BEGIN
            IF LEN(@ValorNovo) > 200
               OR REPLACE(REPLACE(REPLACE(@ValorNovo, N'.', N''), N'_', N''), N'-', N'') LIKE N'%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN2
               OR LOWER(@ValorNovo) NOT LIKE N'%_.png'
                  AND LOWER(@ValorNovo) NOT LIKE N'%_.jpg'
                  AND LOWER(@ValorNovo) NOT LIKE N'%_.jpeg'
                  AND LOWER(@ValorNovo) NOT LIKE N'%_.svg'
                  AND LOWER(@ValorNovo) NOT LIKE N'%_.gif'
                SET @Recusa = N'Informe só o nome do arquivo (sem pasta, sem espaço e sem acento), com extensão png, jpg, svg ou gif.';
        END;

        IF @Tipo = 'COR'
        BEGIN
            SET @ValorNovo = UPPER(@ValorNovo);
            IF LEN(@ValorNovo) <> 7 OR @ValorNovo NOT LIKE N'#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]' COLLATE Latin1_General_BIN2
                SET @Recusa = N'Informe a cor no formato #RRGGBB (ex.: #D43414).';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        IF @ValorNovo COLLATE Latin1_General_CS_AS = ISNULL(@ValorAtual, N'')
        BEGIN
            SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Nenhuma alteração: o valor já era este.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE p
           SET p.VALOR             = @ValorNovo,
               p.DT_ALTERACAO      = SYSDATETIME(),
               p.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Parametro p
        WHERE p.ID_PARAMETRO = @IdParametro
          AND p.EDITAVEL_ADMIN = 1;
        SET @Linhas = @@ROWCOUNT;

        IF @Linhas = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'O parâmetro foi alterado ou bloqueado por outra pessoa. Abra a tela de novo.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Parâmetro gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar o parâmetro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_PARAMETRO;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Log_Limpar_Processar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Log_Limpar_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Rotina diária (agenda das rotinas, etapa 02d): apaga do
                SIS.Log_Passo o que for mais antigo que LOG_PASSO_DIAS_RETENCAO
                (mínimo de segurança: 7 dias), em blocos de 5.000 linhas para
                não segurar a tabela.
                SIS.Log_Erro NÃO é apagado por esta rotina.
                Automação: em erro, registra em SIS.Log_Erro e relança.
                Devolve 1 linha: SUCESSO, MENSAGEM, QTD_EXCLUIDA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Log_Limpar_Processar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Log_Limpar_Processar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Log_Limpar_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Parâmetros';
    DECLARE @Dias       INT;
    DECLARE @Corte      DATETIME2(0);
    DECLARE @Bloco      INT           = 1;
    DECLARE @Total      INT           = 0;

    BEGIN TRY
        SET @Dias = SIS.fn_SIS_Parametro_Inteiro('LOG_PASSO_DIAS_RETENCAO');
        IF @Dias < 7 SET @Dias = 7;
        SET @Corte = DATEADD(DAY, -@Dias, SYSDATETIME());

        SET @EtapaAtual = 'Limpeza do Log_Passo';
        WHILE @Bloco > 0
        BEGIN
            DELETE TOP (5000) lp
            FROM SIS.Log_Passo lp
            WHERE lp.DT_PASSO < @Corte;

            SET @Bloco = @@ROWCOUNT;
            SET @Total = @Total + @Bloco;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Log de passos: ' + CONVERT(NVARCHAR(20), @Total) + N' linha(s) com mais de ' + CONVERT(NVARCHAR(10), @Dias) + N' dias excluída(s).' AS NVARCHAR(400)) AS MENSAGEM,
               @Total AS QTD_EXCLUIDA;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Licenca_Modulos_Aplicar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Licenca_Modulos_Aplicar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Acerta SIS.Modulo.LIBERADO_LICENCA pela licença ativa:
                liberado = módulo listado na licença ativa e dentro da
                validade; SIS sempre liberado. Sem licença ativa (ou vencida),
                só SIS fica liberado.
                Chamada por SIS_Licenca_Gravar, pelo fim do MASTER (módulo
                novo instalado já sai certo) e pela rotina diária (validade).
                Só altera os módulos que estão diferentes (regra 20).
                Automação: em erro, registra e relança.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Licenca_Modulos_Aplicar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Licenca_Modulos_Aplicar]
    @Usuario NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Licenca_Modulos_Aplicar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Aplicar módulos';
    DECLARE @Hoje       DATE          = CAST(SYSDATETIME() AS DATE);

    BEGIN TRY
        SET @Usuario = ISNULL(NULLIF(LTRIM(RTRIM(@Usuario)), N''), SIS.fn_SIS_Usuario_Atual());

        UPDATE m
           SET m.LIBERADO_LICENCA  = x.LIBERADO,
               m.DT_ALTERACAO      = SYSDATETIME(),
               m.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Modulo m
        CROSS APPLY (SELECT CAST(CASE WHEN m.CODIGO = 'SIS' THEN 1
                                      WHEN EXISTS (SELECT 1
                                                   FROM SIS.Licenca l
                                                   CROSS APPLY STRING_SPLIT(l.MODULOS, ',') s
                                                   WHERE l.ATIVA = 1
                                                     AND (l.DT_VALIDADE IS NULL OR l.DT_VALIDADE >= @Hoje)
                                                     AND LTRIM(RTRIM(s.value)) = m.CODIGO) THEN 1
                                      ELSE 0 END AS BIT) AS LIBERADO) x
        WHERE m.LIBERADO_LICENCA <> x.LIBERADO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Licenca_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Licenca_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Instala uma licença. A API chama SÓ DEPOIS de conferir a
                assinatura digital da chave com a chave pública embutida nela
                e de conferir que o servidor é o da licença; os demais
                parâmetros são o conteúdo já lido da chave.
                Tudo-ou-nada: desativa a licença anterior, grava a nova com as
                empresas e acerta os módulos liberados.
                @Modulos      : códigos separados por vírgula ("CAD,FIN,VENDA").
                                Código que ainda não existe neste banco é
                                guardado e avisado (módulo instalado depois
                                passa a valer sozinho, via
                                SIS_Licenca_Modulos_Aplicar no fim do MASTER).
                @EmpresasJson : [{"cnpj":"...","razao_social":"...",
                                  "nome_fantasia":"...","principal":true}, ...]
                                Sem nenhuma marcada como principal, a primeira
                                da lista vira a principal.
                Permissão: SIS_LICENCA / INCLUIR.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_LICENCA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Licenca_Gravar]
    @IdUsuario     INT,
    @ChaveLicenca  NVARCHAR(MAX),
    @IdServidor    VARCHAR(200),
    @DtEmissao     DATE,
    @DtValidade    DATE          = NULL,
    @Modulos       VARCHAR(400),
    @EmpresasJson  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc       NVARCHAR(128) = N'[SIS].[SIS_Licenca_Gravar]';
    DECLARE @EtapaAtual     VARCHAR(100)  = 'Validação';
    DECLARE @Recusa         NVARCHAR(400) = N'';
    DECLARE @Usuario        NVARCHAR(100);
    DECLARE @IdLicenca      INT;
    DECLARE @ModulosNorm    VARCHAR(400)  = '';
    DECLARE @Desconhecidos  VARCHAR(400)  = '';
    DECLARE @Hoje           DATE          = CAST(SYSDATETIME() AS DATE);

    DROP TABLE IF EXISTS #Emp;
    DROP TABLE IF EXISTS #Mod;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LICENCA', 'INCLUIR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para instalar licença.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_LICENCA;
            RETURN;
        END;

        SET @Usuario      = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @ChaveLicenca = LTRIM(RTRIM(ISNULL(@ChaveLicenca, N'')));
        SET @IdServidor   = LTRIM(RTRIM(ISNULL(@IdServidor, '')));

        IF @ChaveLicenca = N''                                     SET @Recusa = N'A chave da licença está vazia.';
        IF @Recusa = N'' AND @IdServidor = ''                      SET @Recusa = N'A licença não identifica o servidor autorizado.';
        IF @Recusa = N'' AND @DtEmissao IS NULL                    SET @Recusa = N'A licença não tem data de emissão.';
        IF @Recusa = N'' AND @DtValidade IS NOT NULL AND @DtValidade < @DtEmissao
                                                                   SET @Recusa = N'A validade da licença é anterior à emissão.';
        IF @Recusa = N'' AND @DtValidade IS NOT NULL AND @DtValidade < @Hoje
                                                                   SET @Recusa = N'Esta licença já está vencida.';
        IF @Recusa = N'' AND ISJSON(ISNULL(@EmpresasJson, N'')) = 0 SET @Recusa = N'A lista de empresas da licença é inválida.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_LICENCA;
            RETURN;
        END;

        IF EXISTS (SELECT 1 FROM SIS.Licenca l WHERE l.ATIVA = 1 AND l.CHAVE_LICENCA = @ChaveLicenca)
        BEGIN
            SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Esta licença já está instalada.' AS NVARCHAR(400)) AS MENSAGEM,
                   (SELECT l.ID_LICENCA FROM SIS.Licenca l WHERE l.ATIVA = 1) AS ID_LICENCA;
            RETURN;
        END;

        SET @EtapaAtual = 'Leitura das empresas';
        SELECT CAST(j.[key] AS INT) AS ORDEM,
               UPPER(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.cnpj, ''))), '.', ''), '/', ''), '-', ''), ' ', '')) AS CNPJ,
               LTRIM(RTRIM(ISNULL(e.razao_social, N'')))  AS RAZAO_SOCIAL,
               LTRIM(RTRIM(ISNULL(e.nome_fantasia, N''))) AS NOME_FANTASIA,
               ISNULL(e.principal, 0)                     AS PRINCIPAL
        INTO #Emp
        FROM OPENJSON(@EmpresasJson) j
        CROSS APPLY OPENJSON(j.value)
             WITH (cnpj          VARCHAR(30)   '$.cnpj',
                   razao_social  NVARCHAR(150) '$.razao_social',
                   nome_fantasia NVARCHAR(100) '$.nome_fantasia',
                   principal     BIT           '$.principal') e
        WHERE j.type = 5;   -- só objetos

        IF NOT EXISTS (SELECT 1 FROM #Emp)
            SET @Recusa = N'A licença não tem nenhuma empresa.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Emp e WHERE LEN(e.CNPJ) <> 14 OR e.CNPJ LIKE '%[^0-9A-Z]%')
            SET @Recusa = N'A licença tem CNPJ inválido.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Emp e WHERE e.RAZAO_SOCIAL = N'')
            SET @Recusa = N'A licença tem empresa sem razão social.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Emp e GROUP BY e.CNPJ HAVING COUNT(*) > 1)
            SET @Recusa = N'A licença repete o mesmo CNPJ.';
        IF @Recusa = N'' AND (SELECT COUNT(*) FROM #Emp e WHERE e.PRINCIPAL = 1) > 1
            SET @Recusa = N'A licença marca mais de uma empresa como principal.';

        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Emp;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_LICENCA;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM #Emp e WHERE e.PRINCIPAL = 1)
            UPDATE e SET e.PRINCIPAL = 1
            FROM #Emp e
            WHERE e.ORDEM = (SELECT MIN(x.ORDEM) FROM #Emp x);

        SET @EtapaAtual = 'Leitura dos módulos';
        SELECT DISTINCT UPPER(LTRIM(RTRIM(s.value))) AS CODIGO
        INTO #Mod
        FROM STRING_SPLIT(ISNULL(@Modulos, ''), ',') s
        WHERE LTRIM(RTRIM(s.value)) <> '';

        SELECT @ModulosNorm = ISNULL(STRING_AGG(CAST(md.CODIGO AS VARCHAR(400)), ',') WITHIN GROUP (ORDER BY md.CODIGO), '')
        FROM #Mod md;

        SELECT @Desconhecidos = ISNULL(STRING_AGG(CAST(md.CODIGO AS VARCHAR(400)), ', ') WITHIN GROUP (ORDER BY md.CODIGO), '')
        FROM #Mod md
        WHERE NOT EXISTS (SELECT 1 FROM SIS.Modulo m WHERE m.CODIGO = md.CODIGO);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            UPDATE l
               SET l.ATIVA             = 0,
                   l.DT_DESATIVACAO    = SYSDATETIME(),
                   l.DT_ALTERACAO      = SYSDATETIME(),
                   l.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Licenca l WITH (UPDLOCK, HOLDLOCK)
            WHERE l.ATIVA = 1;

            INSERT INTO SIS.Licenca (CHAVE_LICENCA, ID_SERVIDOR, DT_EMISSAO, DT_VALIDADE, MODULOS, ATIVA, USUARIO_CRIACAO)
            VALUES (@ChaveLicenca, @IdServidor, @DtEmissao, @DtValidade, ISNULL(@ModulosNorm, ''), 1, ISNULL(@Usuario, N''));
            SET @IdLicenca = CAST(SCOPE_IDENTITY() AS INT);

            INSERT INTO SIS.Licenca_Empresa (ID_LICENCA, CNPJ, RAZAO_SOCIAL, NOME_FANTASIA, PRINCIPAL, USUARIO_CRIACAO)
            SELECT @IdLicenca, e.CNPJ, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.PRINCIPAL, ISNULL(@Usuario, N'')
            FROM #Emp e;

            EXEC SIS.SIS_Licenca_Modulos_Aplicar @Usuario = @Usuario;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Emp;
        DROP TABLE IF EXISTS #Mod;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Licença instalada.'
                    + CASE WHEN @Desconhecidos <> '' THEN N' Módulos ainda não instalados neste banco (passam a valer quando forem instalados): ' + @Desconhecidos + N'.' ELSE N'' END
                    AS NVARCHAR(400)) AS MENSAGEM,
               @IdLicenca AS ID_LICENCA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Emp;
            DROP TABLE IF EXISTS #Mod;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível instalar a licença. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_LICENCA;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Licenca_Obter.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Licenca_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Licença ativa, para a API conferir a assinatura ao iniciar e a
                cada login, e para a tela "Licença" mostrar o que está liberado.
                Sempre devolve 1 linha: ENCONTRADA = 0 quando não há licença.
                EMPRESAS_JSON: [{"CNPJ":"...","RAZAO_SOCIAL":"...",
                "NOME_FANTASIA":"...","PRINCIPAL":true}].
                Sem conferência de permissão: a API precisa ler antes de haver
                usuário logado, e nada aqui é segredo (a chave é assinada,
                não é senha).
                Padrão "Listar": THROW 50001 com mensagem amigável em erro.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Licenca_Obter;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Licenca_Obter]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Licenca_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Consulta';

    BEGIN TRY
        SELECT CAST(CASE WHEN l.ID_LICENCA IS NULL THEN 0 ELSE 1 END AS BIT) AS ENCONTRADA,
               l.ID_LICENCA,
               ISNULL(l.CHAVE_LICENCA, N'')     AS CHAVE_LICENCA,
               ISNULL(l.ID_SERVIDOR, '')        AS ID_SERVIDOR,
               l.DT_EMISSAO,
               l.DT_VALIDADE,
               ISNULL(l.MODULOS, '')            AS MODULOS,
               l.DT_CRIACAO                     AS DT_INSTALACAO,
               ISNULL(l.USUARIO_CRIACAO, N'')   AS USUARIO_INSTALACAO,
               ISNULL((SELECT e.CNPJ, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.PRINCIPAL
                       FROM SIS.Licenca_Empresa e WITH (NOLOCK)
                       WHERE e.ID_LICENCA = l.ID_LICENCA
                       ORDER BY e.PRINCIPAL DESC, e.RAZAO_SOCIAL
                       FOR JSON PATH), N'[]')   AS EMPRESAS_JSON
        FROM (SELECT 1 AS X) d
        LEFT JOIN SIS.Licenca l WITH (NOLOCK) ON l.ATIVA = 1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível ler a licença. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Login_Obter.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Login_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : 1º passo do login (uso exclusivo da API, nunca vai para a
                tela): devolve hash, salt, iterações e algoritmo da senha do
                login informado, para a API conferir a senha digitada.
                Sempre devolve 1 linha; ENCONTRADO = 0 para login inexistente
                ou usuário interno. Mesmo nesse caso a API calcula um hash
                qualquer, para o tempo de resposta não revelar se o login
                existe. O resultado vai para SIS_Usuario_Login_Processar.
                Não confere ativo/bloqueado: isso é do 2º passo, que registra
                a tentativa.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Usuario_Login_Obter @Login = N'admin';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Login_Obter]
    @Login NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Usuario_Login_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Consulta';

    BEGIN TRY
        SET @Login = LOWER(LTRIM(RTRIM(ISNULL(@Login, N''))));

        SELECT CAST(CASE WHEN u.ID_USUARIO IS NULL THEN 0 ELSE 1 END AS BIT) AS ENCONTRADO,
               u.ID_USUARIO,
               u.SENHA_HASH,
               u.SENHA_SALT,
               ISNULL(u.SENHA_ITERACOES, 0)  AS SENHA_ITERACOES,
               ISNULL(u.SENHA_ALGORITMO, '') AS SENHA_ALGORITMO
        FROM (SELECT 1 AS X) d
        LEFT JOIN SIS.Usuario u ON u.LOGIN = @Login AND u.INTERNO = 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível conferir o login. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Login_Processar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Login_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : 2º passo do login (uso exclusivo da API). A API informa se a
                senha conferiu (@SenhaConferida) e, se conferiu, o SHA-256 do
                token de sessão que vai no cookie (@TokenHash, 32 bytes).
                Regras:
                  - login inexistente/interno ou inativo: recusa genérica;
                  - bloqueado ou sem senha definida: recusa com o motivo;
                  - senha errada: soma tentativa; ao chegar no limite
                    SENHA_TENTATIVAS_BLOQUEIO (mínimo 3), bloqueia;
                  - senha certa: zera tentativas, abre a sessão;
                  - computador (IP) com LOGIN_COMPUTADOR_TENTATIVAS erros
                    seguidos (qualquer usuário, inclusive inexistente) nos
                    últimos LOGIN_COMPUTADOR_MINUTOS: recusa sem olhar a
                    senha nem contar tentativa no usuário (ESTACAO_BLOQUEADA),
                    até passar o tempo. Um login certo zera a contagem.
                Toda tentativa vai para SIS.Login_Log.
                Recusa antes de gravar: COMMIT (nada foi alterado), para a
                procedure funcionar também dentro de INSERT ... EXEC.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO, ID_SESSAO,
                NOME, TROCAR_SENHA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (20/11/2026) - Etapa 03d: limite de tentativas por computador.

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Login_Processar]
    @Login           NVARCHAR(100),
    @SenhaConferida  BIT,
    @TokenHash       VARBINARY(32)  = NULL,
    @Ip              VARCHAR(45)    = NULL,
    @Estacao         NVARCHAR(128)  = NULL,
    @Navegador       NVARCHAR(300)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Usuario_Login_Processar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Limite       INT;
    DECLARE @IdUsuario    INT;
    DECLARE @Ativo        BIT;
    DECLARE @Bloqueado    BIT;
    DECLARE @TemSenha     BIT;
    DECLARE @Tentativas   SMALLINT;
    DECLARE @Nome         NVARCHAR(100);
    DECLARE @TrocarSenha  BIT;
    DECLARE @Resultado    VARCHAR(20)   = '';
    DECLARE @Mensagem     NVARCHAR(400) = N'';
    DECLARE @IdSessao     BIGINT;
    DECLARE @LimiteIp     INT;
    DECLARE @MinutosIp    INT;
    DECLARE @ErrosIp      INT = 0;

    BEGIN TRY
        SET @Login          = LOWER(LTRIM(RTRIM(ISNULL(@Login, N''))));
        SET @SenhaConferida = ISNULL(@SenhaConferida, 0);
        SET @Ip             = ISNULL(@Ip, '');
        SET @Estacao        = ISNULL(@Estacao, N'');
        SET @Navegador      = ISNULL(@Navegador, N'');
        SET @Limite         = SIS.fn_SIS_Parametro_Inteiro('SENHA_TENTATIVAS_BLOQUEIO');
        IF @Limite < 3 SET @Limite = 3;
        SET @LimiteIp       = ISNULL(SIS.fn_SIS_Parametro_Inteiro('LOGIN_COMPUTADOR_TENTATIVAS'), 10);
        IF @LimiteIp < 5 SET @LimiteIp = 5;
        SET @MinutosIp      = ISNULL(SIS.fn_SIS_Parametro_Inteiro('LOGIN_COMPUTADOR_MINUTOS'), 15);
        IF @MinutosIp < 1 SET @MinutosIp = 1;

        IF @SenhaConferida = 1 AND DATALENGTH(ISNULL(@TokenHash, 0x)) <> 32
        BEGIN
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, ORIGEM)
            VALUES (@NomeProc, @EtapaAtual, 0, N'Token de sessão inválido recebido da API (precisa ter 32 bytes).', 0, 'SQL');
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Falha técnica no login. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
            RETURN;
        END;

        SET @EtapaAtual = 'Processamento';
        BEGIN TRANSACTION;

            SELECT @IdUsuario   = u.ID_USUARIO,
                   @Ativo       = u.ATIVO,
                   @Bloqueado   = u.BLOQUEADO,
                   @TemSenha    = CASE WHEN u.SENHA_HASH IS NULL THEN 0 ELSE 1 END,
                   @Tentativas  = u.TENTATIVAS_ERRADAS,
                   @Nome        = u.NOME,
                   @TrocarSenha = u.TROCAR_SENHA
            FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK)
            WHERE u.LOGIN = @Login
              AND u.INTERNO = 0;

            -- Computador que errou demais: espera, sem olhar a senha nem contar no usuário
            IF @Ip <> ''
                SELECT @ErrosIp = COUNT(*)
                FROM SIS.Login_Log l
                WHERE l.IP = @Ip
                  AND l.DT_TENTATIVA >= DATEADD(MINUTE, -@MinutosIp, SYSDATETIME())
                  AND l.RESULTADO IN ('SENHA_ERRADA', 'BLOQUEOU', 'INEXISTENTE', 'INATIVO')
                  AND l.ID_LOGIN_LOG > ISNULL((SELECT MAX(o.ID_LOGIN_LOG) FROM SIS.Login_Log o WHERE o.IP = @Ip AND o.RESULTADO = 'OK'), 0);

            IF @ErrosIp >= @LimiteIp
            BEGIN
                SET @Resultado = 'ESTACAO_BLOQUEADA';
                SET @Mensagem  = N'Muitas tentativas de login erradas neste computador. Aguarde ' + CONVERT(NVARCHAR(10), @MinutosIp) + N' minutos e tente de novo.';
            END;

            IF @Resultado = '' AND @IdUsuario IS NULL
            BEGIN
                SET @Resultado = 'INEXISTENTE';
                SET @Mensagem  = N'Usuário ou senha inválidos.';
            END;

            IF @Resultado = '' AND @Ativo = 0
            BEGIN
                SET @Resultado = 'INATIVO';
                SET @Mensagem  = CASE WHEN @SenhaConferida = 1 THEN N'Usuário inativo. Procure o administrador do sistema.' ELSE N'Usuário ou senha inválidos.' END;
            END;

            IF @Resultado = '' AND @Bloqueado = 1
            BEGIN
                SET @Resultado = 'BLOQUEADO';
                SET @Mensagem  = N'Usuário bloqueado por excesso de tentativas. Procure o administrador do sistema.';
            END;

            IF @Resultado = '' AND @TemSenha = 0
            BEGIN
                SET @Resultado = 'SEM_SENHA';
                SET @Mensagem  = N'A senha deste usuário ainda não foi definida. Procure o administrador do sistema.';
            END;

            IF @Resultado = '' AND @SenhaConferida = 0
            BEGIN
                SET @Tentativas = @Tentativas + 1;

                UPDATE u
                   SET u.TENTATIVAS_ERRADAS = @Tentativas,
                       u.BLOQUEADO          = CASE WHEN @Tentativas >= @Limite THEN 1 ELSE 0 END,
                       u.DT_BLOQUEIO        = CASE WHEN @Tentativas >= @Limite THEN SYSDATETIME() ELSE u.DT_BLOQUEIO END
                FROM SIS.Usuario u
                WHERE u.ID_USUARIO = @IdUsuario;

                SET @Resultado = CASE WHEN @Tentativas >= @Limite THEN 'BLOQUEOU' ELSE 'SENHA_ERRADA' END;
                SET @Mensagem  = CASE WHEN @Tentativas >= @Limite
                                      THEN N'Senha incorreta. O usuário foi bloqueado após ' + CONVERT(NVARCHAR(10), @Limite) + N' tentativas. Procure o administrador do sistema.'
                                      ELSE N'Usuário ou senha inválidos. Restam ' + CONVERT(NVARCHAR(10), @Limite - @Tentativas) + N' tentativa(s) antes do bloqueio.'
                                 END;
            END;

            IF @Resultado = ''
            BEGIN
                UPDATE u
                   SET u.TENTATIVAS_ERRADAS = 0,
                       u.DT_ULTIMO_LOGIN    = SYSDATETIME()
                FROM SIS.Usuario u
                WHERE u.ID_USUARIO = @IdUsuario;

                INSERT INTO SIS.Sessao (ID_USUARIO, TOKEN_HASH, IP, ESTACAO, NAVEGADOR)
                VALUES (@IdUsuario, @TokenHash, @Ip, @Estacao, @Navegador);
                SET @IdSessao = CAST(SCOPE_IDENTITY() AS BIGINT);

                SET @Resultado = 'OK';
                SET @Mensagem  = CASE WHEN @TrocarSenha = 1 THEN N'Bem-vindo. Defina uma nova senha para continuar.' ELSE N'Bem-vindo.' END;
            END;

            INSERT INTO SIS.Login_Log (LOGIN_INFORMADO, ID_USUARIO, RESULTADO, IP, ESTACAO)
            VALUES (LEFT(@Login, 100), @IdUsuario, @Resultado, @Ip, @Estacao);

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Resultado = 'OK' THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(@Mensagem AS NVARCHAR(400)) AS MENSAGEM,
               CAST(CASE WHEN @Resultado = 'OK' THEN @IdUsuario END AS INT) AS ID_USUARIO,
               @IdSessao AS ID_SESSAO,
               CAST(CASE WHEN @Resultado = 'OK' THEN ISNULL(@Nome, N'') ELSE N'' END AS NVARCHAR(100)) AS NOME,
               CAST(CASE WHEN @Resultado = 'OK' THEN ISNULL(@TrocarSenha, 0) ELSE 0 END AS BIT) AS TROCAR_SENHA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível fazer o login. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Sessao_Validar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Sessao_Validar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : A API chama a cada requisição com o SHA-256 do token do
                cookie. Confere se a sessão está aberta, se o usuário continua
                ativo e desbloqueado e se não passou do tempo de inatividade
                (SESSAO_MINUTOS_INATIVIDADE, mínimo 5). Fecha a sessão quando
                não vale mais (MOTIVO_FIM EXPIRADA / INATIVADO / BLOQUEIO).
                Atualiza DT_ULTIMO_ACESSO no máximo uma vez por minuto (evita
                gravar a cada clique).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO, ID_SESSAO,
                LOGIN, NOME, TROCAR_SENHA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Sessao_Validar]
    @TokenHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[SIS].[SIS_Sessao_Validar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Consulta';
    DECLARE @Minutos       INT;
    DECLARE @Agora         DATETIME2(0)  = SYSDATETIME();
    DECLARE @IdSessao      BIGINT;
    DECLARE @IdUsuario     INT;
    DECLARE @UltimoAcesso  DATETIME2(0);
    DECLARE @Ativo         BIT;
    DECLARE @Bloqueado     BIT;
    DECLARE @Login         NVARCHAR(100);
    DECLARE @Nome          NVARCHAR(100);
    DECLARE @TrocarSenha   BIT;
    DECLARE @Motivo        VARCHAR(20)   = '';
    DECLARE @Mensagem      NVARCHAR(400) = N'';

    BEGIN TRY
        SET @Minutos = SIS.fn_SIS_Parametro_Inteiro('SESSAO_MINUTOS_INATIVIDADE');
        IF @Minutos < 5 SET @Minutos = 5;

        SELECT @IdSessao     = s.ID_SESSAO,
               @IdUsuario    = s.ID_USUARIO,
               @UltimoAcesso = s.DT_ULTIMO_ACESSO,
               @Ativo        = u.ATIVO,
               @Bloqueado    = u.BLOQUEADO,
               @Login        = CONVERT(NVARCHAR(100), u.LOGIN),
               @Nome         = u.NOME,
               @TrocarSenha  = u.TROCAR_SENHA
        FROM SIS.Sessao s
        INNER JOIN SIS.Usuario u ON u.ID_USUARIO = s.ID_USUARIO
        WHERE s.TOKEN_HASH = @TokenHash
          AND s.DT_FIM IS NULL;

        IF @IdSessao IS NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Sessão encerrada. Entre novamente.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS LOGIN,
                   CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
            RETURN;
        END;

        IF @Ativo = 0                                               SELECT @Motivo = 'INATIVADO', @Mensagem = N'Usuário inativo. Procure o administrador do sistema.';
        IF @Motivo = '' AND @Bloqueado = 1                          SELECT @Motivo = 'BLOQUEIO',  @Mensagem = N'Usuário bloqueado. Procure o administrador do sistema.';
        IF @Motivo = '' AND @UltimoAcesso < DATEADD(MINUTE, -@Minutos, @Agora)
                                                                    SELECT @Motivo = 'EXPIRADA',  @Mensagem = N'Sessão expirada por falta de uso. Entre novamente.';

        SET @EtapaAtual = 'Atualização';
        IF @Motivo <> ''
        BEGIN
            UPDATE s SET s.DT_FIM = @Agora, s.MOTIVO_FIM = @Motivo
            FROM SIS.Sessao s
            WHERE s.ID_SESSAO = @IdSessao AND s.DT_FIM IS NULL;

            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Mensagem AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS LOGIN,
                   CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
            RETURN;
        END;

        UPDATE s SET s.DT_ULTIMO_ACESSO = @Agora
        FROM SIS.Sessao s
        WHERE s.ID_SESSAO = @IdSessao
          AND s.DT_FIM IS NULL
          AND s.DT_ULTIMO_ACESSO < DATEADD(MINUTE, -1, @Agora);

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'' AS NVARCHAR(400)) AS MENSAGEM,
               @IdUsuario AS ID_USUARIO, @IdSessao AS ID_SESSAO, ISNULL(@Login, N'') AS LOGIN,
               ISNULL(@Nome, N'') AS NOME, ISNULL(@TrocarSenha, 0) AS TROCAR_SENHA;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível conferir a sessão. Entre novamente.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS LOGIN,
               CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Sessao_Encerrar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Sessao_Encerrar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Encerra a sessão do token (botão "Sair"). Pode ser chamada de
                novo sem erro: sessão já encerrada continua como estava.
                @Motivo: LOGOUT (padrão) ou ADMIN.
                Devolve 1 linha: SUCESSO, MENSAGEM.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Sessao_Encerrar]
    @TokenHash  VARBINARY(32),
    @Motivo     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Sessao_Encerrar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Encerramento';

    BEGIN TRY
        SET @Motivo = UPPER(ISNULL(NULLIF(LTRIM(RTRIM(@Motivo)), ''), 'LOGOUT'));
        IF @Motivo NOT IN ('LOGOUT', 'ADMIN') SET @Motivo = 'LOGOUT';

        UPDATE s SET s.DT_FIM = SYSDATETIME(), s.MOTIVO_FIM = @Motivo
        FROM SIS.Sessao s
        WHERE s.TOKEN_HASH = @TokenHash
          AND s.DT_FIM IS NULL;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Sessão encerrada.' AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível encerrar a sessão. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Lista de usuários da tela "Usuários" (sem o usuário interno; usuários
                do administrador geral só aparecem para o administrador geral).
                @Texto procura em login, nome e e-mail. @SomenteAtivos = 1
                (padrão) esconde os desativados.
                Permissão: SIS_USUARIO / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: quem não é nível 2 não vê
                        usuários de nível 2; devolve PERFIL_NIVEL_ADMIN.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Usuario_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Listar]
    @IdUsuario      INT,
    @Texto          NVARCHAR(100) = NULL,
    @SomenteAtivos  BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Usuario_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Nivel      TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os usuários.', 1;

        SET @Texto         = NULLIF(LTRIM(RTRIM(@Texto)), N'');
        SET @SomenteAtivos = ISNULL(@SomenteAtivos, 1);

        SET @EtapaAtual = 'Consulta';
        SELECT u.ID_USUARIO,
               CONVERT(NVARCHAR(40), u.LOGIN) AS LOGIN,
               u.NOME,
               u.EMAIL,
               u.ID_PERFIL,
               p.NOME                                                AS PERFIL_NOME,
               p.NIVEL_ADMIN                                         AS PERFIL_NIVEL_ADMIN,
               u.ATIVO,
               u.BLOQUEADO,
               u.TROCAR_SENHA,
               CAST(CASE WHEN u.SENHA_HASH IS NULL THEN 0 ELSE 1 END AS BIT) AS TEM_SENHA,
               u.DT_ULTIMO_LOGIN,
               (SELECT COUNT(*) FROM SIS.Usuario_Permissao up WITH (NOLOCK) WHERE up.ID_USUARIO = u.ID_USUARIO) AS QTD_EXCECOES
        FROM SIS.Usuario u WITH (NOLOCK)
        INNER JOIN SIS.Perfil p WITH (NOLOCK) ON p.ID_PERFIL = u.ID_PERFIL
        WHERE u.INTERNO = 0
          AND (p.NIVEL_ADMIN < 2 OR @Nivel = 2)
          AND (@SomenteAtivos = 0 OR u.ATIVO = 1)
          AND (@Texto IS NULL OR u.LOGIN LIKE N'%' + @Texto + N'%' OR u.NOME LIKE N'%' + @Texto + N'%' OR u.EMAIL LIKE N'%' + @Texto + N'%')
        ORDER BY u.NOME
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os usuários. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Obter.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Um usuário, para a tela de manutenção (ou para "Meus dados":
                o próprio usuário sempre pode ver o seu cadastro).
                Nunca devolve hash nem salt da senha.
                Permissão: SIS_USUARIO / VER (ou o próprio usuário).
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: quem não é nível 2 não vê
                        usuário de nível 2 (só o próprio); PERFIL_NIVEL_ADMIN.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Usuario_Obter @IdUsuario = 2, @IdUsuarioConsulta = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Obter]
    @IdUsuario          INT,
    @IdUsuarioConsulta  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Usuario_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Nivel      TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);

    BEGIN TRY
        IF ISNULL(@IdUsuario, 0) <> ISNULL(@IdUsuarioConsulta, -1)
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os usuários.', 1;

        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK)
                       INNER JOIN SIS.Perfil p WITH (NOLOCK) ON p.ID_PERFIL = u.ID_PERFIL
                       WHERE u.ID_USUARIO = @IdUsuarioConsulta AND u.INTERNO = 0
                         AND (p.NIVEL_ADMIN < 2 OR @Nivel = 2 OR u.ID_USUARIO = @IdUsuario))
            THROW 50001, N'Usuário não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT u.ID_USUARIO,
               CONVERT(NVARCHAR(40), u.LOGIN) AS LOGIN,
               u.NOME,
               u.EMAIL,
               u.ID_PERFIL,
               p.NOME                                                AS PERFIL_NOME,
               p.NIVEL_ADMIN                                         AS PERFIL_NIVEL_ADMIN,
               u.ATIVO,
               u.BLOQUEADO,
               u.DT_BLOQUEIO,
               u.TENTATIVAS_ERRADAS,
               u.TROCAR_SENHA,
               CAST(CASE WHEN u.SENHA_HASH IS NULL THEN 0 ELSE 1 END AS BIT) AS TEM_SENHA,
               u.DT_SENHA,
               u.DT_ULTIMO_LOGIN,
               u.DT_CRIACAO,
               u.USUARIO_CRIACAO,
               u.DT_ALTERACAO,
               ISNULL(u.USUARIO_ALTERACAO, N'')                      AS USUARIO_ALTERACAO
        FROM SIS.Usuario u WITH (NOLOCK)
        INNER JOIN SIS.Perfil p WITH (NOLOCK) ON p.ID_PERFIL = u.ID_PERFIL
        WHERE u.ID_USUARIO = @IdUsuarioConsulta;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o usuário. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Inclui (@IdUsuarioAlvo NULL) ou altera um usuário: login,
                nome, e-mail, perfil e ativo. A senha é gravada à parte
                (SIS_Usuario_Senha_Gravar): usuário novo nasce sem senha e
                com troca obrigatória no primeiro acesso.
                Regras:
                  - login: 3 a 40 caracteres, minúsculas, dígitos, ". _ -";
                    único (conferido com UPDLOCK, HOLDLOCK);
                  - perfil precisa existir e estar ativo;
                  - ninguém desativa o próprio usuário;
                  - perfil de nível 2 (administrador geral) só é dado, e
                    usuário de nível 2 só é alterado, pelo administrador geral;
                  - quem tira um administrador (desativa ou baixa o nível)
                    precisa deixar outro usuário ativo com nível igual ou
                    maior;
                  - desativar encerra as sessões abertas do usuário.
                Permissão: SIS_USUARIO / INCLUIR ou ALTERAR.
                Recusa antes de gravar: COMMIT (nada foi alterado).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: só o nível 2 vê/altera
                        usuário de nível 2 e dá perfil de nível 2; sempre sobra
                        um usuário ativo em cada nível de administrador em uso.
    v1.2 (15/11/2026) - Correção: login com "_" era recusado (mesmo defeito do
                        padrão "[^...._-]" do LIKE).

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Gravar]
    @IdUsuario      INT,
    @IdUsuarioAlvo  INT            = NULL,
    @Login          VARCHAR(40),
    @Nome           NVARCHAR(100),
    @Email          NVARCHAR(200)  = NULL,
    @IdPerfil       INT,
    @Ativo          BIT            = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc        NVARCHAR(128) = N'[SIS].[SIS_Usuario_Gravar]';
    DECLARE @EtapaAtual      VARCHAR(100)  = 'Validação';
    DECLARE @Recusa          NVARCHAR(400) = N'';
    DECLARE @Usuario         NVARCHAR(100);
    DECLARE @Incluir         BIT           = CASE WHEN @IdUsuarioAlvo IS NULL THEN 1 ELSE 0 END;
    DECLARE @NivelNovo       TINYINT;
    DECLARE @NivelAtual      TINYINT       = 0;
    DECLARE @NivelAlvo       TINYINT;
    DECLARE @Nivel           TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);
    DECLARE @IdGravado       INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', CASE WHEN @Incluir = 1 THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Incluir = 1 THEN N'Você não tem permissão para incluir usuários.' ELSE N'Você não tem permissão para alterar usuários.' END AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_USUARIO;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Login   = LOWER(LTRIM(RTRIM(ISNULL(@Login, ''))));
        SET @Nome    = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Email   = LOWER(LTRIM(RTRIM(ISNULL(@Email, N''))));
        SET @Ativo   = ISNULL(@Ativo, 1);

        IF LEN(@Login) < 3 OR REPLACE(REPLACE(REPLACE(@Login, '.', ''), '_', ''), '-', '') LIKE '%[^a-z0-9]%' COLLATE Latin1_General_BIN2
            SET @Recusa = N'Login inválido: use de 3 a 40 letras minúsculas, números, ponto, hífen ou sublinhado (sem espaço e sem acento).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome do usuário.';
        IF @Recusa = N'' AND @Email <> N''
           AND (@Email NOT LIKE N'%_@_%._%' OR @Email LIKE N'% %' OR @Email LIKE N'%;%' OR @Email LIKE N'%,%' OR @Email LIKE N'%@%@%')
            SET @Recusa = N'Informe um e-mail válido (ou deixe em branco).';

        SELECT @NivelNovo = p.NIVEL_ADMIN
        FROM SIS.Perfil p
        WHERE p.ID_PERFIL = @IdPerfil
          AND p.ATIVO = 1;

        IF @Recusa = N'' AND (@NivelNovo IS NULL OR (@NivelNovo = 2 AND @Nivel < 2))
            SET @Recusa = N'Escolha um perfil ativo.';

        IF @Recusa = N'' AND @Incluir = 0
        BEGIN
            SELECT @NivelAlvo = p.NIVEL_ADMIN
            FROM SIS.Usuario u
            INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
            WHERE u.ID_USUARIO = @IdUsuarioAlvo AND u.INTERNO = 0;

            IF @NivelAlvo IS NULL OR (@NivelAlvo = 2 AND @Nivel < 2)
                SET @Recusa = N'Usuário não encontrado.';
        END;

        IF @Recusa = N'' AND @Incluir = 0 AND @IdUsuarioAlvo = @IdUsuario AND @Ativo = 0
            SET @Recusa = N'Você não pode desativar o seu próprio usuário.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdUsuarioAlvo AS ID_USUARIO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK)
                       WHERE u.LOGIN = @Login AND u.ID_USUARIO <> ISNULL(@IdUsuarioAlvo, 0))
                SET @Recusa = N'Já existe um usuário com o login "' + CONVERT(NVARCHAR(40), @Login) + N'".';

            IF @Recusa = N'' AND @Incluir = 0
            BEGIN
                SELECT @NivelAtual = CASE WHEN u.ATIVO = 1 THEN p.NIVEL_ADMIN ELSE 0 END
                FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK)
                INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                WHERE u.ID_USUARIO = @IdUsuarioAlvo;

                IF @NivelAtual >= 1 AND (@Ativo = 0 OR @NivelNovo < @NivelAtual)
                   AND NOT EXISTS (SELECT 1
                                   FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK)
                                   INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                                   WHERE u.ID_USUARIO <> @IdUsuarioAlvo
                                     AND u.INTERNO = 0
                                     AND u.ATIVO = 1
                                     AND p.ATIVO = 1
                                     AND p.NIVEL_ADMIN >= @NivelAtual)
                    SET @Recusa = CASE WHEN @NivelAtual = 2
                                       THEN N'Este é o único administrador geral ativo: não é possível mudar o perfil nem desativar.'
                                       ELSE N'Este é o único administrador ativo: cadastre outro administrador antes de mudar o perfil ou desativar este usuário.' END;
            END;

            IF @Recusa <> N''
            BEGIN
                COMMIT TRANSACTION;   -- nada foi gravado; só libera as travas
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdUsuarioAlvo AS ID_USUARIO;
                RETURN;
            END;

            IF @Incluir = 1
            BEGIN
                INSERT INTO SIS.Usuario (LOGIN, NOME, EMAIL, ID_PERFIL, TROCAR_SENHA, ATIVO, USUARIO_CRIACAO)
                VALUES (@Login, @Nome, @Email, @IdPerfil, 1, @Ativo, ISNULL(@Usuario, N''));
                SET @IdGravado = CAST(SCOPE_IDENTITY() AS INT);
            END
            ELSE
            BEGIN
                UPDATE u
                   SET u.LOGIN             = @Login,
                       u.NOME              = @Nome,
                       u.EMAIL             = @Email,
                       u.ID_PERFIL         = @IdPerfil,
                       u.ATIVO             = @Ativo,
                       u.DT_ALTERACAO      = SYSDATETIME(),
                       u.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Usuario u
                WHERE u.ID_USUARIO = @IdUsuarioAlvo;
                SET @IdGravado = @IdUsuarioAlvo;

                IF @Ativo = 0
                    UPDATE s SET s.DT_FIM = SYSDATETIME(), s.MOTIVO_FIM = 'INATIVADO'
                    FROM SIS.Sessao s
                    WHERE s.ID_USUARIO = @IdUsuarioAlvo
                      AND s.DT_FIM IS NULL;
            END;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Incluir = 1 THEN N'Usuário incluído. Defina agora a senha provisória.' ELSE N'Usuário gravado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdGravado AS ID_USUARIO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar o usuário. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_USUARIO;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Senha_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Senha_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Grava a senha de um usuário. O banco recebe só o resultado do
                PBKDF2-SHA256 calculado pela API (hash de 32 bytes, salt de
                16+ bytes, iterações >= SENHA_PBKDF2_ITERACOES, mínimo
                100.000). Tamanho mínimo e regras da senha digitada são
                conferidos pela API antes do hash (SENHA_TAMANHO_MINIMO).
                Dois casos:
                  - o próprio usuário troca a sua senha (a API já conferiu a
                    senha atual): TROCAR_SENHA = 0;
                  - outro (administrador) define senha provisória: precisa de
                    SIS_USUARIO / REDEFINIR_SENHA; TROCAR_SENHA = 1, zera as
                    tentativas, desbloqueia e encerra as sessões do usuário.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: só o nível 2 define senha
                        de usuário de nível 2.

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Senha_Gravar]
    @IdUsuario      INT,
    @IdUsuarioAlvo  INT,
    @SenhaHash      VARBINARY(64),
    @SenhaSalt      VARBINARY(64),
    @Iteracoes      INT,
    @Algoritmo      VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Usuario_Senha_Gravar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @Propria      BIT           = CASE WHEN @IdUsuario = @IdUsuarioAlvo THEN 1 ELSE 0 END;
    DECLARE @MinIteracoes INT;
    DECLARE @Nivel        TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);

    BEGIN TRY
        IF @Propria = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'REDEFINIR_SENHA') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para definir a senha de outro usuário.' AS NVARCHAR(400)) AS MENSAGEM, @IdUsuarioAlvo AS ID_USUARIO;
            RETURN;
        END;

        SET @Usuario      = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Algoritmo    = UPPER(LTRIM(RTRIM(ISNULL(@Algoritmo, ''))));
        SET @MinIteracoes = SIS.fn_SIS_Parametro_Inteiro('SENHA_PBKDF2_ITERACOES');
        IF @MinIteracoes < 100000 SET @MinIteracoes = 100000;

        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u
                       INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                       WHERE u.ID_USUARIO = @IdUsuarioAlvo AND u.INTERNO = 0 AND u.ATIVO = 1
                         AND (p.NIVEL_ADMIN < 2 OR @Nivel = 2 OR @Propria = 1))
            SET @Recusa = N'Usuário não encontrado ou inativo.';
        IF @Recusa = N'' AND @Algoritmo <> 'PBKDF2-SHA256'
            SET @Recusa = N'Falha técnica: algoritmo de senha não suportado.';
        IF @Recusa = N'' AND DATALENGTH(ISNULL(@SenhaHash, 0x)) <> 32
            SET @Recusa = N'Falha técnica: hash de senha inválido.';
        IF @Recusa = N'' AND DATALENGTH(ISNULL(@SenhaSalt, 0x)) < 16
            SET @Recusa = N'Falha técnica: salt de senha inválido.';
        IF @Recusa = N'' AND ISNULL(@Iteracoes, 0) < @MinIteracoes
            SET @Recusa = N'Falha técnica: quantidade de iterações da senha abaixo do mínimo.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdUsuarioAlvo AS ID_USUARIO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            UPDATE u
               SET u.SENHA_HASH         = @SenhaHash,
                   u.SENHA_SALT         = @SenhaSalt,
                   u.SENHA_ITERACOES    = @Iteracoes,
                   u.SENHA_ALGORITMO    = @Algoritmo,
                   u.DT_SENHA           = SYSDATETIME(),
                   u.TROCAR_SENHA       = CASE WHEN @Propria = 1 THEN 0 ELSE 1 END,
                   u.TENTATIVAS_ERRADAS = CASE WHEN @Propria = 1 THEN u.TENTATIVAS_ERRADAS ELSE 0 END,
                   u.BLOQUEADO          = CASE WHEN @Propria = 1 THEN u.BLOQUEADO ELSE 0 END,
                   u.DT_BLOQUEIO        = CASE WHEN @Propria = 1 THEN u.DT_BLOQUEIO ELSE NULL END,
                   u.DT_ALTERACAO       = SYSDATETIME(),
                   u.USUARIO_ALTERACAO  = @Usuario
            FROM SIS.Usuario u
            WHERE u.ID_USUARIO = @IdUsuarioAlvo;

            IF @Propria = 0
                UPDATE s SET s.DT_FIM = SYSDATETIME(), s.MOTIVO_FIM = 'SENHA_ALTERADA'
                FROM SIS.Sessao s
                WHERE s.ID_USUARIO = @IdUsuarioAlvo
                  AND s.DT_FIM IS NULL;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Propria = 1 THEN N'Senha alterada.' ELSE N'Senha provisória definida. O usuário vai trocá-la no próximo acesso.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdUsuarioAlvo AS ID_USUARIO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar a senha. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdUsuarioAlvo AS ID_USUARIO;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Desbloquear.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Desbloquear]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Desbloqueia um usuário bloqueado por excesso de tentativas e
                zera o contador. A senha continua a mesma (se o usuário
                esqueceu, usar SIS_Usuario_Senha_Gravar, que também
                desbloqueia).
                Permissão: SIS_USUARIO / DESBLOQUEAR.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: só o nível 2 desbloqueia
                        usuário de nível 2.

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Desbloquear]
    @IdUsuario      INT,
    @IdUsuarioAlvo  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Usuario_Desbloquear]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Linhas     INT           = 0;
    DECLARE @Nivel      TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'DESBLOQUEAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para desbloquear usuários.' AS NVARCHAR(400)) AS MENSAGEM, @IdUsuarioAlvo AS ID_USUARIO;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u
                       INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                       WHERE u.ID_USUARIO = @IdUsuarioAlvo AND u.INTERNO = 0
                         AND (p.NIVEL_ADMIN < 2 OR @Nivel = 2))
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Usuário não encontrado.' AS NVARCHAR(400)) AS MENSAGEM, @IdUsuarioAlvo AS ID_USUARIO;
            RETURN;
        END;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';

        UPDATE u
           SET u.BLOQUEADO          = 0,
               u.DT_BLOQUEIO        = NULL,
               u.TENTATIVAS_ERRADAS = 0,
               u.DT_ALTERACAO       = SYSDATETIME(),
               u.USUARIO_ALTERACAO  = @Usuario
        FROM SIS.Usuario u
        WHERE u.ID_USUARIO = @IdUsuarioAlvo
          AND (u.BLOQUEADO = 1 OR u.TENTATIVAS_ERRADAS > 0);
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 0 THEN N'O usuário não estava bloqueado.' ELSE N'Usuário desbloqueado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdUsuarioAlvo AS ID_USUARIO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível desbloquear o usuário. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdUsuarioAlvo AS ID_USUARIO;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Perfil_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Perfil_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Lista de perfis: tela "Perfis e permissões" e a escolha do
                perfil na tela de usuários.
                Permissão: SIS_PERFIL / VER ou SIS_USUARIO / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: NIVEL_ADMIN no lugar de
                        ADMINISTRADOR; perfis de nível 2 só para o nível 2.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Perfil_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Perfil_Listar]
    @IdUsuario      INT,
    @SomenteAtivos  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Perfil_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Nivel      TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PERFIL', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os perfis.', 1;

        SET @SomenteAtivos = ISNULL(@SomenteAtivos, 0);

        SET @EtapaAtual = 'Consulta';
        SELECT p.ID_PERFIL,
               p.NOME,
               p.DESCRICAO,
               p.NIVEL_ADMIN,
               p.ATIVO,
               (SELECT COUNT(*) FROM SIS.Usuario u WITH (NOLOCK)
                WHERE u.ID_PERFIL = p.ID_PERFIL AND u.INTERNO = 0 AND u.ATIVO = 1)            AS QTD_USUARIOS_ATIVOS,
               (SELECT COUNT(*) FROM SIS.Perfil_Permissao pp WITH (NOLOCK)
                WHERE pp.ID_PERFIL = p.ID_PERFIL)                                               AS QTD_PERMISSOES
        FROM SIS.Perfil p WITH (NOLOCK)
        WHERE (@SomenteAtivos = 0 OR p.ATIVO = 1)
          AND (p.NIVEL_ADMIN < 2 OR @Nivel = 2)
        ORDER BY p.NIVEL_ADMIN DESC, p.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os perfis. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Perfil_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Perfil_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Inclui (@IdPerfil NULL) ou altera um perfil: nome, descrição e
                ativo. As permissões do perfil são gravadas à parte
                (SIS_Permissao_Gravar).
                Regras: nome único (UPDLOCK, HOLDLOCK); perfis de administrador
                (NIVEL_ADMIN 1 e 2) não podem ser desativados; perfil com
                usuário ativo não pode ser desativado; perfil de nível 2 só
                é visto e alterado pelo administrador geral. O NIVEL_ADMIN não
                muda por aqui (perfil novo é sempre comum).
                Permissão: SIS_PERFIL / INCLUIR ou ALTERAR.
                Recusa antes de gravar: COMMIT (nada foi alterado).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_PERFIL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: perfil de nível 2 só é
                        alterado pelo nível 2; perfis de administrador (1 e 2)
                        não podem ser desativados.

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Perfil_Gravar]
    @IdUsuario  INT,
    @IdPerfil   INT            = NULL,
    @Nome       NVARCHAR(60),
    @Descricao  NVARCHAR(400)  = NULL,
    @Ativo      BIT            = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Perfil_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @Incluir     BIT           = CASE WHEN @IdPerfil IS NULL THEN 1 ELSE 0 END;
    DECLARE @NivelPerfil TINYINT;
    DECLARE @Nivel       TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);
    DECLARE @QtdUsuarios INT           = 0;
    DECLARE @IdGravado   INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PERFIL', CASE WHEN @Incluir = 1 THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Incluir = 1 THEN N'Você não tem permissão para incluir perfis.' ELSE N'Você não tem permissão para alterar perfis.' END AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_PERFIL;
            RETURN;
        END;

        SET @Usuario   = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Nome      = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Ativo     = ISNULL(@Ativo, 1);

        IF @Nome = N''
            SET @Recusa = N'Informe o nome do perfil.';

        IF @Recusa = N'' AND @Incluir = 0
        BEGIN
            SELECT @NivelPerfil = p.NIVEL_ADMIN FROM SIS.Perfil p WHERE p.ID_PERFIL = @IdPerfil;
            IF @NivelPerfil IS NULL OR (@NivelPerfil = 2 AND @Nivel < 2)
                SET @Recusa = N'Perfil não encontrado.';
            IF @Recusa = N'' AND @NivelPerfil >= 1 AND @Ativo = 0
                SET @Recusa = N'Perfil de administrador não pode ser desativado.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPerfil AS ID_PERFIL;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM SIS.Perfil p WITH (UPDLOCK, HOLDLOCK)
                       WHERE p.NOME = @Nome AND p.ID_PERFIL <> ISNULL(@IdPerfil, 0))
                SET @Recusa = N'Já existe um perfil com o nome "' + @Nome + N'".';

            IF @Recusa = N'' AND @Incluir = 0 AND @Ativo = 0
            BEGIN
                SELECT @QtdUsuarios = COUNT(*)
                FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK)
                WHERE u.ID_PERFIL = @IdPerfil AND u.INTERNO = 0 AND u.ATIVO = 1;

                IF @QtdUsuarios > 0
                    SET @Recusa = N'Há ' + CONVERT(NVARCHAR(10), @QtdUsuarios) + N' usuário(s) ativo(s) neste perfil: mude o perfil deles antes de desativar.';
            END;

            IF @Recusa <> N''
            BEGIN
                COMMIT TRANSACTION;   -- nada foi gravado; só libera as travas
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPerfil AS ID_PERFIL;
                RETURN;
            END;

            IF @Incluir = 1
            BEGIN
                INSERT INTO SIS.Perfil (NOME, DESCRICAO, NIVEL_ADMIN, ATIVO, USUARIO_CRIACAO)
                VALUES (@Nome, @Descricao, 0, @Ativo, ISNULL(@Usuario, N''));
                SET @IdGravado = CAST(SCOPE_IDENTITY() AS INT);
            END
            ELSE
            BEGIN
                UPDATE p
                   SET p.NOME              = @Nome,
                       p.DESCRICAO         = @Descricao,
                       p.ATIVO             = @Ativo,
                       p.DT_ALTERACAO      = SYSDATETIME(),
                       p.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Perfil p
                WHERE p.ID_PERFIL = @IdPerfil;
                SET @IdGravado = @IdPerfil;
            END;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Incluir = 1 THEN N'Perfil incluído. Marque agora as permissões.' ELSE N'Perfil gravado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdGravado AS ID_PERFIL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar o perfil. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_PERFIL;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Permissao_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Permissao_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Grade de permissões (módulo > tela > ação) para marcar:
                  @IdPerfil       -> permissões do perfil (NO_PERFIL);
                  @IdUsuarioAlvo  -> do perfil do usuário + exceções dele
                                     (EXCECAO 'C' concede / 'R' retira).
                Informar só um dos dois. EFETIVA = o que vale de fato.
                Telas exclusivas do administrador geral não entram (ninguém
                recebe por marcação). Perfil de administrador: tudo marcado.
                Só módulos ativos e liberados na licença; ITEM_NOME traz o
                caminho do menu ("Segurança > Usuários").
                Permissão: SIS_PERFIL / VER (perfil) ou SIS_USUARIO / VER
                (usuário).
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: telas EXCLUSIVO_GERAL fora
                        da grade; perfil/usuário de nível 2 só para o nível 2;
                        devolve PERFIL_NIVEL_ADMIN.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Permissao_Listar @IdUsuario = 2, @IdPerfil = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Permissao_Listar]
    @IdUsuario      INT,
    @IdPerfil       INT = NULL,
    @IdUsuarioAlvo  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[SIS].[SIS_Permissao_Listar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Validação';
    DECLARE @IdPerfilBase  INT;
    DECLARE @NivelPerfil   TINYINT;
    DECLARE @Nivel         TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);

    BEGIN TRY
        IF (@IdPerfil IS NULL AND @IdUsuarioAlvo IS NULL) OR (@IdPerfil IS NOT NULL AND @IdUsuarioAlvo IS NOT NULL)
            THROW 50001, N'Informe o perfil ou o usuário (só um dos dois).', 1;

        IF @IdPerfil IS NOT NULL AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PERFIL', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os perfis.', 1;

        IF @IdUsuarioAlvo IS NOT NULL AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os usuários.', 1;

        IF @IdPerfil IS NOT NULL
            SET @IdPerfilBase = @IdPerfil;
        IF @IdUsuarioAlvo IS NOT NULL
            SELECT @IdPerfilBase = u.ID_PERFIL FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuarioAlvo AND u.INTERNO = 0;

        SELECT @NivelPerfil = p.NIVEL_ADMIN FROM SIS.Perfil p WITH (NOLOCK) WHERE p.ID_PERFIL = @IdPerfilBase;

        IF @NivelPerfil IS NULL OR (@NivelPerfil = 2 AND @Nivel < 2)
            THROW 50001, N'Perfil ou usuário não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        WITH Arvore AS
        (
            SELECT i.ID_ITEM,
                   CAST(i.NOME AS NVARCHAR(400)) AS CAMINHO_NOME,
                   CAST(RIGHT('00000' + CONVERT(VARCHAR(5), i.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), i.ID_ITEM), 10) AS VARCHAR(400)) AS ORDEM_CAMINHO
            FROM SIS.Item i WITH (NOLOCK)
            WHERE i.ID_ITEM_PAI IS NULL
              AND i.ATIVO = 1
            UNION ALL
            SELECT c.ID_ITEM,
                   CAST(a.CAMINHO_NOME + N' > ' + c.NOME AS NVARCHAR(400)),
                   CAST(a.ORDEM_CAMINHO + '/' + RIGHT('00000' + CONVERT(VARCHAR(5), c.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), c.ID_ITEM), 10) AS VARCHAR(400))
            FROM SIS.Item c WITH (NOLOCK)
            INNER JOIN Arvore a ON a.ID_ITEM = c.ID_ITEM_PAI
            WHERE c.ATIVO = 1
        )
        SELECT m.ID_MODULO,
               m.CODIGO                AS MODULO_CODIGO,
               m.NOME                  AS MODULO_NOME,
               i.ID_ITEM,
               i.CODIGO                AS ITEM_CODIGO,
               ar.CAMINHO_NOME         AS ITEM_NOME,
               ia.ID_ITEM_ACAO,
               a.CODIGO                AS ACAO_CODIGO,
               a.NOME                  AS ACAO_NOME,
               x.NO_PERFIL,
               CAST(ISNULL(up.TIPO, '') AS CHAR(1)) AS EXCECAO,
               CAST(CASE WHEN @NivelPerfil >= 1 THEN 1
                         WHEN up.TIPO = 'C'     THEN 1
                         WHEN up.TIPO = 'R'     THEN 0
                         ELSE x.NO_PERFIL END AS BIT) AS EFETIVA,
               @NivelPerfil            AS PERFIL_NIVEL_ADMIN
        FROM Arvore ar
        INNER JOIN SIS.Item      i  WITH (NOLOCK) ON i.ID_ITEM   = ar.ID_ITEM AND i.TIPO = 'TELA' AND i.EXCLUSIVO_GERAL = 0
        INNER JOIN SIS.Modulo    m  WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
        INNER JOIN SIS.Item_Acao ia WITH (NOLOCK) ON ia.ID_ITEM  = i.ID_ITEM AND ia.ATIVO = 1
        INNER JOIN SIS.Acao      a  WITH (NOLOCK) ON a.ID_ACAO   = ia.ID_ACAO AND a.ATIVO = 1
        LEFT  JOIN SIS.Usuario_Permissao up WITH (NOLOCK) ON up.ID_USUARIO = @IdUsuarioAlvo AND up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
        CROSS APPLY (SELECT CAST(CASE WHEN @NivelPerfil >= 1
                                        OR EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WITH (NOLOCK)
                                                   WHERE pp.ID_PERFIL = @IdPerfilBase AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO)
                                      THEN 1 ELSE 0 END AS BIT) AS NO_PERFIL) x
        WHERE m.ATIVO = 1
          AND m.LIBERADO_LICENCA = 1
        ORDER BY m.ORDEM_MENU, ar.ORDEM_CAMINHO, a.ORDEM
        OPTION (MAXRECURSION 20);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as permissões. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Permissao_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Permissao_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Grava de uma vez (tudo-ou-nada) as marcações da grade de
                permissões, de um perfil OU de um usuário.
                @ListaJson: [{"id_item_acao": 12, "valor": "S"}, ...]
                  perfil  : valor "S" (permite) ou "N" (tira);
                  usuário : valor "C" (concede), "R" (retira) ou "" (volta ao
                            que o perfil diz).
                Exceção de usuário que não muda nada (conceder o que o perfil
                já dá, retirar o que ele não dá) não é gravada.
                Recusas: perfil de administrador (nível 1 ou 2, já tem tudo);
                retirar permissão de usuário administrador; tela exclusiva do
                administrador geral; perfil/usuário de nível 2 para quem não
                é nível 2.
                Permissão: SIS_PERFIL / ALTERAR ou SIS_USUARIO / ALTERAR.
                Devolve 1 linha: SUCESSO, MENSAGEM, QTD_ALTERADA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: recusa perfis de nível 1 e
                        2, tela EXCLUSIVO_GERAL e alvo de nível 2 para quem não
                        é nível 2.

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Permissao_Gravar]
    @IdUsuario      INT,
    @IdPerfil       INT            = NULL,
    @IdUsuarioAlvo  INT            = NULL,
    @ListaJson      NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[SIS].[SIS_Permissao_Gravar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Validação';
    DECLARE @Recusa        NVARCHAR(400) = N'';
    DECLARE @Usuario       NVARCHAR(100);
    DECLARE @ModoPerfil    BIT           = CASE WHEN @IdPerfil IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @IdPerfilBase  INT;
    DECLARE @NivelPerfil   TINYINT;
    DECLARE @Nivel         TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);
    DECLARE @Qtd           INT           = 0;

    DROP TABLE IF EXISTS #Lista;

    BEGIN TRY
        IF (@IdPerfil IS NULL AND @IdUsuarioAlvo IS NULL) OR (@IdPerfil IS NOT NULL AND @IdUsuarioAlvo IS NOT NULL)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe o perfil ou o usuário (só um dos dois).' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_ALTERADA;
            RETURN;
        END;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE WHEN @ModoPerfil = 1 THEN 'SIS_PERFIL' ELSE 'SIS_USUARIO' END, 'ALTERAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para alterar permissões.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_ALTERADA;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        IF @ModoPerfil = 1
            SET @IdPerfilBase = @IdPerfil;
        IF @ModoPerfil = 0
            SELECT @IdPerfilBase = u.ID_PERFIL FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdUsuarioAlvo AND u.INTERNO = 0;

        SELECT @NivelPerfil = p.NIVEL_ADMIN FROM SIS.Perfil p WHERE p.ID_PERFIL = @IdPerfilBase;

        IF @NivelPerfil IS NULL OR (@NivelPerfil = 2 AND @Nivel < 2)
            SET @Recusa = N'Perfil ou usuário não encontrado.';
        IF @Recusa = N'' AND @ModoPerfil = 1 AND @NivelPerfil >= 1
            SET @Recusa = N'Perfil de administrador já tem todas as permissões.';
        IF @Recusa = N'' AND ISJSON(ISNULL(@ListaJson, N'')) = 0
            SET @Recusa = N'Lista de permissões inválida.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_ALTERADA;
            RETURN;
        END;

        SET @EtapaAtual = 'Leitura da lista';
        SELECT j.id_item_acao                              AS ID_ITEM_ACAO,
               UPPER(LTRIM(RTRIM(ISNULL(j.valor, ''))))    AS VALOR,
               CAST(0 AS BIT)                              AS NO_PERFIL,
               CAST('' AS CHAR(1))                         AS FINAL
        INTO #Lista
        FROM OPENJSON(@ListaJson)
             WITH (id_item_acao INT        '$.id_item_acao',
                   valor        VARCHAR(5) '$.valor') j;

        IF NOT EXISTS (SELECT 1 FROM #Lista)
            SET @Recusa = N'Nenhuma permissão informada.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Lista l
                                     WHERE l.ID_ITEM_ACAO IS NULL
                                        OR NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM_ACAO = l.ID_ITEM_ACAO AND ia.ATIVO = 1))
            SET @Recusa = N'A lista tem permissão inexistente.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Lista l
                                     INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = l.ID_ITEM_ACAO
                                     INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM
                                     WHERE i.EXCLUSIVO_GERAL = 1)
            SET @Recusa = N'A lista tem tela exclusiva do administrador geral (não pode ser dada a ninguém).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Lista l GROUP BY l.ID_ITEM_ACAO HAVING COUNT(*) > 1)
            SET @Recusa = N'A lista repete a mesma permissão.';
        IF @Recusa = N'' AND @ModoPerfil = 1 AND EXISTS (SELECT 1 FROM #Lista l WHERE l.VALOR NOT IN ('S', 'N'))
            SET @Recusa = N'Valor inválido na lista (use S ou N).';
        IF @Recusa = N'' AND @ModoPerfil = 0 AND EXISTS (SELECT 1 FROM #Lista l WHERE l.VALOR NOT IN ('C', 'R', ''))
            SET @Recusa = N'Valor inválido na lista (use C, R ou vazio).';
        IF @Recusa = N'' AND @ModoPerfil = 0 AND @NivelPerfil >= 1 AND EXISTS (SELECT 1 FROM #Lista l WHERE l.VALOR = 'R')
            SET @Recusa = N'Usuário administrador tem todas as permissões: não é possível retirar.';

        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Lista;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_ALTERADA;
            RETURN;
        END;

        IF @ModoPerfil = 0
        BEGIN
            UPDATE l
               SET l.NO_PERFIL = CASE WHEN EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp
                                                   WHERE pp.ID_PERFIL = @IdPerfilBase AND pp.ID_ITEM_ACAO = l.ID_ITEM_ACAO)
                                      THEN 1 ELSE 0 END
            FROM #Lista l;

            UPDATE l
               SET l.FINAL = CASE WHEN @NivelPerfil = 0 AND l.VALOR = 'C' AND l.NO_PERFIL = 0 THEN 'C'
                                  WHEN @NivelPerfil = 0 AND l.VALOR = 'R' AND l.NO_PERFIL = 1 THEN 'R'
                                  ELSE '' END
            FROM #Lista l;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF @ModoPerfil = 1
            BEGIN
                INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
                SELECT @IdPerfil, l.ID_ITEM_ACAO, ISNULL(@Usuario, N'')
                FROM #Lista l
                WHERE l.VALOR = 'S'
                  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WITH (UPDLOCK, HOLDLOCK)
                                  WHERE pp.ID_PERFIL = @IdPerfil AND pp.ID_ITEM_ACAO = l.ID_ITEM_ACAO);
                SET @Qtd = @Qtd + @@ROWCOUNT;

                DELETE pp
                FROM SIS.Perfil_Permissao pp
                INNER JOIN #Lista l ON l.ID_ITEM_ACAO = pp.ID_ITEM_ACAO
                WHERE pp.ID_PERFIL = @IdPerfil
                  AND l.VALOR = 'N';
                SET @Qtd = @Qtd + @@ROWCOUNT;

                UPDATE p SET p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Perfil p
                WHERE p.ID_PERFIL = @IdPerfil AND @Qtd > 0;
            END;

            IF @ModoPerfil = 0
            BEGIN
                DELETE up
                FROM SIS.Usuario_Permissao up
                INNER JOIN #Lista l ON l.ID_ITEM_ACAO = up.ID_ITEM_ACAO
                WHERE up.ID_USUARIO = @IdUsuarioAlvo
                  AND l.FINAL = '';
                SET @Qtd = @Qtd + @@ROWCOUNT;

                UPDATE up
                   SET up.TIPO              = l.FINAL,
                       up.DT_ALTERACAO      = SYSDATETIME(),
                       up.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Usuario_Permissao up
                INNER JOIN #Lista l ON l.ID_ITEM_ACAO = up.ID_ITEM_ACAO
                WHERE up.ID_USUARIO = @IdUsuarioAlvo
                  AND l.FINAL <> ''
                  AND up.TIPO <> l.FINAL;
                SET @Qtd = @Qtd + @@ROWCOUNT;

                INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
                SELECT @IdUsuarioAlvo, l.ID_ITEM_ACAO, l.FINAL, ISNULL(@Usuario, N'')
                FROM #Lista l
                WHERE l.FINAL <> ''
                  AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao up WITH (UPDLOCK, HOLDLOCK)
                                  WHERE up.ID_USUARIO = @IdUsuarioAlvo AND up.ID_ITEM_ACAO = l.ID_ITEM_ACAO);
                SET @Qtd = @Qtd + @@ROWCOUNT;
            END;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Lista;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Qtd = 0 THEN N'Nenhuma alteração.' ELSE N'Permissões gravadas.' END AS NVARCHAR(400)) AS MENSAGEM,
               @Qtd AS QTD_ALTERADA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Lista;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar as permissões. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(0 AS INT) AS QTD_ALTERADA;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Menu_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Menu_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Menu lateral em drill-down do usuário logado (seção 3 item 8):
                só módulos liberados na licença, só telas em que ele tem VER,
                e os agrupadores (MENU) que levam até elas.
                Uma linha por nó, já na ordem de exibição:
                  TIPO      : MODULO / MENU / TELA
                  CHAVE     : 'M<id>' (módulo) ou 'I<id>' (item)
                  CHAVE_PAI : '' (módulo), 'M<id>' ou 'I<id>'
                  NIVEL     : 0 = módulo, 1 = direto no módulo, 2...
                  ACOES     : ações permitidas na tela ("VER,INCLUIR,...")
                              para a tela esconder os botões não permitidos.
                Sem conferência de permissão: é o próprio menu do usuário.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Menu_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Menu_Listar]
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Menu_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissões';

    DROP TABLE IF EXISTS #Perm;
    DROP TABLE IF EXISTS #Arv;
    DROP TABLE IF EXISTS #Vis;

    BEGIN TRY
        SELECT v.ID_ITEM, v.ACAO_CODIGO, a.ORDEM
        INTO #Perm
        FROM SIS.vw_SIS_Permissao_Efetiva v
        INNER JOIN SIS.Acao a ON a.ID_ACAO = v.ID_ACAO
        WHERE v.ID_USUARIO = @IdUsuario;

        SET @EtapaAtual = 'Árvore do menu';
        WITH Arvore AS
        (
            SELECT i.ID_ITEM, 1 AS NIVEL,
                   CAST(RIGHT('00000' + CONVERT(VARCHAR(5), i.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), i.ID_ITEM), 10) AS VARCHAR(400)) AS ORDEM_CAMINHO
            FROM SIS.Item i WITH (NOLOCK)
            WHERE i.ID_ITEM_PAI IS NULL
              AND i.ATIVO = 1
            UNION ALL
            SELECT c.ID_ITEM, a.NIVEL + 1,
                   CAST(a.ORDEM_CAMINHO + '/' + RIGHT('00000' + CONVERT(VARCHAR(5), c.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), c.ID_ITEM), 10) AS VARCHAR(400))
            FROM SIS.Item c WITH (NOLOCK)
            INNER JOIN Arvore a ON a.ID_ITEM = c.ID_ITEM_PAI
            WHERE c.ATIVO = 1
        )
        SELECT ar.ID_ITEM, ar.NIVEL, ar.ORDEM_CAMINHO
        INTO #Arv
        FROM Arvore ar
        OPTION (MAXRECURSION 20);

        SET @EtapaAtual = 'Itens visíveis';
        WITH Visivel AS
        (
            SELECT i.ID_ITEM, i.ID_ITEM_PAI
            FROM SIS.Item i WITH (NOLOCK)
            INNER JOIN #Arv ar ON ar.ID_ITEM = i.ID_ITEM
            WHERE i.TIPO = 'TELA'
              AND EXISTS (SELECT 1 FROM #Perm p WHERE p.ID_ITEM = i.ID_ITEM AND p.ACAO_CODIGO = 'VER')
            UNION ALL
            SELECT pai.ID_ITEM, pai.ID_ITEM_PAI
            FROM SIS.Item pai WITH (NOLOCK)
            INNER JOIN Visivel v ON v.ID_ITEM_PAI = pai.ID_ITEM
            WHERE pai.ATIVO = 1
        )
        SELECT DISTINCT v.ID_ITEM
        INTO #Vis
        FROM Visivel v
        OPTION (MAXRECURSION 20);

        SET @EtapaAtual = 'Montagem';
        SELECT x.TIPO, x.CHAVE, x.CHAVE_PAI, x.CODIGO, x.NOME, x.CAMINHO, x.ICONE, x.NIVEL, x.ACOES
        FROM (
                SELECT CAST('MODULO' AS VARCHAR(10))                               AS TIPO,
                       CAST('M' + CONVERT(VARCHAR(10), m.ID_MODULO) AS VARCHAR(12)) AS CHAVE,
                       CAST('' AS VARCHAR(12))                                     AS CHAVE_PAI,
                       CAST(m.CODIGO AS VARCHAR(40))                               AS CODIGO,
                       CAST(m.NOME AS NVARCHAR(80))                                AS NOME,
                       CAST('' AS VARCHAR(200))                                    AS CAMINHO,
                       m.ICONE                                                     AS ICONE,
                       0                                                           AS NIVEL,
                       CAST('' AS VARCHAR(400))                                    AS ACOES,
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10) AS VARCHAR(500)) AS ORDEM_GERAL
                FROM SIS.Modulo m WITH (NOLOCK)
                WHERE EXISTS (SELECT 1 FROM #Vis v INNER JOIN SIS.Item i ON i.ID_ITEM = v.ID_ITEM WHERE i.ID_MODULO = m.ID_MODULO)
                UNION ALL
                SELECT CAST(i.TIPO AS VARCHAR(10)),
                       CAST('I' + CONVERT(VARCHAR(10), i.ID_ITEM) AS VARCHAR(12)),
                       CAST(CASE WHEN i.ID_ITEM_PAI IS NULL THEN 'M' + CONVERT(VARCHAR(10), i.ID_MODULO)
                                 ELSE 'I' + CONVERT(VARCHAR(10), i.ID_ITEM_PAI) END AS VARCHAR(12)),
                       CAST(i.CODIGO AS VARCHAR(40)),
                       CAST(i.NOME AS NVARCHAR(80)),
                       CAST(i.CAMINHO AS VARCHAR(200)),
                       i.ICONE,
                       ar.NIVEL,
                       CAST(ISNULL((SELECT STRING_AGG(CAST(p.ACAO_CODIGO AS VARCHAR(400)), ',') WITHIN GROUP (ORDER BY p.ORDEM)
                                    FROM #Perm p WHERE p.ID_ITEM = i.ID_ITEM), '') AS VARCHAR(400)),
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10)
                            + '|' + ar.ORDEM_CAMINHO AS VARCHAR(500))
                FROM #Vis v
                INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.ID_ITEM   = v.ID_ITEM
                INNER JOIN #Arv       ar              ON ar.ID_ITEM  = i.ID_ITEM
                INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
             ) x
        ORDER BY x.ORDEM_GERAL;

        DROP TABLE IF EXISTS #Perm;
        DROP TABLE IF EXISTS #Arv;
        DROP TABLE IF EXISTS #Vis;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Perm;
            DROP TABLE IF EXISTS #Arv;
            DROP TABLE IF EXISTS #Vis;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        THROW 50001, N'Não foi possível montar o menu. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Contexto_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Contexto_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Grava no SESSION_CONTEXT da conexão quem está usando o
                sistema, para os valores padrão das colunas USUARIO_CRIACAO,
                o log de erros e as triggers de auditoria saberem o usuário de
                verdade (e não o login técnico da API). A API chama no início
                de cada requisição, logo depois de abrir a conexão:
                  USUARIO    : login do usuário (fn_SIS_Usuario_Login)
                  ID_USUARIO : ID do usuário
                  ESTACAO    : IP ou nome da máquina do usuário
                  ORIGEM     : tela ou rotina (ex.: 'sis/usuarios.html',
                               'ROTINA:EMAIL_FILA')
                  ID_LOTE    : lote em andamento (NULL quando não há)
                A conexão devolvida ao pool é limpa pelo SQL Server
                (sp_reset_connection), então um usuário nunca herda o contexto
                de outro. Rotina automática usa o usuário interno "sistema".
                Sem result set (é chamada antes da procedure da tela).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Contexto_Gravar @IdUsuario = 2, @Estacao = N'127.0.0.1', @Origem = N'SSMS';
    -- SELECT SESSION_CONTEXT(N'USUARIO'), SESSION_CONTEXT(N'ORIGEM');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Contexto_Gravar]
    @IdUsuario  INT,
    @Estacao    NVARCHAR(128) = NULL,
    @Origem     NVARCHAR(256) = NULL,
    @IdLote     BIGINT        = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Contexto_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Contexto';
    DECLARE @Login      NVARCHAR(100);

    BEGIN TRY
        SELECT @Login = CONVERT(NVARCHAR(100), u.LOGIN)
        FROM SIS.Usuario u
        WHERE u.ID_USUARIO = @IdUsuario;

        SET @Login   = ISNULL(@Login, N'');
        SET @Estacao = ISNULL(@Estacao, N'');
        SET @Origem  = ISNULL(@Origem, N'');

        EXEC sys.sp_set_session_context @key = N'USUARIO',    @value = @Login;
        EXEC sys.sp_set_session_context @key = N'ID_USUARIO', @value = @IdUsuario;
        EXEC sys.sp_set_session_context @key = N'ESTACAO',    @value = @Estacao;
        EXEC sys.sp_set_session_context @key = N'ORIGEM',     @value = @Origem;
        EXEC sys.sp_set_session_context @key = N'ID_LOTE',    @value = @IdLote;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Trigger_Gerar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Auditoria_Trigger_Gerar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Gera (e, com @Criar = 1, cria) a trigger de auditoria de uma
                tabela, lendo a estrutura dela no próprio banco: nenhuma
                trigger de auditoria é escrita à mão, e nenhum campo fica de
                fora por esquecimento.
                A trigger gerada ([SCHEMA].[tg_SCHEMA_Tabela_Auditoria],
                AFTER INSERT, UPDATE, DELETE, set-based, sem variável de I/U/D,
                PADRAO_SQL regras 6 e 34) grava em SIS.Auditoria:
                  inclusão/exclusão: 1 linha com o registro inteiro em JSON;
                  alteração: 1 linha por campo que mudou (texto comparado em
                  binário, para pegar até mudança de maiúscula/minúscula).
                Parâmetros:
                  @Tabela          'SCHEMA.Tabela' (precisa ter chave primária
                                   de uma coluna só)
                  @CamposIgnorados não geram linha de alteração (ex.: contador
                                   de tentativas). DT_/USUARIO_ CRIACAO e
                                   ALTERACAO e a chave já são ignorados.
                  @CamposSigilosos aparecem como "***" (ex.: hash de senha).
                                   Colunas binárias são sempre sigilosas.
                  @Criar           0 = só devolve o script (coluna SCRIPT);
                                   1 = cria/atualiza a trigger.
                Quando a tabela ganha coluna nova, basta rodar de novo.
                No MASTER, a parte 8 (triggers) chama esta procedure para cada
                tabela auditada (Carga_SIS_Auditoria_Triggers.sql), em vez de
                guardar o texto das triggers: o resultado é sempre o mesmo
                para a mesma estrutura de tabela.
                Automação: em erro, registra em SIS.Log_Erro e relança.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (18/11/2026) - Desempenho em carga grande: a foto JSON do registro é
                        montada direto da linha (sem buscar de novo no inserted/
                        deleted, que não tem índice e deixava a trigger
                        quadrática: 25 mil linhas levavam horas). Mesmo
                        resultado gravado na SIS.Auditoria.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro';            -- só mostra o script
    -- EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro', @Criar = 1; -- cria
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Auditoria_Trigger_Gerar]
    @Tabela           NVARCHAR(256),
    @CamposIgnorados  NVARCHAR(MAX) = NULL,
    @CamposSigilosos  NVARCHAR(MAX) = NULL,
    @Criar            BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Auditoria_Trigger_Gerar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @NL           NCHAR(2)      = NCHAR(13) + NCHAR(10);
    DECLARE @Sep          NVARCHAR(10)  = N',' + NCHAR(13) + NCHAR(10);
    DECLARE @ObjId        INT;
    DECLARE @Schema       SYSNAME;
    DECLARE @Nome         SYSNAME;
    DECLARE @Pk           SYSNAME;
    DECLARE @QtdPk        INT;
    DECLARE @NomeTabela   NVARCHAR(256);
    DECLARE @NomeTrigger  SYSNAME;
    DECLARE @ListaJson    NVARCHAR(MAX);
    DECLARE @Valores      NVARCHAR(MAX);
    DECLARE @Contexto     NVARCHAR(MAX);
    DECLARE @Script       NVARCHAR(MAX);

    DROP TABLE IF EXISTS #Col;

    BEGIN TRY
        SET @Criar  = ISNULL(@Criar, 0);
        SET @ObjId  = OBJECT_ID(LTRIM(RTRIM(ISNULL(@Tabela, N''))), N'U');

        IF @ObjId IS NULL
            THROW 50001, N'Tabela não encontrada (use SCHEMA.Tabela).', 1;

        SET @Schema      = OBJECT_SCHEMA_NAME(@ObjId);
        SET @Nome        = OBJECT_NAME(@ObjId);
        SET @NomeTabela  = @Schema + N'.' + @Nome;
        SET @NomeTrigger = N'tg_' + @Schema + N'_' + @Nome + N'_Auditoria';

        IF @NomeTabela = N'SIS.Auditoria'
            THROW 50001, N'A própria auditoria não é auditada.', 1;

        SELECT @QtdPk = COUNT(*)
        FROM sys.indexes ix
        INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
        WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

        IF ISNULL(@QtdPk, 0) <> 1
            THROW 50001, N'A tabela precisa ter chave primária de uma coluna só.', 1;

        SELECT @Pk = c.name
        FROM sys.indexes ix
        INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
        INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

        SET @EtapaAtual = 'Leitura das colunas';
        SELECT c.column_id AS ORDEM,
               c.name      AS NOME,
               t.name      AS TIPO,
               CAST(CASE WHEN t.name IN ('varbinary', 'binary', 'image', 'timestamp')
                           OR EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(@CamposSigilosos, N''), N',') s WHERE LTRIM(RTRIM(s.value)) = c.name)
                         THEN 1 ELSE 0 END AS BIT) AS SIGILOSO,
               CAST(CASE WHEN c.name IN (N'DT_CRIACAO', N'USUARIO_CRIACAO', N'DT_ALTERACAO', N'USUARIO_ALTERACAO')
                           OR c.name = @Pk
                           OR c.is_computed = 1
                           OR t.name IN ('timestamp', 'text', 'ntext', 'image', 'geography', 'geometry')
                           OR EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(@CamposIgnorados, N''), N',') s WHERE LTRIM(RTRIM(s.value)) = c.name)
                         THEN 1 ELSE 0 END AS BIT) AS IGNORADO,
               CAST(CASE WHEN t.name IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 1 ELSE 0 END AS BIT) AS TEXTO,
               CAST(CASE WHEN t.name IN ('date', 'datetime', 'datetime2', 'smalldatetime', 'datetimeoffset', 'time') THEN 1 ELSE 0 END AS BIT) AS DATA,
               CAST(CASE WHEN t.name IN ('xml', 'sql_variant', 'hierarchyid') THEN 1 ELSE 0 END AS BIT) AS ESPECIAL
        INTO #Col
        FROM sys.columns c
        INNER JOIN sys.types t ON t.system_type_id = c.system_type_id AND t.user_type_id = c.system_type_id
        WHERE c.object_id = @ObjId
          AND t.name NOT IN ('geography', 'geometry');

        SET @EtapaAtual = 'Montagem do script';

        -- Foto do registro (JSON) para inclusão e exclusão
        SELECT @ListaJson = STRING_AGG(CAST(
                   CASE WHEN c.SIGILOSO = 1 THEN N'CASE WHEN x.' + QUOTENAME(c.NOME) + N' IS NULL THEN NULL ELSE N''***'' END AS ' + QUOTENAME(c.NOME)
                        WHEN c.ESPECIAL = 1 THEN N'CONVERT(NVARCHAR(MAX), x.' + QUOTENAME(c.NOME) + N') AS ' + QUOTENAME(c.NOME)
                        WHEN c.TIPO IN ('text', 'ntext') THEN N'CONVERT(NVARCHAR(MAX), x.' + QUOTENAME(c.NOME) + N') AS ' + QUOTENAME(c.NOME)
                        ELSE N'x.' + QUOTENAME(c.NOME) END AS NVARCHAR(MAX)), N', ') WITHIN GROUP (ORDER BY c.ORDEM)
        FROM #Col c
        WHERE c.TIPO <> 'timestamp';

        -- Uma linha de VALUES por campo comparado na alteração
        SELECT @Valores = STRING_AGG(CAST(
                   N'                (N''' + c.NOME + N''', '
                 + CASE WHEN c.SIGILOSO = 1 THEN N'CASE WHEN d.' + QUOTENAME(c.NOME) + N' IS NULL THEN NULL ELSE N''***'' END, CASE WHEN i.' + QUOTENAME(c.NOME) + N' IS NULL THEN NULL ELSE N''***'' END, '
                        WHEN c.DATA = 1     THEN N'CONVERT(NVARCHAR(MAX), d.' + QUOTENAME(c.NOME) + N', 121), CONVERT(NVARCHAR(MAX), i.' + QUOTENAME(c.NOME) + N', 121), '
                        ELSE                     N'CONVERT(NVARCHAR(MAX), d.' + QUOTENAME(c.NOME) + N'), CONVERT(NVARCHAR(MAX), i.' + QUOTENAME(c.NOME) + N'), '
                   END
                 + N'CASE WHEN '
                 + CASE WHEN c.TEXTO = 1    THEN N'd.' + QUOTENAME(c.NOME) + N' COLLATE Latin1_General_BIN2 <> i.' + QUOTENAME(c.NOME) + N' COLLATE Latin1_General_BIN2'
                        WHEN c.ESPECIAL = 1 THEN N'CONVERT(NVARCHAR(MAX), d.' + QUOTENAME(c.NOME) + N') <> CONVERT(NVARCHAR(MAX), i.' + QUOTENAME(c.NOME) + N')'
                        ELSE                     N'd.' + QUOTENAME(c.NOME) + N' <> i.' + QUOTENAME(c.NOME)
                   END
                 + N' OR (d.' + QUOTENAME(c.NOME) + N' IS NULL AND i.' + QUOTENAME(c.NOME) + N' IS NOT NULL)'
                 + N' OR (d.' + QUOTENAME(c.NOME) + N' IS NOT NULL AND i.' + QUOTENAME(c.NOME) + N' IS NULL) THEN 1 ELSE 0 END)'
                 AS NVARCHAR(MAX)), @Sep) WITHIN GROUP (ORDER BY c.ORDEM)
        FROM #Col c
        WHERE c.IGNORADO = 0;

        SET @Contexto = N'@Usuario, @IdUsuario, @Estacao, @Origem, @IdLote, @Transacao';

        SET @Script =
              N'CREATE OR ALTER TRIGGER ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@NomeTrigger) + @NL
            + N'ON ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Nome) + @NL
            + N'AFTER INSERT, UPDATE, DELETE' + @NL
            + N'AS' + @NL
            + N'/* Auditoria de ' + @NomeTabela + N'. Gerado por SIS.SIS_Auditoria_Trigger_Gerar em ' + SIS.fn_SIS_Formatar_Data_Hora(SYSDATETIME()) + N'.' + @NL
            + N'   NÃO EDITAR: mudou a tabela, gerar de novo.' + @NL
            + N'   Ignorados: ' + ISNULL(NULLIF(@CamposIgnorados, N''), N'(nenhum além dos padrões)') + N' | Sigilosos: ' + ISNULL(NULLIF(@CamposSigilosos, N''), N'(só colunas binárias)') + N' */' + @NL
            + N'BEGIN' + @NL
            + N'    SET NOCOUNT ON;' + @NL
            + N'    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;' + @NL + @NL
            + N'    DECLARE @Usuario   NVARCHAR(100) = ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N''USUARIO'')), ISNULL(CONVERT(NVARCHAR(100), SUSER_SNAME()), N''''));' + @NL
            + N'    DECLARE @IdUsuario INT           = TRY_CONVERT(INT, SESSION_CONTEXT(N''ID_USUARIO''));' + @NL
            + N'    DECLARE @Estacao   NVARCHAR(128) = ISNULL(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N''ESTACAO'')), ISNULL(HOST_NAME(), N''''));' + @NL
            + N'    DECLARE @Origem    NVARCHAR(256) = ISNULL(CONVERT(NVARCHAR(256), SESSION_CONTEXT(N''ORIGEM'')), ISNULL(APP_NAME(), N''''));' + @NL
            + N'    DECLARE @IdLote    BIGINT        = TRY_CONVERT(BIGINT, SESSION_CONTEXT(N''ID_LOTE''));' + @NL
            + N'    DECLARE @Transacao BIGINT        = CURRENT_TRANSACTION_ID();' + @NL + @NL
            + N'    BEGIN TRY' + @NL
            + N'        -- Inclusão: foto do registro novo' + @NL
            + N'        INSERT INTO SIS.Auditoria (TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, ID_USUARIO, ESTACAO, ORIGEM, ID_LOTE, TRANSACAO)' + @NL
            + N'        SELECT N''' + @NomeTabela + N''', i.' + QUOTENAME(@Pk) + N', ''I'', N'''', NULL,' + @NL
            + N'               (SELECT ' + REPLACE(@ListaJson, N'x.[', N'i.[') + N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),' + @NL
            + N'               ' + @Contexto + @NL
            + N'        FROM inserted i' + @NL
            + N'        WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.' + QUOTENAME(@Pk) + N' = i.' + QUOTENAME(@Pk) + N');' + @NL + @NL
            + N'        -- Exclusão: foto do registro apagado' + @NL
            + N'        INSERT INTO SIS.Auditoria (TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, ID_USUARIO, ESTACAO, ORIGEM, ID_LOTE, TRANSACAO)' + @NL
            + N'        SELECT N''' + @NomeTabela + N''', d.' + QUOTENAME(@Pk) + N', ''E'', N'''',' + @NL
            + N'               (SELECT ' + REPLACE(@ListaJson, N'x.[', N'd.[') + N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),' + @NL
            + N'               NULL, ' + @Contexto + @NL
            + N'        FROM deleted d' + @NL
            + N'        WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.' + QUOTENAME(@Pk) + N' = d.' + QUOTENAME(@Pk) + N');' + @NL
            + CASE WHEN ISNULL(@Valores, N'') = N'' THEN N''
                   ELSE @NL
                      + N'        -- Alteração: uma linha por campo que mudou' + @NL
                      + N'        INSERT INTO SIS.Auditoria (TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, ID_USUARIO, ESTACAO, ORIGEM, ID_LOTE, TRANSACAO)' + @NL
                      + N'        SELECT N''' + @NomeTabela + N''', i.' + QUOTENAME(@Pk) + N', ''A'', v.CAMPO, v.ANTES, v.DEPOIS, ' + @Contexto + @NL
                      + N'        FROM inserted i' + @NL
                      + N'        INNER JOIN deleted d ON d.' + QUOTENAME(@Pk) + N' = i.' + QUOTENAME(@Pk) + @NL
                      + N'        CROSS APPLY (VALUES' + @NL
                      + @Valores + @NL
                      + N'        ) v (CAMPO, ANTES, DEPOIS, MUDOU)' + @NL
                      + N'        WHERE v.MUDOU = 1;' + @NL
              END
            + N'    END TRY' + @NL
            + N'    BEGIN CATCH' + @NL
            + N'        THROW;   -- auditoria é integridade: sem auditoria, a gravação é desfeita' + @NL
            + N'    END CATCH;' + @NL
            + N'END;';

        DROP TABLE IF EXISTS #Col;

        IF @Criar = 0
        BEGIN
            SELECT @Script AS SCRIPT;
            RETURN;
        END;

        SET @EtapaAtual = 'Criação da trigger';
        EXEC sys.sp_executesql @Script;
        PRINT N'Auditoria ligada: ' + @Schema + N'.' + @NomeTrigger;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Col;
            IF ERROR_NUMBER() <> 50001
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, LEFT(@EtapaAtual + ' (' + CONVERT(VARCHAR(256), ISNULL(@Tabela, N'')) + ')', 200), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Registro_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Auditoria_Registro_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Aba "Histórico" de toda tela de manutenção (seção 3.7): quem
                incluiu, alterou ou excluiu aquele registro, quando, de onde e
                o valor antes e depois. Mais recente primeiro.
                @Item   : código da tela que está pedindo (ex.: SIS_USUARIO)
                @Tabela : 'SCHEMA.Tabela' do registro (precisa estar em
                          TABELAS_DA_TELA da tela)
                Permissão: VER na tela informada.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Auditoria_Registro_Listar @IdUsuario = 2, @Item = 'SIS_PARAMETRO', @Tabela = N'SIS.Parametro', @IdRegistro = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Auditoria_Registro_Listar]
    @IdUsuario   INT,
    @Item        VARCHAR(40),
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Auditoria_Registro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver este histórico.', 1;

        IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            THROW 50001, N'Esta tela não mostra histórico desse tipo de registro.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT a.ID_AUDITORIA,
               a.DT_OPERACAO,
               a.OPERACAO,
               CAST(CASE a.OPERACAO WHEN 'I' THEN N'Inclusão' WHEN 'A' THEN N'Alteração' ELSE N'Exclusão' END AS NVARCHAR(20)) AS OPERACAO_NOME,
               a.CAMPO,
               ISNULL(CAST(a.VALOR_ANTES  AS NVARCHAR(4000)), N'') AS VALOR_ANTES,
               ISNULL(CAST(a.VALOR_DEPOIS AS NVARCHAR(4000)), N'') AS VALOR_DEPOIS,
               a.USUARIO,
               a.ESTACAO,
               a.ORIGEM,
               a.ID_LOTE
        FROM SIS.Auditoria a WITH (NOLOCK)
        WHERE a.TABELA = @Tabela
          AND a.ID_REGISTRO = @IdRegistro
        ORDER BY a.ID_AUDITORIA DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o histórico. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Auditoria_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela geral de consulta da auditoria (seção 3.7), com filtros:
                período (sem datas: últimos 7 dias), usuário (parte do login),
                tabela (parte do nome), registro, operação (I/A/E) e lote.
                @MaxLinhas: padrão 1000, máximo 10000.
                Permissão: SIS_AUDITORIA / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Auditoria_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Auditoria_Listar @IdUsuario = 2, @Tabela = N'Parametro', @Operacao = 'A';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Auditoria_Listar]
    @IdUsuario   INT,
    @DtInicio    DATE          = NULL,
    @DtFim       DATE          = NULL,
    @Usuario     NVARCHAR(100) = NULL,
    @Tabela      NVARCHAR(256) = NULL,
    @IdRegistro  BIGINT        = NULL,
    @Operacao    CHAR(1)       = NULL,
    @IdLote      BIGINT        = NULL,
    @MaxLinhas   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Auditoria_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_AUDITORIA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para consultar a auditoria.', 1;

        SET @DtFim     = ISNULL(@DtFim, CAST(SYSDATETIME() AS DATE));
        SET @DtInicio  = ISNULL(@DtInicio, DATEADD(DAY, -7, @DtFim));
        SET @Usuario   = NULLIF(LTRIM(RTRIM(@Usuario)), N'');
        SET @Tabela    = NULLIF(LTRIM(RTRIM(@Tabela)), N'');
        SET @Operacao  = NULLIF(UPPER(LTRIM(RTRIM(@Operacao))), '');
        SET @MaxLinhas = ISNULL(@MaxLinhas, 1000);
        IF @MaxLinhas < 1 SET @MaxLinhas = 1000;
        IF @MaxLinhas > 10000 SET @MaxLinhas = 10000;

        IF @DtInicio > @DtFim
            THROW 50001, N'A data inicial não pode ser maior que a data final.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               a.ID_AUDITORIA,
               a.DT_OPERACAO,
               a.TABELA,
               a.ID_REGISTRO,
               a.OPERACAO,
               CAST(CASE a.OPERACAO WHEN 'I' THEN N'Inclusão' WHEN 'A' THEN N'Alteração' ELSE N'Exclusão' END AS NVARCHAR(20)) AS OPERACAO_NOME,
               a.CAMPO,
               ISNULL(CAST(a.VALOR_ANTES  AS NVARCHAR(4000)), N'') AS VALOR_ANTES,
               ISNULL(CAST(a.VALOR_DEPOIS AS NVARCHAR(4000)), N'') AS VALOR_DEPOIS,
               a.USUARIO,
               a.ESTACAO,
               a.ORIGEM,
               a.ID_LOTE
        FROM SIS.Auditoria a WITH (NOLOCK)
        WHERE a.DT_OPERACAO >= @DtInicio
          AND a.DT_OPERACAO <  DATEADD(DAY, 1, @DtFim)
          AND (@Usuario    IS NULL OR a.USUARIO LIKE N'%' + @Usuario + N'%')
          AND (@Tabela     IS NULL OR a.TABELA  LIKE N'%' + @Tabela + N'%')
          AND (@IdRegistro IS NULL OR a.ID_REGISTRO = @IdRegistro)
          AND (@Operacao   IS NULL OR a.OPERACAO = @Operacao)
          AND (@IdLote     IS NULL OR a.ID_LOTE = @IdLote)
        ORDER BY a.ID_AUDITORIA DESC
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível consultar a auditoria. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lote_Gerar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lote_Gerar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Abre um lote para um processo que vai gerar vários registros
                juntos e devolve o número em @IdLote (OUTPUT). Uso interno:
                chamada pelas procedures de negócio (gerar parcelas, processar
                retorno, aprovar medição...), dentro da transação delas
                (o INSERT é atômico; se o processo desfizer, o lote some junto).
                @DefinirContexto = 1 (padrão) grava o lote no SESSION_CONTEXT,
                e a auditoria de tudo que for gravado em seguida leva o número
                do lote. No fim, o processo chama SIS_Lote_Concluir.
                Recusa (origem inválida): THROW 50001, para o processo que
                chamou desfazer tudo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- DECLARE @L BIGINT; EXEC SIS.SIS_Lote_Gerar @IdUsuario = 1, @Origem = 'TESTE', @Descricao = N'Teste', @IdLote = @L OUTPUT; SELECT @L;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lote_Gerar]
    @IdUsuario         INT,
    @Origem            VARCHAR(30),
    @Descricao         NVARCHAR(400) = NULL,
    @TabelaReferencia  NVARCHAR(256) = NULL,
    @IdReferencia      BIGINT        = NULL,
    @DefinirContexto   BIT           = 1,
    @IdLote            BIGINT        OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lote_Gerar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @IdLote = NULL;
        SET @Origem = UPPER(LTRIM(RTRIM(ISNULL(@Origem, ''))));

        IF @Origem = '' OR REPLACE(@Origem, '_', '') LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2
            THROW 50001, N'Origem do lote inválida (use letras maiúsculas, números e "_").', 1;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';

        INSERT INTO SIS.Lote (ORIGEM, DESCRICAO, TABELA_REFERENCIA, ID_REFERENCIA, USUARIO_CRIACAO)
        VALUES (@Origem, LTRIM(RTRIM(ISNULL(@Descricao, N''))), LTRIM(RTRIM(ISNULL(@TabelaReferencia, N''))), @IdReferencia, ISNULL(@Usuario, N''));
        SET @IdLote = CAST(SCOPE_IDENTITY() AS BIGINT);

        IF ISNULL(@DefinirContexto, 1) = 1
            EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = @IdLote;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 50001 AND XACT_STATE() = 1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lote_Concluir.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lote_Concluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Fecha o lote aberto por SIS_Lote_Gerar: grava a quantidade de
                registros gerados e tira o lote do SESSION_CONTEXT (o que for
                gravado depois não leva mais esse número). Uso interno, dentro
                da transação do processo. Sem result set; erro: THROW.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lote_Concluir @IdLote = 1, @QtdRegistros = 30;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lote_Concluir]
    @IdLote        BIGINT,
    @QtdRegistros  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lote_Concluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Gravação';
    DECLARE @Nulo       BIGINT;

    BEGIN TRY
        UPDATE l
           SET l.QTD_REGISTROS = ISNULL(@QtdRegistros, 0)
        FROM SIS.Lote l
        WHERE l.ID_LOTE = @IdLote
          AND l.QTD_REGISTROS <> ISNULL(@QtdRegistros, 0);

        IF TRY_CONVERT(BIGINT, SESSION_CONTEXT(N'ID_LOTE')) = @IdLote
            EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = @Nulo;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() = 1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lote_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Lote_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Lotes": lotes gerados, com filtros por período (sem
                datas: últimos 30 dias), origem e número. Informando @IdLote,
                traz só aquele lote (qualquer data).
                Os registros de cada lote são listados pela tela do módulo
                dono deles (ex.: lançamentos do lote, pedido 9, fase 6).
                @MaxLinhas: padrão 500, máximo 5000.
                Permissão: SIS_LOTE / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lote_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lote_Listar]
    @IdUsuario  INT,
    @DtInicio   DATE         = NULL,
    @DtFim      DATE         = NULL,
    @Origem     VARCHAR(30)  = NULL,
    @IdLote     BIGINT       = NULL,
    @MaxLinhas  INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lote_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LOTE', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os lotes.', 1;

        SET @DtFim     = ISNULL(@DtFim, CAST(SYSDATETIME() AS DATE));
        SET @DtInicio  = ISNULL(@DtInicio, DATEADD(DAY, -30, @DtFim));
        SET @Origem    = NULLIF(UPPER(LTRIM(RTRIM(@Origem))), '');
        SET @MaxLinhas = ISNULL(@MaxLinhas, 500);
        IF @MaxLinhas < 1 SET @MaxLinhas = 500;
        IF @MaxLinhas > 5000 SET @MaxLinhas = 5000;

        IF @IdLote IS NULL AND @DtInicio > @DtFim
            THROW 50001, N'A data inicial não pode ser maior que a data final.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               l.ID_LOTE,
               l.ORIGEM,
               l.DESCRICAO,
               l.TABELA_REFERENCIA,
               l.ID_REFERENCIA,
               l.QTD_REGISTROS,
               l.SITUACAO,
               l.DT_CRIACAO,
               l.USUARIO_CRIACAO
        FROM SIS.Lote l WITH (NOLOCK)
        WHERE (@IdLote IS NOT NULL AND l.ID_LOTE = @IdLote)
           OR (@IdLote IS NULL
               AND l.DT_CRIACAO >= @DtInicio
               AND l.DT_CRIACAO <  DATEADD(DAY, 1, @DtFim)
               AND (@Origem IS NULL OR l.ORIGEM = @Origem))
        ORDER BY l.ID_LOTE DESC
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os lotes. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Registra um anexo. A API recebe o arquivo, grava em disco com
                nome gerado (GUID + extensão) em ANEXO_PASTA_RAIZ\ano\mês,
                calcula o SHA-256 e então chama esta procedure. Se a procedure
                recusar, a API apaga o arquivo que acabou de gravar.
                Confere:
                  - permissão ALTERAR na tela (@Item) e que a tela mantém a
                    tabela (TABELAS_DA_TELA);
                  - que o registro existe (pela chave primária da tabela);
                  - tipo ativo e extensão aceita pelo tipo;
                  - tamanho até ANEXO_TAMANHO_MAX_MB;
                  - nome do arquivo gerado (só letras, números, "-" e ".");
                  - o mesmo arquivo (hash) ainda não anexado ao registro.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_ANEXO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (20/11/2026) - Etapa 03d: conferência do registro pelo SIS_Registro_Existe
                        (o SELECT dinâmico falhava com o login da API no servidor).

  Homologação (LOCAL): ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Gravar]
    @IdUsuario      INT,
    @Item           VARCHAR(40),
    @Tabela         NVARCHAR(256),
    @IdRegistro     BIGINT,
    @CodigoTipo     VARCHAR(30),
    @NomeOriginal   NVARCHAR(260),
    @NomeArquivo    VARCHAR(100),
    @PastaRelativa  VARCHAR(50),
    @TamanhoBytes   BIGINT,
    @HashSha256     VARBINARY(32),
    @Descricao      NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Anexo_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @IdTipo      INT;
    DECLARE @Extensoes   VARCHAR(200);
    DECLARE @Extensao    VARCHAR(10);
    DECLARE @MaxMb       INT;
    DECLARE @Existe      BIT           = 0;
    DECLARE @IdAnexo     BIGINT;

    BEGIN TRY
        SET @Tabela        = LTRIM(RTRIM(ISNULL(@Tabela, N'')));
        SET @CodigoTipo    = UPPER(LTRIM(RTRIM(ISNULL(@CodigoTipo, ''))));
        SET @NomeOriginal  = LTRIM(RTRIM(ISNULL(@NomeOriginal, N'')));
        SET @NomeArquivo   = LTRIM(RTRIM(ISNULL(@NomeArquivo, '')));
        SET @PastaRelativa = LTRIM(RTRIM(ISNULL(@PastaRelativa, '')));
        SET @Extensao      = LOWER(CASE WHEN CHARINDEX('.', REVERSE(@NomeArquivo)) > 1
                                        THEN RIGHT(@NomeArquivo, CHARINDEX('.', REVERSE(@NomeArquivo)) - 1) ELSE '' END);
        SET @MaxMb         = SIS.fn_SIS_Parametro_Inteiro('ANEXO_TAMANHO_MAX_MB');
        IF @MaxMb < 1 SET @MaxMb = 1;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para anexar arquivos nesta tela.';
        IF @Recusa = N'' AND SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            SET @Recusa = N'Esta tela não aceita anexos desse tipo de registro.';

        SELECT @IdTipo = t.ID_ANEXO_TIPO, @Extensoes = t.EXTENSOES
        FROM SIS.Anexo_Tipo t
        WHERE t.CODIGO = @CodigoTipo AND t.ATIVO = 1;

        IF @Recusa = N'' AND @IdTipo IS NULL
            SET @Recusa = N'Escolha um tipo de anexo válido.';
        IF @Recusa = N'' AND (@Extensao = '' OR NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@Extensoes, ',') s WHERE LTRIM(RTRIM(s.value)) = @Extensao))
            SET @Recusa = N'Este tipo de anexo aceita só: ' + CONVERT(NVARCHAR(200), REPLACE(@Extensoes, ',', ', ')) + N'.';
        IF @Recusa = N'' AND (ISNULL(@TamanhoBytes, 0) <= 0 OR @TamanhoBytes > CAST(@MaxMb AS BIGINT) * 1048576)
            SET @Recusa = N'O arquivo precisa ter até ' + CONVERT(NVARCHAR(10), @MaxMb) + N' MB.';
        IF @Recusa = N'' AND (@NomeOriginal = N''
                              OR @NomeArquivo = ''
                              OR REPLACE(REPLACE(@NomeArquivo, '-', ''), '.', '') LIKE '%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN2
                              OR REPLACE(@PastaRelativa, '\', '') LIKE '%[^0-9]%' COLLATE Latin1_General_BIN2
                              OR DATALENGTH(ISNULL(@HashSha256, 0x)) <> 32)
            SET @Recusa = N'Falha técnica no envio do arquivo (nome, pasta ou hash inválido).';

        IF @Recusa = N''
        BEGIN
            -- v1.1: conferência pelo SIS_Registro_Existe (SQL dinâmico com a permissão do dono:
            -- no servidor o login da API só executa procedures)
            SET @EtapaAtual = 'Registro de referência';
            EXEC SIS.SIS_Registro_Existe @Item = @Item, @Tabela = @Tabela, @Id = @IdRegistro, @Existe = @Existe OUTPUT;
            IF ISNULL(@Existe, 0) = 0
                SET @Recusa = N'Registro não encontrado.';
        END;

        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM SIS.Anexo a
                                     WHERE a.TABELA_REFERENCIA = @Tabela AND a.ID_REFERENCIA = @IdRegistro
                                       AND a.HASH_SHA256 = @HashSha256 AND a.SITUACAO = 'ATIVO')
            SET @Recusa = N'Este arquivo já está anexado a este registro.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_ANEXO;
            RETURN;
        END;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';

        INSERT INTO SIS.Anexo (TABELA_REFERENCIA, ID_REFERENCIA, ID_ANEXO_TIPO, NOME_ORIGINAL, NOME_ARQUIVO, PASTA_RELATIVA,
                               EXTENSAO, TAMANHO_BYTES, HASH_SHA256, DESCRICAO, USUARIO_CRIACAO)
        VALUES (@Tabela, @IdRegistro, @IdTipo, @NomeOriginal, @NomeArquivo, @PastaRelativa,
                @Extensao, @TamanhoBytes, @HashSha256, LTRIM(RTRIM(ISNULL(@Descricao, N''))), ISNULL(@Usuario, N''));
        SET @IdAnexo = CAST(SCOPE_IDENTITY() AS BIGINT);

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Arquivo anexado.' AS NVARCHAR(400)) AS MENSAGEM, @IdAnexo AS ID_ANEXO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível registrar o anexo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_ANEXO;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Anexos de um registro (aba "Anexos" das telas), mais recente
                primeiro. @IncluirExcluidos = 1 mostra também os excluídos
                (com quem excluiu, quando e o motivo).
                Permissão: VER na tela (@Item), que precisa manter a tabela.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Anexo_Listar @IdUsuario = 2, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = 3;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Listar]
    @IdUsuario         INT,
    @Item              VARCHAR(40),
    @Tabela            NVARCHAR(256),
    @IdRegistro        BIGINT,
    @IncluirExcluidos  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Anexo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver estes anexos.', 1;
        IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            THROW 50001, N'Esta tela não mostra anexos desse tipo de registro.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT a.ID_ANEXO,
               t.CODIGO                              AS TIPO_CODIGO,
               t.NOME                                AS TIPO_NOME,
               a.NOME_ORIGINAL,
               a.EXTENSAO,
               a.TAMANHO_BYTES,
               a.DESCRICAO,
               a.SITUACAO,
               a.DT_CRIACAO,
               a.USUARIO_CRIACAO,
               a.DT_EXCLUSAO,
               ISNULL(a.USUARIO_EXCLUSAO, N'')       AS USUARIO_EXCLUSAO,
               ISNULL(a.MOTIVO_EXCLUSAO, N'')        AS MOTIVO_EXCLUSAO
        FROM SIS.Anexo a WITH (NOLOCK)
        INNER JOIN SIS.Anexo_Tipo t WITH (NOLOCK) ON t.ID_ANEXO_TIPO = a.ID_ANEXO_TIPO
        WHERE a.TABELA_REFERENCIA = @Tabela
          AND a.ID_REFERENCIA = @IdRegistro
          AND (ISNULL(@IncluirExcluidos, 0) = 1 OR a.SITUACAO = 'ATIVO')
        ORDER BY a.ID_ANEXO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os anexos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Obter.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Dados para a API entregar o arquivo de um anexo (download):
                caminho completo (ANEXO_PASTA_RAIZ + PASTA_RELATIVA +
                NOME_ARQUIVO), nome original e hash para conferir o arquivo.
                Só anexo ativo, de tabela mantida pela tela (@Item).
                Permissão: VER na tela.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Anexo_Obter @IdUsuario = 2, @Item = 'SIS_USUARIO', @IdAnexo = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Obter]
    @IdUsuario  INT,
    @Item       VARCHAR(40),
    @IdAnexo    BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Anexo_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Tabela     NVARCHAR(256);
    DECLARE @Raiz       NVARCHAR(4000);

    BEGIN TRY
        SELECT @Tabela = a.TABELA_REFERENCIA
        FROM SIS.Anexo a WITH (NOLOCK)
        WHERE a.ID_ANEXO = @IdAnexo AND a.SITUACAO = 'ATIVO';

        IF @Tabela IS NULL
            THROW 50001, N'Anexo não encontrado.', 1;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0 OR SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            THROW 50001, N'Você não tem permissão para abrir este anexo.', 1;

        SET @Raiz = SIS.fn_SIS_Parametro('ANEXO_PASTA_RAIZ');
        IF RIGHT(@Raiz, 1) <> N'\' SET @Raiz = @Raiz + N'\';

        SET @EtapaAtual = 'Consulta';
        SELECT a.ID_ANEXO,
               a.NOME_ORIGINAL,
               a.EXTENSAO,
               a.TAMANHO_BYTES,
               a.HASH_SHA256,
               CAST(@Raiz + CASE WHEN a.PASTA_RELATIVA = '' THEN N'' ELSE CONVERT(NVARCHAR(50), a.PASTA_RELATIVA) + N'\' END
                    + CONVERT(NVARCHAR(100), a.NOME_ARQUIVO) AS NVARCHAR(4000)) AS CAMINHO_COMPLETO
        FROM SIS.Anexo a WITH (NOLOCK)
        WHERE a.ID_ANEXO = @IdAnexo;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível abrir o anexo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Excluir.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Exclui um anexo sem apagar (regra 56): marca SITUACAO =
                'EXCLUIDO' com quem, quando e o motivo (obrigatório). O arquivo
                continua em disco e o anexo continua visível com "mostrar
                excluídos".
                Permissão: ALTERAR na tela (@Item), que precisa manter a tabela.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_ANEXO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL): ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Excluir]
    @IdUsuario  INT,
    @Item       VARCHAR(40),
    @IdAnexo    BIGINT,
    @Motivo     NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Anexo_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Tabela     NVARCHAR(256);
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Linhas     INT           = 0;

    BEGIN TRY
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        SELECT @Tabela = a.TABELA_REFERENCIA FROM SIS.Anexo a WHERE a.ID_ANEXO = @IdAnexo AND a.SITUACAO = 'ATIVO';

        IF @Tabela IS NULL
            SET @Recusa = N'Anexo não encontrado ou já excluído.';
        IF @Recusa = N'' AND (SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 0 OR SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0)
            SET @Recusa = N'Você não tem permissão para excluir este anexo.';
        IF @Recusa = N'' AND @Motivo = N''
            SET @Recusa = N'Informe o motivo da exclusão.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdAnexo AS ID_ANEXO;
            RETURN;
        END;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';

        UPDATE a
           SET a.SITUACAO          = 'EXCLUIDO',
               a.DT_EXCLUSAO       = SYSDATETIME(),
               a.USUARIO_EXCLUSAO  = @Usuario,
               a.MOTIVO_EXCLUSAO   = @Motivo,
               a.DT_ALTERACAO      = SYSDATETIME(),
               a.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Anexo a
        WHERE a.ID_ANEXO = @IdAnexo
          AND a.SITUACAO = 'ATIVO';
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Anexo excluído.' ELSE N'O anexo já tinha sido excluído por outra pessoa.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdAnexo AS ID_ANEXO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível excluir o anexo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdAnexo AS ID_ANEXO;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Modulo_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Modulo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Módulos e telas" (exclusiva do administrador geral):
                a MESMA ÁRVORE do menu lateral (módulo > agrupadores > telas),
                só que completa: mostra também o que está desligado ou fora da
                licença, para o administrador geral ver o menu inteiro e ligar
                ou desligar cada parte.
                Uma linha por nó, já na ordem do menu, com a mesma chave do
                SIS_Menu_Listar (CHAVE / CHAVE_PAI / NIVEL), para a tela usar o
                mesmo componente de árvore:
                  TIPO           : MODULO / MENU / TELA
                  PODE_HABILITAR : 1 em módulo e tela (tem a chave liga/desliga);
                                   0 em agrupador (MENU), que só aparece se
                                   tiver tela em uso dentro
                  NA_LICENCA     : módulo liberado pela licença ativa
                  HABILITADO     : ligado pelo administrador geral
                  EM_USO         : aparece para os usuários (licença + módulo
                                   habilitado + tela habilitada)
                  PROTEGIDO      : não pode ser desligado (módulo SIS e a
                                   própria tela "Módulos e telas")
                Permissão: SIS_MODULO / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c, pedido 5 do Celso).
    v1.1 (16/11/2026) - Mesma estrutura do menu (pedido do Celso): agrupadores
                        (MENU) também aparecem; CHAVE, CHAVE_PAI, NIVEL e
                        PODE_HABILITAR; NOME só do nó e CAMINHO com o caminho.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Modulo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Modulo_Listar]
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Modulo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_MODULO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os módulos.', 1;

        SET @EtapaAtual = 'Consulta';
        WITH Arvore AS
        (
            SELECT i.ID_ITEM, 1 AS NIVEL,
                   CAST(i.NOME AS NVARCHAR(400)) AS CAMINHO_NOME,
                   CAST(RIGHT('00000' + CONVERT(VARCHAR(5), i.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), i.ID_ITEM), 10) AS VARCHAR(400)) AS ORDEM_CAMINHO
            FROM SIS.Item i WITH (NOLOCK)
            WHERE i.ID_ITEM_PAI IS NULL
              AND i.ATIVO = 1
            UNION ALL
            SELECT c.ID_ITEM, a.NIVEL + 1,
                   CAST(a.CAMINHO_NOME + N' > ' + c.NOME AS NVARCHAR(400)),
                   CAST(a.ORDEM_CAMINHO + '/' + RIGHT('00000' + CONVERT(VARCHAR(5), c.ORDEM), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), c.ID_ITEM), 10) AS VARCHAR(400))
            FROM SIS.Item c WITH (NOLOCK)
            INNER JOIN Arvore a ON a.ID_ITEM = c.ID_ITEM_PAI
            WHERE c.ATIVO = 1
        )
        SELECT x.TIPO, x.CHAVE, x.CHAVE_PAI, x.NIVEL, x.CODIGO, x.NOME, x.CAMINHO, x.MODULO_CODIGO,
               x.EXCLUSIVO_GERAL, x.PODE_HABILITAR, x.NA_LICENCA, x.HABILITADO, x.EM_USO, x.PROTEGIDO
        FROM (
                SELECT CAST('MODULO' AS VARCHAR(10))                                   AS TIPO,
                       CAST('M' + CONVERT(VARCHAR(10), m.ID_MODULO) AS VARCHAR(12))    AS CHAVE,
                       CAST('' AS VARCHAR(12))                                         AS CHAVE_PAI,
                       0                                                               AS NIVEL,
                       CAST(m.CODIGO AS VARCHAR(40))                                   AS CODIGO,
                       CAST(m.NOME AS NVARCHAR(80))                                    AS NOME,
                       CAST(m.NOME AS NVARCHAR(400))                                   AS CAMINHO,
                       m.CODIGO                                                        AS MODULO_CODIGO,
                       CAST(0 AS BIT)                                                  AS EXCLUSIVO_GERAL,
                       CAST(1 AS BIT)                                                  AS PODE_HABILITAR,
                       m.LIBERADO_LICENCA                                              AS NA_LICENCA,
                       m.HABILITADO,
                       CAST(CASE WHEN m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END AS BIT) AS EM_USO,
                       CAST(CASE WHEN m.CODIGO = 'SIS' THEN 1 ELSE 0 END AS BIT)       AS PROTEGIDO,
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10) AS VARCHAR(500)) AS ORDEM_GERAL
                FROM SIS.Modulo m WITH (NOLOCK)
                WHERE m.ATIVO = 1
                UNION ALL
                SELECT CAST(i.TIPO AS VARCHAR(10)),
                       CAST('I' + CONVERT(VARCHAR(10), i.ID_ITEM) AS VARCHAR(12)),
                       CAST(CASE WHEN i.ID_ITEM_PAI IS NULL THEN 'M' + CONVERT(VARCHAR(10), i.ID_MODULO)
                                 ELSE 'I' + CONVERT(VARCHAR(10), i.ID_ITEM_PAI) END AS VARCHAR(12)),
                       ar.NIVEL,
                       CAST(i.CODIGO AS VARCHAR(40)),
                       CAST(i.NOME AS NVARCHAR(80)),
                       CAST(m.NOME + N' > ' + ar.CAMINHO_NOME AS NVARCHAR(400)),
                       m.CODIGO,
                       i.EXCLUSIVO_GERAL,
                       CAST(CASE WHEN i.TIPO = 'TELA' THEN 1 ELSE 0 END AS BIT),
                       m.LIBERADO_LICENCA,
                       CAST(CASE WHEN i.TIPO = 'TELA' THEN i.HABILITADO ELSE 1 END AS BIT),
                       CAST(CASE WHEN i.TIPO = 'TELA'
                                 THEN CASE WHEN m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 AND i.HABILITADO = 1 THEN 1 ELSE 0 END
                                 ELSE CASE WHEN m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END
                            END AS BIT),
                       CAST(CASE WHEN i.CODIGO = 'SIS_MODULO' THEN 1 ELSE 0 END AS BIT),
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10)
                            + '|' + ar.ORDEM_CAMINHO AS VARCHAR(500))
                FROM Arvore ar
                INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.ID_ITEM   = ar.ID_ITEM
                INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
                WHERE m.ATIVO = 1
             ) x
        ORDER BY x.ORDEM_GERAL
        OPTION (MAXRECURSION 20);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os módulos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Habilitacao_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Habilitacao_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga ou desliga um módulo ou uma tela para uso (pedido 5 do
                Celso): @Tipo 'MODULO' (código do módulo, ex.: FIN) ou 'TELA'
                (código do item, ex.: FIN_CONCILIACAO).
                Não desliga o que é protegido (módulo SIS e a tela "Módulos e
                telas"), para o administrador geral nunca se trancar fora.
                Habilitar não libera o que a licença não libera: o uso exige
                os dois.
                Permissão: SIS_MODULO / ALTERAR (só o administrador geral).
                Devolve 1 linha: SUCESSO, MENSAGEM.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL): ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Habilitacao_Gravar]
    @IdUsuario   INT,
    @Tipo        VARCHAR(10),
    @Codigo      VARCHAR(40),
    @Habilitado  BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Habilitacao_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Linhas     INT           = 0;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_MODULO', 'ALTERAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para habilitar módulos e telas.' AS NVARCHAR(400)) AS MENSAGEM;
            RETURN;
        END;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Tipo       = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Codigo     = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Habilitado = ISNULL(@Habilitado, 0);

        IF @Tipo NOT IN ('MODULO', 'TELA')
            SET @Recusa = N'Informe se é módulo ou tela.';
        IF @Recusa = N'' AND @Tipo = 'MODULO' AND NOT EXISTS (SELECT 1 FROM SIS.Modulo m WHERE m.CODIGO = @Codigo)
            SET @Recusa = N'Módulo não encontrado.';
        IF @Recusa = N'' AND @Tipo = 'TELA' AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = @Codigo AND i.TIPO = 'TELA')
            SET @Recusa = N'Tela não encontrada.';
        IF @Recusa = N'' AND @Habilitado = 0 AND ((@Tipo = 'MODULO' AND @Codigo = 'SIS') OR (@Tipo = 'TELA' AND @Codigo = 'SIS_MODULO'))
            SET @Recusa = N'Este item é protegido e não pode ser desligado.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        IF @Tipo = 'MODULO'
        BEGIN
            UPDATE m SET m.HABILITADO = @Habilitado, m.DT_ALTERACAO = SYSDATETIME(), m.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Modulo m
            WHERE m.CODIGO = @Codigo AND m.HABILITADO <> @Habilitado;
            SET @Linhas = @@ROWCOUNT;
        END;

        IF @Tipo = 'TELA'
        BEGIN
            UPDATE i SET i.HABILITADO = @Habilitado, i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Item i
            WHERE i.CODIGO = @Codigo AND i.HABILITADO <> @Habilitado;
            SET @Linhas = @@ROWCOUNT;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 0 THEN N'Nenhuma alteração.'
                         WHEN @Habilitado = 1 THEN N'Habilitado para uso.'
                         ELSE N'Desabilitado: não aparece mais para os usuários.' END AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a habilitação. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Enfileirar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Enfileirar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Única porta de entrada da fila de e-mails (PADRAO_EMAIL seção
                1). Chamada pelas orquestradoras e rotinas, nunca pela tela.
                Só faz INSERT: quem envia é o serviço.
                - Destinatários: ";" ou "," como separador; endereços
                  inválidos são descartados (e registrados no log); sem
                  nenhum válido, não grava e devolve @IdEmail = NULL.
                - @ChaveOrigem repetida: não grava de novo; devolve o
                  @IdEmail que já existe (o mesmo aviso nunca sai duas
                  vezes).
                - Banco _LOCAL (teste): o e-mail vai só para o parâmetro
                  EMAIL_TESTE, com "[TESTE]" no assunto e o endereço pedido
                  guardado em PARA_ORIGINAL (MODO_TESTE = 1). Proteção
                  extra, além do @bRunLocal das orquestradoras.
                  Exceção: tipo listado em EMAIL_LOCAL_LIBERADOS (separado
                  por vírgula) sai de verdade mesmo no _LOCAL (v1.1).
                - Assunto sem quebra de linha (texto puro, regra 14).
                - @Anexos: JSON '[{"caminho":"C:\\...\\a.pdf","nome":"a.pdf",
                  "cid":""}]'.
                - ID_LOTE vem do contexto da sessão, se houver.
                Se quem chamou já está numa transação, o INSERT entra nela
                (sai junto com a operação de negócio, ou não sai).
                Erro interno: grava em SIS.Log_Erro e devolve @IdEmail NULL
                (falha de e-mail não desfaz a operação de negócio), salvo se
                a transação de quem chamou ficou condenada (aí repassa o
                erro).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (17/11/2026) - Exceção controlada à proteção do banco _LOCAL (pedido
                        do Celso, 03c): tipos listados no parâmetro
                        EMAIL_LOCAL_LIBERADOS (ex.: COMUNICADO) saem para os
                        destinatários reais. Vazio = tudo desviado, como antes.

  Homologação (LOCAL):
    -- DECLARE @Id BIGINT;
    -- EXEC SIS.SIS_Email_Enfileirar @Para = N'x@y.com', @Assunto = N'Teste', @CorpoHTML = N'<p>oi</p>',
    --      @Tipo = 'TESTE', @Origem = N'manual', @IdEmail = @Id OUTPUT; SELECT @Id;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Enfileirar]
    @Para         NVARCHAR(MAX),
    @Assunto      NVARCHAR(400),
    @CorpoHTML    NVARCHAR(MAX),
    @Tipo         VARCHAR(30),
    @Origem       NVARCHAR(256),
    @ChaveOrigem  NVARCHAR(200) = NULL,
    @Cc           NVARCHAR(MAX) = NULL,
    @Cco          NVARCHAR(MAX) = NULL,
    @Grupo        VARCHAR(30)   = NULL,
    @Conta        VARCHAR(10)   = 'INTERNA',
    @Anexos       NVARCHAR(MAX) = NULL,
    @IdEmail      BIGINT        OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Email_Enfileirar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Destinatários';
    DECLARE @ParaOk      NVARCHAR(MAX);
    DECLARE @CcOk        NVARCHAR(MAX);
    DECLARE @CcoOk       NVARCHAR(MAX);
    DECLARE @Invalidos   NVARCHAR(MAX);
    DECLARE @ParaOrig    NVARCHAR(MAX) = N'';
    DECLARE @Teste       BIT           = CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 1 ELSE 0 END;
    DECLARE @IdLote      BIGINT        = TRY_CONVERT(BIGINT, SESSION_CONTEXT(N'ID_LOTE'));
    DECLARE @MinhaTran   BIT           = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;

    SET @IdEmail = NULL;

    BEGIN TRY
        SET @ChaveOrigem = NULLIF(LTRIM(RTRIM(@ChaveOrigem)), N'');
        SET @Tipo        = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Conta       = UPPER(LTRIM(RTRIM(ISNULL(@Conta, 'INTERNA'))));
        SET @Assunto     = LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@Assunto, N''), NCHAR(13) + NCHAR(10), N' '), NCHAR(13), N' '), NCHAR(10), N' '), NCHAR(9), N' ')));

        IF @ChaveOrigem IS NOT NULL
        BEGIN
            SELECT @IdEmail = f.ID_EMAIL FROM SIS.Email_Fila f WHERE f.CHAVE_ORIGEM = @ChaveOrigem;
            IF @IdEmail IS NOT NULL RETURN;
        END;

        -- Separa válidos e inválidos (sem repetir, na ordem em que vieram)
        WITH e AS
        (
            SELECT x.LISTA, LTRIM(RTRIM(s.value)) AS EMAIL, MIN(s.ordinal) AS ORDEM
            FROM (VALUES (1, ISNULL(@Para, N'')), (2, ISNULL(@Cc, N'')), (3, ISNULL(@Cco, N''))) x (LISTA, TEXTO)
            CROSS APPLY STRING_SPLIT(REPLACE(x.TEXTO, N',', N';'), N';', 1) s
            WHERE LTRIM(RTRIM(s.value)) <> N''
            GROUP BY x.LISTA, LTRIM(RTRIM(s.value))
        )
        SELECT @ParaOk    = STRING_AGG(CASE WHEN e.LISTA = 1 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @CcOk      = STRING_AGG(CASE WHEN e.LISTA = 2 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @CcoOk     = STRING_AGG(CASE WHEN e.LISTA = 3 AND SIS.fn_SIS_Email_Valido(e.EMAIL) = 1 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM),
               @Invalidos = STRING_AGG(CASE WHEN SIS.fn_SIS_Email_Valido(e.EMAIL) = 0 THEN CONVERT(NVARCHAR(MAX), e.EMAIL) END, N'; ') WITHIN GROUP (ORDER BY e.LISTA, e.ORDEM)
        FROM e;

        SET @ParaOk = ISNULL(@ParaOk, N'');
        SET @CcOk   = ISNULL(@CcOk, N'');
        SET @CcoOk  = ISNULL(@CcoOk, N'');

        IF ISNULL(@Invalidos, N'') <> N''
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, 0,
                    LEFT(N'Endereços inválidos descartados (' + ISNULL(@Origem, N'') + N' / ' + @Tipo + N'): ' + @Invalidos, 4000), 0, SYSDATETIME());

        IF @ParaOk = N''
        BEGIN
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, 0,
                    LEFT(N'E-mail não enfileirado: nenhum destinatário válido (' + ISNULL(@Origem, N'') + N' / ' + @Tipo + N' / ' + @Assunto + N').', 4000), 0, SYSDATETIME());
            RETURN;
        END;

        SET @EtapaAtual = 'Modo teste';
        IF @Teste = 1
           AND EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(SIS.fn_SIS_Parametro('EMAIL_LOCAL_LIBERADOS'), N''), N',') l
                       WHERE UPPER(LTRIM(RTRIM(l.value))) = UPPER(@Tipo))
            SET @Teste = 0;   -- tipo liberado: sai para os destinatários reais

        IF @Teste = 1
        BEGIN
            SET @ParaOrig = @ParaOk
                          + CASE WHEN @CcOk  <> N'' THEN N' | cc: '  + @CcOk  ELSE N'' END
                          + CASE WHEN @CcoOk <> N'' THEN N' | cco: ' + @CcoOk ELSE N'' END;
            SET @ParaOk   = ISNULL(SIS.fn_SIS_Parametro('EMAIL_TESTE'), N'');
            SET @CcOk     = N'';
            SET @CcoOk    = N'';
            SET @Assunto  = N'[TESTE] ' + @Assunto;

            IF SIS.fn_SIS_Email_Valido(@ParaOk) = 0
            BEGIN
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, 0, N'E-mail não enfileirado: parâmetro EMAIL_TESTE vazio ou inválido.', 0, SYSDATETIME());
                RETURN;
            END;
        END;

        SET @EtapaAtual = 'Gravação';
        IF @MinhaTran = 1 BEGIN TRANSACTION;

        INSERT INTO SIS.Email_Fila (CHAVE_ORIGEM, TIPO, CONTA, GRUPO, PARA, CC, CCO, PARA_ORIGINAL, ASSUNTO, CORPO_HTML, ORIGEM, ID_LOTE, MODO_TESTE)
        VALUES (@ChaveOrigem, @Tipo, @Conta, LTRIM(RTRIM(ISNULL(@Grupo, ''))), LEFT(@ParaOk, 2000), LEFT(@CcOk, 2000), LEFT(@CcoOk, 2000),
                LEFT(@ParaOrig, 4000), LEFT(@Assunto, 400), ISNULL(@CorpoHTML, N''), LEFT(ISNULL(@Origem, N''), 256), @IdLote, @Teste);

        SET @IdEmail = SCOPE_IDENTITY();

        IF ISNULL(@Anexos, N'') <> N''
            INSERT INTO SIS.Email_Fila_Anexo (ID_EMAIL, CAMINHO, NOME_EXIBICAO, CID, ORDEM)
            SELECT @IdEmail,
                   LTRIM(RTRIM(j.caminho)),
                   ISNULL(NULLIF(LTRIM(RTRIM(j.nome)), N''), RIGHT(LTRIM(RTRIM(j.caminho)), CHARINDEX(N'\', REVERSE(N'\' + LTRIM(RTRIM(j.caminho)))) - 1)),
                   LTRIM(RTRIM(ISNULL(j.cid, ''))),
                   CAST(k.[key] AS SMALLINT) + 1
            FROM OPENJSON(@Anexos) k
            CROSS APPLY OPENJSON(k.value) WITH (caminho NVARCHAR(1000) '$.caminho', nome NVARCHAR(260) '$.nome', cid VARCHAR(60) '$.cid') j
            WHERE LTRIM(RTRIM(ISNULL(j.caminho, N''))) <> N'';

        IF @MinhaTran = 1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @MinhaTran = 1 AND @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Mesma chave gravada ao mesmo tempo por outra sessão: devolve a que ficou
        IF ERROR_NUMBER() IN (2601, 2627) AND @ChaveOrigem IS NOT NULL AND XACT_STATE() <> -1
        BEGIN
            SELECT @IdEmail = f.ID_EMAIL FROM SIS.Email_Fila f WHERE f.CHAVE_ORIGEM = @ChaveOrigem;
            RETURN;
        END;

        IF XACT_STATE() = -1 THROW;

        SET @IdEmail = NULL;
        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Capturar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Capturar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço do sistema (a cada minuto). Pega até
                @Quantidade e-mails PENDENTES já no horário, marca como
                PROCESSANDO e soma 1 tentativa, numa única instrução com
                UPDLOCK + READPAST: dois serviços (ou duas chamadas) nunca
                pegam o mesmo e-mail.
                Devolve um e-mail por linha, com os anexos em JSON
                (ANEXOS_JSON: [{"CAMINHO","NOME_EXIBICAO","CID"}]).
                Depois de tentar enviar, o serviço chama
                SIS_Email_Resultado_Gravar para cada um.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Capturar @Servidor = N'TESTE', @Quantidade = 5;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Capturar]
    @Servidor    NVARCHAR(128),
    @Quantidade  INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Capturar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Captura';
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Pegos      TABLE (ID_EMAIL BIGINT PRIMARY KEY);

    BEGIN TRY
        SET @Quantidade = CASE WHEN ISNULL(@Quantidade, 0) < 1 THEN 20 WHEN @Quantidade > 200 THEN 200 ELSE @Quantidade END;

        WITH c AS
        (
            SELECT TOP (@Quantidade) f.ID_EMAIL, f.STATUS, f.TENTATIVAS, f.DT_CAPTURA, f.SERVIDOR
            FROM SIS.Email_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE f.STATUS = 'PENDENTE'
              AND f.PROXIMA_TENTATIVA <= @Agora
            ORDER BY f.PROXIMA_TENTATIVA, f.ID_EMAIL
        )
        UPDATE c
           SET c.STATUS     = 'PROCESSANDO',
               c.TENTATIVAS = c.TENTATIVAS + 1,
               c.DT_CAPTURA = @Agora,
               c.SERVIDOR   = LEFT(ISNULL(@Servidor, N''), 128)
        OUTPUT inserted.ID_EMAIL INTO @Pegos (ID_EMAIL);

        SET @EtapaAtual = 'Retorno';
        SELECT f.ID_EMAIL, f.TIPO, f.CONTA, f.PARA, f.CC, f.CCO, f.ASSUNTO, f.CORPO_HTML, f.TENTATIVAS, f.MODO_TESTE,
               ISNULL((SELECT a.CAMINHO, a.NOME_EXIBICAO, a.CID
                       FROM SIS.Email_Fila_Anexo a
                       WHERE a.ID_EMAIL = f.ID_EMAIL
                       ORDER BY a.ORDEM, a.ID_EMAIL_ANEXO
                       FOR JSON PATH), N'[]') AS ANEXOS_JSON
        FROM SIS.Email_Fila f
        INNER JOIN @Pegos p ON p.ID_EMAIL = f.ID_EMAIL
        ORDER BY f.ID_EMAIL;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Resultado_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Resultado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço, depois de tentar enviar um e-mail
                capturado (PADRAO_EMAIL regras 3 a 5).
                @Resultado:
                  ENVIADO         : STATUS = ENVIADO.
                  ERRO_TEMPORARIO : volta para PENDENTE e espera 1, 5, 15 e
                                    depois 60 min a cada tentativa; passou de
                                    EMAIL_TENTATIVAS_MAX, vira ERRO.
                  ERRO_PERMANENTE : ERRO direto (endereço inválido, anexo
                                    que não existe, recusa definitiva).
                Toda tentativa vai para SIS.Email_Log.
                E-mail que terminou em ERRO gera um alerta técnico para o
                parâmetro EMAIL_ADMIN_ALERTA (se preenchido), uma vez por
                e-mail (CHAVE_ORIGEM 'ALERTA_EMAIL:<id>'). Alerta que falha
                não gera outro alerta.
                Devolve SUCESSO, MENSAGEM, ID (ID = ID_EMAIL).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (17/11/2026) - Nome do sistema no assunto do alerta pelo parâmetro SISTEMA_NOME.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Resultado_Gravar @IdEmail = 1, @Resultado = 'ENVIADO', @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Resultado_Gravar]
    @IdEmail    BIGINT,
    @Resultado  VARCHAR(20),
    @Mensagem   NVARCHAR(1000) = NULL,
    @Servidor   NVARCHAR(128)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @AssuntoAlerta NVARCHAR(400);
    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Email_Resultado_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Status      VARCHAR(12);
    DECLARE @Tentativas  INT;
    DECLARE @Tipo        VARCHAR(30);
    DECLARE @Assunto     NVARCHAR(400);
    DECLARE @Para        NVARCHAR(2000);
    DECLARE @Max         INT           = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_TENTATIVAS_MAX'), 5);
    DECLARE @Novo        VARCHAR(12);
    DECLARE @Espera      INT;
    DECLARE @Agora       DATETIME2(0)  = SYSDATETIME();
    DECLARE @Alerta      NVARCHAR(256);
    DECLARE @Corpo       NVARCHAR(MAX);
    DECLARE @IdAlerta    BIGINT;
    DECLARE @Chave       NVARCHAR(200);

    BEGIN TRY
        SET @Resultado = UPPER(LTRIM(RTRIM(ISNULL(@Resultado, ''))));
        SET @Mensagem  = LEFT(ISNULL(@Mensagem, N''), 1000);
        IF @Max < 1 SET @Max = 1;

        IF @Resultado NOT IN ('ENVIADO', 'ERRO_TEMPORARIO', 'ERRO_PERMANENTE')
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Resultado inválido.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        BEGIN TRANSACTION;

        SELECT @Status = f.STATUS, @Tentativas = f.TENTATIVAS, @Tipo = f.TIPO, @Assunto = f.ASSUNTO, @Para = f.PARA
        FROM SIS.Email_Fila f WITH (UPDLOCK, ROWLOCK)
        WHERE f.ID_EMAIL = @IdEmail;

        IF @Status IS NULL OR @Status <> 'PROCESSANDO'
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Status IS NULL THEN N'E-mail não encontrado.' ELSE N'O e-mail não está em processamento (situação: ' + @Status + N').' END AS NVARCHAR(400)) AS MENSAGEM,
                   @IdEmail AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Novo = CASE WHEN @Resultado = 'ENVIADO' THEN 'ENVIADO'
                         WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Tentativas < @Max THEN 'PENDENTE'
                         ELSE 'ERRO' END;
        SET @Espera = CASE WHEN @Tentativas <= 1 THEN 1 WHEN @Tentativas = 2 THEN 5 WHEN @Tentativas = 3 THEN 15 ELSE 60 END;

        UPDATE f
           SET f.STATUS            = @Novo,
               f.DT_ENVIO          = CASE WHEN @Novo = 'ENVIADO' THEN @Agora ELSE f.DT_ENVIO END,
               f.ULTIMO_ERRO       = CASE WHEN @Novo = 'ENVIADO' THEN N'' ELSE @Mensagem END,
               f.PROXIMA_TENTATIVA = CASE WHEN @Novo = 'PENDENTE' THEN DATEADD(MINUTE, @Espera, @Agora) ELSE f.PROXIMA_TENTATIVA END,
               f.SERVIDOR          = CASE WHEN ISNULL(@Servidor, N'') <> N'' THEN LEFT(@Servidor, 128) ELSE f.SERVIDOR END,
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = N'sistema'
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, SERVIDOR, USUARIO)
        VALUES (@IdEmail, @Tentativas,
                CASE WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Novo = 'ERRO' THEN 'ERRO_PERMANENTE' ELSE @Resultado END,
                CASE WHEN @Resultado = 'ERRO_TEMPORARIO' AND @Novo = 'ERRO' THEN LEFT(N'Limite de tentativas atingido. ' + @Mensagem, 1000) ELSE @Mensagem END,
                LEFT(ISNULL(@Servidor, N''), 128), N'sistema');

        -- Alerta técnico (uma vez por e-mail; alerta não gera alerta)
        SET @EtapaAtual = 'Alerta';
        SET @Alerta = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
        IF @Novo = 'ERRO' AND @Tipo <> 'ALERTA_EMAIL' AND @Alerta <> N''
        BEGIN
            SET @Chave = N'ALERTA_EMAIL:' + CAST(@IdEmail AS NVARCHAR(20));
            SET @Corpo = SIS.fn_SIS_Email_HTML(
                             N'Falha no envio de e-mail', 'ALERTA',
                             N'<p>Um e-mail do sistema não pôde ser enviado e foi marcado como erro.</p>'
                           + N'<table style="border-collapse:collapse;font-size:13px;">'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Número</td><td style="padding:4px 8px;">' + CAST(@IdEmail AS NVARCHAR(20)) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Tipo</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Tipo) + N'</td></tr>'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Assunto</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Assunto) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Para</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Para) + N'</td></tr>'
                           + N'<tr><td style="padding:4px 8px;color:#777777;">Tentativas</td><td style="padding:4px 8px;">' + CAST(@Tentativas AS NVARCHAR(10)) + N'</td></tr>'
                           + N'<tr style="background:#f5f5f5;"><td style="padding:4px 8px;color:#777777;">Erro</td><td style="padding:4px 8px;">' + SIS.fn_SIS_Texto_HTML(@Mensagem) + N'</td></tr>'
                           + N'</table>'
                           + N'<p>Para reenviar, use a tela Sistema &gt; E-mails &gt; E-mails enviados.</p>',
                             @NomeProc, '', 0);

            SET @AssuntoAlerta = ISNULL(NULLIF(SIS.fn_SIS_Parametro('SISTEMA_NOME'), N''), N'SistemaCMJ') + N' - FALHA no envio de e-mail';
            EXEC SIS.SIS_Email_Enfileirar
                 @Para = @Alerta,
                 @Assunto = @AssuntoAlerta,
                 @CorpoHTML = @Corpo,
                 @Tipo = 'ALERTA_EMAIL',
                 @Origem = @NomeProc,
                 @ChaveOrigem = @Chave,
                 @IdEmail = @IdAlerta OUTPUT;
        END;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE @Novo WHEN 'ENVIADO'  THEN N'Enviado.'
                               WHEN 'PENDENTE' THEN N'Nova tentativa em ' + CAST(@Espera AS NVARCHAR(5)) + N' min.'
                               ELSE N'Marcado como erro.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o resultado do envio. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Presos_Liberar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Presos_Liberar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Rotina automática (SIS.Rotina EMAIL_PRESOS). Um e-mail que
                ficou em PROCESSANDO mais que EMAIL_MINUTOS_PRESO minutos
                (o serviço caiu no meio do envio) volta para PENDENTE, ou vai
                para ERRO se já gastou todas as tentativas. Registra no
                SIS.Email_Log (LIBERADO). Sem parâmetro e sem retorno, como
                toda rotina da agenda.
                Pode repetir um envio se o serviço caiu depois de enviar e
                antes de gravar o resultado (raro; preferível a perder o
                e-mail).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Presos_Liberar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Presos_Liberar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Presos_Liberar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Parâmetros';
    DECLARE @Minutos    INT;
    DECLARE @Max        INT;
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Soltos     TABLE (ID_EMAIL BIGINT, TENTATIVAS INT, STATUS VARCHAR(12));

    BEGIN TRY
        SET @Minutos = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_MINUTOS_PRESO'), 15);
        SET @Max     = ISNULL(SIS.fn_SIS_Parametro_Inteiro('EMAIL_TENTATIVAS_MAX'), 5);
        IF @Minutos < 5 SET @Minutos = 5;
        IF @Max < 1 SET @Max = 1;

        SET @EtapaAtual = 'Liberação';
        BEGIN TRANSACTION;

        UPDATE f
           SET f.STATUS            = CASE WHEN f.TENTATIVAS >= @Max THEN 'ERRO' ELSE 'PENDENTE' END,
               f.PROXIMA_TENTATIVA = @Agora,
               f.ULTIMO_ERRO       = N'Ficou preso em processamento (o serviço parou no meio do envio).',
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = N'sistema'
        OUTPUT inserted.ID_EMAIL, inserted.TENTATIVAS, inserted.STATUS INTO @Soltos (ID_EMAIL, TENTATIVAS, STATUS)
        FROM SIS.Email_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE f.STATUS = 'PROCESSANDO'
          AND f.DT_CAPTURA < DATEADD(MINUTE, -@Minutos, @Agora);

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, USUARIO)
        SELECT s.ID_EMAIL, s.TENTATIVAS, 'LIBERADO',
               CASE WHEN s.STATUS = 'ERRO' THEN N'Preso em processamento; tentativas esgotadas: marcado como erro.'
                    ELSE N'Preso em processamento há mais de ' + CAST(@Minutos AS NVARCHAR(10)) + N' min: volta para a fila.' END,
               N'sistema'
        FROM @Soltos s;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "E-mails enviados" (Sistema > E-mails): a fila com
                filtro por situação, período (data de criação) e texto
                (assunto, destinatário ou tipo). Mais recente primeiro.
                Sem o corpo (ver SIS_Email_Obter).
                Permissão: VER em SIS_EMAIL_FILA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Listar @IdUsuario = 2, @Status = 'ERRO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Listar]
    @IdUsuario  INT,
    @Status     VARCHAR(12)   = NULL,
    @DtInicio   DATE          = NULL,
    @DtFim      DATE          = NULL,
    @Texto      NVARCHAR(200) = NULL,
    @MaxLinhas  INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os e-mails do sistema.', 1;

        SET @Status    = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Status, '')))), '');
        SET @Texto     = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 5000 THEN 500 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               f.ID_EMAIL, f.DT_CRIACAO, f.TIPO, f.CONTA, f.STATUS, f.PARA, f.PARA_ORIGINAL, f.ASSUNTO,
               f.TENTATIVAS, f.PROXIMA_TENTATIVA, f.DT_ENVIO, f.ULTIMO_ERRO, f.MODO_TESTE, f.ORIGEM, f.GRUPO, f.ID_LOTE,
               (SELECT COUNT(*) FROM SIS.Email_Fila_Anexo a WHERE a.ID_EMAIL = f.ID_EMAIL AND a.CID = '') AS QTD_ANEXOS
        FROM SIS.Email_Fila f WITH (NOLOCK)
        WHERE (@Status   IS NULL OR f.STATUS = @Status)
          AND (@DtInicio IS NULL OR f.DT_CRIACAO >= @DtInicio)
          AND (@DtFim    IS NULL OR f.DT_CRIACAO <  DATEADD(DAY, 1, CAST(@DtFim AS DATETIME2(0))))
          AND (@Texto    IS NULL OR f.ASSUNTO LIKE N'%' + @Texto + N'%' OR f.PARA LIKE N'%' + @Texto + N'%'
                                 OR f.PARA_ORIGINAL LIKE N'%' + @Texto + N'%' OR f.TIPO LIKE N'%' + @Texto + N'%')
        ORDER BY f.ID_EMAIL DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os e-mails. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Obter.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Detalhe de um e-mail da fila para a tela (pré-visualizar o
                corpo, ver anexos e o histórico de tentativas).
                Devolve 3 conjuntos: 1) o e-mail com o corpo; 2) os anexos;
                3) o histórico (SIS.Email_Log), mais recente primeiro.
                Permissão: VER em SIS_EMAIL_FILA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Obter @IdUsuario = 2, @IdEmail = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Obter]
    @IdUsuario  INT,
    @IdEmail    BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os e-mails do sistema.', 1;

        IF NOT EXISTS (SELECT 1 FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @IdEmail)
            THROW 50001, N'E-mail não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT f.ID_EMAIL, f.DT_CRIACAO, f.TIPO, f.CONTA, f.STATUS, f.PARA, f.CC, f.CCO, f.PARA_ORIGINAL, f.ASSUNTO, f.CORPO_HTML,
               f.TENTATIVAS, f.DT_ENVIO, f.ULTIMO_ERRO, f.MODO_TESTE, f.ORIGEM, f.GRUPO, f.CHAVE_ORIGEM, f.ID_LOTE, f.USUARIO_CRIACAO
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        SELECT a.ID_EMAIL_ANEXO, a.NOME_EXIBICAO, a.CAMINHO, a.CID, a.ORDEM
        FROM SIS.Email_Fila_Anexo a
        WHERE a.ID_EMAIL = @IdEmail
        ORDER BY a.ORDEM, a.ID_EMAIL_ANEXO;

        SELECT l.ID_EMAIL_LOG, l.DT_REGISTRO, l.TENTATIVA, l.RESULTADO, l.MENSAGEM, l.SERVIDOR, l.USUARIO
        FROM SIS.Email_Log l
        WHERE l.ID_EMAIL = @IdEmail
        ORDER BY l.ID_EMAIL_LOG DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível abrir o e-mail. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Email_Situacao_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Situacao_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "E-mails enviados":
                @Acao = 'REENVIAR': e-mail em ERRO ou CANCELADO volta para a
                        fila (PENDENTE, tentativas zeradas). Permissão
                        ENVIAR. E-mail já enviado não é reenviado por aqui
                        (evita mandar duas vezes ao cliente).
                @Acao = 'CANCELAR': e-mail PENDENTE ou em ERRO não sai mais.
                        Permissão CANCELAR. @Motivo obrigatório.
                Tudo fica no SIS.Email_Log com o usuário.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Situacao_Gravar @IdUsuario = 2, @IdEmail = 1, @Acao = 'REENVIAR';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Situacao_Gravar]
    @IdUsuario  INT,
    @IdEmail    BIGINT,
    @Acao       VARCHAR(10),
    @Motivo     NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Situacao_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Status     VARCHAR(12);
    DECLARE @Tentativas INT;
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();

    BEGIN TRY
        SET @Acao   = UPPER(LTRIM(RTRIM(ISNULL(@Acao, ''))));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF @Acao NOT IN ('REENVIAR', 'CANCELAR')
            SET @Recusa = N'Ação inválida.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', CASE @Acao WHEN 'REENVIAR' THEN 'ENVIAR' ELSE 'CANCELAR' END) = 0
            SET @Recusa = CASE @Acao WHEN 'REENVIAR' THEN N'Você não tem permissão para reenviar e-mails.' ELSE N'Você não tem permissão para cancelar e-mails.' END;
        IF @Recusa = N'' AND @Acao = 'CANCELAR' AND @Motivo = N''
            SET @Recusa = N'Informe o motivo do cancelamento.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        SELECT @Status = f.STATUS, @Tentativas = f.TENTATIVAS
        FROM SIS.Email_Fila f WITH (UPDLOCK, ROWLOCK)
        WHERE f.ID_EMAIL = @IdEmail;

        SET @Recusa = CASE WHEN @Status IS NULL THEN N'E-mail não encontrado.'
                           WHEN @Acao = 'REENVIAR' AND @Status NOT IN ('ERRO', 'CANCELADO')
                                THEN N'Só e-mail com erro ou cancelado pode ser reenviado (situação: ' + @Status + N').'
                           WHEN @Acao = 'CANCELAR' AND @Status NOT IN ('PENDENTE', 'ERRO')
                                THEN N'Só e-mail pendente ou com erro pode ser cancelado (situação: ' + @Status + N').'
                           ELSE N'' END;

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
            RETURN;
        END;

        UPDATE f
           SET f.STATUS            = CASE @Acao WHEN 'REENVIAR' THEN 'PENDENTE' ELSE 'CANCELADO' END,
               f.TENTATIVAS        = CASE @Acao WHEN 'REENVIAR' THEN 0 ELSE f.TENTATIVAS END,
               f.PROXIMA_TENTATIVA = CASE @Acao WHEN 'REENVIAR' THEN @Agora ELSE f.PROXIMA_TENTATIVA END,
               f.ULTIMO_ERRO       = CASE @Acao WHEN 'REENVIAR' THEN N'' ELSE f.ULTIMO_ERRO END,
               f.DT_ALTERACAO      = @Agora,
               f.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        INSERT INTO SIS.Email_Log (ID_EMAIL, TENTATIVA, RESULTADO, MENSAGEM, USUARIO)
        VALUES (@IdEmail, @Tentativas, CASE @Acao WHEN 'REENVIAR' THEN 'REENVIO' ELSE 'CANCELADO' END,
                CASE @Acao WHEN 'REENVIAR' THEN N'Reenvio pedido pela tela.' ELSE LEFT(N'Cancelado: ' + @Motivo, 1000) END, @Usuario);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE @Acao WHEN 'REENVIAR' THEN N'E-mail colocado de novo na fila.' ELSE N'E-mail cancelado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmail AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Grupo_Email_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Grupo_Email_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Grupos de e-mail": cada grupo com a quantidade e a lista
                de destinatários ativos (separados por "; ").
                Permissão: VER em SIS_GRUPO_EMAIL.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Grupo_Email_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Grupo_Email_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Grupo_Email_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_GRUPO_EMAIL', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os grupos de e-mail.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT g.ID_GRUPO_EMAIL, g.CODIGO, g.NOME, g.DESCRICAO, g.ATIVO,
               (SELECT COUNT(*) FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.ATIVO = 1) AS QTD_DESTINATARIOS,
               ISNULL((SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), d.EMAIL), N'; ') WITHIN GROUP (ORDER BY d.EMAIL)
                       FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.ATIVO = 1), N'') AS DESTINATARIOS,
               g.DT_ALTERACAO, g.USUARIO_ALTERACAO
        FROM SIS.Grupo_Email g
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR g.ATIVO = 1)
        ORDER BY g.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os grupos de e-mail. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Grupo_Email_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Grupo_Email_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdGrupoEmail NULL) ou altera um grupo de e-mail e a
                lista de destinatários dele.
                @Destinatarios: todos os endereços do grupo, separados por
                ";", "," ou quebra de linha. A lista gravada fica igual à
                informada: endereço novo entra, endereço que saiu é
                excluído (fica na auditoria), endereço desativado volta.
                Recusa com a lista dos endereços inválidos (nada é gravado).
                Código: letras maiúsculas, números e "_" (ex.: FIN_PAGAR);
                não muda depois de criado (as rotinas usam o código).
                Permissão: INCLUIR ou ALTERAR em SIS_GRUPO_EMAIL.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Grupo_Email_Gravar @IdUsuario = 2, @IdGrupoEmail = NULL, @Codigo = 'FIN_PAGAR',
    --      @Nome = N'Contas a pagar', @Destinatarios = N'financeiro@cmj.com.br';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Grupo_Email_Gravar]
    @IdUsuario      INT,
    @IdGrupoEmail   INT           = NULL,
    @Codigo         VARCHAR(30),
    @Nome           NVARCHAR(80),
    @Descricao      NVARCHAR(400) = NULL,
    @Ativo          BIT           = 1,
    @Destinatarios  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Grupo_Email_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Invalidos  NVARCHAR(MAX);
    DECLARE @CodigoAtual VARCHAR(30);
    DECLARE @Lista      TABLE (EMAIL NVARCHAR(256) PRIMARY KEY);

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Nome      = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Ativo     = ISNULL(@Ativo, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_GRUPO_EMAIL', CASE WHEN @IdGrupoEmail IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar grupos de e-mail.';

        IF @Recusa = N'' AND @IdGrupoEmail IS NOT NULL
        BEGIN
            SELECT @CodigoAtual = g.CODIGO FROM SIS.Grupo_Email g WHERE g.ID_GRUPO_EMAIL = @IdGrupoEmail;
            IF @CodigoAtual IS NULL SET @Recusa = N'Grupo não encontrado.';
            ELSE IF @Codigo <> @CodigoAtual SET @Recusa = N'O código do grupo não pode ser mudado (as rotinas usam o código).';
        END;

        IF @Recusa = N'' AND (@Codigo = '' OR LEN(@Codigo) > 30 OR REPLACE(@Codigo, '_', '') LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras maiúsculas sem acento, números e "_" (ex.: FIN_PAGAR).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome do grupo.';
        IF @Recusa = N'' AND @IdGrupoEmail IS NULL AND EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = @Codigo)
            SET @Recusa = N'Já existe um grupo com este código.';

        IF @Recusa = N''
        BEGIN
            INSERT INTO @Lista (EMAIL)
            SELECT DISTINCT LOWER(LTRIM(RTRIM(s.value)))
            FROM STRING_SPLIT(REPLACE(REPLACE(REPLACE(ISNULL(@Destinatarios, N''), NCHAR(13), N';'), NCHAR(10), N';'), N',', N';'), N';') s
            WHERE LTRIM(RTRIM(s.value)) <> N'';

            SELECT @Invalidos = STRING_AGG(CONVERT(NVARCHAR(MAX), l.EMAIL), N'; ')
            FROM @Lista l
            WHERE SIS.fn_SIS_Email_Valido(l.EMAIL) = 0;

            IF ISNULL(@Invalidos, N'') <> N''
                SET @Recusa = LEFT(N'Endereço(s) inválido(s): ' + @Invalidos, 400);
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdGrupoEmail AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdGrupoEmail IS NULL
        BEGIN
            INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Nome, @Descricao, @Ativo, @Usuario);
            SET @IdGrupoEmail = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE g
               SET g.NOME = @Nome, g.DESCRICAO = @Descricao, g.ATIVO = @Ativo,
                   g.DT_ALTERACAO = @Agora, g.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Grupo_Email g
            WHERE g.ID_GRUPO_EMAIL = @IdGrupoEmail
              AND (g.NOME <> @Nome COLLATE Latin1_General_BIN2 OR g.DESCRICAO <> @Descricao COLLATE Latin1_General_BIN2 OR g.ATIVO <> @Ativo);

        DELETE d
        FROM SIS.Grupo_Email_Destinatario d
        WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail
          AND NOT EXISTS (SELECT 1 FROM @Lista l WHERE l.EMAIL = d.EMAIL);

        UPDATE d
           SET d.ATIVO = 1, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Grupo_Email_Destinatario d
        WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail
          AND d.ATIVO = 0;

        INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, USUARIO_CRIACAO)
        SELECT @IdGrupoEmail, l.EMAIL, @Usuario
        FROM @Lista l
        WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail AND d.EMAIL = l.EMAIL);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Grupo gravado com ' + CAST((SELECT COUNT(*) FROM @Lista) AS NVARCHAR(10)) + N' destinatário(s).' AS NVARCHAR(400)) AS MENSAGEM,
               @IdGrupoEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o grupo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdGrupoEmail AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Processar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Agendador das rotinas automáticas (substitui o SQL Agent, que
                o Express não tem). O serviço do sistema chama a cada minuto.
                1) Rotina presa além do TEMPO_LIMITE_MINUTOS (o serviço caiu
                   no meio): fecha a execução como ERRO e reagenda.
                2) Roda, uma de cada vez e até @Maximo, as rotinas vencidas:
                   ativas (ou pedidas em "executar agora"), não em execução,
                   com o módulo na licença e habilitado. A captura usa
                   UPDLOCK + READPAST: duas chamadas nunca rodam a mesma.
                3) Cada rotina roda com o contexto do usuário interno
                   "sistema" (a auditoria mostra "sistema" e a origem
                   "rotina:<CODIGO>"), por EXEC da procedure cadastrada em
                   SIS.Rotina (precisa existir e não ter parâmetros).
                4) Grava o resultado em SIS.Rotina_Execucao e em SIS.Rotina e
                   calcula a próxima execução (fn_SIS_Rotina_Proxima). Erro
                   da rotina vai também para SIS.Log_Erro e não impede as
                   outras de rodar.
                Devolve 1 linha: QTD_EXECUTADAS, QTD_ERRO, QTD_LIBERADAS
                (@Silencioso = 1: não devolve nada).
                Não roda dentro de transação aberta (nem via INSERT-EXEC):
                cada rotina precisa controlar a própria transação.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Processar @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Processar]
    @Servidor  NVARCHAR(128),
    @Maximo      INT = 10,
    @Silencioso  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Rotina_Processar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Rotinas presas';
    DECLARE @IdSistema   INT           = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema');
    DECLARE @Feitas      INT           = 0;
    DECLARE @Erros       INT           = 0;
    DECLARE @Liberadas   INT           = 0;
    DECLARE @IdRotina    INT;
    DECLARE @Codigo      VARCHAR(40);
    DECLARE @Proc        NVARCHAR(256);
    DECLARE @Solicitante NVARCHAR(100);
    DECLARE @IdExecucao  BIGINT;
    DECLARE @Inicio      DATETIME2(0);
    DECLARE @ObjId       INT;
    DECLARE @Sql         NVARCHAR(600);
    DECLARE @Resultado   VARCHAR(10);
    DECLARE @Msg         NVARCHAR(1000);
    DECLARE @OrigemCtx   NVARCHAR(256);
    DECLARE @Presas      TABLE (ID_ROTINA INT PRIMARY KEY);

    IF @@TRANCOUNT > 0
        THROW 50001, N'O agendador de rotinas não pode rodar dentro de uma transação.', 1;

    BEGIN TRY
        SET @Servidor = LEFT(ISNULL(@Servidor, N''), 128);
        SET @Maximo   = CASE WHEN ISNULL(@Maximo, 0) < 1 THEN 10 WHEN @Maximo > 100 THEN 100 ELSE @Maximo END;

        -- 1) Presas além do tempo limite
        BEGIN TRANSACTION;

        UPDATE r
           SET r.EM_EXECUCAO      = 0,
               r.ULTIMO_RESULTADO = 'ERRO',
               r.ULTIMA_MENSAGEM  = N'Passou do tempo limite de ' + CAST(r.TEMPO_LIMITE_MINUTOS AS NVARCHAR(10)) + N' min sem terminar (o serviço pode ter parado).',
               r.SOLICITADA_POR   = N'',
               r.PROXIMA_EXECUCAO = CASE WHEN r.ATIVA = 1 THEN SIS.fn_SIS_Rotina_Proxima(r.FREQUENCIA, r.INTERVALO_MINUTOS, r.HORARIO, r.DIAS_SEMANA, r.DIA_MES, SYSDATETIME()) END
        OUTPUT inserted.ID_ROTINA INTO @Presas (ID_ROTINA)
        FROM SIS.Rotina r WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE r.EM_EXECUCAO = 1
          AND r.DT_INICIO_EXECUCAO < DATEADD(MINUTE, -r.TEMPO_LIMITE_MINUTOS, SYSDATETIME());

        UPDATE e
           SET e.RESULTADO = 'ERRO', e.DT_FIM = SYSDATETIME(), e.MENSAGEM = N'Passou do tempo limite sem terminar.'
        FROM SIS.Rotina_Execucao e
        INNER JOIN @Presas p ON p.ID_ROTINA = e.ID_ROTINA
        WHERE e.RESULTADO = 'EXECUTANDO';

        SET @Liberadas = (SELECT COUNT(*) FROM @Presas);
        COMMIT TRANSACTION;

        -- 2) Vencidas, uma de cada vez
        WHILE @Feitas < @Maximo
        BEGIN
            SET @EtapaAtual = 'Captura';
            SET @IdRotina = NULL;

            BEGIN TRANSACTION;

            SELECT TOP (1) @IdRotina = r.ID_ROTINA, @Codigo = r.CODIGO, @Proc = r.PROCEDIMENTO, @Solicitante = r.SOLICITADA_POR
            FROM SIS.Rotina r WITH (UPDLOCK, READPAST, ROWLOCK)
            INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
            WHERE r.EM_EXECUCAO = 0
              AND r.PROXIMA_EXECUCAO <= SYSDATETIME()
              AND (r.ATIVA = 1 OR r.SOLICITADA_POR <> N'')
              AND m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1
            ORDER BY r.PROXIMA_EXECUCAO, r.ID_ROTINA;

            IF @IdRotina IS NULL
            BEGIN
                COMMIT TRANSACTION;
                BREAK;
            END;

            SET @Inicio = SYSDATETIME();
            UPDATE SIS.Rotina SET EM_EXECUCAO = 1, DT_INICIO_EXECUCAO = @Inicio WHERE ID_ROTINA = @IdRotina;

            INSERT INTO SIS.Rotina_Execucao (ID_ROTINA, ORIGEM, SOLICITANTE, SERVIDOR, DT_INICIO)
            VALUES (@IdRotina, CASE WHEN @Solicitante <> N'' THEN 'MANUAL' ELSE 'AGENDA' END, @Solicitante, @Servidor, @Inicio);
            SET @IdExecucao = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            -- 3) Execução
            SET @EtapaAtual = LEFT('Rotina ' + @Codigo, 100);
            SET @Resultado  = 'OK';
            SET @Msg        = N'';

            BEGIN TRY
                SET @OrigemCtx = N'rotina:' + @Codigo;
                EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Estacao = @Servidor, @Origem = @OrigemCtx;

                SET @ObjId = OBJECT_ID(@Proc, N'P');
                IF @ObjId IS NULL
                    THROW 50001, N'A procedure cadastrada para a rotina não existe.', 1;
                IF EXISTS (SELECT 1 FROM sys.parameters p WHERE p.object_id = @ObjId)
                    THROW 50001, N'A procedure da rotina não pode ter parâmetros.', 1;

                SET @Sql = N'EXEC ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N';';
                EXEC sys.sp_executesql @Sql;

                IF @@TRANCOUNT > 0
                BEGIN
                    ROLLBACK TRANSACTION;
                    THROW 50001, N'A rotina terminou com uma transação aberta (desfeita).', 1;
                END;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

                SET @Resultado = 'ERRO';
                SET @Msg       = LEFT(ERROR_MESSAGE(), 1000);

                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
            END CATCH;

            EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

            -- 4) Resultado e próxima execução
            SET @EtapaAtual = 'Resultado';
            UPDATE r
               SET r.EM_EXECUCAO      = 0,
                   r.ULTIMA_EXECUCAO  = @Inicio,
                   r.ULTIMO_RESULTADO = @Resultado,
                   r.ULTIMA_MENSAGEM  = @Msg,
                   r.SOLICITADA_POR   = N'',
                   r.PROXIMA_EXECUCAO = CASE WHEN r.ATIVA = 1 THEN SIS.fn_SIS_Rotina_Proxima(r.FREQUENCIA, r.INTERVALO_MINUTOS, r.HORARIO, r.DIAS_SEMANA, r.DIA_MES, SYSDATETIME()) END
            FROM SIS.Rotina r
            WHERE r.ID_ROTINA = @IdRotina;

            UPDATE SIS.Rotina_Execucao
               SET DT_FIM = SYSDATETIME(), RESULTADO = @Resultado, MENSAGEM = @Msg
            WHERE ID_EXECUCAO = @IdExecucao;

            SET @Feitas = @Feitas + 1;
            IF @Resultado = 'ERRO' SET @Erros = @Erros + 1;
        END;

        IF ISNULL(@Silencioso, 0) = 0
            SELECT @Feitas AS QTD_EXECUTADAS, @Erros AS QTD_ERRO, @Liberadas AS QTD_LIBERADAS;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Rotinas automáticas" (exclusiva do administrador
                geral): cada rotina com a agenda em texto ("A cada 10 min",
                "Diária às 03:10", "Semanal (seg, qua) às 08:00", "Mensal
                no dia 5 às 07:00"), situação, última e próxima execução.
                MODULO_DISPONIVEL = 0: o módulo da rotina está fora da
                licença ou desabilitado (a rotina não roda).
                Permissão: VER em SIS_ROTINA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as rotinas automáticas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT r.ID_ROTINA, r.CODIGO, r.NOME, r.DESCRICAO, m.CODIGO AS MODULO_CODIGO,
               CAST(CASE WHEN m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END AS BIT) AS MODULO_DISPONIVEL,
               r.FREQUENCIA, r.INTERVALO_MINUTOS, CONVERT(VARCHAR(5), r.HORARIO, 108) AS HORARIO, r.DIAS_SEMANA, r.DIA_MES,
               CAST(CASE r.FREQUENCIA
                        WHEN 'MINUTOS' THEN N'A cada ' + CAST(r.INTERVALO_MINUTOS AS NVARCHAR(10)) + N' min'
                        WHEN 'DIARIA'  THEN N'Diária às ' + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                        WHEN 'SEMANAL' THEN N'Semanal (' + ISNULL((SELECT STRING_AGG(CHOOSE(TRY_CAST(s.value AS INT), N'dom', N'seg', N'ter', N'qua', N'qui', N'sex', N'sáb'), N', ')
                                                                          WITHIN GROUP (ORDER BY TRY_CAST(s.value AS INT))
                                                                   FROM STRING_SPLIT(r.DIAS_SEMANA, ',') s WHERE s.value <> ''), N'') + N') às ' + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                        ELSE CASE WHEN r.DIA_MES = 31 THEN N'Mensal no último dia às ' ELSE N'Mensal no dia ' + CAST(r.DIA_MES AS NVARCHAR(3)) + N' às ' END + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                    END AS NVARCHAR(200)) AS AGENDA_TEXTO,
               r.TEMPO_LIMITE_MINUTOS, r.ATIVA, r.EM_EXECUCAO, r.PROXIMA_EXECUCAO, r.SOLICITADA_POR,
               r.ULTIMA_EXECUCAO, r.ULTIMO_RESULTADO, r.ULTIMA_MENSAGEM, r.PROCEDIMENTO
        FROM SIS.Rotina r
        INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
        ORDER BY m.ORDEM_MENU, r.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as rotinas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Rotinas automáticas": muda a agenda de uma rotina e
                liga/desliga. A rotina em si (qual procedure roda) só muda
                por carga: pela tela não se cadastra rotina nova.
                @Frequencia MINUTOS usa @IntervaloMinutos (1 a 1440);
                DIARIA usa @Horario ('HH:MM'); SEMANAL usa @DiasSemana
                ('2,4', 1 = domingo) e @Horario; MENSAL usa @DiaMes (1 a 31;
                31 = último dia) e @Horario. Os campos que a frequência não
                usa são zerados.
                Recalcula a próxima execução (desligada = sem próxima).
                Permissão: ALTERAR em SIS_ROTINA (tela exclusiva do
                administrador geral). Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Gravar @IdUsuario = 2, @Codigo = 'LOG_LIMPEZA', @Ativa = 1, @Frequencia = 'DIARIA', @Horario = '03:10';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Gravar]
    @IdUsuario           INT,
    @Codigo              VARCHAR(40),
    @Ativa               BIT,
    @Frequencia          VARCHAR(10),
    @IntervaloMinutos    INT         = NULL,
    @Horario             VARCHAR(5)  = NULL,
    @DiasSemana          VARCHAR(20) = NULL,
    @DiaMes              TINYINT     = NULL,
    @TempoLimiteMinutos  INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @IdRotina   INT;
    DECLARE @Hora       TIME(0);
    DECLARE @Dias       VARCHAR(20)   = '';
    DECLARE @Proxima    DATETIME2(0);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para alterar as rotinas automáticas.';

        SET @Codigo     = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Frequencia = UPPER(LTRIM(RTRIM(ISNULL(@Frequencia, ''))));
        SET @Ativa      = ISNULL(@Ativa, 0);

        IF @Recusa = N''
        BEGIN
            SELECT @IdRotina = r.ID_ROTINA, @TempoLimiteMinutos = ISNULL(@TempoLimiteMinutos, r.TEMPO_LIMITE_MINUTOS)
            FROM SIS.Rotina r WHERE r.CODIGO = @Codigo;
            IF @IdRotina IS NULL SET @Recusa = N'Rotina não encontrada.';
        END;

        IF @Recusa = N'' AND @Frequencia NOT IN ('MINUTOS', 'DIARIA', 'SEMANAL', 'MENSAL')
            SET @Recusa = N'Escolha a frequência: a cada X minutos, diária, semanal ou mensal.';

        IF @Recusa = N'' AND @Frequencia = 'MINUTOS' AND ISNULL(@IntervaloMinutos, 0) NOT BETWEEN 1 AND 1440
            SET @Recusa = N'Informe o intervalo em minutos (de 1 a 1440).';

        IF @Recusa = N'' AND @Frequencia <> 'MINUTOS'
        BEGIN
            SET @Hora = TRY_CONVERT(TIME(0), LTRIM(RTRIM(ISNULL(@Horario, ''))));
            IF @Hora IS NULL OR LEN(LTRIM(RTRIM(@Horario))) <> 5 SET @Recusa = N'Informe o horário no formato HH:MM (ex.: 03:10).';
        END;

        IF @Recusa = N'' AND @Frequencia = 'SEMANAL'
        BEGIN
            IF EXISTS (SELECT 1 FROM STRING_SPLIT(REPLACE(ISNULL(@DiasSemana, ''), ' ', ''), ',') s
                       WHERE s.value <> '' AND ISNULL(TRY_CAST(s.value AS INT), 0) NOT BETWEEN 1 AND 7)
                SET @Recusa = N'Dias da semana inválidos (1 = domingo ... 7 = sábado).';
            ELSE
                SELECT @Dias = ISNULL(STRING_AGG(CAST(d.N AS VARCHAR(1)), ',') WITHIN GROUP (ORDER BY d.N), '')
                FROM (SELECT DISTINCT TRY_CAST(s.value AS INT) AS N
                      FROM STRING_SPLIT(REPLACE(ISNULL(@DiasSemana, ''), ' ', ''), ',') s WHERE s.value <> '') d;
            IF @Recusa = N'' AND @Dias = '' SET @Recusa = N'Escolha ao menos um dia da semana.';
        END;

        IF @Recusa = N'' AND @Frequencia = 'MENSAL' AND ISNULL(@DiaMes, 0) NOT BETWEEN 1 AND 31
            SET @Recusa = N'Informe o dia do mês (1 a 31; 31 = último dia).';

        IF @Recusa = N'' AND ISNULL(@TempoLimiteMinutos, 0) NOT BETWEEN 1 AND 1440
            SET @Recusa = N'Tempo limite inválido (de 1 a 1440 minutos).';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
            RETURN;
        END;

        IF @Frequencia <> 'MINUTOS' SET @IntervaloMinutos = 0;
        IF @Frequencia = 'MINUTOS'  SET @Hora = '00:00';
        IF @Frequencia <> 'MENSAL'  SET @DiaMes = 0;

        SET @Proxima = CASE WHEN @Ativa = 1 THEN SIS.fn_SIS_Rotina_Proxima(@Frequencia, @IntervaloMinutos, @Hora, @Dias, @DiaMes, SYSDATETIME()) END;
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE r
           SET r.ATIVA                = @Ativa,
               r.FREQUENCIA           = @Frequencia,
               r.INTERVALO_MINUTOS    = @IntervaloMinutos,
               r.HORARIO              = @Hora,
               r.DIAS_SEMANA          = @Dias,
               r.DIA_MES              = @DiaMes,
               r.TEMPO_LIMITE_MINUTOS = @TempoLimiteMinutos,
               r.PROXIMA_EXECUCAO     = CASE WHEN r.EM_EXECUCAO = 1 THEN r.PROXIMA_EXECUCAO ELSE @Proxima END,
               r.DT_ALTERACAO         = SYSDATETIME(),
               r.USUARIO_ALTERACAO    = @Usuario
        FROM SIS.Rotina r
        WHERE r.ID_ROTINA = @IdRotina;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Ativa = 0 THEN N'Rotina desligada: não roda mais pela agenda.'
                         ELSE N'Agenda gravada. Próxima execução: ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@Proxima), N'-') + N'.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdRotina AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a rotina. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Executar_Agora.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Executar_Agora]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botão "Executar agora" da tela "Rotinas automáticas": marca a
                rotina para rodar na próxima volta do agendador (o serviço
                confere a cada minuto). Vale também para rotina desligada
                (roda uma vez). A execução fica registrada como MANUAL, com
                quem pediu.
                Recusa se já está em execução ou se o módulo da rotina está
                fora da licença ou desabilitado.
                Permissão: EXECUTAR em SIS_ROTINA. Devolve SUCESSO, MENSAGEM,
                ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (16/11/2026) - Etapa 03a: "executar agora" grava a próxima execução 1
                        segundo antes de agora. A coluna é DATETIME2(0) e
                        arredonda: 15:11:16,6 virava 15:11:17 e o processador
                        rodando no mesmo segundo não pegava a rotina (falha
                        intermitente do teste 02d nº 107/108).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Executar_Agora @IdUsuario = 2, @Codigo = 'EMAIL_PRESOS';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Executar_Agora]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Executar_Agora]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @IdRotina   INT;
    DECLARE @EmExecucao BIT;
    DECLARE @Disponivel BIT;

    BEGIN TRY
        SET @Codigo = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'EXECUTAR') = 0
            SET @Recusa = N'Você não tem permissão para executar rotinas.';

        IF @Recusa = N''
        BEGIN
            SELECT @IdRotina = r.ID_ROTINA, @EmExecucao = r.EM_EXECUCAO,
                   @Disponivel = CASE WHEN m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END
            FROM SIS.Rotina r
            INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
            WHERE r.CODIGO = @Codigo;

            SET @Recusa = CASE WHEN @IdRotina IS NULL THEN N'Rotina não encontrada.'
                               WHEN @EmExecucao = 1 THEN N'A rotina já está em execução.'
                               WHEN @Disponivel = 0 THEN N'O módulo desta rotina está fora da licença ou desabilitado.'
                               ELSE N'' END;
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE r
           SET r.PROXIMA_EXECUCAO = DATEADD(SECOND, -1, SYSDATETIME()),   -- DATETIME2(0) arredonda: sem o -1 podia cair no segundo seguinte
               r.SOLICITADA_POR   = SIS.fn_SIS_Usuario_Login(@IdUsuario)
        FROM SIS.Rotina r
        WHERE r.ID_ROTINA = @IdRotina AND r.EM_EXECUCAO = 0;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Pedido registrado: a rotina roda em até 1 minuto.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdRotina AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível registrar o pedido. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Rotina_Execucao_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Execucao_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico das execuções das rotinas automáticas (todas ou de
                uma rotina), mais recente primeiro, com a duração em
                segundos.
                Permissão: VER em SIS_ROTINA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Execucao_Listar @IdUsuario = 2, @Codigo = 'LOG_LIMPEZA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Execucao_Listar]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40) = NULL,
    @MaxLinhas  INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Execucao_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as rotinas automáticas.', 1;

        SET @Codigo    = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Codigo, '')))), '');
        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 5000 THEN 500 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               e.ID_EXECUCAO, r.CODIGO, r.NOME, e.ORIGEM, e.SOLICITANTE, e.SERVIDOR, e.DT_INICIO, e.DT_FIM,
               DATEDIFF(SECOND, e.DT_INICIO, ISNULL(e.DT_FIM, SYSDATETIME())) AS DURACAO_SEGUNDOS,
               e.RESULTADO, e.MENSAGEM
        FROM SIS.Rotina_Execucao e WITH (NOLOCK)
        INNER JOIN SIS.Rotina r ON r.ID_ROTINA = e.ID_ROTINA
        WHERE (@Codigo IS NULL OR r.CODIGO = @Codigo)
        ORDER BY e.ID_EXECUCAO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o histórico das rotinas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "Instalação e manutenção" (exclusiva do
                administrador geral), por grupo e ordem, com o último pedido
                de cada comando (situação, quando e por quem).
                Permissão: VER em SIS_INSTALACAO.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para a tela de instalação e manutenção.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_COMANDO, c.CODIGO, c.NOME, c.DESCRICAO, c.GRUPO,
               CAST(CASE c.GRUPO WHEN 'INSTALACAO'  THEN N'Instalação'
                                 WHEN 'ATUALIZACAO' THEN N'Atualização'
                                 WHEN 'BACKUP'      THEN N'Backup'
                                 WHEN 'SERVICO'     THEN N'Serviço do sistema'
                                 ELSE N'Diagnóstico' END AS NVARCHAR(40)) AS GRUPO_NOME,
               c.ORDEM, c.PERIGOSO, c.ACEITA_PARAMETRO, c.PARAMETRO_DESCRICAO,
               u.ID_PEDIDO AS ULTIMO_PEDIDO, u.STATUS AS ULTIMO_STATUS, u.DT_PEDIDO AS ULTIMO_DT_PEDIDO,
               u.USUARIO_PEDIDO AS ULTIMO_USUARIO, u.DT_FIM AS ULTIMO_DT_FIM
        FROM SIS.Comando c
        OUTER APPLY (SELECT TOP (1) f.ID_PEDIDO, f.STATUS, f.DT_PEDIDO, f.USUARIO_PEDIDO, f.DT_FIM
                     FROM SIS.Comando_Fila f WHERE f.ID_COMANDO = c.ID_COMANDO ORDER BY f.ID_PEDIDO DESC) u
        WHERE c.ATIVO = 1
        ORDER BY CASE c.GRUPO WHEN 'INSTALACAO' THEN 1 WHEN 'ATUALIZACAO' THEN 2 WHEN 'BACKUP' THEN 3 WHEN 'SERVICO' THEN 4 ELSE 5 END,
                 c.ORDEM, c.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os comandos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Solicitar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Solicitar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botão de um comando na tela "Instalação e manutenção": grava o
                pedido em SIS.Comando_Fila para o serviço executar. Não
                executa nada no Windows.
                - Comando PERIGOSO: a API só chama esta procedure depois de
                  pedir a senha de novo e a confirmação.
                - @Parametro: só para comando que aceita (e aí é
                  obrigatório). Recusa caracteres que poderiam virar outro
                  comando (& | ; < > ` " ' % ^ e quebra de linha); o serviço
                  valida de novo.
                - Recusa se o mesmo comando já está pendente ou executando.
                Permissão: EXECUTAR em SIS_INSTALACAO (tela exclusiva do
                administrador geral). Devolve SUCESSO, MENSAGEM, ID
                (ID = número do pedido).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Solicitar @IdUsuario = 2, @Codigo = 'DISCO_ESPACO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Solicitar]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40),
    @Parametro  NVARCHAR(400) = NULL,
    @Estacao    NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Solicitar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @IdComando  INT;
    DECLARE @Aceita     BIT;
    DECLARE @IdPedido   BIGINT;

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Parametro = LTRIM(RTRIM(ISNULL(@Parametro, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'EXECUTAR') = 0
            SET @Recusa = N'Você não tem permissão para executar comandos de instalação e manutenção.';

        IF @Recusa = N''
        BEGIN
            SELECT @IdComando = c.ID_COMANDO, @Aceita = c.ACEITA_PARAMETRO
            FROM SIS.Comando c WHERE c.CODIGO = @Codigo AND c.ATIVO = 1;
            IF @IdComando IS NULL SET @Recusa = N'Comando não encontrado.';
        END;

        IF @Recusa = N'' AND @Aceita = 0 AND @Parametro <> N''
            SET @Recusa = N'Este comando não recebe valor.';
        IF @Recusa = N'' AND @Aceita = 1 AND @Parametro = N''
            SET @Recusa = N'Informe o valor pedido pelo comando.';
        IF @Recusa = N'' AND @Parametro <> N''
           AND (   @Parametro LIKE N'%[&|;<>`"''%^]%'
                OR CHARINDEX(NCHAR(13), @Parametro) > 0 OR CHARINDEX(NCHAR(10), @Parametro) > 0 OR CHARINDEX(N'..', @Parametro) > 0)
            SET @Recusa = N'O valor tem caracteres não permitidos.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM SIS.Comando_Fila f WITH (UPDLOCK, HOLDLOCK)
                   WHERE f.ID_COMANDO = @IdComando AND f.STATUS IN ('PENDENTE', 'EXECUTANDO'))
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Este comando já está na fila ou em execução.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        INSERT INTO SIS.Comando_Fila (ID_COMANDO, PARAMETRO, USUARIO_PEDIDO, ESTACAO_PEDIDO)
        VALUES (@IdComando, @Parametro, SIS.fn_SIS_Usuario_Login(@IdUsuario),
                LEFT(ISNULL(NULLIF(@Estacao, N''), ISNULL(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'ESTACAO')), N'')), 128));
        SET @IdPedido = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Pedido registrado. Acompanhe o resultado nesta tela.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível registrar o pedido. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Cancelar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Cancelar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Cancela um pedido de comando que ainda não começou
                (PENDENTE). Comando em execução não é interrompido por aqui.
                Permissão: CANCELAR em SIS_INSTALACAO. Devolve SUCESSO,
                MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Cancelar @IdUsuario = 2, @IdPedido = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Cancelar]
    @IdUsuario  INT,
    @IdPedido   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Cancelar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Linhas     INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'CANCELAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para cancelar comandos.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE f
           SET f.STATUS               = 'CANCELADO',
               f.DT_CANCELAMENTO      = SYSDATETIME(),
               f.USUARIO_CANCELAMENTO = SIS.fn_SIS_Usuario_Login(@IdUsuario)
        FROM SIS.Comando_Fila f
        WHERE f.ID_PEDIDO = @IdPedido AND f.STATUS = 'PENDENTE';
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Pedido cancelado.' ELSE N'Só pedido pendente (que ainda não começou) pode ser cancelado.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível cancelar. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Fila_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Fila_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico dos pedidos de comandos (tela "Instalação e
                manutenção"), mais recente primeiro. @IdPedido informado:
                só aquele pedido, com a saída completa (para a janela de
                detalhe); sem ele, a saída vem cortada em 500 caracteres.
                Permissão: VER em SIS_INSTALACAO.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Fila_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Fila_Listar]
    @IdUsuario  INT,
    @IdPedido   BIGINT = NULL,
    @MaxLinhas  INT    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Fila_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para a tela de instalação e manutenção.', 1;

        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 2000 THEN 200 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               f.ID_PEDIDO, c.CODIGO, c.NOME, f.PARAMETRO, f.STATUS, f.DT_PEDIDO, f.USUARIO_PEDIDO, f.ESTACAO_PEDIDO,
               f.DT_INICIO, f.DT_FIM, f.SERVIDOR, f.CODIGO_SAIDA,
               CASE WHEN @IdPedido IS NULL AND LEN(f.SAIDA) > 500 THEN LEFT(f.SAIDA, 500) + N' (...)' ELSE f.SAIDA END AS SAIDA,
               f.DT_CANCELAMENTO, f.USUARIO_CANCELAMENTO
        FROM SIS.Comando_Fila f WITH (NOLOCK)
        INNER JOIN SIS.Comando c ON c.ID_COMANDO = f.ID_COMANDO
        WHERE (@IdPedido IS NULL OR f.ID_PEDIDO = @IdPedido)
        ORDER BY f.ID_PEDIDO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os pedidos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Capturar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Capturar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço do sistema. Pega o pedido de comando
                PENDENTE mais antigo e marca EXECUTANDO; um comando de cada
                vez (se já existe um executando, não devolve nada).
                Devolve 0 ou 1 linha: ID_PEDIDO, CODIGO, PARAMETRO. O
                serviço executa o que estiver na SUA lista fixa para o
                CODIGO e chama SIS_Comando_Resultado_Gravar.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Capturar @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Capturar]
    @Servidor  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Capturar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Captura';
    DECLARE @IdPedido   BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM SIS.Comando_Fila f WITH (UPDLOCK, HOLDLOCK) WHERE f.STATUS = 'EXECUTANDO')
        BEGIN
            SELECT TOP (1) @IdPedido = f.ID_PEDIDO
            FROM SIS.Comando_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE f.STATUS = 'PENDENTE'
            ORDER BY f.ID_PEDIDO;

            IF @IdPedido IS NOT NULL
                UPDATE SIS.Comando_Fila
                   SET STATUS = 'EXECUTANDO', DT_INICIO = SYSDATETIME(), SERVIDOR = LEFT(ISNULL(@Servidor, N''), 128)
                WHERE ID_PEDIDO = @IdPedido;
        END;

        COMMIT TRANSACTION;

        SELECT f.ID_PEDIDO, c.CODIGO, f.PARAMETRO
        FROM SIS.Comando_Fila f
        INNER JOIN SIS.Comando c ON c.ID_COMANDO = f.ID_COMANDO
        WHERE f.ID_PEDIDO = @IdPedido;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comando_Resultado_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Resultado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço, ao terminar um comando capturado:
                grava CONCLUIDO (@Sucesso = 1) ou ERRO, o código de saída e a
                saída do comando (o serviço tira senhas e chaves antes de
                mandar). Só aceita pedido em EXECUTANDO.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Resultado_Gravar @IdPedido = 1, @Sucesso = 1, @CodigoSaida = 0, @Saida = N'ok';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Resultado_Gravar]
    @IdPedido     BIGINT,
    @Sucesso      BIT,
    @CodigoSaida  INT           = NULL,
    @Saida        NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Resultado_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Gravação';
    DECLARE @Linhas     INT;

    BEGIN TRY
        UPDATE f
           SET f.STATUS       = CASE WHEN ISNULL(@Sucesso, 0) = 1 THEN 'CONCLUIDO' ELSE 'ERRO' END,
               f.DT_FIM       = SYSDATETIME(),
               f.CODIGO_SAIDA = @CodigoSaida,
               f.SAIDA        = ISNULL(@Saida, N'')
        FROM SIS.Comando_Fila f
        WHERE f.ID_PEDIDO = @IdPedido AND f.STATUS = 'EXECUTANDO';
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Resultado gravado.' ELSE N'O pedido não está em execução.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o resultado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Banco_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Banco_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Lista de bancos (tela Bancos e escolha do banco nas contas e nos
                dados bancários das pessoas). Permissão: VER em BANCO_BANCO,
                BANCO_CONTA ou CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Banco_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Banco_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Banco_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_BANCO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a lista de bancos.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT b.ID_BANCO, b.CODIGO, b.ISPB, b.NOME, b.ATIVO, b.DT_ALTERACAO, ISNULL(b.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM BANCO.Banco b WITH (NOLOCK)
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR b.ATIVO = 1)
        ORDER BY b.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a lista de bancos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Banco_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Banco_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdBanco NULL) ou altera um banco da lista. Código COMPE com
                3 dígitos (único); ISPB com 8 dígitos ou vazio.
                Permissão: INCLUIR ou ALTERAR em BANCO_BANCO. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (16/11/2026) - @Codigo e @Ispb maiores que a coluna: o ISPB digitado
                        com pontos (12.345.678) era cortado em 8 caracteres
                        antes de limpar e virava inválido (achado na homologação).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Banco_Gravar @IdUsuario = 2, @Codigo = '748', @Ispb = '01181521', @Nome = N'Sicredi';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Banco_Gravar]
    @IdUsuario  INT,
    @IdBanco    INT          = NULL,
    @Codigo     VARCHAR(10),
    @Ispb       VARCHAR(20)  = NULL,
    @Nome       NVARCHAR(80),
    @Ativo      BIT          = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Banco_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Codigo = LTRIM(RTRIM(ISNULL(@Codigo, '')));
        SET @Ispb   = CAD.fn_CAD_Somente_Digitos(@Ispb);
        SET @Nome   = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Ativo  = ISNULL(@Ativo, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_BANCO', CASE WHEN @IdBanco IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar bancos.';
        IF @Recusa = N'' AND @IdBanco IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.ID_BANCO = @IdBanco)
            SET @Recusa = N'Banco não encontrado.';
        IF @Recusa = N'' AND (LEN(@Codigo) <> 3 OR @Codigo LIKE '%[^0-9]%')
            SET @Recusa = N'Código do banco inválido: informe os 3 dígitos (ex.: 748).';
        IF @Recusa = N'' AND @Ispb <> '' AND LEN(@Ispb) <> 8
            SET @Recusa = N'ISPB inválido: são 8 dígitos (ou deixe em branco).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome do banco.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.CODIGO = @Codigo AND b.ID_BANCO <> ISNULL(@IdBanco, 0))
            SET @Recusa = N'Já existe um banco com este código.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdBanco IS NULL
        BEGIN
            INSERT INTO BANCO.Banco (CODIGO, ISPB, NOME, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Ispb, @Nome, @Ativo, @Usuario);
            SET @IdBanco = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE b
               SET b.CODIGO = @Codigo, b.ISPB = @Ispb, b.NOME = @Nome, b.ATIVO = @Ativo,
                   b.DT_ALTERACAO = SYSDATETIME(), b.USUARIO_ALTERACAO = @Usuario
            FROM BANCO.Banco b
            WHERE b.ID_BANCO = @IdBanco;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Banco gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o banco. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Listar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Gravar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/BANCO.BANCO_Conta_Excluir.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma conta. Nada é apagado.
                Não desativa a conta que é padrão de empresa ou centro de custo ativo
                (troque a conta padrão antes). Permissão: EXCLUIR em BANCO_CONTA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

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

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar contas bancárias.';

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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Listar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Gravar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Excluir.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma empresa. Nada é apagado.
                Não desativa empresa com conta ou centro de custo ativo (desative-os
                antes). Permissão: EXCLUIR em CAD_EMPRESA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

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

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar empresas.';

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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Listar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Gravar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Centro_Custo_Excluir.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) um centro de custo. Nada é
                apagado. Reativar exige a empresa ativa.
                Permissão: EXCLUIR em CAD_CENTRO_CUSTO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

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

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar centros de custo.';

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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Listar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Obter.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Gravar.sql
-- -----------------------------------------------------------------------------
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
               OR NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = v.ID_VINCULADA)
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Pessoa_Excluir.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[CAD_Pessoa_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) uma pessoa. Nada é apagado: a
                pessoa some das listas de escolha, mas continua nos lançamentos e no
                histórico. Permissão: EXCLUIR em CAD_PESSOA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

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

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar pessoas.';

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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Conta_Listar.sql
-- -----------------------------------------------------------------------------
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
            UNION ALL
            SELECT CAST(2 AS TINYINT), s.ID_PLANO_SUBGRUPO, s.ID_PLANO_GRUPO, s.NUMERO,
                   CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + CONVERT(VARCHAR(3), s.NUMERO)),
                   s.DESCRICAO, g.TIPO, g.CUSTO_OBRA, CAST(0 AS BIT), CONVERT(VARCHAR(30), ''),
                   s.ORDEM, s.ATIVO, CAST(CASE WHEN s.ATIVO = 1 AND g.ATIVO = 1 THEN 1 ELSE 0 END AS BIT),
                   CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + RIGHT('00' + CONVERT(VARCHAR(3), s.NUMERO), 2) + '.000'),
                   s.DT_ALTERACAO, ISNULL(s.USUARIO_ALTERACAO, N'')
            FROM CAD.Plano_Subgrupo s WITH (NOLOCK)
            INNER JOIN CAD.Plano_Grupo g WITH (NOLOCK) ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO
            UNION ALL
            SELECT CAST(3 AS TINYINT), v.ID_PLANO_CONTA, v.ID_PLANO_SUBGRUPO, v.NUMERO_CONTA, v.CODIGO,
                   v.DESCRICAO, v.TIPO, v.CUSTO_OBRA, v.CONTABIL, v.CONTA_CONTABIL_REF,
                   CAST(0 AS SMALLINT), v.CONTA_ATIVA, v.ATIVO_EFETIVO, v.ORDEM_ARVORE,
                   c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'')
            FROM CAD.vw_CAD_Plano_Conta v WITH (NOLOCK)
            INNER JOIN CAD.Plano_Conta c WITH (NOLOCK) ON c.ID_PLANO_CONTA = v.ID_PLANO_CONTA
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Grupo_Gravar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Subgrupo_Gravar.sql
-- -----------------------------------------------------------------------------
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
        IF @Recusa = N'' AND @IdPlanoSubgrupo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo x WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @IdPlanoGrupo)
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Conta_Gravar.sql
-- -----------------------------------------------------------------------------
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
        IF @Recusa = N'' AND @IdPlanoConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Conta x WHERE x.ID_PLANO_CONTA = @IdPlanoConta)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo)
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/CAD.CAD_Plano_Excluir.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) um grupo (@Nivel 1), subgrupo (2)
                ou conta (3) do plano. Nada é apagado: desativar o grupo ou o subgrupo
                esconde tudo abaixo dele das listas de escolha (ATIVO_EFETIVO), sem
                mexer nos filhos. Permissão: EXCLUIR em CAD_PLANO_CONTA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

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

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar o plano de contas.';
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.FIN_Arquivo_Morto_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[FIN_Arquivo_Morto_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Consulta do arquivo morto (só leitura): período, conta, busca por
                parte do texto (pessoa, obra, empresa, complemento, documento, nota
                ou plano) e valor exato. Permissão: VER em FIN_ARQUIVO_MORTO.
                Devolve até @Limite linhas, mais recentes primeiro.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Arquivo_Morto_Listar @IdUsuario = 2, @Busca = N'pintor', @DtInicio = '2010-01-01', @DtFim = '2010-12-31';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Arquivo_Morto_Listar]
    @IdUsuario  INT,
    @Busca      NVARCHAR(100) = NULL,
    @DtInicio   DATE          = NULL,
    @DtFim      DATE          = NULL,
    @Conta      NVARCHAR(80)  = NULL,
    @Limite     INT           = 1000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Arquivo_Morto_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Like       NVARCHAR(110);
    DECLARE @Valor      DECIMAL(18,2);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_ARQUIVO_MORTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para consultar o arquivo morto.', 1;

        SET @Busca  = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Conta  = LTRIM(RTRIM(ISNULL(@Conta, N'')));
        SET @Limite = CASE WHEN ISNULL(@Limite, 0) BETWEEN 1 AND 20000 THEN @Limite ELSE 1000 END;
        SET @Like   = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Valor  = TRY_CONVERT(DECIMAL(18,2), REPLACE(REPLACE(@Busca, N'.', N''), N',', N'.'));

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@Limite)
               a.ID_ARQUIVO_MORTO, a.DT_MOVIMENTO, a.DT_VENCIMENTO, a.DT_PAGAMENTO,
               a.EMPRESA, a.OBRA, a.PESSOA, a.CONTA, a.PLANO1, a.PLANO2, a.PLANO3,
               a.HISTORICO, a.COMPLEMENTO, a.DOCUMENTO, a.NOTA_FISCAL, a.IMOVEL,
               a.VALOR_DEBITO, a.VALOR_CREDITO, a.CONFIRMADO, a.ORIGEM_ACCESS, a.CODIGO_ACCESS
        FROM FIN.Arquivo_Morto a WITH (NOLOCK)
        WHERE (@DtInicio IS NULL OR a.DT_MOVIMENTO >= @DtInicio)
          AND (@DtFim    IS NULL OR a.DT_MOVIMENTO <= @DtFim)
          AND (@Conta = N'' OR a.CONTA = @Conta)
          AND (   @Busca = N''
               OR a.PESSOA LIKE @Like OR a.OBRA LIKE @Like OR a.EMPRESA LIKE @Like
               OR a.COMPLEMENTO LIKE @Like OR a.DOCUMENTO LIKE @Like OR a.NOTA_FISCAL LIKE @Like
               OR a.PLANO3 LIKE @Like OR a.HISTORICO LIKE @Like
               OR (@Valor IS NOT NULL AND (a.VALOR_DEBITO = @Valor OR a.VALOR_CREDITO = @Valor)))
        ORDER BY a.DT_MOVIMENTO DESC, a.ID_ARQUIVO_MORTO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível consultar o arquivo morto. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Previa_Gerar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Previa_Gerar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Monta a edição da semana (segunda a sexta da data de hoje) com os
                itens ativos e manda a PRÉVIA só para o grupo de aprovação. Prévias
                anteriores ainda pendentes viram DESCARTADA (não acumulam). Semana
                que já teve envio oficial: recusa. Chamada pela rotina (@IdUsuario
                NULL, sem conferir permissão) ou pelo botão "Gerar prévia agora"
                (permissão ENVIAR em SIS_COMUNICADO). Devolve SUCESSO, MENSAGEM, ID
                (ID = ID_COMUNICADO_EDICAO).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
    v1.1 (17/11/2026) - Nome do sistema no aviso da prévia pelo parâmetro SISTEMA_NOME.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = 2, @IdComunicado = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Previa_Gerar]
    @IdUsuario     INT = NULL,
    @IdComunicado  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Previa_Gerar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Hoje       DATE          = CAST(SYSDATETIME() AS DATE);
    DECLARE @Inicio     DATE;
    DECLARE @Fim        DATE;
    DECLARE @Titulo     NVARCHAR(150);
    DECLARE @GrupoAprov VARCHAR(30);
    DECLARE @Para       NVARCHAR(MAX);
    DECLARE @Assunto    NVARCHAR(400);
    DECLARE @AssuntoPv  NVARCHAR(400);
    DECLARE @Conteudo   NVARCHAR(MAX);
    DECLARE @Corpo      NVARCHAR(MAX);
    DECLARE @CorpoPv    NVARCHAR(MAX);
    DECLARE @Aviso      NVARCHAR(MAX);
    DECLARE @IdEdicao   BIGINT;
    DECLARE @IdEmail    BIGINT;
    DECLARE @Chave      NVARCHAR(200);
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        -- segunda-feira da semana, sem depender de SET DATEFIRST (01/01/1900 foi segunda)
        SET @Inicio = DATEADD(DAY, -(DATEDIFF(DAY, '19000101', @Hoje) % 7), @Hoje);
        SET @Fim    = DATEADD(DAY, 4, @Inicio);

        IF @IdUsuario IS NOT NULL AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'ENVIAR') = 0
            SET @Recusa = N'Você não tem permissão para gerar a prévia do comunicado.';

        SELECT @Titulo = c.TITULO, @GrupoAprov = g.CODIGO
        FROM SIS.Comunicado c
        INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL_APROVACAO
        WHERE c.ID_COMUNICADO = @IdComunicado AND c.ATIVO = 1;

        IF @Recusa = N'' AND @Titulo IS NULL
            SET @Recusa = N'Comunicado não encontrado ou desligado.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM SIS.Comunicado_Edicao e
                                     WHERE e.ID_COMUNICADO = @IdComunicado AND e.DT_INICIO = @Inicio AND e.SITUACAO = 'ENVIADA')
            SET @Recusa = N'O comunicado desta semana já foi enviado.';
        SET @Para = ISNULL(SIS.fn_SIS_Emails_Do_Grupo(@GrupoAprov), N'');
        IF @Recusa = N'' AND @Para = N''
            SET @Recusa = N'O grupo de aprovação do comunicado não tem e-mail ativo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Montagem';
        SET @Usuario   = ISNULL(SIS.fn_SIS_Usuario_Login(@IdUsuario), N'rotina');
        SET @Assunto   = N'CMJ - ' + @Titulo + N' - semana de ' + LEFT(SIS.fn_SIS_Formatar_Data(@Inicio), 5)
                       + N' a ' + SIS.fn_SIS_Formatar_Data(@Fim);
        SET @Conteudo  = SIS.fn_SIS_Comunicado_Conteudo(@IdComunicado);
        SET @Corpo     = SIS.fn_SIS_Email_HTML(@Titulo, 'INFO', @Conteudo, NULL, NULL, 1);
        SET @AssuntoPv = N'[PRÉVIA] ' + @Assunto;
        SET @Aviso     = N'<div style="background:#FFF3E0;border-left:4px solid #E65100;padding:10px 14px;margin-bottom:16px;">'
                       + N'<b>Prévia para aprovação.</b> Este e-mail ainda não foi enviado aos destinatários. '
                       + N'Para liberar, abra o ' + SIS.fn_SIS_Texto_HTML(ISNULL(NULLIF(SIS.fn_SIS_Parametro('SISTEMA_NOME'), N''), N'SistemaCMJ')) + N', menu Sistema &gt; E-mails &gt; Comunicados, e clique em "Aprovar e enviar".</div>';
        SET @CorpoPv   = SIS.fn_SIS_Email_HTML(N'Prévia - ' + @Titulo, 'INFO', @Aviso + @Conteudo, @NomeProc, @GrupoAprov, 0);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE e
           SET e.SITUACAO = 'DESCARTADA', e.DT_ALTERACAO = SYSDATETIME(), e.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Edicao e WITH (UPDLOCK, HOLDLOCK)
        WHERE e.ID_COMUNICADO = @IdComunicado AND e.SITUACAO = 'PREVIA';

        INSERT INTO SIS.Comunicado_Edicao (ID_COMUNICADO, DT_INICIO, DT_FIM, ASSUNTO, CORPO_HTML, SITUACAO, USUARIO_CRIACAO)
        VALUES (@IdComunicado, @Inicio, @Fim, @Assunto, @Corpo, 'PREVIA', @Usuario);
        SET @IdEdicao = SCOPE_IDENTITY();

        SET @Chave = N'COMUNICADO_PREVIA:' + CONVERT(NVARCHAR(30), @IdEdicao);
        EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @AssuntoPv, @CorpoHTML = @CorpoPv, @Tipo = 'COMUNICADO_PREVIA',
             @Origem = @NomeProc, @ChaveOrigem = @Chave, @Grupo = @GrupoAprov, @Conta = 'INTERNA', @IdEmail = @IdEmail OUTPUT;

        IF @IdEmail IS NULL
            THROW 50001, N'A prévia não entrou na fila de e-mails (veja o log de erros).', 1;

        UPDATE SIS.Comunicado_Edicao SET ID_EMAIL_PREVIA = @IdEmail WHERE ID_COMUNICADO_EDICAO = @IdEdicao;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia gerada e enviada para aprovação.' AS NVARCHAR(400)) AS MENSAGEM, @IdEdicao AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gerar a prévia do comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Previa_Processar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Previa_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Rotina semanal (SIS.Rotina COMUNICADO_PREVIA, sexta 9h): gera a
                prévia de cada comunicado ativo. Um comunicado com problema não
                impede os outros (laço isolado, regra 13); no fim, se algum falhou,
                relança um erro agregado para a rotina registrar ERRO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Previa_Processar]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Previa_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Laço';
    DECLARE @Id         INT           = 0;
    DECLARE @Proximo    INT;
    DECLARE @Falhas     NVARCHAR(MAX) = N'';
    DECLARE @Res        TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);

    WHILE 1 = 1
    BEGIN
        SET @Proximo = NULL;
        SELECT TOP (1) @Proximo = c.ID_COMUNICADO
        FROM SIS.Comunicado c
        WHERE c.ATIVO = 1 AND c.ID_COMUNICADO > @Id
        ORDER BY c.ID_COMUNICADO;
        IF @Proximo IS NULL BREAK;
        SET @Id = @Proximo;

        BEGIN TRY
            DELETE FROM @Res;
            INSERT INTO @Res (SUCESSO, MENSAGEM, ID)
            EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = NULL, @IdComunicado = @Id;

            SELECT @Falhas = @Falhas + N' [' + CONVERT(NVARCHAR(10), @Id) + N'] ' + r.MENSAGEM
            FROM @Res r
            WHERE r.SUCESSO = 0;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SET @Falhas = @Falhas + N' [' + CONVERT(NVARCHAR(10), @Id) + N'] ' + ERROR_MESSAGE();
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;
    END;

    IF @Falhas <> N''
    BEGIN
        SET @Falhas = LEFT(N'Comunicados com problema:' + @Falhas, 2000);
        THROW 50001, @Falhas, 1;
    END;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Obter.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Dados da tela Comunicados: o comunicado (o primeiro, ativo antes,
                quando @IdComunicado vier vazio), os itens (ITENS_JSON), as últimas
                20 edições (EDICOES_JSON, sem o HTML), os destinatários dos dois
                grupos e a agenda da rotina. Permissão: VER em SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Obter]
    @IdUsuario     INT,
    @IdComunicado  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os comunicados.', 1;

        IF @IdComunicado IS NULL
            SELECT TOP (1) @IdComunicado = c.ID_COMUNICADO FROM SIS.Comunicado c ORDER BY c.ATIVO DESC, c.ID_COMUNICADO;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_COMUNICADO, c.CODIGO, c.TITULO, c.INTRODUCAO, c.EXIGE_APROVACAO, c.ATIVO,
               g.CODIGO AS GRUPO, ga.CODIGO AS GRUPO_APROVACAO,
               ISNULL(SIS.fn_SIS_Emails_Do_Grupo(g.CODIGO), N'')  AS DESTINATARIOS,
               ISNULL(SIS.fn_SIS_Emails_Do_Grupo(ga.CODIGO), N'') AS DESTINATARIOS_APROVACAO,
               ISNULL(CONVERT(VARCHAR(5), r.HORARIO, 108), '') AS ROTINA_HORARIO, ISNULL(r.DIAS_SEMANA, '') AS ROTINA_DIAS,
               r.PROXIMA_EXECUCAO AS ROTINA_PROXIMA, ISNULL(r.ATIVA, CAST(0 AS BIT)) AS ROTINA_ATIVA,
               ISNULL((SELECT i.ID_COMUNICADO_ITEM AS id, i.SECAO AS secao, i.TEXTO AS texto, i.ORDEM AS ordem, i.ATIVO AS ativo
                       FROM SIS.Comunicado_Item i
                       WHERE i.ID_COMUNICADO = c.ID_COMUNICADO AND i.ATIVO = 1
                       ORDER BY i.SECAO, i.ORDEM, i.ID_COMUNICADO_ITEM
                       FOR JSON PATH), N'[]') AS ITENS_JSON,
               ISNULL((SELECT TOP (20) e.ID_COMUNICADO_EDICAO AS id, e.DT_INICIO AS inicio, e.DT_FIM AS fim, e.ASSUNTO AS assunto,
                              e.SITUACAO AS situacao, e.DT_CRIACAO AS criada, e.DT_APROVACAO AS aprovada, e.USUARIO_APROVACAO AS aprovadaPor
                       FROM SIS.Comunicado_Edicao e
                       WHERE e.ID_COMUNICADO = c.ID_COMUNICADO
                       ORDER BY e.ID_COMUNICADO_EDICAO DESC
                       FOR JSON PATH), N'[]') AS EDICOES_JSON
        FROM SIS.Comunicado c
        INNER JOIN SIS.Grupo_Email g  ON g.ID_GRUPO_EMAIL  = c.ID_GRUPO_EMAIL
        INNER JOIN SIS.Grupo_Email ga ON ga.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL_APROVACAO
        LEFT  JOIN SIS.Rotina r ON r.CODIGO = 'COMUNICADO_PREVIA'
        WHERE c.ID_COMUNICADO = @IdComunicado;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o comunicado. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Edicao_Obter.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Uma edição com o HTML, para a tela mostrar exatamente o que será
                (ou foi) enviado. Permissão: VER em SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Obter]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'VER') = 0
        THROW 50001, N'Você não tem permissão para ver os comunicados.', 1;

    SELECT e.ID_COMUNICADO_EDICAO, e.ID_COMUNICADO, e.DT_INICIO, e.DT_FIM, e.ASSUNTO, e.CORPO_HTML, e.SITUACAO,
           e.DT_APROVACAO, e.USUARIO_APROVACAO, e.DT_CRIACAO, e.USUARIO_CRIACAO
    FROM SIS.Comunicado_Edicao e WITH (NOLOCK)
    WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Grava a introdução e a lista inteira de itens do comunicado
                (tudo-ou-nada). @ItensJson: [{"id":null|n,"secao":"EM_TESTE",
                "texto":"...","ordem":1}]. Item que sumiu da lista é DESATIVADO
                (nunca apagado). Permissão: ALTERAR em SIS_COMUNICADO. Não gera
                prévia: a tela oferece "Gerar prévia agora".

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Gravar @IdUsuario = 2, @IdComunicado = 1, @Introducao = N'Olá', @ItensJson = N'[{"secao":"EM_TESTE","texto":"Teste","ordem":1}]';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Gravar]
    @IdUsuario     INT,
    @IdComunicado  INT,
    @Introducao    NVARCHAR(1000) = NULL,
    @ItensJson     NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        DROP TABLE IF EXISTS #Itens;
        SET @Introducao = LTRIM(RTRIM(ISNULL(@Introducao, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para alterar comunicados.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado c WHERE c.ID_COMUNICADO = @IdComunicado)
            SET @Recusa = N'Comunicado não encontrado.';
        IF @Recusa = N'' AND ISJSON(ISNULL(@ItensJson, N'')) = 0
            SET @Recusa = N'Lista de itens inválida.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
            RETURN;
        END;

        SELECT j.id AS ID_ITEM, UPPER(LTRIM(RTRIM(ISNULL(j.secao, '')))) AS SECAO,
               LTRIM(RTRIM(ISNULL(j.texto, N''))) AS TEXTO, ISNULL(j.ordem, 0) AS ORDEM
        INTO #Itens
        FROM OPENJSON(@ItensJson) WITH (id INT '$.id', secao VARCHAR(15) '$.secao', texto NVARCHAR(400) '$.texto', ordem SMALLINT '$.ordem') j;

        IF EXISTS (SELECT 1 FROM #Itens WHERE SECAO NOT IN ('IMPLANTADO', 'EM_TESTE', 'PROXIMA_FASE'))
            SET @Recusa = N'Seção inválida num dos itens.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens WHERE TEXTO = N'')
            SET @Recusa = N'Há item sem texto. Preencha ou remova a linha.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens WHERE LEN(TEXTO) > 300)
            SET @Recusa = N'Cada item pode ter no máximo 300 caracteres.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens i WHERE i.ID_ITEM IS NOT NULL
                                     AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Item ci WHERE ci.ID_COMUNICADO_ITEM = i.ID_ITEM AND ci.ID_COMUNICADO = @IdComunicado))
            SET @Recusa = N'Um dos itens não pertence a este comunicado.';
        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Itens;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE c
           SET c.INTRODUCAO = @Introducao, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado c
        WHERE c.ID_COMUNICADO = @IdComunicado AND c.INTRODUCAO <> @Introducao;

        UPDATE ci
           SET ci.SECAO = i.SECAO, ci.TEXTO = i.TEXTO, ci.ORDEM = i.ORDEM, ci.ATIVO = 1,
               ci.DT_ALTERACAO = SYSDATETIME(), ci.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Item ci
        INNER JOIN #Itens i ON i.ID_ITEM = ci.ID_COMUNICADO_ITEM
        WHERE ci.SECAO <> i.SECAO OR ci.TEXTO <> i.TEXTO OR ci.ORDEM <> i.ORDEM OR ci.ATIVO = 0;

        UPDATE ci
           SET ci.ATIVO = 0, ci.DT_ALTERACAO = SYSDATETIME(), ci.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Item ci
        WHERE ci.ID_COMUNICADO = @IdComunicado AND ci.ATIVO = 1
          AND NOT EXISTS (SELECT 1 FROM #Itens i WHERE i.ID_ITEM = ci.ID_COMUNICADO_ITEM);

        INSERT INTO SIS.Comunicado_Item (ID_COMUNICADO, SECAO, TEXTO, ORDEM, USUARIO_CRIACAO)
        SELECT @IdComunicado, i.SECAO, i.TEXTO, i.ORDEM, @Usuario
        FROM #Itens i
        WHERE i.ID_ITEM IS NULL;

        COMMIT TRANSACTION;
        DROP TABLE IF EXISTS #Itens;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Comunicado gravado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Itens;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Edicao_Aprovar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Aprovar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : "Aprovar e enviar": manda ao grupo oficial exatamente o que foi
                aprovado na prévia (assunto e HTML da edição) e marca ENVIADA, tudo
                na mesma transação. Só edição em PREVIA. Permissão: APROVAR em
                SIS_COMUNICADO. Conta EXTERNA (destinatários de fora). No banco
                _LOCAL a fila manda para o EMAIL_TESTE (proteção da 02d).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Edicao_Aprovar @IdUsuario = 2, @IdEdicao = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Aprovar]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Edicao_Aprovar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Situacao   VARCHAR(10);
    DECLARE @Grupo      VARCHAR(30);
    DECLARE @Para       NVARCHAR(MAX);
    DECLARE @Assunto    NVARCHAR(400);
    DECLARE @Corpo      NVARCHAR(MAX);
    DECLARE @IdEmail    BIGINT;
    DECLARE @Chave      NVARCHAR(200);
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'APROVAR') = 0
            SET @Recusa = N'Você não tem permissão para aprovar comunicados.';

        SET @EtapaAtual = 'Envio';
        BEGIN TRANSACTION;

        SELECT @Situacao = e.SITUACAO, @Grupo = g.CODIGO, @Assunto = e.ASSUNTO, @Corpo = e.CORPO_HTML
        FROM SIS.Comunicado_Edicao e WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = e.ID_COMUNICADO
        INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL
        WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao;

        IF @Recusa = N'' AND @Situacao IS NULL
            SET @Recusa = N'Edição do comunicado não encontrada.';
        IF @Recusa = N'' AND @Situacao <> 'PREVIA'
            SET @Recusa = CASE @Situacao WHEN 'ENVIADA' THEN N'Este comunicado já foi enviado.'
                                         ELSE N'Esta prévia foi descartada. Gere uma prévia nova.' END;
        SET @Para = ISNULL(SIS.fn_SIS_Emails_Do_Grupo(@Grupo), N'');
        IF @Recusa = N'' AND @Para = N''
            SET @Recusa = N'O grupo de destinatários do comunicado não tem e-mail ativo.';
        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi alterado; COMMIT (e não ROLLBACK) funciona também dentro de INSERT-EXEC
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Chave   = N'COMUNICADO:' + CONVERT(NVARCHAR(30), @IdEdicao);
        EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @Assunto, @CorpoHTML = @Corpo, @Tipo = 'COMUNICADO',
             @Origem = @NomeProc, @ChaveOrigem = @Chave, @Grupo = @Grupo, @Conta = 'EXTERNA', @IdEmail = @IdEmail OUTPUT;

        IF @IdEmail IS NULL
            THROW 50001, N'O comunicado não entrou na fila de e-mails (veja o log de erros).', 1;

        UPDATE SIS.Comunicado_Edicao
           SET SITUACAO = 'ENVIADA', ID_EMAIL_OFICIAL = @IdEmail, DT_APROVACAO = SYSDATETIME(), USUARIO_APROVACAO = @Usuario,
               DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_COMUNICADO_EDICAO = @IdEdicao;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Comunicado aprovado. O e-mail foi para a fila de envio.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível aprovar o comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Comunicado_Edicao_Descartar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Descartar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Descarta uma prévia (nada é enviado). Permissão: APROVAR em
                SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Descartar]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Edicao_Descartar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'APROVAR') = 0
            SET @Recusa = N'Você não tem permissão para descartar comunicados.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Edicao e WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao AND e.SITUACAO = 'PREVIA')
            SET @Recusa = N'Só uma prévia pendente pode ser descartada.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        UPDATE SIS.Comunicado_Edicao
           SET SITUACAO = 'DESCARTADA', DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_COMUNICADO_EDICAO = @IdEdicao AND SITUACAO = 'PREVIA';

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia descartada. Nada foi enviado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível descartar a prévia. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Instalacao_Situacao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Instalacao_Situacao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Diz se o banco está esperando o PRIMEIRO ACESSO da instalação:
                nenhum usuário administrador (perfil de nível 1 ou 2, ativo, não
                interno) tem senha definida. Só nesse caso a tela de instalação
                (que a API abre apenas no próprio servidor) pode definir as
                senhas do administrador geral e do administrador da empresa.
                Devolve 1 linha: PENDENTE, LOGIN_GERAL, LOGIN_EMPRESA.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL): ver sql/testes/SIS/03d_Homologacao_Instalacao.sql.
    -- EXEC SIS.SIS_Instalacao_Situacao;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Instalacao_Situacao]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(CASE WHEN EXISTS (SELECT 1 FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                                  WHERE p.NIVEL_ADMIN >= 1 AND u.INTERNO = 0 AND u.ATIVO = 1 AND u.SENHA_HASH IS NOT NULL)
                     THEN 0 ELSE 1 END AS BIT) AS PENDENTE,
           ISNULL((SELECT TOP (1) u.LOGIN FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                   WHERE p.NIVEL_ADMIN = 2 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO), '') AS LOGIN_GERAL,
           ISNULL((SELECT TOP (1) u.LOGIN FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                   WHERE p.NIVEL_ADMIN = 1 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO), '') AS LOGIN_EMPRESA;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Instalacao_Senha_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Instalacao_Senha_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : PRIMEIRO ACESSO da instalação (uso exclusivo da API, tela que só
                abre no próprio servidor): grava de uma vez (tudo-ou-nada) a
                senha do administrador geral (nível 2) e a do administrador da
                empresa (nível 1). O banco recebe só o PBKDF2-SHA256 calculado
                pela API (como em SIS_Usuario_Senha_Gravar).
                Só funciona enquanto NENHUM administrador tem senha
                (SIS_Instalacao_Situacao.PENDENTE = 1); depois disso recusa
                sempre: senha nova passa pelo caminho normal (tela Usuários).
                Administrador geral: TROCAR_SENHA = 0 (ele mesmo digitou).
                Administrador da empresa: TROCAR_SENHA = 1 (senha provisória,
                troca no primeiro login).
                Gravado em nome do usuário "sistema" (auditoria), estação
                "Instalação (servidor)".
                Devolve 1 linha: SUCESSO, MENSAGEM.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL): ver sql/testes/SIS/03d_Homologacao_Instalacao.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Instalacao_Senha_Gravar]
    @HashGeral     VARBINARY(64),
    @SaltGeral     VARBINARY(64),
    @HashEmpresa   VARBINARY(64),
    @SaltEmpresa   VARBINARY(64),
    @Iteracoes     INT,
    @Algoritmo     VARCHAR(30),
    @Ip            VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[SIS].[SIS_Instalacao_Senha_Gravar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Validação';
    DECLARE @Recusa        NVARCHAR(400) = N'';
    DECLARE @MinIteracoes  INT;
    DECLARE @IdSistema     INT;
    DECLARE @IdGeral       INT;
    DECLARE @IdEmpresa     INT;

    BEGIN TRY
        SET @MinIteracoes = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SENHA_PBKDF2_ITERACOES'), 600000);
        IF @MinIteracoes < 100000 SET @MinIteracoes = 100000;
        SET @IdSistema = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema' AND u.INTERNO = 1);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK) INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                       WHERE p.NIVEL_ADMIN >= 1 AND u.INTERNO = 0 AND u.ATIVO = 1 AND u.SENHA_HASH IS NOT NULL)
                SET @Recusa = N'A instalação já foi concluída: os administradores já têm senha. Para trocar uma senha, use a tela de usuários.';

            SELECT TOP (1) @IdGeral = u.ID_USUARIO FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
            WHERE p.NIVEL_ADMIN = 2 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO;
            SELECT TOP (1) @IdEmpresa = u.ID_USUARIO FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
            WHERE p.NIVEL_ADMIN = 1 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO;

            IF @Recusa = N'' AND (@IdGeral IS NULL OR @IdEmpresa IS NULL OR @IdSistema IS NULL)
                SET @Recusa = N'Faltam os usuários iniciais no banco (rode o MASTER).';
            IF @Recusa = N'' AND ISNULL(@Algoritmo, '') <> 'PBKDF2-SHA256'
                SET @Recusa = N'Falha técnica: algoritmo de senha não suportado.';
            IF @Recusa = N'' AND (DATALENGTH(ISNULL(@HashGeral, 0x)) <> 32 OR DATALENGTH(ISNULL(@HashEmpresa, 0x)) <> 32)
                SET @Recusa = N'Falha técnica: hash de senha inválido.';
            IF @Recusa = N'' AND (DATALENGTH(ISNULL(@SaltGeral, 0x)) < 16 OR DATALENGTH(ISNULL(@SaltEmpresa, 0x)) < 16)
                SET @Recusa = N'Falha técnica: salt de senha inválido.';
            IF @Recusa = N'' AND ISNULL(@Iteracoes, 0) < @MinIteracoes
                SET @Recusa = N'Falha técnica: quantidade de iterações da senha abaixo do mínimo.';

            IF @Recusa <> N''
            BEGIN
                COMMIT TRANSACTION;
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM;
                RETURN;
            END;

            EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Estacao = N'Instalação (servidor)', @Origem = N'Tela de primeiro acesso';

            UPDATE u
               SET u.SENHA_HASH         = CASE WHEN u.ID_USUARIO = @IdGeral THEN @HashGeral ELSE @HashEmpresa END,
                   u.SENHA_SALT         = CASE WHEN u.ID_USUARIO = @IdGeral THEN @SaltGeral ELSE @SaltEmpresa END,
                   u.SENHA_ITERACOES    = @Iteracoes,
                   u.SENHA_ALGORITMO    = @Algoritmo,
                   u.DT_SENHA           = SYSDATETIME(),
                   u.TROCAR_SENHA       = CASE WHEN u.ID_USUARIO = @IdGeral THEN 0 ELSE 1 END,
                   u.TENTATIVAS_ERRADAS = 0,
                   u.BLOQUEADO          = 0,
                   u.DT_BLOQUEIO        = NULL,
                   u.DT_ALTERACAO       = SYSDATETIME(),
                   u.USUARIO_ALTERACAO  = N'instalacao'
            FROM SIS.Usuario u
            WHERE u.ID_USUARIO IN (@IdGeral, @IdEmpresa);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Senhas gravadas. Entre com o administrador geral; o administrador da empresa troca a senha no primeiro acesso.' AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar as senhas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Registro_Existe.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Registro_Existe]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Diz se existe o registro @Id (chave primária de uma coluna) na
                tabela @Tabela, que precisa estar entre as TABELAS_DA_TELA do
                item @Item (SIS.fn_SIS_Item_Tem_Tabela); qualquer outra tabela
                devolve 0. Usada por quem precisa conferir um registro de
                tabela variável (ex.: SIS_Anexo_Gravar).
                Roda com a permissão do dono do banco (EXECUTE AS OWNER) porque
                a consulta é montada na hora (SQL dinâmico) e, no servidor, o
                login da API só executa procedures (papel rl_sistemacmj_api):
                sem isso o SELECT seria recusado. O escopo elevado fica só nesta
                consulta; nomes vêm do catálogo e vão com QUOTENAME.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d; achado no ensaio do serviço).

  Homologação (LOCAL e ensaio): sql/testes/SIS/03d_Homologacao_Registro_Existe.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Registro_Existe]
    @Item    VARCHAR(40),
    @Tabela  NVARCHAR(256),
    @Id      BIGINT,
    @Existe  BIT OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ObjId INT, @Pk SYSNAME, @Qtd INT, @Achou INT, @Sql NVARCHAR(MAX);
    SET @Existe = 0;

    IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0 OR @Id IS NULL
        RETURN;

    SET @ObjId = OBJECT_ID(@Tabela, N'U');
    SELECT @Pk = MAX(c.name), @Qtd = COUNT(*)
    FROM sys.indexes ix
    INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
    INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

    IF @ObjId IS NULL OR @Pk IS NULL OR @Qtd <> 1
        RETURN;

    SET @Sql = N'SELECT @Achou = 1 FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId))
             + N' WHERE ' + QUOTENAME(@Pk) + N' = @Id;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Achou INT OUTPUT', @Id = @Id, @Achou = @Achou OUTPUT;
    SET @Existe = CASE WHEN @Achou = 1 THEN 1 ELSE 0 END;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Registrar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Registrar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Registra um backup em SIS.Backup_Execucao. Chamada SÓ pelo script de
                backup do servidor (instalacao\backup_servidor.ps1), que roda
                pelas tarefas do Windows; o login da API não pode executar
                (DENY no papel rl_sistemacmj_api).
                Situação ERRO: manda aviso por e-mail para o parâmetro
                EMAIL_ADMIN_ALERTA (se preenchido), uma vez por backup.
                @ArquivosExistentes (opcional): lista separada por "|" com os
                arquivos que ainda existem na pasta depois da limpeza; os
                demais registros ficam com ARQUIVO_EXISTE = 0.
                Devolve 1 linha: ID_BACKUP.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Registrar]
    @Tipo                VARCHAR(10),
    @Arquivo             NVARCHAR(400),
    @DtInicio            DATETIME2(0),
    @DtFim               DATETIME2(0)   = NULL,
    @TamanhoMb           DECIMAL(12,1)  = 0,
    @Situacao            VARCHAR(10),
    @Mensagem            NVARCHAR(2000) = N'',
    @CopiaNuvem          BIT            = 0,
    @ArquivosExistentes  NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id BIGINT, @Para NVARCHAR(400), @IdEmail BIGINT, @Corpo NVARCHAR(MAX), @Chave NVARCHAR(200);

    INSERT INTO SIS.Backup_Execucao (TIPO, ARQUIVO, DT_INICIO, DT_FIM, TAMANHO_MB, SITUACAO, MENSAGEM, COPIA_NUVEM)
    VALUES (@Tipo, ISNULL(@Arquivo, N''), @DtInicio, @DtFim, ISNULL(@TamanhoMb, 0), @Situacao, LEFT(ISNULL(@Mensagem, N''), 2000), ISNULL(@CopiaNuvem, 0));
    SET @Id = CAST(SCOPE_IDENTITY() AS BIGINT);

    IF @ArquivosExistentes IS NOT NULL
        UPDATE b SET b.ARQUIVO_EXISTE = 0
        FROM SIS.Backup_Execucao b
        WHERE b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N''
          AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@ArquivosExistentes, '|') s WHERE LTRIM(RTRIM(s.value)) = b.ARQUIVO);

    IF @Situacao = 'ERRO'
    BEGIN
        SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
        IF @Para <> N''
        BEGIN
            SET @Corpo = SIS.fn_SIS_Email_HTML(N'Falha no backup', 'ALERTA',
                N'<p>O backup <b>' + SIS.fn_SIS_Texto_HTML(@Tipo) + N'</b> do banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b> falhou em '
                + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@DtInicio), N'') + N'.</p><p>Mensagem: ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Mensagem, N'')) + N'</p>'
                + N'<p>Confira o servidor e o registro do backup (pasta do backup, arquivo backup.log).</p>',
                N'[SIS].[SIS_Backup_Registrar]', NULL, 0);
            SET @Chave = N'BACKUP_ERRO_' + CONVERT(NVARCHAR(20), @Id);
            EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: falha no backup do sistema', @CorpoHTML = @Corpo,
                 @Tipo = 'ALERTA', @Origem = N'[SIS].[SIS_Backup_Registrar]', @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
        END;
    END;

    SELECT @Id AS ID_BACKUP;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.SIS_Backup_Conferir_Processar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Conferir_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Rotina agendada (BACKUP_CONFERIR, de hora em hora): avisa por
                e-mail (parâmetro EMAIL_ADMIN_ALERTA) quando o backup ATRASA:
                  - último backup COMPLETO ok há mais de BACKUP_HORAS_ALERTA_COMPLETO;
                  - último backup do LOG ok há mais de BACKUP_HORAS_ALERTA_LOG
                    (só depois do primeiro completo);
                  - último TESTE de restauração ok há mais de BACKUP_DIAS_ALERTA_TESTE.
                Cada aviso sai no máximo uma vez por dia (chave de origem com a
                data). Sem nenhum backup registrado ainda: não avisa (servidor
                recém-instalado).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Conferir_Processar]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Para NVARCHAR(400) = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
    DECLARE @HorasCompleto INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_HORAS_ALERTA_COMPLETO'), 26);
    DECLARE @HorasLog INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_HORAS_ALERTA_LOG'), 3);
    DECLARE @DiasTeste INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_DIAS_ALERTA_TESTE'), 8);
    DECLARE @UltCompleto DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK');
    DECLARE @UltLog DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO IN ('LOG', 'COMPLETO') AND b.SITUACAO = 'OK');
    DECLARE @UltTeste DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'TESTE' AND b.SITUACAO = 'OK');
    DECLARE @Agora DATETIME2(0) = SYSDATETIME();
    DECLARE @Problemas NVARCHAR(MAX) = N'';
    DECLARE @Corpo NVARCHAR(MAX), @IdEmail BIGINT, @Chave NVARCHAR(200);

    IF @Para = N'' OR NOT EXISTS (SELECT 1 FROM SIS.Backup_Execucao) RETURN;

    IF @UltCompleto IS NULL OR @UltCompleto < DATEADD(HOUR, -@HorasCompleto, @Agora)
        SET @Problemas += N'<li>Backup completo: o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltCompleto), N'(nenhum)') + N'.</li>';
    IF @UltCompleto IS NOT NULL AND @UltLog < DATEADD(HOUR, -@HorasLog, @Agora)
        SET @Problemas += N'<li>Backup do log (de hora em hora): o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltLog), N'(nenhum)') + N'.</li>';
    -- teste: só cobra depois que o servidor tem backups há mais de @DiasTeste dias
    IF (SELECT MIN(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK') < DATEADD(DAY, -@DiasTeste, @Agora)
       AND (@UltTeste IS NULL OR @UltTeste < DATEADD(DAY, -@DiasTeste, @Agora))
        SET @Problemas += N'<li>Teste de restauração: o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltTeste), N'(nenhum)') + N'.</li>';

    IF @Problemas = N'' RETURN;

    SET @Corpo = SIS.fn_SIS_Email_HTML(N'Backup atrasado', 'ALERTA',
        N'<p>O backup do banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b> está atrasado:</p><ul>' + @Problemas + N'</ul>'
        + N'<p>Confira se o servidor ficou desligado, se as tarefas "SisCMJ - Backup" estão ativas no Agendador de Tarefas e o arquivo backup.log na pasta do backup.</p>',
        N'[SIS].[SIS_Backup_Conferir_Processar]', NULL, 0);
    SET @Chave = N'BACKUP_ATRASO_' + CONVERT(NVARCHAR(8), @Agora, 112);
    EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: backup do sistema atrasado', @CorpoHTML = @Corpo,
         @Tipo = 'ALERTA', @Origem = N'[SIS].[SIS_Backup_Conferir_Processar]',
         @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
END;
GO
GO

-- =============================================================================
-- 8. TRIGGERS
-- =============================================================================
PRINT N'8. TRIGGERS';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.tg_SIS_Auditoria_Protecao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [SIS].[tg_SIS_Auditoria_Protecao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Ninguém altera nem apaga a auditoria (seção 3.7), nem o
                administrador. Qualquer UPDATE ou DELETE em SIS.Auditoria é
                recusado com o erro 50010 e nada muda.
                (TRUNCATE não dispara trigger: fica bloqueado pelo DENY no
                papel da API, etapa 02d, e por ninguém ter ALTER na tabela.)

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação: ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER TRIGGER [SIS].[tg_SIS_Auditoria_Protecao]
ON [SIS].[Auditoria]
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    THROW 50010, N'A auditoria não pode ser alterada nem apagada.', 1;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/FIN.tg_FIN_Baixa_Saldo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [FIN].[tg_FIN_Baixa_Saldo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Mantém FIN.Parcela.VALOR_BAIXADO e a SITUACAO (ABERTA, PARCIAL,
                PAGA) a cada inclusão/alteração/exclusão de baixa, por delta
                (regra 9: UNION ALL de inserted positivo e deleted negativo).
                Parcela CANCELADA não muda de situação. Sem recursão: só atualiza
                o que muda (regra 20).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER TRIGGER [FIN].[tg_FIN_Baixa_Saldo]
ON [FIN].[Baixa]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    ;WITH Delta AS
    (
        SELECT d.ID_PARCELA, SUM(d.VALOR) AS VALOR
        FROM (
                SELECT i.ID_PARCELA, i.VALOR_PRINCIPAL AS VALOR FROM inserted i
                UNION ALL
                SELECT x.ID_PARCELA, -x.VALOR_PRINCIPAL FROM deleted x
             ) d
        GROUP BY d.ID_PARCELA
    )
    UPDATE p
       SET p.VALOR_BAIXADO = p.VALOR_BAIXADO + dl.VALOR
    FROM FIN.Parcela p
    INNER JOIN Delta dl ON dl.ID_PARCELA = p.ID_PARCELA
    WHERE dl.VALOR <> 0;

    UPDATE p
       SET p.SITUACAO = CASE WHEN p.VALOR_BAIXADO <= 0 THEN 'ABERTA'
                             WHEN p.VALOR_BAIXADO >= p.VALOR THEN 'PAGA'
                             ELSE 'PARCIAL' END
    FROM FIN.Parcela p
    WHERE p.ID_PARCELA IN (SELECT i.ID_PARCELA FROM inserted i UNION SELECT x.ID_PARCELA FROM deleted x)
      AND p.SITUACAO <> 'CANCELADA'
      AND p.SITUACAO <> CASE WHEN p.VALOR_BAIXADO <= 0 THEN 'ABERTA'
                             WHEN p.VALOR_BAIXADO >= p.VALOR THEN 'PAGA'
                             ELSE 'PARCIAL' END;
END;
GO
GO

-- =============================================================================
-- 8b. SEGURANCA (papel da API)
-- =============================================================================
PRINT N'8b. SEGURANCA (papel da API)';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/SIS.rl_sistemacmj_api.sql
-- -----------------------------------------------------------------------------
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
                  - DENY de EXECUTE no gerador de triggers (só instalação).
                O login e o usuário do banco (ex.: sistemacmj_api) são
                criados na instalação do servidor (instalador / MASTER), que
                também coloca o usuário neste papel: a senha nunca fica em
                arquivo do projeto.
                Idempotente: pode rodar de novo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
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
GO
GO

-- =============================================================================
-- 9. PARAMETROS E CARGA INICIAL
-- =============================================================================
PRINT N'9. PARAMETROS E CARGA INICIAL';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Modulo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Modulo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Módulos do sistema, na ordem do menu. Só insere o que falta
                (PADRAO_SQL regra 39): nada já cadastrado é alterado.
                LIBERADO_LICENCA começa 0 em todos, menos SIS (a parte básica
                do sistema). Os demais são ligados pela licença (etapa 02b).
                Ícones: definidos na fase das telas.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (16/11/2026) - HABILITADO: só o SIS nasce habilitado; os demais o
                        administrador geral liga quando estiverem prontos.
    v1.2 (16/11/2026) - Módulo COMP (Compras), pedido do Celso; nasce fora
                        da licença e desabilitado (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Modulo (CODIGO, NOME, ORDEM_MENU, ICONE, LIBERADO_LICENCA, HABILITADO)
SELECT v.CODIGO, v.NOME, v.ORDEM_MENU, '', v.LIBERADO_LICENCA, v.LIBERADO_LICENCA
FROM (VALUES
        (CAST('CAD'   AS VARCHAR(10)), CAST(N'Cadastros'           AS NVARCHAR(60)), CAST(10 AS SMALLINT), CAST(0 AS BIT)),
        ('IMOB',  N'Imóveis',             20, 0),
        ('VENDA', N'Vendas',              30, 0),
        ('FIN',   N'Financeiro',          40, 0),
        ('COMP',  N'Compras',             45, 0),
        ('BANCO', N'Bancos',              50, 0),
        ('COBR',  N'Cobrança',            60, 0),
        ('OBRA',  N'Custos de obra',      70, 0),
        ('GER',   N'Painel e relatórios', 80, 0),
        ('SIS',   N'Sistema',             90, 1)
     ) v (CODIGO, NOME, ORDEM_MENU, LIBERADO_LICENCA)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Modulo m WHERE m.CODIGO = v.CODIGO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Parametro.sql
-- -----------------------------------------------------------------------------
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
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('EMAIL_RODAPE_CNPJ', N'N', 'SN',
         N'Mostrar o CNPJ da empresa no rodapé dos e-mails enviados a clientes e terceiros (S/N).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Acao.sql
-- -----------------------------------------------------------------------------
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
        ('EXECUTAR',         N'Executar (rotina, comando)', 150)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Item.sql
-- -----------------------------------------------------------------------------
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
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOTE',          N'Lotes',               'TELA', 'sis/lotes.html',       30, 0, 1, 'SIS.Lote')
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
        ('SIS_EMAIL_FILA','EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Perfil_Usuario.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Perfil] e [SIS].[Usuario]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Os dois perfis de administrador e os usuários iniciais.
                Só insere o que falta (regra 39); perfis procurados pelo nível.
                Perfis:
                  Administrador geral (NIVEL_ADMIN 2): o criador do sistema;
                      tudo, inclusive Licença e Parâmetros; invisível para os
                      demais.
                  Administrador (NIVEL_ADMIN 1): administrador da CMJ; todos os
                      menus menos as telas exclusivas do administrador geral.
                Usuários:
                  sistema : INTERNO, rotinas automáticas e migração; nunca faz
                            login.
                  celso   : Celso de Freitas, administrador geral.
                  admin   : administrador da CMJ.
                celso e admin nascem SEM senha: a senha provisória é definida
                no primeiro acesso da instalação (tela local do servidor, que
                a API só abre em localhost e grava com o usuário "sistema");
                no primeiro login cada um troca a sua.
                Os outros perfis (Financeiro, Vendas, Consulta...) são criados
                pelo administrador da CMJ (pendência 9 da seção 6).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: perfil "Administrador
                        geral" (nível 2) e usuário celso.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Perfil (NOME, DESCRICAO, NIVEL_ADMIN, ATIVO)
SELECT v.NOME, v.DESCRICAO, v.NIVEL_ADMIN, 1
FROM (VALUES
        (CAST(N'Administrador geral' AS NVARCHAR(60)),
         CAST(N'Criador do sistema: acesso total, inclusive licença e parâmetros. Visível só para o próprio nível.' AS NVARCHAR(400)),
         CAST(2 AS TINYINT)),
        (N'Administrador',
         N'Administrador da empresa: todos os menus liberados na licença, inclusive usuários e permissões, menos licença e parâmetros.',
         1)
     ) v (NOME, DESCRICAO, NIVEL_ADMIN)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil p WHERE p.NIVEL_ADMIN = v.NIVEL_ADMIN);
GO

INSERT INTO SIS.Usuario (LOGIN, NOME, EMAIL, ID_PERFIL, TROCAR_SENHA, INTERNO, ATIVO)
SELECT v.LOGIN, v.NOME, N'', pa.ID_PERFIL, v.TROCAR_SENHA, v.INTERNO, 1
FROM (VALUES
        (CAST('sistema' AS VARCHAR(40)), CAST(N'Sistema (rotinas automáticas)' AS NVARCHAR(100)), CAST(0 AS BIT), CAST(1 AS BIT), CAST(2 AS TINYINT)),
        ('celso', N'Celso de Freitas',          1, 0, 2),
        ('admin', N'Administrador do sistema',  1, 0, 1)
     ) v (LOGIN, NOME, TROCAR_SENHA, INTERNO, NIVEL_ADMIN)
CROSS APPLY (SELECT TOP (1) p.ID_PERFIL FROM SIS.Perfil p WHERE p.NIVEL_ADMIN = v.NIVEL_ADMIN ORDER BY p.ID_PERFIL) pa
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario u WHERE u.LOGIN = v.LOGIN);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Anexo_Tipo.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Anexo_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tipos de anexo e extensões aceitas. Só insere o que falta
                (regra 39). LOGOMARCA: logomarca de cada obra (pedido do Celso,
                15/11/2026), anexada no cadastro da obra (etapa 03).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Anexo_Tipo (CODIGO, NOME, EXTENSOES)
SELECT v.CODIGO, v.NOME, v.EXTENSOES
FROM (VALUES
        (CAST('CONTRATO' AS VARCHAR(30)), CAST(N'Contrato' AS NVARCHAR(60)), CAST('pdf,doc,docx,jpg,jpeg,png' AS VARCHAR(200))),
        ('NOTA_FISCAL',  N'Nota fiscal',                'pdf,xml,jpg,jpeg,png'),
        ('COMPROVANTE',  N'Comprovante de pagamento',   'pdf,jpg,jpeg,png'),
        ('ACORDO',       N'Acordo / renegociação',      'pdf,doc,docx,jpg,jpeg,png'),
        ('BOLETO',       N'Boleto',                     'pdf'),
        ('MEDICAO',      N'Boletim de medição',         'pdf,xlsx,xls,jpg,jpeg,png'),
        ('DOCUMENTO',    N'Documento pessoal / da empresa', 'pdf,jpg,jpeg,png'),
        ('LOGOMARCA',    N'Logomarca',                  'png,jpg,jpeg,svg'),
        ('OUTRO',        N'Outro',                      'pdf,doc,docx,xls,xlsx,jpg,jpeg,png,txt,zip')
     ) v (CODIGO, NOME, EXTENSOES)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Anexo_Tipo t WHERE t.CODIGO = v.CODIGO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Auditoria_Triggers.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Rotina.sql
-- -----------------------------------------------------------------------------
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
         N'SIS.SIS_Email_Presos_Liberar', 'SIS', 'MINUTOS', 10, '00:00', '', 0, 10)
     ) v (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, MODULO, FREQUENCIA, INTERVALO, HORARIO, DIAS, DIA_MES, LIMITE)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = v.CODIGO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Comando.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Comando]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botões da tela "Instalação e manutenção" (pedidos 2 e 4 do
                Celso). Só insere o que falta; nome, descrição, grupo, ordem
                e as marcas PERIGOSO / ACEITA_PARAMETRO são acertados também
                em comando já existente (comandos só mudam por carga).
                O que cada CODIGO faz de verdade fica na lista fixa do
                serviço (fase 3, API/serviço); código sem tratamento no
                serviço termina em ERRO "comando não disponível nesta
                versão".
                A primeira instalação (SQL Server Express, .NET e o próprio
                serviço) é feita pelo instalador único, rodado uma vez como
                administrador do Windows; daí em diante, tudo por aqui.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaComando;

SELECT v.CODIGO, v.NOME, v.DESCRICAO, v.GRUPO, v.ORDEM, v.PERIGOSO, v.ACEITA, v.PARAM_DESC
INTO #CargaComando
FROM (VALUES
        (CAST('PASTAS_CRIAR' AS VARCHAR(40)), CAST(N'Criar as pastas do sistema' AS NVARCHAR(80)),
         CAST(N'Cria (se faltar) as pastas de anexos, identidade visual, backup e atualizações dos parâmetros, com as permissões do serviço.' AS NVARCHAR(1000)),
         CAST('INSTALACAO' AS VARCHAR(20)), CAST(10 AS SMALLINT), CAST(0 AS BIT), CAST(0 AS BIT), CAST(N'' AS NVARCHAR(200))),
        ('FIREWALL_LIBERAR', N'Liberar o sistema no firewall',
         N'Cria a regra do Firewall do Windows para a porta do sistema, só para a rede interna.', 'INSTALACAO', 20, 1, 0, N''),
        ('CERTIFICADO_HTTPS', N'Instalar ou renovar o certificado HTTPS',
         N'Instala o certificado (.pfx) usado pelo endereço seguro do sistema e reinicia o serviço.', 'INSTALACAO', 30, 1, 1,
         N'Nome do arquivo .pfx na pasta de atualizações'),
        ('SERVICO_INSTALAR', N'Reinstalar o serviço do sistema',
         N'Registra de novo o serviço do Windows do SistemaCMJ (início automático e recuperação em falha).', 'INSTALACAO', 40, 1, 0, N''),
        ('ATUALIZACAO_BANCO', N'Aplicar atualização do banco',
         N'Faz backup e depois roda o pacote de atualização do banco (.sql) que está na pasta de atualizações.', 'ATUALIZACAO', 10, 1, 1,
         N'Nome do arquivo .sql na pasta de atualizações'),
        ('ATUALIZACAO_SISTEMA', N'Atualizar o sistema (telas e API)',
         N'Para o serviço, troca os arquivos do sistema pelo pacote (.zip) da pasta de atualizações, guardando a versão anterior, e inicia o serviço.', 'ATUALIZACAO', 20, 1, 1,
         N'Nome do arquivo .zip na pasta de atualizações'),
        ('BACKUP_AGORA', N'Fazer backup agora',
         N'Backup completo do banco na pasta de backup, com conferência (RESTORE VERIFYONLY).', 'BACKUP', 10, 0, 0, N''),
        ('BACKUP_TESTAR', N'Testar a restauração do último backup',
         N'Restaura o último backup num banco de teste separado, confere e apaga o banco de teste. O banco em uso não é tocado.', 'BACKUP', 20, 0, 0, N''),
        ('BACKUP_COPIAR', N'Copiar backups para fora do servidor',
         N'Copia os backups para a pasta externa configurada (disco externo ou pasta sincronizada com a nuvem).', 'BACKUP', 30, 0, 0, N''),
        ('SERVICO_SITUACAO', N'Ver situação do serviço',
         N'Mostra se o serviço está rodando, desde quando, a versão e a última volta da fila de e-mails e das rotinas.', 'SERVICO', 10, 0, 0, N''),
        ('SERVICO_REINICIAR', N'Reiniciar o serviço do sistema',
         N'Reinicia o serviço do SistemaCMJ. Os usuários conectados perdem a tela aberta por alguns segundos.', 'SERVICO', 20, 1, 0, N''),
        ('BANCO_VERIFICAR', N'Verificar a integridade do banco',
         N'Roda o DBCC CHECKDB e mostra o resultado.', 'DIAGNOSTICO', 10, 0, 0, N''),
        ('DISCO_ESPACO', N'Espaço em disco do servidor',
         N'Mostra o espaço livre dos discos e o tamanho do banco, dos anexos e dos backups.', 'DIAGNOSTICO', 20, 0, 0, N''),
        ('LOG_SERVICO_VER', N'Ver o log do serviço',
         N'Mostra as últimas linhas do log do serviço do sistema (sem senhas).', 'DIAGNOSTICO', 30, 0, 0, N'')
     ) v (CODIGO, NOME, DESCRICAO, GRUPO, ORDEM, PERIGOSO, ACEITA, PARAM_DESC);

INSERT INTO SIS.Comando (CODIGO, NOME, DESCRICAO, GRUPO, ORDEM, PERIGOSO, ACEITA_PARAMETRO, PARAMETRO_DESCRICAO, USUARIO_CRIACAO)
SELECT c.CODIGO, c.NOME, c.DESCRICAO, c.GRUPO, c.ORDEM, c.PERIGOSO, c.ACEITA, c.PARAM_DESC, N'instalacao'
FROM #CargaComando c
WHERE NOT EXISTS (SELECT 1 FROM SIS.Comando x WHERE x.CODIGO = c.CODIGO);

UPDATE x
   SET x.NOME = c.NOME, x.DESCRICAO = c.DESCRICAO, x.GRUPO = c.GRUPO, x.ORDEM = c.ORDEM,
       x.PERIGOSO = c.PERIGOSO, x.ACEITA_PARAMETRO = c.ACEITA, x.PARAMETRO_DESCRICAO = c.PARAM_DESC,
       x.DT_ALTERACAO = SYSDATETIME(), x.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Comando x
INNER JOIN #CargaComando c ON c.CODIGO = x.CODIGO
WHERE x.NOME <> c.NOME COLLATE Latin1_General_BIN2 OR x.DESCRICAO <> c.DESCRICAO COLLATE Latin1_General_BIN2
   OR x.GRUPO <> c.GRUPO OR x.ORDEM <> c.ORDEM OR x.PERIGOSO <> c.PERIGOSO OR x.ACEITA_PARAMETRO <> c.ACEITA
   OR x.PARAMETRO_DESCRICAO <> c.PARAM_DESC COLLATE Latin1_General_BIN2;

DROP TABLE IF EXISTS #CargaComando;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/BANCO/Carga_BANCO_Banco.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga inicial de [BANCO].[Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Principais bancos (código COMPE e ISPB). Só insere o que falta
                (regra 39): banco já cadastrado não é alterado. O administrador
                acrescenta outros pela tela "Bancos" (conferir o ISPB antes de usar
                em PIX).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO BANCO.Banco (CODIGO, ISPB, NOME, USUARIO_CRIACAO)
SELECT v.CODIGO, v.ISPB, v.NOME, N'instalacao'
FROM (VALUES
        (CAST('001' AS CHAR(3)), CAST('00000000' AS VARCHAR(8)), CAST(N'Banco do Brasil' AS NVARCHAR(80))),
        ('033', '90400888', N'Santander'),
        ('041', '92702067', N'Banrisul'),
        ('077', '00416968', N'Banco Inter'),
        ('104', '00360305', N'Caixa Econômica Federal'),
        ('208', '30306294', N'BTG Pactual'),
        ('237', '60746948', N'Bradesco'),
        ('260', '18236120', N'Nubank'),
        ('290', '08561701', N'PagBank (PagSeguro)'),
        ('323', '10573521', N'Mercado Pago'),
        ('336', '31872495', N'C6 Bank'),
        ('341', '60701190', N'Itaú Unibanco'),
        ('422', '58160789', N'Safra'),
        ('748', '01181521', N'Sicredi'),
        ('756', '02038232', N'Sicoob')
     ) v (CODIGO, ISPB, NOME)
WHERE NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.CODIGO = v.CODIGO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/Carga_CAD_Item.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/CAD/Carga_CAD_Auditoria_Triggers.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/Carga_FIN_Item.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga de [SIS].[Item] e [SIS].[Item_Acao] do módulo FIN
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Tela "Arquivo morto" (só consulta: VER e EXPORTAR, sem incluir,
                alterar ou excluir). Nasce DESABILITADA, como toda tela de módulo
                novo. As telas de lançamento, baixa e conciliação entram na fase 4.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_ARQUIVO_MORTO', N'Arquivo morto', 'TELA', 'fin/arquivo-morto.html', 90, 0, 0, 'FIN.Arquivo_Morto'
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_ARQUIVO_MORTO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_ARQUIVO_MORTO' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))), ('FIN_ARQUIVO_MORTO', 'EXPORTAR')) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Comunicado.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga do boletim semanal da implantação
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Grupos de e-mail, comunicado BOLETIM_IMPLANTACAO com os itens
                iniciais aprovados pelo Celso em 17/11/2026, tela Comunicados (menu
                Sistema > E-mails; administrador geral e administrador da CMJ) e a
                rotina COMUNICADO_PREVIA (sexta-feira, 9h). Só insere o que falta
                (regra 39): o que o Celso mudar pela tela não é sobrescrito.
                Destinatários oficiais (17/11/2026): escritório Construtora Marcílio
                Judice e Danielle M. Judice Daher. Aprovação: Celso.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
    v1.1 (20/11/2026) - Etapa 03d: a rotina COMUNICADO_PREVIA nasce DESLIGADA fora
                        do banco de teste (_LOCAL), para o servidor não mandar um
                        segundo boletim enquanto o notebook manda; o Celso liga
                        na virada (decisão de 20/11/2026).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT v.CODIGO, v.NOME, v.DESCRICAO, N'instalacao'
FROM (VALUES
        (CAST('BOLETIM_IMPLANTACAO' AS VARCHAR(30)), CAST(N'Boletim da implantação' AS NVARCHAR(80)),
         CAST(N'Recebem o boletim semanal do andamento da implantação do SistemaCMJ.' AS NVARCHAR(400))),
        ('BOLETIM_APROVACAO', N'Aprovação do boletim', N'Recebem a prévia do boletim para aprovar antes do envio oficial.')
     ) v (CODIGO, NOME, DESCRICAO)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = v.CODIGO);
GO

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, v.EMAIL, v.NOME, N'instalacao'
FROM (VALUES
        (CAST('BOLETIM_IMPLANTACAO' AS VARCHAR(30)), CAST(N'construtora.m.judice@gmail.com' AS NVARCHAR(256)), CAST(N'Escritório Construtora Marcílio Judice' AS NVARCHAR(100))),
        ('BOLETIM_IMPLANTACAO', N'dmjdaher@gmail.com',       N'Danielle M. Judice Daher'),
        ('BOLETIM_APROVACAO',   N'celsofreitas62@gmail.com', N'Celso de Freitas')
     ) v (GRUPO, EMAIL, NOME)
INNER JOIN SIS.Grupo_Email g ON g.CODIGO = v.GRUPO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.EMAIL = v.EMAIL);
GO

INSERT INTO SIS.Comunicado (CODIGO, TITULO, INTRODUCAO, ID_GRUPO_EMAIL, ID_GRUPO_EMAIL_APROVACAO, EXIGE_APROVACAO, USUARIO_CRIACAO)
SELECT 'BOLETIM_IMPLANTACAO', N'Boletim da implantação do SisCMJ',
       N'Segue o resumo semanal do andamento da implantação do novo sistema de gestão da Construtora.',
       g.ID_GRUPO_EMAIL, ga.ID_GRUPO_EMAIL, 1, N'instalacao'
FROM SIS.Grupo_Email g
INNER JOIN SIS.Grupo_Email ga ON ga.CODIGO = 'BOLETIM_APROVACAO'
WHERE g.CODIGO = 'BOLETIM_IMPLANTACAO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado c WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO');
GO

IF NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Item i INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = i.ID_COMUNICADO WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO')
    INSERT INTO SIS.Comunicado_Item (ID_COMUNICADO, SECAO, TEXTO, ORDEM, USUARIO_CRIACAO)
    SELECT c.ID_COMUNICADO, v.SECAO, v.TEXTO, v.ORDEM, N'instalacao'
    FROM (VALUES
            (CAST('IMPLANTADO' AS VARCHAR(15)), CAST(N'Nenhum módulo em uso na empresa ainda. A instalação no servidor da Construtora vem logo depois da fase atual.' AS NVARCHAR(300)), CAST(1 AS SMALLINT)),
            ('EM_TESTE',     N'Entrada no sistema com usuário e senha, e menu.', 1),
            ('EM_TESTE',     N'Cadastro de clientes e fornecedores.', 2),
            ('PROXIMA_FASE', N'Financeiro: contas a pagar e a receber.', 1),
            ('PROXIMA_FASE', N'Preparação da migração dos dados do sistema antigo.', 2)
         ) v (SECAO, TEXTO, ORDEM)
    CROSS JOIN SIS.Comunicado c
    WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO';
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'SIS_COMUNICADO', N'Comunicados', 'TELA', 'sis/comunicados.html', 30, 0, 1,
       'SIS.Comunicado,SIS.Comunicado_Item'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_EMAILS'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_COMUNICADO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('ALTERAR'), ('ENVIAR'), ('APROVAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'SIS_COMUNICADO'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT 'COMUNICADO_PREVIA', N'Prévia dos comunicados semanais',
       N'Monta o comunicado da semana (boletim da implantação) e manda a prévia para aprovação. O envio oficial só sai depois de "Aprovar e enviar" na tela Comunicados.',
       N'SIS.SIS_Comunicado_Previa_Processar', m.ID_MODULO, 'SEMANAL', 0, '09:00', '6', 0, 30, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 1 ELSE 0 END,
       SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '09:00', '6', 0, SYSDATETIME()), N'instalacao'
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = 'COMUNICADO_PREVIA');
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comunicado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comunicado_Item', @Criar = 1;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/FIN/Carga_FIN_Auditoria_Triggers.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do FIN e do BANCO (03c)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de negócio da 03c. Não
                entram: Arquivo_Morto (só consulta, carga da migração) e as linhas
                do extrato (vêm do arquivo do banco). CAD.Empresa é regerada por
                causa da coluna nova PASTA_OFX.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Historico_Padrao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Mes_Fechado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Transferencia',    @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Movimento',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Lancamento',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Parcela',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Baixa',            @Criar = 1;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Backup.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga do backup do servidor
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Rotina BACKUP_CONFERIR (de hora em hora; avisa atraso de backup
                por e-mail): nasce ATIVA no servidor e DESLIGADA no banco de
                desenvolvimento (_LOCAL), onde o backup é outro (backup\ do
                notebook) e não se registra em SIS.Backup.
                Segurança: o login da API não pode registrar backup (DENY).
                Só insere o que falta (regra 39).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT 'BACKUP_CONFERIR', N'Conferir o backup',
       N'Avisa por e-mail (EMAIL_ADMIN_ALERTA) quando o backup completo, o do log ou o teste de restauração atrasam (parâmetros BACKUP_*_ALERTA_*).',
       N'SIS.SIS_Backup_Conferir_Processar', m.ID_MODULO, 'MINUTOS', 60, '00:00', '', 0, 10,
       CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 0 ELSE 1 END,
       SIS.fn_SIS_Rotina_Proxima('MINUTOS', 60, '00:00', '', 0, SYSDATETIME()), N'instalacao'
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = 'BACKUP_CONFERIR');
GO

IF DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NOT NULL
    DENY EXECUTE ON [SIS].[SIS_Backup_Registrar] TO [rl_sistemacmj_api];
GO
GO

-- =============================================================================
-- 9. (fim) FINALIZACAO DA INSTALACAO
-- =============================================================================
PRINT N'9. (fim) FINALIZACAO DA INSTALACAO';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Finalizar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : finalização da carga da base SIS
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Última instrução da instalação: acerta os módulos liberados
                pela licença ativa (módulo recém-instalado que já constava na
                licença passa a valer na hora). No MASTER fica no fim da
                parte 9 (parâmetros e carga inicial).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Licenca_Modulos_Aplicar @Usuario = N'instalacao';
GO
GO

-- =============================================================================
-- 9. (fim) REGISTRO DA VERSAO DO BANCO
-- =============================================================================
PRINT N'9. (fim) REGISTRO DA VERSAO DO BANCO';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/SIS/Carga_SIS_Versao.sql
-- -----------------------------------------------------------------------------
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
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '1.5';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO
GO

PRINT N'MASTER v1.5 concluido sem erro.';
GO

SET NOEXEC OFF;
GO
