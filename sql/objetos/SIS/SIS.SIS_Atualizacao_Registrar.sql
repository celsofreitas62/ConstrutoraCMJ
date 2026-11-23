/*******************************************************************************
  Objeto      : [SIS].[SIS_Atualizacao_Registrar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Registra uma atualização de versão em SIS.Atualizacao. Chamada SÓ
                pelo atualizar.ps1 do pacote (atualização em um clique, 03h),
                rodado pelo administrador do Windows; o login da API não pode
                executar (DENY no papel rl_sistemacmj_api).
                Situação DESFEITA ou ERRO: manda aviso por e-mail para o
                parâmetro EMAIL_ADMIN_ALERTA (se preenchido).
                Situação CONCLUIDA: manda a nota da versão ao grupo
                VERSAO_AVISO_GRUPO (se VERSAO_AVISO_EMAIL_ATIVO = S).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_GERADO.

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 03h, banco 1.8).
    v1.1 (23/11/2026) - Etapa 04c (P22): atualização CONCLUIDA manda a nota das
                        versões novas (SIS.Versao_Nota, só itens para todos)
                        por e-mail ao grupo do parâmetro VERSAO_AVISO_GRUPO,
                        se VERSAO_AVISO_EMAIL_ATIVO = S. Falha no e-mail não
                        desfaz o registro (só vai para o log).

  Homologação:
    -- sql/testes/SIS/03h_Homologacao_Atualizacao.sql
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Atualizacao_Registrar]
    @VersaoProgramaDe    VARCHAR(20)    = '',
    @VersaoProgramaPara  VARCHAR(20),
    @VersaoBancoDe       VARCHAR(20)    = '',
    @VersaoBancoPara     VARCHAR(20),
    @DtInicio            DATETIME2(0),
    @DtFim               DATETIME2(0)   = NULL,
    @SegundosFora        INT            = 0,
    @Situacao            VARCHAR(10),
    @Mensagem            NVARCHAR(2000) = N'',
    @Notas               NVARCHAR(MAX)  = N'',
    @Pacote              NVARCHAR(260)  = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @EtapaAtual VARCHAR(100) = 'Conferência', @Id INT, @Para NVARCHAR(400), @Corpo NVARCHAR(MAX),
            @Chave NVARCHAR(200), @IdEmail BIGINT, @Agora DATETIME2(0) = SYSDATETIME(),
            @Grupo VARCHAR(30), @Itens NVARCHAR(MAX), @De INT, @Ate INT, @Sistema NVARCHAR(100);

    BEGIN TRY
        IF ISNULL(@Situacao, '') NOT IN ('CONCLUIDA', 'DESFEITA', 'ERRO')
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Situação inválida: use CONCLUIDA, DESFEITA ou ERRO.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS ID_GERADO;
            RETURN;
        END;
        IF LTRIM(RTRIM(ISNULL(@VersaoProgramaPara, ''))) = '' OR LTRIM(RTRIM(ISNULL(@VersaoBancoPara, ''))) = '' OR @DtInicio IS NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe as versões novas e o início da atualização.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS ID_GERADO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        INSERT INTO SIS.Atualizacao (VERSAO_PROGRAMA_DE, VERSAO_PROGRAMA_PARA, VERSAO_BANCO_DE, VERSAO_BANCO_PARA, DT_INICIO, DT_FIM,
                                     SEGUNDOS_FORA, SITUACAO, MENSAGEM, NOTAS, PACOTE)
        VALUES (ISNULL(@VersaoProgramaDe, ''), @VersaoProgramaPara, ISNULL(@VersaoBancoDe, ''), @VersaoBancoPara, @DtInicio, ISNULL(@DtFim, @Agora),
                ISNULL(@SegundosFora, 0), @Situacao, LEFT(ISNULL(@Mensagem, N''), 2000), ISNULL(@Notas, N''), LEFT(ISNULL(@Pacote, N''), 260));
        SET @Id = CAST(SCOPE_IDENTITY() AS INT);

        SET @EtapaAtual = 'Aviso por e-mail';
        IF @Situacao IN ('DESFEITA', 'ERRO')
        BEGIN
            SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
            IF @Para <> N''
            BEGIN
                SET @Corpo = SIS.fn_SIS_Email_HTML(N'Atualização de versão ' + CASE @Situacao WHEN 'DESFEITA' THEN N'desfeita' ELSE N'com erro' END, 'ALERTA',
                    N'<p>A atualização do sistema para a versão <b>' + SIS.fn_SIS_Texto_HTML(@VersaoBancoPara) + N'</b> (a versão era '
                    + SIS.fn_SIS_Texto_HTML(ISNULL(@VersaoBancoDe, '')) + N') no banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b> terminou como <b>'
                    + CASE @Situacao WHEN 'DESFEITA' THEN N'DESFEITA (voltou sozinha para a versão anterior)' ELSE N'ERRO (não conseguiu voltar sozinha: conferir o servidor)' END
                    + N'</b> em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(ISNULL(@DtFim, @Agora)), N'') + N'.</p><p>Motivo: ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Mensagem, N'')) + N'</p>',
                    N'[SIS].[SIS_Atualizacao_Registrar]', NULL, 0);
                SET @Chave = N'ATUALIZACAO_' + CONVERT(NVARCHAR(20), @Id);
                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: atualização do sistema não concluída', @CorpoHTML = @Corpo,
                     @Tipo = 'ALERTA', @Origem = N'[SIS].[SIS_Atualizacao_Registrar]', @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
            END;
        END;

        IF @Situacao = 'CONCLUIDA' AND SIS.fn_SIS_Parametro_SN('VERSAO_AVISO_EMAIL_ATIVO') = 1
        BEGIN
        BEGIN TRY
            SET @EtapaAtual = 'Nota da versão por e-mail';
            SET @Grupo = CONVERT(VARCHAR(30), LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('VERSAO_AVISO_GRUPO'), N''))));
            SET @Para  = CASE WHEN @Grupo = '' THEN N'' ELSE LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Emails_Do_Grupo(@Grupo), N''))) END;
            SET @De    = SIS.fn_SIS_Versao_Numero(@VersaoBancoDe);
            SET @Ate   = SIS.fn_SIS_Versao_Numero(@VersaoBancoPara);

            SELECT @Itens = STRING_AGG(CAST(N'<p style="margin:16px 0 4px 0;font-weight:bold;">Versão ' + SIS.fn_SIS_Texto_HTML(v.VERSAO)
                                            + CASE WHEN v.DT_VERSAO IS NULL THEN N'' ELSE N' (' + CONVERT(NVARCHAR(10), v.DT_VERSAO, 103) + N')' END
                                            + N'</p><ul style="margin:0;padding-left:20px;">' + v.ITENS + N'</ul>' AS NVARCHAR(MAX)), N'')
                          WITHIN GROUP (ORDER BY v.VERSAO_NUMERO DESC)
            FROM (SELECT n.VERSAO, n.VERSAO_NUMERO, MAX(n.DT_VERSAO) AS DT_VERSAO,
                         STRING_AGG(CAST(N'<li style="margin-bottom:6px;"><b>' + CASE n.TIPO WHEN 'NOVO' THEN N'Novo' WHEN 'MELHORIA' THEN N'Melhoria' ELSE N'Correção' END
                                         + N':</b> ' + ISNULL(n.TEXTO_HTML, N'') + N'</li>' AS NVARCHAR(MAX)), N'') WITHIN GROUP (ORDER BY n.ORDEM) AS ITENS
                  FROM SIS.Versao_Nota n WITH (NOLOCK)
                  WHERE n.PUBLICO = 'TODOS' AND n.VERSAO_NUMERO > @De AND n.VERSAO_NUMERO <= @Ate
                  GROUP BY n.VERSAO, n.VERSAO_NUMERO) v;

            IF @Para = N''
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (N'[SIS].[SIS_Atualizacao_Registrar]', @EtapaAtual, 0, N'Nota da versão não enviada: o grupo de e-mail do parâmetro VERSAO_AVISO_GRUPO está vazio ou sem destinatário.', 0, SYSDATETIME());

            IF @Para <> N'' AND ISNULL(@Itens, N'') <> N''
            BEGIN
                SET @Sistema = ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('SISTEMA_NOME'), N''))), N''), N'sistema');
                SET @Corpo = SIS.fn_SIS_Email_HTML(N'Nova versão do ' + @Sistema + N': ' + ISNULL(@VersaoBancoPara, ''), 'INFO',
                    N'<p>O ' + SIS.fn_SIS_Texto_HTML(@Sistema) + N' foi atualizado para a versão <b>' + SIS.fn_SIS_Texto_HTML(@VersaoBancoPara) + N'</b> em '
                    + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(ISNULL(@DtFim, @Agora)), N'') + N'. O sistema ficou fora do ar por '
                    + CONVERT(NVARCHAR(10), ISNULL(@SegundosFora, 0)) + N' segundo(s).</p><p>Veja o que mudou:</p>' + @Itens
                    + N'<p style="margin-top:16px;">As notas de todas as versões ficam em Sistema › Versões.</p>',
                    N'[SIS].[SIS_Atualizacao_Registrar]', @Grupo, 0);
                SET @Chave = N'VERSAO_NOTA_' + CONVERT(NVARCHAR(20), @Id);
                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'Nova versão do sistema instalada', @CorpoHTML = @Corpo,
                     @Tipo = 'NOTA_VERSAO', @Origem = N'[SIS].[SIS_Atualizacao_Registrar]', @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
            END;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> -1
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (N'[SIS].[SIS_Atualizacao_Registrar]', @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Atualização registrada.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@Id AS INT) AS ID_GERADO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (N'[SIS].[SIS_Atualizacao_Registrar]', @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Erro ao registrar a atualização: o erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(ISNULL(@Id, 0) AS INT) AS ID_GERADO;
    END CATCH;
END;
GO
