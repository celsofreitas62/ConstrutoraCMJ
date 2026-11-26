/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha do lançamento (Contas a pagar / a receber): dados do
                documento com os nomes do que foi escolhido, as parcelas
                (PARCELAS, JSON, com QTD_BAIXAS e TRAVADA), as baixas (BAIXAS,
                JSON, só consulta até a etapa 04g) e os avisos já confirmados
                (AVISOS_CONFIRMADOS, JSON). Situação para a tela: TEM_BAIXA,
                NA_LIXEIRA, MES_FECHADO, PODE_ALTERAR (permissão + situação +
                origem), PODE_CANCELAR e PODE_EXCLUIR.
                Permissão: VER em FIN_PAGAR / FIN_RECEBER (conforme o tipo).
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
    v1.1 (26/11/2026) - Etapa 04f2c (P27): PENDENCIAS (JSON, as abertas,
                        automáticas e manuais), QTD_PENDENCIAS, PODE_PENDENCIA,
                        BLOQUEIA_BAIXA e MOTIVO_BLOQUEIO (FIN.fn_FIN_Pendencia_Bloqueia).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Obter @IdUsuario = 2, @IdLancamento = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Obter]
    @IdUsuario     INT,
    @IdLancamento  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Tipo       CHAR(1);
    DECLARE @Item       VARCHAR(40);
    DECLARE @TemBaixa   BIT = 0;
    DECLARE @NaLixeira  BIT = 0;
    DECLARE @MesFechado BIT = 0;
    DECLARE @Editavel   BIT = 0;

    BEGIN TRY
        SELECT @Tipo = l.TIPO FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_LANCAMENTO = @IdLancamento;
        IF @Tipo IS NULL
            THROW 50001, N'Lançamento não encontrado.', 1;

        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver este lançamento.', 1;

        SET @EtapaAtual = 'Situação';
        IF EXISTS (SELECT 1 FROM FIN.Baixa b WITH (NOLOCK) INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
                   WHERE p.ID_LANCAMENTO = @IdLancamento)
            SET @TemBaixa = 1;
        SET @NaLixeira = SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento);
        IF EXISTS (SELECT 1 FROM FIN.Lancamento l WITH (NOLOCK)
                   INNER JOIN FIN.Mes_Fechado m  WITH (NOLOCK) ON m.ID_EMPRESA = l.ID_EMPRESA AND m.MES = l.DT_COMPETENCIA AND m.FECHADO = 1
                   INNER JOIN CAD.Plano_Conta pc WITH (NOLOCK) ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.CONTABIL = 1
                   WHERE l.ID_LANCAMENTO = @IdLancamento)
            SET @MesFechado = 1;
        SELECT @Editavel = CASE WHEN l.SITUACAO = 'ATIVO' AND l.ORIGEM IN ('MANUAL', 'MIGRACAO') AND @NaLixeira = 0 AND @MesFechado = 0 THEN 1 ELSE 0 END
        FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_LANCAMENTO = @IdLancamento;

        SET @EtapaAtual = 'Consulta';
        SELECT l.ID_LANCAMENTO, l.TIPO, l.ID_EMPRESA, ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) AS EMPRESA_NOME,
               l.ID_CENTRO_CUSTO, ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'') AS CENTRO_CODIGO, ISNULL(cc.DESCRICAO, N'') AS CENTRO_DESCRICAO,
               l.ID_PESSOA, ISNULL(pe.NOME, N'') AS PESSOA_NOME, ISNULL(pe.CPF_CNPJ, '') AS PESSOA_CPF_CNPJ,
               l.ID_PLANO_CONTA, ISNULL(CONVERT(NVARCHAR(12), v.CODIGO), N'') AS PLANO_CODIGO, ISNULL(v.DESCRICAO, N'') AS PLANO_DESCRICAO,
               ISNULL(CONVERT(VARCHAR(15), v.TIPO), '') AS PLANO_TIPO,
               l.ID_HISTORICO_PADRAO, ISNULL(h.DESCRICAO, N'') AS HISTORICO_PADRAO_DESCRICAO,
               l.DOCUMENTO, l.DT_EMISSAO, l.DT_COMPETENCIA, l.HISTORICO, l.OBSERVACAO, l.VALOR_TOTAL,
               l.ORIGEM, l.ID_ORIGEM, l.ID_LOTE, l.SITUACAO, l.PREVISAO, l.INTEGRACAO,
               l.DT_CANCELAMENTO, ISNULL(l.USUARIO_CANCELAMENTO, N'') AS USUARIO_CANCELAMENTO, l.MOTIVO_CANCELAMENTO,
               l.CODIGO_ACCESS, l.DT_CRIACAO, l.USUARIO_CRIACAO, l.DT_ALTERACAO, ISNULL(l.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO,
               @TemBaixa AS TEM_BAIXA, @NaLixeira AS NA_LIXEIRA, @MesFechado AS MES_FECHADO,
               CAST(CASE WHEN @Editavel = 1 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_ALTERAR,
               CAST(CASE WHEN @Editavel = 1 AND @TemBaixa = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'CANCELAR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_CANCELAR,
               CAST(CASE WHEN @Editavel = 1 AND @TemBaixa = 0 AND l.ORIGEM = 'MANUAL' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'EXCLUIR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_EXCLUIR,
               ISNULL((SELECT p.ID_PARCELA AS id, p.NUMERO AS numero, p.QTD_PARCELAS AS qtdParcelas, p.DT_VENCIMENTO AS vencimento,
                              p.VALOR AS valor, p.VALOR_BAIXADO AS valorBaixado, p.SALDO AS saldo, p.SITUACAO AS situacao,
                              p.ID_CONTA_PREVISTA AS idContaPrevista, ISNULL(c.DESCRICAO, N'') AS contaPrevista, p.ID_LOTE AS idLote,
                              (SELECT COUNT(*) FROM FIN.Baixa b WITH (NOLOCK) WHERE b.ID_PARCELA = p.ID_PARCELA) AS qtdBaixas,
                              CAST(CASE WHEN EXISTS (SELECT 1 FROM FIN.Baixa b WITH (NOLOCK) WHERE b.ID_PARCELA = p.ID_PARCELA) THEN 1 ELSE 0 END AS BIT) AS travada
                       FROM FIN.Parcela p WITH (NOLOCK)
                       LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = p.ID_CONTA_PREVISTA
                       WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO
                       ORDER BY p.NUMERO
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS PARCELAS,
               ISNULL((SELECT b.ID_BAIXA AS id, p.NUMERO AS parcela, b.DT_PAGAMENTO AS data, b.ID_CONTA AS idConta, c.DESCRICAO AS conta,
                              b.FORMA AS forma, b.VALOR_PRINCIPAL AS principal, b.JUROS AS juros, b.MULTA AS multa, b.CORRECAO AS correcao,
                              b.DESCONTO AS desconto, b.ABATIMENTO AS abatimento, b.TARIFA AS tarifa, b.RETENCAO AS retencao,
                              b.VALOR_LIQUIDO AS liquido, b.COMPENSADO AS compensado, b.DT_COMPENSACAO AS dataCompensacao,
                              b.ID_BAIXA_ESTORNADA AS idBaixaEstornada,
                              CAST(CASE WHEN EXISTS (SELECT 1 FROM FIN.Baixa x WITH (NOLOCK) WHERE x.ID_BAIXA_ESTORNADA = b.ID_BAIXA) THEN 1 ELSE 0 END AS BIT) AS estornada,
                              b.OBSERVACAO AS observacao, b.USUARIO_CRIACAO AS usuario
                       FROM FIN.Baixa b WITH (NOLOCK)
                       INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
                       INNER JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = b.ID_CONTA
                       WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO
                       ORDER BY b.DT_PAGAMENTO, b.ID_BAIXA
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS BAIXAS,
               ISNULL((SELECT a.CODIGO_REGRA AS codigo, a.NIVEL AS nivel, a.MENSAGEM AS mensagem, a.MOTIVO AS motivo,
                              a.ID_REFERENCIA AS idReferencia, a.USUARIO_CRIACAO AS usuario, a.DT_CRIACAO AS data
                       FROM SIS.Aviso_Confirmado a WITH (NOLOCK)
                       WHERE a.TABELA = N'FIN.Lancamento' AND a.ID_REGISTRO = l.ID_LANCAMENTO
                       ORDER BY a.DT_CRIACAO DESC, a.ID_AVISO_CONFIRMADO DESC
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS AVISOS_CONFIRMADOS,
               ISNULL((SELECT pd.ID_LANCAMENTO_PENDENCIA AS id, pd.ORIGEM AS origem, pd.CODIGO AS codigo, pd.DESCRICAO AS descricao,
                              pd.ORIENTACAO AS orientacao, pd.BLOQUEIA_BAIXA AS bloqueiaBaixa, pd.ATRASADA AS atrasada,
                              pd.ID_PARCELA AS idParcela, pd.ID_USUARIO_RESPONSAVEL AS idResponsavel, pd.DT_PREVISAO AS previsao
                       FROM FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) pd
                       ORDER BY CASE pd.ORIGEM WHEN 'MANUAL' THEN 0 ELSE 1 END, pd.DT_PREVISAO, pd.CODIGO
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS PENDENCIAS,
               (SELECT COUNT(*) FROM FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) pc) AS QTD_PENDENCIAS,
               CAST(CASE WHEN @NaLixeira = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'PENDENCIA') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_PENDENCIA,
               bq.BLOQUEIA AS BLOQUEIA_BAIXA, bq.MOTIVO AS MOTIVO_BLOQUEIO
        FROM FIN.Lancamento l WITH (NOLOCK)
        INNER JOIN CAD.Empresa e            WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
        LEFT  JOIN CAD.Centro_Custo cc      WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO
        LEFT  JOIN CAD.Pessoa pe            WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        LEFT  JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = l.ID_PLANO_CONTA
        LEFT  JOIN FIN.Historico_Padrao h   WITH (NOLOCK) ON h.ID_HISTORICO_PADRAO = l.ID_HISTORICO_PADRAO
        CROSS APPLY FIN.fn_FIN_Pendencia_Bloqueia(l.ID_LANCAMENTO, NULL) bq
        WHERE l.ID_LANCAMENTO = @IdLancamento;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o lançamento. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
