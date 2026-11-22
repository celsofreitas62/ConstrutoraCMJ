/*******************************************************************************
  Pacote      : 04a - telas de Usuarios e Perfis (senha provisoria que vence, perfis de fabrica Financeiro e Consulta); banco 1.9
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 22/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 03h já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/04a_Homologacao_Usuarios.sql e 02b_Homologacao_SIS.sql.
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
                INEXISTENTE, ESTACAO_BLOQUEADA (o computador errou demais
                em pouco tempo e está em espera), PROVISORIA_VENCIDA (senha
                provisória certa, mas passou de SENHA_PROVISORIA_HORAS). LOGIN_INFORMADO guarda o que foi digitado
                (para ver tentativas com nomes que não existem).
                Nunca é apagado.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (20/11/2026) - Etapa 03d: resultado ESTACAO_BLOQUEADA (limite de
                        tentativas por computador) e índice por IP e data.
    v1.2 (22/11/2026) - Etapa 04a: resultado PROVISORIA_VENCIDA.
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
        CONSTRAINT CK_Login_Log_RESULTADO CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE', 'ESTACAO_BLOQUEADA', 'PROVISORIA_VENCIDA'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_DT_TENTATIVA')
    CREATE NONCLUSTERED INDEX IX_Login_Log_DT_TENTATIVA ON [SIS].[Login_Log] (DT_TENTATIVA) INCLUDE (ID_USUARIO, RESULTADO);
GO

-- v1.1/v1.2: resultados ESTACAO_BLOQUEADA e PROVISORIA_VENCIDA (troca a restrição só se ainda não aceita)
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints c
               WHERE c.name = N'CK_Login_Log_RESULTADO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Login_Log]')
                 AND c.definition LIKE N'%PROVISORIA_VENCIDA%')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.check_constraints c WHERE c.name = N'CK_Login_Log_RESULTADO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Login_Log]'))
        ALTER TABLE [SIS].[Login_Log] DROP CONSTRAINT CK_Login_Log_RESULTADO;
    ALTER TABLE [SIS].[Login_Log] ADD CONSTRAINT CK_Login_Log_RESULTADO
        CHECK (RESULTADO IN ('OK', 'SENHA_ERRADA', 'BLOQUEOU', 'BLOQUEADO', 'INATIVO', 'SEM_SENHA', 'INEXISTENTE', 'ESTACAO_BLOQUEADA', 'PROVISORIA_VENCIDA'));
END;
GO

-- v1.1: contagem de tentativas erradas por computador (SIS_Usuario_Login_Processar)
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Login_Log]') AND i.name = N'IX_Login_Log_IP_DT')
    CREATE NONCLUSTERED INDEX IX_Login_Log_IP_DT ON [SIS].[Login_Log] (IP, DT_TENTATIVA) INCLUDE (RESULTADO);
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
                  - senha certa: zera tentativas, abre a sessão;
                  - computador (IP) com LOGIN_COMPUTADOR_TENTATIVAS erros
                    seguidos (qualquer usuário, inclusive inexistente) nos
                    últimos LOGIN_COMPUTADOR_MINUTOS: recusa sem olhar a
                    senha nem contar tentativa no usuário (ESTACAO_BLOQUEADA),
                    até passar o tempo. Um login certo zera a contagem;
                  - senha provisória (TROCAR_SENHA = 1) certa, mas dada há
                    mais de SENHA_PROVISORIA_HORAS (0 = não vence): recusa
                    (PROVISORIA_VENCIDA) e pede para o administrador reiniciar
                    a senha. Não vale para o administrador geral (nível 2),
                    para ele nunca ficar sem entrar.
                Toda tentativa vai para SIS.Login_Log.
                Recusa antes de gravar: COMMIT (nada foi alterado), para a
                procedure funcionar também dentro de INSERT ... EXEC.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO, ID_SESSAO,
                NOME, TROCAR_SENHA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (20/11/2026) - Etapa 03d: limite de tentativas por computador.
    v1.2 (22/11/2026) - Etapa 04a: senha provisória vence (SENHA_PROVISORIA_HORAS).

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
    DECLARE @DtSenha      DATETIME2(0);
    DECLARE @NivelAdmin   TINYINT       = 0;
    DECLARE @HorasProv    INT;

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
        SET @HorasProv      = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SENHA_PROVISORIA_HORAS'), 24);

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
                   @TrocarSenha = u.TROCAR_SENHA,
                   @DtSenha     = u.DT_SENHA,
                   @NivelAdmin  = p.NIVEL_ADMIN
            FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
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

            IF @Resultado = '' AND @TrocarSenha = 1 AND ISNULL(@NivelAdmin, 0) < 2 AND @HorasProv > 0
               AND @DtSenha < DATEADD(HOUR, -@HorasProv, SYSDATETIME())
            BEGIN
                SET @Resultado = 'PROVISORIA_VENCIDA';
                SET @Mensagem  = N'A sua senha provisória venceu (vale ' + CONVERT(NVARCHAR(10), @HorasProv) + N' horas). Peça ao administrador do sistema para reiniciar a sua senha.';
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
    v1.2 (22/11/2026) - Etapa 04a (tela de Usuários): SENHA_PROVISORIA_VENCIDA e
                        DT_SENHA.

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
    DECLARE @HorasProv  INT           = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SENHA_PROVISORIA_HORAS'), 24);

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
               CAST(CASE WHEN u.SENHA_HASH IS NOT NULL AND u.TROCAR_SENHA = 1 AND p.NIVEL_ADMIN < 2 AND @HorasProv > 0
                          AND u.DT_SENHA < DATEADD(HOUR, -@HorasProv, SYSDATETIME()) THEN 1 ELSE 0 END AS BIT) AS SENHA_PROVISORIA_VENCIDA,
               u.DT_SENHA,
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
    v1.2 (22/11/2026) - Etapa 04a (tela de Usuários): SENHA_PROVISORIA_VENCIDA e
                        QTD_EXCECOES.

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
    DECLARE @HorasProv  INT           = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SENHA_PROVISORIA_HORAS'), 24);

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
               CAST(CASE WHEN u.SENHA_HASH IS NOT NULL AND u.TROCAR_SENHA = 1 AND p.NIVEL_ADMIN < 2 AND @HorasProv > 0
                          AND u.DT_SENHA < DATEADD(HOUR, -@HorasProv, SYSDATETIME()) THEN 1 ELSE 0 END AS BIT) AS SENHA_PROVISORIA_VENCIDA,
               u.DT_SENHA,
               u.DT_ULTIMO_LOGIN,
               u.DT_CRIACAO,
               u.USUARIO_CRIACAO,
               u.DT_ALTERACAO,
               ISNULL(u.USUARIO_ALTERACAO, N'')                      AS USUARIO_ALTERACAO,
               (SELECT COUNT(*) FROM SIS.Usuario_Permissao up WITH (NOLOCK) WHERE up.ID_USUARIO = u.ID_USUARIO) AS QTD_EXCECOES
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
         N'Horas que a senha provisória vale. Passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar a senha de novo. 0 = não vence. Não vale para o administrador geral.', 'SIS', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
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
       OR (n.NOME = N'Financeiro' AND m.CODIGO IN ('CAD', 'FIN', 'BANCO', 'COBR') AND a.CODIGO <> 'REABRIR')
       OR (n.NOME = N'Financeiro' AND m.CODIGO NOT IN ('CAD', 'FIN', 'BANCO', 'COBR') AND a.CODIGO = 'VER'))
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = n.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);
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
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '1.9';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO

PRINT N'Pacote 04a concluído sem erro.';
GO

SET NOEXEC OFF;
GO
