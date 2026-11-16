/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Emails_Do_Grupo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Endereços ativos de um grupo de e-mail ativo, separados por
                "; ", em ordem alfabética. Nunca devolve NULL: grupo
                inexistente, inativo ou vazio devolve '' (a orquestradora
                registra o motivo e não envia; PADRAO_EMAIL regra 8).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Emails_Do_Grupo('SIS_ALERTA');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Emails_Do_Grupo] (@Grupo VARCHAR(30))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Emails NVARCHAR(MAX);

    SELECT @Emails = STRING_AGG(CONVERT(NVARCHAR(MAX), LTRIM(RTRIM(d.EMAIL))), N'; ') WITHIN GROUP (ORDER BY d.EMAIL)
    FROM SIS.Grupo_Email_Destinatario d
    INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = d.ID_GRUPO_EMAIL
    WHERE g.CODIGO = @Grupo
      AND g.ATIVO = 1
      AND d.ATIVO = 1
      AND LTRIM(RTRIM(ISNULL(d.EMAIL, N''))) <> N'';

    RETURN ISNULL(@Emails, N'');
END;
GO
