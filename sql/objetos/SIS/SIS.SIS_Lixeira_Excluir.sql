/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Botão Excluir das telas (P20): manda o registro para a
                lixeira, de onde pode ser recuperado até o fim do prazo
                (LIXEIRA_DIAS_GUARDA ou o prazo próprio da tela). Só exclui o
                que nada usa; senão recusa e sugere Desativar.
                Permissão: EXCLUIR na tela (@Item), e a tela precisa mostrar
                a tabela (SIS.Item.TABELAS_DA_TELA).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_LIXEIRA, DT_APAGAR.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = 2, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = 1, @Motivo = N'cadastro em dobro';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Excluir]
    @IdUsuario   INT,
    @Item        VARCHAR(40),
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Motivo      NVARCHAR(400) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @Recusa NVARCHAR(400) = N'', @IdLixeira BIGINT, @DtApagar DATE;

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para excluir nesta tela.';
        ELSE IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            SET @Recusa = N'Esta tela não exclui esse tipo de registro.';
        ELSE IF @IdRegistro IS NULL
            SET @Recusa = N'Escolha o registro a excluir.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_LIXEIRA, CAST(NULL AS DATE) AS DT_APAGAR;
            RETURN;
        END;

        SET @EtapaAtual = 'Lixeira';
        IF @TranCountEntrada = 0 BEGIN TRANSACTION;
            EXEC SIS.SIS_Lixeira_Marcar @IdUsuario = @IdUsuario, @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Item = @Item,
                 @Motivo = @Motivo, @IdLixeira = @IdLixeira OUTPUT, @Mensagem = @Recusa OUTPUT;
        IF @TranCountEntrada = 0 COMMIT TRANSACTION;

        IF ISNULL(@Recusa, N'') <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_LIXEIRA, CAST(NULL AS DATE) AS DT_APAGAR;
            RETURN;
        END;

        SELECT @DtApagar = l.DT_APAGAR FROM SIS.Lixeira l WHERE l.ID_LIXEIRA = @IdLixeira;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Registro enviado para a lixeira. Pode ser recuperado até ' + ISNULL(SIS.fn_SIS_Formatar_Data(@DtApagar), N'') + N' (Sistema › Lixeira).' AS NVARCHAR(400)) AS MENSAGEM,
               @IdLixeira AS ID_LIXEIRA, @DtApagar AS DT_APAGAR;
    END TRY
    BEGIN CATCH
        IF @TranCountEntrada = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível excluir o registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_LIXEIRA, CAST(NULL AS DATE) AS DT_APAGAR;
    END CATCH;
END;
GO
