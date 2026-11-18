/*******************************************************************************
  Pacote      : 03c2 parte B - auditoria rápida em carga grande (SIS_Auditoria_Trigger_Gerar v1.1, vai para o MASTER) e transformação, tela de casos do movimento do Access em lançamento, parcela, baixa, movimento e transferência; casos e correções (schema MIG, NÃO vai para o MASTER)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 18/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacote 03c2 e sql/local/03c2_Migracao_Cadastros_LOCAL.sql já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/local/03c2b_Migracao_Movimento_LOCAL.sql.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Banco errado: este pacote só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Trigger_Gerar.sql
-- =============================================================================
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
    v1.1 (18/11/2026) - Desempenho em carga grande: a foto JSON do registro é
                        montada direto da linha (sem buscar de novo no inserted/
                        deleted, que não tem índice e deixava a trigger
                        quadrática: 25 mil linhas levavam horas). Mesmo
                        resultado gravado na SIS.Auditoria.

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
            + N'               (SELECT ' + REPLACE(@ListaJson, N'x.[', N'i.[') + N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),' + @NL
            + N'               ' + @Contexto + @NL
            + N'        FROM inserted i' + @NL
            + N'        WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.' + QUOTENAME(@Pk) + N' = i.' + QUOTENAME(@Pk) + N');' + @NL + @NL
            + N'        -- Exclusão: foto do registro apagado' + @NL
            + N'        INSERT INTO SIS.Auditoria (TABELA, ID_REGISTRO, OPERACAO, CAMPO, VALOR_ANTES, VALOR_DEPOIS, USUARIO, ID_USUARIO, ESTACAO, ORIGEM, ID_LOTE, TRANSACAO)' + @NL
            + N'        SELECT N''' + @NomeTabela + N''', d.' + QUOTENAME(@Pk) + N', ''E'', N'''',' + @NL
            + N'               (SELECT ' + REPLACE(@ListaJson, N'x.[', N'd.[') + N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),' + @NL
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do SIS
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de configuração e
                segurança do SIS, gerando cada trigger com
                SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas.
                No MASTER fica na parte 8 (triggers). Cada etapa seguinte
                acrescenta aqui (ou na carga do seu bloco) as suas tabelas.
                Não auditadas (são registros, não cadastros): Log_Erro,
                Log_Passo, Login_Log, Sessao, Lote e a própria Auditoria.
                SIS.Usuario: não registra contador de tentativas nem último
                login (mudam a cada acesso); hash e salt da senha saem "***".

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (16/11/2026) - Etapa 02d: grupos de e-mail, rotinas (sem as colunas
                        de execução) e comandos. Filas e logs não são
                        auditados (têm histórico próprio).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Modulo',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Item',              @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Acao',              @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Item_Acao',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Perfil',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Perfil_Permissao',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Usuario',           @Criar = 1,
     @CamposIgnorados = N'TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN', @CamposSigilosos = N'SENHA_HASH,SENHA_SALT';
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Usuario_Permissao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Licenca',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Licenca_Empresa',   @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Anexo_Tipo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Anexo',             @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Grupo_Email',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Grupo_Email_Destinatario', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Rotina',            @Criar = 1,
     @CamposIgnorados = N'PROXIMA_EXECUCAO,SOLICITADA_POR,EM_EXECUCAO,DT_INICIO_EXECUCAO,ULTIMA_EXECUCAO,ULTIMO_RESULTADO,ULTIMA_MENSAGEM';
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comando',           @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Comunicado.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga do boletim semanal da implantação
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Grupos de e-mail, comunicado BOLETIM_IMPLANTACAO com os itens
                iniciais aprovados pelo Celso em 17/11/2026, tela Comunicados (menu
                Sistema > E-mails; administrador geral e administrador da CMJ) e a
                rotina COMUNICADO_PREVIA (sexta-feira, 9h). Só insere o que falta
                (regra 39): o que o Celso mudar pela tela não é sobrescrito.
                Destinatários oficiais (17/11/2026): escritório Construtora Marcílio
                Judice e Danielle M. Judice Daher. Aprovação: Celso.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT v.CODIGO, v.NOME, v.DESCRICAO, N'instalacao'
FROM (VALUES
        (CAST('BOLETIM_IMPLANTACAO' AS VARCHAR(30)), CAST(N'Boletim da implantação' AS NVARCHAR(80)),
         CAST(N'Recebem o boletim semanal do andamento da implantação do SistemaCMJ.' AS NVARCHAR(400))),
        ('BOLETIM_APROVACAO', N'Aprovação do boletim', N'Recebem a prévia do boletim para aprovar antes do envio oficial.')
     ) v (CODIGO, NOME, DESCRICAO)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = v.CODIGO);
GO

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, v.EMAIL, v.NOME, N'instalacao'
FROM (VALUES
        (CAST('BOLETIM_IMPLANTACAO' AS VARCHAR(30)), CAST(N'construtora.m.judice@gmail.com' AS NVARCHAR(256)), CAST(N'Escritório Construtora Marcílio Judice' AS NVARCHAR(100))),
        ('BOLETIM_IMPLANTACAO', N'dmjdaher@gmail.com',       N'Danielle M. Judice Daher'),
        ('BOLETIM_APROVACAO',   N'celsofreitas62@gmail.com', N'Celso de Freitas')
     ) v (GRUPO, EMAIL, NOME)
INNER JOIN SIS.Grupo_Email g ON g.CODIGO = v.GRUPO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.EMAIL = v.EMAIL);
GO

INSERT INTO SIS.Comunicado (CODIGO, TITULO, INTRODUCAO, ID_GRUPO_EMAIL, ID_GRUPO_EMAIL_APROVACAO, EXIGE_APROVACAO, USUARIO_CRIACAO)
SELECT 'BOLETIM_IMPLANTACAO', N'Boletim da implantação do SisCMJ',
       N'Segue o resumo semanal do andamento da implantação do novo sistema de gestão da Construtora.',
       g.ID_GRUPO_EMAIL, ga.ID_GRUPO_EMAIL, 1, N'instalacao'
FROM SIS.Grupo_Email g
INNER JOIN SIS.Grupo_Email ga ON ga.CODIGO = 'BOLETIM_APROVACAO'
WHERE g.CODIGO = 'BOLETIM_IMPLANTACAO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado c WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO');
GO

IF NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Item i INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = i.ID_COMUNICADO WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO')
    INSERT INTO SIS.Comunicado_Item (ID_COMUNICADO, SECAO, TEXTO, ORDEM, USUARIO_CRIACAO)
    SELECT c.ID_COMUNICADO, v.SECAO, v.TEXTO, v.ORDEM, N'instalacao'
    FROM (VALUES
            (CAST('IMPLANTADO' AS VARCHAR(15)), CAST(N'Nenhum módulo em uso na empresa ainda. A instalação no servidor da Construtora vem logo depois da fase atual.' AS NVARCHAR(300)), CAST(1 AS SMALLINT)),
            ('EM_TESTE',     N'Entrada no sistema com usuário e senha, e menu.', 1),
            ('EM_TESTE',     N'Cadastro de clientes e fornecedores.', 2),
            ('PROXIMA_FASE', N'Financeiro: contas a pagar e a receber.', 1),
            ('PROXIMA_FASE', N'Preparação da migração dos dados do sistema antigo.', 2)
         ) v (SECAO, TEXTO, ORDEM)
    CROSS JOIN SIS.Comunicado c
    WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO';
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'SIS_COMUNICADO', N'Comunicados', 'TELA', 'sis/comunicados.html', 30, 0, 1,
       'SIS.Comunicado,SIS.Comunicado_Item'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_EMAILS'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_COMUNICADO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('ALTERAR'), ('ENVIAR'), ('APROVAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'SIS_COMUNICADO'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

INSERT INTO SIS.Rotina (CODIGO, NOME, DESCRICAO, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, HORARIO, DIAS_SEMANA, DIA_MES,
                        TEMPO_LIMITE_MINUTOS, ATIVA, PROXIMA_EXECUCAO, USUARIO_CRIACAO)
SELECT 'COMUNICADO_PREVIA', N'Prévia dos comunicados semanais',
       N'Monta o comunicado da semana (boletim da implantação) e manda a prévia para aprovação. O envio oficial só sai depois de "Aprovar e enviar" na tela Comunicados.',
       N'SIS.SIS_Comunicado_Previa_Processar', m.ID_MODULO, 'SEMANAL', 0, '09:00', '6', 0, 30, 1,
       SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '09:00', '6', 0, SYSDATETIME()), N'instalacao'
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Rotina r WHERE r.CODIGO = 'COMUNICADO_PREVIA');
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comunicado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comunicado_Item', @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/Carga_CAD_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do CAD e do BANCO
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas 11 tabelas da etapa 03a, gerando cada
                trigger com SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas. No MASTER
                fica na parte 8 (triggers).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Banco',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Conta',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Centro_Custo',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa',                @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Contato',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Vinculo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Dado_Bancario',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Grupo',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Subgrupo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Conta',           @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do FIN e do BANCO (03c)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de negócio da 03c. Não
                entram: Arquivo_Morto (só consulta, carga da migração) e as linhas
                do extrato (vêm do arquivo do banco). CAD.Empresa é regerada por
                causa da coluna nova PASTA_OFX.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Historico_Padrao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Mes_Fechado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Transferencia',    @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Movimento',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Lancamento',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Parcela',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Baixa',            @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.Tabelas_Transformacao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : tabelas da transformação do movimento (schema MIG)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Etapa 03c2, parte B.
                MIG.Caso                 documentos do Access (unidades: lote,
                                         venda ou avulso) que não se encaixam em
                                         nenhuma regra, mais os que já têm
                                         correção da tela (REGRA_ATUAL mostra
                                         como ficaram; MOTIVO_ORIGINAL guarda o
                                         motivo da primeira vez). Atualizada a
                                         cada rodada.
                MIG.Caso_Correcao        decisão por documento, gravada pela
                                         tela de casos: IGNORAR (não migra) ou
                                         ARQUIVO_MORTO (vai para o arquivo morto).
                MIG.Caso_Correcao_Linha  correção por linha do Access (obra,
                                         pessoa, conta, plano, datas, valores,
                                         confirmado, ignorar a linha), aplicada a
                                         cada rodada antes da classificação.
                MIG.Linha_Destino        para cada linha do Access, o que ela
                                         virou no sistema novo (conferência).
                MIG.DePara_Venda         parcelas de venda: ligação com o imóvel
                                         e o contrato do Access (fase 5).
                As correções ficam guardadas pelo código do Access (origem +
                número), então valem em toda nova rodada até a virada.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
    v1.1 (18/11/2026) - Tela de casos: MIG.Caso ganha REGRA_ATUAL e
                        MOTIVO_ORIGINAL; tabelas de correção ganham chave
                        numérica (ID) e campos padrão de criação/alteração, para
                        a auditoria (SIS.Auditoria) registrar quem corrigiu o
                        quê; Caso_Correcao_Linha ganha UNIDADE. As tabelas de
                        correção vazias no formato antigo são refeitas.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[MIG].[Caso]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso]
    (
        UNIDADE        VARCHAR(40)    NOT NULL CONSTRAINT PK_Caso PRIMARY KEY,
        PADRAO         VARCHAR(200)   NOT NULL CONSTRAINT DF_Caso_PADRAO DEFAULT (''),
        MOTIVO         NVARCHAR(400)  NOT NULL,
        DETALHE        NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_DETALHE DEFAULT (N''),
        LINHAS         INT            NOT NULL,
        VALOR_DEBITO   DECIMAL(18,2)  NOT NULL,
        VALOR_CREDITO  DECIMAL(18,2)  NOT NULL,
        DT_DOCUMENTO   DATE           NULL,
        DT_CALCULO     DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_DT DEFAULT (SYSDATETIME())
    );
GO

IF COL_LENGTH(N'MIG.Caso', N'DETALHE') IS NULL
    ALTER TABLE [MIG].[Caso] ADD DETALHE NVARCHAR(400) NOT NULL CONSTRAINT DF_Caso_DETALHE DEFAULT (N'');
GO
IF COL_LENGTH(N'MIG.Caso', N'REGRA_ATUAL') IS NULL
    ALTER TABLE [MIG].[Caso] ADD REGRA_ATUAL VARCHAR(15) NOT NULL CONSTRAINT DF_Caso_REGRA_ATUAL DEFAULT ('CASO');
GO
IF COL_LENGTH(N'MIG.Caso', N'MOTIVO_ORIGINAL') IS NULL
    ALTER TABLE [MIG].[Caso] ADD MOTIVO_ORIGINAL NVARCHAR(400) NOT NULL CONSTRAINT DF_Caso_MOTIVO_ORIGINAL DEFAULT (N'');
GO

-- formato antigo (sem ID) e vazio: refaz (a auditoria precisa de chave numérica)
IF OBJECT_ID(N'[MIG].[Caso_Correcao]', N'U') IS NOT NULL AND COL_LENGTH(N'MIG.Caso_Correcao', N'ID_CASO_CORRECAO') IS NULL
   AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao)
    DROP TABLE [MIG].[Caso_Correcao];
IF OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]', N'U') IS NOT NULL AND COL_LENGTH(N'MIG.Caso_Correcao_Linha', N'ID_CASO_CORRECAO_LINHA') IS NULL
   AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha)
    DROP TABLE [MIG].[Caso_Correcao_Linha];
GO

IF OBJECT_ID(N'[MIG].[Caso_Correcao]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso_Correcao]
    (
        ID_CASO_CORRECAO   INT            IDENTITY(1,1) NOT NULL CONSTRAINT PK_Caso_Correcao PRIMARY KEY,
        UNIDADE            VARCHAR(40)    NOT NULL,
        ACAO               VARCHAR(15)    NOT NULL,
        MOTIVO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_Correcao_MOTIVO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_Correcao_DT_CRIACAO DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL,
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT UQ_Caso_Correcao_UNIDADE UNIQUE (UNIDADE),
        CONSTRAINT CK_Caso_Correcao_ACAO CHECK (ACAO IN ('IGNORAR', 'ARQUIVO_MORTO'))
    );
GO

IF OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso_Correcao_Linha]
    (
        ID_CASO_CORRECAO_LINHA INT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_Caso_Correcao_Linha PRIMARY KEY,
        ORIGEM             VARCHAR(20)    NOT NULL,
        NUM                INT            NOT NULL,
        UNIDADE            VARCHAR(40)    NOT NULL,
        EMP_VINCULADA      INT            NULL,       -- NULL = mantém o valor do Access
        PARCEIRO           INT            NULL,
        CONTA              INT            NULL,
        PLANO3             INT            NULL,
        DT_MOVTO           DATE           NULL,
        DT_VENCTO          DATE           NULL,
        DT_PAGTO           DATE           NULL,
        VALOR_DEBITO       DECIMAL(18,2)  NULL,
        VALOR_CREDITO      DECIMAL(18,2)  NULL,
        CONFIRMADO         BIT            NULL,
        IGNORAR_LINHA      BIT            NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_IGN    DEFAULT (0),
        MOTIVO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_MOTIVO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_DT_CRIACAO DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL,
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT UQ_Caso_Correcao_Linha UNIQUE (ORIGEM, NUM),
        CONSTRAINT CK_Caso_Correcao_Linha_VALOR CHECK (ISNULL(VALOR_DEBITO, 0) >= 0 AND ISNULL(VALOR_CREDITO, 0) >= 0)
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]') AND name = N'IX_Caso_Correcao_Linha_UNIDADE')
    CREATE NONCLUSTERED INDEX IX_Caso_Correcao_Linha_UNIDADE ON [MIG].[Caso_Correcao_Linha] (UNIDADE);
GO

IF OBJECT_ID(N'[MIG].[Linha_Destino]', N'U') IS NULL
    CREATE TABLE [MIG].[Linha_Destino]
    (
        ORIGEM            VARCHAR(20)    NOT NULL,
        NUM               INT            NOT NULL,
        UNIDADE           VARCHAR(40)    NOT NULL,
        REGRA             VARCHAR(12)    NOT NULL,
        PAPEL             VARCHAR(15)    NOT NULL,     -- TITULO / PAGAMENTO / CONTRAPARTIDA / TRANSFERENCIA
        ID_LANCAMENTO     BIGINT         NULL,
        ID_MOVIMENTO      BIGINT         NULL,
        ID_TRANSFERENCIA  BIGINT         NULL,
        ID_CONTA          INT            NULL,
        VALOR             DECIMAL(18,2)  NOT NULL,
        CONSTRAINT PK_Linha_Destino PRIMARY KEY (ORIGEM, NUM)
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Venda]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Venda]
    (
        ID_LANCAMENTO  BIGINT         NOT NULL CONSTRAINT PK_DePara_Venda PRIMARY KEY,
        ORIGEM         VARCHAR(20)    NOT NULL,
        NUM            INT            NOT NULL,
        LINK_VENDA     INT            NOT NULL,
        IMOVEL         INT            NULL,
        PARCEIRO       INT            NULL,
        CONTRATO       VARCHAR(40)    NOT NULL,
        NUM_DOC        NVARCHAR(100)  NOT NULL
    );
GO

-- auditoria das correções feitas pela tela (quem, quando, antes e depois)
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'MIG.Caso_Correcao',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'MIG.Caso_Correcao_Linha', @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Movimento_Transformar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Movimento_Transformar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Etapa 03c2, parte B: transforma os documentos do Access que vão
                para o sistema novo (MIG.Movimento, DESTINO = 'SISTEMA') em
                lançamento, parcela, baixa, movimento bancário e transferência,
                pelas regras aprovadas pelo Celso em 18/11/2026
                (docs/requisitos/Migracao_Movimento.md, seção 9):
                  LOTE      títulos da conta "Pagto em Lote" + uma saída (banco
                            ou caixinha) com o mesmo total: cada título vira conta
                            a pagar; a saída vira UM movimento ligado a todas as
                            baixas; o lote do Access vira um SIS.Lote;
                  VENDA     linha da conta "Débitos" (cliente) + entrada no banco
                            ou caixa: conta a receber; ligação com o contrato em
                            MIG.DePara_Venda;
                  AVULSO    pagamentos e recebimentos direto no banco ou no caixa
                            (caixinha = conta Caixa da empresa);
                  TRANSF    créditos e débitos soltos: transferência entre o banco
                            e o Caixa contábil da empresa (banco da linha, se
                            houver; senão a conta padrão da obra ou da empresa);
                  CASO      o resto: MIG.Caso, para a tela de correção.
                Correções da tela (MIG.Caso_Correcao e Caso_Correcao_Linha) são
                aplicadas antes da classificação.
                Situação: linha confirmada = baixa; "efetuado" sem "confirmado"
                com data de pagamento = baixa não compensada (cheque); sem data
                = parcela em aberto. "Somente integração" = lançamento só
                contábil e baixa sem movimento no banco.
                @Unidade (tela de casos, botão "Conferir"): classifica só aquele
                documento, atualiza a linha dele em MIG.Caso e devolve uma
                linha (UNIDADE, REGRA, MOTIVO, DETALHE); nada é gravado no
                financeiro.
                MIG.Caso guarda os casos e também os documentos que já têm
                correção da tela (REGRA_ATUAL = como ficaram), para a tela
                mostrar o que foi resolvido.
                @Executar = 0 (padrão): só a prévia (classificação e números),
                nada é gravado no financeiro. @Executar = 1: apaga a carga
                anterior da migração (lotes de origem MIGRACAO) e grava de novo,
                tudo-ou-nada. Usuário "sistema", origem MIGRACAO.
                Pré-requisito: MIG_Movimento_Preparar e MIG_Cadastros_Processar.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
    v1.1 (18/11/2026) - Tela de casos: parâmetro @Unidade (conferir um
                        documento só); MIG.Caso atualizada por MERGE, mantendo
                        os documentos corrigidos (REGRA_ATUAL, MOTIVO_ORIGINAL).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Movimento_Transformar;                 -- prévia
    -- EXEC MIG.MIG_Movimento_Transformar @Executar = 1;   -- grava
    -- EXEC MIG.MIG_Movimento_Transformar @Unidade = 'L:123'; -- confere um documento
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Movimento_Transformar]
    @Executar           BIT          = 0,
    @NomeCaixa          NVARCHAR(60) = N'Caixa',
    @NomeCaixaContabil  NVARCHAR(60) = N'Caixa contábil',
    @Unidade            VARCHAR(40)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[MIG].[MIG_Movimento_Transformar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @IdSistema    INT;
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @IdPrincipal  INT;
    DECLARE @IdLoteGeral  BIGINT;
    DECLARE @Agora        DATETIME2(0) = SYSDATETIME();

    BEGIN TRY
        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo;

        IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
            THROW 50001, N'Rode antes o MIG.MIG_Movimento_Preparar.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.DePara_Centro) OR NOT EXISTS (SELECT 1 FROM MIG.DePara_Plano)
            THROW 50001, N'Rode antes o MIG.MIG_Cadastros_Processar.', 1;
        IF @Unidade IS NOT NULL AND ISNULL(@Executar, 0) = 1
            THROW 50001, N'A conferência de um documento só (@Unidade) não grava: rode sem @Executar.', 1;

        SELECT @IdSistema = u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdSistema);
        EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Origem = N'MIGRACAO';
        SELECT @IdPrincipal = e.ID_EMPRESA
        FROM CAD.Empresa e INNER JOIN MIG.Classif_Empresa c ON c.CODIGO_MASTER = e.CODIGO_ACCESS AND c.PRINCIPAL = 1;

        /* ------------------------------------------------------------------
           1. Linhas do Access (com as correções da tela) e os de-paras
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Linhas';
        SELECT h.CodHistorico AS COD, f.ID_HISTORICO_PADRAO
        INTO #Hist
        FROM (SELECT TRY_CONVERT(INT, a.CodHistorico) AS CodHistorico, LEFT(LTRIM(RTRIM(ISNULL(a.Descricao, N''))), 80) AS DESCRICAO FROM MIG.Access_Historico a) h
        CROSS APPLY (SELECT TOP (1) x.ID_HISTORICO_PADRAO FROM FIN.Historico_Padrao x
                     WHERE x.CODIGO_ACCESS = h.CodHistorico OR x.DESCRICAO = h.DESCRICAO
                     ORDER BY CASE WHEN x.CODIGO_ACCESS = h.CodHistorico THEN 0 ELSE 1 END) f
        WHERE h.CodHistorico IS NOT NULL;

        SELECT m.ORIGEM, m.NUM, m.UNIDADE, m.PADRAO, m.CONTRATO, m.LINK_VENDA, m.IMOVEL,
               COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS EV,
               COALESCE(o.PARCEIRO, m.PARCEIRO)           AS PAR,
               COALESCE(o.CONTA, m.CONTA)                 AS CONTA,
               COALESCE(o.PLANO3, m.PLANO3)               AS P3,
               m.HISTORICO,
               CASE WHEN COALESCE(o.DT_MOVTO,  m.DT_MOVTO)  BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_MOVTO,  m.DT_MOVTO)  END AS DM,
               CASE WHEN COALESCE(o.DT_VENCTO, m.DT_VENCTO) BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_VENCTO, m.DT_VENCTO) END AS DV,
               CASE WHEN COALESCE(o.DT_PAGTO,  m.DT_PAGTO)  BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_PAGTO,  m.DT_PAGTO)  END AS DP,
               m.DT_UNIDADE,
               COALESCE(o.VALOR_DEBITO, m.VALOR_DEBITO)   AS DEB,
               COALESCE(o.VALOR_CREDITO, m.VALOR_CREDITO) AS CRE,
               COALESCE(o.CONFIRMADO, m.CONFIRMADO)       AS CONF,
               m.EFETUADO AS EFET, m.INTEGRACAO AS INTEG, m.SOMENTE_INTEGRACAO AS SOI,
               m.NUM_DOC, m.COMPLEMENTO, m.OBSERVACAO, m.NOTA_FISCAL,
               CAST('' AS VARCHAR(4)) AS TC, CAST('' AS CHAR(1)) AS LADO, CAST(0 AS DECIMAL(18,2)) AS VALOR,
               CAST(NULL AS INT) AS ID_CENTRO, CAST(NULL AS INT) AS ID_EMPRESA, CAST(NULL AS INT) AS ID_CONTA_PADRAO,
               CAST(NULL AS INT) AS ID_PESSOA, CAST(NULL AS INT) AS ID_PLANO, CAST(NULL AS INT) AS ID_CONTA_BCO,
               CAST(NULL AS INT) AS ID_EMPRESA_BCO, CAST(NULL AS INT) AS ID_HIST
        INTO #L
        FROM MIG.Movimento m
        LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
        WHERE m.DESTINO = 'SISTEMA'
          AND (@Unidade IS NULL OR m.UNIDADE = @Unidade)
          AND ISNULL(o.IGNORAR_LINHA, 0) = 0
          AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao c WHERE c.UNIDADE = m.UNIDADE);

        CREATE UNIQUE CLUSTERED INDEX IX_L ON #L (ORIGEM, NUM);
        CREATE INDEX IX_L_U ON #L (UNIDADE);

        UPDATE l
           SET l.TC    = CASE l.CONTA WHEN 1 THEN 'CRED' WHEN 2 THEN 'DEB' WHEN 3 THEN 'LOTE' WHEN 9 THEN 'NA' ELSE 'BCO' END,
               l.LADO  = CASE WHEN l.DEB > 0 AND l.CRE > 0 THEN 'X' WHEN l.DEB > 0 THEN 'D' WHEN l.CRE > 0 THEN 'C' ELSE '0' END,
               l.VALOR = l.DEB + l.CRE
        FROM #L l;

        UPDATE l
           SET l.ID_CENTRO       = COALESCE(dp.ID_CENTRO_CUSTO, dc.ID_CENTRO_CUSTO),
               l.ID_EMPRESA      = COALESCE(cc.ID_EMPRESA, dc.ID_EMPRESA),
               l.ID_CONTA_PADRAO = dc.ID_CONTA_PADRAO,
               l.ID_PESSOA       = p.ID_PESSOA,
               l.ID_PLANO        = dp.ID_PLANO_CONTA,
               l.ID_CONTA_BCO    = CASE WHEN l.TC = 'BCO' THEN k.ID_CONTA END,
               l.ID_EMPRESA_BCO  = CASE WHEN l.TC = 'BCO' THEN k.ID_EMPRESA END,
               l.ID_HIST         = h.ID_HISTORICO_PADRAO
        FROM #L l
        LEFT JOIN MIG.DePara_Centro dc ON dc.CODIGO_VINCULADA = l.EV
        LEFT JOIN MIG.DePara_Plano dp  ON dp.PLANO3_ACCESS = l.P3
        LEFT JOIN CAD.Centro_Custo cc  ON cc.ID_CENTRO_CUSTO = dp.ID_CENTRO_CUSTO
        LEFT JOIN CAD.Pessoa p         ON p.CODIGO_ACCESS = l.PAR AND l.PAR > 1
        LEFT JOIN BANCO.Conta k        ON k.CODIGO_ACCESS = l.CONTA
        LEFT JOIN #Hist h              ON h.COD = l.HISTORICO;

        /* ------------------------------------------------------------------
           2. Classificação de cada documento (unidade)
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Classificação';
        SELECT l.UNIDADE, MIN(l.PADRAO) AS PADRAO, LEFT(l.UNIDADE, 1) AS TIPO_U,
               COUNT(*) AS N, MIN(l.DT_UNIDADE) AS DT_UNIDADE,
               SUM(l.DEB) AS S_DEB_TOTAL, SUM(l.CRE) AS S_CRE_TOTAL,
               SUM(CASE WHEN l.LADO = 'X' THEN 1 ELSE 0 END) AS N_DUPLO,
               SUM(CASE WHEN l.LADO IN ('D', 'C') THEN 1 ELSE 0 END) AS N_NZ,
               SUM(CASE WHEN l.TC = 'LOTE' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_LOTE,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_PAG,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_REC,
               SUM(CASE WHEN l.TC = 'BCO' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_PAG_BCO,
               SUM(CASE WHEN l.TC = 'BCO' AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_REC_BCO,
               SUM(CASE WHEN l.TC = 'CRED' AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_CRED,
               SUM(CASE WHEN l.TC = 'DEB' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_DEBD,
               SUM(CASE WHEN l.LADO IN ('D', 'C') AND NOT ((l.TC = 'LOTE' AND l.LADO = 'D') OR l.TC IN ('BCO', 'NA')
                                                         OR (l.TC = 'CRED' AND l.LADO = 'C') OR (l.TC = 'DEB' AND l.LADO = 'D')) THEN 1 ELSE 0 END) AS N_OUTRO,
               SUM(CASE WHEN l.TC = 'LOTE' AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_LOTE,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_PAG,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'C' THEN l.VALOR ELSE 0 END) AS S_REC,
               SUM(CASE WHEN l.TC = 'CRED' AND l.LADO = 'C' THEN l.VALOR ELSE 0 END) AS S_CRED,
               SUM(CASE WHEN l.TC = 'DEB' AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_DEBD,
               SUM(CASE WHEN l.TC IN ('CRED', 'DEB') AND l.LADO IN ('D', 'C') AND l.CONF = 0 THEN 1 ELSE 0 END) AS N_TR_NAO_CONF,
               CAST('' AS VARCHAR(12)) AS REGRA, CAST(N'' AS NVARCHAR(400)) AS MOTIVO, CAST(N'' AS NVARCHAR(400)) AS DETALHE
        INTO #U
        FROM #L l
        GROUP BY l.UNIDADE;

        UPDATE u
           SET u.REGRA = CASE
                   WHEN u.N_DUPLO > 0 THEN 'CASO'
                   WHEN u.N_NZ = 0 THEN 'CASO'
                   WHEN u.N_OUTRO > 0 THEN 'CASO'
                   WHEN u.N_LOTE > 0 AND u.TIPO_U = 'L' AND u.N_PAG = 1 AND u.N_REC = 0 AND u.N_DEBD = 0 AND ABS(u.S_LOTE - u.S_PAG) <= 0.01 THEN 'LOTE'
                   WHEN u.N_LOTE > 0 THEN 'CASO'
                   WHEN u.TIPO_U = 'V' AND u.N_NZ = 2 AND u.N_DEBD = 1 AND u.N_REC = 1 AND ABS(u.S_DEBD - u.S_REC) <= 0.01 THEN 'VENDA'
                   WHEN u.TIPO_U = 'V' THEN 'CASO'
                   WHEN u.N_NZ = 2 AND u.N_PAG_BCO = 1 AND u.N_CRED = 1 AND u.S_PAG = u.S_CRED THEN 'TRANSF_PAR'
                   WHEN u.N_NZ = 2 AND u.N_REC_BCO = 1 AND u.N_DEBD = 1 AND u.S_REC = u.S_DEBD THEN 'TRANSF_PAR'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ AND u.N_TR_NAO_CONF = 0 THEN 'TRANSF'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ THEN 'CASO'
                   WHEN u.N_CRED + u.N_DEBD = 0 THEN 'AVULSO'
                   ELSE 'CASO' END,
               u.MOTIVO = CASE
                   WHEN u.N_DUPLO > 0 THEN N'Linha com débito e crédito ao mesmo tempo'
                   WHEN u.N_NZ = 0 THEN N'Documento com valor zero'
                   WHEN u.N_OUTRO > 0 THEN N'Combinação de contas não prevista (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')'
                   WHEN u.N_LOTE > 0 AND u.TIPO_U <> 'L' THEN N'Título de pagamento em lote fora de um lote'
                   WHEN u.N_LOTE > 0 AND u.N_PAG = 0 THEN N'Pagamento em lote sem a saída do banco ou do caixa'
                   WHEN u.N_LOTE > 0 AND u.N_PAG > 1 THEN N'Pagamento em lote com mais de uma saída'
                   WHEN u.N_LOTE > 0 AND (u.N_REC > 0 OR u.N_DEBD > 0) THEN N'Pagamento em lote com entrada no mesmo lote'
                   WHEN u.N_LOTE > 0 THEN N'Total dos títulos do lote diferente da saída do banco ou do caixa'
                   WHEN u.TIPO_U = 'V' THEN N'Parcela de venda fora do padrão (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ THEN N'Transferência não confirmada'
                   ELSE N'Combinação de contas não prevista (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')' END
        FROM #U u;
        UPDATE #U SET DETALHE = N'Títulos ' + FORMAT(S_LOTE, 'N2', 'pt-BR') + N'; saída ' + FORMAT(S_PAG, 'N2', 'pt-BR')
        WHERE REGRA = 'CASO' AND N_LOTE > 0;
        UPDATE #U SET MOTIVO = N'', DETALHE = N'' WHERE REGRA <> 'CASO';

        /* ------------------------------------------------------------------
           3. Contas auxiliares: centro administrativo, caixa e Caixa contábil
              de cada empresa
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Contas auxiliares';
        SELECT c.ID_EMPRESA, MIN(c.ID_CENTRO_CUSTO) AS ID_CENTRO
        INTO #CentroAdm
        FROM CAD.Centro_Custo c
        WHERE c.TIPO = 'ADMINISTRATIVO' AND c.ATIVO = 1 AND c.CODIGO_ACCESS IS NOT NULL
        GROUP BY c.ID_EMPRESA;

        SELECT e.ID_EMPRESA,
               (SELECT TOP (1) k.ID_CONTA FROM BANCO.Conta k
                WHERE k.ID_EMPRESA = e.ID_EMPRESA AND k.TIPO = 'CAIXA' AND k.DESCRICAO <> @NomeCaixaContabil
                ORDER BY k.ATIVO DESC, CASE WHEN k.CODIGO_ACCESS IS NULL THEN 1 ELSE 0 END, k.ID_CONTA) AS ID_CONTA
        INTO #Caixa
        FROM CAD.Empresa e
        WHERE e.CODIGO_ACCESS IS NOT NULL;

        SELECT k.ID_EMPRESA, MIN(k.ID_CONTA) AS ID_CONTA
        INTO #CxContabil
        FROM BANCO.Conta k
        WHERE k.TIPO = 'CAIXA' AND k.DESCRICAO = @NomeCaixaContabil
        GROUP BY k.ID_EMPRESA;

        /* ------------------------------------------------------------------
           4. Títulos (lançamentos) e transferências a gerar
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Títulos';
        -- linha que paga/recebe em cada LOTE e VENDA
        ;WITH Pag AS
        (
            SELECT l.UNIDADE, l.ORIGEM, l.NUM, l.TC, l.CONF, l.EFET, l.SOI, l.DP, l.DM, l.DV, l.ID_CONTA_BCO, l.ID_EMPRESA, l.ID_CENTRO, l.ID_PLANO,
                   l.ID_PESSOA, l.EV, l.VALOR, l.COMPLEMENTO, l.NUM_DOC, l.INTEG,
                   ROW_NUMBER() OVER (PARTITION BY l.UNIDADE ORDER BY l.NUM) AS RN
            FROM #L l
            INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
            WHERE (u.REGRA = 'LOTE'  AND l.TC IN ('BCO', 'NA') AND l.LADO = 'D')
               OR (u.REGRA = 'VENDA' AND l.TC IN ('BCO', 'NA') AND l.LADO = 'C')
        )
        SELECT t.ORIGEM, t.NUM, t.UNIDADE, u.REGRA,
               CAST(CASE WHEN u.REGRA = 'VENDA' THEN 'R' WHEN u.REGRA = 'LOTE' THEN 'P' WHEN t.LADO = 'D' THEN 'P' ELSE 'R' END AS CHAR(1)) AS TIPO,
               -- obra/plano: na venda vêm da linha da entrada; nos demais, do próprio título
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_CENTRO, t.ID_CENTRO) ELSE t.ID_CENTRO END AS ID_CENTRO,
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_EMPRESA, t.ID_EMPRESA) ELSE t.ID_EMPRESA END AS ID_EMPRESA,
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_PLANO, t.ID_PLANO) ELSE t.ID_PLANO END AS ID_PLANO,
               COALESCE(t.ID_PESSOA, p.ID_PESSOA) AS ID_PESSOA,
               t.ID_HIST,
               CAST(LEFT(ISNULL(t.NUM_DOC, N''), 40) AS NVARCHAR(40)) AS DOCUMENTO,
               COALESCE(t.DM, t.DV, t.DT_UNIDADE) AS DT_EMISSAO,
               COALESCE(t.DV, t.DM, t.DT_UNIDADE) AS DT_VENC,
               CAST(LEFT(ISNULL(NULLIF(t.COMPLEMENTO, N''), ISNULL(p.COMPLEMENTO, N'')), 200) AS NVARCHAR(200)) AS HISTORICO,
               CAST(LEFT(CONCAT_WS(N' | ', NULLIF(t.OBSERVACAO, N''), N'NF: ' + NULLIF(t.NOTA_FISCAL, N''),
                                   N'Access: ' + t.ORIGEM + N' ' + CONVERT(NVARCHAR(12), t.NUM) + N', documento ' + t.UNIDADE), 2000) AS NVARCHAR(2000)) AS OBSERVACAO,
               t.VALOR,
               CAST(CASE WHEN t.SOI = 1 THEN 'SO_CONTABIL' WHEN t.INTEG = 1 THEN 'COMPLETA' ELSE 'NENHUMA' END AS VARCHAR(12)) AS INTEGRACAO,
               -- quem paga: a linha da saída/entrada (LOTE/VENDA) ou o próprio título (AVULSO)
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.TC ELSE t.TC END AS TC_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ID_CONTA_BCO ELSE t.ID_CONTA_BCO END AS ID_CONTA_BCO,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.CONF ELSE t.CONF END AS CONF,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.EFET ELSE t.EFET END AS EFET,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.SOI ELSE t.SOI END AS SOI_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN COALESCE(p.DP, p.DM, t.DP, t.DM) ELSE COALESCE(t.DP, t.DM, t.DV) END AS DT_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.DP ELSE t.DP END AS DP_ORIGINAL,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ORIGEM ELSE t.ORIGEM END AS PAG_ORIGEM,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.NUM ELSE t.NUM END AS PAG_NUM,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ID_EMPRESA ELSE NULL END AS ID_EMPRESA_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN ISNULL(p.COMPLEMENTO, N'') ELSE ISNULL(t.COMPLEMENTO, N'') END AS HIST_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN ISNULL(p.NUM_DOC, N'') ELSE ISNULL(t.NUM_DOC, N'') END AS DOC_PAG,
               t.LINK_VENDA, t.IMOVEL, t.PAR, t.CONTRATO, t.NUM_DOC,
               CAST(NULL AS INT) AS ID_CONTA_PAG,
               CAST(0 AS BIT) AS PAGO, CAST(1 AS BIT) AS COMPENSADO, CAST(0 AS BIT) AS GERA_MOV
        INTO #T
        FROM #L t
        INNER JOIN #U u ON u.UNIDADE = t.UNIDADE
        LEFT JOIN Pag p ON p.UNIDADE = t.UNIDADE AND p.RN = 1 AND u.REGRA IN ('LOTE', 'VENDA')
        WHERE (u.REGRA = 'LOTE'   AND t.TC = 'LOTE' AND t.LADO = 'D')
           OR (u.REGRA = 'VENDA'  AND t.TC = 'DEB'  AND t.LADO = 'D')
           OR (u.REGRA = 'AVULSO' AND t.TC IN ('BCO', 'NA') AND t.LADO IN ('D', 'C'));

        -- empresa e obra: sem obra no Access ("N/A"), usa a empresa da conta que pagou e a área administrativa dela
        UPDATE t SET t.ID_EMPRESA = COALESCE(t.ID_EMPRESA, t.ID_EMPRESA_PAG, k.ID_EMPRESA, @IdPrincipal)
        FROM #T t LEFT JOIN BANCO.Conta k ON k.ID_CONTA = t.ID_CONTA_BCO;
        UPDATE t SET t.ID_CENTRO = a.ID_CENTRO
        FROM #T t INNER JOIN #CentroAdm a ON a.ID_EMPRESA = t.ID_EMPRESA
        WHERE t.ID_CENTRO IS NULL;

        -- conta que pagou: o banco da linha ou o caixa da empresa (no lote, a empresa do 1º título)
        ;WITH EmpLote AS (SELECT t.UNIDADE, MIN(t.ID_EMPRESA) AS ID_EMPRESA FROM #T t WHERE t.REGRA = 'LOTE' GROUP BY t.UNIDADE)
        UPDATE t
           SET t.ID_CONTA_PAG = CASE WHEN t.TC_PAG = 'BCO' THEN t.ID_CONTA_BCO
                                     ELSE (SELECT c.ID_CONTA FROM #Caixa c WHERE c.ID_EMPRESA = COALESCE(t.ID_EMPRESA_PAG, el.ID_EMPRESA, t.ID_EMPRESA)) END,
               t.PAGO       = CASE WHEN t.CONF = 1 OR (t.EFET = 1 AND t.DP_ORIGINAL IS NOT NULL) THEN 1 ELSE 0 END,
               t.COMPENSADO = CASE WHEN t.CONF = 1 THEN 1 ELSE 0 END
        FROM #T t LEFT JOIN EmpLote el ON el.UNIDADE = t.UNIDADE;
        UPDATE #T SET GERA_MOV = CASE WHEN PAGO = 1 AND COMPENSADO = 1 AND SOI_PAG = 0 THEN 1 ELSE 0 END;

        -- transferências (créditos e débitos soltos; pares banco + contrapartida)
        SET @EtapaAtual = 'Transferências';
        SELECT l.ORIGEM, l.NUM, l.UNIDADE, u.REGRA,
               COALESCE(l.DP, l.DM, l.DV) AS DT,
               l.VALOR,
               CAST(LEFT(CONCAT_WS(N' - ', NULLIF(l.COMPLEMENTO, N''), NULLIF(l.NUM_DOC, N''), N'Access ' + CONVERT(NVARCHAR(12), l.NUM)), 200) AS NVARCHAR(200)) AS HISTORICO,
               -- banco: o da linha do par; senão a conta padrão da obra; senão a da empresa
               COALESCE(b.ID_CONTA_BCO, l.ID_CONTA_PADRAO, e.ID_CONTA_BANCARIA_PADRAO) AS ID_BANCO,
               l.LADO, l.TC, l.ID_EMPRESA,
               b.ORIGEM AS BCO_ORIGEM, b.NUM AS BCO_NUM,
               CAST(NULL AS INT) AS ID_CX, CAST(NULL AS INT) AS ID_ORIGEM, CAST(NULL AS INT) AS ID_DESTINO
        INTO #TR
        FROM #L l
        INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
        LEFT JOIN #L b ON b.UNIDADE = l.UNIDADE AND u.REGRA = 'TRANSF_PAR' AND b.TC = 'BCO'
        LEFT JOIN CAD.Empresa e ON e.ID_EMPRESA = l.ID_EMPRESA
        WHERE u.REGRA IN ('TRANSF', 'TRANSF_PAR') AND ((l.TC = 'CRED' AND l.LADO = 'C') OR (l.TC = 'DEB' AND l.LADO = 'D'));

        UPDATE r
           SET r.ID_CX      = x.ID_CONTA,
               r.ID_ORIGEM  = CASE WHEN r.TC = 'CRED' THEN r.ID_BANCO ELSE x.ID_CONTA END,   -- crédito solto: saque do banco para o caixa contábil
               r.ID_DESTINO = CASE WHEN r.TC = 'CRED' THEN x.ID_CONTA ELSE r.ID_BANCO END    -- débito solto: do caixa contábil para o banco
        FROM #TR r
        LEFT JOIN BANCO.Conta k ON k.ID_CONTA = r.ID_BANCO
        LEFT JOIN #CxContabil x ON x.ID_EMPRESA = k.ID_EMPRESA;

        -- transferência sem banco identificável vira caso
        UPDATE u SET u.REGRA = 'CASO', u.MOTIVO = N'Transferência sem conta bancária identificável (obra sem conta padrão)'
        FROM #U u WHERE EXISTS (SELECT 1 FROM #TR r WHERE r.UNIDADE = u.UNIDADE AND (r.ID_ORIGEM IS NULL OR r.ID_DESTINO IS NULL OR r.ID_ORIGEM = r.ID_DESTINO));
        DELETE r FROM #TR r INNER JOIN #U u ON u.UNIDADE = r.UNIDADE WHERE u.REGRA = 'CASO';

        -- título pago sem conta (empresa sem caixa) vira caso
        UPDATE u SET u.REGRA = 'CASO', u.MOTIVO = N'Pagamento sem conta identificável'
        FROM #U u WHERE EXISTS (SELECT 1 FROM #T t WHERE t.UNIDADE = u.UNIDADE AND t.PAGO = 1 AND t.ID_CONTA_PAG IS NULL AND t.TC_PAG = 'BCO');
        DELETE t FROM #T t INNER JOIN #U u ON u.UNIDADE = t.UNIDADE WHERE u.REGRA = 'CASO';

        -- casos para a tela, mais os documentos que já têm correção da tela
        SET @EtapaAtual = 'Casos';
        SELECT m.UNIDADE, MIN(m.PADRAO) AS PADRAO, COUNT(*) AS N, SUM(m.VALOR_DEBITO) AS D, SUM(m.VALOR_CREDITO) AS C,
               MIN(m.DT_UNIDADE) AS DT, MIN(cc.ACAO) AS ACAO
        INTO #Dec
        FROM MIG.Movimento m
        INNER JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = m.UNIDADE
        WHERE m.DESTINO = 'SISTEMA' AND (@Unidade IS NULL OR m.UNIDADE = @Unidade)
        GROUP BY m.UNIDADE;

        SELECT u.UNIDADE, CAST(ISNULL(u.PADRAO, '') AS VARCHAR(200)) AS PADRAO, CAST(u.REGRA AS VARCHAR(15)) AS REGRA,
               u.MOTIVO, u.DETALHE, u.N, u.S_DEB_TOTAL AS D, u.S_CRE_TOTAL AS C, u.DT_UNIDADE AS DT
        INTO #CasoNovo
        FROM #U u
        WHERE u.REGRA = 'CASO' OR EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = u.UNIDADE)
        UNION ALL
        SELECT d.UNIDADE, ISNULL(d.PADRAO, ''), d.ACAO, N'', N'', d.N, d.D, d.C, d.DT
        FROM #Dec d
        UNION ALL   -- todas as linhas do documento marcadas "ignorar": o documento fica de fora
        SELECT m.UNIDADE, MIN(m.PADRAO), 'IGNORAR', N'', N'', COUNT(*), SUM(m.VALOR_DEBITO), SUM(m.VALOR_CREDITO), MIN(m.DT_UNIDADE)
        FROM MIG.Movimento m
        WHERE m.DESTINO = 'SISTEMA' AND (@Unidade IS NULL OR m.UNIDADE = @Unidade)
          AND EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = m.UNIDADE)
          AND NOT EXISTS (SELECT 1 FROM #U u WHERE u.UNIDADE = m.UNIDADE)
          AND NOT EXISTS (SELECT 1 FROM #Dec d WHERE d.UNIDADE = m.UNIDADE)
        GROUP BY m.UNIDADE;

        BEGIN TRANSACTION;
        MERGE MIG.Caso AS c
        USING #CasoNovo AS n ON n.UNIDADE = c.UNIDADE
        WHEN MATCHED THEN UPDATE SET
             c.PADRAO = n.PADRAO, c.REGRA_ATUAL = n.REGRA, c.MOTIVO = n.MOTIVO, c.DETALHE = n.DETALHE,
             c.LINHAS = n.N, c.VALOR_DEBITO = n.D, c.VALOR_CREDITO = n.C, c.DT_DOCUMENTO = n.DT, c.DT_CALCULO = SYSDATETIME(),
             c.MOTIVO_ORIGINAL = CASE WHEN c.MOTIVO_ORIGINAL = N'' THEN c.MOTIVO ELSE c.MOTIVO_ORIGINAL END
        WHEN NOT MATCHED BY TARGET THEN
             INSERT (UNIDADE, PADRAO, REGRA_ATUAL, MOTIVO, MOTIVO_ORIGINAL, DETALHE, LINHAS, VALOR_DEBITO, VALOR_CREDITO, DT_DOCUMENTO)
             VALUES (n.UNIDADE, n.PADRAO, n.REGRA, n.MOTIVO, n.MOTIVO, n.DETALHE, n.N, n.D, n.C, n.DT)
        WHEN NOT MATCHED BY SOURCE AND (@Unidade IS NULL OR c.UNIDADE = @Unidade) THEN DELETE;
        COMMIT TRANSACTION;

        -- conferência de um documento só (tela de casos)
        IF @Unidade IS NOT NULL
        BEGIN
            SELECT CAST(@Unidade AS VARCHAR(40)) AS UNIDADE,
                   CAST(COALESCE(n.REGRA, u.REGRA, 'SEM_LINHAS') AS VARCHAR(15)) AS REGRA,
                   COALESCE(n.MOTIVO, u.MOTIVO, N'') AS MOTIVO,
                   COALESCE(n.DETALHE, u.DETALHE, N'') AS DETALHE
            FROM (SELECT 1 AS X) x
            LEFT JOIN #CasoNovo n ON n.UNIDADE = @Unidade
            LEFT JOIN #U u ON u.UNIDADE = @Unidade;
            DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo;
            RETURN;
        END;

        /* ------------------------------------------------------------------
           Prévia
           ------------------------------------------------------------------ */
        IF ISNULL(@Executar, 0) = 0
        BEGIN
            SELECT 'PREVIA' AS GRADE, u.REGRA, COUNT(*) AS DOCUMENTOS, SUM(u.N) AS LINHAS, SUM(u.S_DEB_TOTAL) AS DEBITOS, SUM(u.S_CRE_TOTAL) AS CREDITOS
            FROM #U u GROUP BY u.REGRA ORDER BY u.REGRA;
            SELECT 'TITULOS' AS GRADE, t.REGRA, t.TIPO, COUNT(*) AS LANCAMENTOS, SUM(t.VALOR) AS VALOR,
                   SUM(CASE WHEN t.PAGO = 1 THEN 1 ELSE 0 END) AS PAGOS, SUM(CASE WHEN t.PAGO = 0 THEN 1 ELSE 0 END) AS EM_ABERTO,
                   SUM(CASE WHEN t.PAGO = 1 AND t.COMPENSADO = 0 THEN 1 ELSE 0 END) AS NAO_COMPENSADOS,
                   SUM(CASE WHEN t.ID_PESSOA IS NULL THEN 1 ELSE 0 END) AS SEM_PESSOA, SUM(CASE WHEN t.ID_PLANO IS NULL THEN 1 ELSE 0 END) AS SEM_PLANO,
                   SUM(CASE WHEN t.ID_CENTRO IS NULL THEN 1 ELSE 0 END) AS SEM_CENTRO,
                   SUM(CASE WHEN t.PAGO = 1 AND t.ID_CONTA_PAG IS NULL THEN 1 ELSE 0 END) AS PAGO_SEM_CONTA
            FROM #T t GROUP BY t.REGRA, t.TIPO ORDER BY t.REGRA, t.TIPO;
            SELECT 'TRANSFERENCIAS' AS GRADE, r.REGRA, r.TC, COUNT(*) AS QTD, SUM(r.VALOR) AS VALOR FROM #TR r GROUP BY r.REGRA, r.TC;
            SELECT 'CASOS' AS GRADE, c.MOTIVO, COUNT(*) AS DOCUMENTOS, SUM(c.LINHAS) AS LINHAS FROM MIG.Caso c WHERE c.REGRA_ATUAL = 'CASO' GROUP BY c.MOTIVO ORDER BY COUNT(*) DESC;
            DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo;
            RETURN;
        END;

        /* ------------------------------------------------------------------
           5. Gravação (tudo-ou-nada)
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Gravação: limpeza da carga anterior';
        BEGIN TRANSACTION;

        DELETE b FROM FIN.Baixa b
        INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE l.ORIGEM = 'MIGRACAO';
        DELETE m FROM BANCO.Movimento m INNER JOIN SIS.Lote x ON x.ID_LOTE = m.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO';
        DELETE t FROM FIN.Transferencia t INNER JOIN SIS.Lote x ON x.ID_LOTE = t.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO';
        DELETE p FROM FIN.Parcela p INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.ORIGEM = 'MIGRACAO';
        DELETE FROM MIG.DePara_Venda;
        DELETE FROM FIN.Lancamento WHERE ORIGEM = 'MIGRACAO';
        DELETE FROM SIS.Lote WHERE ORIGEM = 'MIGRACAO';
        DELETE FROM MIG.Linha_Destino;

        SET @EtapaAtual = 'Gravação: caixas';
        INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, CONCILIA, MOSTRA_SALDO, ATIVO, USUARIO_CRIACAO)
        SELECT DISTINCT e.ID_EMPRESA, @NomeCaixa, 'CAIXA', 0, 1, 1, @Usuario
        FROM #T t
        INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = t.ID_EMPRESA
        WHERE t.TC_PAG = 'NA' AND t.ID_CONTA_PAG IS NULL
          AND NOT EXISTS (SELECT 1 FROM BANCO.Conta k WHERE k.ID_EMPRESA = e.ID_EMPRESA AND k.DESCRICAO = @NomeCaixa);
        UPDATE t SET t.ID_CONTA_PAG = k.ID_CONTA
        FROM #T t INNER JOIN BANCO.Conta k ON k.ID_EMPRESA = t.ID_EMPRESA AND k.DESCRICAO = @NomeCaixa
        WHERE t.TC_PAG = 'NA' AND t.ID_CONTA_PAG IS NULL;

        SET @EtapaAtual = 'Gravação: lotes';
        INSERT INTO SIS.Lote (ORIGEM, DESCRICAO, TABELA_REFERENCIA, QTD_REGISTROS, USUARIO_CRIACAO)
        VALUES ('MIGRACAO', N'Migração do movimento do Access (lançamentos avulsos, vendas e transferências)', N'FIN.Lancamento', 0, @Usuario);
        SET @IdLoteGeral = SCOPE_IDENTITY();

        CREATE TABLE #MapLote (UNIDADE VARCHAR(40) PRIMARY KEY, ID_LOTE BIGINT);
        MERGE SIS.Lote AS d
        USING (SELECT t.UNIDADE, COUNT(*) AS QTD FROM #T t WHERE t.REGRA = 'LOTE' GROUP BY t.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (ORIGEM, DESCRICAO, TABELA_REFERENCIA, QTD_REGISTROS, USUARIO_CRIACAO)
             VALUES ('MIGRACAO', N'Pagamento em lote do Access nº ' + SUBSTRING(s.UNIDADE, 3, 20), N'FIN.Lancamento', s.QTD, @Usuario)
        OUTPUT s.UNIDADE, inserted.ID_LOTE INTO #MapLote (UNIDADE, ID_LOTE);

        SET @EtapaAtual = 'Gravação: lançamentos';
        CREATE TABLE #MapLanc (ORIGEM VARCHAR(20), NUM INT, ID_LANCAMENTO BIGINT, PRIMARY KEY (ORIGEM, NUM));
        MERGE FIN.Lancamento AS d
        USING (SELECT t.*, ISNULL(ml.ID_LOTE, @IdLoteGeral) AS ID_LOTE FROM #T t LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (TIPO, ID_EMPRESA, ID_CENTRO_CUSTO, ID_PESSOA, ID_PLANO_CONTA, ID_HISTORICO_PADRAO, DOCUMENTO, DT_EMISSAO, DT_COMPETENCIA,
                                      HISTORICO, OBSERVACAO, VALOR_TOTAL, ORIGEM, ID_LOTE, INTEGRACAO, CODIGO_ACCESS, ORIGEM_ACCESS, USUARIO_CRIACAO)
             VALUES (s.TIPO, s.ID_EMPRESA, s.ID_CENTRO, s.ID_PESSOA, s.ID_PLANO, s.ID_HIST, s.DOCUMENTO, s.DT_EMISSAO, DATEFROMPARTS(YEAR(s.DT_EMISSAO), MONTH(s.DT_EMISSAO), 1),
                     s.HISTORICO, s.OBSERVACAO, s.VALOR, 'MIGRACAO', s.ID_LOTE, s.INTEGRACAO, s.NUM, s.ORIGEM, @Usuario)
        OUTPUT s.ORIGEM, s.NUM, inserted.ID_LANCAMENTO INTO #MapLanc (ORIGEM, NUM, ID_LANCAMENTO);

        SET @EtapaAtual = 'Gravação: parcelas';
        INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR, ID_CONTA_PREVISTA, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT m.ID_LANCAMENTO, 1, 1, t.DT_VENC, t.VALOR, t.ID_CONTA_PAG, ISNULL(ml.ID_LOTE, @IdLoteGeral), t.NUM, @Usuario
        FROM #T t
        INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE;

        SET @EtapaAtual = 'Gravação: movimentos das baixas';
        -- um movimento por saída/entrada (no lote, um só pelo total)
        SELECT t.PAG_ORIGEM, t.PAG_NUM, MIN(t.UNIDADE) AS UNIDADE, MIN(t.ID_CONTA_PAG) AS ID_CONTA, MIN(t.DT_PAG) AS DT,
               SUM(CASE WHEN t.TIPO = 'P' THEN -t.VALOR ELSE t.VALOR END) AS VALOR,
               CAST(LEFT(MIN(t.HIST_PAG), 200) AS NVARCHAR(200)) AS HISTORICO, CAST(LEFT(MIN(t.DOC_PAG), 40) AS NVARCHAR(40)) AS DOCUMENTO
        INTO #Mov
        FROM #T t
        WHERE t.GERA_MOV = 1
        GROUP BY t.PAG_ORIGEM, t.PAG_NUM;

        CREATE TABLE #MapMov (PAG_ORIGEM VARCHAR(20), PAG_NUM INT, ID_MOVIMENTO BIGINT, PRIMARY KEY (PAG_ORIGEM, PAG_NUM));
        MERGE BANCO.Movimento AS d
        USING (SELECT v.*, ISNULL(ml.ID_LOTE, @IdLoteGeral) AS ID_LOTE FROM #Mov v LEFT JOIN #MapLote ml ON ml.UNIDADE = v.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
             VALUES (s.ID_CONTA, s.DT, s.VALOR, 'BAIXA', s.HISTORICO, s.DOCUMENTO, s.ID_LOTE, s.PAG_NUM, @Usuario)
        OUTPUT s.PAG_ORIGEM, s.PAG_NUM, inserted.ID_MOVIMENTO INTO #MapMov (PAG_ORIGEM, PAG_NUM, ID_MOVIMENTO);

        SET @EtapaAtual = 'Gravação: baixas';
        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, ID_MOVIMENTO, COMPENSADO, DT_COMPENSACAO, OBSERVACAO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT p.ID_PARCELA, t.DT_PAG, t.ID_CONTA_PAG, CASE WHEN t.COMPENSADO = 0 THEN 'CHEQUE' ELSE 'OUTRA' END, t.VALOR, mm.ID_MOVIMENTO,
               t.COMPENSADO, CASE WHEN t.COMPENSADO = 1 THEN t.DT_PAG END,
               CAST(CASE WHEN t.SOI_PAG = 1 THEN N'Somente integração no Access: sem movimento no banco.' ELSE N'' END AS NVARCHAR(400)),
               ISNULL(ml.ID_LOTE, @IdLoteGeral), t.PAG_NUM, @Usuario
        FROM #T t
        INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        INNER JOIN FIN.Parcela p ON p.ID_LANCAMENTO = m.ID_LANCAMENTO
        LEFT JOIN #MapMov mm ON mm.PAG_ORIGEM = t.PAG_ORIGEM AND mm.PAG_NUM = t.PAG_NUM
        LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE
        WHERE t.PAGO = 1 AND t.ID_CONTA_PAG IS NOT NULL;

        SET @EtapaAtual = 'Gravação: transferências';
        CREATE TABLE #MapTr (ORIGEM VARCHAR(20), NUM INT, ID_TRANSFERENCIA BIGINT, PRIMARY KEY (ORIGEM, NUM));
        MERGE FIN.Transferencia AS d
        USING #TR AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (DT_TRANSFERENCIA, ID_CONTA_ORIGEM, ID_CONTA_DESTINO, VALOR, HISTORICO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
             VALUES (s.DT, s.ID_ORIGEM, s.ID_DESTINO, s.VALOR, s.HISTORICO, @IdLoteGeral, s.NUM, @Usuario)
        OUTPUT s.ORIGEM, s.NUM, inserted.ID_TRANSFERENCIA INTO #MapTr (ORIGEM, NUM, ID_TRANSFERENCIA);

        INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, ID_TRANSFERENCIA, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT x.ID_CONTA, r.DT, x.VALOR, 'TRANSFERENCIA', r.HISTORICO, mt.ID_TRANSFERENCIA, @IdLoteGeral, r.NUM, @Usuario
        FROM #TR r
        INNER JOIN #MapTr mt ON mt.ORIGEM = r.ORIGEM AND mt.NUM = r.NUM
        CROSS APPLY (VALUES (r.ID_ORIGEM, -r.VALOR), (r.ID_DESTINO, r.VALOR)) x (ID_CONTA, VALOR);

        SET @EtapaAtual = 'Gravação: destino das linhas';
        INSERT INTO MIG.Linha_Destino (ORIGEM, NUM, UNIDADE, REGRA, PAPEL, ID_LANCAMENTO, ID_MOVIMENTO, ID_TRANSFERENCIA, ID_CONTA, VALOR)
        SELECT l.ORIGEM, l.NUM, l.UNIDADE, u.REGRA,
               CASE WHEN tt.NUM IS NOT NULL THEN 'TITULO'
                    WHEN pg.PAG_NUM IS NOT NULL THEN 'PAGAMENTO'
                    WHEN tr.NUM IS NOT NULL OR tb.NUM IS NOT NULL THEN 'TRANSFERENCIA'
                    WHEN u.REGRA = 'CASO' THEN 'CASO'
                    ELSE 'CONTRAPARTIDA' END,
               ml.ID_LANCAMENTO,
               COALESCE(mm.ID_MOVIMENTO, mm2.ID_MOVIMENTO),
               COALESCE(mt.ID_TRANSFERENCIA, mt2.ID_TRANSFERENCIA),
               COALESCE(tt.ID_CONTA_PAG, pg.ID_CONTA, tr.ID_BANCO, tb.ID_BANCO),
               l.VALOR
        FROM #L l
        INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
        LEFT JOIN #T tt ON tt.ORIGEM = l.ORIGEM AND tt.NUM = l.NUM
        LEFT JOIN #MapLanc ml ON ml.ORIGEM = l.ORIGEM AND ml.NUM = l.NUM
        LEFT JOIN (SELECT PAG_ORIGEM, PAG_NUM, MIN(ID_CONTA_PAG) AS ID_CONTA FROM #T GROUP BY PAG_ORIGEM, PAG_NUM) pg ON pg.PAG_ORIGEM = l.ORIGEM AND pg.PAG_NUM = l.NUM AND tt.NUM IS NULL
        LEFT JOIN #MapMov mm ON mm.PAG_ORIGEM = l.ORIGEM AND mm.PAG_NUM = l.NUM
        LEFT JOIN #MapMov mm2 ON mm2.PAG_ORIGEM = tt.PAG_ORIGEM AND mm2.PAG_NUM = tt.PAG_NUM AND mm.ID_MOVIMENTO IS NULL
        LEFT JOIN #TR tr ON tr.ORIGEM = l.ORIGEM AND tr.NUM = l.NUM
        LEFT JOIN #TR tb ON tb.BCO_ORIGEM = l.ORIGEM AND tb.BCO_NUM = l.NUM
        LEFT JOIN #MapTr mt ON mt.ORIGEM = l.ORIGEM AND mt.NUM = l.NUM
        LEFT JOIN #MapTr mt2 ON mt2.ORIGEM = tb.ORIGEM AND mt2.NUM = tb.NUM;

        INSERT INTO MIG.DePara_Venda (ID_LANCAMENTO, ORIGEM, NUM, LINK_VENDA, IMOVEL, PARCEIRO, CONTRATO, NUM_DOC)
        SELECT m.ID_LANCAMENTO, t.ORIGEM, t.NUM, ISNULL(t.LINK_VENDA, 0), t.IMOVEL, t.PAR, ISNULL(t.CONTRATO, ''), CAST(LEFT(ISNULL(t.NUM_DOC, N''), 100) AS NVARCHAR(100))
        FROM #T t INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        WHERE t.REGRA = 'VENDA';

        UPDATE SIS.Lote SET QTD_REGISTROS = (SELECT COUNT(*) FROM FIN.Lancamento l WHERE l.ID_LOTE = @IdLoteGeral) WHERE ID_LOTE = @IdLoteGeral;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo;

        SELECT 'GRAVADO' AS GRADE, r.ORDEM, r.ITEM, r.QTD, r.VALOR
        FROM (
            SELECT 1 AS ORDEM, N'Lançamentos a pagar' AS ITEM, COUNT(*) AS QTD, SUM(l.VALOR_TOTAL) AS VALOR FROM FIN.Lancamento l WHERE l.ORIGEM = 'MIGRACAO' AND l.TIPO = 'P'
            UNION ALL SELECT 2, N'Lançamentos a receber', COUNT(*), SUM(l.VALOR_TOTAL) FROM FIN.Lancamento l WHERE l.ORIGEM = 'MIGRACAO' AND l.TIPO = 'R'
            UNION ALL SELECT 3, N'Parcelas em aberto', COUNT(*), SUM(p.SALDO) FROM FIN.Parcela p INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.ORIGEM = 'MIGRACAO' AND p.SALDO > 0
            UNION ALL SELECT 4, N'Baixas', COUNT(*), SUM(b.VALOR_LIQUIDO) FROM FIN.Baixa b INNER JOIN SIS.Lote x ON x.ID_LOTE = b.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 5, N'Movimentos de baixa (banco/caixa)', COUNT(*), SUM(m.VALOR) FROM BANCO.Movimento m INNER JOIN SIS.Lote x ON x.ID_LOTE = m.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO' AND m.TIPO = 'BAIXA'
            UNION ALL SELECT 6, N'Transferências', COUNT(*), SUM(t.VALOR) FROM FIN.Transferencia t INNER JOIN SIS.Lote x ON x.ID_LOTE = t.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 7, N'Lotes do Access', COUNT(*) - 1, NULL FROM SIS.Lote x WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 8, N'Casos para a tela', COUNT(*), SUM(c.VALOR_DEBITO + c.VALOR_CREDITO) FROM MIG.Caso c WHERE c.REGRA_ATUAL = 'CASO'
        ) r ORDER BY r.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Movimento_Conferencia_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Movimento_Conferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Conferência da transformação do movimento (etapa 03c2, parte B),
                Access x sistema novo. Grades:
                  1. RESUMO: linhas do Access por regra e papel (título,
                     pagamento, contrapartida, transferência, caso);
                  2. TITULOS_ANO: títulos do Access x lançamentos gravados, por
                     ano e tipo (valor, pagos, em aberto) - a diferença tem de
                     ser zero;
                  3. CONTAS: por conta, o que o Access tinha nas linhas de banco e
                     caixinha x movimentos gravados (baixas e transferências);
                     a diferença é explicada pelas transferências dos lançamentos
                     soltos e pelas baixas "somente integração";
                  4. EMPRESAS: lançamentos por empresa;
                  5. CASOS: documentos para a tela de correção.
                Só leitura.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
    v1.1 (18/11/2026) - Casos: só os que ainda não se encaixam, mais a grade
                        CASOS_SITUACAO (pendentes, corrigidos, ignorados, arquivo morto).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Movimento_Conferencia_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    /* 1. Resumo */
    SELECT 'RESUMO' AS GRADE, d.REGRA, d.PAPEL, COUNT(DISTINCT d.UNIDADE) AS DOCUMENTOS, COUNT(*) AS LINHAS, SUM(d.VALOR) AS VALOR
    FROM MIG.Linha_Destino d
    GROUP BY d.REGRA, d.PAPEL
    UNION ALL
    SELECT 'RESUMO', 'IGNORADA', 'CORRECAO', COUNT(DISTINCT m.UNIDADE), COUNT(*), SUM(m.VALOR_DEBITO + m.VALOR_CREDITO)
    FROM MIG.Movimento m
    WHERE m.DESTINO = 'SISTEMA' AND NOT EXISTS (SELECT 1 FROM MIG.Linha_Destino d WHERE d.ORIGEM = m.ORIGEM AND d.NUM = m.NUM)
    ORDER BY 2, 3;

    /* 2. Títulos por ano: Access x sistema */
    SELECT 'TITULOS_ANO' AS GRADE, YEAR(l.DT_EMISSAO) AS ANO, l.TIPO,
           COUNT(*) AS LANCAMENTOS,
           SUM(m.VALOR_DEBITO + m.VALOR_CREDITO) AS VALOR_ACCESS,
           SUM(l.VALOR_TOTAL) AS VALOR_SISTEMA,
           SUM(l.VALOR_TOTAL) - SUM(m.VALOR_DEBITO + m.VALOR_CREDITO) AS DIFERENCA,
           SUM(p.VALOR_BAIXADO) AS PAGO, SUM(p.SALDO) AS EM_ABERTO
    FROM MIG.Linha_Destino d
    INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
    INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = d.ID_LANCAMENTO
    INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_LANCAMENTO = l.ID_LANCAMENTO
    WHERE d.PAPEL = 'TITULO'
    GROUP BY YEAR(l.DT_EMISSAO), l.TIPO
    ORDER BY 2, 3;

    /* 3. Contas */
    ;WITH Acc AS
    (
        SELECT d.ID_CONTA,
               SUM(CASE WHEN m.CONTA NOT IN (1, 2, 3) THEN m.VALOR_CREDITO - m.VALOR_DEBITO ELSE 0 END) AS ACCESS_BANCO_CAIXINHA,
               SUM(CASE WHEN m.CONTA NOT IN (1, 2, 3) AND m.SOMENTE_INTEGRACAO = 1 THEN m.VALOR_CREDITO - m.VALOR_DEBITO ELSE 0 END) AS ACCESS_SOMENTE_INTEGRACAO
        FROM MIG.Linha_Destino d
        INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
        WHERE d.PAPEL IN ('PAGAMENTO', 'TITULO') AND d.ID_CONTA IS NOT NULL AND m.CONTA NOT IN (1, 2, 3)
          AND (d.PAPEL = 'PAGAMENTO' OR d.REGRA = 'AVULSO')
        GROUP BY d.ID_CONTA
    ),
    Novo AS
    (
        SELECT mv.ID_CONTA,
               SUM(CASE WHEN mv.TIPO = 'BAIXA' THEN mv.VALOR ELSE 0 END) AS NOVO_BAIXAS,
               SUM(CASE WHEN mv.TIPO = 'TRANSFERENCIA' THEN mv.VALOR ELSE 0 END) AS NOVO_TRANSFERENCIAS
        FROM BANCO.Movimento mv WITH (NOLOCK)
        INNER JOIN SIS.Lote x WITH (NOLOCK) ON x.ID_LOTE = mv.ID_LOTE
        WHERE x.ORIGEM = 'MIGRACAO'
        GROUP BY mv.ID_CONTA
    )
    SELECT 'CONTAS' AS GRADE, e.NOME_FANTASIA AS EMPRESA, k.DESCRICAO AS CONTA, k.TIPO,
           ISNULL(a.ACCESS_BANCO_CAIXINHA, 0) AS ACCESS_BANCO_CAIXINHA,
           ISNULL(a.ACCESS_SOMENTE_INTEGRACAO, 0) AS ACCESS_SOMENTE_INTEGRACAO,
           ISNULL(n.NOVO_BAIXAS, 0) AS NOVO_BAIXAS,
           ISNULL(n.NOVO_TRANSFERENCIAS, 0) AS NOVO_TRANSFERENCIAS,
           ISNULL(n.NOVO_BAIXAS, 0) - (ISNULL(a.ACCESS_BANCO_CAIXINHA, 0) - ISNULL(a.ACCESS_SOMENTE_INTEGRACAO, 0)) AS DIFERENCA_BAIXAS
    FROM BANCO.Conta k WITH (NOLOCK)
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = k.ID_EMPRESA
    LEFT JOIN Acc a ON a.ID_CONTA = k.ID_CONTA
    LEFT JOIN Novo n ON n.ID_CONTA = k.ID_CONTA
    WHERE a.ID_CONTA IS NOT NULL OR n.ID_CONTA IS NOT NULL
    ORDER BY e.NOME_FANTASIA, k.DESCRICAO;

    /* 4. Empresas */
    SELECT 'EMPRESAS' AS GRADE, e.NOME_FANTASIA AS EMPRESA, l.TIPO, COUNT(*) AS LANCAMENTOS, SUM(l.VALOR_TOTAL) AS VALOR,
           SUM(p.VALOR_BAIXADO) AS PAGO, SUM(p.SALDO) AS EM_ABERTO,
           SUM(CASE WHEN l.ID_PESSOA IS NULL THEN 1 ELSE 0 END) AS SEM_PESSOA,
           SUM(CASE WHEN l.ID_PLANO_CONTA IS NULL THEN 1 ELSE 0 END) AS SEM_PLANO
    FROM FIN.Lancamento l WITH (NOLOCK)
    INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_LANCAMENTO = l.ID_LANCAMENTO
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
    WHERE l.ORIGEM = 'MIGRACAO'
    GROUP BY e.NOME_FANTASIA, l.TIPO
    ORDER BY e.NOME_FANTASIA, l.TIPO;

    /* 5. Casos */
    SELECT 'CASOS' AS GRADE, c.MOTIVO, COUNT(*) AS DOCUMENTOS, SUM(c.LINHAS) AS LINHAS, SUM(c.VALOR_DEBITO) AS DEBITOS, SUM(c.VALOR_CREDITO) AS CREDITOS,
           MIN(c.DT_DOCUMENTO) AS DE, MAX(c.DT_DOCUMENTO) AS ATE
    FROM MIG.Caso c
    WHERE c.REGRA_ATUAL = 'CASO'
    GROUP BY c.MOTIVO
    ORDER BY COUNT(*) DESC;

    SELECT 'CASOS_SITUACAO' AS GRADE, c.REGRA_ATUAL, COUNT(*) AS DOCUMENTOS, SUM(c.VALOR_DEBITO + c.VALOR_CREDITO) AS VALOR
    FROM MIG.Caso c
    GROUP BY c.REGRA_ATUAL
    ORDER BY c.REGRA_ATUAL;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Lista da tela "Casos da migração" (MIG_CASOS): um documento do
                Access por linha (MIG.Caso: os que não se encaixam e os que já
                têm correção), com obra, histórico, motivo, valores e
                situação: PENDENTE, EM_CORRECAO (corrigido mas ainda não se
                encaixa), RESOLVIDO (corrigido e já se encaixa), IGNORADO,
                ARQUIVO_MORTO. Filtros e totais ficam na tela (são poucos
                documentos). Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Listar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.UNIDADE,
               CASE LEFT(c.UNIDADE, 1) WHEN 'L' THEN N'Lote ' WHEN 'V' THEN N'Venda ' ELSE N'Documento ' END
                 + SUBSTRING(c.UNIDADE, CHARINDEX(':', c.UNIDADE) + 1, 40) AS DOCUMENTO,
               c.DT_DOCUMENTO, YEAR(c.DT_DOCUMENTO) AS ANO,
               ISNULL(nv.NOME, N'') AS EMPRESA,
               ISNULL(NULLIF(pl.COMPLEMENTO, N''), ISNULL(h.DESCRICAO, N'')) AS HISTORICO,
               CASE WHEN c.REGRA_ATUAL = 'CASO' THEN c.MOTIVO ELSE c.MOTIVO_ORIGINAL END AS MOTIVO,
               c.MOTIVO_ORIGINAL, c.DETALHE, c.REGRA_ATUAL, c.LINHAS,
               c.VALOR_DEBITO, c.VALOR_CREDITO, c.VALOR_DEBITO - c.VALOR_CREDITO AS DIFERENCA,
               CASE WHEN c.REGRA_ATUAL = 'IGNORAR' THEN 'IGNORADO'
                    WHEN c.REGRA_ATUAL = 'ARQUIVO_MORTO' THEN 'ARQUIVO_MORTO'
                    WHEN c.REGRA_ATUAL = 'CASO' AND k.QTD > 0 THEN 'EM_CORRECAO'
                    WHEN c.REGRA_ATUAL = 'CASO' THEN 'PENDENTE'
                    ELSE 'RESOLVIDO' END AS SITUACAO,
               ISNULL(k.QTD, 0) AS LINHAS_CORRIGIDAS,
               COALESCE(cc.USUARIO_ALTERACAO, cc.USUARIO_CRIACAO, k.USUARIO, N'') AS CORRIGIDO_POR,
               COALESCE(cc.DT_ALTERACAO, cc.DT_CRIACAO, k.DT) AS CORRIGIDO_EM
        FROM MIG.Caso c
        OUTER APPLY (SELECT TOP (1) COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS EV, m.COMPLEMENTO, m.HISTORICO
                     FROM MIG.Movimento m
                     LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
                     WHERE m.UNIDADE = c.UNIDADE AND m.DESTINO = 'SISTEMA'
                     ORDER BY CASE WHEN m.COMPLEMENTO <> N'' THEN 0 ELSE 1 END, m.NUM) pl
        OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(v.NomeVinculada)) AS NOME FROM MIG.Access_EmpVinculada v WHERE TRY_CONVERT(INT, v.CodigoVinculada) = pl.EV) nv
        OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS DESCRICAO FROM MIG.Access_Historico x WHERE TRY_CONVERT(INT, x.CodHistorico) = pl.HISTORICO) h
        OUTER APPLY (SELECT COUNT(*) AS QTD, MAX(COALESCE(o.USUARIO_ALTERACAO, o.USUARIO_CRIACAO)) AS USUARIO, MAX(COALESCE(o.DT_ALTERACAO, o.DT_CRIACAO)) AS DT
                     FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = c.UNIDADE) k
        LEFT JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = c.UNIDADE
        ORDER BY c.DT_DOCUMENTO, c.UNIDADE;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar os casos da migração. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Um caso da tela "Casos da migração": cabeçalho (motivo, situação,
                decisão gravada) e as linhas do Access (LINHAS_JSON), cada uma
                com o valor original e o valor em uso (original + correção da
                tela) de obra, pessoa, conta, plano, datas, valores e
                confirmado, já com os nomes do Access. Data corrigida para
                01/01/1900 = "sem data". Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Obter @IdUsuario = 1, @Unidade = 'L:123';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Obter]
    @IdUsuario  INT,
    @Unidade    VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = @Unidade)
            THROW 50001, N'Caso não encontrado. Atualize a lista.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.UNIDADE, c.REGRA_ATUAL, c.MOTIVO, c.MOTIVO_ORIGINAL, c.DETALHE, c.PADRAO, c.DT_DOCUMENTO, c.DT_CALCULO,
               ISNULL(cc.ACAO, '') AS ACAO, ISNULL(cc.MOTIVO, N'') AS ACAO_MOTIVO,
               COALESCE(cc.USUARIO_ALTERACAO, cc.USUARIO_CRIACAO, N'') AS ACAO_USUARIO, COALESCE(cc.DT_ALTERACAO, cc.DT_CRIACAO) AS ACAO_DT,
               ISNULL((SELECT TOP (1) o.MOTIVO FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = c.UNIDADE AND o.MOTIVO <> N''
                       ORDER BY COALESCE(o.DT_ALTERACAO, o.DT_CRIACAO) DESC), N'') AS CORRECAO_MOTIVO,
               ISNULL((
                   SELECT m.ORIGEM AS origem, m.NUM AS num, m.TIPO_CONTA AS tipoConta, m.LADO AS lado,
                          m.NUM_DOC AS numDoc, m.COMPLEMENTO AS complemento, ISNULL(h.DESCRICAO, N'') AS historico,
                          m.EMP_VINCULADA AS empOrig, COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS emp, ISNULL(nv.NOME, N'') AS empNome,
                          m.PARCEIRO AS parceiroOrig, COALESCE(o.PARCEIRO, m.PARCEIRO) AS parceiro, ISNULL(np.NOME, N'') AS parceiroNome,
                          m.CONTA AS contaOrig, COALESCE(o.CONTA, m.CONTA) AS conta, ISNULL(nc.NOME, N'') AS contaNome,
                          m.PLANO3 AS planoOrig, COALESCE(o.PLANO3, m.PLANO3) AS plano, ISNULL(npl.NOME, N'') AS planoNome,
                          m.DT_MOVTO AS dtMovtoOrig, NULLIF(COALESCE(o.DT_MOVTO, m.DT_MOVTO), '1900-01-01') AS dtMovto,
                          m.DT_VENCTO AS dtVenctoOrig, NULLIF(COALESCE(o.DT_VENCTO, m.DT_VENCTO), '1900-01-01') AS dtVencto,
                          m.DT_PAGTO AS dtPagtoOrig, NULLIF(COALESCE(o.DT_PAGTO, m.DT_PAGTO), '1900-01-01') AS dtPagto,
                          m.VALOR_DEBITO AS debitoOrig, COALESCE(o.VALOR_DEBITO, m.VALOR_DEBITO) AS debito,
                          m.VALOR_CREDITO AS creditoOrig, COALESCE(o.VALOR_CREDITO, m.VALOR_CREDITO) AS credito,
                          m.CONFIRMADO AS confirmadoOrig, COALESCE(o.CONFIRMADO, m.CONFIRMADO) AS confirmado,
                          m.EFETUADO AS efetuado, m.SOMENTE_INTEGRACAO AS somenteIntegracao,
                          ISNULL(o.IGNORAR_LINHA, CAST(0 AS BIT)) AS ignorar,
                          CAST(CASE WHEN o.ID_CASO_CORRECAO_LINHA IS NULL THEN 0 ELSE 1 END AS BIT) AS corrigida
                   FROM MIG.Movimento m
                   LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS DESCRICAO FROM MIG.Access_Historico x WHERE TRY_CONVERT(INT, x.CodHistorico) = m.HISTORICO) h
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(v.NomeVinculada)) AS NOME FROM MIG.Access_EmpVinculada v WHERE TRY_CONVERT(INT, v.CodigoVinculada) = COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA)) nv
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.NomeParceiro)) AS NOME FROM MIG.Access_Parceiros x WHERE TRY_CONVERT(INT, x.CodigoParceiro) = COALESCE(o.PARCEIRO, m.PARCEIRO)) np
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS NOME FROM MIG.Access_Contas_Financeiras x WHERE TRY_CONVERT(INT, x.CodigoConta) = COALESCE(o.CONTA, m.CONTA)) nc
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.DescricaoPlano3)) AS NOME FROM MIG.Access_Plano3 x WHERE TRY_CONVERT(INT, x.Plano3) = COALESCE(o.PLANO3, m.PLANO3)) npl
                   WHERE m.UNIDADE = c.UNIDADE AND m.DESTINO = 'SISTEMA'
                   ORDER BY m.DT_MOVTO, m.NUM
                   FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS LINHAS_JSON
        FROM MIG.Caso c
        LEFT JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = c.UNIDADE
        WHERE c.UNIDADE = @Unidade;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar o caso. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Opcoes.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Opcoes]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Listas de escolha da tela "Casos da migração", com os códigos e
                nomes do Access: obras (só as que têm de-para), contas, planos
                (só os que têm de-para) e pessoas. Uma linha com quatro colunas
                JSON. Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Opcoes @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Opcoes]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Opcoes]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, v.CodigoVinculada) AS c, MIN(LTRIM(RTRIM(v.NomeVinculada))) AS n
                                          FROM MIG.Access_EmpVinculada v
                                          WHERE EXISTS (SELECT 1 FROM MIG.DePara_Centro d WHERE d.CODIGO_VINCULADA = TRY_CONVERT(INT, v.CodigoVinculada))
                                          GROUP BY TRY_CONVERT(INT, v.CodigoVinculada)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS OBRAS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, k.CodigoConta) AS c, MIN(LTRIM(RTRIM(k.Descricao))) AS n
                                          FROM MIG.Access_Contas_Financeiras k
                                          WHERE TRY_CONVERT(INT, k.CodigoConta) IS NOT NULL
                                          GROUP BY TRY_CONVERT(INT, k.CodigoConta)) x
                    ORDER BY x.c FOR JSON PATH), N'[]') AS CONTAS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, p.Plano3) AS c, MIN(LTRIM(RTRIM(p.DescricaoPlano3))) AS n
                                          FROM MIG.Access_Plano3 p
                                          WHERE EXISTS (SELECT 1 FROM MIG.DePara_Plano d WHERE d.PLANO3_ACCESS = TRY_CONVERT(INT, p.Plano3))
                                          GROUP BY TRY_CONVERT(INT, p.Plano3)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS PLANOS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, p.CodigoParceiro) AS c, MIN(LTRIM(RTRIM(p.NomeParceiro))) AS n
                                          FROM MIG.Access_Parceiros p
                                          WHERE TRY_CONVERT(INT, p.CodigoParceiro) > 1
                                          GROUP BY TRY_CONVERT(INT, p.CodigoParceiro)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS PESSOAS_JSON;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar as listas da tela. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Gravar.sql
