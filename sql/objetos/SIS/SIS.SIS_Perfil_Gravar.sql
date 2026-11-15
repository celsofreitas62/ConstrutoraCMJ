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
