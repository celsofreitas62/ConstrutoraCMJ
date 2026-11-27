/*******************************************************************************
  Objeto      : [SIS].[SIS_Preferencia_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Grava as preferências do usuário logado (tela Preferências;
                P03 e P06), várias de uma vez:
                  @Preferencias = '[{"codigo":"TEMA","valor":"ESCURO"},
                                    {"codigo":"INICIO_VISAO","valor":""}]'
                Valor vazio = volta ao padrão (apaga a escolha). Confere cada
                valor pelo TIPO, pelas OPCOES e pela faixa (VALOR_MINIMO /
                VALOR_MAXIMO) do catálogo; um valor inválido recusa tudo
                (tudo-ou-nada). Só o próprio usuário grava as dele.
                Resposta (regra 18): SUCESSO, MENSAGEM, QTD_GRAVADAS.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Preferencia_Gravar @IdUsuario = 2, @Preferencias = N'[{"codigo":"TEMA","valor":"ESCURO"}]';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Preferencia_Gravar]
    @IdUsuario     INT,
    @Preferencias  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Preferencia_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Recusa     NVARCHAR(400);
    DECLARE @Qtd        INT = 0;

    DECLARE @Itens TABLE
    (
        CODIGO          VARCHAR(40)   NOT NULL,
        VALOR           NVARCHAR(400) NOT NULL,
        ID_PREFERENCIA  INT           NULL,
        NOME            NVARCHAR(80)  NULL,
        TIPO            VARCHAR(10)   NULL,
        OPCOES          NVARCHAR(400) NULL,
        VALOR_MINIMO    INT           NULL,
        VALOR_MAXIMO    INT           NULL
    );

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Usuário não encontrado ou desativado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;
        SET @Preferencias = LTRIM(RTRIM(ISNULL(@Preferencias, N'')));
        IF @Preferencias = N'' OR ISJSON(@Preferencias) = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Nenhuma preferência informada.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;

        INSERT INTO @Itens (CODIGO, VALOR)
        SELECT UPPER(LTRIM(RTRIM(ISNULL(j.codigo, '')))), LTRIM(RTRIM(ISNULL(j.valor, N'')))
        FROM OPENJSON(@Preferencias) WITH (codigo VARCHAR(40) '$.codigo', valor NVARCHAR(400) '$.valor') j;

        IF NOT EXISTS (SELECT 1 FROM @Itens)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Nenhuma preferência informada.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;
        IF EXISTS (SELECT 1 FROM @Itens GROUP BY CODIGO HAVING COUNT(*) > 1)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'A mesma preferência veio mais de uma vez.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;

        UPDATE i
           SET i.ID_PREFERENCIA = p.ID_PREFERENCIA, i.NOME = p.NOME, i.TIPO = p.TIPO, i.OPCOES = p.OPCOES,
               i.VALOR_MINIMO = p.VALOR_MINIMO, i.VALOR_MAXIMO = p.VALOR_MAXIMO,
               i.VALOR = CASE WHEN p.TIPO = 'SN' OR p.OPCOES <> N'' THEN UPPER(i.VALOR) ELSE i.VALOR END
        FROM @Itens i
        INNER JOIN SIS.Preferencia p ON p.CODIGO = i.CODIGO AND p.ATIVO = 1;

        -- Conferência de cada valor (vazio = volta ao padrão, sempre aceito)
        SELECT TOP 1 @Recusa =
               CASE WHEN i.ID_PREFERENCIA IS NULL THEN N'Preferência desconhecida: ' + CONVERT(NVARCHAR(40), i.CODIGO) + N'.'
                    WHEN i.VALOR = N'' THEN NULL
                    WHEN i.TIPO = 'SN' AND i.VALOR NOT IN (N'S', N'N') THEN N'"' + i.NOME + N'": escolha Sim ou Não.'
                    WHEN i.OPCOES <> N'' AND CHARINDEX(N';' + i.VALOR + N';', N';' + REPLACE(i.OPCOES, N' ', N'') + N';') = 0 THEN N'"' + i.NOME + N'": opção inválida.'
                    WHEN i.TIPO = 'INTEIRO' AND TRY_CONVERT(INT, i.VALOR) IS NULL THEN N'"' + i.NOME + N'": informe um número inteiro.'
                    WHEN i.TIPO = 'INTEIRO' AND i.VALOR_MINIMO IS NOT NULL AND TRY_CONVERT(INT, i.VALOR) < i.VALOR_MINIMO
                         THEN N'"' + i.NOME + N'": o menor valor aceito é ' + CONVERT(NVARCHAR(12), i.VALOR_MINIMO) + N'.'
                    WHEN i.TIPO = 'INTEIRO' AND i.VALOR_MAXIMO IS NOT NULL AND TRY_CONVERT(INT, i.VALOR) > i.VALOR_MAXIMO
                         THEN N'"' + i.NOME + N'": o maior valor aceito é ' + CONVERT(NVARCHAR(12), i.VALOR_MAXIMO) + N'.'
               END
        FROM @Itens i
        WHERE i.ID_PREFERENCIA IS NULL
           OR (i.VALOR <> N''
               AND (   (i.TIPO = 'SN' AND i.VALOR NOT IN (N'S', N'N'))
                    OR (i.OPCOES <> N'' AND CHARINDEX(N';' + i.VALOR + N';', N';' + REPLACE(i.OPCOES, N' ', N'') + N';') = 0)
                    OR (i.TIPO = 'INTEIRO' AND (TRY_CONVERT(INT, i.VALOR) IS NULL
                                                OR TRY_CONVERT(INT, i.VALOR) < ISNULL(i.VALOR_MINIMO, -2147483647)
                                                OR TRY_CONVERT(INT, i.VALOR) > ISNULL(i.VALOR_MAXIMO, 2147483647)))))
        ORDER BY i.CODIGO;

        IF @Recusa IS NOT NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;

        UPDATE @Itens SET VALOR = CONVERT(NVARCHAR(400), TRY_CONVERT(INT, VALOR)) WHERE TIPO = 'INTEIRO' AND VALOR <> N'';

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        -- preferência do próprio usuário (só ele grava): sem disputa entre sessões
        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            DELETE up
            FROM SIS.Usuario_Preferencia up
            INNER JOIN @Itens i ON i.ID_PREFERENCIA = up.ID_PREFERENCIA
            WHERE up.ID_USUARIO = @IdUsuario AND i.VALOR = N'';
            SET @Qtd = @@ROWCOUNT;

            UPDATE up
               SET up.VALOR = i.VALOR, up.DT_ALTERACAO = SYSDATETIME(), up.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Usuario_Preferencia up
            INNER JOIN @Itens i ON i.ID_PREFERENCIA = up.ID_PREFERENCIA
            WHERE up.ID_USUARIO = @IdUsuario AND i.VALOR <> N'' AND up.VALOR <> i.VALOR;
            SET @Qtd = @Qtd + @@ROWCOUNT;

            INSERT INTO SIS.Usuario_Preferencia (ID_USUARIO, ID_PREFERENCIA, VALOR, USUARIO_CRIACAO)
            SELECT @IdUsuario, i.ID_PREFERENCIA, i.VALOR, ISNULL(@Usuario, N'')
            FROM @Itens i
            WHERE i.VALOR <> N''
              AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Preferencia x WHERE x.ID_USUARIO = @IdUsuario AND x.ID_PREFERENCIA = i.ID_PREFERENCIA);
            SET @Qtd = @Qtd + @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Preferências gravadas.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@Qtd AS INT) AS QTD_GRAVADAS;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar as preferências. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(0 AS INT) AS QTD_GRAVADAS;
    END CATCH;
END;
GO
