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
