/*******************************************************************************
  Objeto      : [SIS].[SIS_Auditoria_Trigger_Gerar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Gera (e, com @Criar = 1, cria) a trigger de auditoria de uma
                tabela, lendo a estrutura dela no próprio banco: nenhuma
                trigger de auditoria é escrita à mão, e nenhum campo fica de
                fora por esquecimento.
                A trigger gerada ([SCHEMA].[tg_SCHEMA_Tabela_Auditoria],
                AFTER INSERT, UPDATE, DELETE, set-based, sem variável de I/U/D,
                PADRAO_SQL regras 6 e 34) grava em SIS.Auditoria:
                  inclusão/exclusão: 1 linha com o registro inteiro em JSON;
                  alteração: 1 linha por campo que mudou (texto comparado em
                  binário, para pegar até mudança de maiúscula/minúscula).
                Parâmetros:
                  @Tabela          'SCHEMA.Tabela' (precisa ter chave primária
                                   de uma coluna só)
                  @CamposIgnorados não geram linha de alteração (ex.: contador
                                   de tentativas). DT_/USUARIO_ CRIACAO e
                                   ALTERACAO e a chave já são ignorados.
                  @CamposSigilosos aparecem como "***" (ex.: hash de senha).
                                   Colunas binárias são sempre sigilosas.
                  @Criar           0 = só devolve o script (coluna SCRIPT);
                                   1 = cria/atualiza a trigger.
                Quando a tabela ganha coluna nova, basta rodar de novo.
                No MASTER, a parte 8 (triggers) chama esta procedure para cada
                tabela auditada (Carga_SIS_Auditoria_Triggers.sql), em vez de
                guardar o texto das triggers: o resultado é sempre o mesmo
                para a mesma estrutura de tabela.
                Automação: em erro, registra em SIS.Log_Erro e relança.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro';            -- só mostra o script
    -- EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro', @Criar = 1; -- cria
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Auditoria_Trigger_Gerar]
    @Tabela           NVARCHAR(256),
    @CamposIgnorados  NVARCHAR(MAX) = NULL,
    @CamposSigilosos  NVARCHAR(MAX) = NULL,
    @Criar            BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Auditoria_Trigger_Gerar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @NL           NCHAR(2)      = NCHAR(13) + NCHAR(10);
    DECLARE @Sep          NVARCHAR(10)  = N',' + NCHAR(13) + NCHAR(10);
    DECLARE @ObjId        INT;
    DECLARE @Schema       SYSNAME;
    DECLARE @Nome         SYSNAME;
    DECLARE @Pk           SYSNAME;
    DECLARE @QtdPk        INT;
    DECLARE @NomeTabela   NVARCHAR(256);
    DECLARE @NomeTrigger  SYSNAME;
    DECLARE @ListaJson    NVARCHAR(MAX);
    DECLARE @Valores      NVARCHAR(MAX);
    DECLARE @Contexto     NVARCHAR(MAX);
    DECLARE @Script       NVARCHAR(MAX);

    DROP TABLE IF EXISTS #Col;

    BEGIN TRY
        SET @Criar  = ISNULL(@Criar, 0);
        SET @ObjId  = OBJECT_ID(LTRIM(RTRIM(ISNULL(@Tabela, N''))), N'U');

        IF @ObjId IS NULL
            THROW 50001, N'Tabela não encontrada (use SCHEMA.Tabela).', 1;

        SET @Schema      = OBJECT_SCHEMA_NAME(@ObjId);
        SET @Nome        = OBJECT_NAME(@ObjId);
        SET @NomeTabela  = @Schema + N'.' + @Nome;
        SET @NomeTrigger = N'tg_' + @Schema + N'_' + @Nome + N'_Auditoria';

        IF @NomeTabela = N'SIS.Auditoria'
            THROW 50001, N'A própria auditoria não é auditada.', 1;

        SELECT @QtdPk = COUNT(*)
        FROM sys.indexes ix
        INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
        WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

        IF ISNULL(@QtdPk, 0) <> 1
            THROW 50001, N'A tabela precisa ter chave primária de uma coluna só.', 1;

        SELECT @Pk = c.name
        FROM sys.indexes ix
        INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
        INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

        SET @EtapaAtual = 'Leitura das colunas';
        SELECT c.column_id AS ORDEM,
               c.name      AS NOME,
               t.name      AS TIPO,
               CAST(CASE WHEN t.name IN ('varbinary', 'binary', 'image', 'timestamp')
                           OR EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(@CamposSigilosos, N''), N',') s WHERE LTRIM(RTRIM(s.value)) = c.name)
                         THEN 1 ELSE 0 END AS BIT) AS SIGILOSO,
               CAST(CASE WHEN c.name IN (N'DT_CRIACAO', N'USUARIO_CRIACAO', N'DT_ALTERACAO', N'USUARIO_ALTERACAO')
                           OR c.name = @Pk
                           OR c.is_computed = 1
                           OR t.name IN ('timestamp', 'text', 'ntext', 'image', 'geography', 'geometry')
                           OR EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(@CamposIgnorados, N''), N',') s WHERE LTRIM(RTRIM(s.value)) = c.name)
                         THEN 1 ELSE 0 END AS BIT) AS IGNORADO,
               CAST(CASE WHEN t.name IN ('char', 'varchar', 'nchar', 'nvarchar') THEN 1 ELSE 0 END AS BIT) AS TEXTO,
               CAST(CASE WHEN t.name IN ('date', 'datetime', 'datetime2', 'smalldatetime', 'datetimeoffset', 'time') THEN 1 ELSE 0 END AS BIT) AS DATA,
               CAST(CASE WHEN t.name IN ('xml', 'sql_variant', 'hierarchyid') THEN 1 ELSE 0 END AS BIT) AS ESPECIAL
        INTO #Col
        FROM sys.columns c
        INNER JOIN sys.types t ON t.system_type_id = c.system_type_id AND t.user_type_id = c.system_type_id
        WHERE c.object_id = @ObjId
          AND t.name NOT IN ('geography', 'geometry');

        SET @EtapaAtual = 'Montagem do script';

        -- Foto do registro (JSON) para inclusão e exclusão
        SELECT @ListaJson = STRING_AGG(CAST(
                   CASE WHEN c.SIGILOSO = 1 THEN N'CASE WHEN x.' + QUOTENAME(c.NOME) + N' IS NULL THEN NULL ELSE N''***'' END AS ' + QUOTENAME(c.NOME)
                        WHEN c.ESPECIAL = 1 THEN N'CONVERT(NVARCHAR(MAX), x.' + QUOTENAME(c.NOME) + N') AS ' + QUOTENAME(c.NOME)
                        WHEN c.TIPO IN ('text', 'ntext') THEN N'CONVERT(NVARCHAR(MAX), x.' + QUOTENAME(c.NOME) + N') AS ' + QUOTENAME(c.NOME)
                        ELSE N'x.' + QUOTENAME(c.NOME) END AS NVARCHAR(MAX)), N', ') WITHIN GROUP (ORDER BY c.ORDEM)
        FROM #Col c
        WHERE c.TIPO <> 'timestamp';

        -- Uma linha de VALUES por campo comparado na alteração
        SELECT @Valores = STRING_AGG(CAST(
                   N'                (N''' + c.NOME + N''', '
                 + CASE WHEN c.SIGILOSO = 1 THEN N'CASE WHEN d.' + QUOTENAME(c.NOME) + N' IS NULL THEN NULL ELSE N''***'' END, CASE WHEN i.' + QUOTENAME(c.NOME) + N' IS NULL THEN NULL ELSE N''***'' END, '
                        WHEN c.DATA = 1     THEN N'CONVERT(NVARCHAR(MAX), d.' + QUOTENAME(c.NOME) + N', 121), CONVERT(NVARCHAR(MAX), i.' + QUOTENAME(c.NOME) + N', 121), '
                        ELSE                     N'CONVERT(NVARCHAR(MAX), d.' + QUOTENAME(c.NOME) + N'), CONVERT(NVARCHAR(MAX), i.' + QUOTENAME(c.NOME) + N'), '
                   END
                 + N'CASE WHEN '
                 + CASE WHEN c.TEXTO = 1    THEN N'd.' + QUOTENAME(c.NOME) + N' COLLATE Latin1_General_BIN2 <> i.' + QUOTENAME(c.NOME) + N' COLLATE Latin1_General_BIN2'
                        WHEN c.ESPECIAL = 1 THEN N'CONVERT(NVARCHAR(MAX), d.' + QUOTENAME(c.NOME) + N') <> CONVERT(NVARCHAR(MAX), i.' + QUOTENAME(c.NOME) + N')'
                        ELSE                     N'd.' + QUOTENAME(c.NOME) + N' <> i.' + QUOTENAME(c.NOME)
                   END
                 + N' OR (d.' + QUOTENAME(c.NOME) + N' IS NULL AND i.' + QUOTENAME(c.NOME) + N' IS NOT NULL)'
                 + N' OR (d.' + QUOTENAME(c.NOME) + N' IS NOT NULL AND i.' + QUOTENAME(c.NOME) + N' IS NULL) THEN 1 ELSE 0 END)'
                 AS NVARCHAR(MAX)), @Sep) WITHIN GROUP (ORDER BY c.ORDEM)
        FROM #Col c
        WHERE c.IGNORADO = 0;

        SET @Contexto = N'@Usuario, @IdUsuario, @Estacao, @Origem, @IdLote, @Transacao';

        SET @Script =
              N'CREATE OR ALTER TRIGGER ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@NomeTrigger) + @NL
            + N'ON ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Nome) + @NL
            + N'AFTER INSERT, UPDATE, DELETE' + @NL
            + N'AS' + @NL
            + N'/* Auditoria de ' + @NomeTabela + N'. Gerado por SIS.SIS_Auditoria_Trigger_Gerar em ' + SIS.fn_SIS_Formatar_Data_Hora(SYSDATETIME()) + N'.' + @NL
            + N'   NÃO EDITAR: mudou a tabela, gerar de novo.' + @NL
            + N'   Ignorados: ' + ISNULL(NULLIF(@CamposIgnorados, N''), N'(nenhum além dos padrões)') + N' | Sigilosos: ' + ISNULL(NULLIF(@CamposSigilosos, N''), N'(só colunas binárias)') + N' */' + @NL
            + N'BEGIN' + @NL
            + N'    SET NOCOUNT ON;' + @NL
            + N'    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;' + @NL + @NL
            + N'    DECLARE @Usuario   NVARCHAR(100) = ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N''USUARIO'')), ISNULL(CONVERT(NVARCHAR(100), SUSER_SNAME()), N''''));' + @NL
            + N'    DECLARE @IdUsuario INT           = TRY_CONVERT(INT, SESSION_CONTEXT(N''ID_USUARIO''));' + @NL
            + N'    DECLARE @Estacao   NVARCHAR(128) = ISNULL(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N''ESTACAO'')), ISNULL(HOST_NAME(), N''''));' + @NL
            + N'    DECLARE @Origem    NVARCHAR(256) = ISNULL(CONVERT(NVARCHAR(256), SESSION_CONTEXT(N''ORIGEM'')), ISNULL(APP_NAME(), N''''));' + @NL
            + N'    DECLARE @IdLote    BIGINT        = TRY_CONVERT(BIGINT, SESSION_CONTEXT(N''ID_LOTE''));' + @NL
            + N'    DECLARE @Transacao BIGINT        = CURRENT_TRANSACTION_ID();' + @NL + @NL
            + N'    BEGIN TRY' + @NL
            + N'        -- Inclusão: foto do registro novo' + @NL
            + N'        INSERT INTO SIS.Auditoria (TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, ID_USUARIO, ESTACAO, ORIGEM, ID_LOTE, TRANSACAO)' + @NL
            + N'        SELECT N''' + @NomeTabela + N''', i.' + QUOTENAME(@Pk) + N', ''I'', N'''', NULL,' + @NL
            + N'               (SELECT ' + @ListaJson + N' FROM inserted x WHERE x.' + QUOTENAME(@Pk) + N' = i.' + QUOTENAME(@Pk) + N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),' + @NL
            + N'               ' + @Contexto + @NL
            + N'        FROM inserted i' + @NL
            + N'        WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.' + QUOTENAME(@Pk) + N' = i.' + QUOTENAME(@Pk) + N');' + @NL + @NL
            + N'        -- Exclusão: foto do registro apagado' + @NL
            + N'        INSERT INTO SIS.Auditoria (TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, ID_USUARIO, ESTACAO, ORIGEM, ID_LOTE, TRANSACAO)' + @NL
            + N'        SELECT N''' + @NomeTabela + N''', d.' + QUOTENAME(@Pk) + N', ''E'', N'''',' + @NL
            + N'               (SELECT ' + @ListaJson + N' FROM deleted x WHERE x.' + QUOTENAME(@Pk) + N' = d.' + QUOTENAME(@Pk) + N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),' + @NL
            + N'               NULL, ' + @Contexto + @NL
            + N'        FROM deleted d' + @NL
            + N'        WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.' + QUOTENAME(@Pk) + N' = d.' + QUOTENAME(@Pk) + N');' + @NL
            + CASE WHEN ISNULL(@Valores, N'') = N'' THEN N''
                   ELSE @NL
                      + N'        -- Alteração: uma linha por campo que mudou' + @NL
                      + N'        INSERT INTO SIS.Auditoria (TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, ID_USUARIO, ESTACAO, ORIGEM, ID_LOTE, TRANSACAO)' + @NL
                      + N'        SELECT N''' + @NomeTabela + N''', i.' + QUOTENAME(@Pk) + N', ''A'', v.CAMPO, v.ANTES, v.DEPOIS, ' + @Contexto + @NL
                      + N'        FROM inserted i' + @NL
                      + N'        INNER JOIN deleted d ON d.' + QUOTENAME(@Pk) + N' = i.' + QUOTENAME(@Pk) + @NL
                      + N'        CROSS APPLY (VALUES' + @NL
                      + @Valores + @NL
                      + N'        ) v (CAMPO, ANTES, DEPOIS, MUDOU)' + @NL
                      + N'        WHERE v.MUDOU = 1;' + @NL
              END
            + N'    END TRY' + @NL
            + N'    BEGIN CATCH' + @NL
            + N'        THROW;   -- auditoria é integridade: sem auditoria, a gravação é desfeita' + @NL
            + N'    END CATCH;' + @NL
            + N'END;';

        DROP TABLE IF EXISTS #Col;

        IF @Criar = 0
        BEGIN
            SELECT @Script AS SCRIPT;
            RETURN;
        END;

        SET @EtapaAtual = 'Criação da trigger';
        EXEC sys.sp_executesql @Script;
        PRINT N'Auditoria ligada: ' + @Schema + N'.' + @NomeTrigger;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Col;
            IF ERROR_NUMBER() <> 50001
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, LEFT(@EtapaAtual + ' (' + CONVERT(VARCHAR(256), ISNULL(@Tabela, N'')) + ')', 200), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;
        THROW;
    END CATCH;
END;
GO
