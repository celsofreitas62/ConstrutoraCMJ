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
