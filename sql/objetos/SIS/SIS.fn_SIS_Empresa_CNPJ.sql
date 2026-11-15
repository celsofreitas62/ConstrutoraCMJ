/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Empresa_CNPJ]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : CNPJ (14 posições, sem pontuação) da empresa PRINCIPAL da
                licença ativa. Para exibir: SIS.fn_SIS_Mascarar_CPF_CNPJ.
                Sem licença ativa: ''. Nunca NULL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação:
    -- SELECT SIS.fn_SIS_Mascarar_CPF_CNPJ(SIS.fn_SIS_Empresa_CNPJ(), 0);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Empresa_CNPJ] ()
RETURNS VARCHAR(14)
AS
BEGIN
    DECLARE @Cnpj VARCHAR(14);

    SELECT @Cnpj = e.CNPJ
    FROM SIS.Licenca l WITH (NOLOCK)
    INNER JOIN SIS.Licenca_Empresa e WITH (NOLOCK) ON e.ID_LICENCA = l.ID_LICENCA
    WHERE l.ATIVA = 1
      AND e.PRINCIPAL = 1;

    RETURN ISNULL(@Cnpj, '');
END;
GO
