/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Situacao_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Resumo do topo da tela Sistema > Backups (SIS_BACKUP, VER),
                1 linha: até onde dá para voltar (do backup completo mais
                antigo que ainda existe até o último backup do log ou
                completo), último completo, último log, último teste, pedido
                de restauração em aberto e se o usuário pode restaurar.
                Sem permissão: erro 50001.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
    v1.1 (20/11/2026) - "De" respeita a última atualização de versão
                        (fn_SIS_Backup_Limite_Versao); DT_PODE_VOLTAR_ATE_HORA
                        (último backup do log: limite do "dia e hora"),
                        DT_LIMITE_VERSAO e VERSAO. Achados no ensaio.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Situacao_Obter @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Situacao_Obter]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Backup_Situacao_Obter]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @DtMaisAntigo DATETIME2(0), @DtInicioAntigo DATETIME2(0), @DtMaisRecente DATETIME2(0), @DtAteHora DATETIME2(0);
    DECLARE @DtLimite     DATETIME2(0) = SIS.fn_SIS_Backup_Limite_Versao();

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os backups.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (1) @DtMaisAntigo = b.DT_FIM, @DtInicioAntigo = b.DT_INICIO
        FROM SIS.Backup_Execucao b WITH (NOLOCK)
        WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK' AND b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N'' AND b.DT_FIM IS NOT NULL
        ORDER BY b.DT_FIM, b.ID_BACKUP;

        SELECT @DtMaisRecente = MAX(b.DT_FIM)
        FROM SIS.Backup_Execucao b WITH (NOLOCK)
        WHERE b.TIPO IN ('COMPLETO', 'LOG') AND b.SITUACAO = 'OK' AND b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N''
          AND b.DT_INICIO >= @DtInicioAntigo;

        SELECT @DtAteHora = MAX(b.DT_FIM)
        FROM SIS.Backup_Execucao b WITH (NOLOCK)
        WHERE b.TIPO = 'LOG' AND b.SITUACAO = 'OK' AND b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N''
          AND b.DT_INICIO >= @DtInicioAntigo;

        IF @DtMaisAntigo < @DtLimite SET @DtMaisAntigo = @DtLimite;
        IF @DtMaisRecente < @DtMaisAntigo SET @DtMaisRecente = NULL;
        IF @DtAteHora < @DtMaisAntigo SET @DtAteHora = NULL;

        SELECT @DtMaisAntigo  AS DT_PODE_VOLTAR_DE,
               @DtMaisRecente AS DT_PODE_VOLTAR_ATE,
               @DtAteHora     AS DT_PODE_VOLTAR_ATE_HORA,
               CASE WHEN @DtLimite > '1900-01-01' THEN @DtLimite END AS DT_LIMITE_VERSAO,
               CAST(SIS.fn_SIS_Versao_Banco() AS VARCHAR(20)) AS VERSAO,
               (SELECT MAX(b.DT_FIM) FROM SIS.Backup_Execucao b WITH (NOLOCK) WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK') AS DT_ULTIMO_COMPLETO,
               (SELECT MAX(b.DT_FIM) FROM SIS.Backup_Execucao b WITH (NOLOCK) WHERE b.TIPO = 'LOG'      AND b.SITUACAO = 'OK') AS DT_ULTIMO_LOG,
               (SELECT MAX(b.DT_FIM) FROM SIS.Backup_Execucao b WITH (NOLOCK) WHERE b.TIPO = 'TESTE'    AND b.SITUACAO = 'OK') AS DT_ULTIMO_TESTE,
               CAST(ISNULL((SELECT COUNT(*) FROM SIS.Backup_Execucao b WITH (NOLOCK)
                            WHERE b.SITUACAO = 'ERRO' AND b.DT_INICIO >= DATEADD(DAY, -7, SYSDATETIME())), 0) AS INT) AS QTD_ERROS_7_DIAS,
               CAST(ISNULL((SELECT TOP (1) r.ID_RESTAURACAO FROM SIS.Backup_Restauracao r WITH (NOLOCK)
                            WHERE r.SITUACAO IN ('PENDENTE', 'EXECUTANDO') ORDER BY r.ID_RESTAURACAO), 0) AS INT) AS ID_RESTAURACAO_ABERTA,
               CAST(ISNULL((SELECT TOP (1) r.SITUACAO FROM SIS.Backup_Restauracao r WITH (NOLOCK)
                            WHERE r.SITUACAO IN ('PENDENTE', 'EXECUTANDO') ORDER BY r.ID_RESTAURACAO), '') AS VARCHAR(12)) AS SITUACAO_ABERTA,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'RESTAURAR') AS PODE_RESTAURAR,
               CAST(DB_NAME() AS NVARCHAR(128)) AS BANCO,
               SYSDATETIME() AS DT_AGORA;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar a situação dos backups. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
