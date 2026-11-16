/*******************************************************************************
  Objeto      : [SIS].[SIS_Auditoria_Registro_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Aba "Histórico" de toda tela de manutenção (seção 3.7): quem
                incluiu, alterou ou excluiu aquele registro, quando, de onde e
                o valor antes e depois. Mais recente primeiro.
                @Item   : código da tela que está pedindo (ex.: SIS_USUARIO)
                @Tabela : 'SCHEMA.Tabela' do registro (precisa estar em
                          TABELAS_DA_TELA da tela)
                Permissão: VER na tela informada.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Auditoria_Registro_Listar @IdUsuario = 2, @Item = 'SIS_PARAMETRO', @Tabela = N'SIS.Parametro', @IdRegistro = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Auditoria_Registro_Listar]
    @IdUsuario   INT,
    @Item        VARCHAR(40),
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Auditoria_Registro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver este histórico.', 1;

        IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            THROW 50001, N'Esta tela não mostra histórico desse tipo de registro.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT a.ID_AUDITORIA,
               a.DT_OPERACAO,
               a.OPERACAO,
               CAST(CASE a.OPERACAO WHEN 'I' THEN N'Inclusão' WHEN 'A' THEN N'Alteração' ELSE N'Exclusão' END AS NVARCHAR(20)) AS OPERACAO_NOME,
               a.CAMPO,
               ISNULL(CAST(a.VALOR_ANTES  AS NVARCHAR(4000)), N'') AS VALOR_ANTES,
               ISNULL(CAST(a.VALOR_DEPOIS AS NVARCHAR(4000)), N'') AS VALOR_DEPOIS,
               a.USUARIO,
               a.ESTACAO,
               a.ORIGEM,
               a.ID_LOTE
        FROM SIS.Auditoria a WITH (NOLOCK)
        WHERE a.TABELA = @Tabela
          AND a.ID_REGISTRO = @IdRegistro
        ORDER BY a.ID_AUDITORIA DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o histórico. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
