/*******************************************************************************
  Pacote      : 04b2 - historico padrao das fichas (SIS_Historico_Listar) e TRANSACAO na auditoria; banco 2.1
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 23/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04b já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/04b2_Homologacao_Historico.sql e 04b_Homologacao_Lixeira_Desfazer.sql.
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
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Registro_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Auditoria_Registro_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Aba "Histórico" de toda tela de manutenção (seção 3.7): quem
                incluiu, alterou ou excluiu aquele registro, quando, de onde e
                o valor antes e depois. Mais recente primeiro.
                @Item   : código da tela que está pedindo (ex.: SIS_USUARIO)
                @Tabela : 'SCHEMA.Tabela' do registro (precisa estar em
                          TABELAS_DA_TELA da tela)
                Permissão: VER na tela informada.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (23/11/2026) - Etapa 04b2: devolve TRANSACAO (agrupa o que foi gravado
                        junto; a aba Histórico desfaz por operação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Auditoria_Registro_Listar @IdUsuario = 2, @Item = 'SIS_PARAMETRO', @Tabela = N'SIS.Parametro', @IdRegistro = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Auditoria_Registro_Listar]
    @IdUsuario   INT,
    @Item        VARCHAR(40),
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Auditoria_Registro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver este histórico.', 1;

        IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            THROW 50001, N'Esta tela não mostra histórico desse tipo de registro.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT a.ID_AUDITORIA,
               a.DT_OPERACAO,
               a.OPERACAO,
               CAST(CASE a.OPERACAO WHEN 'I' THEN N'Inclusão' WHEN 'A' THEN N'Alteração' ELSE N'Exclusão' END AS NVARCHAR(20)) AS OPERACAO_NOME,
               a.CAMPO,
               ISNULL(CAST(a.VALOR_ANTES  AS NVARCHAR(4000)), N'') AS VALOR_ANTES,
               ISNULL(CAST(a.VALOR_DEPOIS AS NVARCHAR(4000)), N'') AS VALOR_DEPOIS,
               a.USUARIO,
               a.ESTACAO,
               a.ORIGEM,
               a.ID_LOTE,
               a.TRANSACAO
        FROM SIS.Auditoria a WITH (NOLOCK)
        WHERE a.TABELA = @Tabela
          AND a.ID_REGISTRO = @IdRegistro
        ORDER BY a.ID_AUDITORIA DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o histórico. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Auditoria_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Auditoria_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela geral de consulta da auditoria (seção 3.7), com filtros:
                período (sem datas: últimos 7 dias), usuário (parte do login),
                tabela (parte do nome), registro, operação (I/A/E) e lote.
                @MaxLinhas: padrão 1000, máximo 10000.
                Permissão: SIS_AUDITORIA / VER.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (23/11/2026) - Etapa 04b2: devolve TRANSACAO e TELA_NOME (tela Auditoria
                        agrupa por operação e mostra o nome da tela).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Auditoria_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Auditoria_Listar @IdUsuario = 2, @Tabela = N'Parametro', @Operacao = 'A';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Auditoria_Listar]
    @IdUsuario   INT,
    @DtInicio    DATE          = NULL,
    @DtFim       DATE          = NULL,
    @Usuario     NVARCHAR(100) = NULL,
    @Tabela      NVARCHAR(256) = NULL,
    @IdRegistro  BIGINT        = NULL,
    @Operacao    CHAR(1)       = NULL,
    @IdLote      BIGINT        = NULL,
    @MaxLinhas   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Auditoria_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_AUDITORIA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para consultar a auditoria.', 1;

        SET @DtFim     = ISNULL(@DtFim, CAST(SYSDATETIME() AS DATE));
        SET @DtInicio  = ISNULL(@DtInicio, DATEADD(DAY, -7, @DtFim));
        SET @Usuario   = NULLIF(LTRIM(RTRIM(@Usuario)), N'');
        SET @Tabela    = NULLIF(LTRIM(RTRIM(@Tabela)), N'');
        SET @Operacao  = NULLIF(UPPER(LTRIM(RTRIM(@Operacao))), '');
        SET @MaxLinhas = ISNULL(@MaxLinhas, 1000);
        IF @MaxLinhas < 1 SET @MaxLinhas = 1000;
        IF @MaxLinhas > 10000 SET @MaxLinhas = 10000;

        IF @DtInicio > @DtFim
            THROW 50001, N'A data inicial não pode ser maior que a data final.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               a.ID_AUDITORIA,
               a.DT_OPERACAO,
               a.TABELA,
               a.ID_REGISTRO,
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
               ISNULL(i.NOME, a.TABELA) AS TELA_NOME
        FROM SIS.Auditoria a WITH (NOLOCK)
        LEFT JOIN SIS.Item i WITH (NOLOCK) ON i.CODIGO = SIS.fn_SIS_Item_Da_Tabela(a.TABELA)
        WHERE a.DT_OPERACAO >= @DtInicio
          AND a.DT_OPERACAO <  DATEADD(DAY, 1, @DtFim)
          AND (@Usuario    IS NULL OR a.USUARIO LIKE N'%' + @Usuario + N'%')
          AND (@Tabela     IS NULL OR a.TABELA  LIKE N'%' + @Tabela + N'%')
          AND (@IdRegistro IS NULL OR a.ID_REGISTRO = @IdRegistro)
          AND (@Operacao   IS NULL OR a.OPERACAO = @Operacao)
          AND (@IdLote     IS NULL OR a.ID_LOTE = @IdLote)
        ORDER BY a.ID_AUDITORIA DESC
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível consultar a auditoria. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Historico_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Versao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : registro da versão do banco em [SIS].[Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : ÚLTIMA instrução do MASTER (depois da finalização): grava a
                versão que acabou de ser instalada. É a ÚNICA fonte da versão do
                banco: o montar_master.py lê o número daqui para o cabeçalho
                do MASTER, e a API exige o mesmo número
                (Infra/VersaoBanco.cs, VersaoExigida).
                REGRA: toda mudança que vai para o MASTER sobe este número e o
                da API juntos.
                Em banco de desenvolvimento (_LOCAL) grava com ORIGEM
                PACOTE_LOCAL. Rodar de novo grava outra linha (histórico).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d): versão 1.1 do banco.
    Versões do banco: 1.1 (20/11/2026) limite de login por computador e versão;
                      1.2 (20/11/2026) primeiro acesso da instalação;
                      1.3 (20/11/2026) SIS_Registro_Existe (anexos com o login da API);
                      1.4 (20/11/2026) fn_SIS_Usuario_Id (licença gravada pela API);
                      1.5 (20/11/2026) backup do servidor (SIS.Backup, avisos de atraso).
                      1.6 (20/11/2026) restauração de backup pela tela (SIS.Backup_Restauracao).
                      1.7 (22/11/2026) ajuda exclusiva do administrador geral (SIS_Ajuda_Geral_Obter, tela SIS_AJUDA_GERAL).
                      1.8 (22/11/2026) atualização em um clique (SIS.Atualizacao, SIS_Atualizacao_Registrar).
                      1.9 (22/11/2026) telas de Usuários e Perfis (senha provisória que vence, perfis Financeiro e Consulta).
                      2.0 (22/11/2026) histórico padrão: desfazer pela auditoria e lixeira (P20, etapa 04b).
                      2.1 (23/11/2026) telas da lixeira, do histórico e da auditoria (P20, etapa 04b2).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '2.1';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO

PRINT N'Pacote 04b2 concluído sem erro.';
GO

SET NOEXEC OFF;
GO
