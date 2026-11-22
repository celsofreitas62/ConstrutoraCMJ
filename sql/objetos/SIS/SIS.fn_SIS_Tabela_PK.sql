/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Tabela_PK]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Nome da coluna da chave primária de uma tabela ('SCHEMA.Tabela').
                Devolve '' se a tabela não existir ou se a chave tiver mais de
                uma coluna. Usada pelo desfazer e pela lixeira (P20).
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Tabela_PK(N'CAD.Pessoa');  -- ID_PESSOA
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Tabela_PK] (@Tabela NVARCHAR(256))
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @ObjId INT = OBJECT_ID(LTRIM(RTRIM(ISNULL(@Tabela, N''))), N'U');
    DECLARE @Pk NVARCHAR(128), @Qtd INT;

    IF @ObjId IS NULL RETURN N'';

    SELECT @Pk = MAX(c.name), @Qtd = COUNT(*)
    FROM sys.indexes ix
    INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
    INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

    IF ISNULL(@Qtd, 0) <> 1 RETURN N'';
    RETURN ISNULL(@Pk, N'');
END;
GO
