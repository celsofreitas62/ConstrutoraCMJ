/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Trava_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Trava própria de FIN.Lancamento e FIN.Parcela para a lixeira e
                o desfazer (SIS.Tabela_Config.PROC_VALIDAR, P20). Chamada por
                SIS_Tabela_Trava_Conferir. @Mensagem vazia = pode.
                  - mês fechado da empresa na competência, com conta contábil
                    (pedido 10: só conta marcada como contábil);
                  - LIXEIRA: só lançamento de origem manual, sem baixa (as
                    baixas também barram pela SIS_Lixeira_Referencias);
                  - DESFAZER: recusa se o lançamento (ou a parcela) tem baixa:
                    o que tem pagamento é acertado pela ficha.
                  - origem de outra rotina (venda, compra...): recusa;
                  - LIXEIRA com o usuário da API no contexto: confere EXCLUIR
                    na tela do tipo do lançamento (a pagar ou a receber), já
                    que as duas telas usam as mesmas tabelas.
                Uso interno (DENY para a API).
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Trava_Conferir]
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Operacao    VARCHAR(20),
    @Mensagem    NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdLancamento BIGINT;
    DECLARE @Origem       VARCHAR(15);
    DECLARE @Tipo         CHAR(1);
    DECLARE @IdUsuario    INT = TRY_CONVERT(INT, SESSION_CONTEXT(N'ID_USUARIO'));

    SET @Mensagem = N'';

    IF @Tabela = N'FIN.Parcela'
        SELECT @IdLancamento = p.ID_LANCAMENTO FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdRegistro;
    ELSE
        SET @IdLancamento = @IdRegistro;

    SELECT @Origem = l.ORIGEM, @Tipo = l.TIPO FROM FIN.Lancamento l WHERE l.ID_LANCAMENTO = @IdLancamento;
    IF @Origem IS NULL RETURN;

    IF EXISTS (SELECT 1 FROM FIN.Lancamento l
               INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = l.ID_EMPRESA AND m.MES = l.DT_COMPETENCIA AND m.FECHADO = 1
               INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.CONTABIL = 1
               WHERE l.ID_LANCAMENTO = @IdLancamento)
    BEGIN
        SET @Mensagem = N'O mês do lançamento está fechado (conta contábil).';
        RETURN;
    END;

    IF @Origem NOT IN ('MANUAL', 'MIGRACAO')
    BEGIN
        SET @Mensagem = N'Lançamento gerado por outra rotina (' + CONVERT(NVARCHAR(15), @Origem) + N'): use a tela de origem.';
        RETURN;
    END;

    IF @Operacao = 'LIXEIRA' AND @IdUsuario IS NOT NULL
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'EXCLUIR') = 0
    BEGIN
        SET @Mensagem = N'Você não tem permissão para excluir lançamentos a ' + CASE @Tipo WHEN 'P' THEN N'pagar.' ELSE N'receber.' END;
        RETURN;
    END;

    IF @Operacao = 'LIXEIRA' AND @Origem <> 'MANUAL'
    BEGIN
        SET @Mensagem = N'Só lançamento incluído pela tela vai para a lixeira; os que vieram do Access podem ser cancelados.';
        RETURN;
    END;

    IF @Operacao IN ('LIXEIRA', 'DESFAZER')
       AND EXISTS (SELECT 1 FROM FIN.Baixa b INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA
                   WHERE p.ID_LANCAMENTO = @IdLancamento AND (@Tabela <> N'FIN.Parcela' OR p.ID_PARCELA = @IdRegistro))
    BEGIN
        SET @Mensagem = N'O lançamento tem pagamento ou recebimento: acerte pela ficha (as baixas não são desfeitas por aqui).';
        RETURN;
    END;
END;
GO
