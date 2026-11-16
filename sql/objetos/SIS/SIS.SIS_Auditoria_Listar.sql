/*******************************************************************************
  Objeto      : [SIS].[SIS_Auditoria_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela geral de consulta da auditoria (seção 3.7), com filtros:
                período (sem datas: últimos 7 dias), usuário (parte do login),
                tabela (parte do nome), registro, operação (I/A/E) e lote.
                @MaxLinhas: padrão 1000, máximo 10000.
                Permissão: SIS_AUDITORIA / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Auditoria_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Auditoria_Listar @IdUsuario = 2, @Tabela = N'Parametro', @Operacao = 'A';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Auditoria_Listar]
    @IdUsuario   INT,
    @DtInicio    DATE          = NULL,
    @DtFim       DATE          = NULL,
    @Usuario     NVARCHAR(100) = NULL,
    @Tabela      NVARCHAR(256) = NULL,
    @IdRegistro  BIGINT        = NULL,
    @Operacao    CHAR(1)       = NULL,
    @IdLote      BIGINT        = NULL,
    @MaxLinhas   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Auditoria_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_AUDITORIA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para consultar a auditoria.', 1;

        SET @DtFim     = ISNULL(@DtFim, CAST(SYSDATETIME() AS DATE));
        SET @DtInicio  = ISNULL(@DtInicio, DATEADD(DAY, -7, @DtFim));
        SET @Usuario   = NULLIF(LTRIM(RTRIM(@Usuario)), N'');
        SET @Tabela    = NULLIF(LTRIM(RTRIM(@Tabela)), N'');
        SET @Operacao  = NULLIF(UPPER(LTRIM(RTRIM(@Operacao))), '');
        SET @MaxLinhas = ISNULL(@MaxLinhas, 1000);
        IF @MaxLinhas < 1 SET @MaxLinhas = 1000;
        IF @MaxLinhas > 10000 SET @MaxLinhas = 10000;

        IF @DtInicio > @DtFim
            THROW 50001, N'A data inicial não pode ser maior que a data final.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               a.ID_AUDITORIA,
               a.DT_OPERACAO,
               a.TABELA,
               a.ID_REGISTRO,
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
        WHERE a.DT_OPERACAO >= @DtInicio
          AND a.DT_OPERACAO <  DATEADD(DAY, 1, @DtFim)
          AND (@Usuario    IS NULL OR a.USUARIO LIKE N'%' + @Usuario + N'%')
          AND (@Tabela     IS NULL OR a.TABELA  LIKE N'%' + @Tabela + N'%')
          AND (@IdRegistro IS NULL OR a.ID_REGISTRO = @IdRegistro)
          AND (@Operacao   IS NULL OR a.OPERACAO = @Operacao)
          AND (@IdLote     IS NULL OR a.ID_LOTE = @IdLote)
        ORDER BY a.ID_AUDITORIA DESC
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível consultar a auditoria. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
