/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Inteiro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Valor inteiro de um parâmetro. Inexistente, vazio ou inválido:
                devolve 0 (nunca NULL). Quem chama decide o que fazer com 0
                (ex.: aplicar um mínimo de segurança).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_Inteiro('SENHA_TAMANHO_MINIMO');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Inteiro] (@Chave VARCHAR(60))
RETURNS INT
AS
BEGIN
    RETURN ISNULL(TRY_CONVERT(INT, SIS.fn_SIS_Parametro(@Chave)), 0);
END;
GO
