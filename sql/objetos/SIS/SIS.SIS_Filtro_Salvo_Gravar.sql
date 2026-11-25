/*******************************************************************************
  Objeto      : [SIS].[SIS_Filtro_Salvo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Salva um filtro da lista para o próprio usuário. Nome que já
                existe na mesma tela é substituído (salvar de novo atualiza).
                @Padrao = 1 marca como o filtro com que a lista abre e tira a
                marca dos outros da mesma tela. Limite de filtros por usuário
                e tela no parâmetro FILTRO_SALVO_MAX. Permissão: VER na tela.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_FILTRO_SALVO.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = 2, @Item = 'FIN_RECEBER', @Nome = N'Vencidos', @Filtro = N'{"situacao":"VENCIDA"}', @Padrao = 0;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Filtro_Salvo_Gravar]
    @IdUsuario  INT,
    @Item       VARCHAR(40),
    @Nome       NVARCHAR(60),
    @Filtro     NVARCHAR(MAX),
    @Padrao     BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Filtro_Salvo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Id         INT;
    DECLARE @Max        INT;
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Item   = UPPER(LTRIM(RTRIM(ISNULL(@Item, ''))));
        SET @Nome   = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Filtro = LTRIM(RTRIM(ISNULL(@Filtro, N'')));
        SET @Padrao = ISNULL(@Padrao, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para ver esta tela.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_FILTRO_SALVO;
            RETURN;
        END;
        IF @Nome = N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe um nome para o filtro.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_FILTRO_SALVO;
            RETURN;
        END;
        IF LEN(@Filtro) > 2000 OR ISJSON(@Filtro) = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Filtro inválido.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_FILTRO_SALVO;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Max     = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FILTRO_SALVO_MAX'), 20);

        SET @EtapaAtual = 'Limite';
        SELECT @Id = f.ID_FILTRO_SALVO
        FROM SIS.Filtro_Salvo f
        WHERE f.ID_USUARIO = @IdUsuario AND f.ITEM = @Item AND f.NOME = @Nome;

        IF @Id IS NULL AND (SELECT COUNT(*) FROM SIS.Filtro_Salvo f WHERE f.ID_USUARIO = @IdUsuario AND f.ITEM = @Item) >= @Max
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(N'Você já tem ' + CONVERT(NVARCHAR(10), @Max) + N' filtros salvos nesta tela. Apague um antes de salvar outro.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_FILTRO_SALVO;
            RETURN;
        END;

        -- preferência do próprio usuário (só ele grava): sem disputa entre sessões
        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF @Padrao = 1
                UPDATE f
                   SET f.PADRAO = 0, f.DT_ALTERACAO = SYSDATETIME(), f.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Filtro_Salvo f
                WHERE f.ID_USUARIO = @IdUsuario AND f.ITEM = @Item AND f.PADRAO = 1
                  AND (@Id IS NULL OR f.ID_FILTRO_SALVO <> @Id);

            IF @Id IS NULL
            BEGIN
                INSERT INTO SIS.Filtro_Salvo (ID_USUARIO, ITEM, NOME, FILTRO, PADRAO, USUARIO_CRIACAO)
                VALUES (@IdUsuario, @Item, @Nome, @Filtro, @Padrao, @Usuario);
                SET @Id = SCOPE_IDENTITY();
            END
            ELSE
                UPDATE f
                   SET f.FILTRO = @Filtro, f.PADRAO = @Padrao, f.DT_ALTERACAO = SYSDATETIME(), f.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Filtro_Salvo f
                WHERE f.ID_FILTRO_SALVO = @Id;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Filtro salvo.' AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID_FILTRO_SALVO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível salvar o filtro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_FILTRO_SALVO;
    END CATCH;
END;
GO
