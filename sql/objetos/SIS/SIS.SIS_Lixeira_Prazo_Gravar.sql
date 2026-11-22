/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Prazo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Prazo próprio da lixeira para uma tela (P20). @Dias vazio
                (NULL) = volta a valer o prazo geral (LIXEIRA_DIAS_GUARDA).
                Vale para o que for excluído daqui em diante; o que já está na
                lixeira mantém a data marcada (use "Manter mais N dias").
                Permissão: ALTERAR em SIS_LIXEIRA e VER na tela.
                Devolve 1 linha: SUCESSO, MENSAGEM.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Prazo_Gravar @IdUsuario = 2, @Tabela = N'CAD.Pessoa', @Dias = 120;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Prazo_Gravar]
    @IdUsuario  INT,
    @Tabela     NVARCHAR(256),
    @Dias       INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Prazo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa NVARCHAR(400) = N'', @Usuario NVARCHAR(100);

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para mudar o prazo da lixeira.';
        ELSE IF NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela AND c.ATIVO = 1 AND c.PERMITE_LIXEIRA = 1)
            SET @Recusa = N'Esta tela não usa a lixeira.';
        ELSE IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, SIS.fn_SIS_Item_Da_Tabela(@Tabela), 'VER') = 0
            SET @Recusa = N'Você não tem permissão para ver esta tela.';
        ELSE IF @Dias IS NOT NULL AND @Dias NOT BETWEEN 1 AND 3650
            SET @Recusa = N'Informe de 1 a 3650 dias, ou deixe em branco para usar o prazo geral.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        UPDATE c
           SET c.DIAS_GUARDA = @Dias, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Tabela_Config c
        WHERE c.TABELA = @Tabela
          AND ISNULL(c.DIAS_GUARDA, -1) <> ISNULL(@Dias, -1);

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Dias IS NULL THEN N'Prazo próprio retirado: vale o prazo geral (' + CAST(SIS.fn_SIS_Lixeira_Dias(@Tabela) AS NVARCHAR(10)) + N' dias).'
                         ELSE N'Prazo gravado: ' + CAST(@Dias AS NVARCHAR(10)) + N' dias, para o que for excluído daqui em diante.' END AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o prazo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO
