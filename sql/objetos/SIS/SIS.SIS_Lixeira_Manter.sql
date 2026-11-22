/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Manter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Botão "Manter mais N dias" da tela Sistema › Lixeira (P20):
                adia a data em que o registro será apagado de vez, sem
                recuperar. Conta os dias a partir da data marcada (ou de hoje,
                se ela já passou) e libera um novo aviso por e-mail.
                Permissão: ALTERAR em SIS_LIXEIRA e VER na tela do registro.
                Devolve 1 linha: SUCESSO, MENSAGEM, DT_APAGAR.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Manter @IdUsuario = 2, @IdLixeira = 1, @Dias = 30;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Manter]
    @IdUsuario  INT,
    @IdLixeira  BIGINT,
    @Dias       INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Manter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa NVARCHAR(400) = N'', @Item VARCHAR(40), @Situacao VARCHAR(12), @DtApagar DATE, @Usuario NVARCHAR(100);

    BEGIN TRY
        SELECT @Item = l.ITEM_CODIGO, @Situacao = l.SITUACAO FROM SIS.Lixeira l WHERE l.ID_LIXEIRA = @IdLixeira;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para mudar o prazo da lixeira.';
        ELSE IF @Situacao IS NULL
            SET @Recusa = N'Registro da lixeira não encontrado.';
        ELSE IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            SET @Recusa = N'Você não tem permissão para ver a tela deste registro.';
        ELSE IF @Situacao <> 'LIXEIRA'
            SET @Recusa = N'O registro não está mais na lixeira.';
        ELSE IF ISNULL(@Dias, 0) NOT BETWEEN 1 AND 3650
            SET @Recusa = N'Informe de 1 a 3650 dias.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS DATE) AS DT_APAGAR;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        UPDATE l
           SET @DtApagar = l.DT_APAGAR = DATEADD(DAY, @Dias, CASE WHEN l.DT_APAGAR < CAST(SYSDATETIME() AS DATE) THEN CAST(SYSDATETIME() AS DATE) ELSE l.DT_APAGAR END),
               l.DT_AVISO = NULL, l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Lixeira l
        WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA';

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Prazo adiado: o registro fica na lixeira até ' + ISNULL(SIS.fn_SIS_Formatar_Data(@DtApagar), N'') + N'.' AS NVARCHAR(400)) AS MENSAGEM,
               @DtApagar AS DT_APAGAR;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível mudar o prazo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS DATE) AS DT_APAGAR;
    END CATCH;
END;
GO
