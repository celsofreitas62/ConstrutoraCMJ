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
