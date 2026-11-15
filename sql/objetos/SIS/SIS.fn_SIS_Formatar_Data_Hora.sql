/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Formatar_Data_Hora]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Data e hora no formato dd/MM/yyyy HH:mm (rodapé de e-mail,
                relatórios). NULL vira '' (nunca NULL).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Formatar_Data_Hora('2026-11-15 09:05:33');   -- 15/11/2026 09:05
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Formatar_Data_Hora] (@DataHora DATETIME2(0))
RETURNS NVARCHAR(16)
AS
BEGIN
    IF @DataHora IS NULL RETURN N'';
    RETURN CONVERT(NVARCHAR(10), @DataHora, 103) + N' ' + LEFT(CONVERT(NVARCHAR(8), @DataHora, 108), 5);
END;
GO
