/*******************************************************************************
  Objeto      : [SIS].[SIS_Perfil_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Lista de perfis: tela "Perfis e permissões" e a escolha do
                perfil na tela de usuários.
                Permissão: SIS_PERFIL / VER ou SIS_USUARIO / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: NIVEL_ADMIN no lugar de
                        ADMINISTRADOR; perfis de nível 2 só para o nível 2.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Perfil_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Perfil_Listar]
    @IdUsuario      INT,
    @SomenteAtivos  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Perfil_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Nivel      TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PERFIL', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os perfis.', 1;

        SET @SomenteAtivos = ISNULL(@SomenteAtivos, 0);

        SET @EtapaAtual = 'Consulta';
        SELECT p.ID_PERFIL,
               p.NOME,
               p.DESCRICAO,
               p.NIVEL_ADMIN,
               p.ATIVO,
               (SELECT COUNT(*) FROM SIS.Usuario u WITH (NOLOCK)
                WHERE u.ID_PERFIL = p.ID_PERFIL AND u.INTERNO = 0 AND u.ATIVO = 1)            AS QTD_USUARIOS_ATIVOS,
               (SELECT COUNT(*) FROM SIS.Perfil_Permissao pp WITH (NOLOCK)
                WHERE pp.ID_PERFIL = p.ID_PERFIL)                                               AS QTD_PERMISSOES
        FROM SIS.Perfil p WITH (NOLOCK)
        WHERE (@SomenteAtivos = 0 OR p.ATIVO = 1)
          AND (p.NIVEL_ADMIN < 2 OR @Nivel = 2)
        ORDER BY p.NIVEL_ADMIN DESC, p.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os perfis. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
