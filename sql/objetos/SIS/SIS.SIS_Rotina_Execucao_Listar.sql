/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Execucao_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico das execuções das rotinas automáticas (todas ou de
                uma rotina), mais recente primeiro, com a duração em
                segundos.
                Permissão: VER em SIS_ROTINA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Execucao_Listar @IdUsuario = 2, @Codigo = 'LOG_LIMPEZA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Execucao_Listar]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40) = NULL,
    @MaxLinhas  INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Execucao_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as rotinas automáticas.', 1;

        SET @Codigo    = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Codigo, '')))), '');
        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 5000 THEN 500 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               e.ID_EXECUCAO, r.CODIGO, r.NOME, e.ORIGEM, e.SOLICITANTE, e.SERVIDOR, e.DT_INICIO, e.DT_FIM,
               DATEDIFF(SECOND, e.DT_INICIO, ISNULL(e.DT_FIM, SYSDATETIME())) AS DURACAO_SEGUNDOS,
               e.RESULTADO, e.MENSAGEM
        FROM SIS.Rotina_Execucao e WITH (NOLOCK)
        INNER JOIN SIS.Rotina r ON r.ID_ROTINA = e.ID_ROTINA
        WHERE (@Codigo IS NULL OR r.CODIGO = @Codigo)
        ORDER BY e.ID_EXECUCAO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o histórico das rotinas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
