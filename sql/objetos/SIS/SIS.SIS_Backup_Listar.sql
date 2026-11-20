/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Lista dos backups para a tela Sistema > Backups (SIS_BACKUP,
                ação VER): completos, do log de hora em hora, testes de
                restauração e backups de segurança, do mais novo para o mais
                antigo, com a indicação de que o arquivo ainda existe.
                Mostra os dos últimos @Dias dias (padrão: parâmetro
                BACKUP_DIAS_MANTER + 7) e qualquer um cujo arquivo ainda exista.
                Sem permissão: erro 50001 (a tela mostra a mensagem).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).
    v1.1 (20/11/2026) - PODE_ESCOLHER só para backup feito depois da atualização
                        para a versão atual (fn_SIS_Backup_Limite_Versao).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Backup_Listar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Listar]
    @IdUsuario  INT,
    @Dias       INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Backup_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Desde      DATETIME2(0);
    DECLARE @DtLimite   DATETIME2(0)  = SIS.fn_SIS_Backup_Limite_Versao();

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_BACKUP', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os backups.', 1;

        SET @Dias = ISNULL(@Dias, ISNULL(TRY_CONVERT(INT, SIS.fn_SIS_Parametro('BACKUP_DIAS_MANTER')), 7) + 7);
        IF @Dias < 1 SET @Dias = 1;
        IF @Dias > 3650 SET @Dias = 3650;
        SET @Desde = DATEADD(DAY, -@Dias, SYSDATETIME());

        SET @EtapaAtual = 'Consulta';
        SELECT b.ID_BACKUP,
               b.TIPO,
               CAST(CASE b.TIPO WHEN 'COMPLETO' THEN N'Completo' WHEN 'LOG' THEN N'De hora em hora (log)'
                                WHEN 'TESTE' THEN N'Teste de restauração' WHEN 'SEGURANCA' THEN N'Segurança (antes de restaurar)'
                                ELSE N'' END AS NVARCHAR(40)) AS TIPO_NOME,
               b.ARQUIVO,
               CAST(ISNULL(RIGHT(b.ARQUIVO, CHARINDEX(N'\', REVERSE(b.ARQUIVO) + N'\') - 1), N'') AS NVARCHAR(260)) AS ARQUIVO_NOME,
               b.DT_INICIO,
               b.DT_FIM,
               b.TAMANHO_MB,
               b.SITUACAO,
               b.MENSAGEM,
               b.COPIA_NUVEM,
               b.ARQUIVO_EXISTE,
               CAST(CASE WHEN b.TIPO IN ('COMPLETO', 'SEGURANCA') AND b.SITUACAO = 'OK' AND b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N''
                              AND b.DT_FIM >= @DtLimite
                         THEN 1 ELSE 0 END AS BIT) AS PODE_ESCOLHER,
               b.SERVIDOR
        FROM SIS.Backup_Execucao b WITH (NOLOCK)
        WHERE b.DT_INICIO >= @Desde
           OR (b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N'' AND b.TIPO <> 'TESTE')
        ORDER BY b.DT_INICIO DESC, b.ID_BACKUP DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível listar os backups. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
