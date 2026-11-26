/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Valido]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Confere os dígitos verificadores de CPF (11 dígitos) e de CNPJ (14
                posições, aceitando o CNPJ alfanumérico: as 12 primeiras posições
                podem ter letras, valor = código ASCII - 48; os 2 dígitos finais são
                numéricos). Recusa todos os caracteres iguais. Vazio ou outro tamanho
                devolve 0. Nunca NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (26/11/2026) - Etapa 04f2c: a regra passou para CAD.fn_CAD_Documento_Checar
                        (em linha, rápida em consultas grandes); esta chama aquela.

  Homologação (LOCAL):
    -- SELECT CAD.fn_CAD_Documento_Valido('529.982.247-25'), CAD.fn_CAD_Documento_Valido('12.ABC.345/01DE-35');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Valido] (@Documento NVARCHAR(30))
RETURNS BIT
AS
BEGIN
    RETURN ISNULL((SELECT c.VALIDO FROM CAD.fn_CAD_Documento_Checar(@Documento) c), CAST(0 AS BIT));
END;
GO
