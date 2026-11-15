/*******************************************************************************
  Pacote      : 02b - base SIS (licença, usuários, perfis, permissões, sessão, menu, dois níveis de administrador)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 15/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacote 02a já rodado.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/02b_Homologacao_SIS.sql e depois
                sql/testes/SIS/02a_Homologacao_SIS.sql (v1.1).
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
-- Arquivo: sql/objetos/SIS/SIS.Licenca.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Licenca_Empresa.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Item.sql
-- =============================================================================
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
                Itens e ações são criados só por carga (script), nunca por tela.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - EXCLUSIVO_GERAL (dois níveis de administrador).
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

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Item]') AND i.name = N'IX_Item_ID_MODULO')
    CREATE NONCLUSTERED INDEX IX_Item_ID_MODULO ON [SIS].[Item] (ID_MODULO, ID_ITEM_PAI);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Acao.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Item_Acao.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Perfil.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Perfil_Permissao.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Usuario.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Usuario_Permissao.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Sessao.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Login_Log.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Login_Log]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Toda tentativa de login, certa ou errada (seção 3.6).
                RESULTADO: OK, SENHA_ERRADA, BLOQUEOU (errou e foi bloqueado
                nesta tentativa), BLOQUEADO (já estava), INATIVO, SEM_SENHA,
                INEXISTENTE. LOGIN_INFORMADO guarda o que foi digitado
                (para ver tentativas com nomes que não existem).
                Nunca é apagado.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
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
        CONSTRAINT CK_Login_Log_RESULTADO CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_DT_TENTATIVA')
    CREATE NONCLUSTERED INDEX IX_Login_Log_DT_TENTATIVA ON [SIS].[Login_Log] (DT_TENTATIVA) INCLUDE (ID_USUARIO, RESULTADO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.vw_SIS_Permissao_Efetiva.sql
-- =============================================================================
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
                ativo; tela, ação e módulo ativos; módulo liberado na licença.
                Fonte única de permissão: fn_SIS_Tem_Permissao e
                SIS_Menu_Listar leem daqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador (NIVEL_ADMIN, EXCLUSIVO_GERAL).

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
  AND (i.EXCLUSIVO_GERAL = 0 OR p.NIVEL_ADMIN = 2)
  AND (    p.NIVEL_ADMIN >= 1
       OR (    (   EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp
                           WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO)
                OR EXISTS (SELECT 1 FROM SIS.Usuario_Permissao up
                           WHERE up.ID_USUARIO = u.ID_USUARIO AND up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO AND up.TIPO = 'C'))
           AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao up
                           WHERE up.ID_USUARIO = u.ID_USUARIO AND up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO AND up.TIPO = 'R')));
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Usuario_Login.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Usuario_Nivel_Admin.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Tem_Permissao.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Empresa_Razao_Social.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Empresa_CNPJ.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Licenca_Modulos_Aplicar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Licenca_Gravar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Licenca_Obter.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Login_Obter.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Login_Processar.sql
-- =============================================================================
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
                  - senha certa: zera tentativas, abre a sessão.
                Toda tentativa vai para SIS.Login_Log.
                Recusa antes de gravar: COMMIT (nada foi alterado), para a
                procedure funcionar também dentro de INSERT ... EXEC.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO, ID_SESSAO,
                NOME, TROCAR_SENHA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

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

    BEGIN TRY
        SET @Login          = LOWER(LTRIM(RTRIM(ISNULL(@Login, N''))));
        SET @SenhaConferida = ISNULL(@SenhaConferida, 0);
        SET @Ip             = ISNULL(@Ip, '');
        SET @Estacao        = ISNULL(@Estacao, N'');
        SET @Navegador      = ISNULL(@Navegador, N'');
        SET @Limite         = SIS.fn_SIS_Parametro_Inteiro('SENHA_TENTATIVAS_BLOQUEIO');
        IF @Limite < 3 SET @Limite = 3;

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

            IF @IdUsuario IS NULL
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Sessao_Validar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Sessao_Encerrar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Obter.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Gravar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Senha_Gravar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Usuario_Desbloquear.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Perfil_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Perfil_Gravar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Permissao_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Permissao_Gravar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Menu_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Log_Erro_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Parametro_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Parametro_Gravar.sql
-- =============================================================================
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
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1)
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
        ('REDEFINIR_SENHA',  N'Definir senha provisória',   140)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
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

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - EXCLUSIVO_GERAL: Licença e Parâmetros só para o
                        administrador geral (acertado também em item já
                        existente, porque itens só mudam por carga).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaItem;

SELECT v.MODULO, v.PAI, v.CODIGO, v.NOME, v.TIPO, v.CAMINHO, v.ORDEM, v.EXCLUSIVO_GERAL
INTO #CargaItem
FROM (VALUES
        (CAST('SIS' AS VARCHAR(10)), CAST(NULL AS VARCHAR(40)), CAST('SIS_CONFIGURACAO' AS VARCHAR(40)), CAST(N'Configuração' AS NVARCHAR(80)), CAST('MENU' AS VARCHAR(10)), CAST('' AS VARCHAR(200)), CAST(10 AS SMALLINT), CAST(0 AS BIT)),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_LICENCA',       N'Licença',             'TELA', 'sis/licenca.html',     10, 1),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_PARAMETRO',     N'Parâmetros',          'TELA', 'sis/parametros.html',  20, 1),
        ('SIS', NULL,                'SIS_SEGURANCA',     N'Segurança',           'MENU', '',                     20, 0),
        ('SIS', 'SIS_SEGURANCA',     'SIS_USUARIO',       N'Usuários',            'TELA', 'sis/usuarios.html',    10, 0),
        ('SIS', 'SIS_SEGURANCA',     'SIS_PERFIL',        N'Perfis e permissões', 'TELA', 'sis/perfis.html',      20, 0),
        ('SIS', NULL,                'SIS_MONITORAMENTO', N'Monitoramento',       'MENU', '',                     30, 0),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOG_ERRO',      N'Log de erros',        'TELA', 'sis/log-erros.html',   10, 0)
     ) v (MODULO, PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL);

DECLARE @Passada INT = 1;
WHILE @Passada <= 5
BEGIN
    INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL)
    SELECT m.ID_MODULO, pai.ID_ITEM, c.CODIGO, c.NOME, c.TIPO, c.CAMINHO, c.ORDEM, c.EXCLUSIVO_GERAL
    FROM #CargaItem c
    INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
    LEFT  JOIN SIS.Item pai ON pai.CODIGO = c.PAI
    WHERE (c.PAI IS NULL OR pai.ID_ITEM IS NOT NULL)
      AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = c.CODIGO);

    SET @Passada = @Passada + 1;
END;

UPDATE i
   SET i.EXCLUSIVO_GERAL   = c.EXCLUSIVO_GERAL,
       i.DT_ALTERACAO      = SYSDATETIME(),
       i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
INNER JOIN #CargaItem c ON c.CODIGO = i.CODIGO
WHERE i.EXCLUSIVO_GERAL <> c.EXCLUSIVO_GERAL;

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
        ('SIS_LOG_ERRO',  'EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Perfil_Usuario.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Finalizar.sql
-- =============================================================================
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

PRINT N'Pacote 02b concluído sem erro.';
GO

SET NOEXEC OFF;
GO
