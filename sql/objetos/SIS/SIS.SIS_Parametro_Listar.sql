/*******************************************************************************
  Objeto      : [SIS].[SIS_Parametro_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Lista dos parâmetros para a tela do administrador, com o módulo
                de cada um. Filtros opcionais: módulo e texto (procura na chave
                e na descrição). Os não editáveis (EDITAVEL_ADMIN = 0) também
                aparecem, só para consulta.
                Padrão "Listar": THROW 50001 com mensagem amigável em erro.
                Permissão: SIS_PARAMETRO / VER.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: recebe @IdUsuario e confere a permissão
                        SIS_PARAMETRO / VER.
    v1.2 (25/11/2026) - Etapa 04f: @SoUso = 1 (tela "Parâmetros de uso"):
                        administrador (nível 1 ou 2) com VER em
                        SIS_PARAMETRO_USO vê só os de NIVEL_MINIMO 1. Sem
                        SIS_PARAMETRO (exclusivo do geral), também só os de uso.
                        Devolve NIVEL_MINIMO e OPCOES.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Parametro_Listar @IdUsuario = 2, @Texto = N'senha';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Listar]
    @IdUsuario INT,
    @IdModulo  INT            = NULL,
    @Texto     NVARCHAR(100)  = NULL,
    @SoUso     BIT            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Parametro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @VeTodos    BIT           = 0;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'VER') = 1 AND ISNULL(@SoUso, 0) = 0
            SET @VeTodos = 1;
        IF @VeTodos = 0
           AND (SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO_USO', 'VER') = 0 OR SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) < 1)
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os parâmetros.', 1;

        SET @EtapaAtual = 'Consulta';
        SET @Texto = NULLIF(LTRIM(RTRIM(@Texto)), N'');

        SELECT p.ID_PARAMETRO,
               p.CHAVE,
               p.VALOR,
               p.VALOR_PADRAO,
               p.TIPO,
               p.DESCRICAO,
               p.ID_MODULO,
               m.CODIGO                         AS MODULO_CODIGO,
               m.NOME                           AS MODULO_NOME,
               p.EDITAVEL_ADMIN,
               p.NIVEL_MINIMO,
               p.OPCOES,
               p.DT_ALTERACAO,
               ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM SIS.Parametro p WITH (NOLOCK)
        INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = p.ID_MODULO
        WHERE (@IdModulo IS NULL OR p.ID_MODULO = @IdModulo)
          AND (@VeTodos = 1 OR p.NIVEL_MINIMO = 1)
          AND (@Texto IS NULL OR p.CHAVE LIKE N'%' + @Texto + N'%' OR p.DESCRICAO LIKE N'%' + @Texto + N'%')
        ORDER BY m.ORDEM_MENU, p.CHAVE
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os parâmetros. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
