/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Texto_HTML]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Escapa texto livre antes de entrar num HTML (PADRAO_EMAIL
                regra 12): & < > " e apóstrofo. O "&" é trocado primeiro, senão
                as entidades geradas seriam escapadas de novo.
                NULL vira '' (nunca apaga o HTML inteiro).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Texto_HTML(N'<b>A & B</b>');   -- &lt;b&gt;A &amp; B&lt;/b&gt;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Texto_HTML] (@Texto NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    RETURN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@Texto, N''),
               N'&',  N'&amp;'),
               N'<',  N'&lt;'),
               N'>',  N'&gt;'),
               N'"',  N'&quot;'),
               N'''', N'&#39;');
END;
GO
