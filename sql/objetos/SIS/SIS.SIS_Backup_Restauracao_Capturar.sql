/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Capturar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Chamada SÓ pelo script do servidor (instalacao\backup_servidor.ps1,
                tarefa "Restauração (pedidos)", a cada minuto, como SYSTEM). O
                login da API não pode executar (DENY no papel rl_sistemacmj_api).
                Pega o pedido PENDENTE mais antigo, marca EXECUTANDO e devolve o
                plano: uma linha por arquivo a aplicar, na ordem (ORDEM 0 = o
                backup completo; 1, 2... = os backups do log; ULTIMO = 1 na
                última linha, aplicada com STOPAT quando TIPO_PONTO = DATA_HORA).
                Sem pedido, ou com outro pedido já EXECUTANDO: devolve 0 linhas.
                Se o plano não fecha mais (arquivo apagado pela limpeza), marca
                o pedido como ERRO, avisa por e-mail e devolve 0 linhas.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Capturar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Capturar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Captura';
    DECLARE @Capturado  TABLE (ID_RESTAURACAO INT NOT NULL);
    DECLARE @Id INT, @IdBackup BIGINT, @DtPonto DATETIME2(0);
    DECLARE @QtdLinhas INT, @QtdSemArquivo INT, @Alcanca INT;
    DECLARE @Erro NVARCHAR(400) = N'';
    DECLARE @Resultado  TABLE (ID_RESTAURACAO INT, SITUACAO VARCHAR(12));

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM SIS.Backup_Restauracao r WHERE r.SITUACAO = 'EXECUTANDO')
            RETURN;

        BEGIN TRANSACTION;
            WITH Proximo AS
            (
                SELECT TOP (1) r.*
                FROM SIS.Backup_Restauracao r WITH (UPDLOCK, READPAST, ROWLOCK)
                WHERE r.SITUACAO = 'PENDENTE'
                ORDER BY r.ID_RESTAURACAO
            )
            UPDATE Proximo
               SET SITUACAO          = 'EXECUTANDO',
                   DT_INICIO         = SYSDATETIME(),
                   MENSAGEM          = N'',
                   DT_ALTERACAO      = SYSDATETIME(),
                   USUARIO_ALTERACAO = N'restauracao'
            OUTPUT inserted.ID_RESTAURACAO INTO @Capturado (ID_RESTAURACAO);
        COMMIT TRANSACTION;

        SELECT @Id = c.ID_RESTAURACAO FROM @Capturado c;
        IF @Id IS NULL RETURN;

        SELECT @IdBackup = r.ID_BACKUP, @DtPonto = r.DT_PONTO FROM SIS.Backup_Restauracao r WHERE r.ID_RESTAURACAO = @Id;

        SET @EtapaAtual = 'Plano';
        SELECT @QtdLinhas     = COUNT(*),
               @QtdSemArquivo = SUM(CASE WHEN p.ARQUIVO_EXISTE = 0 THEN 1 ELSE 0 END),
               @Alcanca       = MAX(CAST(p.ALCANCA_PONTO AS INT))
        FROM SIS.fn_SIS_Backup_Plano(@IdBackup, @DtPonto) p;

        IF ISNULL(@QtdLinhas, 0) = 0 OR ISNULL(@QtdSemArquivo, 0) > 0 OR ISNULL(@Alcanca, 0) = 0
            SET @Erro = N'O plano da restauração não fecha mais (backup não encontrado ou arquivo apagado pela limpeza). Nada foi restaurado; faça um pedido novo.';

        IF @Erro <> N''
        BEGIN
            INSERT INTO @Resultado (ID_RESTAURACAO, SITUACAO)
            EXEC SIS.SIS_Backup_Restauracao_Resultado @IdRestauracao = @Id, @Situacao = 'ERRO', @Mensagem = @Erro;
            RETURN;
        END;

        SELECT r.ID_RESTAURACAO, r.TIPO_PONTO, r.DT_PONTO, r.ID_BACKUP, r.MOTIVO, r.USUARIO_PEDIDO, r.ID_USUARIO_PEDIDO, r.DT_PEDIDO, r.DT_INICIO,
               p.ORDEM, p.ID_BACKUP AS ID_BACKUP_ARQUIVO, p.TIPO, p.ARQUIVO, p.DT_INICIO AS DT_INICIO_ARQUIVO, p.DT_FIM AS DT_FIM_ARQUIVO,
               CAST(CASE WHEN p.ORDEM = MAX(p.ORDEM) OVER () THEN 1 ELSE 0 END AS BIT) AS ULTIMO
        FROM SIS.Backup_Restauracao r
        CROSS JOIN SIS.fn_SIS_Backup_Plano(@IdBackup, @DtPonto) p
        WHERE r.ID_RESTAURACAO = @Id
        ORDER BY p.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
