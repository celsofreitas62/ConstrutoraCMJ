/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Decimal]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Valor decimal (percentual, taxa) de um parâmetro, em
                DECIMAL(18,6). O valor é gravado com ponto ("2.5"); por
                segurança, vírgula também é aceita na leitura.
                Inexistente, vazio ou inválido: devolve 0 (nunca NULL).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_Decimal('FIN_MULTA_PERCENTUAL');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Decimal] (@Chave VARCHAR(60))
RETURNS DECIMAL(18,6)
AS
BEGIN
    RETURN ISNULL(TRY_CONVERT(DECIMAL(18,6), REPLACE(SIS.fn_SIS_Parametro(@Chave), N',', N'.')), 0);
END;
GO
