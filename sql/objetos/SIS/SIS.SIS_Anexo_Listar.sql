/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Anexos de um registro (aba "Anexos" das telas), mais recente
                primeiro. @IncluirExcluidos = 1 mostra também os excluídos
                (com quem excluiu, quando e o motivo).
                Permissão: VER na tela (@Item), que precisa manter a tabela.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (25/11/2026) - Etapa 04d (P12): DT_VALIDADE e VENCIDO (validade antes de hoje).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Anexo_Listar @IdUsuario = 2, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = 3;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Listar]
    @IdUsuario         INT,
    @Item              VARCHAR(40),
    @Tabela            NVARCHAR(256),
    @IdRegistro        BIGINT,
    @IncluirExcluidos  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Anexo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver estes anexos.', 1;
        IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            THROW 50001, N'Esta tela não mostra anexos desse tipo de registro.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT a.ID_ANEXO,
               t.CODIGO                              AS TIPO_CODIGO,
               t.NOME                                AS TIPO_NOME,
               a.NOME_ORIGINAL,
               a.EXTENSAO,
               a.TAMANHO_BYTES,
               a.DESCRICAO,
               a.DT_VALIDADE,
               CAST(CASE WHEN a.DT_VALIDADE < CONVERT(DATE, SYSDATETIME()) THEN 1 ELSE 0 END AS BIT) AS VENCIDO,
               a.SITUACAO,
               a.DT_CRIACAO,
               a.USUARIO_CRIACAO,
               a.DT_EXCLUSAO,
               ISNULL(a.USUARIO_EXCLUSAO, N'')       AS USUARIO_EXCLUSAO,
               ISNULL(a.MOTIVO_EXCLUSAO, N'')        AS MOTIVO_EXCLUSAO
        FROM SIS.Anexo a WITH (NOLOCK)
        INNER JOIN SIS.Anexo_Tipo t WITH (NOLOCK) ON t.ID_ANEXO_TIPO = a.ID_ANEXO_TIPO
        WHERE a.TABELA_REFERENCIA = @Tabela
          AND a.ID_REFERENCIA = @IdRegistro
          AND (ISNULL(@IncluirExcluidos, 0) = 1 OR a.SITUACAO = 'ATIVO')
        ORDER BY a.ID_ANEXO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os anexos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
