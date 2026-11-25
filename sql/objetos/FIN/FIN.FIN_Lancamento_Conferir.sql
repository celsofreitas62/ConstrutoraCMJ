/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Prévia, só leitura, das proteções contra erro de digitação
                (P17) de um lançamento antes de gravar: a tela mostra os
                bloqueios, os avisos a confirmar e o pedido de motivo (trava de
                datas). Usa a mesma conferência da gravação
                (FIN_Lancamento_Gravar com @SomenteConferir = 1), para as
                regras nunca ficarem diferentes. Não grava nada.
                Devolve 1 linha: SUCESSO (0 = há bloqueio ou dado inválido),
                MENSAGEM, ID, PENDENTE (há aviso ou motivo) e AVISOS (JSON).
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Conferir]
    @IdUsuario           INT,
    @IdLancamento        BIGINT          = NULL,
    @Tipo                CHAR(1)         = NULL,
    @IdCentroCusto       INT             = NULL,
    @IdPessoa            INT             = NULL,
    @IdPlanoConta        INT             = NULL,
    @IdHistoricoPadrao   INT             = NULL,
    @Documento           NVARCHAR(40)    = NULL,
    @DtEmissao           DATE            = NULL,
    @DtCompetencia       DATE            = NULL,
    @Historico           NVARCHAR(200)   = NULL,
    @Observacao          NVARCHAR(2000)  = NULL,
    @ValorTotal          DECIMAL(18,2)   = NULL,
    @Previsao            BIT             = 0,
    @Integracao          VARCHAR(12)     = NULL,
    @Parcelas            NVARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC FIN.FIN_Lancamento_Gravar
         @IdUsuario = @IdUsuario, @IdLancamento = @IdLancamento, @Tipo = @Tipo, @IdCentroCusto = @IdCentroCusto,
         @IdPessoa = @IdPessoa, @IdPlanoConta = @IdPlanoConta, @IdHistoricoPadrao = @IdHistoricoPadrao,
         @Documento = @Documento, @DtEmissao = @DtEmissao, @DtCompetencia = @DtCompetencia, @Historico = @Historico,
         @Observacao = @Observacao, @ValorTotal = @ValorTotal, @Previsao = @Previsao, @Integracao = @Integracao,
         @Parcelas = @Parcelas, @SomenteConferir = 1;
END;
GO
