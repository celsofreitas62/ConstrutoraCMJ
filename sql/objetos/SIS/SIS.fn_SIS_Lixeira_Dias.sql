/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Lixeira_Dias]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Prazo da lixeira, em dias, para a tabela informada: o prazo
                próprio da tela (SIS.Tabela_Config.DIAS_GUARDA) ou, sem ele, o
                parâmetro LIXEIRA_DIAS_GUARDA. Nunca menos de 1 dia.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Lixeira_Dias(N'CAD.Pessoa');  -- 90
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Lixeira_Dias] (@Tabela NVARCHAR(256))
RETURNS INT
AS
BEGIN
    DECLARE @Dias INT;

    SELECT @Dias = c.DIAS_GUARDA FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela;
    SET @Dias = ISNULL(@Dias, SIS.fn_SIS_Parametro_Inteiro('LIXEIRA_DIAS_GUARDA'));

    RETURN CASE WHEN ISNULL(@Dias, 0) < 1 THEN 1 ELSE @Dias END;
END;
GO
