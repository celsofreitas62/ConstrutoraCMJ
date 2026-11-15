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
