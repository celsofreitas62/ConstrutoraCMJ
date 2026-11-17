/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Grava a introdução e a lista inteira de itens do comunicado
                (tudo-ou-nada). @ItensJson: [{"id":null|n,"secao":"EM_TESTE",
                "texto":"...","ordem":1}]. Item que sumiu da lista é DESATIVADO
                (nunca apagado). Permissão: ALTERAR em SIS_COMUNICADO. Não gera
                prévia: a tela oferece "Gerar prévia agora".

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comunicado_Gravar @IdUsuario = 2, @IdComunicado = 1, @Introducao = N'Olá', @ItensJson = N'[{"secao":"EM_TESTE","texto":"Teste","ordem":1}]';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Gravar]
    @IdUsuario     INT,
    @IdComunicado  INT,
    @Introducao    NVARCHAR(1000) = NULL,
    @ItensJson     NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        DROP TABLE IF EXISTS #Itens;
        SET @Introducao = LTRIM(RTRIM(ISNULL(@Introducao, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para alterar comunicados.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado c WHERE c.ID_COMUNICADO = @IdComunicado)
            SET @Recusa = N'Comunicado não encontrado.';
        IF @Recusa = N'' AND ISJSON(ISNULL(@ItensJson, N'')) = 0
            SET @Recusa = N'Lista de itens inválida.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
            RETURN;
        END;

        SELECT j.id AS ID_ITEM, UPPER(LTRIM(RTRIM(ISNULL(j.secao, '')))) AS SECAO,
               LTRIM(RTRIM(ISNULL(j.texto, N''))) AS TEXTO, ISNULL(j.ordem, 0) AS ORDEM
        INTO #Itens
        FROM OPENJSON(@ItensJson) WITH (id INT '$.id', secao VARCHAR(15) '$.secao', texto NVARCHAR(400) '$.texto', ordem SMALLINT '$.ordem') j;

        IF EXISTS (SELECT 1 FROM #Itens WHERE SECAO NOT IN ('IMPLANTADO', 'EM_TESTE', 'PROXIMA_FASE'))
            SET @Recusa = N'Seção inválida num dos itens.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens WHERE TEXTO = N'')
            SET @Recusa = N'Há item sem texto. Preencha ou remova a linha.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens WHERE LEN(TEXTO) > 300)
            SET @Recusa = N'Cada item pode ter no máximo 300 caracteres.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Itens i WHERE i.ID_ITEM IS NOT NULL
                                     AND NOT EXISTS (SELECT 1 FROM SIS.Comunicado_Item ci WHERE ci.ID_COMUNICADO_ITEM = i.ID_ITEM AND ci.ID_COMUNICADO = @IdComunicado))
            SET @Recusa = N'Um dos itens não pertence a este comunicado.';
        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Itens;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE c
           SET c.INTRODUCAO = @Introducao, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado c
        WHERE c.ID_COMUNICADO = @IdComunicado AND c.INTRODUCAO <> @Introducao;

        UPDATE ci
           SET ci.SECAO = i.SECAO, ci.TEXTO = i.TEXTO, ci.ORDEM = i.ORDEM, ci.ATIVO = 1,
               ci.DT_ALTERACAO = SYSDATETIME(), ci.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Item ci
        INNER JOIN #Itens i ON i.ID_ITEM = ci.ID_COMUNICADO_ITEM
        WHERE ci.SECAO <> i.SECAO OR ci.TEXTO <> i.TEXTO OR ci.ORDEM <> i.ORDEM OR ci.ATIVO = 0;

        UPDATE ci
           SET ci.ATIVO = 0, ci.DT_ALTERACAO = SYSDATETIME(), ci.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Comunicado_Item ci
        WHERE ci.ID_COMUNICADO = @IdComunicado AND ci.ATIVO = 1
          AND NOT EXISTS (SELECT 1 FROM #Itens i WHERE i.ID_ITEM = ci.ID_COMUNICADO_ITEM);

        INSERT INTO SIS.Comunicado_Item (ID_COMUNICADO, SECAO, TEXTO, ORDEM, USUARIO_CRIACAO)
        SELECT @IdComunicado, i.SECAO, i.TEXTO, i.ORDEM, @Usuario
        FROM #Itens i
        WHERE i.ID_ITEM IS NULL;

        COMMIT TRANSACTION;
        DROP TABLE IF EXISTS #Itens;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Comunicado gravado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Itens;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o comunicado. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@IdComunicado AS BIGINT) AS ID;
    END CATCH;
END;
GO
