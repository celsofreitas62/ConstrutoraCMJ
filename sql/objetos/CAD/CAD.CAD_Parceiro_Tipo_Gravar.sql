/*******************************************************************************
  Objeto      : [CAD].[CAD_Parceiro_Tipo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Inclui (@IdParceiroTipo NULL) ou altera um tipo de parceiro.
                Código: letras, números e "_" (maiúsculas), único. Tipos do
                sistema (SISTEMA = 1): só a descrição e a ordem mudam (código e
                situação não). Desativar um tipo em uso: avisa quantos
                parceiros têm o tipo (eles continuam com ele).
                Permissão: INCLUIR ou ALTERAR em CAD_PARCEIRO_TIPO (desativar
                ou reativar: DESATIVAR). Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Parceiro_Tipo_Gravar @IdUsuario = 2, @Codigo = 'EMPREITEIRO', @Descricao = N'Empreiteiro';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Parceiro_Tipo_Gravar]
    @IdUsuario        INT,
    @IdParceiroTipo   INT           = NULL,
    @Codigo           VARCHAR(20),
    @Descricao        NVARCHAR(60),
    @Ordem            INT           = NULL,
    @Ativo            BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Parceiro_Tipo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @Sistema    BIT           = 0;
    DECLARE @CodigoAtual VARCHAR(20);
    DECLARE @AtivoAtual BIT;
    DECLARE @EmUso      INT           = 0;

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Ativo     = ISNULL(@Ativo, 1);

        SELECT @Sistema = t.SISTEMA, @CodigoAtual = t.CODIGO, @AtivoAtual = t.ATIVO
        FROM CAD.Parceiro_Tipo t WHERE t.ID_PARCEIRO_TIPO = @IdParceiroTipo;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PARCEIRO_TIPO', CASE WHEN @IdParceiroTipo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar tipos de parceiro.';
        IF @Recusa = N'' AND @IdParceiroTipo IS NOT NULL AND @CodigoAtual IS NULL
            SET @Recusa = N'Tipo de parceiro não encontrado.';
        IF @Recusa = N'' AND @IdParceiroTipo IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Parceiro_Tipo', @IdParceiroTipo) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @Sistema = 1 AND @Codigo <> @CodigoAtual
            SET @Recusa = N'O código de um tipo do sistema não pode ser mudado (só a descrição e a ordem).';
        IF @Recusa = N'' AND @Sistema = 1 AND @Ativo = 0
            SET @Recusa = N'Um tipo do sistema não pode ser desativado.';
        IF @Recusa = N'' AND (@Codigo = '' OR @Codigo LIKE '%[^A-Z0-9_]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras sem acento, números e "_" (ex.: EMPREITEIRO).';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = @Codigo AND t.ID_PARCEIRO_TIPO <> ISNULL(@IdParceiroTipo, 0))
            SET @Recusa = N'Já existe um tipo de parceiro com este código (confira também a lixeira).';
        IF @Recusa = N'' AND @IdParceiroTipo IS NOT NULL AND @Ativo <> @AtivoAtual
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PARCEIRO_TIPO', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar tipos de parceiro.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdParceiroTipo AS ID;
            RETURN;
        END;

        IF @IdParceiroTipo IS NOT NULL AND @Ativo = 0 AND @AtivoAtual = 1
            SELECT @EmUso = COUNT(*) FROM CAD.Pessoa_Tipo x WHERE x.ID_PARCEIRO_TIPO = @IdParceiroTipo AND x.ATIVO = 1;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdParceiroTipo IS NULL
        BEGIN
            INSERT INTO CAD.Parceiro_Tipo (CODIGO, DESCRICAO, SISTEMA, ORDEM, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Descricao, 0, ISNULL(@Ordem, 100), @Ativo, @Usuario);
            SET @IdParceiroTipo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE CAD.Parceiro_Tipo
               SET CODIGO = @Codigo, DESCRICAO = @Descricao, ORDEM = ISNULL(@Ordem, ORDEM), ATIVO = @Ativo,
                   DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
             WHERE ID_PARCEIRO_TIPO = @IdParceiroTipo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Tipo de parceiro gravado.'
                    + CASE WHEN @EmUso > 0 THEN N' Atenção: ' + CONVERT(NVARCHAR(10), @EmUso)
                                + N' parceiro(s) continuam com este tipo; ele só não aparece mais para novas marcações.' ELSE N'' END
                    AS NVARCHAR(400)) AS MENSAGEM,
               @IdParceiroTipo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o tipo de parceiro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdParceiroTipo AS ID;
    END CATCH;
END;
GO
