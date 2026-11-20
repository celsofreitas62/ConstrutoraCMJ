/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Backup_Limite_Versao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Data e hora em que o banco passou para a versão atual (primeiro
                registro da versão atual em SIS.Versao_Banco). A restauração
                pela tela não pode voltar para antes disso: o banco voltaria
                para a versão anterior e o programa (que exige a versão atual)
                deixaria de funcionar. Sem registro: 01/01/1900. Nunca NULL.
                Achado no ensaio de 20/11/2026 (pedido nº 5 voltou o banco de
                ensaio da 1.6 para a 1.5).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, ensaio da restauração).

  Homologação:
    -- SELECT SIS.fn_SIS_Backup_Limite_Versao();
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Backup_Limite_Versao] ()
RETURNS DATETIME2(0)
AS
BEGIN
    RETURN ISNULL((SELECT MIN(v.DT_INSTALACAO) FROM SIS.Versao_Banco v WHERE v.VERSAO = SIS.fn_SIS_Versao_Banco()),
                  CAST('1900-01-01' AS DATETIME2(0)));
END;
GO
