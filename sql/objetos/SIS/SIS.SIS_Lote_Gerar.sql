/*******************************************************************************
  Objeto      : [SIS].[SIS_Lote_Gerar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Abre um lote para um processo que vai gerar vários registros
                juntos e devolve o número em @IdLote (OUTPUT). Uso interno:
                chamada pelas procedures de negócio (gerar parcelas, processar
                retorno, aprovar medição...), dentro da transação delas
                (o INSERT é atômico; se o processo desfizer, o lote some junto).
                @DefinirContexto = 1 (padrão) grava o lote no SESSION_CONTEXT,
                e a auditoria de tudo que for gravado em seguida leva o número
                do lote. No fim, o processo chama SIS_Lote_Concluir.
                Recusa (origem inválida): THROW 50001, para o processo que
                chamou desfazer tudo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- DECLARE @L BIGINT; EXEC SIS.SIS_Lote_Gerar @IdUsuario = 1, @Origem = 'TESTE', @Descricao = N'Teste', @IdLote = @L OUTPUT; SELECT @L;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lote_Gerar]
    @IdUsuario         INT,
    @Origem            VARCHAR(30),
    @Descricao         NVARCHAR(400) = NULL,
    @TabelaReferencia  NVARCHAR(256) = NULL,
    @IdReferencia      BIGINT        = NULL,
    @DefinirContexto   BIT           = 1,
    @IdLote            BIGINT        OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lote_Gerar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @IdLote = NULL;
        SET @Origem = UPPER(LTRIM(RTRIM(ISNULL(@Origem, ''))));

        IF @Origem = '' OR REPLACE(@Origem, '_', '') LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2
            THROW 50001, N'Origem do lote inválida (use letras maiúsculas, números e "_").', 1;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';

        INSERT INTO SIS.Lote (ORIGEM, DESCRICAO, TABELA_REFERENCIA, ID_REFERENCIA, USUARIO_CRIACAO)
        VALUES (@Origem, LTRIM(RTRIM(ISNULL(@Descricao, N''))), LTRIM(RTRIM(ISNULL(@TabelaReferencia, N''))), @IdReferencia, ISNULL(@Usuario, N''));
        SET @IdLote = CAST(SCOPE_IDENTITY() AS BIGINT);

        IF ISNULL(@DefinirContexto, 1) = 1
            EXEC sys.sp_set_session_context @key = N'ID_LOTE', @value = @IdLote;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() <> 50001 AND XACT_STATE() = 1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
