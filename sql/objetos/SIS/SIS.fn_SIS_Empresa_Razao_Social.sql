/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Empresa_Razao_Social]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Razão social da empresa PRINCIPAL da licença ativa (rodapé de
                e-mail, cabeçalho de relatório). Vem da licença assinada:
                ninguém altera por tela. Sem licença ativa: ''. Nunca NULL.
                Substitui o parâmetro EMPRESA_RAZAO_SOCIAL dos gabaritos.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação:
    -- SELECT SIS.fn_SIS_Empresa_Razao_Social();
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Empresa_Razao_Social] ()
RETURNS NVARCHAR(150)
AS
BEGIN
    DECLARE @Razao NVARCHAR(150);

    SELECT @Razao = e.RAZAO_SOCIAL
    FROM SIS.Licenca l WITH (NOLOCK)
    INNER JOIN SIS.Licenca_Empresa e WITH (NOLOCK) ON e.ID_LICENCA = l.ID_LICENCA
    WHERE l.ATIVA = 1
      AND e.PRINCIPAL = 1;

    RETURN ISNULL(@Razao, N'');
END;
GO
