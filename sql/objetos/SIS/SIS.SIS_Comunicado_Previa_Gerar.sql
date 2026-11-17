/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Previa_Gerar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Monta a edição da semana (segunda a sexta da data de hoje) com os
                itens ativos e manda a PRÉVIA só para o grupo de aprovação. Prévias
                anteriores ainda pendentes viram DESCARTADA (não acumulam). Semana
                que já teve envio oficial: recusa. Chamada pela rotina (@IdUsuario
                NULL, sem conferir permissão) ou pelo botão "Gerar prévia agora"
                (permissão ENVIAR em SIS_COMUNICADO). Devolve SUCESSO, MENSAGEM, ID
                (ID = ID_COMUNICADO_EDICAO).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = 2, @IdComunicado = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Previa_Gerar]
    @IdUsuario     INT = NULL,
    @IdComunicado  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Previa_Gerar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Hoje       DATE          = CAST(SYSDATETIME() AS DATE);
    DECLARE @Inicio     DATE;
    DECLARE @Fim        DATE;
    DECLARE @Titulo     NVARCHAR(150);
    DECLARE @GrupoAprov VARCHAR(30);
    DECLARE @Para       NVARCHAR(MAX);
    DECLARE @Assunto    NVARCHAR(400);
    DECLARE @AssuntoPv  NVARCHAR(400);
    DECLARE @Conteudo   NVARCHAR(MAX);
    DECLARE @Corpo      NVARCHAR(MAX);
    DECLARE @CorpoPv    NVARCHAR(MAX);
    DECLARE @Aviso      NVARCHAR(MAX);
    DECLARE @IdEdicao   BIGINT;
    DECLARE @IdEmail    BIGINT;
    DECLARE @Chave      NVARCHAR(200);
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        -- segunda-feira da semana, sem depender de SET DATEFIRST (01/01/1900 foi segunda)
        SET @Inicio = DATEADD(DAY, -(DATEDIFF(DAY, '19000101', @Hoje) % 7), @Hoje);
        SET @Fim    = DATEADD(DAY, 4, @Inicio);

        IF @IdUsuario IS NOT NULL AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'ENVIAR') = 0
            SET @Recusa = N'Você não tem permissão para gerar a prévia do comunicado.';

        SELECT @Titulo = c.TITULO, @GrupoAprov = g.CODIGO
        FROM SIS.Comunicado c
        INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL_APROVACAO
        WHERE c.ID_COMUNICADO = @IdComunicado AND c.ATIVO = 1;

        IF @Recusa = N'' AND @Titulo IS NULL
            SET @Recusa = N'Comunicado não encontrado ou desligado.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM SIS.Comunicado_Edicao e
                                     WHERE e.ID_COMUNICADO = @IdComunicado AND e.DT_INICIO = @Inicio AND e.SITUACAO = 'ENVIADA')
            SET @Recusa = N'O comunicado desta semana já foi enviado.';
        SET @Para = ISNULL(SIS.fn_SIS_Emails_Do_Grupo(@GrupoAprov), N'');
        IF @Recusa = N'' AND @Para = N''
            SET @Recusa = N'O grupo de aprovação do comunicado não tem e-mail ativo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Montagem';
        SET @Usuario   = ISNULL(SIS.fn_SIS_Usuario_Login(@IdUsuario), N'rotina');
        SET @Assunto   = N'CMJ - ' + @Titulo + N' - semana de ' + LEFT(SIS.fn_SIS_Formatar_Data(@Inicio), 5)
                       + N' a ' + SIS.fn_SIS_Formatar_Data(@Fim);
        SET @Conteudo  = SIS.fn_SIS_Comunicado_Conteudo(@IdComunicado);
        SET @Corpo     = SIS.fn_SIS_Email_HTML(@Titulo, 'INFO', @Conteudo, NULL, NULL, 1);
        SET @AssuntoPv = N'[PRÉVIA] ' + @Assunto;
        SET @Aviso     = N'<div style="background:#FFF3E0;border-left:4px solid #E65100;padding:10px 14px;margin-bottom:16px;">'
                       + N'<b>Prévia para aprovação.</b> Este e-mail ainda não foi enviado aos destinatários. '
                       + N'Para liberar, abra o SistemaCMJ, menu Sistema &gt; E-mails &gt; Comunicados, e clique em "Aprovar e enviar".</div>';
        SET @CorpoPv   = SIS.fn_SIS_Email_HTML(N'Prévia - ' + @Titulo, 'INFO', @Aviso + @Conteudo, @NomeProc, @GrupoAprov, 0);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE e
           SET e.SITUACAO = 'DESCARTADA', e.DT_ALTERACAO = SYSDATETIME(), e.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Edicao e WITH (UPDLOCK, HOLDLOCK)
        WHERE e.ID_COMUNICADO = @IdComunicado AND e.SITUACAO = 'PREVIA';

        INSERT INTO SIS.Comunicado_Edicao (ID_COMUNICADO, DT_INICIO, DT_FIM, ASSUNTO, CORPO_HTML, SITUACAO, USUARIO_CRIACAO)
        VALUES (@IdComunicado, @Inicio, @Fim, @Assunto, @Corpo, 'PREVIA', @Usuario);
        SET @IdEdicao = SCOPE_IDENTITY();

        SET @Chave = N'COMUNICADO_PREVIA:' + CONVERT(NVARCHAR(30), @IdEdicao);
        EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @AssuntoPv, @CorpoHTML = @CorpoPv, @Tipo = 'COMUNICADO_PREVIA',
             @Origem = @NomeProc, @ChaveOrigem = @Chave, @Grupo = @GrupoAprov, @Conta = 'INTERNA', @IdEmail = @IdEmail OUTPUT;

        IF @IdEmail IS NULL
            THROW 50001, N'A prévia não entrou na fila de e-mails (veja o log de erros).', 1;

        UPDATE SIS.Comunicado_Edicao SET ID_EMAIL_PREVIA = @IdEmail WHERE ID_COMUNICADO_EDICAO = @IdEdicao;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Prévia gerada e enviada para aprovação.' AS NVARCHAR(400)) AS MENSAGEM, @IdEdicao AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gerar a prévia do comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
