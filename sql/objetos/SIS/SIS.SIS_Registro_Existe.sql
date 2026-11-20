/*******************************************************************************
  Objeto      : [SIS].[SIS_Registro_Existe]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Diz se existe o registro @Id (chave primária de uma coluna) na
                tabela @Tabela, que precisa estar entre as TABELAS_DA_TELA do
                item @Item (SIS.fn_SIS_Item_Tem_Tabela); qualquer outra tabela
                devolve 0. Usada por quem precisa conferir um registro de
                tabela variável (ex.: SIS_Anexo_Gravar).
                Roda com a permissão do dono do banco (EXECUTE AS OWNER) porque
                a consulta é montada na hora (SQL dinâmico) e, no servidor, o
                login da API só executa procedures (papel rl_sistemacmj_api):
                sem isso o SELECT seria recusado. O escopo elevado fica só nesta
                consulta; nomes vêm do catálogo e vão com QUOTENAME.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d; achado no ensaio do serviço).

  Homologação (LOCAL e ensaio): sql/testes/SIS/03d_Homologacao_Registro_Existe.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Registro_Existe]
    @Item    VARCHAR(40),
    @Tabela  NVARCHAR(256),
    @Id      BIGINT,
    @Existe  BIT OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ObjId INT, @Pk SYSNAME, @Qtd INT, @Achou INT, @Sql NVARCHAR(MAX);
    SET @Existe = 0;

    IF SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0 OR @Id IS NULL
        RETURN;

    SET @ObjId = OBJECT_ID(@Tabela, N'U');
    SELECT @Pk = MAX(c.name), @Qtd = COUNT(*)
    FROM sys.indexes ix
    INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
    INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

    IF @ObjId IS NULL OR @Pk IS NULL OR @Qtd <> 1
        RETURN;

    SET @Sql = N'SELECT @Achou = 1 FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId))
             + N' WHERE ' + QUOTENAME(@Pk) + N' = @Id;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Achou INT OUTPUT', @Id = @Id, @Achou = @Achou OUTPUT;
    SET @Existe = CASE WHEN @Achou = 1 THEN 1 ELSE 0 END;
END;
GO
