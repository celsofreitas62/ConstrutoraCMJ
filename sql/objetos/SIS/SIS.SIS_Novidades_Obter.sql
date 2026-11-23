/*******************************************************************************
  Objeto      : [SIS].[SIS_Novidades_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Aviso "O que há de novo" (pedido P22): as notas das versões
                instaladas depois da última que o usuário já viu
                (SIS.Usuario_Novidade), no máximo NOVIDADES_VERSOES_MAX versões
                (as mais novas; VERSOES_OMITIDAS diz quantas ficaram de fora,
                para a tela oferecer "ver todas as versões").
                Nenhuma linha = nada a mostrar (aviso desligado pelo parâmetro
                NOVIDADES_AVISO_ATIVO, usuário já viu tudo, ou usuário sem
                registro: nasce com a versão atual vista).
                Não marca como visto: quem marca é SIS_Novidades_Marcar_Vista
                (botão "Entendi" da janela).
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Novidades_Obter @IdUsuario = 2;
    -- sql/testes/SIS/04c_Homologacao_Versoes.sql
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Novidades_Obter]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Novidades_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Usuário';
    DECLARE @VersaoAtual VARCHAR(20), @Atual INT, @Vista INT = 0, @Max INT, @Mostrar BIT = 1, @Geral BIT, @Omitidas INT = 0;
    DECLARE @Versoes TABLE (VERSAO_NUMERO INT NOT NULL PRIMARY KEY, POSICAO INT NOT NULL);

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
            THROW 50001, N'Usuário não identificado. Entre no sistema de novo.', 1;

        SET @VersaoAtual = SIS.fn_SIS_Versao_Banco();
        SET @Atual       = SIS.fn_SIS_Versao_Numero(@VersaoAtual);
        SET @Geral       = CASE WHEN SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) = 2 THEN 1 ELSE 0 END;
        SET @Max         = ISNULL(SIS.fn_SIS_Parametro_Inteiro('NOVIDADES_VERSOES_MAX'), 3);
        IF @Max < 1 SET @Max = 1;
        IF SIS.fn_SIS_Parametro_SN('NOVIDADES_AVISO_ATIVO') = 0 SET @Mostrar = 0;

        SET @EtapaAtual = 'Última versão vista';
        IF @Mostrar = 1
        BEGIN
            BEGIN TRANSACTION;
            INSERT INTO SIS.Usuario_Novidade (ID_USUARIO, VERSAO_VISTA)
            SELECT @IdUsuario, ISNULL(@VersaoAtual, '')
            WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Novidade n WITH (UPDLOCK, HOLDLOCK) WHERE n.ID_USUARIO = @IdUsuario);
            IF @@ROWCOUNT > 0 SET @Mostrar = 0;
            COMMIT TRANSACTION;

            SELECT @Vista = SIS.fn_SIS_Versao_Numero(n.VERSAO_VISTA)
            FROM SIS.Usuario_Novidade n WITH (NOLOCK)
            WHERE n.ID_USUARIO = @IdUsuario;
        END;

        SET @EtapaAtual = 'Versões novas';
        INSERT INTO @Versoes (VERSAO_NUMERO, POSICAO)
        SELECT v.VERSAO_NUMERO, ROW_NUMBER() OVER (ORDER BY v.VERSAO_NUMERO DESC)
        FROM (SELECT DISTINCT n.VERSAO_NUMERO
              FROM SIS.Versao_Nota n WITH (NOLOCK)
              WHERE @Mostrar = 1
                AND n.VERSAO_NUMERO > ISNULL(@Vista, 0)
                AND n.VERSAO_NUMERO <= @Atual
                AND (n.PUBLICO = 'TODOS' OR @Geral = 1)) v;

        SELECT @Omitidas = COUNT(*) FROM @Versoes WHERE POSICAO > @Max;

        SET @EtapaAtual = 'Consulta';
        SELECT n.VERSAO,
               n.VERSAO_NUMERO,
               CAST(ISNULL(CONVERT(VARCHAR(10), n.DT_VERSAO, 103), '') AS VARCHAR(10)) AS DT_VERSAO,
               n.ORDEM,
               n.TIPO,
               CAST(CASE n.TIPO WHEN 'NOVO' THEN N'Novo' WHEN 'MELHORIA' THEN N'Melhoria' ELSE N'Correção' END AS NVARCHAR(20)) AS TIPO_NOME,
               n.PUBLICO,
               n.TEXTO,
               n.TEXTO_HTML,
               CAST(ISNULL(@VersaoAtual, '') AS VARCHAR(20)) AS VERSAO_ATUAL,
               CAST(@Omitidas AS INT) AS VERSOES_OMITIDAS
        FROM SIS.Versao_Nota n WITH (NOLOCK)
        INNER JOIN @Versoes v ON v.VERSAO_NUMERO = n.VERSAO_NUMERO AND v.POSICAO <= @Max
        WHERE (n.PUBLICO = 'TODOS' OR @Geral = 1)
        ORDER BY n.VERSAO_NUMERO DESC, n.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar as novidades da versão. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
