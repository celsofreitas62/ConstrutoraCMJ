/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Atual]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Usuário da sessão atual: o que a API gravou no SESSION_CONTEXT
                (chave USUARIO, etapa 02c) ou, na falta, o login do SQL.
                Nunca devolve NULL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

  Homologação:
    -- SELECT SIS.fn_SIS_Usuario_Atual();
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Atual] ()
RETURNS NVARCHAR(100)
AS
BEGIN
    RETURN ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')),
                  ISNULL(CONVERT(NVARCHAR(100), SUSER_SNAME()), N''));
END;
GO
