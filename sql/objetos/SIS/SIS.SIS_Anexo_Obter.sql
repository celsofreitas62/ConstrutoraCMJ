/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Dados para a API entregar o arquivo de um anexo (download):
                caminho completo (ANEXO_PASTA_RAIZ + PASTA_RELATIVA +
                NOME_ARQUIVO), nome original e hash para conferir o arquivo.
                Só anexo ativo, de tabela mantida pela tela (@Item).
                Permissão: VER na tela.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Anexo_Obter @IdUsuario = 2, @Item = 'SIS_USUARIO', @IdAnexo = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Obter]
    @IdUsuario  INT,
    @Item       VARCHAR(40),
    @IdAnexo    BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Anexo_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Tabela     NVARCHAR(256);
    DECLARE @Raiz       NVARCHAR(4000);

    BEGIN TRY
        SELECT @Tabela = a.TABELA_REFERENCIA
        FROM SIS.Anexo a WITH (NOLOCK)
        WHERE a.ID_ANEXO = @IdAnexo AND a.SITUACAO = 'ATIVO';

        IF @Tabela IS NULL
            THROW 50001, N'Anexo não encontrado.', 1;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0 OR SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            THROW 50001, N'Você não tem permissão para abrir este anexo.', 1;

        SET @Raiz = SIS.fn_SIS_Parametro('ANEXO_PASTA_RAIZ');
        IF RIGHT(@Raiz, 1) <> N'\' SET @Raiz = @Raiz + N'\';

        SET @EtapaAtual = 'Consulta';
        SELECT a.ID_ANEXO,
               a.NOME_ORIGINAL,
               a.EXTENSAO,
               a.TAMANHO_BYTES,
               a.HASH_SHA256,
               CAST(@Raiz + CASE WHEN a.PASTA_RELATIVA = '' THEN N'' ELSE CONVERT(NVARCHAR(50), a.PASTA_RELATIVA) + N'\' END
                    + CONVERT(NVARCHAR(100), a.NOME_ARQUIVO) AS NVARCHAR(4000)) AS CAMINHO_COMPLETO
        FROM SIS.Anexo a WITH (NOLOCK)
        WHERE a.ID_ANEXO = @IdAnexo;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível abrir o anexo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
