/*******************************************************************************
  Objeto      : [BANCO].[fn_BANCO_Caixa_Recusa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Fechamento de caixa (04g): a conta aceita movimento nesta data?
                Devolve '' quando aceita, ou a mensagem de recusa quando há um
                fechamento FECHADO na conta com data igual ou posterior. Fonte
                única da regra: baixa, estorno, transferência e ajuste chamam.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04g).
  Homologação (LOCAL):
    -- SELECT BANCO.fn_BANCO_Caixa_Recusa(1, '2026-11-26');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [BANCO].[fn_BANCO_Caixa_Recusa] (@IdConta INT, @Data DATE)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @Fechado DATE, @Conta NVARCHAR(100);

    SELECT @Fechado = MAX(f.DT_FECHAMENTO)
    FROM BANCO.Caixa_Fechamento f
    WHERE f.ID_CONTA = @IdConta AND f.SITUACAO = 'FECHADO';

    IF @Fechado IS NULL OR @Data IS NULL OR @Data > @Fechado RETURN N'';

    SELECT @Conta = c.DESCRICAO FROM BANCO.Conta c WHERE c.ID_CONTA = @IdConta;

    RETURN N'O caixa da conta ' + ISNULL(@Conta, N'') + N' está fechado até '
         + CONVERT(NVARCHAR(10), @Fechado, 103) + N': reabra o fechamento para movimentar em '
         + CONVERT(NVARCHAR(10), @Data, 103) + N'.';
END;
GO
