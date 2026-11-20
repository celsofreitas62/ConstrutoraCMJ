/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Versão atual do banco (a da instalação mais recente em
                SIS.Versao_Banco). Vazio = banco sem versão registrada.
                Usada pela API ao subir e em /api/saude.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Versao_Banco();
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Versao_Banco] ()
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN ISNULL((SELECT TOP (1) v.VERSAO FROM SIS.Versao_Banco v ORDER BY v.ID_VERSAO_BANCO DESC), '');
END;
GO
