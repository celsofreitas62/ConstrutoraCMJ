/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Versao_Numero]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Converte um número de versão ("2.1", "2.10", "1.8.0") num
                inteiro que ordena certo (maior.menor.revisão =
                maior * 1.000.000 + menor * 1.000 + revisão), porque "2.10"
                é maior que "2.9", mas como texto não é. Vazio ou inválido
                devolve 0 (nunca NULL).
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Versao_Numero('2.10'), SIS.fn_SIS_Versao_Numero('2.9'), SIS.fn_SIS_Versao_Numero('');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Versao_Numero] (@Versao VARCHAR(20))
RETURNS INT
AS
BEGIN
    DECLARE @V VARCHAR(21) = LTRIM(RTRIM(ISNULL(@Versao, ''))), @P1 INT = 0, @P2 INT = 0, @P3 INT = 0, @i INT;

    IF @V = '' OR @V LIKE '%[^0-9.]%' OR @V LIKE '.%' RETURN 0;

    SET @i = CHARINDEX('.', @V + '.');
    SET @P1 = ISNULL(TRY_CAST(LEFT(@V, @i - 1) AS INT), 0);
    SET @V = STUFF(@V, 1, @i, '');
    IF @V <> ''
    BEGIN
        SET @i = CHARINDEX('.', @V + '.');
        SET @P2 = ISNULL(TRY_CAST(LEFT(@V, @i - 1) AS INT), 0);
        SET @V = STUFF(@V, 1, @i, '');
    END;
    IF @V <> ''
    BEGIN
        SET @i = CHARINDEX('.', @V + '.');
        SET @P3 = ISNULL(TRY_CAST(LEFT(@V, @i - 1) AS INT), 0);
    END;

    IF @P1 > 2000 OR @P2 > 999 OR @P3 > 999 RETURN 0;
    RETURN @P1 * 1000000 + @P2 * 1000 + @P3;
END;
GO
