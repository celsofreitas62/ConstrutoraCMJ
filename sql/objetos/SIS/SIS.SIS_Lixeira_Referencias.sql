/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Referencias]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Conta onde um registro é usado, para saber se pode ir para a
                lixeira e se pode ser apagado de vez (P20). Lê as chaves
                estrangeiras do próprio banco (nada fixo no código):
                  - linhas de outras tabelas que apontam para o registro,
                    menos as tabelas filhas que "vão junto"
                    (SIS.Tabela_Config.TABELAS_FILHAS);
                  - linhas que apontam para as filhas deste registro;
                  - anexos ativos (SIS.Anexo) do registro.
                @Qtd = total de usos; @Onde = nome da tela (ou tabela) do
                primeiro uso encontrado. Uso interno (DENY para a API).
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- DECLARE @q INT, @o NVARCHAR(400);
    -- EXEC SIS.SIS_Lixeira_Referencias @Tabela = N'CAD.Empresa', @IdRegistro = 1, @Qtd = @q OUTPUT, @Onde = @o OUTPUT; SELECT @q, @o;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Referencias]
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Qtd         INT           OUTPUT,
    @Onde        NVARCHAR(400) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ObjId INT = OBJECT_ID(@Tabela, N'U');
    DECLARE @Filhas TABLE (TABELA NVARCHAR(256) NOT NULL, COLUNA NVARCHAR(128) NOT NULL, OBJ INT NULL, PK NVARCHAR(128) NULL);
    DECLARE @Refs   TABLE (ORDEM INT IDENTITY(1,1) NOT NULL, COMANDO NVARCHAR(MAX) NOT NULL, TABELA NVARCHAR(256) NOT NULL);
    DECLARE @i INT = 1, @Total INT, @n BIGINT, @Cmd NVARCHAR(MAX), @TabRef NVARCHAR(256);

    SET @Qtd = 0;
    SET @Onde = N'';
    IF @ObjId IS NULL OR @IdRegistro IS NULL RETURN;

    INSERT INTO @Filhas (TABELA, COLUNA)
    SELECT LEFT(x.v, LEN(x.v) - CHARINDEX(N'.', REVERSE(x.v))), RIGHT(x.v, CHARINDEX(N'.', REVERSE(x.v)) - 1)
    FROM SIS.Tabela_Config c
    CROSS APPLY (SELECT LTRIM(RTRIM(s.value)) AS v FROM STRING_SPLIT(c.TABELAS_FILHAS, N',') s) x
    WHERE c.TABELA = @Tabela
      AND x.v LIKE N'%_._%._%';

    UPDATE f SET f.OBJ = OBJECT_ID(f.TABELA, N'U'), f.PK = SIS.fn_SIS_Tabela_PK(f.TABELA) FROM @Filhas f;
    DELETE FROM @Filhas WHERE OBJ IS NULL OR ISNULL(PK, N'') = N'';

    -- Quem aponta direto para o registro (menos as filhas que vão junto)
    INSERT INTO @Refs (COMANDO, TABELA)
    SELECT N'SELECT @n = COUNT_BIG(*) FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
         + N' WITH (NOLOCK) WHERE ' + QUOTENAME(pc.name) + N' = @Id;',
           OBJECT_SCHEMA_NAME(fk.parent_object_id) + N'.' + OBJECT_NAME(fk.parent_object_id)
    FROM sys.foreign_keys fk
    INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
    INNER JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
    WHERE fk.referenced_object_id = @ObjId
      AND (SELECT COUNT(*) FROM sys.foreign_key_columns x WHERE x.constraint_object_id = fk.object_id) = 1
      AND NOT EXISTS (SELECT 1 FROM @Filhas f WHERE f.OBJ = fk.parent_object_id AND f.COLUNA = pc.name)
    ORDER BY fk.name;

    -- Quem aponta para as filhas deste registro
    INSERT INTO @Refs (COMANDO, TABELA)
    SELECT N'SELECT @n = COUNT_BIG(*) FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id))
         + N' r WITH (NOLOCK) WHERE r.' + QUOTENAME(pc.name) + N' IN (SELECT f.' + QUOTENAME(f.PK)
         + N' FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(f.OBJ)) + N'.' + QUOTENAME(OBJECT_NAME(f.OBJ)) + N' f WITH (NOLOCK) WHERE f.' + QUOTENAME(f.COLUNA) + N' = @Id);',
           OBJECT_SCHEMA_NAME(fk.parent_object_id) + N'.' + OBJECT_NAME(fk.parent_object_id)
    FROM @Filhas f
    INNER JOIN sys.foreign_keys fk ON fk.referenced_object_id = f.OBJ
    INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
    INNER JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
    WHERE (SELECT COUNT(*) FROM sys.foreign_key_columns x WHERE x.constraint_object_id = fk.object_id) = 1
      AND fk.parent_object_id <> @ObjId
    ORDER BY fk.name;

    SELECT @Total = COUNT(*) FROM @Refs;
    WHILE @i <= @Total
    BEGIN
        SELECT @Cmd = r.COMANDO, @TabRef = r.TABELA FROM @Refs r WHERE r.ORDEM = @i;
        SET @n = 0;
        EXEC sys.sp_executesql @Cmd, N'@Id BIGINT, @n BIGINT OUTPUT', @Id = @IdRegistro, @n = @n OUTPUT;
        IF ISNULL(@n, 0) > 0
        BEGIN
            IF @Onde = N''
                SET @Onde = ISNULL((SELECT TOP 1 i.NOME FROM SIS.Item i WHERE i.CODIGO = SIS.fn_SIS_Item_Da_Tabela(@TabRef)), @TabRef);
            SET @Qtd = @Qtd + CAST(@n AS INT);
        END;
        SET @i = @i + 1;
    END;

    -- Anexos ativos do registro
    SELECT @n = COUNT_BIG(*)
    FROM SIS.Anexo a WITH (NOLOCK)
    WHERE a.TABELA_REFERENCIA = @Tabela AND a.ID_REFERENCIA = @IdRegistro AND a.SITUACAO = 'ATIVO';
    IF ISNULL(@n, 0) > 0
    BEGIN
        IF @Onde = N'' SET @Onde = N'anexos';
        SET @Qtd = @Qtd + CAST(@n AS INT);
    END;
END;
GO
