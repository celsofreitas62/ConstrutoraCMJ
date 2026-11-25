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
