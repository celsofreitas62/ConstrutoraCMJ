/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Banco_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdBanco NULL) ou altera um banco da lista. Código COMPE com
                3 dígitos (único); ISPB com 8 dígitos ou vazio.
                Permissão: INCLUIR ou ALTERAR em BANCO_BANCO. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (16/11/2026) - @Codigo e @Ispb maiores que a coluna: o ISPB digitado
                        com pontos (12.345.678) era cortado em 8 caracteres
                        antes de limpar e virava inválido (achado na homologação).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Banco_Gravar @IdUsuario = 2, @Codigo = '748', @Ispb = '01181521', @Nome = N'Sicredi';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Banco_Gravar]
    @IdUsuario  INT,
    @IdBanco    INT          = NULL,
    @Codigo     VARCHAR(10),
    @Ispb       VARCHAR(20)  = NULL,
    @Nome       NVARCHAR(80),
    @Ativo      BIT          = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Banco_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Codigo = LTRIM(RTRIM(ISNULL(@Codigo, '')));
        SET @Ispb   = CAD.fn_CAD_Somente_Digitos(@Ispb);
        SET @Nome   = LTRIM(RTRIM(ISNULL(@Nome, N'')));
        SET @Ativo  = ISNULL(@Ativo, 1);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_BANCO', CASE WHEN @IdBanco IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar bancos.';
        IF @Recusa = N'' AND @IdBanco IS NOT NULL AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.ID_BANCO = @IdBanco)
            SET @Recusa = N'Banco não encontrado.';
        IF @Recusa = N'' AND (LEN(@Codigo) <> 3 OR @Codigo LIKE '%[^0-9]%')
            SET @Recusa = N'Código do banco inválido: informe os 3 dígitos (ex.: 748).';
        IF @Recusa = N'' AND @Ispb <> '' AND LEN(@Ispb) <> 8
            SET @Recusa = N'ISPB inválido: são 8 dígitos (ou deixe em branco).';
        IF @Recusa = N'' AND @Nome = N''
            SET @Recusa = N'Informe o nome do banco.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.CODIGO = @Codigo AND b.ID_BANCO <> ISNULL(@IdBanco, 0))
            SET @Recusa = N'Já existe um banco com este código.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdBanco IS NULL
        BEGIN
            INSERT INTO BANCO.Banco (CODIGO, ISPB, NOME, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Ispb, @Nome, @Ativo, @Usuario);
            SET @IdBanco = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE b
               SET b.CODIGO = @Codigo, b.ISPB = @Ispb, b.NOME = @Nome, b.ATIVO = @Ativo,
                   b.DT_ALTERACAO = SYSDATETIME(), b.USUARIO_ALTERACAO = @Usuario
            FROM BANCO.Banco b
            WHERE b.ID_BANCO = @IdBanco;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Banco gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o banco. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdBanco AS ID;
    END CATCH;
END;
GO
