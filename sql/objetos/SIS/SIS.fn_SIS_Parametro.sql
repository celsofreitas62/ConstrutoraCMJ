/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Valor (texto) de um parâmetro de SIS.Parametro.
                Parâmetro inexistente ou chave vazia: devolve '' (nunca NULL).
                Para número e S/N usar as versões tipadas
                (fn_SIS_Parametro_Inteiro, _Decimal, _SN).
                Parâmetro do tipo DATA: ler com esta function e converter com
                TRY_CONVERT(DATE, valor, 23) (não há versão tipada porque uma
                data vazia teria de virar NULL ou uma data sentinela).

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro('EMAIL_TESTE');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro] (@Chave VARCHAR(60))
RETURNS NVARCHAR(4000)
AS
BEGIN
    DECLARE @Valor NVARCHAR(4000);

    SET @Chave = ISNULL(@Chave, '');
    IF @Chave = '' RETURN N'';

    SELECT @Valor = p.VALOR
    FROM SIS.Parametro p WITH (NOLOCK)
    WHERE p.CHAVE = @Chave;

    RETURN ISNULL(@Valor, N'');
END;
GO
