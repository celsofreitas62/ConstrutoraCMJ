/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Formatar_Moeda]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Valor em reais no formato brasileiro: "R$ 1.234,56" e
                "-R$ 1.234,56" para negativo. NULL vira "R$ 0,00".
                Usa FORMAT com cultura pt-BR fixa, independente do idioma do
                servidor. O formato "N2" é usado (e não "C") porque o "C" põe
                um espaço especial (não separável) depois do R$.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Formatar_Moeda(1234.56);   -- R$ 1.234,56
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Formatar_Moeda] (@Valor DECIMAL(18,2))
RETURNS NVARCHAR(30)
AS
BEGIN
    DECLARE @V DECIMAL(18,2) = ISNULL(@Valor, 0);

    RETURN CASE WHEN @V < 0 THEN N'-' ELSE N'' END
         + N'R$ '
         + ISNULL(FORMAT(ABS(@V), N'N2', N'pt-BR'), N'0,00');
END;
GO
