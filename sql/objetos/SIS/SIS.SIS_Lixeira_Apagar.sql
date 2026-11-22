/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Apagar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Apaga de vez um registro que está na lixeira (P20), com as
                filhas que vão junto (SIS.Tabela_Config.TABELAS_FILHAS).
                Antes confere de novo se nada passou a usar o registro e as
                travas; se algo usar, não apaga e devolve o motivo. A trigger
                de auditoria guarda a cópia completa de tudo o que for apagado.
                Marca a linha da SIS.Lixeira como APAGADO.
                Recusa = @Mensagem preenchida, sem apagar nada. Quem chama
                cuida da transação. Uso interno (DENY para a API): chamada por
                SIS_Lixeira_Esvaziar e SIS_Lixeira_Processar.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Apagar]
    @IdLixeira  BIGINT,
    @Usuario    NVARCHAR(100),
    @Motivo     NVARCHAR(400),
    @Mensagem   NVARCHAR(400) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Tabela NVARCHAR(256), @IdRegistro BIGINT, @ObjId INT, @Pk NVARCHAR(128), @Nome NVARCHAR(300);
    DECLARE @Qtd INT, @Onde NVARCHAR(400), @Sql NVARCHAR(MAX), @Apagados INT;

    SET @Mensagem = N'';

    SELECT @Tabela = l.TABELA, @IdRegistro = l.ID_REGISTRO
    FROM SIS.Lixeira l WITH (UPDLOCK, HOLDLOCK)
    WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA';

    IF @Tabela IS NULL
    BEGIN
        SET @Mensagem = N'O registro não está mais na lixeira.';
        RETURN;
    END;

    SET @ObjId = OBJECT_ID(@Tabela, N'U');
    SET @Pk = SIS.fn_SIS_Tabela_PK(@Tabela);
    IF @ObjId IS NULL OR @Pk = N''
    BEGIN
        SET @Mensagem = N'Tabela do registro não encontrada.';
        RETURN;
    END;
    SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));

    EXEC SIS.SIS_Lixeira_Referencias @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Qtd = @Qtd OUTPUT, @Onde = @Onde OUTPUT;
    IF ISNULL(@Qtd, 0) > 0
    BEGIN
        SET @Mensagem = N'Não foi apagado: o registro passou a ser usado em ' + ISNULL(@Onde, N'outro cadastro') + N'. Recupere-o ou tire o uso antes.';
        RETURN;
    END;

    EXEC SIS.SIS_Tabela_Trava_Conferir @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = 'APAGAR', @Mensagem = @Mensagem OUTPUT;
    IF ISNULL(@Mensagem, N'') <> N'' RETURN;
    SET @Mensagem = N'';

    -- Filhas que vão junto
    SET @Sql = N'';
    SELECT @Sql = @Sql + N'DELETE FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(f.TABELA, N'U'))) + N'.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(f.TABELA, N'U')))
                + N' WHERE ' + QUOTENAME(f.COLUNA) + N' = @Id;' + NCHAR(13) + NCHAR(10)
    FROM (SELECT LEFT(x.v, LEN(x.v) - CHARINDEX(N'.', REVERSE(x.v))) AS TABELA, RIGHT(x.v, CHARINDEX(N'.', REVERSE(x.v)) - 1) AS COLUNA
          FROM SIS.Tabela_Config c
          CROSS APPLY (SELECT LTRIM(RTRIM(s.value)) AS v FROM STRING_SPLIT(c.TABELAS_FILHAS, N',') s) x
          WHERE c.TABELA = @Tabela AND x.v LIKE N'%_._%._%') f
    WHERE OBJECT_ID(f.TABELA, N'U') IS NOT NULL
      AND COL_LENGTH(f.TABELA, f.COLUNA) IS NOT NULL;

    IF @Sql <> N''
        EXEC sys.sp_executesql @Sql, N'@Id BIGINT', @Id = @IdRegistro;

    SET @Sql = N'DELETE FROM ' + @Nome + N' WHERE ' + QUOTENAME(@Pk) + N' = @Id AND DT_EXCLUSAO IS NOT NULL; SET @n = @@ROWCOUNT;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @n INT OUTPUT', @Id = @IdRegistro, @n = @Apagados OUTPUT;

    UPDATE l
       SET l.SITUACAO = 'APAGADO', l.DT_SITUACAO = SYSDATETIME(), l.USUARIO_SITUACAO = ISNULL(@Usuario, N''),
           l.MOTIVO_SITUACAO = LEFT(ISNULL(@Motivo, N'') + CASE WHEN ISNULL(@Apagados, 0) = 0 THEN N' (o registro já não existia)' ELSE N'' END, 400),
           l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = ISNULL(@Usuario, N'')
    FROM SIS.Lixeira l
    WHERE l.ID_LIXEIRA = @IdLixeira AND l.SITUACAO = 'LIXEIRA';
END;
GO
