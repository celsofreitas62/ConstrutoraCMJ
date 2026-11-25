/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Data_Recusa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Trava de datas do financeiro (aprovada em 18/11/2026). Função
                única de validação, usada por todas as gravações do FIN.
                @Campo: EMISSAO, VENCIMENTO ou BAIXA (pagamento, recebimento,
                transferência, movimento bancário). Devolve o motivo da
                recusa, ou vazio quando a data pode. Nunca devolve NULL.
                  - antes do 1º dia do mês atual: recusa, menos até o dia
                    FIN_DIAS_TOLERANCIA_MES_ANTERIOR, quando o mês anterior
                    ainda é aceito;
                  - EMISSAO / BAIXA: no máximo FIN_EMISSAO_DIAS_FUTURO /
                    FIN_BAIXA_DIAS_FUTURO dias no futuro;
                  - VENCIMENTO: até FIN_VENCIMENTO_ANOS_FUTURO anos à frente.
                FIN_TRAVA_DATAS_ATIVA = N desliga tudo. A exceção
                (LANCAR_RETROATIVO, com motivo) fica com quem chama.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

  Homologação (LOCAL):
    -- SELECT FIN.fn_FIN_Data_Recusa('EMISSAO', '2020-01-01'), FIN.fn_FIN_Data_Recusa('VENCIMENTO', '2099-01-01');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Data_Recusa] (@Campo VARCHAR(12), @Data DATE)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Piso DATE, @Teto DATE, @Tolerancia INT, @Futuro INT, @Nome NVARCHAR(30);

    IF @Data IS NULL RETURN N'';
    IF ISNULL(SIS.fn_SIS_Parametro_SN('FIN_TRAVA_DATAS_ATIVA'), 1) = 0 RETURN N'';

    SET @Nome = CASE @Campo WHEN 'EMISSAO' THEN N'de emissão' WHEN 'VENCIMENTO' THEN N'de vencimento' ELSE N'de pagamento' END;
    SET @Tolerancia = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_DIAS_TOLERANCIA_MES_ANTERIOR'), 5);
    SET @Piso = DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1);
    IF DAY(@Hoje) <= @Tolerancia SET @Piso = DATEADD(MONTH, -1, @Piso);

    IF @Data < @Piso
        RETURN N'A data ' + @Nome + N' ' + CONVERT(NVARCHAR(10), @Data, 103) + N' é anterior a '
             + CONVERT(NVARCHAR(10), @Piso, 103) + N' (limite da trava de datas).';

    IF @Campo = 'VENCIMENTO'
    BEGIN
        SET @Teto = DATEADD(YEAR, ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_VENCIMENTO_ANOS_FUTURO'), 35), @Hoje);
        IF @Data > @Teto
            RETURN N'O vencimento ' + CONVERT(NVARCHAR(10), @Data, 103) + N' passa do limite de '
                 + CONVERT(NVARCHAR(10), @Teto, 103) + N' (confira o ano).';
        RETURN N'';
    END;

    SET @Futuro = ISNULL(SIS.fn_SIS_Parametro_Inteiro(CASE WHEN @Campo = 'EMISSAO' THEN 'FIN_EMISSAO_DIAS_FUTURO' ELSE 'FIN_BAIXA_DIAS_FUTURO' END), 0);
    IF @Data > DATEADD(DAY, @Futuro, @Hoje)
        RETURN N'A data ' + @Nome + N' ' + CONVERT(NVARCHAR(10), @Data, 103)
             + CASE WHEN @Futuro = 0 THEN N' não pode ser futura.' ELSE N' passa de ' + CONVERT(NVARCHAR(10), @Futuro) + N' dias no futuro.' END;

    RETURN N'';
END;
GO
