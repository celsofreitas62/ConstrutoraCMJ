/*******************************************************************************
  Pacote      : 04f2a - lista de contas a pagar e a receber: contadores, situacoes hoje e a vencer, periodo por emissao ou competencia, filtros salvos; banco continua 2.4 ate a 04f2d
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 25/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04f já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/FIN/04f2a_Homologacao_Lista.sql e 04f.
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
-- Arquivo: sql/objetos/SIS/SIS.Filtro_Salvo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Filtro_Salvo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Filtros salvos pelo usuário nas listas (ex.: "Vencidos da CMJ"
                em Contas a receber). Um nome por usuário e tela; FILTRO é o
                JSON montado pela tela (a tela sabe ler o próprio filtro).
                PADRAO = 1: a lista já abre com este filtro (no máximo um por
                usuário e tela). Preferência de uso, não dado do negócio: só
                o próprio usuário grava e apaga (SIS_Filtro_Salvo_Gravar /
                _Excluir), sem lixeira e sem auditoria.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Filtro_Salvo]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Filtro_Salvo]
    (
        ID_FILTRO_SALVO    INT            IDENTITY(1,1) NOT NULL,
        ID_USUARIO         INT            NOT NULL,
        ITEM               VARCHAR(40)    NOT NULL,
        NOME               NVARCHAR(60)   NOT NULL,
        FILTRO             NVARCHAR(2000) NOT NULL,
        PADRAO             BIT            NOT NULL CONSTRAINT DF_Filtro_Salvo_PADRAO DEFAULT (0),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Filtro_Salvo_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Filtro_Salvo_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Filtro_Salvo         PRIMARY KEY CLUSTERED (ID_FILTRO_SALVO),
        CONSTRAINT FK_Filtro_Salvo_Usuario FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT UQ_Filtro_Salvo_NOME    UNIQUE (ID_USUARIO, ITEM, NOME),
        CONSTRAINT CK_Filtro_Salvo_FILTRO  CHECK (ISJSON(FILTRO) = 1)
    );
    CREATE UNIQUE INDEX UX_Filtro_Salvo_PADRAO ON [SIS].[Filtro_Salvo] (ID_USUARIO, ITEM) WHERE PADRAO = 1;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Lista das telas Contas a pagar (@Tipo P) e Contas a receber
                (@Tipo R) e da aba Movimentação do Parceiro (@Tipo NULL com
                @IdPessoa: os dois tipos que o usuário pode ver).
                @Visao PARCELA (padrão): uma linha por vencimento.
                @Visao LANCAMENTO: uma linha por lançamento (vencimento = o
                primeiro das parcelas filtradas; valores = todas as parcelas).
                @Situacao: EM_ABERTO (aberta + parcial), ABERTA, PARCIAL, PAGA,
                CANCELADA, VENCIDA (em aberto e vencida), HOJE (em aberto
                vencendo hoje), A_VENCER (em aberto, de amanhã até
                FIN_LISTA_DIAS_A_VENCER dias) ou vazio (todas; sem as
                canceladas quando FIN_LISTA_OCULTA_CANCELADAS = S).
                @CampoData escolhe a data do período (@VencDe/@VencAte):
                VENCIMENTO (padrão), EMISSAO ou COMPETENCIA (mês).
                Filtros opcionais por período, empresa, centro,
                parceiro, conta do plano, lote, documento, texto e valor.
                Paginação (@Pagina, @PorPagina; padrão FIN_LISTA_POR_PAGINA:
                a página é escolhida antes de buscar os detalhes) e
                totais do filtro inteiro em cada linha (TOTAL_*). Não lista o
                que está na lixeira. Permissão: VER em FIN_PAGAR / FIN_RECEBER.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
    v1.1 (25/11/2026) - Etapa 04f2a: situações HOJE e A_VENCER, período por
                        emissão ou competência (@CampoData) e canceladas fora
                        de "todas" pelo parâmetro FIN_LISTA_OCULTA_CANCELADAS.

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'R', @Situacao = 'EM_ABERTO';
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'P', @Visao = 'LANCAMENTO', @Texto = N'cimento';
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'R', @Situacao = 'A_VENCER', @CampoData = 'EMISSAO', @VencDe = '2026-01-01';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Listar]
    @IdUsuario      INT,
    @Tipo           CHAR(1)        = NULL,
    @Visao          VARCHAR(12)    = 'PARCELA',
    @Situacao       VARCHAR(12)    = NULL,
    @VencDe         DATE           = NULL,
    @VencAte        DATE           = NULL,
    @CampoData      VARCHAR(12)    = 'VENCIMENTO',
    @IdEmpresa      INT            = NULL,
    @IdCentroCusto  INT            = NULL,
    @IdPessoa       INT            = NULL,
    @IdPlanoConta   INT            = NULL,
    @IdLote         BIGINT         = NULL,
    @IdLancamento   BIGINT         = NULL,
    @Documento      NVARCHAR(40)   = NULL,
    @Texto          NVARCHAR(100)  = NULL,
    @ValorDe        DECIMAL(18,2)  = NULL,
    @ValorAte       DECIMAL(18,2)  = NULL,
    @Ordem          VARCHAR(12)    = 'VENCIMENTO',
    @Pagina         INT            = 1,
    @PorPagina      INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @VeP        BIT;
    DECLARE @VeR        BIT;
    DECLARE @Hoje       DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Termo      NVARCHAR(102);
    DECLARE @Digitos    VARCHAR(100);
    DECLARE @Linhas     INT = 0;
    DECLARE @TotValor   DECIMAL(18,2) = 0;
    DECLARE @TotBaixado DECIMAL(18,2) = 0;
    DECLARE @TotSaldo   DECIMAL(18,2) = 0;
    DECLARE @DiasAVencer INT;
    DECLARE @OcultaCanc  BIT;

    DROP TABLE IF EXISTS #F;
    DROP TABLE IF EXISTS #G;
    DROP TABLE IF EXISTS #T;
    DROP TABLE IF EXISTS #Pg;

    BEGIN TRY
        SET @Tipo = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Tipo, '')))), '');
        SET @VeP  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VeR  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        IF (@Tipo = 'P' AND @VeP = 0) OR (@Tipo = 'R' AND @VeR = 0) OR (@Tipo IS NULL AND @VeP = 0 AND @VeR = 0)
            THROW 50001, N'Você não tem permissão para ver estes lançamentos.', 1;
        IF @Tipo IS NOT NULL AND @Tipo NOT IN ('P', 'R')
            THROW 50001, N'Tipo inválido.', 1;

        SET @Visao     = CASE WHEN UPPER(ISNULL(@Visao, '')) = 'LANCAMENTO' THEN 'LANCAMENTO' ELSE 'PARCELA' END;
        SET @Situacao  = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Situacao, '')))), '');
        SET @Ordem     = UPPER(ISNULL(@Ordem, 'VENCIMENTO'));
        SET @CampoData = CASE UPPER(ISNULL(@CampoData, '')) WHEN 'EMISSAO' THEN 'EMISSAO' WHEN 'COMPETENCIA' THEN 'COMPETENCIA' ELSE 'VENCIMENTO' END;
        SET @DiasAVencer = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_DIAS_A_VENCER'), 7);
        IF @DiasAVencer NOT BETWEEN 1 AND 365 SET @DiasAVencer = 7;
        SET @OcultaCanc  = ISNULL(SIS.fn_SIS_Parametro_SN('FIN_LISTA_OCULTA_CANCELADAS'), 1);
        SET @Pagina    = CASE WHEN ISNULL(@Pagina, 1) < 1 THEN 1 ELSE @Pagina END;
        SET @PorPagina = ISNULL(@PorPagina, ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_POR_PAGINA'), 100));
        IF @PorPagina NOT BETWEEN 10 AND 1000 SET @PorPagina = 100;
        SET @Documento = NULLIF(LTRIM(RTRIM(ISNULL(@Documento, N''))), N'');
        SET @Texto     = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @Termo     = N'%' + REPLACE(REPLACE(REPLACE(ISNULL(@Texto, N''), N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Digitos   = NULLIF(CONVERT(VARCHAR(100), CAD.fn_CAD_Somente_Digitos(ISNULL(@Texto, N''))), '');

        SET @EtapaAtual = 'Filtro';
        SELECT p.ID_PARCELA, p.ID_LANCAMENTO, p.NUMERO, p.DT_VENCIMENTO, p.VALOR, p.VALOR_BAIXADO, p.SALDO, l.DT_EMISSAO,
               ISNULL(pe.NOME, N'') AS PESSOA_NOME
        INTO #F
        FROM FIN.Parcela p WITH (NOLOCK)
        INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        LEFT  JOIN CAD.Pessoa pe    WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        WHERE l.DT_EXCLUSAO IS NULL
          AND ((l.TIPO = 'P' AND @VeP = 1) OR (l.TIPO = 'R' AND @VeR = 1))
          AND (@Tipo IS NULL OR l.TIPO = @Tipo)
          AND ((@Situacao IS NULL AND (@OcultaCanc = 0 OR p.SITUACAO <> 'CANCELADA'))
               OR (@Situacao = 'EM_ABERTO' AND p.SITUACAO IN ('ABERTA', 'PARCIAL'))
               OR (@Situacao = 'VENCIDA'   AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje)
               OR (@Situacao = 'HOJE'      AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO = @Hoje)
               OR (@Situacao = 'A_VENCER'  AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO > @Hoje AND p.DT_VENCIMENTO <= DATEADD(DAY, @DiasAVencer, @Hoje))
               OR p.SITUACAO = @Situacao)
          AND (@VencDe IS NULL
               OR (@CampoData = 'VENCIMENTO'  AND p.DT_VENCIMENTO >= @VencDe)
               OR (@CampoData = 'EMISSAO'     AND l.DT_EMISSAO >= @VencDe)
               OR (@CampoData = 'COMPETENCIA' AND l.DT_COMPETENCIA >= DATEFROMPARTS(YEAR(@VencDe), MONTH(@VencDe), 1)))
          AND (@VencAte IS NULL
               OR (@CampoData = 'VENCIMENTO'  AND p.DT_VENCIMENTO <= @VencAte)
               OR (@CampoData = 'EMISSAO'     AND l.DT_EMISSAO <= @VencAte)
               OR (@CampoData = 'COMPETENCIA' AND l.DT_COMPETENCIA <= @VencAte))
          AND (@IdEmpresa     IS NULL OR l.ID_EMPRESA = @IdEmpresa)
          AND (@IdCentroCusto IS NULL OR l.ID_CENTRO_CUSTO = @IdCentroCusto)
          AND (@IdPessoa      IS NULL OR l.ID_PESSOA = @IdPessoa)
          AND (@IdPlanoConta  IS NULL OR l.ID_PLANO_CONTA = @IdPlanoConta)
          AND (@IdLote        IS NULL OR l.ID_LOTE = @IdLote OR p.ID_LOTE = @IdLote)
          AND (@IdLancamento  IS NULL OR l.ID_LANCAMENTO = @IdLancamento)
          AND (@Documento     IS NULL OR l.DOCUMENTO LIKE @Documento + N'%')
          AND (@ValorDe       IS NULL OR p.VALOR >= @ValorDe)
          AND (@ValorAte      IS NULL OR p.VALOR <= @ValorAte)
          AND (@Texto IS NULL
               OR l.HISTORICO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR l.DOCUMENTO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR l.OBSERVACAO COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME      COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME_FANTASIA COLLATE Latin1_General_CI_AI LIKE @Termo
               OR (@Digitos IS NOT NULL AND LEN(@Digitos) >= 5 AND pe.CPF_CNPJ LIKE @Digitos + '%')
               OR CONVERT(NVARCHAR(20), l.ID_LANCAMENTO) = @Texto)
        OPTION (RECOMPILE);

        -- linhas da página primeiro (só com o que já está em #F); detalhes depois, só para elas
        SET @EtapaAtual = 'Página';
        CREATE TABLE #Pg (ORDEM INT NOT NULL, ID_LANCAMENTO BIGINT NOT NULL, ID_PARCELA BIGINT NULL, DT_VENCIMENTO DATE NULL,
                          QTD INT NULL, VALOR DECIMAL(18,2) NULL, BAIXADO DECIMAL(18,2) NULL, SALDO DECIMAL(18,2) NULL,
                          EM_ABERTO INT NULL, CANCELADAS INT NULL, PRIMEIRA_VENCIDA DATE NULL);

        IF @Visao = 'PARCELA'
        BEGIN
            SELECT @Linhas = COUNT(*), @TotValor = ISNULL(SUM(f.VALOR), 0), @TotBaixado = ISNULL(SUM(f.VALOR_BAIXADO), 0), @TotSaldo = ISNULL(SUM(f.SALDO), 0) FROM #F f;

            INSERT INTO #Pg (ORDEM, ID_LANCAMENTO, ID_PARCELA, DT_VENCIMENTO)
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)), x.ID_LANCAMENTO, x.ID_PARCELA, x.DT_VENCIMENTO
            FROM (SELECT f.ID_LANCAMENTO, f.ID_PARCELA, f.DT_VENCIMENTO, f.VALOR, f.PESSOA_NOME, f.DT_EMISSAO, f.NUMERO
                  FROM #F f
                  ORDER BY CASE WHEN @Ordem = 'VALOR'    THEN f.VALOR END DESC,
                           CASE WHEN @Ordem = 'PARCEIRO' THEN f.PESSOA_NOME END,
                           CASE WHEN @Ordem = 'EMISSAO'  THEN f.DT_EMISSAO END DESC,
                           f.DT_VENCIMENTO, f.ID_LANCAMENTO, f.NUMERO
                  OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY) x;
        END
        ELSE
        BEGIN
            SELECT g.ID_LANCAMENTO, MIN(g.DT_VENCIMENTO) AS DT_VENCIMENTO, MAX(g.PESSOA_NOME) AS PESSOA_NOME, MAX(g.DT_EMISSAO) AS DT_EMISSAO
            INTO #G
            FROM #F g
            GROUP BY g.ID_LANCAMENTO;

            SELECT p.ID_LANCAMENTO, COUNT(*) AS QTD, SUM(p.VALOR) AS VALOR, SUM(p.VALOR_BAIXADO) AS BAIXADO, SUM(p.SALDO) AS SALDO,
                   SUM(CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') THEN 1 ELSE 0 END) AS EM_ABERTO,
                   SUM(CASE WHEN p.SITUACAO = 'CANCELADA' THEN 1 ELSE 0 END) AS CANCELADAS,
                   MIN(CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN p.DT_VENCIMENTO END) AS PRIMEIRA_VENCIDA
            INTO #T
            FROM FIN.Parcela p WITH (NOLOCK)
            INNER JOIN #G g ON g.ID_LANCAMENTO = p.ID_LANCAMENTO
            GROUP BY p.ID_LANCAMENTO;

            SELECT @Linhas = COUNT(*), @TotValor = ISNULL(SUM(t.VALOR), 0), @TotBaixado = ISNULL(SUM(t.BAIXADO), 0), @TotSaldo = ISNULL(SUM(t.SALDO), 0) FROM #T t;

            INSERT INTO #Pg (ORDEM, ID_LANCAMENTO, DT_VENCIMENTO, QTD, VALOR, BAIXADO, SALDO, EM_ABERTO, CANCELADAS, PRIMEIRA_VENCIDA)
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)), x.ID_LANCAMENTO, x.DT_VENCIMENTO, x.QTD, x.VALOR, x.BAIXADO, x.SALDO, x.EM_ABERTO, x.CANCELADAS, x.PRIMEIRA_VENCIDA
            FROM (SELECT g.ID_LANCAMENTO, g.DT_VENCIMENTO, t.QTD, t.VALOR, t.BAIXADO, t.SALDO, t.EM_ABERTO, t.CANCELADAS, t.PRIMEIRA_VENCIDA
                  FROM #G g
                  INNER JOIN #T t ON t.ID_LANCAMENTO = g.ID_LANCAMENTO
                  ORDER BY CASE WHEN @Ordem = 'VALOR'    THEN t.VALOR END DESC,
                           CASE WHEN @Ordem = 'PARCEIRO' THEN g.PESSOA_NOME END,
                           CASE WHEN @Ordem = 'EMISSAO'  THEN g.DT_EMISSAO END DESC,
                           g.DT_VENCIMENTO, g.ID_LANCAMENTO
                  OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY) x;
        END;

        SET @EtapaAtual = 'Consulta';
        SELECT l.ID_LANCAMENTO, pg.ID_PARCELA, l.TIPO,
               CAST(p.NUMERO AS SMALLINT) AS NUMERO,
               CAST(ISNULL(p.QTD_PARCELAS, pg.QTD) AS SMALLINT) AS QTD_PARCELAS,
               pg.DT_VENCIMENTO,
               CAST(ISNULL(p.VALOR, pg.VALOR) AS DECIMAL(18,2)) AS VALOR,
               CAST(ISNULL(p.VALOR_BAIXADO, pg.BAIXADO) AS DECIMAL(18,2)) AS VALOR_BAIXADO,
               CAST(ISNULL(p.SALDO, pg.SALDO) AS DECIMAL(18,2)) AS SALDO,
               CAST(CASE WHEN p.ID_PARCELA IS NOT NULL THEN p.SITUACAO
                         WHEN pg.CANCELADAS = pg.QTD THEN 'CANCELADA'
                         WHEN pg.EM_ABERTO = 0 THEN 'PAGA'
                         WHEN pg.BAIXADO > 0 THEN 'PARCIAL'
                         ELSE 'ABERTA' END AS VARCHAR(10)) AS SITUACAO,
               CAST(CASE WHEN p.ID_PARCELA IS NOT NULL AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN 1
                         WHEN p.ID_PARCELA IS NULL AND pg.PRIMEIRA_VENCIDA IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
               CASE WHEN p.ID_PARCELA IS NOT NULL AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN DATEDIFF(DAY, p.DT_VENCIMENTO, @Hoje)
                    WHEN p.ID_PARCELA IS NULL AND pg.PRIMEIRA_VENCIDA IS NOT NULL THEN DATEDIFF(DAY, pg.PRIMEIRA_VENCIDA, @Hoje) ELSE 0 END AS DIAS_ATRASO,
               l.DT_EMISSAO, l.DT_COMPETENCIA, l.DOCUMENTO, l.HISTORICO,
               l.ID_PESSOA, ISNULL(pe.NOME, N'') AS PESSOA_NOME,
               l.ID_EMPRESA, ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) AS EMPRESA_NOME,
               l.ID_CENTRO_CUSTO, ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'') AS CENTRO_CODIGO, ISNULL(cc.DESCRICAO, N'') AS CENTRO_DESCRICAO,
               l.ID_PLANO_CONTA, ISNULL(CONVERT(NVARCHAR(12), v.CODIGO), N'') AS PLANO_CODIGO, ISNULL(v.DESCRICAO, N'') AS PLANO_DESCRICAO,
               ISNULL(p.ID_LOTE, l.ID_LOTE) AS ID_LOTE, l.ORIGEM, l.PREVISAO, l.SITUACAO AS LANCAMENTO_SITUACAO,
               @Linhas AS TOTAL_LINHAS, @TotValor AS TOTAL_VALOR, @TotBaixado AS TOTAL_BAIXADO, @TotSaldo AS TOTAL_SALDO
        FROM #Pg pg
        INNER JOIN FIN.Lancamento l         WITH (NOLOCK) ON l.ID_LANCAMENTO = pg.ID_LANCAMENTO
        INNER JOIN CAD.Empresa e            WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
        LEFT  JOIN FIN.Parcela p            WITH (NOLOCK) ON p.ID_PARCELA = pg.ID_PARCELA
        LEFT  JOIN CAD.Pessoa pe            WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        LEFT  JOIN CAD.Centro_Custo cc      WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO
        LEFT  JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = l.ID_PLANO_CONTA
        ORDER BY pg.ORDEM;

        DROP TABLE IF EXISTS #F;
        DROP TABLE IF EXISTS #G;
        DROP TABLE IF EXISTS #T;
        DROP TABLE IF EXISTS #Pg;
    END TRY
    BEGIN CATCH
        DROP TABLE IF EXISTS #F;
        DROP TABLE IF EXISTS #G;
        DROP TABLE IF EXISTS #T;
        DROP TABLE IF EXISTS #Pg;
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os lançamentos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Resumo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Resumo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Contadores do topo das telas Contas a pagar (@Tipo P) e Contas
                a receber (@Tipo R): quantidade e saldo das parcelas em aberto
                vencidas, vencendo hoje, a vencer (de amanhã até
                FIN_LISTA_DIAS_A_VENCER dias) e o total em aberto. Respeita os
                filtros de empresa, centro, parceiro e conta do plano (não os
                de situação e período: cada contador é uma situação). Devolve
                também os parâmetros que a tela usa ao abrir (situação e visão
                iniciais, linhas por página, dias a vencer). Não conta o que
                está na lixeira. Permissão: VER em FIN_PAGAR / FIN_RECEBER.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Resumo @IdUsuario = 2, @Tipo = 'R';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Resumo]
    @IdUsuario      INT,
    @Tipo           CHAR(1),
    @IdEmpresa      INT = NULL,
    @IdCentroCusto  INT = NULL,
    @IdPessoa       INT = NULL,
    @IdPlanoConta   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Resumo]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje        DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @DiasAVencer INT;
    DECLARE @Limite      DATE;
    DECLARE @PorPagina   INT;
    DECLARE @SitInicial  NVARCHAR(20);
    DECLARE @VisInicial  NVARCHAR(20);

    BEGIN TRY
        SET @Tipo = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        IF @Tipo NOT IN ('P', 'R')
            THROW 50001, N'Tipo inválido.', 1;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver estes lançamentos.', 1;

        SET @EtapaAtual  = 'Parâmetros';
        SET @DiasAVencer = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_DIAS_A_VENCER'), 7);
        IF @DiasAVencer NOT BETWEEN 1 AND 365 SET @DiasAVencer = 7;
        SET @Limite      = DATEADD(DAY, @DiasAVencer, @Hoje);
        SET @PorPagina   = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_POR_PAGINA'), 100);
        IF @PorPagina NOT BETWEEN 10 AND 1000 SET @PorPagina = 100;
        SET @SitInicial  = UPPER(ISNULL(SIS.fn_SIS_Parametro('FIN_LISTA_SITUACAO_INICIAL'), N'EM_ABERTO'));
        IF @SitInicial NOT IN (N'EM_ABERTO', N'VENCIDA', N'HOJE', N'A_VENCER', N'TODAS') SET @SitInicial = N'EM_ABERTO';
        SET @VisInicial  = UPPER(ISNULL(SIS.fn_SIS_Parametro('FIN_LISTA_VISAO_INICIAL'), N'PARCELA'));
        IF @VisInicial NOT IN (N'PARCELA', N'LANCAMENTO') SET @VisInicial = N'PARCELA';

        SET @EtapaAtual = 'Consulta';
        SELECT CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END), 0) AS INT)                                        AS QTD_VENCIDAS,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2))                        AS VALOR_VENCIDAS,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO = @Hoje THEN 1 ELSE 0 END), 0) AS INT)                                        AS QTD_HOJE,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO = @Hoje THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2))                        AS VALOR_HOJE,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO > @Hoje AND p.DT_VENCIMENTO <= @Limite THEN 1 ELSE 0 END), 0) AS INT)         AS QTD_A_VENCER,
               CAST(ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO > @Hoje AND p.DT_VENCIMENTO <= @Limite THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2)) AS VALOR_A_VENCER,
               CAST(COUNT(*) AS INT)                                                                                                   AS QTD_EM_ABERTO,
               CAST(ISNULL(SUM(p.SALDO), 0) AS DECIMAL(18,2))                                                                          AS VALOR_EM_ABERTO,
               @DiasAVencer                                                                                                            AS DIAS_A_VENCER,
               @PorPagina                                                                                                              AS POR_PAGINA,
               CAST(@SitInicial AS VARCHAR(12))                                                                                        AS SITUACAO_INICIAL,
               CAST(@VisInicial AS VARCHAR(12))                                                                                        AS VISAO_INICIAL
        FROM FIN.Parcela p WITH (NOLOCK)
        INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE l.DT_EXCLUSAO IS NULL
          AND l.TIPO = @Tipo
          AND p.SITUACAO IN ('ABERTA', 'PARCIAL')
          AND (@IdEmpresa     IS NULL OR l.ID_EMPRESA = @IdEmpresa)
          AND (@IdCentroCusto IS NULL OR l.ID_CENTRO_CUSTO = @IdCentroCusto)
          AND (@IdPessoa      IS NULL OR l.ID_PESSOA = @IdPessoa)
          AND (@IdPlanoConta  IS NULL OR l.ID_PLANO_CONTA = @IdPlanoConta)
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o resumo dos lançamentos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Filtro_Salvo_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Filtro_Salvo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Filtros salvos do próprio usuário numa tela (@Item = código da
                tela em SIS.Item, ex.: FIN_RECEBER), o padrão primeiro e depois
                por nome. Permissão: VER na tela. Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Filtro_Salvo_Listar @IdUsuario = 2, @Item = 'FIN_RECEBER';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Filtro_Salvo_Listar]
    @IdUsuario  INT,
    @Item       VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Filtro_Salvo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        SET @Item = UPPER(LTRIM(RTRIM(ISNULL(@Item, ''))));
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver esta tela.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT f.ID_FILTRO_SALVO, f.NOME, f.FILTRO, f.PADRAO
        FROM SIS.Filtro_Salvo f
        WHERE f.ID_USUARIO = @IdUsuario
          AND f.ITEM = @Item
        ORDER BY f.PADRAO DESC, f.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os filtros salvos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Filtro_Salvo_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Filtro_Salvo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Salva um filtro da lista para o próprio usuário. Nome que já
                existe na mesma tela é substituído (salvar de novo atualiza).
                @Padrao = 1 marca como o filtro com que a lista abre e tira a
                marca dos outros da mesma tela. Limite de filtros por usuário
                e tela no parâmetro FILTRO_SALVO_MAX. Permissão: VER na tela.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_FILTRO_SALVO.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = 2, @Item = 'FIN_RECEBER', @Nome = N'Vencidos', @Filtro = N'{"situacao":"VENCIDA"}', @Padrao = 0;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Filtro_Salvo_Gravar]
    @IdUsuario  INT,
    @Item       VARCHAR(40),
    @Nome       NVARCHAR(60),
    @Filtro     NVARCHAR(MAX),
    @Padrao     BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Filtro_Salvo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Id         INT;
    DECLARE @Max        INT;
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Item   = UPPER(LTRIM(RTRIM(ISNULL(@Item, ''))));
        SET @Nome   = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Filtro = LTRIM(RTRIM(ISNULL(@Filtro, N'')));
        SET @Padrao = ISNULL(@Padrao, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para ver esta tela.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_FILTRO_SALVO;
            RETURN;
        END;
        IF @Nome = N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe um nome para o filtro.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_FILTRO_SALVO;
            RETURN;
        END;
        IF LEN(@Filtro) > 2000 OR ISJSON(@Filtro) = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Filtro inválido.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_FILTRO_SALVO;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Max     = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FILTRO_SALVO_MAX'), 20);

        SET @EtapaAtual = 'Limite';
        SELECT @Id = f.ID_FILTRO_SALVO
        FROM SIS.Filtro_Salvo f
        WHERE f.ID_USUARIO = @IdUsuario AND f.ITEM = @Item AND f.NOME = @Nome;

        IF @Id IS NULL AND (SELECT COUNT(*) FROM SIS.Filtro_Salvo f WHERE f.ID_USUARIO = @IdUsuario AND f.ITEM = @Item) >= @Max
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO,
                   CAST(N'Você já tem ' + CONVERT(NVARCHAR(10), @Max) + N' filtros salvos nesta tela. Apague um antes de salvar outro.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_FILTRO_SALVO;
            RETURN;
        END;

        -- preferência do próprio usuário (só ele grava): sem disputa entre sessões
        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF @Padrao = 1
                UPDATE f
                   SET f.PADRAO = 0, f.DT_ALTERACAO = SYSDATETIME(), f.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Filtro_Salvo f
                WHERE f.ID_USUARIO = @IdUsuario AND f.ITEM = @Item AND f.PADRAO = 1
                  AND (@Id IS NULL OR f.ID_FILTRO_SALVO <> @Id);

            IF @Id IS NULL
            BEGIN
                INSERT INTO SIS.Filtro_Salvo (ID_USUARIO, ITEM, NOME, FILTRO, PADRAO, USUARIO_CRIACAO)
                VALUES (@IdUsuario, @Item, @Nome, @Filtro, @Padrao, @Usuario);
                SET @Id = SCOPE_IDENTITY();
            END
            ELSE
                UPDATE f
                   SET f.FILTRO = @Filtro, f.PADRAO = @Padrao, f.DT_ALTERACAO = SYSDATETIME(), f.USUARIO_ALTERACAO = @Usuario
                FROM SIS.Filtro_Salvo f
                WHERE f.ID_FILTRO_SALVO = @Id;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Filtro salvo.' AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID_FILTRO_SALVO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível salvar o filtro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_FILTRO_SALVO;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Filtro_Salvo_Excluir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Filtro_Salvo_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Apaga um filtro salvo do próprio usuário (filtro de outro
                usuário não é encontrado). Preferência de uso: apaga de vez,
                sem lixeira. Devolve 1 linha: SUCESSO, MENSAGEM, ID_FILTRO_SALVO.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f2a).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Filtro_Salvo_Excluir @IdUsuario = 2, @IdFiltroSalvo = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Filtro_Salvo_Excluir]
    @IdUsuario      INT,
    @IdFiltroSalvo  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Filtro_Salvo_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Exclusão';

    BEGIN TRY
        DELETE f
        FROM SIS.Filtro_Salvo f
        WHERE f.ID_FILTRO_SALVO = @IdFiltroSalvo
          AND f.ID_USUARIO = @IdUsuario;

        IF @@ROWCOUNT = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Filtro não encontrado.' AS NVARCHAR(400)) AS MENSAGEM, @IdFiltroSalvo AS ID_FILTRO_SALVO;
            RETURN;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Filtro apagado.' AS NVARCHAR(400)) AS MENSAGEM, @IdFiltroSalvo AS ID_FILTRO_SALVO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível apagar o filtro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdFiltroSalvo AS ID_FILTRO_SALVO;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros de fábrica da base SIS. Só insere o que falta
                (PADRAO_SQL regra 39): valor já alterado pelo administrador
                nunca é sobrescrito. VALOR_PADRAO recebe o mesmo valor de
                fábrica. Cada etapa seguinte acrescenta os seus parâmetros
                (multa, juros, régua de cobrança...) neste arquivo.
                EDITAVEL_ADMIN = 0: só o instalador muda, por script.
                Depende de Carga_SIS_Modulo.sql.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: SENHA_PBKDF2_ITERACOES.
    v1.2 (15/11/2026) - Identidade visual por cliente: pasta, logomarcas e
                        cores (valores de fábrica = CMJ).
    v1.3 (16/11/2026) - Etapa 02d: e-mail (domínio interno, minutos preso),
                        pastas de backup e de atualizações.
    v1.4 (17/11/2026) - Etapa 03c: EMAIL_LOCAL_LIBERADOS (exceção controlada do
                        banco de teste, pedido do Celso) e SISTEMA_NOME
                        (nome do sistema por cliente, pedido do Celso: SisCMJ);
                        EMAIL_LOGO_MODO, EMAIL_LOGO_ENDERECO e
                        EMAIL_LOGO_NOME_ARQUIVO (como a logomarca vai no e-mail).
    v1.5 (20/11/2026) - Etapa 03d: EMAIL_RODAPE_CNPJ (CNPJ no rodapé dos e-mails
                        a clientes e terceiros; fábrica N, pedido do Celso).
    v1.6 (20/11/2026) - Etapa 03d: LOGIN_COMPUTADOR_TENTATIVAS e
                        LOGIN_COMPUTADOR_MINUTOS (limite de tentativas por computador).
    v1.7 (20/11/2026) - Etapa 03d: BACKUP_DIAS_MANTER, BACKUP_NUVEM_MANTER e os
                        avisos de atraso (BACKUP_HORAS_ALERTA_COMPLETO/_LOG,
                        BACKUP_DIAS_ALERTA_TESTE).
    v1.8 (20/11/2026) - Etapa 03d2: BACKUP_RESTAURACAO_MOTIVO_MINIMO (restauração
                        pela tela).
    v1.9 (22/11/2026) - Etapa 04a: SENHA_PROVISORIA_PADRAO e SENHA_PROVISORIA_HORAS
                        (botão Reiniciar senha da tela de Usuários; decisão do
                        Celso de 16/11/2026, PADRAO_TELAS regra 13).
    v2.0 (22/11/2026) - Etapa 04b (P20): LIXEIRA_ATIVA, LIXEIRA_DIAS_GUARDA (90),
                        LIXEIRA_AVISO_DIAS, LIXEIRA_AVISO_GRUPO e
                        LIXEIRA_LIMPEZA_ATIVA.
    v2.1 (23/11/2026) - Etapa 04c (P22): NOVIDADES_AVISO_ATIVO,
                        NOVIDADES_VERSOES_MAX (3), VERSAO_AVISO_EMAIL_ATIVO e
                        VERSAO_AVISO_GRUPO.
    v2.2 (25/11/2026) - Etapa 04d (P12, P10): PARCEIRO_ROTULO, PARCEIRO_ROTULO_PLURAL,
                        CEP_CONSULTA_ATIVA, CEP_URL_PRINCIPAL, CEP_URL_RESERVA,
                        CEP_CACHE_DIAS, CNPJ_CONSULTA_ATIVA, CNPJ_URL,
                        CONSULTA_TEMPO_LIMITE_SEG e COBRANCA_APTO_EXIGE_*.
    v2.3 (25/11/2026) - Etapa 04e: CENTRO_ENCERRADO_BLOQUEIA (lançamento novo em
                        centro de custo encerrado: S = bloqueia, N = só avisa) e
                        SELETOR_LIMITE (máximo de linhas nas escolhas com busca).
    v2.4 (25/11/2026) - Etapa 04f2a: FILTRO_SALVO_MAX (filtros salvos por
                        usuário em cada lista).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN)
SELECT v.CHAVE, v.VALOR, v.VALOR, v.TIPO, v.DESCRICAO, m.ID_MODULO, v.EDITAVEL_ADMIN
FROM (VALUES
        (CAST('EMAIL_TESTE' AS VARCHAR(60)), CAST(N'celsofreitas62@gmail.com' AS NVARCHAR(4000)), CAST('EMAIL' AS VARCHAR(10)),
         CAST(N'Endereço que recebe TODOS os e-mails quando o sistema roda em modo teste (banco _LOCAL).' AS NVARCHAR(400)), CAST('SIS' AS VARCHAR(10)), CAST(0 AS BIT)),
        ('EMAIL_ADMIN_ALERTA', N'', 'EMAIL',
         N'Endereço que recebe os alertas técnicos (falha no envio de e-mail, rotina com erro). Vazio = sem alerta.', 'SIS', 1),
        ('EMAIL_TENTATIVAS_MAX', N'5', 'INTEIRO',
         N'Quantas vezes o serviço tenta reenviar um e-mail com falha temporária antes de desistir.', 'SIS', 1),
        ('SENHA_TAMANHO_MINIMO', N'8', 'INTEIRO',
         N'Quantidade mínima de caracteres da senha dos usuários.', 'SIS', 1),
        ('SENHA_TENTATIVAS_BLOQUEIO', N'5', 'INTEIRO',
         N'Tentativas de senha errada seguidas até o usuário ser bloqueado.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_TENTATIVAS', N'10', 'INTEIRO',
         N'Tentativas de login erradas seguidas, de um mesmo computador (com qualquer usuário), até ele ficar em espera. Mínimo 5.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_MINUTOS', N'15', 'INTEIRO',
         N'Minutos que o computador fica em espera depois de errar o login demais, e janela de contagem das tentativas.', 'SIS', 1),
        ('SESSAO_MINUTOS_INATIVIDADE', N'30', 'INTEIRO',
         N'Minutos sem uso até a sessão expirar e pedir login de novo.', 'SIS', 1),
        ('ANEXO_PASTA_RAIZ', N'C:\SistemaCMJ_Arquivos\Anexos', 'TEXTO',
         N'Pasta do servidor onde os anexos são gravados (o banco guarda só a referência).', 'SIS', 0),
        ('ANEXO_TAMANHO_MAX_MB', N'20', 'INTEIRO',
         N'Tamanho máximo de cada anexo, em MB.', 'SIS', 1),
        ('LOG_PASSO_DIAS_RETENCAO', N'90', 'INTEIRO',
         N'Dias que o log passo a passo das rotinas é guardado (mínimo 7). O log de erros não é apagado.', 'SIS', 1),
        ('SENHA_PBKDF2_ITERACOES', N'600000', 'INTEIRO',
         N'Iterações do PBKDF2-SHA256 usadas pela API ao gravar senha (mínimo aceito: 100000).', 'SIS', 0),
        ('IDENTIDADE_PASTA', N'C:\SistemaCMJ_Arquivos\Identidade', 'TEXTO',
         N'Pasta do servidor com os arquivos de identidade visual do cliente (logomarcas).', 'SIS', 0),
        ('EMPRESA_LOGO', N'logo.png', 'ARQUIVO',
         N'Logomarca vertical completa (documentos, contratos, telas grandes). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_HORIZONTAL', N'logo_horizontal.png', 'ARQUIVO',
         N'Logomarca horizontal (cabeçalho do sistema e dos relatórios). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_EMAIL', N'logo_email.png', 'ARQUIVO',
         N'Logomarca pequena do cabeçalho dos e-mails. Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_SIMBOLO', N'logo_simbolo.png', 'ARQUIVO',
         N'Só o símbolo da logomarca (menu recolhido, ícone). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_COR_PRINCIPAL', N'#D43414', 'COR',
         N'Cor principal do cliente: cabeçalhos do sistema, dos relatórios e dos e-mails informativos.', 'SIS', 1),
        ('EMPRESA_COR_SECUNDARIA', N'#A8A8A8', 'COR',
         N'Cor secundária do cliente (detalhes, linhas, textos de apoio).', 'SIS', 1),
        ('EMAIL_COR_ALERTA', N'#E65100', 'COR',
         N'Cor dos avisos de alerta (vencido, falha, divergência). Diferente da cor principal.', 'SIS', 1),
        ('EMAIL_COR_SUCESSO', N'#2E7D32', 'COR',
         N'Cor das confirmações (pagamento recebido, envio concluído).', 'SIS', 1),
        ('EMAIL_DOMINIO_INTERNO', N'', 'TEXTO',
         N'Domínio(s) do e-mail da empresa (ex.: cmj.com.br), separados por vírgula. Esses endereços saem pela conta interna; os demais pela externa. Vazio = todos pela interna.', 'SIS', 1),
        ('SISTEMA_NOME', N'SisCMJ', 'TEXTO',
         N'Nome do sistema mostrado nas telas, nos e-mails (rodapé e remetente) e nos relatórios. Só o administrador geral altera.', 'SIS', 0),
        ('EMAIL_LOGO_MODO', N'EMBUTIDA', 'TEXTO',
         N'Logomarca nos e-mails: EMBUTIDA (vai dentro do e-mail), ENDERECO (puxada do endereço público EMAIL_LOGO_ENDERECO, não aparece como anexo) ou SEM_IMAGEM (só a faixa colorida).', 'SIS', 0),
        ('EMAIL_LOGO_ENDERECO', N'', 'TEXTO',
         N'Endereço público (https://...) da logomarca, usado quando EMAIL_LOGO_MODO = ENDERECO.', 'SIS', 0),
        ('EMAIL_LOGO_NOME_ARQUIVO', N'CMJ.png', 'TEXTO',
         N'Nome com que a logomarca embutida aparece para quem recebe o e-mail (ex.: CMJ.png).', 'SIS', 0),
        ('EMAIL_LOCAL_LIBERADOS', N'', 'TEXTO',
         N'Só no banco de teste (_LOCAL): tipos de e-mail que saem para os destinatários reais em vez de irem para o EMAIL_TESTE, separados por vírgula (ex.: COMUNICADO). Vazio = todos desviados. Não tem efeito em produção.', 'SIS', 0),
        ('EMAIL_MINUTOS_PRESO', N'15', 'INTEIRO',
         N'Minutos que um e-mail pode ficar "processando" antes de voltar para a fila (serviço parou no meio). Mínimo 5.', 'SIS', 1),
        ('BACKUP_PASTA', N'C:\SistemaCMJ_Arquivos\Backup', 'TEXTO',
         N'Pasta do servidor onde ficam os backups do banco.', 'SIS', 0),
        ('BACKUP_PASTA_EXTERNA', N'', 'TEXTO',
         N'Pasta fora do servidor (disco externo ou pasta sincronizada com a nuvem) para onde os backups são copiados. Vazio = não copia.', 'SIS', 0),
        ('BACKUP_DIAS_MANTER', N'7', 'INTEIRO',
         N'Dias de backup guardados na pasta do servidor (completos e do log); os mais antigos são apagados.', 'SIS', 0),
        ('BACKUP_NUVEM_MANTER', N'1', 'INTEIRO',
         N'Quantos backups completos ficam na pasta da nuvem (BACKUP_PASTA_EXTERNA). 0 = não copia.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_COMPLETO', N'26', 'INTEIRO',
         N'Avisa por e-mail se o último backup completo sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_LOG', N'3', 'INTEIRO',
         N'Avisa por e-mail se o último backup do log (de hora em hora) sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_DIAS_ALERTA_TESTE', N'8', 'INTEIRO',
         N'Avisa por e-mail se o último teste de restauração sem erro tiver mais dias que isto.', 'SIS', 0),
        ('BACKUP_RESTAURACAO_MOTIVO_MINIMO', N'10', 'INTEIRO',
         N'Quantidade mínima de letras do motivo obrigatório ao pedir uma restauração de backup pela tela.', 'SIS', 0),
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('EMAIL_RODAPE_CNPJ', N'N', 'SN',
         N'Mostrar o CNPJ da empresa no rodapé dos e-mails enviados a clientes e terceiros (S/N).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1),
        ('SENHA_PROVISORIA_PADRAO', N'@12345', 'TEXTO',
         N'Senha provisória dada pelo botão Reiniciar senha da tela de Usuários. O usuário é obrigado a trocá-la no primeiro acesso.', 'SIS', 0),
        ('SENHA_PROVISORIA_HORAS', N'24', 'INTEIRO',
         N'Horas que a senha provisória vale. Passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar a senha de novo. 0 = não vence. Não vale para o administrador geral.', 'SIS', 1),
        ('LIXEIRA_ATIVA', N'S', 'SN',
         N'S = o botão Excluir das telas manda o registro para a lixeira (recuperável). N = a lixeira fica desligada e só é possível desativar.', 'SIS', 1),
        ('LIXEIRA_DIAS_GUARDA', N'90', 'INTEIRO',
         N'Dias que um registro excluído fica na lixeira antes de ser apagado de vez (mínimo 1). Cada tela pode ter prazo próprio na configuração das tabelas; vazio = vale este.', 'SIS', 1),
        ('LIXEIRA_AVISO_DIAS', N'1', 'INTEIRO',
         N'Com quantos dias de antecedência o e-mail avisa o que será apagado de vez da lixeira. 0 = sem aviso.', 'SIS', 1),
        ('LIXEIRA_AVISO_GRUPO', N'LIXEIRA_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe o aviso do que será apagado da lixeira (tela Grupos de e-mail).', 'SIS', 1),
        ('LIXEIRA_LIMPEZA_ATIVA', N'S', 'SN',
         N'S = a rotina diária apaga de vez o que passou do prazo da lixeira. N = nada é apagado (o aviso continua saindo).', 'SIS', 1),
        ('NOVIDADES_AVISO_ATIVO', N'S', 'SN',
         N'S = depois de cada atualização, cada usuário vê uma vez a janela "O que há de novo" com as notas da versão. N = não mostra (as notas continuam em Sistema › Versões).', 'SIS', 1),
        ('NOVIDADES_VERSOES_MAX', N'3', 'INTEIRO',
         N'Quantas versões, no máximo, a janela "O que há de novo" mostra de uma vez (as mais novas); as outras ficam em Sistema › Versões.', 'SIS', 1),
        ('VERSAO_AVISO_EMAIL_ATIVO', N'S', 'SN',
         N'S = cada atualização concluída manda a nota da versão por e-mail ao grupo do parâmetro VERSAO_AVISO_GRUPO. N = não manda.', 'SIS', 1),
        ('VERSAO_AVISO_GRUPO', N'VERSAO_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe a nota da versão depois de cada atualização (tela Grupos de e-mail).', 'SIS', 1),
        ('PARCEIRO_ROTULO', N'Parceiro', 'TEXTO',
         N'Nome do cadastro de pessoas nas telas e menus (singular). Ex.: Parceiro.', 'CAD', 0),
        ('PARCEIRO_ROTULO_PLURAL', N'Parceiros', 'TEXTO',
         N'Nome do cadastro de pessoas nas telas e menus (plural). Ex.: Parceiros.', 'CAD', 0),
        ('CEP_CONSULTA_ATIVA', N'S', 'SN',
         N'S = ao digitar o CEP, o servidor consulta o endereço na internet (ViaCEP; reserva BrasilAPI). N = digitação manual.', 'CAD', 1),
        ('CEP_URL_PRINCIPAL', N'https://viacep.com.br/ws/{cep}/json/', 'TEXTO',
         N'Endereço da consulta principal de CEP ({cep} = 8 dígitos). Formato de resposta do ViaCEP.', 'CAD', 0),
        ('CEP_URL_RESERVA', N'https://brasilapi.com.br/api/cep/v1/{cep}', 'TEXTO',
         N'Endereço da consulta de CEP usada quando a principal falha ({cep} = 8 dígitos). Formato da BrasilAPI. Vazio = sem reserva.', 'CAD', 0),
        ('CEP_CACHE_DIAS', N'180', 'INTEIRO',
         N'Dias que um endereço consultado fica guardado antes de consultar de novo na internet.', 'CAD', 1),
        ('CNPJ_CONSULTA_ATIVA', N'S', 'SN',
         N'S = ao digitar o CNPJ, o servidor consulta razão social, nome fantasia, endereço e situação na Receita (BrasilAPI). N = digitação manual.', 'CAD', 1),
        ('CNPJ_URL', N'https://brasilapi.com.br/api/cnpj/v1/{cnpj}', 'TEXTO',
         N'Endereço da consulta de CNPJ ({cnpj} = 14 caracteres). Formato da BrasilAPI.', 'CAD', 0),
        ('CONSULTA_TEMPO_LIMITE_SEG', N'8', 'INTEIRO',
         N'Segundos de espera de cada consulta na internet (CEP, CNPJ) antes de desistir e deixar digitar à mão.', 'CAD', 0),
        ('COBRANCA_APTO_EXIGE_DOCUMENTO', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige CPF ou CNPJ válido.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_ENDERECO', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige CEP, logradouro, número, bairro, cidade e UF.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_EMAIL', N'S', 'SN',
         N'Cadastro apto para cobrança (boleto): exige e-mail principal (ou de cobrança) válido.', 'CAD', 1),
        ('COBRANCA_APTO_EXIGE_TELEFONE', N'N', 'SN',
         N'Cadastro apto para cobrança (boleto): exige celular ou telefone.', 'CAD', 1),
        ('CENTRO_ENCERRADO_BLOQUEIA', N'S', 'SN',
         N'Lançamento novo com data depois do encerramento do centro de custo (obra entregue): S = bloqueia; N = só avisa.', 'CAD', 1),
        ('SELETOR_LIMITE', N'50', 'INTEIRO',
         N'Máximo de linhas mostradas nas escolhas com busca (conta do plano, centro de custo, conta bancária).', 'CAD', 0),
        ('FILTRO_SALVO_MAX', N'20', 'INTEIRO',
         N'Quantos filtros salvos cada usuário pode ter em cada lista (ex.: "Vencidos da CMJ" em Contas a receber).', 'SIS', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga dos parâmetros do financeiro em [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Trava de datas (aprovada em 18/11/2026) e proteções contra
                erro de digitação nos lançamentos (P17, aprovado em 25/11/2026).
                Regras FIN_REGRA_*: AVISO (pede confirmação, que fica
                registrada), BLOQUEIO (não deixa gravar) ou NAO (desligada).
                Só insere o que falta (regra 39): nunca sobrescreve o valor
                que a CMJ já alterou. NIVEL_MINIMO e OPCOES são da instalação
                e são acertados sempre. Os parâmetros de uso têm NIVEL_MINIMO
                1 (os dois administradores alteram em "Parâmetros de uso").
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
    v1.1 (25/11/2026) - Etapa 04f2a: parâmetros da lista (dias "a vencer",
                        situação e visão ao abrir, canceladas em "todas").
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaParametro;

SELECT v.CHAVE, v.VALOR, v.TIPO, v.DESCRICAO, v.NIVEL, v.OPCOES
INTO #CargaParametro
FROM (VALUES
        (CAST('FIN_TRAVA_DATAS_ATIVA' AS VARCHAR(60)), CAST(N'S' AS NVARCHAR(4000)), CAST('SN' AS VARCHAR(10)),
         CAST(N'Liga a trava de datas dos lançamentos (datas muito antigas ou futuras são recusadas; quem tem a permissão "Lançar fora da trava de datas" grava informando o motivo).' AS NVARCHAR(400)),
         CAST(1 AS TINYINT), CAST(N'' AS NVARCHAR(200))),
        ('FIN_DIAS_TOLERANCIA_MES_ANTERIOR', N'5', 'INTEIRO',
         N'Data anterior ao 1º dia do mês atual é recusada, menos até este dia do mês, quando o mês anterior ainda é aceito.', 1, N''),
        ('FIN_EMISSAO_DIAS_FUTURO', N'0', 'INTEIRO',
         N'Quantos dias no futuro a data de emissão do documento pode ter (0 = não pode ser futura).', 1, N''),
        ('FIN_BAIXA_DIAS_FUTURO', N'0', 'INTEIRO',
         N'Quantos dias no futuro a data de pagamento, recebimento, transferência ou movimento bancário pode ter (0 = não pode ser futura).', 1, N''),
        ('FIN_VENCIMENTO_ANOS_FUTURO', N'35', 'INTEIRO',
         N'Até quantos anos à frente um vencimento pode ser lançado.', 1, N''),
        ('FIN_DATA_AVISO_DIAS', N'3', 'INTEIRO',
         N'Data de emissão (ou vencimento no passado) a mais destes dias de hoje, mesmo dentro do permitido: a tela pede para confirmar a data.', 1, N''),
        ('FIN_REGRA_DUPLIC_DOCUMENTO', N'BLOQUEIO', 'TEXTO',
         N'Mesmo parceiro e mesmo número de documento já lançado (no mesmo tipo, a pagar ou a receber). Vale para documento com número.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_DUPLIC_VALOR', N'AVISO', 'TEXTO',
         N'Possível duplicidade: mesmo parceiro, mesmo valor de parcela e vencimento próximo (dias em FIN_DUPLIC_VALOR_DIAS).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_DUPLIC_VALOR_DIAS', N'5', 'INTEIRO',
         N'Diferença de dias no vencimento para considerar possível duplicidade.', 1, N''),
        ('FIN_REGRA_VALOR_FORA_PADRAO', N'AVISO', 'TEXTO',
         N'Valor fora do padrão: maior que FIN_VALOR_FORA_PADRAO_VEZES vezes a média dos lançamentos do mesmo parceiro e conta do plano.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_VALOR_FORA_PADRAO_VEZES', N'3', 'DECIMAL',
         N'Quantas vezes acima da média o valor precisa estar para o aviso de valor fora do padrão.', 1, N''),
        ('FIN_VALOR_FORA_PADRAO_MIN_HIST', N'3', 'INTEIRO',
         N'Quantos lançamentos anteriores (mesmo parceiro e conta) são necessários para calcular a média do valor fora do padrão.', 1, N''),
        ('FIN_VALOR_FORA_PADRAO_MESES', N'12', 'INTEIRO',
         N'Quantos meses para trás entram na média do valor fora do padrão.', 1, N''),
        ('FIN_REGRA_VENC_ANTES_EMISSAO', N'AVISO', 'TEXTO',
         N'Vencimento de alguma parcela antes da data de emissão do documento.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_COMPETENCIA_DISTANTE', N'AVISO', 'TEXTO',
         N'Mês de competência distante do mês de emissão (mais que FIN_COMPETENCIA_MESES meses).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_COMPETENCIA_MESES', N'3', 'INTEIRO',
         N'Diferença máxima, em meses, entre a competência e a emissão antes do aviso.', 1, N''),
        ('FIN_REGRA_TIPO_PARCEIRO', N'AVISO', 'TEXTO',
         N'Parceiro sem o tipo Fornecedor (contas a pagar) ou Cliente (contas a receber); o aviso oferece marcar o tipo.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_TIPO_CONTA', N'AVISO', 'TEXTO',
         N'Conta do plano de receita usada em contas a pagar, ou de despesa em contas a receber.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_LISTA_POR_PAGINA', N'100', 'INTEIRO',
         N'Quantas linhas por página nas listas de contas a pagar e a receber.', 1, N''),
        ('FIN_LISTA_DIAS_A_VENCER', N'7', 'INTEIRO',
         N'Quantos dias à frente contam como "a vencer" no contador e no filtro das listas de contas a pagar e a receber.', 1, N''),
        ('FIN_LISTA_SITUACAO_INICIAL', N'EM_ABERTO', 'TEXTO',
         N'Situação já escolhida ao abrir as listas de contas a pagar e a receber (TODAS = sem filtro).', 1, N'EM_ABERTO;VENCIDA;HOJE;A_VENCER;TODAS'),
        ('FIN_LISTA_VISAO_INICIAL', N'PARCELA', 'TEXTO',
         N'Visão ao abrir as listas: PARCELA (uma linha por vencimento) ou LANCAMENTO (uma linha por lançamento).', 1, N'PARCELA;LANCAMENTO'),
        ('FIN_LISTA_OCULTA_CANCELADAS', N'S', 'SN',
         N'S = a situação "Todas" não mostra as parcelas canceladas (aparecem só escolhendo "Cancelada").', 1, N'')
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, NIVEL, OPCOES);

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN, NIVEL_MINIMO, OPCOES)
SELECT c.CHAVE, c.VALOR, c.VALOR, c.TIPO, c.DESCRICAO, m.ID_MODULO, 1, c.NIVEL, c.OPCOES
FROM #CargaParametro c
INNER JOIN SIS.Modulo m ON m.CODIGO = 'FIN'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = c.CHAVE);

UPDATE p
   SET p.NIVEL_MINIMO = c.NIVEL, p.OPCOES = c.OPCOES, p.DESCRICAO = c.DESCRICAO, p.VALOR_PADRAO = c.VALOR
FROM SIS.Parametro p
INNER JOIN #CargaParametro c ON c.CHAVE = p.CHAVE
WHERE p.NIVEL_MINIMO <> c.NIVEL OR p.OPCOES <> c.OPCOES OR p.DESCRICAO <> c.DESCRICAO OR p.VALOR_PADRAO <> c.VALOR;

-- Parâmetros de uso de outras etapas que os dois administradores também alteram
UPDATE p
   SET p.NIVEL_MINIMO = 1
FROM SIS.Parametro p
WHERE p.CHAVE IN ('CENTRO_ENCERRADO_BLOQUEIA')
  AND p.NIVEL_MINIMO <> 1;

DROP TABLE IF EXISTS #CargaParametro;
GO

PRINT N'Pacote 04f2a concluído sem erro.';
GO

SET NOEXEC OFF;
GO
