/*******************************************************************************
  Objeto      : [SIS].[SIS_Licenca_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Instala uma licença. A API chama SÓ DEPOIS de conferir a
                assinatura digital da chave com a chave pública embutida nela
                e de conferir que o servidor é o da licença; os demais
                parâmetros são o conteúdo já lido da chave.
                Tudo-ou-nada: desativa a licença anterior, grava a nova com as
                empresas e acerta os módulos liberados.
                @Modulos      : códigos separados por vírgula ("CAD,FIN,VENDA").
                                Código que ainda não existe neste banco é
                                guardado e avisado (módulo instalado depois
                                passa a valer sozinho, via
                                SIS_Licenca_Modulos_Aplicar no fim do MASTER).
                @EmpresasJson : [{"cnpj":"...","razao_social":"...",
                                  "nome_fantasia":"...","principal":true}, ...]
                                Sem nenhuma marcada como principal, a primeira
                                da lista vira a principal.
                Permissão: SIS_LICENCA / INCLUIR.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_LICENCA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Licenca_Gravar]
    @IdUsuario     INT,
    @ChaveLicenca  NVARCHAR(MAX),
    @IdServidor    VARCHAR(200),
    @DtEmissao     DATE,
    @DtValidade    DATE          = NULL,
    @Modulos       VARCHAR(400),
    @EmpresasJson  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc       NVARCHAR(128) = N'[SIS].[SIS_Licenca_Gravar]';
    DECLARE @EtapaAtual     VARCHAR(100)  = 'Validação';
    DECLARE @Recusa         NVARCHAR(400) = N'';
    DECLARE @Usuario        NVARCHAR(100);
    DECLARE @IdLicenca      INT;
    DECLARE @ModulosNorm    VARCHAR(400)  = '';
    DECLARE @Desconhecidos  VARCHAR(400)  = '';
    DECLARE @Hoje           DATE          = CAST(SYSDATETIME() AS DATE);

    DROP TABLE IF EXISTS #Emp;
    DROP TABLE IF EXISTS #Mod;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LICENCA', 'INCLUIR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para instalar licença.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_LICENCA;
            RETURN;
        END;

        SET @Usuario      = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @ChaveLicenca = LTRIM(RTRIM(ISNULL(@ChaveLicenca, N'')));
        SET @IdServidor   = LTRIM(RTRIM(ISNULL(@IdServidor, '')));

        IF @ChaveLicenca = N''                                     SET @Recusa = N'A chave da licença está vazia.';
        IF @Recusa = N'' AND @IdServidor = ''                      SET @Recusa = N'A licença não identifica o servidor autorizado.';
        IF @Recusa = N'' AND @DtEmissao IS NULL                    SET @Recusa = N'A licença não tem data de emissão.';
        IF @Recusa = N'' AND @DtValidade IS NOT NULL AND @DtValidade < @DtEmissao
                                                                   SET @Recusa = N'A validade da licença é anterior à emissão.';
        IF @Recusa = N'' AND @DtValidade IS NOT NULL AND @DtValidade < @Hoje
                                                                   SET @Recusa = N'Esta licença já está vencida.';
        IF @Recusa = N'' AND ISJSON(ISNULL(@EmpresasJson, N'')) = 0 SET @Recusa = N'A lista de empresas da licença é inválida.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_LICENCA;
            RETURN;
        END;

        IF EXISTS (SELECT 1 FROM SIS.Licenca l WHERE l.ATIVA = 1 AND l.CHAVE_LICENCA = @ChaveLicenca)
        BEGIN
            SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Esta licença já está instalada.' AS NVARCHAR(400)) AS MENSAGEM,
                   (SELECT l.ID_LICENCA FROM SIS.Licenca l WHERE l.ATIVA = 1) AS ID_LICENCA;
            RETURN;
        END;

        SET @EtapaAtual = 'Leitura das empresas';
        SELECT CAST(j.[key] AS INT) AS ORDEM,
               UPPER(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(e.cnpj, ''))), '.', ''), '/', ''), '-', ''), ' ', '')) AS CNPJ,
               LTRIM(RTRIM(ISNULL(e.razao_social, N'')))  AS RAZAO_SOCIAL,
               LTRIM(RTRIM(ISNULL(e.nome_fantasia, N''))) AS NOME_FANTASIA,
               ISNULL(e.principal, 0)                     AS PRINCIPAL
        INTO #Emp
        FROM OPENJSON(@EmpresasJson) j
        CROSS APPLY OPENJSON(j.value)
             WITH (cnpj          VARCHAR(30)   '$.cnpj',
                   razao_social  NVARCHAR(150) '$.razao_social',
                   nome_fantasia NVARCHAR(100) '$.nome_fantasia',
                   principal     BIT           '$.principal') e
        WHERE j.type = 5;   -- só objetos

        IF NOT EXISTS (SELECT 1 FROM #Emp)
            SET @Recusa = N'A licença não tem nenhuma empresa.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Emp e WHERE LEN(e.CNPJ) <> 14 OR e.CNPJ LIKE '%[^0-9A-Z]%')
            SET @Recusa = N'A licença tem CNPJ inválido.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Emp e WHERE e.RAZAO_SOCIAL = N'')
            SET @Recusa = N'A licença tem empresa sem razão social.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Emp e GROUP BY e.CNPJ HAVING COUNT(*) > 1)
            SET @Recusa = N'A licença repete o mesmo CNPJ.';
        IF @Recusa = N'' AND (SELECT COUNT(*) FROM #Emp e WHERE e.PRINCIPAL = 1) > 1
            SET @Recusa = N'A licença marca mais de uma empresa como principal.';

        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Emp;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_LICENCA;
            RETURN;
        END;

        IF NOT EXISTS (SELECT 1 FROM #Emp e WHERE e.PRINCIPAL = 1)
            UPDATE e SET e.PRINCIPAL = 1
            FROM #Emp e
            WHERE e.ORDEM = (SELECT MIN(x.ORDEM) FROM #Emp x);

        SET @EtapaAtual = 'Leitura dos módulos';
        SELECT DISTINCT UPPER(LTRIM(RTRIM(s.value))) AS CODIGO
        INTO #Mod
        FROM STRING_SPLIT(ISNULL(@Modulos, ''), ',') s
        WHERE LTRIM(RTRIM(s.value)) <> '';

        SELECT @ModulosNorm = ISNULL(STRING_AGG(CAST(md.CODIGO AS VARCHAR(400)), ',') WITHIN GROUP (ORDER BY md.CODIGO), '')
        FROM #Mod md;

        SELECT @Desconhecidos = ISNULL(STRING_AGG(CAST(md.CODIGO AS VARCHAR(400)), ', ') WITHIN GROUP (ORDER BY md.CODIGO), '')
        FROM #Mod md
        WHERE NOT EXISTS (SELECT 1 FROM SIS.Modulo m WHERE m.CODIGO = md.CODIGO);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            UPDATE l
               SET l.ATIVA             = 0,
                   l.DT_DESATIVACAO    = SYSDATETIME(),
                   l.DT_ALTERACAO      = SYSDATETIME(),
                   l.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Licenca l WITH (UPDLOCK, HOLDLOCK)
            WHERE l.ATIVA = 1;

            INSERT INTO SIS.Licenca (CHAVE_LICENCA, ID_SERVIDOR, DT_EMISSAO, DT_VALIDADE, MODULOS, ATIVA, USUARIO_CRIACAO)
            VALUES (@ChaveLicenca, @IdServidor, @DtEmissao, @DtValidade, ISNULL(@ModulosNorm, ''), 1, ISNULL(@Usuario, N''));
            SET @IdLicenca = CAST(SCOPE_IDENTITY() AS INT);

            INSERT INTO SIS.Licenca_Empresa (ID_LICENCA, CNPJ, RAZAO_SOCIAL, NOME_FANTASIA, PRINCIPAL, USUARIO_CRIACAO)
            SELECT @IdLicenca, e.CNPJ, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.PRINCIPAL, ISNULL(@Usuario, N'')
            FROM #Emp e;

            EXEC SIS.SIS_Licenca_Modulos_Aplicar @Usuario = @Usuario;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Emp;
        DROP TABLE IF EXISTS #Mod;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Licença instalada.'
                    + CASE WHEN @Desconhecidos <> '' THEN N' Módulos ainda não instalados neste banco (passam a valer quando forem instalados): ' + @Desconhecidos + N'.' ELSE N'' END
                    AS NVARCHAR(400)) AS MENSAGEM,
               @IdLicenca AS ID_LICENCA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Emp;
            DROP TABLE IF EXISTS #Mod;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível instalar a licença. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_LICENCA;
    END CATCH;
END;
GO
