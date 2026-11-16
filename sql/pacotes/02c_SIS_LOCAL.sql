/*******************************************************************************
  Pacote      : 02c - base SIS (habilitação de módulo e tela, contexto, auditoria, lote, anexo)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 16/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a, 02b e 02b2 já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/02c_Homologacao_SIS.sql e depois
                02b_Homologacao_SIS.sql (v1.2), para conferir que nada quebrou.
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
-- Arquivo: sql/objetos/SIS/SIS.Modulo.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Lote.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Anexo_Tipo.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Anexo.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Item_Tem_Tabela.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Contexto_Gravar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Trigger_Gerar.sql
-- =============================================================================
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
            + N'               (SELECT ' + @ListaJson + N' FROM inserted x WHERE x.' + QUOTENAME(@Pk) + N' = i.' + QUOTENAME(@Pk) + N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),' + @NL
            + N'               ' + @Contexto + @NL
            + N'        FROM inserted i' + @NL
            + N'        WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.' + QUOTENAME(@Pk) + N' = i.' + QUOTENAME(@Pk) + N');' + @NL + @NL
            + N'        -- Exclusão: foto do registro apagado' + @NL
            + N'        INSERT INTO SIS.Auditoria (TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, ID_USUARIO, ESTACAO, ORIGEM, ID_LOTE, TRANSACAO)' + @NL
            + N'        SELECT N''' + @NomeTabela + N''', d.' + QUOTENAME(@Pk) + N', ''E'', N'''',' + @NL
            + N'               (SELECT ' + @ListaJson + N' FROM deleted x WHERE x.' + QUOTENAME(@Pk) + N' = d.' + QUOTENAME(@Pk) + N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),' + @NL
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Registro_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lote_Gerar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lote_Concluir.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Lote_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Gravar.sql
-- =============================================================================
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
    DECLARE @ObjId       INT;
    DECLARE @Pk          SYSNAME;
    DECLARE @Sql         NVARCHAR(1000);
    DECLARE @Existe      INT           = 0;
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

        SET @ObjId = OBJECT_ID(@Tabela, N'U');
        SELECT @Pk = c.name
        FROM sys.indexes ix
        INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
        INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

        IF @Recusa = N'' AND (@ObjId IS NULL OR @Pk IS NULL)
            SET @Recusa = N'Registro não encontrado.';

        IF @Recusa = N''
        BEGIN
            SET @EtapaAtual = 'Registro de referência';
            SET @Sql = N'SELECT @Existe = 1 FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId))
                     + N' WHERE ' + QUOTENAME(@Pk) + N' = @Id;';
            EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Existe INT OUTPUT', @Id = @IdRegistro, @Existe = @Existe OUTPUT;
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Obter.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Anexo_Excluir.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Modulo_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Modulo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Módulos e telas" (exclusiva do administrador geral):
                módulos e telas com a situação de cada um.
                Uma linha por módulo (TIPO = 'MODULO') e por tela
                (TIPO = 'TELA'), já na ordem do menu:
                  NA_LICENCA : módulo liberado pela licença ativa;
                  HABILITADO : ligado pelo administrador geral;
                  EM_USO     : aparece para os usuários (licença + módulo
                               habilitado + tela habilitada);
                  PROTEGIDO  : não pode ser desligado (módulo SIS e a própria
                               tela "Módulos e telas").
                Permissão: SIS_MODULO / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c, pedido 5 do Celso).

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
        SELECT x.TIPO, x.CODIGO, x.NOME, x.MODULO_CODIGO, x.EXCLUSIVO_GERAL, x.NA_LICENCA, x.HABILITADO, x.EM_USO, x.PROTEGIDO
        FROM (
                SELECT CAST('MODULO' AS VARCHAR(10))                       AS TIPO,
                       CAST(m.CODIGO AS VARCHAR(40))                       AS CODIGO,
                       CAST(m.NOME AS NVARCHAR(400))                       AS NOME,
                       m.CODIGO                                            AS MODULO_CODIGO,
                       CAST(0 AS BIT)                                      AS EXCLUSIVO_GERAL,
                       m.LIBERADO_LICENCA                                  AS NA_LICENCA,
                       m.HABILITADO,
                       CAST(CASE WHEN m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END AS BIT) AS EM_USO,
                       CAST(CASE WHEN m.CODIGO = 'SIS' THEN 1 ELSE 0 END AS BIT) AS PROTEGIDO,
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10) AS VARCHAR(500)) AS ORDEM_GERAL
                FROM SIS.Modulo m WITH (NOLOCK)
                WHERE m.ATIVO = 1
                UNION ALL
                SELECT CAST('TELA' AS VARCHAR(10)),
                       CAST(i.CODIGO AS VARCHAR(40)),
                       ar.CAMINHO_NOME,
                       m.CODIGO,
                       i.EXCLUSIVO_GERAL,
                       m.LIBERADO_LICENCA,
                       i.HABILITADO,
                       CAST(CASE WHEN m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 AND i.HABILITADO = 1 THEN 1 ELSE 0 END AS BIT),
                       CAST(CASE WHEN i.CODIGO = 'SIS_MODULO' THEN 1 ELSE 0 END AS BIT),
                       CAST(RIGHT('00000' + CONVERT(VARCHAR(5), m.ORDEM_MENU), 5) + '.' + RIGHT('0000000000' + CONVERT(VARCHAR(10), m.ID_MODULO), 10)
                            + '|' + ar.ORDEM_CAMINHO AS VARCHAR(500))
                FROM Arvore ar
                INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.ID_ITEM   = ar.ID_ITEM AND i.TIPO = 'TELA'
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Habilitacao_Gravar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.tg_SIS_Auditoria_Protecao.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Modulo.sql
-- =============================================================================
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
        ('BANCO', N'Bancos',              50, 0),
        ('COBR',  N'Cobrança',            60, 0),
        ('OBRA',  N'Custos de obra',      70, 0),
        ('GER',   N'Painel e relatórios', 80, 0),
        ('SIS',   N'Sistema',             90, 1)
     ) v (CODIGO, NOME, ORDEM_MENU, LIBERADO_LICENCA)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Modulo m WHERE m.CODIGO = v.CODIGO);
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
        ('SIS', NULL,                'SIS_SEGURANCA',     N'Segurança',           'MENU', '',                     20, 0, 1, ''),
        ('SIS', 'SIS_SEGURANCA',     'SIS_USUARIO',       N'Usuários',            'TELA', 'sis/usuarios.html',    10, 0, 1, 'SIS.Usuario,SIS.Usuario_Permissao'),
        ('SIS', 'SIS_SEGURANCA',     'SIS_PERFIL',        N'Perfis e permissões', 'TELA', 'sis/perfis.html',      20, 0, 1, 'SIS.Perfil,SIS.Perfil_Permissao'),
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
        ('SIS_LOTE',      'EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Anexo_Tipo.sql
-- =============================================================================
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
GO

PRINT N'Pacote 02c concluído sem erro.';
GO

SET NOEXEC OFF;
GO
