/*******************************************************************************
  Pacote      : 04f2d - movimentacao do Parceiro (resumo por tipo com media mensal) e parametros de uso; banco continua 2.4 ate a 04f2e
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 26/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04f2c já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/FIN/04f2d_Homologacao_Movimentacao.sql e 04f2a.
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
-- Arquivo: sql/objetos/FIN/FIN.FIN_Parceiro_Movimento_Resumo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Parceiro_Movimento_Resumo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Resumo do topo da aba Movimentação da ficha do Parceiro.
                Uma linha por tipo (P = a pagar, R = a receber) que o usuário
                pode ver (VER em FIN_PAGAR / FIN_RECEBER):
                  QTD/VALOR_EM_ABERTO   parcelas abertas ou parciais (saldo)
                  QTD/VALOR_VENCIDAS    das em aberto, vencidas antes de hoje
                  QTD/VALOR_PAGO_12M    baixas dos últimos 12 meses (valor
                                        líquido; estorno entra negativo e
                                        anula a original)
                  MEDIA_MENSAL_12M      VALOR_PAGO_12M / 12 (sugestão (b) da
                                        04f2d: ajuda a perceber valor fora do
                                        padrão)
                  DT_ULTIMO_PAGAMENTO   data da baixa mais recente
                Não conta o que está na lixeira nem lançamento cancelado.
                Sem permissão em nenhum dos dois tipos: THROW 50001.
                Padrão "Listar": THROW 50001 com mensagem amigável em erro.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2d).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Parceiro_Movimento_Resumo @IdUsuario = 2, @IdPessoa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Parceiro_Movimento_Resumo]
    @IdUsuario INT,
    @IdPessoa  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Parceiro_Movimento_Resumo]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje       DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Desde      DATE;
    DECLARE @VeP        BIT;
    DECLARE @VeR        BIT;

    BEGIN TRY
        SET @VeP = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VeR = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        IF @VeP = 0 AND @VeR = 0
            THROW 50001, N'Você não tem permissão para ver a movimentação financeira.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Pessoa WITH (NOLOCK) WHERE ID_PESSOA = @IdPessoa)
            THROW 50001, N'Parceiro não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        SET @Desde = DATEADD(DAY, 1, DATEADD(MONTH, -12, @Hoje));

        ;WITH Tipos AS (
            SELECT t.TIPO
            FROM (VALUES ('P'), ('R')) t (TIPO)
            WHERE (t.TIPO = 'P' AND @VeP = 1) OR (t.TIPO = 'R' AND @VeR = 1)
        ),
        Aberto AS (
            SELECT l.TIPO,
                   COUNT(*)                                                     AS QTD_EM_ABERTO,
                   SUM(p.SALDO)                                                 AS VALOR_EM_ABERTO,
                   SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END)     AS QTD_VENCIDAS,
                   SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN p.SALDO ELSE 0 END) AS VALOR_VENCIDAS
            FROM FIN.Parcela p WITH (NOLOCK)
            INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
            WHERE l.ID_PESSOA = @IdPessoa
              AND l.DT_EXCLUSAO IS NULL
              AND l.SITUACAO = 'ATIVO'
              AND p.SITUACAO IN ('ABERTA', 'PARCIAL')
            GROUP BY l.TIPO
        ),
        Pago AS (
            SELECT l.TIPO,
                   SUM(CASE WHEN b.ID_BAIXA_ESTORNADA IS NULL THEN 1 ELSE -1 END) AS QTD_PAGO_12M,
                   SUM(b.VALOR_LIQUIDO)                                           AS VALOR_PAGO_12M
            FROM FIN.Baixa b WITH (NOLOCK)
            INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
            INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
            WHERE l.ID_PESSOA = @IdPessoa
              AND l.DT_EXCLUSAO IS NULL
              AND b.DT_PAGAMENTO BETWEEN @Desde AND @Hoje
            GROUP BY l.TIPO
        ),
        Ultimo AS (
            SELECT l.TIPO, MAX(b.DT_PAGAMENTO) AS DT_ULTIMO_PAGAMENTO
            FROM FIN.Baixa b WITH (NOLOCK)
            INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
            INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
            WHERE l.ID_PESSOA = @IdPessoa
              AND l.DT_EXCLUSAO IS NULL
              AND b.ID_BAIXA_ESTORNADA IS NULL
            GROUP BY l.TIPO
        )
        SELECT t.TIPO,
               CAST(ISNULL(a.QTD_EM_ABERTO, 0) AS INT)              AS QTD_EM_ABERTO,
               CAST(ISNULL(a.VALOR_EM_ABERTO, 0) AS DECIMAL(18,2))  AS VALOR_EM_ABERTO,
               CAST(ISNULL(a.QTD_VENCIDAS, 0) AS INT)               AS QTD_VENCIDAS,
               CAST(ISNULL(a.VALOR_VENCIDAS, 0) AS DECIMAL(18,2))   AS VALOR_VENCIDAS,
               CAST(ISNULL(g.QTD_PAGO_12M, 0) AS INT)               AS QTD_PAGO_12M,
               CAST(ISNULL(g.VALOR_PAGO_12M, 0) AS DECIMAL(18,2))   AS VALOR_PAGO_12M,
               CAST(ROUND(ISNULL(g.VALOR_PAGO_12M, 0) / 12.0, 2) AS DECIMAL(18,2)) AS MEDIA_MENSAL_12M,
               u.DT_ULTIMO_PAGAMENTO,
               @Desde                                               AS DT_DESDE
        FROM Tipos t
        LEFT JOIN Aberto a ON a.TIPO = t.TIPO
        LEFT JOIN Pago   g ON g.TIPO = t.TIPO
        LEFT JOIN Ultimo u ON u.TIPO = t.TIPO
        ORDER BY t.TIPO
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o resumo da movimentação. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

PRINT N'Pacote 04f2d concluído sem erro.';
GO

SET NOEXEC OFF;
GO
