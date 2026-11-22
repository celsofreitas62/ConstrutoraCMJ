/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Na_Lixeira]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : 1 se o registro está na lixeira (P20), 0 se não está. Usada
                pelas procedures das telas para recusar alterar, desativar ou
                escolher um registro que está na lixeira.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Na_Lixeira(N'CAD.Pessoa', 1);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Na_Lixeira] (@Tabela NVARCHAR(256), @IdRegistro BIGINT)
RETURNS BIT
AS
BEGIN
    IF @IdRegistro IS NULL OR ISNULL(@Tabela, N'') = N'' RETURN 0;

    IF EXISTS (SELECT 1 FROM SIS.Lixeira l
               WHERE l.TABELA = @Tabela AND l.ID_REGISTRO = @IdRegistro AND l.SITUACAO = 'LIXEIRA')
        RETURN 1;

    RETURN 0;
END;
GO
