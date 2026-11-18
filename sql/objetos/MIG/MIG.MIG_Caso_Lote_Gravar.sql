/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Lote_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Ações em lote da tela "Casos da migração": a mesma decisão para
                vários documentos de uma vez (os marcados na lista, ou "Selecionar
                todos" com os filtros). @Acao:
                  IGNORAR        os documentos não migram (motivo obrigatório);
                  ARQUIVO_MORTO  vão para o arquivo morto (motivo obrigatório);
                  DESFAZER       apagam todas as correções e decisões deles.
                @UnidadesJson: lista JSON dos documentos (ex.: ["L:12","V:7"]),
                até 1.000 por vez. Cada decisão guarda a impressão digital do
                documento no Access (aviso "Revisar"). Tudo-ou-nada. Depois de
                gravar, a tela chama MIG_Caso_Conferir com a mesma lista.
                Permissão: ALTERAR em MIG_CASOS.
                Devolve SUCESSO, MENSAGEM, ID (= quantidade de documentos).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, "selecionar todos" na tela de casos).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Lote_Gravar @IdUsuario = 1, @Acao = 'IGNORAR', @Motivo = N'Estornos', @UnidadesJson = N'["L:12","A:345"]';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Lote_Gravar]
    @IdUsuario     INT,
    @Acao          VARCHAR(15),
    @Motivo        NVARCHAR(400) = N'',
    @UnidadesJson  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Lote_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Qtd        INT = 0;

    BEGIN TRY
        DROP TABLE IF EXISTS #Sel;
        SET @Acao   = UPPER(LTRIM(RTRIM(ISNULL(@Acao, ''))));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para corrigir os casos da migração.';
        IF @Recusa = N'' AND @Acao NOT IN ('IGNORAR', 'ARQUIVO_MORTO', 'DESFAZER')
            SET @Recusa = N'Ação inválida.';
        IF @Recusa = N'' AND @Acao IN ('IGNORAR', 'ARQUIVO_MORTO') AND LEN(@Motivo) < 5
            SET @Recusa = N'Escreva o motivo da decisão (pelo menos 5 letras).';
        IF @Recusa = N'' AND ISJSON(ISNULL(@UnidadesJson, N'')) = 0
            SET @Recusa = N'Lista de documentos inválida.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS BIGINT) AS ID;
            RETURN;
        END;

        SELECT DISTINCT CAST(LEFT(j.value, 40) AS VARCHAR(40)) AS UNIDADE
        INTO #Sel
        FROM OPENJSON(@UnidadesJson) j
        WHERE j.value IS NOT NULL;
        SELECT @Qtd = COUNT(*) FROM #Sel;

        IF @Qtd = 0
            SET @Recusa = N'Escolha pelo menos um documento.';
        IF @Recusa = N'' AND @Qtd > 1000
            SET @Recusa = N'No máximo 1.000 documentos por vez. Use os filtros para separar.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Sel s WHERE NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = s.UNIDADE))
            SET @Recusa = N'Algum documento não está mais na lista. Atualize a tela e tente de novo.';
        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Sel;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;
        IF @Acao = 'DESFAZER'
        BEGIN
            DELETE cc FROM MIG.Caso_Correcao cc INNER JOIN #Sel s ON s.UNIDADE = cc.UNIDADE;
            DELETE o  FROM MIG.Caso_Correcao_Linha o INNER JOIN #Sel s ON s.UNIDADE = o.UNIDADE;
        END
        ELSE
        BEGIN
            UPDATE cc
               SET cc.ACAO = @Acao, cc.MOTIVO = @Motivo, cc.HASH_ACCESS = MIG.fn_MIG_Hash_Unidade(cc.UNIDADE),
                   cc.DT_ALTERACAO = SYSDATETIME(), cc.USUARIO_ALTERACAO = @Usuario
            FROM MIG.Caso_Correcao cc
            INNER JOIN #Sel s ON s.UNIDADE = cc.UNIDADE
            WHERE cc.ACAO <> @Acao OR cc.MOTIVO <> @Motivo OR ISNULL(cc.HASH_ACCESS, 0x) <> ISNULL(MIG.fn_MIG_Hash_Unidade(cc.UNIDADE), 0x);

            INSERT INTO MIG.Caso_Correcao (UNIDADE, ACAO, MOTIVO, HASH_ACCESS, USUARIO_CRIACAO)
            SELECT s.UNIDADE, @Acao, @Motivo, MIG.fn_MIG_Hash_Unidade(s.UNIDADE), @Usuario
            FROM #Sel s
            WHERE NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao cc WHERE cc.UNIDADE = s.UNIDADE);
        END;
        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Sel;
        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CONVERT(NVARCHAR(10), @Qtd) + CASE WHEN @Qtd = 1 THEN N' documento ' ELSE N' documentos ' END
                    + CASE @Acao WHEN 'DESFAZER' THEN N'voltaram a ser como estão no Access.'
                                 WHEN 'IGNORAR' THEN N'marcados para não migrar.'
                                 ELSE N'marcados para o arquivo morto.' END AS NVARCHAR(400)) AS MENSAGEM,
               CAST(@Qtd AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Sel;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a decisão em lote. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS BIGINT) AS ID;
    END CATCH;
END;
GO
