/*******************************************************************************
  Objeto      : [FIN].[FIN_Agenda_Resumo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Barra de totais e quadros do topo da tela inicial (agenda
                financeira, P03/P04, etapa 04h1), para o período @De a @Ate:
                  - o que o usuário pode fazer (ver pagar e receber, ver
                    totais, exportar, atalhos: incluir conta a pagar e a
                    receber, extrato, fechamento de caixa, transferência);
                  - quantidade e totais D (a pagar), C (a receber) e Saldo
                    (C - D) do período, e o realizado quando a opção está
                    ligada;
                  - "Em atraso": parcelas em aberto vencidas antes de hoje
                    (fora do período escolhido), quantidade e valor;
                  - saldo de hoje nas contas (ativas e que mostram saldo) e
                    saldo previsto no fim do período (saldo de hoje + o que
                    está em aberto de hoje até @Ate; não conta o atraso).
                P04: sem VER_TOTAIS em FIN_AGENDA, todos os valores somados
                voltam NULL (as quantidades continuam). @IncluiRealizado e
                @SaldoAcumulado NULL = preferência do usuário.
                Permissão: VER em FIN_AGENDA. Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Agenda_Resumo @IdUsuario = 2, @De = '2026-11-01', @Ate = '2026-11-30';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Agenda_Resumo]
    @IdUsuario        INT,
    @De               DATE,
    @Ate              DATE,
    @IdEmpresa        INT = NULL,
    @IncluiRealizado  BIT = NULL,
    @SaldoAcumulado   BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Agenda_Resumo]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje         DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @MaxDias      INT;
    DECLARE @VerPagar     BIT;
    DECLARE @VerReceber   BIT;
    DECLARE @VerTotais    BIT;
    DECLARE @SaldoContas  DECIMAL(18,2) = NULL;
    DECLARE @AbertoFuturo DECIMAL(18,2) = 0;
    DECLARE @AtrasoQtdP   INT = 0, @AtrasoQtdR INT = 0;
    DECLARE @AtrasoD      DECIMAL(18,2) = 0, @AtrasoC DECIMAL(18,2) = 0;
    DECLARE @Ontem        DATE;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a agenda financeira.', 1;

        SET @EtapaAtual = 'Período';
        IF @De IS NULL OR @Ate IS NULL
            THROW 50001, N'Informe o período.', 1;
        IF @Ate < @De
            THROW 50001, N'A data final não pode ser antes da inicial.', 1;
        SET @MaxDias = ISNULL(SIS.fn_SIS_Parametro_Inteiro('AGENDA_PERIODO_MAX_DIAS'), 3700);
        IF @MaxDias NOT BETWEEN 31 AND 7400 SET @MaxDias = 3700;
        IF DATEDIFF(DAY, @De, @Ate) + 1 > @MaxDias
            THROW 50001, N'Período longo demais para a agenda. Escolha um período menor.', 1;

        SET @EtapaAtual = 'Permissões e preferências';
        SET @VerPagar   = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VerReceber = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        SET @VerTotais  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER_TOTAIS');
        IF @IncluiRealizado IS NULL
            SET @IncluiRealizado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_INCLUI_REALIZADO') = N'S' THEN 1 ELSE 0 END;
        IF @SaldoAcumulado IS NULL
            SET @SaldoAcumulado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_SALDO_ACUMULADO') = N'S' THEN 1 ELSE 0 END;
        IF @VerTotais = 0 SET @SaldoAcumulado = 0;

        SET @EtapaAtual = 'Em atraso';
        SET @Ontem = DATEADD(DAY, -1, @Hoje);
        SELECT @AtrasoQtdP = ISNULL(SUM(CASE WHEN b.TIPO = 'P' THEN 1 ELSE 0 END), 0),
               @AtrasoQtdR = ISNULL(SUM(CASE WHEN b.TIPO = 'R' THEN 1 ELSE 0 END), 0),
               @AtrasoD    = ISNULL(SUM(b.ABERTO_D), 0),
               @AtrasoC    = ISNULL(SUM(b.ABERTO_C), 0)
        FROM FIN.fn_FIN_Agenda_Base('19000101', @Ontem, @VerPagar, @VerReceber, 0, @IdEmpresa) b
        OPTION (RECOMPILE);

        IF @SaldoAcumulado = 1
        BEGIN
            SET @EtapaAtual = 'Saldo das contas';
            SELECT @SaldoContas = ISNULL(SUM(s.SALDO), 0)
            FROM BANCO.Conta c WITH (NOLOCK)
            CROSS APPLY BANCO.fn_BANCO_Conta_Saldo(c.ID_CONTA, @Hoje) s
            WHERE c.ATIVO = 1
              AND c.MOSTRA_SALDO = 1
              AND c.DT_EXCLUSAO IS NULL
              AND s.TEM_SALDO = 1
              AND (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa);

            -- saldo previsto no fim do período: o que está em aberto de hoje até @Ate
            IF @Ate >= @Hoje
                SELECT @AbertoFuturo = ISNULL(SUM(b.ABERTO_C - b.ABERTO_D), 0)
                FROM FIN.fn_FIN_Agenda_Base(@Hoje, @Ate, @VerPagar, @VerReceber, 0, @IdEmpresa) b
                OPTION (RECOMPILE);
        END;

        SET @EtapaAtual = 'Consulta';
        SELECT @De                                                                          AS DE,
               @Ate                                                                         AS ATE,
               @Hoje                                                                        AS HOJE,
               @VerPagar                                                                    AS VER_PAGAR,
               @VerReceber                                                                  AS VER_RECEBER,
               @VerTotais                                                                   AS VER_TOTAIS,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'EXPORTAR')               AS PODE_EXPORTAR,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'INCLUIR')                 AS PODE_INCLUIR_PAGAR,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'INCLUIR')               AS PODE_INCLUIR_RECEBER,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_EXTRATO', 'VER')                 AS PODE_EXTRATO,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CAIXA', 'VER')                   AS PODE_CAIXA,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_TRANSFERENCIA', 'INCLUIR')       AS PODE_TRANSFERIR,
               CAST(ISNULL(@IncluiRealizado, 0) AS BIT)                                     AS INCLUI_REALIZADO,
               CAST(ISNULL(@SaldoAcumulado, 0) AS BIT)                                      AS SALDO_ACUMULADO,
               CAST(ISNULL(SUM(CASE WHEN b.TIPO = 'P' THEN 1 ELSE 0 END), 0) AS INT)        AS QTD_PAGAR,
               CAST(ISNULL(SUM(CASE WHEN b.TIPO = 'R' THEN 1 ELSE 0 END), 0) AS INT)        AS QTD_RECEBER,
               CAST(ISNULL(SUM(CASE WHEN b.PREVISAO = 1 THEN 1 ELSE 0 END), 0) AS INT)      AS QTD_PREVISAO,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(b.VALOR_D), 0) END AS DECIMAL(18,2))                 AS TOTAL_D,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(b.VALOR_C), 0) END AS DECIMAL(18,2))                 AS TOTAL_C,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(b.VALOR_C - b.VALOR_D), 0) END AS DECIMAL(18,2))     AS SALDO,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(CASE WHEN b.TIPO = 'P' THEN b.REALIZADO ELSE 0 END), 0) END AS DECIMAL(18,2)) AS REALIZADO_D,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(CASE WHEN b.TIPO = 'R' THEN b.REALIZADO ELSE 0 END), 0) END AS DECIMAL(18,2)) AS REALIZADO_C,
               CAST(ISNULL(@AtrasoQtdP, 0) AS INT)                                          AS ATRASO_QTD_PAGAR,
               CAST(ISNULL(@AtrasoQtdR, 0) AS INT)                                          AS ATRASO_QTD_RECEBER,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(@AtrasoD, 0) END AS DECIMAL(18,2)) AS ATRASO_D,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(@AtrasoC, 0) END AS DECIMAL(18,2)) AS ATRASO_C,
               CAST(CASE WHEN @SaldoAcumulado = 1 THEN ISNULL(@SaldoContas, 0) END AS DECIMAL(18,2))                       AS SALDO_CONTAS_HOJE,
               CAST(CASE WHEN @SaldoAcumulado = 1 AND @Ate >= @Hoje THEN ISNULL(@SaldoContas, 0) + ISNULL(@AbertoFuturo, 0) END AS DECIMAL(18,2)) AS SALDO_PREVISTO_FIM
        FROM FIN.fn_FIN_Agenda_Base(@De, @Ate, @VerPagar, @VerReceber, @IncluiRealizado, @IdEmpresa) b
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a agenda. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
