/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Regra_Nivel]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Lê o nível de uma regra de proteção contra erro de digitação
                (P17) no parâmetro @Chave: AVISO, BLOQUEIO ou NAO (desligada).
                Valor vazio ou estranho vale AVISO (nunca desliga uma regra
                por engano). Nunca devolve NULL.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Regra_Nivel] (@Chave VARCHAR(60))
RETURNS VARCHAR(12)
AS
BEGIN
    DECLARE @Valor NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro(@Chave), N''))));

    RETURN CASE WHEN @Valor IN (N'AVISO', N'BLOQUEIO', N'NAO') THEN CONVERT(VARCHAR(12), @Valor) ELSE 'AVISO' END;
END;
GO
