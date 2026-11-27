/*******************************************************************************
  Objeto      : [FIN].[FIN_Baixa_Preparar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Janela de baixa (04g): dados das parcelas escolhidas para a
                data de pagamento, com a sugestão de juros, multa e limite de
                desconto (FIN.fn_FIN_Baixa_Sugerir), a pendência que bloqueia
                (FIN.fn_FIN_Pendencia_Bloqueia), a conta prevista e o que o
                usuário pode fazer (liberar pendência, desconto acima do
                limite, data fora da trava). Só leitura.
                @Parcelas: IDs separados por vírgula. @DtPagamento NULL = hoje.
                Permissão: BAIXAR em FIN_PAGAR / FIN_RECEBER (parcelas de tipo
                sem permissão não aparecem; nenhuma = erro 50001).
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).
    v1.1 (27/11/2026) - Etapa 04g3: ID_CONTA_SUGERIDA (conta prevista da
                        parcela; senão a conta padrão da empresa; só conta
                        ativa) e FORMA_PADRAO (parâmetro FIN_BAIXA_FORMA_PADRAO)
                        para a janela de baixa já vir preenchida.
  Homologação (LOCAL):
    -- EXEC FIN.FIN_Baixa_Preparar @IdUsuario = 2, @Parcelas = N'1,2', @DtPagamento = '2026-11-26';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Baixa_Preparar]
    @IdUsuario    INT,
    @Parcelas     NVARCHAR(4000),
    @DtPagamento  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PodeP BIT = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'BAIXAR');
    DECLARE @PodeR BIT = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'BAIXAR');
    SET @DtPagamento = ISNULL(@DtPagamento, CONVERT(DATE, SYSDATETIME()));
    DECLARE @Forma VARCHAR(12) = UPPER(LTRIM(RTRIM(ISNULL(CONVERT(VARCHAR(12), SIS.fn_SIS_Parametro('FIN_BAIXA_FORMA_PADRAO')), ''))));

    IF @PodeP = 0 AND @PodeR = 0
        THROW 50001, N'Você não tem permissão para baixar contas a pagar nem a receber.', 1;

    SELECT p.ID_PARCELA, p.ID_LANCAMENTO, l.TIPO, l.ID_EMPRESA, ISNULL(NULLIF(pe.NOME_FANTASIA, N''), pe.NOME) AS PESSOA,
           l.DOCUMENTO, l.HISTORICO, p.NUMERO, p.QTD_PARCELAS, p.DT_VENCIMENTO, p.VALOR, p.VALOR_BAIXADO, p.SALDO, p.SITUACAO,
           l.SITUACAO AS SITUACAO_LANCAMENTO, l.PREVISAO, p.ID_CONTA_PREVISTA,
           s.DIAS_ATRASO, s.CALCULA, s.MULTA, s.JUROS, s.DESCONTO_LIMITE, s.MULTA_PERC, s.JUROS_PERC, s.CARENCIA,
           b.BLOQUEIA AS BLOQUEIA_BAIXA, b.MOTIVO AS MOTIVO_BLOQUEIO,
           SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE l.TIPO WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'LIBERAR_PENDENCIA') AS PODE_LIBERAR_PENDENCIA,
           SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE l.TIPO WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'DESCONTO_LIMITE') AS PODE_DESCONTO_LIMITE,
           SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE l.TIPO WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'LANCAR_RETROATIVO') AS PODE_RETROATIVO,
           cs.ID_CONTA AS ID_CONTA_SUGERIDA, @Forma AS FORMA_PADRAO
    FROM (SELECT DISTINCT TRY_CONVERT(BIGINT, LTRIM(RTRIM(v.value))) AS ID FROM STRING_SPLIT(@Parcelas, N',') v) x
    INNER JOIN FIN.Parcela p    ON p.ID_PARCELA = x.ID
    INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
    LEFT  JOIN CAD.Pessoa pe    ON pe.ID_PESSOA = l.ID_PESSOA
    CROSS APPLY FIN.fn_FIN_Baixa_Sugerir(p.ID_PARCELA, @DtPagamento, NULL) s
    CROSS APPLY FIN.fn_FIN_Pendencia_Bloqueia(p.ID_LANCAMENTO, p.ID_PARCELA) b
    LEFT  JOIN CAD.Empresa e    ON e.ID_EMPRESA = l.ID_EMPRESA
    OUTER APPLY (SELECT TOP (1) c.ID_CONTA
                 FROM BANCO.Conta c WITH (NOLOCK)
                 WHERE c.ATIVO = 1 AND c.DT_EXCLUSAO IS NULL
                   AND c.ID_CONTA IN (p.ID_CONTA_PREVISTA, e.ID_CONTA_BANCARIA_PADRAO)
                 ORDER BY CASE WHEN c.ID_CONTA = p.ID_CONTA_PREVISTA THEN 0 ELSE 1 END) cs
    WHERE (l.TIPO = 'P' AND @PodeP = 1) OR (l.TIPO = 'R' AND @PodeR = 1)
    ORDER BY p.DT_VENCIMENTO, pe.NOME, p.NUMERO;
END;
GO
