/*******************************************************************************
  Objeto      : [SIS].[SIS_Permissao_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Grava de uma vez (tudo-ou-nada) as marcações da grade de
                permissões, de um perfil OU de um usuário.
                @ListaJson: [{"id_item_acao": 12, "valor": "S"}, ...]
                  perfil  : valor "S" (permite) ou "N" (tira);
                  usuário : valor "C" (concede), "R" (retira) ou "" (volta ao
                            que o perfil diz).
                Exceção de usuário que não muda nada (conceder o que o perfil
                já dá, retirar o que ele não dá) não é gravada.
                Recusas: perfil de administrador (nível 1 ou 2, já tem tudo);
                retirar permissão de usuário administrador; tela exclusiva do
                administrador geral; perfil/usuário de nível 2 para quem não
                é nível 2.
                Permissão: SIS_PERFIL / ALTERAR ou SIS_USUARIO / ALTERAR.
                Devolve 1 linha: SUCESSO, MENSAGEM, QTD_ALTERADA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: recusa perfis de nível 1 e
                        2, tela EXCLUSIVO_GERAL e alvo de nível 2 para quem não
                        é nível 2.

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Permissao_Gravar]
    @IdUsuario      INT,
    @IdPerfil       INT            = NULL,
    @IdUsuarioAlvo  INT            = NULL,
    @ListaJson      NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[SIS].[SIS_Permissao_Gravar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Validação';
    DECLARE @Recusa        NVARCHAR(400) = N'';
    DECLARE @Usuario       NVARCHAR(100);
    DECLARE @ModoPerfil    BIT           = CASE WHEN @IdPerfil IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @IdPerfilBase  INT;
    DECLARE @NivelPerfil   TINYINT;
    DECLARE @Nivel         TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);
    DECLARE @Qtd           INT           = 0;

    DROP TABLE IF EXISTS #Lista;

    BEGIN TRY
        IF (@IdPerfil IS NULL AND @IdUsuarioAlvo IS NULL) OR (@IdPerfil IS NOT NULL AND @IdUsuarioAlvo IS NOT NULL)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe o perfil ou o usuário (só um dos dois).' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_ALTERADA;
            RETURN;
        END;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE WHEN @ModoPerfil = 1 THEN 'SIS_PERFIL' ELSE 'SIS_USUARIO' END, 'ALTERAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para alterar permissões.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_ALTERADA;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        IF @ModoPerfil = 1
            SET @IdPerfilBase = @IdPerfil;
        IF @ModoPerfil = 0
            SELECT @IdPerfilBase = u.ID_PERFIL FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdUsuarioAlvo AND u.INTERNO = 0;

        SELECT @NivelPerfil = p.NIVEL_ADMIN FROM SIS.Perfil p WHERE p.ID_PERFIL = @IdPerfilBase;

        IF @NivelPerfil IS NULL OR (@NivelPerfil = 2 AND @Nivel < 2)
            SET @Recusa = N'Perfil ou usuário não encontrado.';
        IF @Recusa = N'' AND @ModoPerfil = 1 AND @NivelPerfil >= 1
            SET @Recusa = N'Perfil de administrador já tem todas as permissões.';
        IF @Recusa = N'' AND ISJSON(ISNULL(@ListaJson, N'')) = 0
            SET @Recusa = N'Lista de permissões inválida.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_ALTERADA;
            RETURN;
        END;

        SET @EtapaAtual = 'Leitura da lista';
        SELECT j.id_item_acao                              AS ID_ITEM_ACAO,
               UPPER(LTRIM(RTRIM(ISNULL(j.valor, ''))))    AS VALOR,
               CAST(0 AS BIT)                              AS NO_PERFIL,
               CAST('' AS CHAR(1))                         AS FINAL
        INTO #Lista
        FROM OPENJSON(@ListaJson)
             WITH (id_item_acao INT        '$.id_item_acao',
                   valor        VARCHAR(5) '$.valor') j;

        IF NOT EXISTS (SELECT 1 FROM #Lista)
            SET @Recusa = N'Nenhuma permissão informada.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Lista l
                                     WHERE l.ID_ITEM_ACAO IS NULL
                                        OR NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM_ACAO = l.ID_ITEM_ACAO AND ia.ATIVO = 1))
            SET @Recusa = N'A lista tem permissão inexistente.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Lista l
                                     INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = l.ID_ITEM_ACAO
                                     INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM
                                     WHERE i.EXCLUSIVO_GERAL = 1)
            SET @Recusa = N'A lista tem tela exclusiva do administrador geral (não pode ser dada a ninguém).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Lista l GROUP BY l.ID_ITEM_ACAO HAVING COUNT(*) > 1)
            SET @Recusa = N'A lista repete a mesma permissão.';
        IF @Recusa = N'' AND @ModoPerfil = 1 AND EXISTS (SELECT 1 FROM #Lista l WHERE l.VALOR NOT IN ('S', 'N'))
            SET @Recusa = N'Valor inválido na lista (use S ou N).';
        IF @Recusa = N'' AND @ModoPerfil = 0 AND EXISTS (SELECT 1 FROM #Lista l WHERE l.VALOR NOT IN ('C', 'R', ''))
            SET @Recusa = N'Valor inválido na lista (use C, R ou vazio).';
        IF @Recusa = N'' AND @ModoPerfil = 0 AND @NivelPerfil >= 1 AND EXISTS (SELECT 1 FROM #Lista l WHERE l.VALOR = 'R')
            SET @Recusa = N'Usuário administrador tem todas as permissões: não é possível retirar.';

        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Lista;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_ALTERADA;
            RETURN;
        END;

        IF @ModoPerfil = 0
        BEGIN
            UPDATE l
               SET l.NO_PERFIL = CASE WHEN EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp
                                                   WHERE pp.ID_PERFIL = @IdPerfilBase AND pp.ID_ITEM_ACAO = l.ID_ITEM_ACAO)
                                      THEN 1 ELSE 0 END
            FROM #Lista l;

            UPDATE l
               SET l.FINAL = CASE WHEN @NivelPerfil = 0 AND l.VALOR = 'C' AND l.NO_PERFIL = 0 THEN 'C'
                                  WHEN @NivelPerfil = 0 AND l.VALOR = 'R' AND l.NO_PERFIL = 1 THEN 'R'
                                  ELSE '' END
            FROM #Lista l;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF @ModoPerfil = 1
            BEGIN
                INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
                SELECT @IdPerfil, l.ID_ITEM_ACAO, ISNULL(@Usuario, N'')
                FROM #Lista l
                WHERE l.VALOR = 'S'
                  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WITH (UPDLOCK, HOLDLOCK)
                                  WHERE pp.ID_PERFIL = @IdPerfil AND pp.ID_ITEM_ACAO = l.ID_ITEM_ACAO);
                SET @Qtd = @Qtd + @@ROWCOUNT;

                DELETE pp
                FROM SIS.Perfil_Permissao pp
                INNER JOIN #Lista l ON l.ID_ITEM_ACAO = pp.ID_ITEM_ACAO
                WHERE pp.ID_PERFIL = @IdPerfil
                  AND l.VALOR = 'N';
                SET @Qtd = @Qtd + @@ROWCOUNT;

                UPDATE p SET p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Perfil p
                WHERE p.ID_PERFIL = @IdPerfil AND @Qtd > 0;
            END;

            IF @ModoPerfil = 0
            BEGIN
                DELETE up
                FROM SIS.Usuario_Permissao up
                INNER JOIN #Lista l ON l.ID_ITEM_ACAO = up.ID_ITEM_ACAO
                WHERE up.ID_USUARIO = @IdUsuarioAlvo
                  AND l.FINAL = '';
                SET @Qtd = @Qtd + @@ROWCOUNT;

                UPDATE up
                   SET up.TIPO              = l.FINAL,
                       up.DT_ALTERACAO      = SYSDATETIME(),
                       up.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Usuario_Permissao up
                INNER JOIN #Lista l ON l.ID_ITEM_ACAO = up.ID_ITEM_ACAO
                WHERE up.ID_USUARIO = @IdUsuarioAlvo
                  AND l.FINAL <> ''
                  AND up.TIPO <> l.FINAL;
                SET @Qtd = @Qtd + @@ROWCOUNT;

                INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
                SELECT @IdUsuarioAlvo, l.ID_ITEM_ACAO, l.FINAL, ISNULL(@Usuario, N'')
                FROM #Lista l
                WHERE l.FINAL <> ''
                  AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao up WITH (UPDLOCK, HOLDLOCK)
                                  WHERE up.ID_USUARIO = @IdUsuarioAlvo AND up.ID_ITEM_ACAO = l.ID_ITEM_ACAO);
                SET @Qtd = @Qtd + @@ROWCOUNT;
            END;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Lista;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Qtd = 0 THEN N'Nenhuma alteração.' ELSE N'Permissões gravadas.' END AS NVARCHAR(400)) AS MENSAGEM,
               @Qtd AS QTD_ALTERADA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Lista;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar as permissões. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(0 AS INT) AS QTD_ALTERADA;
    END CATCH;
END;
GO
