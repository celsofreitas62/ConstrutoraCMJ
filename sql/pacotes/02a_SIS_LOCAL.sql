/*******************************************************************************
  Pacote      : 02a - base SIS (schemas, logs, parâmetros, functions de formatação)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 15/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: sql/local/00_SISTEMACMJ_LOCAL_Criar_Banco.sql já rodado.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/02a_Homologacao_SIS.sql.
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
-- Arquivo: sql/objetos/_GERAL/Schemas.sql
-- =============================================================================
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
IF SCHEMA_ID(N'GER')   IS NULL EXEC (N'CREATE SCHEMA [GER] AUTHORIZATION [dbo];');
IF SCHEMA_ID(N'SIS')   IS NULL EXEC (N'CREATE SCHEMA [SIS] AUTHORIZATION [dbo];');
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

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Log_Erro.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Log_Passo.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Parametro.sql
-- =============================================================================
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
                  SN "S"/"N", EMAIL um endereço só; vazio = não configurado).
                - VALOR_PADRAO: valor de fábrica, para "restaurar padrão".
                - EDITAVEL_ADMIN = 0: só o instalador altera (por script).
                A auditoria (antes/depois) entra com a trigger da etapa 02c.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
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
        CONSTRAINT CK_Parametro_TIPO   CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'SN', 'EMAIL'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Parametro]') AND i.name = N'IX_Parametro_ID_MODULO')
    CREATE NONCLUSTERED INDEX IX_Parametro_ID_MODULO ON [SIS].[Parametro] (ID_MODULO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Usuario_Atual.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_Inteiro.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_Decimal.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_SN.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Texto_HTML.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Formatar_Moeda.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Formatar_Data.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Formatar_Data_Hora.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Mascarar_CPF_CNPJ.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Log_Erro_Gravar.sql
-- =============================================================================
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
                Conferência de permissão: entra na v1.1 (etapa 02b).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Log_Erro_Listar;
    -- EXEC SIS.SIS_Log_Erro_Listar @DtInicio = '2026-11-01', @DtFim = '2026-11-30', @Origem = 'API', @Texto = N'teste';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Log_Erro_Listar]
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
                Conferência de permissão: entra na v1.1 (etapa 02b).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Listar;
    -- EXEC SIS.SIS_Parametro_Listar @Texto = N'senha';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Listar]
    @IdModulo  INT            = NULL,
    @Texto     NVARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Parametro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Consulta';

    BEGIN TRY
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
                  TEXTO    livre (espaços das pontas removidos)
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_PARAMETRO.
                Antes/depois vai para SIS.Auditoria pela trigger (etapa 02c).
                Conferência de permissão: entra na v1.1 (etapa 02b).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Gravar @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'10', @Usuario = N'teste';
    -- EXEC SIS.SIS_Parametro_Gravar @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'8',  @Usuario = N'teste';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Gravar]
    @Chave    VARCHAR(60),
    @Valor    NVARCHAR(4000),
    @Usuario  NVARCHAR(100) = NULL
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

    BEGIN TRY
        SET @Usuario   = ISNULL(NULLIF(LTRIM(RTRIM(@Usuario)), N''), SIS.fn_SIS_Usuario_Atual());
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
-- Arquivo: sql/objetos/SIS/SIS.SIS_Log_Limpar_Processar.sql
-- =============================================================================
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
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Modulo (CODIGO, NOME, ORDEM_MENU, ICONE, LIBERADO_LICENCA)
SELECT v.CODIGO, v.NOME, v.ORDEM_MENU, '', v.LIBERADO_LICENCA
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
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO

PRINT N'Pacote 02a concluído sem erro.';
GO

SET NOEXEC OFF;
GO
