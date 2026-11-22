/*******************************************************************************
  Objeto      : [SIS].[SIS_Historico_Desfazer]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Desfaz pelo histórico (P20), depois da prévia
                (SIS_Historico_Desfazer_Previa): voltar um registro a um ponto
                do histórico (REGISTRO), desfazer uma operação (OPERACAO) ou
                um lote inteiro (LOTE, tela de Auditoria).
                Tudo-ou-nada: se houver qualquer CONFLITO ou BLOQUEADO, não
                faz nada. Grava como alteração nova (a auditoria registra
                tudo, com a origem "desfazer"), as inclusões desfeitas vão para
                a lixeira, são desativadas ou retiradas (tabelas de ligação),
                as exclusões de tabelas de ligação voltam com a foto da
                auditoria (código novo), e o pedido fica em SIS.Desfazer
                com o motivo (obrigatório).
                Permissão: DESFAZER na tela (@Item) e, para cada tipo de
                registro que vai mudar, DESFAZER numa tela que o mostra.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_DESFAZER, QTD_REGISTROS,
                QTD_CAMPOS, QTD_LIXEIRA.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Historico_Desfazer @IdUsuario = 2, @Item = 'CAD_PESSOA', @Modo = 'OPERACAO', @IdAuditoria = 10, @Motivo = N'alterado por engano';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Historico_Desfazer]
    @IdUsuario    INT,
    @Item         VARCHAR(40),
    @Modo         VARCHAR(10),
    @Tabela       NVARCHAR(256) = NULL,
    @IdRegistro   BIGINT        = NULL,
    @IdAuditoria  BIGINT        = NULL,
    @DataHora     DATETIME2(0)  = NULL,
    @IdLote       BIGINT        = NULL,
    @Motivo       NVARCHAR(400) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Historico_Desfazer]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @Recusa NVARCHAR(400) = N'', @Usuario NVARCHAR(100), @OrigemAntes NVARCHAR(256), @OrigemNova NVARCHAR(256);
    DECLARE @Muda INT, @Impede INT, @QtdReg INT, @QtdCampos INT, @QtdLixeira INT, @IdDesfazer BIGINT, @Transacao BIGINT;
    DECLARE @Alt TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(256), CAMPO NVARCHAR(128), QTD INT);
    DECLARE @Lix TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(256), ID_REGISTRO BIGINT);
    DECLARE @Apg TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(256), QTD INT);
    DECLARE @Rei TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(256), FOTO NVARCHAR(MAX));
    DECLARE @Foto NVARCHAR(MAX), @Cols NVARCHAR(MAX), @With NVARCHAR(MAX);
    DECLARE @i INT, @Total INT, @T NVARCHAR(256), @C NVARCHAR(128), @Qtd INT, @Feitos INT, @Id BIGINT;
    DECLARE @ObjId INT, @Pk NVARCHAR(128), @Nome NVARCHAR(300), @Tipo NVARCHAR(128), @EData BIT, @Expr NVARCHAR(400), @Sql NVARCHAR(MAX), @IdLixeira BIGINT, @Msg NVARCHAR(400);
    DECLARE @TelaSemPermissao NVARCHAR(256);

    DROP TABLE IF EXISTS #Desfazer_Plano;

    BEGIN TRY
        SET @Modo   = UPPER(LTRIM(RTRIM(ISNULL(@Modo, ''))));
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'DESFAZER') = 0
            SET @Recusa = N'Você não tem permissão para desfazer nesta tela.';
        ELSE IF @Modo NOT IN ('REGISTRO', 'OPERACAO', 'LOTE')
            SET @Recusa = N'Modo de desfazer inválido.';
        ELSE IF @Modo = 'REGISTRO' AND (SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0 OR @IdRegistro IS NULL OR (@IdAuditoria IS NULL AND @DataHora IS NULL))
            SET @Recusa = N'Escolha o registro e o ponto do histórico para onde voltar.';
        ELSE IF @Modo = 'OPERACAO' AND @IdAuditoria IS NULL
            SET @Recusa = N'Escolha a operação a desfazer.';
        ELSE IF @Modo = 'LOTE' AND (@Item <> 'SIS_AUDITORIA' OR @IdLote IS NULL)
            SET @Recusa = N'Escolha o lote a desfazer (tela de Auditoria).';
        ELSE IF LEN(@Motivo) < 3
            SET @Recusa = N'Informe o motivo do desfazer.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_DESFAZER, 0 AS QTD_REGISTROS, 0 AS QTD_CAMPOS, 0 AS QTD_LIXEIRA;
            RETURN;
        END;

        SET @EtapaAtual = 'Montagem';
        CREATE TABLE #Desfazer_Plano
        (
            ORDEM             INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            TABELA            NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL,
            ID_REGISTRO       BIGINT        NOT NULL,
            DESCRICAO         NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
            CAMPO             NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
            VALOR_ATUAL       NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
            VALOR_NOVO        NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
            ACAO              VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
            SITUACAO          VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
            MENSAGEM          NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
            ULTIMA_AUDITORIA  BIGINT        NULL
        );

        EXEC SIS.SIS_Historico_Desfazer_Montar @Modo = @Modo, @Tabela = @Tabela, @IdRegistro = @IdRegistro,
             @IdAuditoria = @IdAuditoria, @DataHora = @DataHora, @IdLote = @IdLote;

        SELECT @Muda = COUNT(*) FROM #Desfazer_Plano WHERE ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR', 'REINSERIR');
        SELECT @Impede = COUNT(*) FROM #Desfazer_Plano WHERE SITUACAO IN ('CONFLITO', 'BLOQUEADO');

        IF @Impede > 0
            SET @Recusa = LEFT(N'Nada foi desfeito: ' + CAST(@Impede AS NVARCHAR(10)) + N' ponto(s) impedem. '
                        + ISNULL((SELECT TOP 1 p.MENSAGEM FROM #Desfazer_Plano p WHERE p.SITUACAO IN ('CONFLITO', 'BLOQUEADO')
                                  ORDER BY CASE p.SITUACAO WHEN 'BLOQUEADO' THEN 0 ELSE 1 END, p.ORDEM), N''), 400);
        ELSE IF @Muda = 0
            SET @Recusa = N'Nada a desfazer: já está tudo como estava.';

        -- Permissão para cada tipo de registro que vai mudar
        IF @Recusa = N''
        BEGIN
            SELECT TOP 1 @TelaSemPermissao = p.TABELA
            FROM (SELECT DISTINCT TABELA FROM #Desfazer_Plano WHERE ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR', 'REINSERIR')) p
            WHERE NOT EXISTS (SELECT 1 FROM SIS.Item it
                              CROSS APPLY STRING_SPLIT(it.TABELAS_DA_TELA, ',') s
                              WHERE LTRIM(RTRIM(s.value)) = p.TABELA AND it.TIPO = 'TELA'
                                AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, it.CODIGO, 'DESFAZER') = 1)
            ORDER BY p.TABELA;
            IF @TelaSemPermissao IS NOT NULL
                SET @Recusa = LEFT(N'Você não tem permissão para desfazer em ' + ISNULL((SELECT i.NOME FROM SIS.Item i WHERE i.CODIGO = SIS.fn_SIS_Item_Da_Tabela(@TelaSemPermissao)), @TelaSemPermissao) + N'.', 400);
        END;

        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Desfazer_Plano;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_DESFAZER, 0 AS QTD_REGISTROS, 0 AS QTD_CAMPOS, 0 AS QTD_LIXEIRA;
            RETURN;
        END;

        INSERT INTO @Alt (TABELA, CAMPO, QTD)
        SELECT p.TABELA, p.CAMPO, COUNT(*) FROM #Desfazer_Plano p WHERE p.ACAO = 'ALTERAR' GROUP BY p.TABELA, p.CAMPO ORDER BY p.TABELA, p.CAMPO;
        INSERT INTO @Lix (TABELA, ID_REGISTRO)
        SELECT p.TABELA, p.ID_REGISTRO FROM #Desfazer_Plano p WHERE p.ACAO = 'LIXEIRA' ORDER BY p.ORDEM DESC;
        INSERT INTO @Apg (TABELA, QTD)
        SELECT p.TABELA, COUNT(*) FROM #Desfazer_Plano p WHERE p.ACAO = 'APAGAR' GROUP BY p.TABELA ORDER BY p.TABELA;
        INSERT INTO @Rei (TABELA, FOTO)
        SELECT p.TABELA, p.VALOR_NOVO FROM #Desfazer_Plano p WHERE p.ACAO = 'REINSERIR' ORDER BY p.ORDEM;

        SELECT @QtdReg = COUNT(*) FROM (SELECT DISTINCT TABELA, ID_REGISTRO FROM #Desfazer_Plano WHERE ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR', 'REINSERIR')) x;
        SELECT @QtdCampos = COUNT(*) FROM #Desfazer_Plano WHERE ACAO = 'ALTERAR';
        SELECT @QtdLixeira = COUNT(*) FROM @Lix;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @OrigemAntes = ISNULL(CONVERT(NVARCHAR(256), SESSION_CONTEXT(N'ORIGEM')), N'');
        SET @OrigemNova = LEFT(CASE WHEN @OrigemAntes = N'' THEN N'' ELSE @OrigemAntes + N' › ' END + N'desfazer', 256);

        SET @EtapaAtual = 'Gravação';
        IF @TranCountEntrada = 0 BEGIN TRANSACTION;

            EXEC sys.sp_set_session_context @key = N'ORIGEM', @value = @OrigemNova;
            SET @Transacao = CURRENT_TRANSACTION_ID();

            -- Inclusões de tabelas de ligação: retiradas
            SELECT @i = 1, @Total = COUNT(*) FROM @Apg;
            WHILE @i <= @Total
            BEGIN
                SELECT @T = a.TABELA, @Qtd = a.QTD FROM @Apg a WHERE a.ORDEM = @i;
                SET @ObjId = OBJECT_ID(@T, N'U');
                SET @Pk = SIS.fn_SIS_Tabela_PK(@T);
                SET @Sql = N'DELETE t FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N' t'
                         + N' INNER JOIN #Desfazer_Plano p ON p.ID_REGISTRO = t.' + QUOTENAME(@Pk) + N' WHERE p.TABELA = @T AND p.ACAO = ''APAGAR''; SET @n = @@ROWCOUNT;';
                SET @Feitos = 0;
                EXEC sys.sp_executesql @Sql, N'@T NVARCHAR(256), @n INT OUTPUT', @T = @T, @n = @Feitos OUTPUT;
                IF ISNULL(@Feitos, 0) <> @Qtd
                    THROW 50003, N'Nada foi desfeito: alguém mudou estes registros enquanto a prévia estava aberta. Abra a prévia de novo.', 1;
                SET @i = @i + 1;
            END;

            -- Campos: um UPDATE por tabela e campo, só onde o valor de hoje ainda é o da prévia
            SELECT @i = 1, @Total = COUNT(*) FROM @Alt;
            WHILE @i <= @Total
            BEGIN
                SELECT @T = a.TABELA, @C = a.CAMPO, @Qtd = a.QTD FROM @Alt a WHERE a.ORDEM = @i;
                SET @ObjId = OBJECT_ID(@T, N'U');
                SET @Pk = SIS.fn_SIS_Tabela_PK(@T);
                SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));
                SET @Tipo = SIS.fn_SIS_Coluna_Tipo(@T, @C);
                SET @EData = CASE WHEN @Tipo LIKE N'DATE%' OR @Tipo LIKE N'TIME%' OR @Tipo LIKE N'SMALLDATETIME%' THEN 1 ELSE 0 END;
                SET @Expr = CASE WHEN @EData = 1 THEN N'CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(@C) + N', 121)' ELSE N'CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(@C) + N')' END;

                SET @Sql = N'UPDATE t SET t.' + QUOTENAME(@C) + N' = CONVERT(' + @Tipo + N', p.VALOR_NOVO' + CASE WHEN @EData = 1 THEN N', 121' ELSE N'' END + N')'
                         + CASE WHEN COL_LENGTH(@T, N'DT_ALTERACAO') IS NOT NULL AND COL_LENGTH(@T, N'USUARIO_ALTERACAO') IS NOT NULL AND @C NOT IN (N'DT_ALTERACAO', N'USUARIO_ALTERACAO')
                                THEN N', t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario' ELSE N'' END
                         + N' FROM ' + @Nome + N' t INNER JOIN #Desfazer_Plano p ON p.ID_REGISTRO = t.' + QUOTENAME(@Pk)
                         + N' WHERE p.TABELA = @T AND p.CAMPO = @C AND p.ACAO = ''ALTERAR'''
                         + N' AND ((' + @Expr + N' IS NULL AND p.VALOR_ATUAL IS NULL) OR (' + @Expr + N' COLLATE Latin1_General_BIN2 = p.VALOR_ATUAL COLLATE Latin1_General_BIN2));'
                         + N' SET @n = @@ROWCOUNT;';
                SET @Feitos = 0;
                EXEC sys.sp_executesql @Sql, N'@T NVARCHAR(256), @C NVARCHAR(128), @Usuario NVARCHAR(100), @n INT OUTPUT', @T = @T, @C = @C, @Usuario = @Usuario, @n = @Feitos OUTPUT;
                IF ISNULL(@Feitos, 0) <> @Qtd
                    THROW 50003, N'Nada foi desfeito: alguém mudou estes registros enquanto a prévia estava aberta. Abra a prévia de novo.', 1;
                SET @i = @i + 1;
            END;

            -- Exclusões de tabelas de ligação: voltam com a foto da auditoria (código novo)
            SELECT @i = 1, @Total = COUNT(*) FROM @Rei;
            WHILE @i <= @Total
            BEGIN
                SELECT @T = r.TABELA, @Foto = r.FOTO FROM @Rei r WHERE r.ORDEM = @i;
                SET @ObjId = OBJECT_ID(@T, N'U');
                SELECT @Cols = STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), N', ') WITHIN GROUP (ORDER BY c.column_id),
                       @With = STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name) + N' ' + SIS.fn_SIS_Coluna_Tipo(@T, c.name) + N' ''$.' + REPLACE(c.name, N'''', N'''''') + N''''), N', ')
                                 WITHIN GROUP (ORDER BY c.column_id)
                FROM sys.columns c
                INNER JOIN sys.types ty ON ty.system_type_id = c.system_type_id AND ty.user_type_id = c.system_type_id
                WHERE c.object_id = @ObjId AND c.is_identity = 0 AND c.is_computed = 0
                  AND c.name NOT IN (N'DT_CRIACAO', N'USUARIO_CRIACAO', N'DT_ALTERACAO', N'USUARIO_ALTERACAO')
                  AND ty.name NOT IN ('varbinary', 'binary', 'image', 'timestamp', 'text', 'ntext', 'geography', 'geometry');
                SET @Sql = N'INSERT INTO ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N' (' + @Cols + N')'
                         + N' SELECT ' + @Cols + N' FROM OPENJSON(@Foto) WITH (' + @With + N');';
                BEGIN TRY
                    EXEC sys.sp_executesql @Sql, N'@Foto NVARCHAR(MAX)', @Foto = @Foto;
                END TRY
                BEGIN CATCH
                    IF ERROR_NUMBER() IN (2601, 2627)
                        THROW 50003, N'Nada foi desfeito: um registro apagado não pode voltar porque já existe outro igual.', 1;
                    THROW;
                END CATCH;
                SET @i = @i + 1;
            END;

            -- Inclusões desfeitas: para a lixeira (das filhas para o principal)
            SELECT @i = 1, @Total = COUNT(*) FROM @Lix;
            WHILE @i <= @Total
            BEGIN
                SELECT @T = l.TABELA, @Id = l.ID_REGISTRO FROM @Lix l WHERE l.ORDEM = @i;
                SET @Msg = N'';
                EXEC SIS.SIS_Lixeira_Marcar @IdUsuario = @IdUsuario, @Tabela = @T, @IdRegistro = @Id, @Item = NULL,
                     @Motivo = @Motivo, @IdLixeira = @IdLixeira OUTPUT, @Mensagem = @Msg OUTPUT;
                IF ISNULL(@Msg, N'') <> N''
                BEGIN
                    SET @Msg = LEFT(N'Nada foi desfeito: um registro incluído não pôde ir para a lixeira. ' + @Msg, 400);
                    THROW 50003, @Msg, 1;
                END;
                SET @i = @i + 1;
            END;

            INSERT INTO SIS.Desfazer (TIPO, ITEM_CODIGO, TABELA, ID_REGISTRO, ID_AUDITORIA, DT_ALVO, TRANSACAO_ALVO, ID_LOTE_ALVO, MOTIVO,
                                      QTD_REGISTROS, QTD_CAMPOS, QTD_LIXEIRA, TRANSACAO, ID_USUARIO, USUARIO)
            VALUES (@Modo, ISNULL(@Item, ''), @Tabela, @IdRegistro, @IdAuditoria, @DataHora,
                    CASE WHEN @Modo = 'OPERACAO' THEN (SELECT a.TRANSACAO FROM SIS.Auditoria a WHERE a.ID_AUDITORIA = @IdAuditoria) END,
                    @IdLote, @Motivo, ISNULL(@QtdReg, 0), ISNULL(@QtdCampos, 0), ISNULL(@QtdLixeira, 0), @Transacao, @IdUsuario, ISNULL(@Usuario, N''));
            SET @IdDesfazer = SCOPE_IDENTITY();

            EXEC sys.sp_set_session_context @key = N'ORIGEM', @value = @OrigemAntes;
        IF @TranCountEntrada = 0 COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Desfazer_Plano;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Desfeito: ' + CAST(ISNULL(@QtdCampos, 0) AS NVARCHAR(10)) + N' campo(s) em ' + CAST(ISNULL(@QtdReg, 0) AS NVARCHAR(10)) + N' registro(s)'
                    + CASE WHEN @QtdLixeira > 0 THEN N'; ' + CAST(@QtdLixeira AS NVARCHAR(10)) + N' registro(s) incluído(s) foram para a lixeira' ELSE N'' END
                    + CASE WHEN (SELECT ISNULL(SUM(a.QTD), 0) FROM @Apg a) > 0 THEN N'; ' + CAST((SELECT SUM(a.QTD) FROM @Apg a) AS NVARCHAR(10)) + N' retirado(s)' ELSE N'' END
                    + CASE WHEN (SELECT COUNT(*) FROM @Rei) > 0 THEN N'; ' + CAST((SELECT COUNT(*) FROM @Rei) AS NVARCHAR(10)) + N' devolvido(s)' ELSE N'' END
                    + N'. Tudo ficou no histórico.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdDesfazer AS ID_DESFAZER, ISNULL(@QtdReg, 0) AS QTD_REGISTROS, ISNULL(@QtdCampos, 0) AS QTD_CAMPOS, ISNULL(@QtdLixeira, 0) AS QTD_LIXEIRA;
    END TRY
    BEGIN CATCH
        IF @TranCountEntrada = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
        BEGIN
            EXEC sys.sp_set_session_context @key = N'ORIGEM', @value = @OrigemAntes;
            DROP TABLE IF EXISTS #Desfazer_Plano;
            IF ERROR_NUMBER() <> 50003
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(CASE WHEN ERROR_NUMBER() = 50003 THEN ERROR_MESSAGE() ELSE N'Não foi possível desfazer. Nada foi alterado; o erro foi registrado para análise.' END AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_DESFAZER, 0 AS QTD_REGISTROS, 0 AS QTD_CAMPOS, 0 AS QTD_LIXEIRA;
    END CATCH;
END;
GO
