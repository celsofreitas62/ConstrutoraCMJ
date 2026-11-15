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
