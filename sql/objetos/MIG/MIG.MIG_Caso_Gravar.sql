/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Grava a decisão da tela "Casos da migração" para um documento
                do Access (unidade). @Acao:
                  CORRIGIR       correções linha a linha (@LinhasJson: os
                                 valores em uso de cada linha; só o que for
                                 diferente do Access é guardado, em
                                 MIG.Caso_Correcao_Linha); tira a decisão
                                 IGNORAR/ARQUIVO_MORTO, se houver;
                  IGNORAR        o documento não migra (motivo obrigatório);
                  ARQUIVO_MORTO  o documento vai para o arquivo morto (motivo
                                 obrigatório);
                  DESFAZER       apaga todas as correções e decisões do
                                 documento (volta ao Access).
                As correções valem em toda nova rodada da migração. Depois de
                gravar, a tela chama MIG_Caso_Conferir para mostrar se o
                documento passou a se encaixar.
                Datas: em @LinhasJson, data vazia onde o Access tinha data é
                guardada como 01/01/1900 (= "sem data" para a migração).
                Permissão: ALTERAR em MIG_CASOS (os dois administradores).
                Devolve SUCESSO, MENSAGEM, ID (padrão das gravações).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Gravar @IdUsuario = 1, @Unidade = 'L:123', @Acao = 'IGNORAR', @Motivo = N'Lançado em dobro no Access';
    -- EXEC MIG.MIG_Caso_Gravar @IdUsuario = 1, @Unidade = 'L:123', @Acao = 'DESFAZER';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Gravar]
    @IdUsuario   INT,
    @Unidade     VARCHAR(40),
    @Acao        VARCHAR(15),
    @Motivo      NVARCHAR(400) = N'',
    @LinhasJson  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @SemData    DATE = '1900-01-01';
    DECLARE @Qtd        INT  = 0;

    BEGIN TRY
        DROP TABLE IF EXISTS #J, #C;
        SET @Acao   = UPPER(LTRIM(RTRIM(ISNULL(@Acao, ''))));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para corrigir os casos da migração.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = @Unidade)
            SET @Recusa = N'Caso não encontrado. Atualize a lista.';
        IF @Recusa = N'' AND @Acao NOT IN ('CORRIGIR', 'IGNORAR', 'ARQUIVO_MORTO', 'DESFAZER')
            SET @Recusa = N'Ação inválida.';
        IF @Recusa = N'' AND @Acao IN ('IGNORAR', 'ARQUIVO_MORTO') AND LEN(@Motivo) < 5
            SET @Recusa = N'Escreva o motivo da decisão (pelo menos 5 letras).';
        IF @Recusa = N'' AND @Acao = 'CORRIGIR' AND ISJSON(ISNULL(@LinhasJson, N'')) = 0
            SET @Recusa = N'Lista de linhas inválida.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        IF @Acao = 'CORRIGIR'
        BEGIN
            SET @EtapaAtual = 'Leitura das linhas';
            SELECT j.origem AS ORIGEM, j.num AS NUM, j.emp AS EMP, j.parceiro AS PARCEIRO, j.conta AS CONTA, j.plano AS PLANO,
                   j.dtMovto AS DT_MOVTO, j.dtVencto AS DT_VENCTO, j.dtPagto AS DT_PAGTO,
                   ISNULL(j.debito, 0) AS DEB, ISNULL(j.credito, 0) AS CRE, ISNULL(j.confirmado, 0) AS CONF, ISNULL(j.ignorar, 0) AS IGN
            INTO #J
            FROM OPENJSON(@LinhasJson) WITH (
                    origem VARCHAR(20) '$.origem', num INT '$.num', emp INT '$.emp', parceiro INT '$.parceiro', conta INT '$.conta',
                    plano INT '$.plano', dtMovto DATE '$.dtMovto', dtVencto DATE '$.dtVencto', dtPagto DATE '$.dtPagto',
                    debito DECIMAL(18,2) '$.debito', credito DECIMAL(18,2) '$.credito', confirmado BIT '$.confirmado', ignorar BIT '$.ignorar') j;

            IF EXISTS (SELECT 1 FROM #J j WHERE NOT EXISTS (SELECT 1 FROM MIG.Movimento m WHERE m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM AND m.UNIDADE = @Unidade AND m.DESTINO = 'SISTEMA'))
                SET @Recusa = N'Uma das linhas não pertence a este documento. Atualize a tela.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.EMP IS NULL OR NOT EXISTS (SELECT 1 FROM MIG.DePara_Centro d WHERE d.CODIGO_VINCULADA = j.EMP))
                SET @Recusa = N'Escolha uma obra válida em todas as linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.CONTA IS NULL OR NOT EXISTS (SELECT 1 FROM MIG.Access_Contas_Financeiras k WHERE TRY_CONVERT(INT, k.CodigoConta) = j.CONTA))
                SET @Recusa = N'Escolha uma conta válida em todas as linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE (j.PLANO IS NULL AND m.PLANO3 IS NOT NULL)
                                            OR (j.PLANO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MIG.DePara_Plano d WHERE d.PLANO3_ACCESS = j.PLANO))))
                SET @Recusa = N'Escolha um plano de contas válido nas linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.PARCEIRO > 1 AND NOT EXISTS (SELECT 1 FROM MIG.Access_Parceiros p WHERE TRY_CONVERT(INT, p.CodigoParceiro) = j.PARCEIRO))
                SET @Recusa = N'Pessoa não encontrada no cadastro do Access.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.DEB < 0 OR j.CRE < 0)
                SET @Recusa = N'Valor não pode ser negativo.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.DEB > 0 AND j.CRE > 0)
                SET @Recusa = N'Cada linha tem débito ou crédito, não os dois.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.DT_MOVTO NOT BETWEEN '2000-01-01' AND '2060-12-31'
                                                             OR j.DT_VENCTO NOT BETWEEN '2000-01-01' AND '2060-12-31'
                                                             OR j.DT_PAGTO NOT BETWEEN '2000-01-01' AND '2060-12-31')
                SET @Recusa = N'Data fora do intervalo aceito (2000 a 2060).';
            IF @Recusa <> N''
            BEGIN
                DROP TABLE IF EXISTS #J;
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
                RETURN;
            END;

            -- só o que difere do Access vira correção (NULL = mantém o Access)
            SELECT j.ORIGEM, j.NUM,
                   CASE WHEN j.EMP = m.EMP_VINCULADA THEN NULL ELSE j.EMP END AS EMP_VINCULADA,
                   CASE WHEN ISNULL(j.PARCEIRO, 0) = ISNULL(m.PARCEIRO, 0) THEN NULL ELSE ISNULL(j.PARCEIRO, 0) END AS PARCEIRO,
                   CASE WHEN j.CONTA = m.CONTA THEN NULL ELSE j.CONTA END AS CONTA,
                   CASE WHEN j.PLANO = m.PLANO3 OR (j.PLANO IS NULL AND m.PLANO3 IS NULL) THEN NULL ELSE j.PLANO END AS PLANO3,
                   CASE WHEN j.DT_MOVTO  = m.DT_MOVTO  OR (j.DT_MOVTO  IS NULL AND m.DT_MOVTO  IS NULL) THEN NULL ELSE ISNULL(j.DT_MOVTO,  @SemData) END AS DT_MOVTO,
                   CASE WHEN j.DT_VENCTO = m.DT_VENCTO OR (j.DT_VENCTO IS NULL AND m.DT_VENCTO IS NULL) THEN NULL ELSE ISNULL(j.DT_VENCTO, @SemData) END AS DT_VENCTO,
                   CASE WHEN j.DT_PAGTO  = m.DT_PAGTO  OR (j.DT_PAGTO  IS NULL AND m.DT_PAGTO  IS NULL) THEN NULL ELSE ISNULL(j.DT_PAGTO,  @SemData) END AS DT_PAGTO,
                   CASE WHEN j.DEB = ISNULL(m.VALOR_DEBITO, 0)  THEN NULL ELSE j.DEB END AS VALOR_DEBITO,
                   CASE WHEN j.CRE = ISNULL(m.VALOR_CREDITO, 0) THEN NULL ELSE j.CRE END AS VALOR_CREDITO,
                   CASE WHEN j.CONF = m.CONFIRMADO THEN NULL ELSE j.CONF END AS CONFIRMADO,
                   j.IGN AS IGNORAR_LINHA
            INTO #C
            FROM #J j
            INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM;

            DELETE FROM #C
            WHERE EMP_VINCULADA IS NULL AND PARCEIRO IS NULL AND CONTA IS NULL AND PLANO3 IS NULL
              AND DT_MOVTO IS NULL AND DT_VENCTO IS NULL AND DT_PAGTO IS NULL
              AND VALOR_DEBITO IS NULL AND VALOR_CREDITO IS NULL AND CONFIRMADO IS NULL AND IGNORAR_LINHA = 0;
            SELECT @Qtd = COUNT(*) FROM #C;

            IF @Qtd > 0 AND LEN(@Motivo) < 5
            BEGIN
                DROP TABLE IF EXISTS #J, #C;
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Escreva o motivo da correção (pelo menos 5 letras).' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
                RETURN;
            END;

            SET @EtapaAtual = 'Gravação das correções';
            BEGIN TRANSACTION;
            DELETE FROM MIG.Caso_Correcao WHERE UNIDADE = @Unidade;

            DELETE o
            FROM MIG.Caso_Correcao_Linha o
            WHERE o.UNIDADE = @Unidade
              AND NOT EXISTS (SELECT 1 FROM #C c WHERE c.ORIGEM = o.ORIGEM AND c.NUM = o.NUM);

            UPDATE o
               SET o.EMP_VINCULADA = c.EMP_VINCULADA, o.PARCEIRO = c.PARCEIRO, o.CONTA = c.CONTA, o.PLANO3 = c.PLANO3,
                   o.DT_MOVTO = c.DT_MOVTO, o.DT_VENCTO = c.DT_VENCTO, o.DT_PAGTO = c.DT_PAGTO,
                   o.VALOR_DEBITO = c.VALOR_DEBITO, o.VALOR_CREDITO = c.VALOR_CREDITO, o.CONFIRMADO = c.CONFIRMADO,
                   o.IGNORAR_LINHA = c.IGNORAR_LINHA, o.MOTIVO = @Motivo,
                   o.DT_ALTERACAO = SYSDATETIME(), o.USUARIO_ALTERACAO = @Usuario
            FROM MIG.Caso_Correcao_Linha o
            INNER JOIN #C c ON c.ORIGEM = o.ORIGEM AND c.NUM = o.NUM
            WHERE NOT (ISNULL(o.EMP_VINCULADA, -1) = ISNULL(c.EMP_VINCULADA, -1) AND ISNULL(o.PARCEIRO, -1) = ISNULL(c.PARCEIRO, -1)
                   AND ISNULL(o.CONTA, -1) = ISNULL(c.CONTA, -1) AND ISNULL(o.PLANO3, -1) = ISNULL(c.PLANO3, -1)
                   AND ISNULL(o.DT_MOVTO, '1800-01-01') = ISNULL(c.DT_MOVTO, '1800-01-01')
                   AND ISNULL(o.DT_VENCTO, '1800-01-01') = ISNULL(c.DT_VENCTO, '1800-01-01')
                   AND ISNULL(o.DT_PAGTO, '1800-01-01') = ISNULL(c.DT_PAGTO, '1800-01-01')
                   AND ISNULL(o.VALOR_DEBITO, -1) = ISNULL(c.VALOR_DEBITO, -1) AND ISNULL(o.VALOR_CREDITO, -1) = ISNULL(c.VALOR_CREDITO, -1)
                   AND ISNULL(CONVERT(TINYINT, o.CONFIRMADO), 9) = ISNULL(CONVERT(TINYINT, c.CONFIRMADO), 9)
                   AND o.IGNORAR_LINHA = c.IGNORAR_LINHA AND o.MOTIVO = @Motivo);

            INSERT INTO MIG.Caso_Correcao_Linha (ORIGEM, NUM, UNIDADE, EMP_VINCULADA, PARCEIRO, CONTA, PLANO3, DT_MOVTO, DT_VENCTO, DT_PAGTO,
                                                 VALOR_DEBITO, VALOR_CREDITO, CONFIRMADO, IGNORAR_LINHA, MOTIVO, USUARIO_CRIACAO)
            SELECT c.ORIGEM, c.NUM, @Unidade, c.EMP_VINCULADA, c.PARCEIRO, c.CONTA, c.PLANO3, c.DT_MOVTO, c.DT_VENCTO, c.DT_PAGTO,
                   c.VALOR_DEBITO, c.VALOR_CREDITO, c.CONFIRMADO, c.IGNORAR_LINHA, @Motivo, @Usuario
            FROM #C c
            WHERE NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha o WHERE o.ORIGEM = c.ORIGEM AND o.NUM = c.NUM);
            COMMIT TRANSACTION;

            DROP TABLE IF EXISTS #J, #C;
            SELECT CAST(1 AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Qtd = 0 THEN N'Sem correções: o documento fica como está no Access.'
                             ELSE N'Correção gravada (' + CONVERT(NVARCHAR(10), @Qtd) + CASE WHEN @Qtd = 1 THEN N' linha).' ELSE N' linhas).' END END AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação da decisão';
        BEGIN TRANSACTION;
        IF @Acao = 'DESFAZER'
        BEGIN
            DELETE FROM MIG.Caso_Correcao WHERE UNIDADE = @Unidade;
            DELETE FROM MIG.Caso_Correcao_Linha WHERE UNIDADE = @Unidade;
        END
        ELSE
        BEGIN
            UPDATE MIG.Caso_Correcao
               SET ACAO = @Acao, MOTIVO = @Motivo, DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
            WHERE UNIDADE = @Unidade AND (ACAO <> @Acao OR MOTIVO <> @Motivo);
            INSERT INTO MIG.Caso_Correcao (UNIDADE, ACAO, MOTIVO, USUARIO_CRIACAO)
            SELECT @Unidade, @Acao, @Motivo, @Usuario
            WHERE NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao WHERE UNIDADE = @Unidade);
        END;
        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE @Acao WHEN 'DESFAZER' THEN N'Correções desfeitas: o documento volta a ser como está no Access.'
                               WHEN 'IGNORAR' THEN N'Documento marcado para não migrar.'
                               ELSE N'Documento marcado para o arquivo morto.' END AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #J, #C;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a correção. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
