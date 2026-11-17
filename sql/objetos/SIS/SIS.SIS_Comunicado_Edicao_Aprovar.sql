/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Edicao_Aprovar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : "Aprovar e enviar": manda ao grupo oficial exatamente o que foi
                aprovado na prévia (assunto e HTML da edição) e marca ENVIADA, tudo
                na mesma transação. Só edição em PREVIA. Permissão: APROVAR em
                SIS_COMUNICADO. Conta EXTERNA (destinatários de fora). No banco
                _LOCAL a fila manda para o EMAIL_TESTE (proteção da 02d).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Edicao_Aprovar @IdUsuario = 2, @IdEdicao = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Edicao_Aprovar]
    @IdUsuario  INT,
    @IdEdicao   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Edicao_Aprovar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Situacao   VARCHAR(10);
    DECLARE @Grupo      VARCHAR(30);
    DECLARE @Para       NVARCHAR(MAX);
    DECLARE @Assunto    NVARCHAR(400);
    DECLARE @Corpo      NVARCHAR(MAX);
    DECLARE @IdEmail    BIGINT;
    DECLARE @Chave      NVARCHAR(200);
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'APROVAR') = 0
            SET @Recusa = N'Você não tem permissão para aprovar comunicados.';

        SET @EtapaAtual = 'Envio';
        BEGIN TRANSACTION;

        SELECT @Situacao = e.SITUACAO, @Grupo = g.CODIGO, @Assunto = e.ASSUNTO, @Corpo = e.CORPO_HTML
        FROM SIS.Comunicado_Edicao e WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = e.ID_COMUNICADO
        INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL
        WHERE e.ID_COMUNICADO_EDICAO = @IdEdicao;

        IF @Recusa = N'' AND @Situacao IS NULL
            SET @Recusa = N'Edição do comunicado não encontrada.';
        IF @Recusa = N'' AND @Situacao <> 'PREVIA'
            SET @Recusa = CASE @Situacao WHEN 'ENVIADA' THEN N'Este comunicado já foi enviado.'
                                         ELSE N'Esta prévia foi descartada. Gere uma prévia nova.' END;
        SET @Para = ISNULL(SIS.fn_SIS_Emails_Do_Grupo(@Grupo), N'');
        IF @Recusa = N'' AND @Para = N''
            SET @Recusa = N'O grupo de destinatários do comunicado não tem e-mail ativo.';
        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi alterado; COMMIT (e não ROLLBACK) funciona também dentro de INSERT-EXEC
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Chave   = N'COMUNICADO:' + CONVERT(NVARCHAR(30), @IdEdicao);
        EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @Assunto, @CorpoHTML = @Corpo, @Tipo = 'COMUNICADO',
             @Origem = @NomeProc, @ChaveOrigem = @Chave, @Grupo = @Grupo, @Conta = 'EXTERNA', @IdEmail = @IdEmail OUTPUT;

        IF @IdEmail IS NULL
            THROW 50001, N'O comunicado não entrou na fila de e-mails (veja o log de erros).', 1;

        UPDATE SIS.Comunicado_Edicao
           SET SITUACAO = 'ENVIADA', ID_EMAIL_OFICIAL = @IdEmail, DT_APROVACAO = SYSDATETIME(), USUARIO_APROVACAO = @Usuario,
               DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
         WHERE ID_COMUNICADO_EDICAO = @IdEdicao;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Comunicado aprovado. O e-mail foi para a fila de envio.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdEdicao AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível aprovar o comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
