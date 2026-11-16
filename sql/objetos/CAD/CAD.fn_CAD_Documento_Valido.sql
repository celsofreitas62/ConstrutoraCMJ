/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Valido]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Confere os dígitos verificadores de CPF (11 dígitos) e de CNPJ (14
                posições, aceitando o CNPJ alfanumérico: as 12 primeiras posições
                podem ter letras, valor = código ASCII - 48; os 2 dígitos finais são
                numéricos). Recusa todos os caracteres iguais. Vazio ou outro tamanho
                devolve 0. Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Documento_Valido('529.982.247-25'), CAD.fn_CAD_Documento_Valido('12.ABC.345/01DE-35');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Valido] (@Documento NVARCHAR(30))
RETURNS BIT
AS
BEGIN
    DECLARE @D  VARCHAR(30) = CAD.fn_CAD_Documento_Limpo(@Documento);
    DECLARE @S1 INT;
    DECLARE @S2 INT;
    DECLARE @V1 INT;
    DECLARE @V2 INT;

    IF @D = '' OR REPLACE(@D, LEFT(@D, 1), '') = '' RETURN 0;

    IF LEN(@D) = 11
    BEGIN
        IF @D LIKE '%[^0-9]%' RETURN 0;
        SELECT @S1 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * (11 - v.N)) FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9)) v (N);
        SET @V1 = CASE WHEN @S1 % 11 < 2 THEN 0 ELSE 11 - @S1 % 11 END;
        SELECT @S2 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * (12 - v.N)) FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) v (N);
        SET @V2 = CASE WHEN @S2 % 11 < 2 THEN 0 ELSE 11 - @S2 % 11 END;
        RETURN CASE WHEN @V1 = ASCII(SUBSTRING(@D, 10, 1)) - 48 AND @V2 = ASCII(SUBSTRING(@D, 11, 1)) - 48 THEN 1 ELSE 0 END;
    END;

    IF LEN(@D) = 14
    BEGIN
        IF LEFT(@D, 12) LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2 OR RIGHT(@D, 2) LIKE '%[^0-9]%' RETURN 0;
        SELECT @S1 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * CASE WHEN v.N <= 4 THEN 6 - v.N ELSE 14 - v.N END)
        FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) v (N);
        SET @V1 = CASE WHEN @S1 % 11 < 2 THEN 0 ELSE 11 - @S1 % 11 END;
        SELECT @S2 = SUM((ASCII(SUBSTRING(@D, v.N, 1)) - 48) * CASE WHEN v.N <= 5 THEN 7 - v.N ELSE 15 - v.N END)
        FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13)) v (N);
        SET @V2 = CASE WHEN @S2 % 11 < 2 THEN 0 ELSE 11 - @S2 % 11 END;
        RETURN CASE WHEN @V1 = ASCII(SUBSTRING(@D, 13, 1)) - 48 AND @V2 = ASCII(SUBSTRING(@D, 14, 1)) - 48 THEN 1 ELSE 0 END;
    END;

    RETURN 0;
END;
GO
