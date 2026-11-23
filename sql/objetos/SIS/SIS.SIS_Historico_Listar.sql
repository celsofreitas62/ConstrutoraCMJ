/*******************************************************************************
  Objeto      : [SIS].[SIS_Historico_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Aba Histórico padrão de todas as fichas (P20, etapa 04b2): o
                histórico do registro e das filhas que "vão junto"
                (SIS.Tabela_Config.TABELAS_FILHAS), inclusive as já apagadas
                (achadas pela foto da auditoria), mais recente primeiro.
                TRANSACAO agrupa o que foi gravado junto (uma operação).
                PRINCIPAL = 1 nas linhas do próprio registro.
                DESCRICAO: nas permissões (tabelas com ID_ITEM_ACAO), o nome
                da tela e da ação; nas outras, vazia.
                Permissão: VER na tela (@Item), que precisa mostrar @Tabela.
                Padrão "Listar": THROW 50001 com mensagem amigável.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04b2).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Historico_Listar @IdUsuario = 2, @Item = 'CAD_PESSOA', @Tabela = N'CAD.Pessoa', @IdRegistro = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Historico_Listar]
    @IdUsuario   INT,
    @Item        VARCHAR(40),
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @MaxLinhas   INT = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Historico_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Sql NVARCHAR(MAX) = N'';

    DROP TABLE IF EXISTS #Reg;

    BEGIN TRY
        SET @Tabela    = LTRIM(RTRIM(ISNULL(@Tabela, N'')));
        SET @MaxLinhas = ISNULL(@MaxLinhas, 1000);
        IF @MaxLinhas < 1 OR @MaxLinhas > 10000 SET @MaxLinhas = 1000;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver esta tela.', 1;
        IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            THROW 50001, N'Esta tela não mostra histórico desse tipo de registro.', 1;
        IF @IdRegistro IS NULL
            THROW 50001, N'Escolha o registro.', 1;

        SET @EtapaAtual = 'Registros';
        CREATE TABLE #Reg (TABELA NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL, ID_REGISTRO BIGINT NOT NULL, PRIMARY KEY (TABELA, ID_REGISTRO));
        INSERT INTO #Reg (TABELA, ID_REGISTRO) VALUES (@Tabela, @IdRegistro);

        -- filhas que vão junto: as que existem hoje e as que já existiram (foto da auditoria)
        SELECT @Sql = @Sql
                    + N'INSERT INTO #Reg (TABELA, ID_REGISTRO) SELECT DISTINCT N''' + REPLACE(f.TABELA, N'''', N'''''') + N''', CAST(f.'
                    + QUOTENAME(SIS.fn_SIS_Tabela_PK(f.TABELA)) + N' AS BIGINT) FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(f.TABELA, N'U'))) + N'.'
                    + QUOTENAME(OBJECT_NAME(OBJECT_ID(f.TABELA, N'U'))) + N' f WITH (NOLOCK) WHERE f.' + QUOTENAME(f.COLUNA) + N' = @Id'
                    + N' AND NOT EXISTS (SELECT 1 FROM #Reg r WHERE r.TABELA = N''' + REPLACE(f.TABELA, N'''', N'''''') + N''' AND r.ID_REGISTRO = f.'
                    + QUOTENAME(SIS.fn_SIS_Tabela_PK(f.TABELA)) + N');' + NCHAR(13) + NCHAR(10)
                    + N'INSERT INTO #Reg (TABELA, ID_REGISTRO) SELECT DISTINCT a.TABELA, a.ID_REGISTRO FROM SIS.Auditoria a WITH (NOLOCK)'
                    + N' WHERE a.TABELA = N''' + REPLACE(f.TABELA, N'''', N'''''') + N''' AND a.OPERACAO IN (''I'', ''E'')'
                    + N' AND JSON_VALUE(COALESCE(a.VALOR_DEPOIS, a.VALOR_ANTES), N''$.' + REPLACE(f.COLUNA, N'''', N'''''') + N''') = CAST(@Id AS NVARCHAR(30))'
                    + N' AND NOT EXISTS (SELECT 1 FROM #Reg r WHERE r.TABELA = a.TABELA AND r.ID_REGISTRO = a.ID_REGISTRO);' + NCHAR(13) + NCHAR(10)
        FROM (SELECT LEFT(x.v, LEN(x.v) - CHARINDEX(N'.', REVERSE(x.v))) AS TABELA, RIGHT(x.v, CHARINDEX(N'.', REVERSE(x.v)) - 1) AS COLUNA
              FROM SIS.Tabela_Config c WITH (NOLOCK)
              CROSS APPLY (SELECT LTRIM(RTRIM(s.value)) AS v FROM STRING_SPLIT(c.TABELAS_FILHAS, N',') s) x
              WHERE c.TABELA = @Tabela AND c.ATIVO = 1 AND x.v LIKE N'%_._%._%') f
        WHERE OBJECT_ID(f.TABELA, N'U') IS NOT NULL AND COL_LENGTH(f.TABELA, f.COLUNA) IS NOT NULL AND SIS.fn_SIS_Tabela_PK(f.TABELA) <> N'';
        IF @Sql <> N'' EXEC sys.sp_executesql @Sql, N'@Id BIGINT', @Id = @IdRegistro;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               a.ID_AUDITORIA,
               a.DT_OPERACAO,
               CAST(a.TABELA AS NVARCHAR(256)) AS TABELA,
               a.ID_REGISTRO,
               CAST(CASE WHEN a.TABELA = @Tabela AND a.ID_REGISTRO = @IdRegistro THEN 1 ELSE 0 END AS BIT) AS PRINCIPAL,
               a.OPERACAO,
               CAST(CASE a.OPERACAO WHEN 'I' THEN N'Inclusão' WHEN 'A' THEN N'Alteração' ELSE N'Exclusão' END AS NVARCHAR(20)) AS OPERACAO_NOME,
               a.CAMPO,
               ISNULL(CAST(a.VALOR_ANTES  AS NVARCHAR(4000)), N'') AS VALOR_ANTES,
               ISNULL(CAST(a.VALOR_DEPOIS AS NVARCHAR(4000)), N'') AS VALOR_DEPOIS,
               a.USUARIO,
               a.ESTACAO,
               a.ORIGEM,
               a.ID_LOTE,
               a.TRANSACAO,
               CAST(ISNULL(it.NOME + N' › ' + ac.NOME, N'') AS NVARCHAR(200)) AS DESCRICAO
        FROM SIS.Auditoria a WITH (NOLOCK)
        INNER JOIN #Reg r ON r.TABELA = a.TABELA AND r.ID_REGISTRO = a.ID_REGISTRO
        OUTER APPLY (SELECT TRY_CONVERT(INT, CASE WHEN ISNULL(a.CAMPO, N'') = N'' THEN JSON_VALUE(COALESCE(a.VALOR_DEPOIS, a.VALOR_ANTES), N'$.ID_ITEM_ACAO') END) AS ID_ITEM_ACAO) j
        LEFT JOIN SIS.Item_Acao ia WITH (NOLOCK) ON ia.ID_ITEM_ACAO = j.ID_ITEM_ACAO
        LEFT JOIN SIS.Item      it WITH (NOLOCK) ON it.ID_ITEM = ia.ID_ITEM
        LEFT JOIN SIS.Acao      ac WITH (NOLOCK) ON ac.ID_ACAO = ia.ID_ACAO
        ORDER BY a.ID_AUDITORIA DESC;

        DROP TABLE IF EXISTS #Reg;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1 DROP TABLE IF EXISTS #Reg;
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar o histórico. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
