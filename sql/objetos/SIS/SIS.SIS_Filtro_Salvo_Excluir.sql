/*******************************************************************************
  Objeto      : [SIS].[SIS_Filtro_Salvo_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Apaga um filtro salvo do próprio usuário (filtro de outro
                usuário não é encontrado). Preferência de uso: apaga de vez,
                sem lixeira. Devolve 1 linha: SUCESSO, MENSAGEM, ID_FILTRO_SALVO.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Filtro_Salvo_Excluir @IdUsuario = 2, @IdFiltroSalvo = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Filtro_Salvo_Excluir]
    @IdUsuario      INT,
    @IdFiltroSalvo  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Filtro_Salvo_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Exclusão';

    BEGIN TRY
        DELETE f
        FROM SIS.Filtro_Salvo f
        WHERE f.ID_FILTRO_SALVO = @IdFiltroSalvo
          AND f.ID_USUARIO = @IdUsuario;

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Filtro não encontrado.' AS NVARCHAR(400)) AS MENSAGEM, @IdFiltroSalvo AS ID_FILTRO_SALVO;
            RETURN;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Filtro apagado.' AS NVARCHAR(400)) AS MENSAGEM, @IdFiltroSalvo AS ID_FILTRO_SALVO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível apagar o filtro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdFiltroSalvo AS ID_FILTRO_SALVO;
    END CATCH;
END;
GO
