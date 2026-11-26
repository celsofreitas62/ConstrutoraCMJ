/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Pendencia_Resolver]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - resolve uma pendência manual aberta, com a nota da
                resolução (obrigatória), quem e quando. Para voltar atrás:
                FIN_Lancamento_Pendencia_Reabrir.
                Permissão: PENDENCIA em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Pendencia_Resolver @IdUsuario = 2, @IdLancamentoPendencia = 1, @Resolucao = N'NF anexada';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Pendencia_Resolver]
    @IdUsuario              INT,
    @IdLancamentoPendencia  BIGINT,
    @Resolucao              NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Pendencia_Resolver]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @TipoLanc   CHAR(1);
    DECLARE @IdLanc     BIGINT;
    DECLARE @Situacao   VARCHAR(10);
    DECLARE @Ativo      BIT;
    DECLARE @Linhas     INT;

    BEGIN TRY
        SET @Resolucao = LTRIM(RTRIM(ISNULL(@Resolucao, N'')));

        SELECT @IdLanc = lp.ID_LANCAMENTO, @Situacao = lp.SITUACAO, @Ativo = lp.ATIVO, @TipoLanc = l.TIPO
        FROM FIN.Lancamento_Pendencia lp
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = lp.ID_LANCAMENTO
        WHERE lp.ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia;

        IF @IdLanc IS NULL OR @Ativo = 0
            SET @Recusa = N'Pendência não encontrada.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @TipoLanc WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'PENDENCIA') = 0
            SET @Recusa = N'Você não tem permissão para resolver pendências.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLanc) = 1
            SET @Recusa = N'O lançamento está na lixeira.';
        IF @Recusa = N'' AND @Situacao = 'RESOLVIDA'
            SET @Recusa = N'A pendência já está resolvida.';
        IF @Recusa = N'' AND LEN(@Resolucao) < 3
            SET @Recusa = N'Informe como a pendência foi resolvida.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE FIN.Lancamento_Pendencia
           SET SITUACAO = 'RESOLVIDA', DT_RESOLUCAO = SYSDATETIME(), USUARIO_RESOLUCAO = @Usuario, RESOLUCAO = @Resolucao,
               DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_LANCAMENTO_PENDENCIA = @IdLancamentoPendencia AND SITUACAO = 'ABERTA' AND ATIVO = 1;
        SET @Linhas = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Pendência resolvida.' ELSE N'A pendência foi alterada por outra pessoa. Abra a ficha de novo.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamentoPendencia AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível resolver a pendência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamentoPendencia AS ID;
    END CATCH;
END;
GO
