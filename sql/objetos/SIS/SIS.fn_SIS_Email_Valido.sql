/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Email_Valido]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : 1 se o texto tem formato de UM endereço de e-mail
                (nome@dominio.ext, sem espaço, sem acento, sem dois @, sem
                ".." e sem ponto no começo/fim); 0 caso contrário.
                Não confere se a caixa existe (isso só o envio mostra).
                Caracteres aceitos: letras sem acento, números, . @ _ + -
                (conferidos com REPLACE + '[^A-Za-z0-9]' em BIN2, nunca com
                '_' ou '-' dentro de colchetes; PADRAO_SQL).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Email_Valido(N'financeiro@cmj.com.br'), SIS.fn_SIS_Email_Valido(N'sem arroba');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Email_Valido] (@Email NVARCHAR(256))
RETURNS BIT
AS
BEGIN
    DECLARE @E NVARCHAR(256) = LTRIM(RTRIM(ISNULL(@Email, N'')));
    DECLARE @Arroba INT = CHARINDEX(N'@', @E);

    IF LEN(@E) < 6 OR @Arroba < 2 RETURN 0;
    IF CHARINDEX(N'@', @E, @Arroba + 1) > 0 RETURN 0;
    IF CHARINDEX(N'..', @E) > 0 RETURN 0;
    IF LEFT(@E, 1) = N'.' OR RIGHT(@E, 1) = N'.' RETURN 0;
    IF SUBSTRING(@E, @Arroba - 1, 1) = N'.' OR SUBSTRING(@E, @Arroba + 1, 1) = N'.' RETURN 0;
    IF CHARINDEX(N'.', @E, @Arroba + 2) = 0 RETURN 0;
    IF REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@E, N'.', N''), N'@', N''), N'_', N''), N'+', N''), N'-', N'')
       LIKE N'%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN2 RETURN 0;

    RETURN 1;
END;
GO
