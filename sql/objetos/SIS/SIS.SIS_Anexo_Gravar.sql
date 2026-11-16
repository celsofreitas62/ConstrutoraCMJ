/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Registra um anexo. A API recebe o arquivo, grava em disco com
                nome gerado (GUID + extensão) em ANEXO_PASTA_RAIZ\ano\mês,
                calcula o SHA-256 e então chama esta procedure. Se a procedure
                recusar, a API apaga o arquivo que acabou de gravar.
                Confere:
                  - permissão ALTERAR na tela (@Item) e que a tela mantém a
                    tabela (TABELAS_DA_TELA);
                  - que o registro existe (pela chave primária da tabela);
                  - tipo ativo e extensão aceita pelo tipo;
                  - tamanho até ANEXO_TAMANHO_MAX_MB;
                  - nome do arquivo gerado (só letras, números, "-" e ".");
                  - o mesmo arquivo (hash) ainda não anexado ao registro.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_ANEXO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL): ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Gravar]
    @IdUsuario      INT,
    @Item           VARCHAR(40),
    @Tabela         NVARCHAR(256),
    @IdRegistro     BIGINT,
    @CodigoTipo     VARCHAR(30),
    @NomeOriginal   NVARCHAR(260),
    @NomeArquivo    VARCHAR(100),
    @PastaRelativa  VARCHAR(50),
    @TamanhoBytes   BIGINT,
    @HashSha256     VARBINARY(32),
    @Descricao      NVARCHAR(400) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Anexo_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @IdTipo      INT;
    DECLARE @Extensoes   VARCHAR(200);
    DECLARE @Extensao    VARCHAR(10);
    DECLARE @MaxMb       INT;
    DECLARE @ObjId       INT;
    DECLARE @Pk          SYSNAME;
    DECLARE @Sql         NVARCHAR(1000);
    DECLARE @Existe      INT           = 0;
    DECLARE @IdAnexo     BIGINT;

    BEGIN TRY
        SET @Tabela        = LTRIM(RTRIM(ISNULL(@Tabela, N'')));
        SET @CodigoTipo    = UPPER(LTRIM(RTRIM(ISNULL(@CodigoTipo, ''))));
        SET @NomeOriginal  = LTRIM(RTRIM(ISNULL(@NomeOriginal, N'')));
        SET @NomeArquivo   = LTRIM(RTRIM(ISNULL(@NomeArquivo, '')));
        SET @PastaRelativa = LTRIM(RTRIM(ISNULL(@PastaRelativa, '')));
        SET @Extensao      = LOWER(CASE WHEN CHARINDEX('.', REVERSE(@NomeArquivo)) > 1
                                        THEN RIGHT(@NomeArquivo, CHARINDEX('.', REVERSE(@NomeArquivo)) - 1) ELSE '' END);
        SET @MaxMb         = SIS.fn_SIS_Parametro_Inteiro('ANEXO_TAMANHO_MAX_MB');
        IF @MaxMb < 1 SET @MaxMb = 1;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para anexar arquivos nesta tela.';
        IF @Recusa = N'' AND SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0
            SET @Recusa = N'Esta tela não aceita anexos desse tipo de registro.';

        SELECT @IdTipo = t.ID_ANEXO_TIPO, @Extensoes = t.EXTENSOES
        FROM SIS.Anexo_Tipo t
        WHERE t.CODIGO = @CodigoTipo AND t.ATIVO = 1;

        IF @Recusa = N'' AND @IdTipo IS NULL
            SET @Recusa = N'Escolha um tipo de anexo válido.';
        IF @Recusa = N'' AND (@Extensao = '' OR NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@Extensoes, ',') s WHERE LTRIM(RTRIM(s.value)) = @Extensao))
            SET @Recusa = N'Este tipo de anexo aceita só: ' + CONVERT(NVARCHAR(200), REPLACE(@Extensoes, ',', ', ')) + N'.';
        IF @Recusa = N'' AND (ISNULL(@TamanhoBytes, 0) <= 0 OR @TamanhoBytes > CAST(@MaxMb AS BIGINT) * 1048576)
            SET @Recusa = N'O arquivo precisa ter até ' + CONVERT(NVARCHAR(10), @MaxMb) + N' MB.';
        IF @Recusa = N'' AND (@NomeOriginal = N''
                              OR @NomeArquivo = ''
                              OR REPLACE(REPLACE(@NomeArquivo, '-', ''), '.', '') LIKE '%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN2
                              OR REPLACE(@PastaRelativa, '\', '') LIKE '%[^0-9]%' COLLATE Latin1_General_BIN2
                              OR DATALENGTH(ISNULL(@HashSha256, 0x)) <> 32)
            SET @Recusa = N'Falha técnica no envio do arquivo (nome, pasta ou hash inválido).';

        SET @ObjId = OBJECT_ID(@Tabela, N'U');
        SELECT @Pk = c.name
        FROM sys.indexes ix
        INNER JOIN sys.index_columns ic ON ic.object_id = ix.object_id AND ic.index_id = ix.index_id
        INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ix.object_id = @ObjId AND ix.is_primary_key = 1;

        IF @Recusa = N'' AND (@ObjId IS NULL OR @Pk IS NULL)
            SET @Recusa = N'Registro não encontrado.';

        IF @Recusa = N''
        BEGIN
            SET @EtapaAtual = 'Registro de referência';
            SET @Sql = N'SELECT @Existe = 1 FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId))
                     + N' WHERE ' + QUOTENAME(@Pk) + N' = @Id;';
            EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @Existe INT OUTPUT', @Id = @IdRegistro, @Existe = @Existe OUTPUT;
            IF ISNULL(@Existe, 0) = 0
                SET @Recusa = N'Registro não encontrado.';
        END;

        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM SIS.Anexo a
                                     WHERE a.TABELA_REFERENCIA = @Tabela AND a.ID_REFERENCIA = @IdRegistro
                                       AND a.HASH_SHA256 = @HashSha256 AND a.SITUACAO = 'ATIVO')
            SET @Recusa = N'Este arquivo já está anexado a este registro.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID_ANEXO;
            RETURN;
        END;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';

        INSERT INTO SIS.Anexo (TABELA_REFERENCIA, ID_REFERENCIA, ID_ANEXO_TIPO, NOME_ORIGINAL, NOME_ARQUIVO, PASTA_RELATIVA,
                               EXTENSAO, TAMANHO_BYTES, HASH_SHA256, DESCRICAO, USUARIO_CRIACAO)
        VALUES (@Tabela, @IdRegistro, @IdTipo, @NomeOriginal, @NomeArquivo, @PastaRelativa,
                @Extensao, @TamanhoBytes, @HashSha256, LTRIM(RTRIM(ISNULL(@Descricao, N''))), ISNULL(@Usuario, N''));
        SET @IdAnexo = CAST(SCOPE_IDENTITY() AS BIGINT);

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Arquivo anexado.' AS NVARCHAR(400)) AS MENSAGEM, @IdAnexo AS ID_ANEXO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível registrar o anexo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID_ANEXO;
    END CATCH;
END;
GO
