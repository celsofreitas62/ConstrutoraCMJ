/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Esvaziar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Botão "Esvaziar agora" da tela Sistema › Lixeira (P20): apaga
                de vez os registros escolhidos (@Ids = lista de ID_LIXEIRA
                separados por vírgula), sem esperar o prazo. Cada registro é
                independente: se um não puder ser apagado (passou a ser usado,
                trava), os outros seguem. A cópia completa fica na auditoria.
                Permissão: ESVAZIAR em SIS_LIXEIRA e VER na tela de cada
                registro (os de telas que o usuário não vê são ignorados).
                Devolve 1 linha: SUCESSO, MENSAGEM, QTD_APAGADOS, QTD_RECUSADOS.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Esvaziar @IdUsuario = 2, @Ids = N'1,2';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Esvaziar]
    @IdUsuario  INT,
    @Ids        NVARCHAR(MAX),
    @Motivo     NVARCHAR(400) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Sem XACT_ABORT: laço isolado, um registro ruim não derruba os outros (PADRAO_SQL regras 2 e 13).

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Esvaziar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @Lista TABLE (ORDEM INT IDENTITY(1,1), ID_LIXEIRA BIGINT);
    DECLARE @i INT = 1, @Total INT, @Id BIGINT, @Msg NVARCHAR(400), @PrimeiraRecusa NVARCHAR(400) = N'';
    DECLARE @Apagados INT = 0, @Recusados INT = 0, @Usuario NVARCHAR(100);

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'ESVAZIAR') = 0
    BEGIN
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para esvaziar a lixeira.' AS NVARCHAR(400)) AS MENSAGEM, 0 AS QTD_APAGADOS, 0 AS QTD_RECUSADOS;
        RETURN;
    END;

    INSERT INTO @Lista (ID_LIXEIRA)
    SELECT DISTINCT l.ID_LIXEIRA
    FROM STRING_SPLIT(ISNULL(@Ids, N''), N',') s
    INNER JOIN SIS.Lixeira l ON l.ID_LIXEIRA = TRY_CONVERT(BIGINT, LTRIM(RTRIM(s.value)))
    WHERE l.SITUACAO = 'LIXEIRA'
      AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, l.ITEM_CODIGO, 'VER') = 1;

    SELECT @Total = COUNT(*) FROM @Lista;
    IF @Total = 0
    BEGIN
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Escolha os registros da lixeira que serão apagados de vez.' AS NVARCHAR(400)) AS MENSAGEM, 0 AS QTD_APAGADOS, 0 AS QTD_RECUSADOS;
        RETURN;
    END;

    SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    SET @Motivo = ISNULL(NULLIF(LTRIM(RTRIM(@Motivo)), N''), N'Esvaziar agora');
    SET @EtapaAtual = 'Apagando';

    WHILE @i <= @Total
    BEGIN
        SELECT @Id = l.ID_LIXEIRA FROM @Lista l WHERE l.ORDEM = @i;
        SET @Msg = N'';
        BEGIN TRY
            IF @TranCountEntrada = 0 BEGIN TRANSACTION;
                EXEC SIS.SIS_Lixeira_Apagar @IdLixeira = @Id, @Usuario = @Usuario, @Motivo = @Motivo, @Mensagem = @Msg OUTPUT;
            IF @TranCountEntrada = 0 COMMIT TRANSACTION;

            IF ISNULL(@Msg, N'') = N'' SET @Apagados = @Apagados + 1;
            ELSE
            BEGIN
                SET @Recusados = @Recusados + 1;
                IF @PrimeiraRecusa = N'' SET @PrimeiraRecusa = @Msg;
            END;
        END TRY
        BEGIN CATCH
            IF @TranCountEntrada = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            IF XACT_STATE() <> -1
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual + N' ' + CAST(@Id AS NVARCHAR(20)), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
            SET @Recusados = @Recusados + 1;
            IF @PrimeiraRecusa = N'' SET @PrimeiraRecusa = N'Um registro não pôde ser apagado (erro registrado para análise).';
            IF XACT_STATE() = -1 BREAK;
        END CATCH;
        SET @i = @i + 1;
    END;

    SELECT CAST(CASE WHEN @Apagados > 0 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
           CAST(LEFT(CAST(@Apagados AS NVARCHAR(10)) + N' registro(s) apagado(s) de vez.'
                + CASE WHEN @Recusados > 0 THEN N' ' + CAST(@Recusados AS NVARCHAR(10)) + N' não apagado(s): ' + @PrimeiraRecusa ELSE N'' END, 400) AS NVARCHAR(400)) AS MENSAGEM,
           @Apagados AS QTD_APAGADOS, @Recusados AS QTD_RECUSADOS;
END;
GO
