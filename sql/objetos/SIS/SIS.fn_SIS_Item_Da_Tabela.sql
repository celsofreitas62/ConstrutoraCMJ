/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Item_Da_Tabela]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Código da tela (SIS.Item) que mostra a tabela informada
                (coluna TABELAS_DA_TELA); a primeira, se houver mais de uma.
                Devolve '' se nenhuma tela mostrar a tabela. Usada pela lixeira
                e pelo desfazer (P20) para achar a tela, o módulo e a
                permissão de um registro.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Item_Da_Tabela(N'CAD.Plano_Grupo');  -- CAD_PLANO_CONTA
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Item_Da_Tabela] (@Tabela NVARCHAR(256))
RETURNS VARCHAR(40)
AS
BEGIN
    DECLARE @Item VARCHAR(40);

    SELECT TOP 1 @Item = i.CODIGO
    FROM SIS.Item i
    CROSS APPLY STRING_SPLIT(i.TABELAS_DA_TELA, ',') s
    WHERE i.TIPO = 'TELA'
      AND i.ATIVO = 1
      AND LTRIM(RTRIM(s.value)) = LTRIM(RTRIM(ISNULL(@Tabela, N'')))
    ORDER BY i.ID_ITEM;

    RETURN ISNULL(@Item, '');
END;
GO
