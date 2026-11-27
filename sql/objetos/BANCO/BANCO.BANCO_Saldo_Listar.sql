/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Saldo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Saldos por conta numa data (tela Bancos › Extrato e saldos,
                etapa 04g2). Por padrão só as contas ativas marcadas "mostra
                saldo"; @Todas = 1 traz também as outras ativas e
                @IncluirInativas = 1 as desativadas. Saldo pela
                BANCO.fn_BANCO_Conta_Saldo (fonte única), disponível = saldo +
                limite, último movimento, movimentos não conciliados (contas
                que conciliam) e, para os tipos de FIN_CAIXA_FECHAMENTO_TIPOS,
                o último fechamento e se está atrasado (movimento em dia
                ainda não fechado há mais de FIN_CAIXA_FECHAMENTO_ATRASO_DIAS
                dias; 0 = não avisa).
                Permissão: VER em BANCO_EXTRATO ou BANCO_CAIXA (recusa por
                THROW 50001).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Saldo_Listar @IdUsuario = 2, @Data = '2026-11-27';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Saldo_Listar]
    @IdUsuario        INT,
    @Data             DATE  = NULL,
    @IdEmpresa        INT   = NULL,
    @Todas            BIT   = 0,
    @IncluirInativas  BIT   = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[BANCO].[BANCO_Saldo_Listar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Permissão';
    DECLARE @Tipos       NVARCHAR(400);
    DECLARE @Atraso      INT;
    DECLARE @Hoje        DATE = CONVERT(DATE, SYSDATETIME());

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_EXTRATO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CAIXA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os saldos das contas.', 1;

        SET @Data   = ISNULL(@Data, @Hoje);
        SET @Tipos  = N',' + REPLACE(UPPER(ISNULL(SIS.fn_SIS_Parametro('FIN_CAIXA_FECHAMENTO_TIPOS'), N'')), N' ', N'') + N',';
        SET @Atraso = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_CAIXA_FECHAMENTO_ATRASO_DIAS'), 1);

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_CONTA, c.ID_EMPRESA, ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) AS EMPRESA,
               c.DESCRICAO, c.TIPO, ISNULL(b.NOME, N'') AS BANCO, c.AGENCIA, c.NUMERO, c.ORDEM, c.ATIVO, c.MOSTRA_SALDO, c.CONCILIA,
               s.SALDO, s.LIMITE_CREDITO, CAST(s.SALDO + s.LIMITE_CREDITO AS DECIMAL(18,2)) AS DISPONIVEL, s.TEM_SALDO,
               ISNULL(CONVERT(VARCHAR(10), s.DT_SALDO_INICIAL, 23), '') AS DT_SALDO_INICIAL,
               ISNULL(CONVERT(VARCHAR(10), um.DT, 23), '') AS DT_ULTIMO_MOVIMENTO,
               CAST(CASE WHEN c.CONCILIA = 1 THEN ISNULL(nc.QTD, 0) ELSE 0 END AS INT) AS QTD_NAO_CONCILIADOS,
               CAST(CASE WHEN CHARINDEX(N',' + c.TIPO + N',', @Tipos) > 0 THEN 1 ELSE 0 END AS BIT) AS USA_FECHAMENTO,
               ISNULL(CONVERT(VARCHAR(10), f.DT_FECHAMENTO, 23), '') AS DT_ULTIMO_FECHAMENTO,
               CAST(CASE WHEN CHARINDEX(N',' + c.TIPO + N',', @Tipos) > 0 AND @Atraso > 0 AND pf.DT IS NOT NULL
                              AND DATEDIFF(DAY, pf.DT, @Hoje) >= @Atraso THEN 1 ELSE 0 END AS BIT) AS FECHAMENTO_ATRASADO,
               ISNULL(CONVERT(VARCHAR(10), pf.DT, 23), '') AS DT_PRIMEIRO_SEM_FECHAR
        FROM BANCO.Conta c WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
        LEFT  JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = c.ID_BANCO
        CROSS APPLY BANCO.fn_BANCO_Conta_Saldo(c.ID_CONTA, @Data) s
        OUTER APPLY (SELECT MAX(m.DT_MOVIMENTO) AS DT FROM BANCO.Movimento m WITH (NOLOCK) WHERE m.ID_CONTA = c.ID_CONTA AND m.DT_MOVIMENTO <= @Data) um
        OUTER APPLY (SELECT COUNT(*) AS QTD FROM BANCO.Movimento m WITH (NOLOCK)
                     WHERE m.ID_CONTA = c.ID_CONTA AND m.CONCILIADO = 0 AND m.SITUACAO = 'ATIVO' AND m.DT_MOVIMENTO <= @Data
                       AND (c.DT_SALDO_INICIAL IS NULL OR m.DT_MOVIMENTO >= c.DT_SALDO_INICIAL)) nc
        OUTER APPLY (SELECT MAX(x.DT_FECHAMENTO) AS DT_FECHAMENTO FROM BANCO.Caixa_Fechamento x WITH (NOLOCK)
                     WHERE x.ID_CONTA = c.ID_CONTA AND x.SITUACAO = 'FECHADO') f
        OUTER APPLY (SELECT MIN(m.DT_MOVIMENTO) AS DT FROM BANCO.Movimento m WITH (NOLOCK)
                     WHERE m.ID_CONTA = c.ID_CONTA AND m.DT_MOVIMENTO < @Hoje
                       AND (f.DT_FECHAMENTO IS NULL OR m.DT_MOVIMENTO > f.DT_FECHAMENTO)
                       AND (c.DT_SALDO_INICIAL IS NULL OR m.DT_MOVIMENTO >= c.DT_SALDO_INICIAL)) pf
        WHERE c.DT_EXCLUSAO IS NULL
          AND (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa)
          AND (c.ATIVO = 1 OR ISNULL(@IncluirInativas, 0) = 1)
          AND (c.MOSTRA_SALDO = 1 OR ISNULL(@Todas, 0) = 1 OR ISNULL(@IncluirInativas, 0) = 1)
        ORDER BY ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL), c.ORDEM, c.DESCRICAO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível listar os saldos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
