/*******************************************************************************
  Objeto      : [SIS].[SIS_Grupo_Email_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdGrupoEmail NULL) ou altera um grupo de e-mail e a
                lista de destinatários dele.
                @Destinatarios: todos os endereços do grupo, separados por
                ";", "," ou quebra de linha. A lista gravada fica igual à
                informada: endereço novo entra, endereço que saiu é
                excluído (fica na auditoria), endereço desativado volta.
                Recusa com a lista dos endereços inválidos (nada é gravado).
                Código: letras maiúsculas, números e "_" (ex.: FIN_PAGAR);
                não muda depois de criado (as rotinas usam o código).
                Permissão: INCLUIR ou ALTERAR em SIS_GRUPO_EMAIL.
                Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Grupo_Email_Gravar @IdUsuario = 2, @IdGrupoEmail = NULL, @Codigo = 'FIN_PAGAR',
    --      @Nome = N'Contas a pagar', @Destinatarios = N'financeiro@cmj.com.br';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Grupo_Email_Gravar]
    @IdUsuario      INT,
    @IdGrupoEmail   INT           = NULL,
    @Codigo         VARCHAR(30),
    @Nome           NVARCHAR(80),
    @Descricao      NVARCHAR(400) = NULL,
    @Ativo          BIT           = 1,
    @Destinatarios  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Grupo_Email_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Invalidos  NVARCHAR(MAX);
    DECLARE @CodigoAtual VARCHAR(30);
    DECLARE @Lista      TABLE (EMAIL NVARCHAR(256) PRIMARY KEY);

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Nome      = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Ativo     = ISNULL(@Ativo, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_GRUPO_EMAIL', CASE WHEN @IdGrupoEmail IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar grupos de e-mail.';

        IF @Recusa = N'' AND @IdGrupoEmail IS NOT NULL
        BEGIN
            SELECT @CodigoAtual = g.CODIGO FROM SIS.Grupo_Email g WHERE g.ID_GRUPO_EMAIL = @IdGrupoEmail;
            IF @CodigoAtual IS NULL SET @Recusa = N'Grupo não encontrado.';
            ELSE IF @Codigo <> @CodigoAtual SET @Recusa = N'O código do grupo não pode ser mudado (as rotinas usam o código).';
        END;

        IF @Recusa = N'' AND (@Codigo = '' OR LEN(@Codigo) > 30 OR REPLACE(@Codigo, '_', '') LIKE '%[^A-Z0-9]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras maiúsculas sem acento, números e "_" (ex.: FIN_PAGAR).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome do grupo.';
        IF @Recusa = N'' AND @IdGrupoEmail IS NULL AND EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = @Codigo)
            SET @Recusa = N'Já existe um grupo com este código.';

        IF @Recusa = N''
        BEGIN
            INSERT INTO @Lista (EMAIL)
            SELECT DISTINCT LOWER(LTRIM(RTRIM(s.value)))
            FROM STRING_SPLIT(REPLACE(REPLACE(REPLACE(ISNULL(@Destinatarios, N''), NCHAR(13), N';'), NCHAR(10), N';'), N',', N';'), N';') s
            WHERE LTRIM(RTRIM(s.value)) <> N'';

            SELECT @Invalidos = STRING_AGG(CONVERT(NVARCHAR(MAX), l.EMAIL), N'; ')
            FROM @Lista l
            WHERE SIS.fn_SIS_Email_Valido(l.EMAIL) = 0;

            IF ISNULL(@Invalidos, N'') <> N''
                SET @Recusa = LEFT(N'Endereço(s) inválido(s): ' + @Invalidos, 400);
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdGrupoEmail AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdGrupoEmail IS NULL
        BEGIN
            INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Nome, @Descricao, @Ativo, @Usuario);
            SET @IdGrupoEmail = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE g
               SET g.NOME = @Nome, g.DESCRICAO = @Descricao, g.ATIVO = @Ativo,
                   g.DT_ALTERACAO = @Agora, g.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Grupo_Email g
            WHERE g.ID_GRUPO_EMAIL = @IdGrupoEmail
              AND (g.NOME <> @Nome COLLATE Latin1_General_BIN2 OR g.DESCRICAO <> @Descricao COLLATE Latin1_General_BIN2 OR g.ATIVO <> @Ativo);

        DELETE d
        FROM SIS.Grupo_Email_Destinatario d
        WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail
          AND NOT EXISTS (SELECT 1 FROM @Lista l WHERE l.EMAIL = d.EMAIL);

        UPDATE d
           SET d.ATIVO = 1, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Grupo_Email_Destinatario d
        WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail
          AND d.ATIVO = 0;

        INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, USUARIO_CRIACAO)
        SELECT @IdGrupoEmail, l.EMAIL, @Usuario
        FROM @Lista l
        WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = @IdGrupoEmail AND d.EMAIL = l.EMAIL);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Grupo gravado com ' + CAST((SELECT COUNT(*) FROM @Lista) AS NVARCHAR(10)) + N' destinatário(s).' AS NVARCHAR(400)) AS MENSAGEM,
               @IdGrupoEmail AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o grupo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdGrupoEmail AS ID;
    END CATCH;
END;
GO
