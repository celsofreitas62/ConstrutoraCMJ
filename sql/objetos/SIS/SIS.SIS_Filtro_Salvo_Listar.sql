/*******************************************************************************
  Objeto      : [SIS].[SIS_Filtro_Salvo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Filtros salvos do próprio usuário numa tela (@Item = código da
                tela em SIS.Item, ex.: FIN_RECEBER), o padrão primeiro e depois
                por nome. Permissão: VER na tela. Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Filtro_Salvo_Listar @IdUsuario = 2, @Item = 'FIN_RECEBER';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Filtro_Salvo_Listar]
    @IdUsuario  INT,
    @Item       VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Filtro_Salvo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        SET @Item = UPPER(LTRIM(RTRIM(ISNULL(@Item, ''))));
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver esta tela.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT f.ID_FILTRO_SALVO, f.NOME, f.FILTRO, f.PADRAO
        FROM SIS.Filtro_Salvo f
        WHERE f.ID_USUARIO = @IdUsuario
          AND f.ITEM = @Item
        ORDER BY f.PADRAO DESC, f.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os filtros salvos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
