/*******************************************************************************
  Objeto      : [SIS].[SIS_Historico_Desfazer_Montar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Motor do desfazer pelo histórico (P20). Monta, sem gravar
                nada, o plano do que vai mudar, na tabela #Desfazer_Plano
                criada por quem chama (SIS_Historico_Desfazer_Previa e
                SIS_Historico_Desfazer). Modos:
                  REGISTRO  voltar o registro (e as filhas que vão junto) para
                            como estava logo depois da operação @IdAuditoria,
                            ou na data/hora @DataHora;
                  OPERACAO  desfazer a operação (transação) da linha
                            @IdAuditoria;
                  LOTE      desfazer tudo o que o lote @IdLote fez.
                Para cada campo alterado: o valor novo é o "antes" da primeira
                mudança do conjunto; só muda se hoje o campo estiver igual ao
                "depois" da última (senão CONFLITO: alguém mexeu depois).
                Inclusão no conjunto: conforme SIS.Tabela_Config.
                DESFAZER_INCLUSAO (LIXEIRA, DESATIVAR, APAGAR ou RECUSAR).
                Exclusão definitiva no conjunto: conforme DESFAZER_EXCLUSAO
                (REINSERIR, só tabelas de ligação como permissões, ou RECUSAR).
                No modo REGISTRO entram também as filhas que vão junto,
                inclusive as já apagadas (achadas pela foto da auditoria).
                BLOQUEADO: tabela sem desfazer, registro apagado de vez ou na
                lixeira, mês fechado, trava própria. IGNORADO: campo sigiloso,
                bloqueado na configuração, de controle ou a marca da lixeira.
                Comparação de texto em binário, igual à trigger de auditoria.
                Uso interno (DENY para a API).
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Historico_Desfazer_Montar]
    @Modo         VARCHAR(10),
    @Tabela       NVARCHAR(256) = NULL,
    @IdRegistro   BIGINT        = NULL,
    @IdAuditoria  BIGINT        = NULL,
    @DataHora     DATETIME2(0)  = NULL,
    @IdLote       BIGINT        = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Limite BIGINT, @Transacao BIGINT, @Sql NVARCHAR(MAX), @Lista NVARCHAR(MAX);
    DECLARE @i INT, @Total INT, @T NVARCHAR(256), @ObjId INT, @Pk NVARCHAR(128), @Nome NVARCHAR(300), @DescSql NVARCHAR(1000);
    DECLARE @Id BIGINT, @Msg NVARCHAR(400), @ColData NVARCHAR(128), @DataNova DATE;

    DROP TABLE IF EXISTS #Reg;
    DROP TABLE IF EXISTS #Lin;
    DROP TABLE IF EXISTS #Campo;
    DROP TABLE IF EXISTS #Atual;
    DROP TABLE IF EXISTS #Rec;
    DROP TABLE IF EXISTS #Tab;

    CREATE TABLE #Reg  (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, PRIMARY KEY (TABELA, ID_REGISTRO));
    CREATE TABLE #Lin  (ID_AUDITORIA BIGINT NOT NULL PRIMARY KEY, TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, OPERACAO CHAR(1) NOT NULL,
                        CAMPO NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL, VALOR_ANTES NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL, VALOR_DEPOIS NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL);
    CREATE TABLE #Campo (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, CAMPO NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
                         PRIMEIRA BIGINT NOT NULL, ULTIMA BIGINT NOT NULL, VALOR_NOVO NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL, VALOR_ESPERADO NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
                         PRIMARY KEY (TABELA, ID_REGISTRO, CAMPO));
    CREATE TABLE #Atual (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, CAMPO NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL, VALOR NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
                         PRIMARY KEY (TABELA, ID_REGISTRO, CAMPO));
    CREATE TABLE #Rec  (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, TEM_I BIT NOT NULL, TEM_E BIT NOT NULL,
                        EXISTE BIT NOT NULL DEFAULT (0), DESCRICAO NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL, BLOQUEIO NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
                        ACAO VARCHAR(10) COLLATE DATABASE_DEFAULT NULL, AVISO NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL, FOTO NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
                        PRIMARY KEY (TABELA, ID_REGISTRO));
    CREATE TABLE #Tab  (ORDEM INT IDENTITY(1,1) NOT NULL, TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL);

    -- 1) Linhas da auditoria que entram no conjunto
    IF @Modo = 'REGISTRO'
    BEGIN
        IF @IdAuditoria IS NOT NULL
        BEGIN
            SELECT @Transacao = a.TRANSACAO, @Limite = a.ID_AUDITORIA FROM SIS.Auditoria a WHERE a.ID_AUDITORIA = @IdAuditoria;
            IF @Transacao IS NOT NULL
                SELECT @Limite = MAX(a.ID_AUDITORIA) FROM SIS.Auditoria a WHERE a.TRANSACAO = @Transacao;
        END;
        IF @Limite IS NULL AND @DataHora IS NOT NULL
            SELECT @Limite = ISNULL(MAX(a.ID_AUDITORIA), 0) FROM SIS.Auditoria a WHERE a.DT_OPERACAO <= @DataHora;
        IF @Limite IS NULL GOTO Fim;

        INSERT INTO #Reg (TABELA, ID_REGISTRO) VALUES (@Tabela, @IdRegistro);

        -- filhas que vão junto: as que existem hoje e as incluídas/apagadas depois do ponto (pela foto da auditoria)
        SET @Sql = N'';
        SELECT @Sql = @Sql
                    + N'INSERT INTO #Reg (TABELA, ID_REGISTRO) SELECT DISTINCT N''' + REPLACE(f.TABELA, N'''', N'''''') + N''', CAST(f.'
                    + QUOTENAME(SIS.fn_SIS_Tabela_PK(f.TABELA)) + N' AS BIGINT) FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(f.TABELA, N'U'))) + N'.'
                    + QUOTENAME(OBJECT_NAME(OBJECT_ID(f.TABELA, N'U'))) + N' f WHERE f.' + QUOTENAME(f.COLUNA) + N' = @Id'
                    + N' AND NOT EXISTS (SELECT 1 FROM #Reg r WHERE r.TABELA = N''' + REPLACE(f.TABELA, N'''', N'''''') + N''' AND r.ID_REGISTRO = f.'
                    + QUOTENAME(SIS.fn_SIS_Tabela_PK(f.TABELA)) + N');' + NCHAR(13) + NCHAR(10)
                    + N'INSERT INTO #Reg (TABELA, ID_REGISTRO) SELECT DISTINCT a.TABELA, a.ID_REGISTRO FROM SIS.Auditoria a'
                    + N' WHERE a.TABELA = N''' + REPLACE(f.TABELA, N'''', N'''''') + N''' AND a.OPERACAO IN (''I'', ''E'') AND a.ID_AUDITORIA > @Limite'
                    + N' AND JSON_VALUE(COALESCE(a.VALOR_DEPOIS, a.VALOR_ANTES), N''$.' + REPLACE(f.COLUNA, N'''', N'''''') + N''') = CAST(@Id AS NVARCHAR(30))'
                    + N' AND NOT EXISTS (SELECT 1 FROM #Reg r WHERE r.TABELA = a.TABELA AND r.ID_REGISTRO = a.ID_REGISTRO);' + NCHAR(13) + NCHAR(10)
        FROM (SELECT LEFT(x.v, LEN(x.v) - CHARINDEX(N'.', REVERSE(x.v))) AS TABELA, RIGHT(x.v, CHARINDEX(N'.', REVERSE(x.v)) - 1) AS COLUNA
              FROM SIS.Tabela_Config c
              CROSS APPLY (SELECT LTRIM(RTRIM(s.value)) AS v FROM STRING_SPLIT(c.TABELAS_FILHAS, N',') s) x
              WHERE c.TABELA = @Tabela AND x.v LIKE N'%_._%._%') f
        WHERE OBJECT_ID(f.TABELA, N'U') IS NOT NULL AND COL_LENGTH(f.TABELA, f.COLUNA) IS NOT NULL AND SIS.fn_SIS_Tabela_PK(f.TABELA) <> N'';
        IF @Sql <> N'' EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Limite BIGINT', @Id = @IdRegistro, @Limite = @Limite;

        INSERT INTO #Lin (ID_AUDITORIA, TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS)
        SELECT a.ID_AUDITORIA, a.TABELA, a.ID_REGISTRO, a.OPERACAO, a.CAMPO, a.VALOR_ANTES, a.VALOR_DEPOIS
        FROM SIS.Auditoria a
        INNER JOIN #Reg r ON r.TABELA = a.TABELA AND r.ID_REGISTRO = a.ID_REGISTRO
        WHERE a.ID_AUDITORIA > @Limite;
    END;

    IF @Modo = 'OPERACAO'
    BEGIN
        SELECT @Transacao = a.TRANSACAO FROM SIS.Auditoria a WHERE a.ID_AUDITORIA = @IdAuditoria;

        INSERT INTO #Lin (ID_AUDITORIA, TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS)
        SELECT a.ID_AUDITORIA, a.TABELA, a.ID_REGISTRO, a.OPERACAO, a.CAMPO, a.VALOR_ANTES, a.VALOR_DEPOIS
        FROM SIS.Auditoria a
        WHERE (@Transacao IS NOT NULL AND a.TRANSACAO = @Transacao)
           OR (@Transacao IS NULL AND a.ID_AUDITORIA = @IdAuditoria);
    END;

    IF @Modo = 'LOTE'
        INSERT INTO #Lin (ID_AUDITORIA, TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS)
        SELECT a.ID_AUDITORIA, a.TABELA, a.ID_REGISTRO, a.OPERACAO, a.CAMPO, a.VALOR_ANTES, a.VALOR_DEPOIS
        FROM SIS.Auditoria a
        WHERE a.ID_LOTE = @IdLote;

    IF NOT EXISTS (SELECT 1 FROM #Lin) GOTO Fim;

    -- 2) Registros e campos
    INSERT INTO #Rec (TABELA, ID_REGISTRO, TEM_I, TEM_E)
    SELECT l.TABELA, l.ID_REGISTRO,
           CAST(MAX(CASE WHEN l.OPERACAO = 'I' THEN 1 ELSE 0 END) AS BIT),
           CAST(MAX(CASE WHEN l.OPERACAO = 'E' THEN 1 ELSE 0 END) AS BIT)
    FROM #Lin l
    GROUP BY l.TABELA, l.ID_REGISTRO;

    INSERT INTO #Campo (TABELA, ID_REGISTRO, CAMPO, PRIMEIRA, ULTIMA)
    SELECT l.TABELA, l.ID_REGISTRO, l.CAMPO, MIN(l.ID_AUDITORIA), MAX(l.ID_AUDITORIA)
    FROM #Lin l
    WHERE l.OPERACAO = 'A' AND l.CAMPO <> N''
    GROUP BY l.TABELA, l.ID_REGISTRO, l.CAMPO;

    UPDATE c SET c.VALOR_NOVO = p.VALOR_ANTES, c.VALOR_ESPERADO = u.VALOR_DEPOIS
    FROM #Campo c
    INNER JOIN #Lin p ON p.ID_AUDITORIA = c.PRIMEIRA
    INNER JOIN #Lin u ON u.ID_AUDITORIA = c.ULTIMA;

    -- inclusão a desativar: o campo ATIVO entra para leitura do valor de hoje
    INSERT INTO #Campo (TABELA, ID_REGISTRO, CAMPO, PRIMEIRA, ULTIMA, VALOR_NOVO, VALOR_ESPERADO)
    SELECT r.TABELA, r.ID_REGISTRO, N'ATIVO', 0, 0, N'0', NULL
    FROM #Rec r
    INNER JOIN SIS.Tabela_Config cf ON cf.TABELA = r.TABELA AND cf.ATIVO = 1 AND cf.DESFAZER_INCLUSAO = 'DESATIVAR'
    WHERE r.TEM_I = 1 AND COL_LENGTH(r.TABELA, N'ATIVO') IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #Campo c WHERE c.TABELA = r.TABELA AND c.ID_REGISTRO = r.ID_REGISTRO AND c.CAMPO = N'ATIVO');

    -- inclusão a desativar: o valor novo do ATIVO é sempre 0 (mesmo que o ATIVO tenha mudado depois)
    UPDATE c SET c.VALOR_NOVO = N'0'
    FROM #Campo c
    INNER JOIN #Rec r ON r.TABELA = c.TABELA AND r.ID_REGISTRO = c.ID_REGISTRO
    INNER JOIN SIS.Tabela_Config cf ON cf.TABELA = r.TABELA AND cf.ATIVO = 1 AND cf.DESFAZER_INCLUSAO = 'DESATIVAR'
    WHERE r.TEM_I = 1 AND c.CAMPO = N'ATIVO';

    -- 3) Valores de hoje, existência e descrição (uma consulta por tabela)
    INSERT INTO #Tab (TABELA) SELECT DISTINCT r.TABELA FROM #Rec r WHERE OBJECT_ID(r.TABELA, N'U') IS NOT NULL AND SIS.fn_SIS_Tabela_PK(r.TABELA) <> N'';
    SELECT @i = 1, @Total = COUNT(*) FROM #Tab;
    WHILE @i <= @Total
    BEGIN
        SELECT @T = t.TABELA FROM #Tab t WHERE t.ORDEM = @i;
        SET @ObjId = OBJECT_ID(@T, N'U');
        SET @Pk = SIS.fn_SIS_Tabela_PK(@T);
        SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));
        SET @DescSql = NULL;
        SELECT @DescSql = NULLIF(LTRIM(RTRIM(cf.DESCRICAO_SQL)), N'') FROM SIS.Tabela_Config cf WHERE cf.TABELA = @T;

        SET @Sql = N'UPDATE r SET r.EXISTE = 1, r.DESCRICAO = LEFT(CONVERT(NVARCHAR(MAX), '
                 + ISNULL(@DescSql, N'CAST(t.' + QUOTENAME(@Pk) + N' AS NVARCHAR(30))') + N'), 400)'
                 + N' FROM #Rec r INNER JOIN ' + @Nome + N' t ON t.' + QUOTENAME(@Pk) + N' = r.ID_REGISTRO WHERE r.TABELA = @T;';
        EXEC sys.sp_executesql @Sql, N'@T NVARCHAR(256)', @T = @T;

        SET @Lista = NULL;
        SELECT @Lista = STRING_AGG(CONVERT(NVARCHAR(MAX),
                   N'(N''' + REPLACE(x.CAMPO, N'''', N'''''') + N''', '
                 + CASE WHEN ty.name IN ('date', 'datetime', 'datetime2', 'smalldatetime', 'datetimeoffset', 'time') THEN N'CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(x.CAMPO) + N', 121)'
                        WHEN ty.name IN ('varbinary', 'binary', 'image', 'timestamp') THEN N'CASE WHEN t.' + QUOTENAME(x.CAMPO) + N' IS NULL THEN NULL ELSE N''***'' END'
                        ELSE N'CONVERT(NVARCHAR(MAX), t.' + QUOTENAME(x.CAMPO) + N')' END + N')'), N', ')
        FROM (SELECT DISTINCT c.CAMPO FROM #Campo c WHERE c.TABELA = @T) x
        INNER JOIN sys.columns col ON col.object_id = @ObjId AND col.name = x.CAMPO
        INNER JOIN sys.types ty ON ty.system_type_id = col.system_type_id AND ty.user_type_id = col.system_type_id
        WHERE ty.name NOT IN ('text', 'ntext', 'geography', 'geometry');

        IF @Lista IS NOT NULL
        BEGIN
            SET @Sql = N'INSERT INTO #Atual (TABELA, ID_REGISTRO, CAMPO, VALOR) SELECT @T, c.ID_REGISTRO, c.CAMPO, v.VALOR'
                     + N' FROM #Campo c INNER JOIN ' + @Nome + N' t ON t.' + QUOTENAME(@Pk) + N' = c.ID_REGISTRO'
                     + N' CROSS APPLY (VALUES ' + @Lista + N') v (CAMPO, VALOR)'
                     + N' WHERE c.TABELA = @T AND v.CAMPO = c.CAMPO;';
            EXEC sys.sp_executesql @Sql, N'@T NVARCHAR(256)', @T = @T;
        END;
        SET @i = @i + 1;
    END;

    -- 4) Decisão por registro: ACAO = CAMPOS, LIXEIRA, DESATIVAR, APAGAR, REINSERIR ou NADA; BLOQUEIO = o que impede
    UPDATE r SET r.FOTO = (SELECT TOP 1 l.VALOR_ANTES FROM #Lin l WHERE l.TABELA = r.TABELA AND l.ID_REGISTRO = r.ID_REGISTRO AND l.OPERACAO = 'E' ORDER BY l.ID_AUDITORIA)
    FROM #Rec r WHERE r.TEM_E = 1;

    UPDATE r SET
           r.BLOQUEIO = CASE
             WHEN cf.TABELA IS NULL OR cf.PERMITE_DESFAZER = 0 THEN N'Este tipo de registro não pode ser desfeito pelo histórico.'
             WHEN r.TEM_I = 1 AND r.TEM_E = 1 THEN NULL
             WHEN r.TEM_E = 1 AND r.EXISTE = 0 AND cf.DESFAZER_EXCLUSAO = 'REINSERIR' THEN NULL
             WHEN r.TEM_E = 1 AND r.EXISTE = 0 THEN N'O registro foi apagado de vez: não dá para desfazer.'
             WHEN r.EXISTE = 0 AND r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'APAGAR' THEN NULL
             WHEN r.EXISTE = 0 THEN N'O registro foi apagado de vez depois: não dá para desfazer.'
             WHEN SIS.fn_SIS_Na_Lixeira(r.TABELA, r.ID_REGISTRO) = 1 THEN N'O registro está na lixeira: recupere-o antes (Sistema › Lixeira).'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'RECUSAR' THEN N'O registro foi incluído nesta operação e este tipo de inclusão não é desfeito.'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'LIXEIRA' AND cf.PERMITE_LIXEIRA = 0 THEN N'O registro foi incluído nesta operação e não pode ir para a lixeira.'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'DESATIVAR' AND COL_LENGTH(r.TABELA, N'ATIVO') IS NULL THEN N'O registro foi incluído nesta operação e não pode ser desativado.'
             END,
           r.ACAO = CASE
             WHEN r.TEM_I = 1 AND r.TEM_E = 1 THEN 'NADA'
             WHEN r.TEM_E = 1 AND r.EXISTE = 0 THEN 'REINSERIR'
             WHEN r.EXISTE = 0 THEN 'NADA'
             WHEN r.TEM_I = 1 THEN cf.DESFAZER_INCLUSAO
             ELSE 'CAMPOS' END,
           r.AVISO = CASE
             WHEN r.TEM_I = 1 AND r.TEM_E = 1 THEN N'Incluído e apagado dentro do que será desfeito: nada a fazer.'
             WHEN r.TEM_E = 1 AND r.EXISTE = 0 THEN N'Apagado nesta operação: volta como estava (com código novo).'
             WHEN r.EXISTE = 0 THEN N'Incluído nesta operação e já não existe: nada a fazer.'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'LIXEIRA' THEN N'Incluído nesta operação: vai para a lixeira (pode ser recuperado).'
             WHEN r.TEM_I = 1 AND cf.DESFAZER_INCLUSAO = 'APAGAR' THEN N'Incluído nesta operação: será retirado.'
             END
    FROM #Rec r
    LEFT JOIN SIS.Tabela_Config cf ON cf.TABELA = r.TABELA AND cf.ATIVO = 1;

    UPDATE #Rec SET BLOQUEIO = N'O registro apagado tinha campo sigiloso e não pode voltar.'
    WHERE BLOQUEIO IS NULL AND ACAO = 'REINSERIR' AND FOTO LIKE N'%"***"%';

    -- 5) Plano: registros inteiros (lixeira, apagar, reinserir, nada)
    INSERT INTO #Desfazer_Plano (TABELA, ID_REGISTRO, DESCRICAO, CAMPO, VALOR_ATUAL, VALOR_NOVO, ACAO, SITUACAO, MENSAGEM, ULTIMA_AUDITORIA)
    SELECT r.TABELA, r.ID_REGISTRO, r.DESCRICAO, N'', NULL, CASE WHEN r.ACAO = 'REINSERIR' THEN r.FOTO END,
           r.ACAO, 'OK', r.AVISO,
           (SELECT MAX(l.ID_AUDITORIA) FROM #Lin l WHERE l.TABELA = r.TABELA AND l.ID_REGISTRO = r.ID_REGISTRO)
    FROM #Rec r
    WHERE r.BLOQUEIO IS NULL AND r.ACAO IN ('LIXEIRA', 'APAGAR', 'REINSERIR', 'NADA');

    -- 6) Plano: campos (registros a alterar e inclusões a desativar)
    INSERT INTO #Desfazer_Plano (TABELA, ID_REGISTRO, DESCRICAO, CAMPO, VALOR_ATUAL, VALOR_NOVO, ACAO, SITUACAO, MENSAGEM, ULTIMA_AUDITORIA)
    SELECT c.TABELA, c.ID_REGISTRO, r.DESCRICAO, c.CAMPO, a.VALOR, c.VALOR_NOVO,
           CASE WHEN x.IGNORAR = 1 OR x.JA_ESTA = 1 THEN 'NADA'
                WHEN x.IGUAL_ESPERADO = 1 OR r.ACAO = 'DESATIVAR' THEN 'ALTERAR' ELSE 'NADA' END,
           CASE WHEN x.IGNORAR = 1 THEN 'IGNORADO'
                WHEN x.JA_ESTA = 1 OR x.IGUAL_ESPERADO = 1 OR r.ACAO = 'DESATIVAR' THEN 'OK' ELSE 'CONFLITO' END,
           CAST(CASE WHEN a.CAMPO IS NULL THEN N'O campo não existe mais.'
                     WHEN x.IGNORAR = 1 THEN N'Campo que não é desfeito (sigiloso, calculado, de controle ou marca da lixeira).'
                     WHEN x.JA_ESTA = 1 THEN N'Já está assim.'
                     WHEN r.ACAO = 'DESATIVAR' THEN N'Incluído nesta operação: vai ser desativado.'
                     WHEN x.IGUAL_ESPERADO = 1 THEN N''
                     ELSE LEFT(N'Mudou depois desta operação: hoje está "' + ISNULL(a.VALOR, N'(vazio)') + N'".', 400) END AS NVARCHAR(400)),
           NULLIF(c.ULTIMA, 0)
    FROM #Campo c
    INNER JOIN #Rec r ON r.TABELA = c.TABELA AND r.ID_REGISTRO = c.ID_REGISTRO
    LEFT  JOIN SIS.Tabela_Config cf ON cf.TABELA = c.TABELA
    LEFT  JOIN #Atual a ON a.TABELA = c.TABELA AND a.ID_REGISTRO = c.ID_REGISTRO AND a.CAMPO = c.CAMPO
    CROSS APPLY (SELECT
           CAST(CASE WHEN a.CAMPO IS NULL
                       OR c.CAMPO IN (N'DT_CRIACAO', N'USUARIO_CRIACAO', N'DT_ALTERACAO', N'USUARIO_ALTERACAO', N'DT_EXCLUSAO', N'USUARIO_EXCLUSAO')
                       OR c.CAMPO = SIS.fn_SIS_Tabela_PK(c.TABELA)
                       OR c.VALOR_NOVO = N'***' OR c.VALOR_ESPERADO = N'***' OR a.VALOR = N'***'
                       OR EXISTS (SELECT 1 FROM STRING_SPLIT(ISNULL(cf.CAMPOS_BLOQUEADOS, N''), N',') s WHERE LTRIM(RTRIM(s.value)) = c.CAMPO)
                     THEN 1 ELSE 0 END AS BIT) AS IGNORAR,
           CAST(CASE WHEN (a.VALOR IS NULL AND c.VALOR_NOVO IS NULL)
                       OR (a.VALOR COLLATE Latin1_General_BIN2 = c.VALOR_NOVO COLLATE Latin1_General_BIN2) THEN 1 ELSE 0 END AS BIT) AS JA_ESTA,
           CAST(CASE WHEN (a.VALOR IS NULL AND c.VALOR_ESPERADO IS NULL)
                       OR (a.VALOR COLLATE Latin1_General_BIN2 = c.VALOR_ESPERADO COLLATE Latin1_General_BIN2) THEN 1 ELSE 0 END AS BIT) AS IGUAL_ESPERADO
        ) x
    WHERE r.BLOQUEIO IS NULL
      AND (r.ACAO = 'CAMPOS' OR (r.ACAO = 'DESATIVAR' AND c.CAMPO = N'ATIVO'));

    -- 7) Travas (mês fechado e trava própria) dos registros que vão mudar e ainda existem
    DROP TABLE IF EXISTS #Trava;
    SELECT ROW_NUMBER() OVER (ORDER BY p.TABELA, p.ID_REGISTRO) AS ORDEM, p.TABELA, p.ID_REGISTRO
    INTO #Trava
    FROM #Desfazer_Plano p
    WHERE p.ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR')
    GROUP BY p.TABELA, p.ID_REGISTRO;

    SELECT @i = 1, @Total = COUNT(*) FROM #Trava;
    WHILE @i <= @Total
    BEGIN
        SELECT @T = t.TABELA, @Id = t.ID_REGISTRO FROM #Trava t WHERE t.ORDEM = @i;
        SET @ColData = NULL;
        SELECT @ColData = NULLIF(cf.COLUNA_DATA_MES, N'') FROM SIS.Tabela_Config cf WHERE cf.TABELA = @T;
        SET @DataNova = (SELECT TOP 1 TRY_CONVERT(DATE, p.VALOR_NOVO, 121) FROM #Desfazer_Plano p
                         WHERE p.TABELA = @T AND p.ID_REGISTRO = @Id AND p.CAMPO = @ColData AND p.ACAO = 'ALTERAR' ORDER BY p.ORDEM);
        SET @Msg = N'';
        EXEC SIS.SIS_Tabela_Trava_Conferir @Tabela = @T, @IdRegistro = @Id, @Operacao = 'DESFAZER', @DataNova = @DataNova, @Mensagem = @Msg OUTPUT;
        IF ISNULL(@Msg, N'') <> N''
            UPDATE #Rec SET BLOQUEIO = @Msg WHERE TABELA = @T AND ID_REGISTRO = @Id;
        SET @i = @i + 1;
    END;
    DROP TABLE IF EXISTS #Trava;

    -- 8) Registros bloqueados: uma linha cada, sem os campos
    DELETE p FROM #Desfazer_Plano p INNER JOIN #Rec r ON r.TABELA = p.TABELA AND r.ID_REGISTRO = p.ID_REGISTRO WHERE r.BLOQUEIO IS NOT NULL;

    INSERT INTO #Desfazer_Plano (TABELA, ID_REGISTRO, DESCRICAO, CAMPO, VALOR_ATUAL, VALOR_NOVO, ACAO, SITUACAO, MENSAGEM, ULTIMA_AUDITORIA)
    SELECT r.TABELA, r.ID_REGISTRO, r.DESCRICAO, N'', NULL, NULL, 'NADA', 'BLOQUEADO', r.BLOQUEIO,
           (SELECT MAX(l.ID_AUDITORIA) FROM #Lin l WHERE l.TABELA = r.TABELA AND l.ID_REGISTRO = r.ID_REGISTRO)
    FROM #Rec r
    WHERE r.BLOQUEIO IS NOT NULL;

Fim:
    DROP TABLE IF EXISTS #Reg;
    DROP TABLE IF EXISTS #Lin;
    DROP TABLE IF EXISTS #Campo;
    DROP TABLE IF EXISTS #Atual;
    DROP TABLE IF EXISTS #Rec;
    DROP TABLE IF EXISTS #Tab;
END;
GO
