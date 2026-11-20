/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Conferir_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Rotina agendada (BACKUP_CONFERIR, de hora em hora): avisa por
                e-mail (parâmetro EMAIL_ADMIN_ALERTA) quando o backup ATRASA:
                  - último backup COMPLETO ok há mais de BACKUP_HORAS_ALERTA_COMPLETO;
                  - último backup do LOG ok há mais de BACKUP_HORAS_ALERTA_LOG
                    (só depois do primeiro completo);
                  - último TESTE de restauração ok há mais de BACKUP_DIAS_ALERTA_TESTE.
                Cada aviso sai no máximo uma vez por dia (chave de origem com a
                data). Sem nenhum backup registrado ainda: não avisa (servidor
                recém-instalado).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Conferir_Processar]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Para NVARCHAR(400) = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
    DECLARE @HorasCompleto INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_HORAS_ALERTA_COMPLETO'), 26);
    DECLARE @HorasLog INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_HORAS_ALERTA_LOG'), 3);
    DECLARE @DiasTeste INT = ISNULL(SIS.fn_SIS_Parametro_Inteiro('BACKUP_DIAS_ALERTA_TESTE'), 8);
    DECLARE @UltCompleto DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK');
    DECLARE @UltLog DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO IN ('LOG', 'COMPLETO') AND b.SITUACAO = 'OK');
    DECLARE @UltTeste DATETIME2(0) = (SELECT MAX(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'TESTE' AND b.SITUACAO = 'OK');
    DECLARE @Agora DATETIME2(0) = SYSDATETIME();
    DECLARE @Problemas NVARCHAR(MAX) = N'';
    DECLARE @Corpo NVARCHAR(MAX), @IdEmail BIGINT, @Chave NVARCHAR(200);

    IF @Para = N'' OR NOT EXISTS (SELECT 1 FROM SIS.Backup_Execucao) RETURN;

    IF @UltCompleto IS NULL OR @UltCompleto < DATEADD(HOUR, -@HorasCompleto, @Agora)
        SET @Problemas += N'<li>Backup completo: o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltCompleto), N'(nenhum)') + N'.</li>';
    IF @UltCompleto IS NOT NULL AND @UltLog < DATEADD(HOUR, -@HorasLog, @Agora)
        SET @Problemas += N'<li>Backup do log (de hora em hora): o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltLog), N'(nenhum)') + N'.</li>';
    -- teste: só cobra depois que o servidor tem backups há mais de @DiasTeste dias
    IF (SELECT MIN(b.DT_INICIO) FROM SIS.Backup_Execucao b WHERE b.TIPO = 'COMPLETO' AND b.SITUACAO = 'OK') < DATEADD(DAY, -@DiasTeste, @Agora)
       AND (@UltTeste IS NULL OR @UltTeste < DATEADD(DAY, -@DiasTeste, @Agora))
        SET @Problemas += N'<li>Teste de restauração: o último sem erro foi em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@UltTeste), N'(nenhum)') + N'.</li>';

    IF @Problemas = N'' RETURN;

    SET @Corpo = SIS.fn_SIS_Email_HTML(N'Backup atrasado', 'ALERTA',
        N'<p>O backup do banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b> está atrasado:</p><ul>' + @Problemas + N'</ul>'
        + N'<p>Confira se o servidor ficou desligado, se as tarefas "SisCMJ - Backup" estão ativas no Agendador de Tarefas e o arquivo backup.log na pasta do backup.</p>',
        N'[SIS].[SIS_Backup_Conferir_Processar]', NULL, 0);
    SET @Chave = N'BACKUP_ATRASO_' + CONVERT(NVARCHAR(8), @Agora, 112);
    EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: backup do sistema atrasado', @CorpoHTML = @Corpo,
         @Tipo = 'ALERTA', @Origem = N'[SIS].[SIS_Backup_Conferir_Processar]',
         @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
END;
GO
