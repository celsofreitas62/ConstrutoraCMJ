/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Cancelar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Cancela um lançamento (botão Cancelar da ficha): o lançamento
                fica CANCELADO, com data, usuário e motivo, e as parcelas em
                aberto ficam CANCELADA. Continua na lista (filtro Canceladas) e
                no histórico; volta pelo desfazer da aba Histórico. Só sem
                baixa, fora de mês fechado (conta contábil) e de origem manual
                ou migração. Motivo obrigatório. Tudo-ou-nada.
                Permissão: CANCELAR em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

    v1.1 (27/11/2026) - Etapa 04g4: só a baixa viva (não estornada) impede o
                        cancelamento (fn_FIN_Parcela_Baixa_Viva).
  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Cancelar @IdUsuario = 2, @IdLancamento = 1, @Motivo = N'Lançado em dobro';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Cancelar]
    @IdUsuario     INT,
    @IdLancamento  BIGINT,
    @Motivo        NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Cancelar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Tipo       CHAR(1);
    DECLARE @Situacao   VARCHAR(10);
    DECLARE @Origem     VARCHAR(15);
    DECLARE @Linhas     INT;

    BEGIN TRY
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        SELECT @Tipo = l.TIPO, @Situacao = l.SITUACAO, @Origem = l.ORIGEM
        FROM FIN.Lancamento l WHERE l.ID_LANCAMENTO = @IdLancamento;

        IF @Tipo IS NULL
            SET @Recusa = N'Lançamento não encontrado.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'CANCELAR') = 0
            SET @Recusa = N'Você não tem permissão para cancelar lançamentos.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento) = 1
            SET @Recusa = N'O lançamento está na lixeira.';
        IF @Recusa = N'' AND @Situacao = 'CANCELADO'
            SET @Recusa = N'O lançamento já está cancelado.';
        IF @Recusa = N'' AND @Origem NOT IN ('MANUAL', 'MIGRACAO')
            SET @Recusa = N'Este lançamento foi gerado por outra rotina (' + CONVERT(NVARCHAR(15), @Origem) + N'): cancele pela tela de origem.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_LANCAMENTO = @IdLancamento AND EXISTS (SELECT 1 FROM FIN.fn_FIN_Parcela_Baixa_Viva(p.ID_PARCELA)))
            SET @Recusa = N'O lançamento tem pagamento ou recebimento: estorne as baixas antes de cancelar.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Lancamento l
                                     INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = l.ID_EMPRESA AND m.MES = l.DT_COMPETENCIA AND m.FECHADO = 1
                                     INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.CONTABIL = 1
                                     WHERE l.ID_LANCAMENTO = @IdLancamento)
            SET @Recusa = N'O mês do lançamento está fechado (conta contábil).';
        IF @Recusa = N'' AND LEN(@Motivo) < 5
            SET @Recusa = N'Informe o motivo do cancelamento.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE l
           SET l.SITUACAO = 'CANCELADO', l.DT_CANCELAMENTO = SYSDATETIME(), l.USUARIO_CANCELAMENTO = @Usuario,
               l.MOTIVO_CANCELAMENTO = @Motivo, l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = @Usuario
        FROM FIN.Lancamento l
        WHERE l.ID_LANCAMENTO = @IdLancamento AND l.SITUACAO = 'ATIVO';
        SET @Linhas = @@ROWCOUNT;

        UPDATE p
           SET p.SITUACAO = 'CANCELADA', p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = @Usuario
        FROM FIN.Parcela p
        WHERE p.ID_LANCAMENTO = @IdLancamento AND p.SITUACAO = 'ABERTA';

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Lançamento cancelado.' ELSE N'O lançamento foi alterado por outra pessoa. Abra a ficha de novo.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamento AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível cancelar o lançamento. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID;
    END CATCH;
END;
GO
