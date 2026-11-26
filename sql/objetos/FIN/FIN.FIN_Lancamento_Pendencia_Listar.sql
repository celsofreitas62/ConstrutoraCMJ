/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Pendencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - quadro de pendências da ficha do lançamento: as
                automáticas (calculadas na hora, FIN.fn_FIN_Lancamento_Pendencias)
                e as manuais ativas (abertas e, com @IncluirResolvidas = 1,
                também as resolvidas). Ordem: manuais abertas (por
                previsão), automáticas e, por último, as resolvidas.
                PODE_ALTERAR = 1 na manual aberta quando o usuário tem a ação
                PENDENCIA; PODE_REABRIR na resolvida.
                Permissão: VER em FIN_PAGAR / FIN_RECEBER (conforme o tipo).
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Pendencia_Listar @IdUsuario = 2, @IdLancamento = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Pendencia_Listar]
    @IdUsuario          INT,
    @IdLancamento       BIGINT,
    @IncluirResolvidas  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Tipo  CHAR(1);
    DECLARE @Item  VARCHAR(40);
    DECLARE @Pode  BIT;

    SELECT @Tipo = l.TIPO FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_LANCAMENTO = @IdLancamento;
    SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;

    IF @Tipo IS NULL OR SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
        THROW 50001, N'Você não tem permissão para ver este lançamento.', 1;

    SET @Pode = CASE WHEN SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'PENDENCIA') = 1
                      AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento) = 0 THEN 1 ELSE 0 END;

    SELECT x.ID_LANCAMENTO_PENDENCIA, x.ORIGEM, x.CODIGO, x.DESCRICAO, x.ORIENTACAO, x.SITUACAO, x.BLOQUEIA_BAIXA, x.ATRASADA,
           x.ID_PENDENCIA_TIPO, x.ID_PARCELA, x.PARCELA, x.OBSERVACAO, x.ID_USUARIO_RESPONSAVEL, x.RESPONSAVEL, x.DT_PREVISAO,
           x.DT_RESOLUCAO, x.USUARIO_RESOLUCAO, x.RESOLUCAO, x.DT_CRIACAO, x.USUARIO_CRIACAO,
           CAST(CASE WHEN x.ORIGEM = 'MANUAL' AND x.SITUACAO = 'ABERTA' THEN @Pode ELSE 0 END AS BIT) AS PODE_ALTERAR,
           CAST(CASE WHEN x.ORIGEM = 'MANUAL' AND x.SITUACAO = 'RESOLVIDA' THEN @Pode ELSE 0 END AS BIT) AS PODE_REABRIR
    FROM (
        SELECT CAST(NULL AS BIGINT) AS ID_LANCAMENTO_PENDENCIA, f.ORIGEM, f.CODIGO, f.DESCRICAO, f.ORIENTACAO,
               CAST('ABERTA' AS VARCHAR(10)) AS SITUACAO, f.BLOQUEIA_BAIXA, f.ATRASADA, f.ID_PENDENCIA_TIPO,
               f.ID_PARCELA, ISNULL(CONVERT(NVARCHAR(5), p.NUMERO) + N'/' + CONVERT(NVARCHAR(5), p.QTD_PARCELAS), N'') AS PARCELA,
               CAST(N'' AS NVARCHAR(1000)) AS OBSERVACAO, CAST(NULL AS INT) AS ID_USUARIO_RESPONSAVEL, CAST(N'' AS NVARCHAR(100)) AS RESPONSAVEL,
               CAST(NULL AS DATE) AS DT_PREVISAO, CAST(NULL AS DATETIME2(0)) AS DT_RESOLUCAO, CAST(N'' AS NVARCHAR(100)) AS USUARIO_RESOLUCAO,
               CAST(N'' AS NVARCHAR(1000)) AS RESOLUCAO, CAST(NULL AS DATETIME2(0)) AS DT_CRIACAO, CAST(N'' AS NVARCHAR(100)) AS USUARIO_CRIACAO,
               1 AS ORDEM_GRUPO
        FROM FIN.fn_FIN_Lancamento_Pendencias(@IdLancamento) f
        LEFT JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = f.ID_PARCELA
        WHERE f.ORIGEM = 'AUTOMATICA'

        UNION ALL
        SELECT lp.ID_LANCAMENTO_PENDENCIA, CAST('MANUAL' AS VARCHAR(10)), t.CODIGO, t.DESCRICAO, t.ORIENTACAO,
               lp.SITUACAO, t.BLOQUEIA_BAIXA,
               CAST(CASE WHEN lp.SITUACAO = 'ABERTA' AND lp.DT_PREVISAO < CAST(SYSDATETIME() AS DATE) THEN 1 ELSE 0 END AS BIT),
               lp.ID_PENDENCIA_TIPO, lp.ID_PARCELA,
               ISNULL(CONVERT(NVARCHAR(5), p.NUMERO) + N'/' + CONVERT(NVARCHAR(5), p.QTD_PARCELAS), N''),
               lp.OBSERVACAO, lp.ID_USUARIO_RESPONSAVEL, ISNULL(u.NOME, N''), lp.DT_PREVISAO,
               lp.DT_RESOLUCAO, ISNULL(lp.USUARIO_RESOLUCAO, N''), lp.RESOLUCAO, lp.DT_CRIACAO, lp.USUARIO_CRIACAO,
               CASE WHEN lp.SITUACAO = 'ABERTA' THEN 0 ELSE 2 END
        FROM FIN.Lancamento_Pendencia lp WITH (NOLOCK)
        INNER JOIN FIN.Pendencia_Tipo t WITH (NOLOCK) ON t.ID_PENDENCIA_TIPO = lp.ID_PENDENCIA_TIPO
        LEFT JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = lp.ID_PARCELA
        LEFT JOIN SIS.Usuario u WITH (NOLOCK) ON u.ID_USUARIO = lp.ID_USUARIO_RESPONSAVEL
        WHERE lp.ID_LANCAMENTO = @IdLancamento
          AND lp.ATIVO = 1
          AND (lp.SITUACAO = 'ABERTA' OR ISNULL(@IncluirResolvidas, 1) = 1)
    ) x
    ORDER BY x.ORDEM_GRUPO, CASE WHEN x.DT_PREVISAO IS NULL THEN 1 ELSE 0 END, x.DT_PREVISAO, x.DT_RESOLUCAO DESC, x.CODIGO;
END;
GO