-- =============================================================================
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
            -- só o que mudou em relação ao Access precisa existir no de-para (o Access pode ter código sem de-para)
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE (j.EMP IS NULL AND m.EMP_VINCULADA IS NOT NULL)
                                            OR (j.EMP <> ISNULL(m.EMP_VINCULADA, -1) AND NOT EXISTS (SELECT 1 FROM MIG.DePara_Centro d WHERE d.CODIGO_VINCULADA = j.EMP)))
                SET @Recusa = N'Escolha uma obra válida em todas as linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE (j.CONTA IS NULL AND m.CONTA IS NOT NULL)
                                            OR (j.CONTA <> ISNULL(m.CONTA, -1) AND NOT EXISTS (SELECT 1 FROM MIG.Access_Contas_Financeiras k WHERE TRY_CONVERT(INT, k.CodigoConta) = j.CONTA)))
                SET @Recusa = N'Escolha uma conta válida em todas as linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE (j.PLANO IS NULL AND m.PLANO3 IS NOT NULL)
                                            OR (j.PLANO <> ISNULL(m.PLANO3, -1) AND NOT EXISTS (SELECT 1 FROM MIG.DePara_Plano d WHERE d.PLANO3_ACCESS = j.PLANO)))
                SET @Recusa = N'Escolha um plano de contas válido nas linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE j.PARCEIRO > 1 AND j.PARCEIRO <> ISNULL(m.PARCEIRO, 0) AND NOT EXISTS (SELECT 1 FROM MIG.Access_Parceiros p WHERE TRY_CONVERT(INT, p.CodigoParceiro) = j.PARCEIRO))
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

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Conferir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Botão "Conferir" da tela "Casos da migração" (e o passo final
                de cada gravação): classifica de novo só aquele documento, com
                as correções gravadas, pelas mesmas regras da migração
                (MIG_Movimento_Transformar @Unidade). Devolve UNIDADE, REGRA,
                MOTIVO e DETALHE. Nada é gravado no financeiro.
                Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Conferir @IdUsuario = 1, @Unidade = 'L:123';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Conferir]
    @IdUsuario  INT,
    @Unidade    VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Conferir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = @Unidade)
            THROW 50001, N'Caso não encontrado. Atualize a lista.', 1;

        SET @EtapaAtual = 'Classificação';
        EXEC MIG.MIG_Movimento_Transformar @Executar = 0, @Unidade = @Unidade;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível conferir o caso. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/Carga_MIG_Tela_Casos.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga da tela "Casos da migração" (menu e permissões)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Menu Sistema > Migração > Casos da migração (MIG_CASOS), com as
                ações VER e ALTERAR. Para os dois administradores (geral e da
                CMJ); outro perfil só se receber a permissão. Só existe onde a
                migração roda (LOCAL e o servidor da CMJ até a virada); na
                virada, o item é desabilitado. Só insere o que falta (regra 39).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'SIS_MIGRACAO', N'Migração', 'MENU', '', 40, 0, 1, ''
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_MIGRACAO');
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'MIG_CASOS', N'Casos da migração', 'TELA', 'sis/migracao-casos.html', 10, 0, 1,
       'MIG.Caso_Correcao,MIG.Caso_Correcao_Linha'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_MIGRACAO'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'MIG_CASOS');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('ALTERAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'MIG_CASOS'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

PRINT N'Pacote 03c2b concluído sem erro.';
GO

SET NOEXEC OFF;
GO
