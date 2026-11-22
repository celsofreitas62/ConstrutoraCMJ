/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Rotina diária da lixeira (P20; rotina LIXEIRA_LIMPEZA):
                  1) limpeza (liga/desliga LIXEIRA_LIMPEZA_ATIVA): apaga de vez
                     o que passou do prazo (DT_APAGAR até hoje). O que passou a
                     ser usado não é apagado: o motivo fica na linha da lixeira
                     e sai no aviso;
                  2) aviso: um e-mail para o grupo do parâmetro
                     LIXEIRA_AVISO_GRUPO com o que será apagado nos próximos
                     LIXEIRA_AVISO_DIAS dia(s) e ainda não foi avisado. Sem
                     nada para avisar, não sai e-mail. Em teste (@bRunLocal),
                     o aviso vai para o EMAIL_TESTE e não marca "avisado".
                Blocos independentes (regra 13): no fim, se algum falhou,
                relança um erro agregado (a rotina fica com resultado ERRO).
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Processar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Processar]
    @bRunLocal  BIT = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Sem XACT_ABORT: laço isolado na limpeza (regras 2 e 13).
    SET @bRunLocal = ISNULL(@bRunLocal, CASE WHEN DB_NAME() LIKE '%[_]LOCAL' THEN 1 ELSE 0 END);

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Limpeza';
    DECLARE @Hoje DATE = CAST(SYSDATETIME() AS DATE);
    DECLARE @Vencidos TABLE (ORDEM INT IDENTITY(1,1), ID_LIXEIRA BIGINT);
    DECLARE @Aviso TABLE (ID_LIXEIRA BIGINT PRIMARY KEY);
    DECLARE @i INT = 1, @Total INT, @Id BIGINT, @Msg NVARCHAR(400), @Falhas INT = 0;
    DECLARE @Dias INT, @Grupo VARCHAR(30), @Para NVARCHAR(MAX), @Linhas NVARCHAR(MAX), @Corpo NVARCHAR(MAX), @Assunto NVARCHAR(400), @Chave NVARCHAR(200), @IdEmail BIGINT;
    DECLARE @Qtd INT;

    -- 1) Limpeza do que venceu
    BEGIN TRY
        IF SIS.fn_SIS_Parametro_SN('LIXEIRA_LIMPEZA_ATIVA') = 1
        BEGIN
            INSERT INTO @Vencidos (ID_LIXEIRA)
            SELECT l.ID_LIXEIRA FROM SIS.Lixeira l WHERE l.SITUACAO = 'LIXEIRA' AND l.DT_APAGAR <= @Hoje ORDER BY l.ID_LIXEIRA;
            SELECT @Total = COUNT(*) FROM @Vencidos;

            WHILE @i <= @Total
            BEGIN
                SELECT @Id = v.ID_LIXEIRA FROM @Vencidos v WHERE v.ORDEM = @i;
                SET @Msg = N'';
                BEGIN TRY
                    BEGIN TRANSACTION;
                        EXEC SIS.SIS_Lixeira_Apagar @IdLixeira = @Id, @Usuario = N'rotina', @Motivo = N'Prazo da lixeira vencido', @Mensagem = @Msg OUTPUT;
                        IF ISNULL(@Msg, N'') <> N''
                            UPDATE l SET l.MOTIVO_SITUACAO = @Msg, l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = N'rotina'
                            FROM SIS.Lixeira l WHERE l.ID_LIXEIRA = @Id AND l.SITUACAO = 'LIXEIRA' AND l.MOTIVO_SITUACAO <> @Msg;
                    COMMIT TRANSACTION;
                END TRY
                BEGIN CATCH
                    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                    INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                    VALUES (@NomeProc, N'Limpeza ' + CAST(@Id AS NVARCHAR(20)), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
                    SET @Falhas = @Falhas + 1;
                END CATCH;
                SET @i = @i + 1;
            END;
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SET @Falhas = @Falhas + 1;
    END CATCH;

    -- 2) Aviso do que vai ser apagado
    BEGIN TRY
        SET @EtapaAtual = 'Aviso';
        SET @Dias  = SIS.fn_SIS_Parametro_Inteiro('LIXEIRA_AVISO_DIAS');
        SET @Grupo = CONVERT(VARCHAR(30), LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('LIXEIRA_AVISO_GRUPO'), N''))));

        IF @Dias > 0
        BEGIN
            INSERT INTO @Aviso (ID_LIXEIRA)
            SELECT l.ID_LIXEIRA
            FROM SIS.Lixeira l
            WHERE l.SITUACAO = 'LIXEIRA'
              AND l.DT_AVISO IS NULL
              AND l.DT_APAGAR <= DATEADD(DAY, @Dias, @Hoje);
            SELECT @Qtd = COUNT(*) FROM @Aviso;

            SET @Para = CASE WHEN @Grupo = '' THEN N'' ELSE SIS.fn_SIS_Emails_Do_Grupo(@Grupo) END;
            IF @Qtd > 0 AND @Para = N''
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, 0, N'Aviso da lixeira não enviado: o grupo de e-mail do parâmetro LIXEIRA_AVISO_GRUPO está vazio ou sem destinatário.', 0, SYSDATETIME());

            IF @Qtd > 0 AND @Para <> N''
            BEGIN
                SELECT @Linhas = STRING_AGG(CONVERT(NVARCHAR(MAX),
                           N'<tr style="background:' + CASE WHEN x.N % 2 = 0 THEN N'#f5f5f5' ELSE N'#ffffff' END + N'">'
                         + N'<td style="padding:6px;border-bottom:1px solid #eeeeee">' + SIS.fn_SIS_Texto_HTML(ISNULL(x.MODULO, N'') + N' › ' + ISNULL(x.TELA, N'')) + N'</td>'
                         + N'<td style="padding:6px;border-bottom:1px solid #eeeeee">' + SIS.fn_SIS_Texto_HTML(ISNULL(x.DESCRICAO, N''))
                         + CASE WHEN ISNULL(x.MOTIVO_SITUACAO, N'') <> N'' THEN N'<br><span style="color:#E65100">' + SIS.fn_SIS_Texto_HTML(x.MOTIVO_SITUACAO) + N'</span>' ELSE N'' END + N'</td>'
                         + N'<td style="padding:6px;border-bottom:1px solid #eeeeee">' + SIS.fn_SIS_Texto_HTML(ISNULL(x.USUARIO_EXCLUSAO, N'')) + N'<br>' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(x.DT_EXCLUSAO), N'') + N'</td>'
                         + N'<td style="padding:6px;border-bottom:1px solid #eeeeee;text-align:center">' + ISNULL(SIS.fn_SIS_Formatar_Data(x.DT_APAGAR), N'') + N'</td></tr>'), N'')
                       WITHIN GROUP (ORDER BY x.N)
                FROM (SELECT ROW_NUMBER() OVER (ORDER BY l.DT_APAGAR, m.ORDEM_MENU, i.ORDEM, l.ID_LIXEIRA) AS N,
                             m.NOME AS MODULO, i.NOME AS TELA, l.DESCRICAO, l.MOTIVO_SITUACAO, l.USUARIO_EXCLUSAO, l.DT_EXCLUSAO, l.DT_APAGAR
                      FROM @Aviso a
                      INNER JOIN SIS.Lixeira l ON l.ID_LIXEIRA = a.ID_LIXEIRA
                      LEFT  JOIN SIS.Item   i ON i.CODIGO = l.ITEM_CODIGO
                      LEFT  JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO) x;

                SET @Corpo = SIS.fn_SIS_Email_HTML(N'Lixeira: registros que serão apagados de vez', 'INFO',
                    N'<p>Os registros abaixo estão na lixeira e serão <b>apagados de vez</b> na data indicada. '
                    + N'Para manter algum, abra <b>Sistema › Lixeira</b> e use <b>Recuperar</b> ou <b>Manter mais N dias</b>.</p>'
                    + N'<table style="width:100%;border-collapse:collapse;font-size:13px">'
                    + N'<tr style="background:#eeeeee"><th style="padding:6px;text-align:left">Módulo › Tela</th><th style="padding:6px;text-align:left">Registro</th>'
                    + N'<th style="padding:6px;text-align:left">Excluído por / em</th><th style="padding:6px">Apaga em</th></tr>'
                    + ISNULL(@Linhas, N'') + N'</table>',
                    @NomeProc, @Grupo, 0);

                SET @Assunto = LEFT(ISNULL(SIS.fn_SIS_Parametro('SISTEMA_NOME'), N'SisCMJ') + N' - Lixeira: ' + CAST(@Qtd AS NVARCHAR(10))
                             + N' registro(s) serão apagados de vez', 400);
                SET @Chave = N'LIXEIRA_AVISO_' + CONVERT(NVARCHAR(8), @Hoje, 112) + N'_' + CAST((SELECT MAX(a.ID_LIXEIRA) FROM @Aviso a) AS NVARCHAR(20))
                           + CASE WHEN @bRunLocal = 1 THEN N'_' + CONVERT(NVARCHAR(30), SYSDATETIME(), 126) ELSE N'' END;

                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = @Assunto, @CorpoHTML = @Corpo, @Tipo = 'LIXEIRA_AVISO',
                     @Origem = @NomeProc, @ChaveOrigem = @Chave, @Grupo = @Grupo, @IdEmail = @IdEmail OUTPUT;

                IF @bRunLocal = 0 AND @IdEmail IS NOT NULL
                    UPDATE l SET l.DT_AVISO = SYSDATETIME()
                    FROM SIS.Lixeira l
                    INNER JOIN @Aviso a ON a.ID_LIXEIRA = l.ID_LIXEIRA
                    WHERE l.DT_AVISO IS NULL;
            END;
        END;
    END TRY
    BEGIN CATCH
        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SET @Falhas = @Falhas + 1;
    END CATCH;

    IF @Falhas > 0
        THROW 50002, N'Rotina da lixeira terminou com falha (ver o log de erros).', 1;
END;
GO
