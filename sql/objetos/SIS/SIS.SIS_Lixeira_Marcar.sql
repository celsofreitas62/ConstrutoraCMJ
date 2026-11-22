/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Marcar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Manda um registro para a lixeira (P20): confere a
                configuração da tabela, o parâmetro LIXEIRA_ATIVA, se o
                registro existe e não está na lixeira, se nada usa o registro
                (SIS_Lixeira_Referencias) e as travas (mês fechado e trava
                própria); então desativa o registro, preenche DT_EXCLUSAO e
                USUARIO_EXCLUSAO e grava a linha em SIS.Lixeira com o prazo
                (fn_SIS_Lixeira_Dias).
                Recusa = @Mensagem preenchida, sem gravar nada. Quem chama
                cuida da transação. Uso interno (DENY para a API): chamada
                por SIS_Lixeira_Excluir e pelo desfazer de uma inclusão.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Marcar]
    @IdUsuario   INT,
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Item        VARCHAR(40),
    @Motivo      NVARCHAR(400),
    @IdLixeira   BIGINT        OUTPUT,
    @Mensagem    NVARCHAR(400) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ObjId INT = OBJECT_ID(@Tabela, N'U');
    DECLARE @Pk NVARCHAR(128) = SIS.fn_SIS_Tabela_PK(@Tabela);
    DECLARE @Nome NVARCHAR(300), @DescSql NVARCHAR(1000), @Sql NVARCHAR(MAX), @Usuario NVARCHAR(100);
    DECLARE @Existe INT = 0, @Ativo BIT, @JaExcluido BIT, @Descricao NVARCHAR(400), @Qtd INT, @Onde NVARCHAR(400);
    DECLARE @TemAlteracao BIT;

    SET @IdLixeira = NULL;
    SET @Mensagem = N'';

    IF NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela AND c.ATIVO = 1 AND c.PERMITE_LIXEIRA = 1)
       OR @ObjId IS NULL OR @Pk = N''
       OR COL_LENGTH(@Tabela, N'ATIVO') IS NULL OR COL_LENGTH(@Tabela, N'DT_EXCLUSAO') IS NULL OR COL_LENGTH(@Tabela, N'USUARIO_EXCLUSAO') IS NULL
    BEGIN
        SET @Mensagem = N'Este tipo de registro não vai para a lixeira: use Desativar.';
        RETURN;
    END;

    IF SIS.fn_SIS_Parametro_SN('LIXEIRA_ATIVA') = 0
    BEGIN
        SET @Mensagem = N'A lixeira está desligada (parâmetro LIXEIRA_ATIVA): use Desativar.';
        RETURN;
    END;

    SET @Nome = QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId));
    SELECT @DescSql = NULLIF(LTRIM(RTRIM(c.DESCRICAO_SQL)), N'') FROM SIS.Tabela_Config c WHERE c.TABELA = @Tabela;

    SET @Sql = N'SELECT @Existe = 1, @Ativo = t.ATIVO, @JaExcluido = CASE WHEN t.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END, '
             + N'@Descricao = LEFT(CONVERT(NVARCHAR(MAX), ' + ISNULL(@DescSql, N'CAST(t.' + QUOTENAME(@Pk) + N' AS NVARCHAR(30))') + N'), 400) '
             + N'FROM ' + @Nome + N' t WITH (UPDLOCK, HOLDLOCK) WHERE t.' + QUOTENAME(@Pk) + N' = @Id;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Existe INT OUTPUT, @Ativo BIT OUTPUT, @JaExcluido BIT OUTPUT, @Descricao NVARCHAR(400) OUTPUT',
         @Id = @IdRegistro, @Existe = @Existe OUTPUT, @Ativo = @Ativo OUTPUT, @JaExcluido = @JaExcluido OUTPUT, @Descricao = @Descricao OUTPUT;

    IF ISNULL(@Existe, 0) = 0
    BEGIN
        SET @Mensagem = N'Registro não encontrado.';
        RETURN;
    END;

    IF @JaExcluido = 1 OR SIS.fn_SIS_Na_Lixeira(@Tabela, @IdRegistro) = 1
    BEGIN
        SET @Mensagem = N'O registro já está na lixeira.';
        RETURN;
    END;

    EXEC SIS.SIS_Lixeira_Referencias @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Qtd = @Qtd OUTPUT, @Onde = @Onde OUTPUT;
    IF ISNULL(@Qtd, 0) > 0
    BEGIN
        SET @Mensagem = N'Não dá para excluir: o registro é usado em ' + ISNULL(@Onde, N'outro cadastro')
                      + CASE WHEN @Qtd > 1 THEN N' e em mais ' + CAST(@Qtd - 1 AS NVARCHAR(10)) + N' lugar(es)' ELSE N'' END
                      + N'. Use Desativar.';
        RETURN;
    END;

    EXEC SIS.SIS_Tabela_Trava_Conferir @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = 'LIXEIRA', @Mensagem = @Mensagem OUTPUT;
    IF ISNULL(@Mensagem, N'') <> N'' RETURN;
    SET @Mensagem = N'';

    SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    SET @TemAlteracao = CASE WHEN COL_LENGTH(@Tabela, N'DT_ALTERACAO') IS NOT NULL AND COL_LENGTH(@Tabela, N'USUARIO_ALTERACAO') IS NOT NULL THEN 1 ELSE 0 END;

    SET @Sql = N'UPDATE t SET t.ATIVO = 0, t.DT_EXCLUSAO = SYSDATETIME(), t.USUARIO_EXCLUSAO = @Usuario'
             + CASE WHEN @TemAlteracao = 1 THEN N', t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario' ELSE N'' END
             + N' FROM ' + @Nome + N' t WHERE t.' + QUOTENAME(@Pk) + N' = @Id AND t.DT_EXCLUSAO IS NULL;';
    EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Usuario NVARCHAR(100)', @Id = @IdRegistro, @Usuario = @Usuario;

    INSERT INTO SIS.Lixeira (TABELA, ID_REGISTRO, ITEM_CODIGO, DESCRICAO, MOTIVO, ATIVO_ANTES, DT_EXCLUSAO, USUARIO_EXCLUSAO, ID_USUARIO_EXCLUSAO, DT_APAGAR, SITUACAO)
    VALUES (@Tabela, @IdRegistro, ISNULL(NULLIF(@Item, ''), SIS.fn_SIS_Item_Da_Tabela(@Tabela)), ISNULL(@Descricao, N''), ISNULL(@Motivo, N''),
            ISNULL(@Ativo, 1), SYSDATETIME(), ISNULL(@Usuario, N''), @IdUsuario,
            DATEADD(DAY, SIS.fn_SIS_Lixeira_Dias(@Tabela), CAST(SYSDATETIME() AS DATE)), 'LIXEIRA');
    SET @IdLixeira = SCOPE_IDENTITY();
END;
GO
