/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Coluna_Tipo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Tipo completo de uma coluna, pronto para CONVERT (ex.:
                NVARCHAR(200), DECIMAL(18,2), DATETIME2(0)). Devolve '' se a
                coluna não existir. Usada pelo desfazer (P20) para devolver ao
                campo o valor guardado em texto na SIS.Auditoria.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Coluna_Tipo(N'CAD.Pessoa', N'NOME');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Coluna_Tipo] (@Tabela NVARCHAR(256), @Coluna NVARCHAR(128))
RETURNS NVARCHAR(128)
AS
BEGIN
    DECLARE @Tipo NVARCHAR(128);

    SELECT @Tipo = UPPER(t.name)
                 + CASE WHEN t.name IN ('varchar', 'char', 'varbinary', 'binary')
                             THEN N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CAST(c.max_length AS NVARCHAR(10)) END + N')'
                        WHEN t.name IN ('nvarchar', 'nchar')
                             THEN N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CAST(c.max_length / 2 AS NVARCHAR(10)) END + N')'
                        WHEN t.name IN ('decimal', 'numeric')
                             THEN N'(' + CAST(c.precision AS NVARCHAR(5)) + N',' + CAST(c.scale AS NVARCHAR(5)) + N')'
                        WHEN t.name IN ('datetime2', 'time', 'datetimeoffset')
                             THEN N'(' + CAST(c.scale AS NVARCHAR(5)) + N')'
                        ELSE N'' END
    FROM sys.columns c
    INNER JOIN sys.types t ON t.system_type_id = c.system_type_id AND t.user_type_id = c.system_type_id
    WHERE c.object_id = OBJECT_ID(LTRIM(RTRIM(ISNULL(@Tabela, N''))), N'U')
      AND c.name = @Coluna;

    RETURN ISNULL(@Tipo, N'');
END;
GO
