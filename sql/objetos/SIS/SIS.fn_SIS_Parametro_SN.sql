/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_SN]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Liga/desliga (PADRAO_SQL regra 46): 1 se o parâmetro vale "S",
                0 em qualquer outro caso (inclusive inexistente). Assim uma
                rotina nova só age depois de ligada de propósito.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_SN('COBR_REGUA_ATIVA');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_SN] (@Chave VARCHAR(60))
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN UPPER(LTRIM(RTRIM(SIS.fn_SIS_Parametro(@Chave)))) = N'S' THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END;
END;
GO
