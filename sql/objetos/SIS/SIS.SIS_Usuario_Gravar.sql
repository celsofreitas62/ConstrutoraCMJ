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

        IF LEN(@Login) < 3 OR @Login LIKE '%[^a-z0-9._-]%' COLLATE Latin1_General_BIN2
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
