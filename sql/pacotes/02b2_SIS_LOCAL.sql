/*******************************************************************************
  Pacote      : 02b2 - ajuste da base SIS: identidade visual por cliente (logomarcas e cores) e correção de nomes com "_"
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 15/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a e 02b já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/02b2_Homologacao_SIS.sql.
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
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_Cor.sql
-- =============================================================================
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

PRINT N'Pacote 02b2 concluído sem erro.';
GO

SET NOEXEC OFF;
GO
