/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Cor]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Cor de um parâmetro do tipo COR, sempre no formato #RRGGBB,
                pronta para entrar no CSS inline dos e-mails e relatórios.
                Parâmetro inexistente, vazio ou com cor inválida: devolve
                #555555 (cinza neutro), para nunca quebrar o HTML. Nunca NULL.
                Uso: SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL')

  Changelog:
    v1.0 (15/11/2026) - Criação (identidade visual por cliente).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Cor] (@Chave VARCHAR(60))
RETURNS VARCHAR(7)
AS
BEGIN
    DECLARE @Cor VARCHAR(7) = UPPER(LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), SIS.fn_SIS_Parametro(@Chave)))), 7));

    IF LEN(@Cor) = 7 AND @Cor LIKE '#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]' COLLATE Latin1_General_BIN2
        RETURN @Cor;

    RETURN '#555555';
END;
GO
