/*******************************************************************************
  Objeto      : [SIS].[SIS_Preferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Preferências do usuário logado (tela Preferências e abertura
                da tela inicial; P03 e P06): uma linha por preferência ativa
                do catálogo, com o padrão (valor do parâmetro da preferência),
                o que o usuário escolheu e o valor que vale (VALOR = escolha
                do usuário, senão o padrão). Qualquer usuário ativo vê as
                próprias; ninguém vê as de outro. @Grupo filtra pelo GRUPO.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Preferencia_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Preferencia_Listar]
    @IdUsuario  INT,
    @Grupo      NVARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Preferencia_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Usuário';

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
            THROW 50001, N'Usuário não encontrado ou desativado.', 1;

        SET @Grupo = NULLIF(LTRIM(RTRIM(ISNULL(@Grupo, N''))), N'');

        SET @EtapaAtual = 'Consulta';
        SELECT p.CODIGO,
               p.NOME,
               p.DESCRICAO,
               p.GRUPO,
               p.TIPO,
               p.OPCOES,
               ISNULL(p.VALOR_MINIMO, 0)                                          AS VALOR_MINIMO,
               ISNULL(p.VALOR_MAXIMO, 0)                                          AS VALOR_MAXIMO,
               CAST(ISNULL(pa.VALOR, N'') AS NVARCHAR(400))                       AS VALOR_PADRAO,
               CAST(ISNULL(up.VALOR, N'') AS NVARCHAR(400))                       AS VALOR_USUARIO,
               CAST(ISNULL(up.VALOR, ISNULL(pa.VALOR, N'')) AS NVARCHAR(400))     AS VALOR,
               CAST(CASE WHEN up.ID_USUARIO_PREFERENCIA IS NULL THEN 0 ELSE 1 END AS BIT) AS PERSONALIZADA,
               p.ORDEM
        FROM SIS.Preferencia p WITH (NOLOCK)
        LEFT JOIN SIS.Parametro pa WITH (NOLOCK) ON pa.CHAVE = p.CHAVE_PARAMETRO
        LEFT JOIN SIS.Usuario_Preferencia up WITH (NOLOCK) ON up.ID_PREFERENCIA = p.ID_PREFERENCIA AND up.ID_USUARIO = @IdUsuario
        WHERE p.ATIVO = 1
          AND (@Grupo IS NULL OR p.GRUPO = @Grupo)
        ORDER BY p.GRUPO, p.ORDEM, p.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as preferências. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
