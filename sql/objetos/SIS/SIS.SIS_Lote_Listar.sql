/*******************************************************************************
  Objeto      : [SIS].[SIS_Lote_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Lotes": lotes gerados, com filtros por período (sem
                datas: últimos 30 dias), origem e número. Informando @IdLote,
                traz só aquele lote (qualquer data).
                Os registros de cada lote são listados pela tela do módulo
                dono deles (ex.: lançamentos do lote, pedido 9, fase 6).
                @MaxLinhas: padrão 500, máximo 5000.
                Permissão: SIS_LOTE / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lote_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lote_Listar]
    @IdUsuario  INT,
    @DtInicio   DATE         = NULL,
    @DtFim      DATE         = NULL,
    @Origem     VARCHAR(30)  = NULL,
    @IdLote     BIGINT       = NULL,
    @MaxLinhas  INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lote_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LOTE', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os lotes.', 1;

        SET @DtFim     = ISNULL(@DtFim, CAST(SYSDATETIME() AS DATE));
        SET @DtInicio  = ISNULL(@DtInicio, DATEADD(DAY, -30, @DtFim));
        SET @Origem    = NULLIF(UPPER(LTRIM(RTRIM(@Origem))), '');
        SET @MaxLinhas = ISNULL(@MaxLinhas, 500);
        IF @MaxLinhas < 1 SET @MaxLinhas = 500;
        IF @MaxLinhas > 5000 SET @MaxLinhas = 5000;

        IF @IdLote IS NULL AND @DtInicio > @DtFim
            THROW 50001, N'A data inicial não pode ser maior que a data final.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               l.ID_LOTE,
               l.ORIGEM,
               l.DESCRICAO,
               l.TABELA_REFERENCIA,
               l.ID_REFERENCIA,
               l.QTD_REGISTROS,
               l.SITUACAO,
               l.DT_CRIACAO,
               l.USUARIO_CRIACAO
        FROM SIS.Lote l WITH (NOLOCK)
        WHERE (@IdLote IS NOT NULL AND l.ID_LOTE = @IdLote)
           OR (@IdLote IS NULL
               AND l.DT_CRIACAO >= @DtInicio
               AND l.DT_CRIACAO <  DATEADD(DAY, 1, @DtFim)
               AND (@Origem IS NULL OR l.ORIGEM = @Origem))
        ORDER BY l.ID_LOTE DESC
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os lotes. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
