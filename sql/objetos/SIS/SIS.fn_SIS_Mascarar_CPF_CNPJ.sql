/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Mascarar_CPF_CNPJ]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Formata CPF (000.000.000-00) e CNPJ (00.000.000/0000-00).
                @Ocultar = 1 esconde parte do CPF para o cliente/LGPD
                (***.456.789-**, PADRAO_EMAIL regra 21); CNPJ é de empresa e
                não é ocultado.
                Aceita o documento com ou sem pontuação e já aceita o CNPJ
                alfanumérico (letras nas 12 primeiras posições).
                Documento com tamanho diferente de 11/14: devolve como veio,
                sem pontuação. NULL vira '' (nunca NULL).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Mascarar_CPF_CNPJ('12345678901', 1);     -- ***.456.789-**
    -- SELECT SIS.fn_SIS_Mascarar_CPF_CNPJ('12345678000195', 0);  -- 12.345.678/0001-95
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Mascarar_CPF_CNPJ] (@Documento VARCHAR(20), @Ocultar BIT)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @D VARCHAR(20) = UPPER(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@Documento, ''))),
                                 '.', ''), '-', ''), '/', ''), ' ', ''));
    SET @Ocultar = ISNULL(@Ocultar, 0);

    IF LEN(@D) = 11 AND @D NOT LIKE '%[^0-9]%'
        RETURN CASE WHEN @Ocultar = 1
                    THEN '***.' + SUBSTRING(@D, 4, 3) + '.' + SUBSTRING(@D, 7, 3) + '-**'
                    ELSE SUBSTRING(@D, 1, 3) + '.' + SUBSTRING(@D, 4, 3) + '.' + SUBSTRING(@D, 7, 3) + '-' + SUBSTRING(@D, 10, 2)
               END;

    IF LEN(@D) = 14 AND @D NOT LIKE '%[^0-9A-Z]%'
        RETURN SUBSTRING(@D, 1, 2) + '.' + SUBSTRING(@D, 3, 3) + '.' + SUBSTRING(@D, 6, 3) + '/' + SUBSTRING(@D, 9, 4) + '-' + SUBSTRING(@D, 13, 2);

    RETURN @D;
END;
GO
