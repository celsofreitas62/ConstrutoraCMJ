/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Formatar_Data]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Data no formato dd/MM/yyyy (estilo 103, independente do idioma
                do servidor). NULL vira '' (nunca NULL); quem monta HTML decide
                se mostra "-" no lugar.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Formatar_Data('2026-12-10');   -- 10/12/2026
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Formatar_Data] (@Data DATE)
RETURNS NVARCHAR(10)
AS
BEGIN
    IF @Data IS NULL RETURN N'';
    RETURN CONVERT(NVARCHAR(10), @Data, 103);
END;
GO
