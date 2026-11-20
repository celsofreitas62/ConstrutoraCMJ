/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Restauracao_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Pedidos de restauração e o resultado de cada um, do mais novo
                para o mais antigo (tela Sistema > Backups, SIS_BACKUP, VER).
                Sem permissão: erro 50001.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Restauracao_Listar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Restauracao_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Restauracao_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os backups.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT r.ID_RESTAURACAO,
               r.TIPO_PONTO,
               CAST(CASE r.TIPO_PONTO WHEN 'BACKUP' THEN N'Backup escolhido' ELSE N'Dia e hora' END AS NVARCHAR(30)) AS TIPO_PONTO_NOME,
               r.ID_BACKUP,
               CAST(ISNULL(b.ARQUIVO, N'') AS NVARCHAR(400)) AS ARQUIVO_BACKUP,
               ISNULL(r.DT_PONTO, b.DT_FIM) AS DT_VOLTA_PARA,
               r.MOTIVO,
               r.SITUACAO,
               CAST(CASE r.SITUACAO WHEN 'PENDENTE' THEN N'Aguardando' WHEN 'EXECUTANDO' THEN N'Restaurando'
                                    WHEN 'OK' THEN N'Concluída' WHEN 'ERRO' THEN N'Com erro' WHEN 'CANCELADO' THEN N'Cancelada'
                                    ELSE N'' END AS NVARCHAR(20)) AS SITUACAO_NOME,
               r.USUARIO_PEDIDO,
               r.DT_PEDIDO,
               r.DT_INICIO,
               r.DT_FIM,
               r.PLANO,
               r.ARQUIVO_SEGURANCA,
               r.MENSAGEM,
               CAST(CASE WHEN r.SITUACAO = 'PENDENTE' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'RESTAURAR') = 1
                         THEN 1 ELSE 0 END AS BIT) AS PODE_CANCELAR
        FROM SIS.Backup_Restauracao r WITH (NOLOCK)
        LEFT JOIN SIS.Backup_Execucao b WITH (NOLOCK) ON b.ID_BACKUP = r.ID_BACKUP
        ORDER BY r.ID_RESTAURACAO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível listar os pedidos de restauração. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
