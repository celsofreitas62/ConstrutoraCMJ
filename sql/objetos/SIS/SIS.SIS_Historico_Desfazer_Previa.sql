/*******************************************************************************
  Objeto      : [SIS].[SIS_Historico_Desfazer_Previa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Prévia do desfazer pelo histórico (P20), sem gravar nada: o
                que vai mudar, campo a campo (como está agora e como vai
                ficar), o que vai para a lixeira e o que impede (CONFLITO,
                BLOQUEADO). Usada pela aba Histórico das fichas e pela tela de
                Auditoria antes de confirmar. Modos e regras: ver
                SIS_Historico_Desfazer_Montar.
                Permissão: DESFAZER na tela (@Item); no modo REGISTRO a tela
                precisa mostrar a tabela; no modo LOTE, a tela é
                SIS_AUDITORIA.
                Devolve as linhas do plano, com TELA_NOME e as colunas
                PODE_DESFAZER (1 = tudo certo) e RESUMO iguais em todas.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Historico_Desfazer_Previa @IdUsuario = 2, @Item = 'CAD_PESSOA', @Modo = 'REGISTRO', @Tabela = N'CAD.Pessoa', @IdRegistro = 1, @IdAuditoria = 10;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Historico_Desfazer_Previa]
    @IdUsuario    INT,
    @Item         VARCHAR(40),
    @Modo         VARCHAR(10),
    @Tabela       NVARCHAR(256) = NULL,
    @IdRegistro   BIGINT        = NULL,
    @IdAuditoria  BIGINT        = NULL,
    @DataHora     DATETIME2(0)  = NULL,
    @IdLote       BIGINT        = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Historico_Desfazer_Previa]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Pode BIT, @Resumo NVARCHAR(400), @Muda INT, @Impede INT;

    DROP TABLE IF EXISTS #Desfazer_Plano;

    BEGIN TRY
        SET @Modo   = UPPER(LTRIM(RTRIM(ISNULL(@Modo, ''))));
        SET @Tabela = LTRIM(RTRIM(ISNULL(@Tabela, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'DESFAZER') = 0
            THROW 50001, N'Você não tem permissão para desfazer nesta tela.', 1;
        IF @Modo NOT IN ('REGISTRO', 'OPERACAO', 'LOTE')
            THROW 50001, N'Modo de desfazer inválido.', 1;
        IF @Modo = 'REGISTRO' AND (SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0 OR @IdRegistro IS NULL OR (@IdAuditoria IS NULL AND @DataHora IS NULL))
            THROW 50001, N'Escolha o registro e o ponto do histórico para onde voltar.', 1;
        IF @Modo = 'OPERACAO' AND @IdAuditoria IS NULL
            THROW 50001, N'Escolha a operação a desfazer.', 1;
        IF @Modo = 'LOTE' AND (@Item <> 'SIS_AUDITORIA' OR @IdLote IS NULL)
            THROW 50001, N'Escolha o lote a desfazer (tela de Auditoria).', 1;

        SET @EtapaAtual = 'Montagem';
        CREATE TABLE #Desfazer_Plano
        (
            ORDEM             INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            TABELA            NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL,
            ID_REGISTRO       BIGINT        NOT NULL,
            DESCRICAO         NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
            CAMPO             NVARCHAR(128) COLLATE DATABASE_DEFAULT NOT NULL,
            VALOR_ATUAL       NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
            VALOR_NOVO        NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NULL,
            ACAO              VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
            SITUACAO          VARCHAR(10)   COLLATE DATABASE_DEFAULT NOT NULL,
            MENSAGEM          NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
            ULTIMA_AUDITORIA  BIGINT        NULL
        );

        EXEC SIS.SIS_Historico_Desfazer_Montar @Modo = @Modo, @Tabela = @Tabela, @IdRegistro = @IdRegistro,
             @IdAuditoria = @IdAuditoria, @DataHora = @DataHora, @IdLote = @IdLote;

        SELECT @Muda = COUNT(*) FROM #Desfazer_Plano WHERE ACAO IN ('ALTERAR', 'LIXEIRA', 'APAGAR', 'REINSERIR');
        SELECT @Impede = COUNT(*) FROM #Desfazer_Plano WHERE SITUACAO IN ('CONFLITO', 'BLOQUEADO');
        SET @Pode = CASE WHEN @Muda > 0 AND @Impede = 0 THEN 1 ELSE 0 END;
        SET @Resumo = CASE WHEN @Impede > 0 THEN CAST(@Impede AS NVARCHAR(10)) + N' ponto(s) impedem desfazer: veja as linhas em vermelho.'
                           WHEN @Muda = 0 THEN N'Nada a desfazer: já está tudo como estava.'
                           ELSE CAST(@Muda AS NVARCHAR(10)) + N' mudança(s) a fazer. Confira e informe o motivo.' END;

        SELECT p.ORDEM,
               p.TABELA,
               ISNULL(i.NOME, p.TABELA) AS TELA_NOME,
               p.ID_REGISTRO,
               ISNULL(p.DESCRICAO, N'') AS DESCRICAO,
               p.CAMPO,
               ISNULL(CAST(p.VALOR_ATUAL AS NVARCHAR(4000)), N'') AS VALOR_ATUAL,
               ISNULL(CAST(p.VALOR_NOVO  AS NVARCHAR(4000)), N'') AS VALOR_NOVO,
               p.ACAO,
               p.SITUACAO,
               ISNULL(p.MENSAGEM, N'') AS MENSAGEM,
               p.ULTIMA_AUDITORIA,
               @Pode AS PODE_DESFAZER,
               @Resumo AS RESUMO
        FROM #Desfazer_Plano p
        LEFT JOIN SIS.Item i ON i.CODIGO = SIS.fn_SIS_Item_Da_Tabela(p.TABELA)
        ORDER BY CASE p.SITUACAO WHEN 'BLOQUEADO' THEN 0 WHEN 'CONFLITO' THEN 1 ELSE 2 END, p.TABELA, p.ID_REGISTRO, p.ORDEM;

        DROP TABLE IF EXISTS #Desfazer_Plano;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1 DROP TABLE IF EXISTS #Desfazer_Plano;
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível montar a prévia. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
