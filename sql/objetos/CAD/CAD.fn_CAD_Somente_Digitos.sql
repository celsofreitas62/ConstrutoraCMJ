/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Somente_Digitos]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Devolve só os dígitos de um texto (telefone, CEP, agência). Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Somente_Digitos(N'(41) 99999-1234');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Somente_Digitos] (@Texto NVARCHAR(400))
RETURNS VARCHAR(400)
AS
BEGIN
    DECLARE @R VARCHAR(400) = '';
    DECLARE @I INT = 1;
    DECLARE @T NVARCHAR(400) = ISNULL(@Texto, N'');
    DECLARE @C NCHAR(1);

    WHILE @I <= LEN(@T)
    BEGIN
        SET @C = SUBSTRING(@T, @I, 1);
        IF @C LIKE N'[0-9]' SET @R = @R + CONVERT(VARCHAR(1), @C);
        SET @I = @I + 1;
    END;

    RETURN @R;
END;
GO
