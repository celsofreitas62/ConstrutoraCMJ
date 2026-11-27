/*******************************************************************************
  Objeto      : [FIN].[FIN_Agenda_Periodos]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Calendário da tela inicial (agenda financeira, P03/P04, etapa
                04h1): uma linha por dia, por mês ou por grupo de meses de
                @De a @Ate, inclusive os sem nenhuma conta (para o calendário
                desenhar todos os quadros):
                  @Agrupamento = 'DIA'   : um quadro por dia (semana, quinzena,
                                           mês);
                  @Agrupamento = 'MES'   : um quadro por mês (ano, vários
                                           anos), cortado em @De e @Ate;
                  @Agrupamento = 'MESES' : quadros de @MesesGrupo meses
                                           (bimestre = 2, trimestre = 3,
                                           quadrimestre = 4...), a partir do
                                           mês de @De.
                Por quadro: quantidades a pagar e a receber, quantas estão
                vencidas e em aberto, quantas são previsão, D, C e Saldo
                (C - D) e o SALDO_PREVISTO (saldo de hoje nas contas mais o
                que está em aberto de hoje até o fim do quadro; NULL nos
                quadros que acabam antes de hoje e quando a opção está
                desligada). P04: sem VER_TOTAIS em FIN_AGENDA, todos os
                valores voltam NULL (as quantidades continuam).
                @IncluiRealizado e @SaldoAcumulado NULL = preferência do
                usuário. Permissão: VER em FIN_AGENDA. Padrão "Listar":
                THROW 50001.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Agenda_Periodos @IdUsuario = 2, @De = '2026-11-01', @Ate = '2026-11-30', @Agrupamento = 'DIA';
    -- EXEC FIN.FIN_Agenda_Periodos @IdUsuario = 2, @De = '2026-11-01', @Ate = '2027-04-30', @Agrupamento = 'MESES', @MesesGrupo = 3;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Agenda_Periodos]
    @IdUsuario        INT,
    @De               DATE,
    @Ate              DATE,
    @Agrupamento      VARCHAR(10) = 'DIA',
    @MesesGrupo       INT  = NULL,
    @IdEmpresa        INT  = NULL,
    @IncluiRealizado  BIT  = NULL,
    @SaldoAcumulado   BIT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Agenda_Periodos]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje         DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @MaxDias      INT;
    DECLARE @VerPagar     BIT;
    DECLARE @VerReceber   BIT;
    DECLARE @VerTotais    BIT;
    DECLARE @SaldoContas  DECIMAL(18,2) = 0;
    DECLARE @MesDe        DATE;
    DECLARE @Qtd          INT;

    DECLARE @Quadros TABLE
    (
        ORDEM   INT  NOT NULL PRIMARY KEY,
        INICIO  DATE NOT NULL,
        FIM     DATE NOT NULL
    );

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
        SET @Agrupamento = UPPER(LTRIM(RTRIM(ISNULL(@Agrupamento, 'DIA'))));
        IF @Agrupamento NOT IN ('DIA', 'MES', 'MESES')
            THROW 50001, N'Agrupamento inválido.', 1;
        IF @Agrupamento = 'MESES' AND ISNULL(@MesesGrupo, 0) NOT BETWEEN 1 AND 24
            THROW 50001, N'Informe de 1 a 24 meses por quadro.', 1;

        SET @EtapaAtual = 'Permissões e preferências';
        SET @VerPagar   = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VerReceber = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        SET @VerTotais  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER_TOTAIS');
        IF @IncluiRealizado IS NULL
            SET @IncluiRealizado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_INCLUI_REALIZADO') = N'S' THEN 1 ELSE 0 END;
        IF @SaldoAcumulado IS NULL
            SET @SaldoAcumulado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_SALDO_ACUMULADO') = N'S' THEN 1 ELSE 0 END;
        IF @VerTotais = 0 SET @SaldoAcumulado = 0;

        SET @EtapaAtual = 'Quadros';
        SET @MesDe = DATEFROMPARTS(YEAR(@De), MONTH(@De), 1);
        SET @Qtd   = CASE @Agrupamento
                         WHEN 'DIA' THEN DATEDIFF(DAY, @De, @Ate) + 1
                         WHEN 'MES' THEN DATEDIFF(MONTH, @De, @Ate) + 1
                         ELSE DATEDIFF(MONTH, @De, @Ate) / @MesesGrupo + 1
                     END;

        ;WITH n AS (SELECT TOP (@Qtd) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS INT) AS N
                    FROM sys.all_objects a CROSS JOIN sys.all_objects b)
        INSERT INTO @Quadros (ORDEM, INICIO, FIM)
        SELECT n.N + 1,
               CASE @Agrupamento WHEN 'DIA' THEN DATEADD(DAY, n.N, @De)
                                 WHEN 'MES' THEN CASE WHEN n.N = 0 THEN @De ELSE DATEADD(MONTH, n.N, @MesDe) END
                                 ELSE CASE WHEN n.N = 0 THEN @De ELSE DATEADD(MONTH, n.N * @MesesGrupo, @MesDe) END
               END,
               CASE @Agrupamento WHEN 'DIA' THEN DATEADD(DAY, n.N, @De)
                                 WHEN 'MES' THEN CASE WHEN EOMONTH(DATEADD(MONTH, n.N, @MesDe)) > @Ate THEN @Ate ELSE EOMONTH(DATEADD(MONTH, n.N, @MesDe)) END
                                 ELSE CASE WHEN DATEADD(DAY, -1, DATEADD(MONTH, (n.N + 1) * @MesesGrupo, @MesDe)) > @Ate THEN @Ate
                                           ELSE DATEADD(DAY, -1, DATEADD(MONTH, (n.N + 1) * @MesesGrupo, @MesDe)) END
               END
        FROM n;

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

            -- o que está em aberto entre hoje e o início do período entra no saldo de partida
            IF @De > @Hoje
            BEGIN
                DECLARE @AteAntes DATE = DATEADD(DAY, -1, @De);
                SELECT @SaldoContas = @SaldoContas + ISNULL(SUM(b.ABERTO_C - b.ABERTO_D), 0)
                FROM FIN.fn_FIN_Agenda_Base(@Hoje, @AteAntes, @VerPagar, @VerReceber, 0, @IdEmpresa) b
                OPTION (RECOMPILE);
            END;
        END;

        SET @EtapaAtual = 'Consulta';
        ;WITH soma AS
        (
            SELECT q.ORDEM,
                   ISNULL(SUM(CASE WHEN b.TIPO = 'P' THEN 1 ELSE 0 END), 0)                                     AS QTD_PAGAR,
                   ISNULL(SUM(CASE WHEN b.TIPO = 'R' THEN 1 ELSE 0 END), 0)                                     AS QTD_RECEBER,
                   ISNULL(SUM(CASE WHEN b.ABERTO > 0 AND b.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END), 0)         AS QTD_VENCIDAS,
                   ISNULL(SUM(CASE WHEN b.PREVISAO = 1 THEN 1 ELSE 0 END), 0)                                   AS QTD_PREVISAO,
                   ISNULL(SUM(b.VALOR_D), 0)                                                    AS TOTAL_D,
                   ISNULL(SUM(b.VALOR_C), 0)                                                    AS TOTAL_C,
                   ISNULL(SUM(CASE WHEN b.DT_VENCIMENTO >= @Hoje THEN b.ABERTO_C - b.ABERTO_D ELSE 0 END), 0) AS LIQUIDO_FUTURO
            FROM @Quadros q
            LEFT JOIN (SELECT x.*,
                              CASE @Agrupamento WHEN 'DIA' THEN DATEDIFF(DAY, @De, x.DT_VENCIMENTO)
                                                WHEN 'MES' THEN DATEDIFF(MONTH, @De, x.DT_VENCIMENTO)
                                                ELSE DATEDIFF(MONTH, @De, x.DT_VENCIMENTO) / @MesesGrupo END + 1 AS ORDEM_QUADRO
                       FROM FIN.fn_FIN_Agenda_Base(@De, @Ate, @VerPagar, @VerReceber, @IncluiRealizado, @IdEmpresa) x) b
                   ON b.ORDEM_QUADRO = q.ORDEM
            GROUP BY q.ORDEM
        )
        SELECT q.ORDEM,
               q.INICIO,
               q.FIM,
               CAST(CASE WHEN @Hoje BETWEEN q.INICIO AND q.FIM THEN 1 ELSE 0 END AS BIT)  AS TEM_HOJE,
               CAST(s.QTD_PAGAR AS INT)                                                   AS QTD_PAGAR,
               CAST(s.QTD_RECEBER AS INT)                                                 AS QTD_RECEBER,
               CAST(s.QTD_VENCIDAS AS INT)                                                AS QTD_VENCIDAS,
               CAST(s.QTD_PREVISAO AS INT)                                                AS QTD_PREVISAO,
               CAST(CASE WHEN @VerTotais = 1 THEN s.TOTAL_D END AS DECIMAL(18,2))                 AS TOTAL_D,
               CAST(CASE WHEN @VerTotais = 1 THEN s.TOTAL_C END AS DECIMAL(18,2))                 AS TOTAL_C,
               CAST(CASE WHEN @VerTotais = 1 THEN s.TOTAL_C - s.TOTAL_D END AS DECIMAL(18,2))     AS SALDO,
               CAST(CASE WHEN @SaldoAcumulado = 1 AND q.FIM >= @Hoje
                         THEN @SaldoContas + SUM(s.LIQUIDO_FUTURO) OVER (ORDER BY q.ORDEM ROWS UNBOUNDED PRECEDING) END AS DECIMAL(18,2)) AS SALDO_PREVISTO
        FROM @Quadros q
        INNER JOIN soma s ON s.ORDEM = q.ORDEM
        ORDER BY q.ORDEM
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o calendário da agenda. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
