/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Backup_Plano]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Plano de uma restauração: quais arquivos de backup aplicar e
                em que ordem (function inline, só leitura).
                  @IdBackup preenchido (TIPO_PONTO BACKUP): só aquele backup
                    completo ou de segurança, ORDEM 0.
                  @DtPonto preenchido (TIPO_PONTO DATA_HORA): o último backup
                    COMPLETO que terminou até o ponto (ORDEM 0) e os backups
                    do LOG seguintes, até o primeiro que passa do ponto
                    (ORDEM 1, 2...; o último é aplicado com STOPAT).
                Só backups com SITUACAO OK. ARQUIVO_EXISTE vem junto para quem
                chama recusar o plano com arquivo que já foi apagado.
                O plano está completo quando tem a linha 0 e, no DATA_HORA,
                a última linha tem DT_FIM >= @DtPonto (coluna ALCANCA_PONTO).
                A conferência fina da sequência do log (LSN) é feita pelo
                script na hora de restaurar.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d2, restauração pela tela).

  Homologação (LOCAL):
    -- SELECT * FROM SIS.fn_SIS_Backup_Plano(NULL, '2026-11-20 14:45') ORDER BY ORDEM;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Backup_Plano] (@IdBackup BIGINT, @DtPonto DATETIME2(0))
RETURNS TABLE
AS
RETURN
WITH Base AS
(
    SELECT TOP (1) b.ID_BACKUP, b.TIPO, b.ARQUIVO, b.DT_INICIO, b.DT_FIM, b.ARQUIVO_EXISTE
    FROM SIS.Backup_Execucao b
    WHERE b.SITUACAO = 'OK'
      AND b.ARQUIVO <> N''
      AND (   (@IdBackup IS NOT NULL AND b.ID_BACKUP = @IdBackup AND b.TIPO IN ('COMPLETO', 'SEGURANCA'))
           OR (@IdBackup IS NULL AND @DtPonto IS NOT NULL AND b.TIPO = 'COMPLETO' AND b.ARQUIVO_EXISTE = 1 AND b.DT_FIM <= @DtPonto))
    ORDER BY b.DT_FIM DESC, b.ID_BACKUP DESC
),
Corte AS
(
    SELECT MIN(l.DT_INICIO) AS DT_CORTE
    FROM SIS.Backup_Execucao l
    INNER JOIN Base b ON l.DT_INICIO >= b.DT_INICIO
    WHERE @IdBackup IS NULL
      AND l.TIPO = 'LOG'
      AND l.SITUACAO = 'OK'
      AND l.DT_FIM >= @DtPonto
)
SELECT CAST(0 AS INT) AS ORDEM, b.ID_BACKUP, b.TIPO, b.ARQUIVO, b.DT_INICIO, b.DT_FIM, b.ARQUIVO_EXISTE,
       CAST(CASE WHEN @IdBackup IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS ALCANCA_PONTO
FROM Base b
UNION ALL
SELECT CAST(ROW_NUMBER() OVER (ORDER BY l.DT_INICIO, l.ID_BACKUP) AS INT), l.ID_BACKUP, l.TIPO, l.ARQUIVO, l.DT_INICIO, l.DT_FIM, l.ARQUIVO_EXISTE,
       CAST(CASE WHEN l.DT_INICIO = c.DT_CORTE THEN 1 ELSE 0 END AS BIT)
FROM SIS.Backup_Execucao l
INNER JOIN Base b  ON l.DT_INICIO >= b.DT_INICIO
INNER JOIN Corte c ON c.DT_CORTE IS NOT NULL AND l.DT_INICIO <= c.DT_CORTE
WHERE @IdBackup IS NULL
  AND l.TIPO = 'LOG'
  AND l.SITUACAO = 'OK';
GO
