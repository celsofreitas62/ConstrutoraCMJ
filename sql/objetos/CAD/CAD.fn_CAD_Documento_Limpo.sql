/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Limpo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : CPF/CNPJ sem pontuação e em maiúsculas (aceita o CNPJ alfanumérico).
                Tira ponto, traço, barra e espaços. Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Documento_Limpo(N'12.abc.345/01de-35');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Limpo] (@Documento NVARCHAR(30))
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN CONVERT(VARCHAR(30), UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@Documento, N''))),
                   N'.', N''), N'-', N''), N'/', N''), N' ', N''), NCHAR(9), N'')));
END;
GO
