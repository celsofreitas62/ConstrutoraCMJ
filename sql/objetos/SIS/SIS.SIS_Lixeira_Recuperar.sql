/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Recuperar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Botão Recuperar da tela Sistema › Lixeira (P20): o registro
                volta como estava antes de ir para a lixeira (ativo ou
                desativado). Antes confere:
                  - os campos únicos configurados (SIS.Tabela_Config.
                    CAMPOS_UNICOS, ex.: CPF/CNPJ): se outro registro vivo tiver
                    o mesmo valor, recusa e mostra qual é;
                  - se algum registro ligado (chave estrangeira) está na
                    lixeira: recupere esse antes;
                  - as travas (mês fechado e trava própria).
                Permissão: RECUPERAR em SIS_LIXEIRA e VER na tela do registro.
                Devolve 1 linha: SUCESSO, MENSAGEM, TABELA, ID_REGISTRO.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Recuperar @IdUsuario = 2, @IdLixeira = 1, @Motivo = N'excluído por engano';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Recuperar]
    @IdUsuario  INT,
    @IdLixeira  BIGINT,
    @Motivo     NVARCHAR(400) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Recuperar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @TranCountEntrada INT = @@TRANCOUNT;
    DECLARE @Recusa NVARCHAR(400) = N'', @Tabela NVARCHAR(256), @IdRegistro BIGINT, @Item VARCHAR(40), @AtivoAntes BIT;
    DECLARE @ObjId INT, @Pk NVARCHAR(128), @Nome NVARCHAR(300), @Sql NVARCHAR(MAX), @Usuario NVARCHAR(100);
    DECLARE @Campos TABLE (ORDEM INT IDENTITY(1,1), CAMPO NVARCHAR(128));
    DECLARE @Fks TABLE (ORDEM INT IDENTITY(1,1), COLUNA NVARCHAR(128), TABELA_REF NVARCHAR(256));
    DECLARE @i INT, @Total INT, @Campo NVARCHAR(128), @Outro BIGINT, @Ref BIGINT, @TabRef NVARCHAR(256), @DescSql NVARCHAR(1000), @DescOutro NVARCHAR(400);
    DECLARE @TemAlteracao BIT, @Linhas INT;

    BEGIN TRY
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        SELECT @Tabela = l.TABELA, @IdRegistro = l.ID_REGISTRO, @Item = l.ITEM_CODIGO, @AtivoAntes = l.ATIVO_ANTES
        FROM SIS.Lixeira l
        WHERE l.ID_LIXEIRA = @IdLixeira;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'RECUPERAR') = 0
            SET @Recusa = N'Você não tem permissão para recuperar registros da lixeira.';
        ELSE IF @Tabela IS NULL
            SET @Recusa = N'Registro da lixeira não encontrado.';
        ELSE IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            SET @Recusa = N'Você não tem permissão para ver a tela deste registro.';
        ELSE IF NOT EXISTS (SELECT 1 FROM SIS.Lixeira l WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA')
            SET @Recusa = N'O registro não está mais na lixeira.';

        SET @ObjId = OBJECT_ID(@Tabela, N'U');
        SET @Pk = SIS.fn_SIS_Tabela_PK(@Tabela);
        IF @Recusa = N'' AND (@ObjId IS NULL OR @Pk = N'')
            SET @Recusa = N'Tabela do registro não encontrada.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@Tabela AS NVARCHAR(256)) AS TABELA, @IdRegistro AS ID_REGISTRO;
            RETURN;
        END;

        SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));
        SELECT @DescSql = NULLIF(LTRIM(RTRIM(c.DESCRICAO_SQL)), N'') FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela;

        -- Campos únicos contra os registros vivos
        SET @EtapaAtual = 'Campos únicos';
        INSERT INTO @Campos (CAMPO)
        SELECT LTRIM(RTRIM(s.value))
        FROM SIS.Tabela_Config c
        CROSS APPLY STRING_SPLIT(c.CAMPOS_UNICOS, N',') s
        WHERE c.TABELA = @Tabela AND LTRIM(RTRIM(s.value)) <> N'' AND COL_LENGTH(@Tabela, LTRIM(RTRIM(s.value))) IS NOT NULL;

        SELECT @i = 1, @Total = COUNT(*) FROM @Campos;
        WHILE @i <= @Total AND @Recusa = N''
        BEGIN
            SELECT @Campo = c.CAMPO FROM @Campos c WHERE c.ORDEM = @i;
            SET @Outro = NULL;
            SET @Sql = N'SELECT TOP 1 @Outro = o.' + QUOTENAME(@Pk) + N', @Desc = LEFT(CONVERT(NVARCHAR(MAX), '
                     + ISNULL(REPLACE(@DescSql, N't.', N'o.'), N'CAST(o.' + QUOTENAME(@Pk) + N' AS NVARCHAR(30))') + N'), 400)'
                     + N' FROM ' + @Nome + N' o INNER JOIN ' + @Nome + N' t ON t.' + QUOTENAME(@Pk) + N' = @Id'
                     + N' WHERE o.' + QUOTENAME(@Pk) + N' <> @Id AND o.DT_EXCLUSAO IS NULL'
                     + N' AND ISNULL(CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(@Campo) + N'), N'''') <> N'''''
                     + N' AND o.' + QUOTENAME(@Campo) + N' = t.' + QUOTENAME(@Campo)
                     + N' ORDER BY o.' + QUOTENAME(@Pk) + N';';
            EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Outro BIGINT OUTPUT, @Desc NVARCHAR(400) OUTPUT', @Id = @IdRegistro, @Outro = @Outro OUTPUT, @Desc = @DescOutro OUTPUT;
            IF @Outro IS NOT NULL
                SET @Recusa = LEFT(N'Já existe outro cadastro com o mesmo ' + @Campo + N': ' + ISNULL(@DescOutro, N'') + N' (código ' + CAST(@Outro AS NVARCHAR(20))
                            + N'). Confira se é o mesmo antes de recuperar.', 400);
            SET @i = @i + 1;
        END;

        -- Registros ligados que estão na lixeira
        SET @EtapaAtual = 'Registros ligados';
        IF @Recusa = N''
        BEGIN
            INSERT INTO @Fks (COLUNA, TABELA_REF)
            SELECT pc.name, OBJECT_SCHEMA_NAME(fk.referenced_object_id) + N'.' + OBJECT_NAME(fk.referenced_object_id)
            FROM sys.foreign_keys fk
            INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
            INNER JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
            WHERE fk.parent_object_id = @ObjId
              AND (SELECT COUNT(*) FROM sys.foreign_key_columns x WHERE x.constraint_object_id = fk.object_id) = 1;

            SELECT @i = 1, @Total = COUNT(*) FROM @Fks;
            WHILE @i <= @Total AND @Recusa = N''
            BEGIN
                SELECT @Campo = f.COLUNA, @TabRef = f.TABELA_REF FROM @Fks f WHERE f.ORDEM = @i;
                SET @Ref = NULL;
                SET @Sql = N'SELECT @Ref = TRY_CONVERT(BIGINT, t.' + QUOTENAME(@Campo) + N') FROM ' + @Nome + N' t WHERE t.' + QUOTENAME(@Pk) + N' = @Id;';
                EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Ref BIGINT OUTPUT', @Id = @IdRegistro, @Ref = @Ref OUTPUT;
                IF @Ref IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(@TabRef, @Ref) = 1
                    SET @Recusa = LEFT(N'Este registro está ligado a outro que também está na lixeira ('
                                + ISNULL((SELECT TOP 1 l.DESCRICAO FROM SIS.Lixeira l WHERE l.TABELA = @TabRef AND l.ID_REGISTRO = @Ref AND l.SITUACAO = 'LIXEIRA'), N'')
                                + N'). Recupere aquele antes.', 400);
                SET @i = @i + 1;
            END;
        END;

        IF @Recusa = N''
        BEGIN
            EXEC SIS.SIS_Tabela_Trava_Conferir @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = 'RECUPERAR', @Mensagem = @Recusa OUTPUT;
            SET @Recusa = ISNULL(@Recusa, N'');
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@Tabela AS NVARCHAR(256)) AS TABELA, @IdRegistro AS ID_REGISTRO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @TemAlteracao = CASE WHEN COL_LENGTH(@Tabela, N'DT_ALTERACAO') IS NOT NULL AND COL_LENGTH(@Tabela, N'USUARIO_ALTERACAO') IS NOT NULL THEN 1 ELSE 0 END;
        SET @Sql = N'UPDATE t SET t.ATIVO = @Ativo, t.DT_EXCLUSAO = NULL, t.USUARIO_EXCLUSAO = NULL'
                 + CASE WHEN @TemAlteracao = 1 THEN N', t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario' ELSE N'' END
                 + N' FROM ' + @Nome + N' t WHERE t.' + QUOTENAME(@Pk) + N' = @Id AND t.DT_EXCLUSAO IS NOT NULL; SET @n = @@ROWCOUNT;';

        IF @TranCountEntrada = 0 BEGIN TRANSACTION;
            EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Ativo BIT, @Usuario NVARCHAR(100), @n INT OUTPUT',
                 @Id = @IdRegistro, @Ativo = @AtivoAntes, @Usuario = @Usuario, @n = @Linhas OUTPUT;

            UPDATE l
               SET l.SITUACAO = 'RECUPERADO', l.DT_SITUACAO = SYSDATETIME(), l.USUARIO_SITUACAO = ISNULL(@Usuario, N''),
                   l.MOTIVO_SITUACAO = @Motivo, l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = ISNULL(@Usuario, N'')
            FROM SIS.Lixeira l
            WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA';
        IF @TranCountEntrada = 0 COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @AtivoAntes = 1 THEN N'Registro recuperado: voltou ativo.' ELSE N'Registro recuperado: voltou desativado, como estava antes de ir para a lixeira.' END AS NVARCHAR(400)) AS MENSAGEM,
               CAST(@Tabela AS NVARCHAR(256)) AS TABELA, @IdRegistro AS ID_REGISTRO;
    END TRY
    BEGIN CATCH
        IF @TranCountEntrada = 0 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível recuperar o registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(@Tabela AS NVARCHAR(256)) AS TABELA, @IdRegistro AS ID_REGISTRO;
    END CATCH;
END;
GO
