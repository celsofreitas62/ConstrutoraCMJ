/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Rotinas automáticas": muda a agenda de uma rotina e
                liga/desliga. A rotina em si (qual procedure roda) só muda
                por carga: pela tela não se cadastra rotina nova.
                @Frequencia MINUTOS usa @IntervaloMinutos (1 a 1440);
                DIARIA usa @Horario ('HH:MM'); SEMANAL usa @DiasSemana
                ('2,4', 1 = domingo) e @Horario; MENSAL usa @DiaMes (1 a 31;
                31 = último dia) e @Horario. Os campos que a frequência não
                usa são zerados.
                Recalcula a próxima execução (desligada = sem próxima).
                Permissão: ALTERAR em SIS_ROTINA (tela exclusiva do
                administrador geral). Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Gravar @IdUsuario = 2, @Codigo = 'LOG_LIMPEZA', @Ativa = 1, @Frequencia = 'DIARIA', @Horario = '03:10';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Gravar]
    @IdUsuario           INT,
    @Codigo              VARCHAR(40),
    @Ativa               BIT,
    @Frequencia          VARCHAR(10),
    @IntervaloMinutos    INT         = NULL,
    @Horario             VARCHAR(5)  = NULL,
    @DiasSemana          VARCHAR(20) = NULL,
    @DiaMes              TINYINT     = NULL,
    @TempoLimiteMinutos  INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @IdRotina   INT;
    DECLARE @Hora       TIME(0);
    DECLARE @Dias       VARCHAR(20)   = '';
    DECLARE @Proxima    DATETIME2(0);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para alterar as rotinas automáticas.';

        SET @Codigo     = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Frequencia = UPPER(LTRIM(RTRIM(ISNULL(@Frequencia, ''))));
        SET @Ativa      = ISNULL(@Ativa, 0);

        IF @Recusa = N''
        BEGIN
            SELECT @IdRotina = r.ID_ROTINA, @TempoLimiteMinutos = ISNULL(@TempoLimiteMinutos, r.TEMPO_LIMITE_MINUTOS)
            FROM SIS.Rotina r WHERE r.CODIGO = @Codigo;
            IF @IdRotina IS NULL SET @Recusa = N'Rotina não encontrada.';
        END;

        IF @Recusa = N'' AND @Frequencia NOT IN ('MINUTOS', 'DIARIA', 'SEMANAL', 'MENSAL')
            SET @Recusa = N'Escolha a frequência: a cada X minutos, diária, semanal ou mensal.';

        IF @Recusa = N'' AND @Frequencia = 'MINUTOS' AND ISNULL(@IntervaloMinutos, 0) NOT BETWEEN 1 AND 1440
            SET @Recusa = N'Informe o intervalo em minutos (de 1 a 1440).';

        IF @Recusa = N'' AND @Frequencia <> 'MINUTOS'
        BEGIN
            SET @Hora = TRY_CONVERT(TIME(0), LTRIM(RTRIM(ISNULL(@Horario, ''))));
            IF @Hora IS NULL OR LEN(LTRIM(RTRIM(@Horario))) <> 5 SET @Recusa = N'Informe o horário no formato HH:MM (ex.: 03:10).';
        END;

        IF @Recusa = N'' AND @Frequencia = 'SEMANAL'
        BEGIN
            IF EXISTS (SELECT 1 FROM STRING_SPLIT(REPLACE(ISNULL(@DiasSemana, ''), ' ', ''), ',') s
                       WHERE s.value <> '' AND ISNULL(TRY_CAST(s.value AS INT), 0) NOT BETWEEN 1 AND 7)
                SET @Recusa = N'Dias da semana inválidos (1 = domingo ... 7 = sábado).';
            ELSE
                SELECT @Dias = ISNULL(STRING_AGG(CAST(d.N AS VARCHAR(1)), ',') WITHIN GROUP (ORDER BY d.N), '')
                FROM (SELECT DISTINCT TRY_CAST(s.value AS INT) AS N
                      FROM STRING_SPLIT(REPLACE(ISNULL(@DiasSemana, ''), ' ', ''), ',') s WHERE s.value <> '') d;
            IF @Recusa = N'' AND @Dias = '' SET @Recusa = N'Escolha ao menos um dia da semana.';
        END;

        IF @Recusa = N'' AND @Frequencia = 'MENSAL' AND ISNULL(@DiaMes, 0) NOT BETWEEN 1 AND 31
            SET @Recusa = N'Informe o dia do mês (1 a 31; 31 = último dia).';

        IF @Recusa = N'' AND ISNULL(@TempoLimiteMinutos, 0) NOT BETWEEN 1 AND 1440
            SET @Recusa = N'Tempo limite inválido (de 1 a 1440 minutos).';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
            RETURN;
        END;

        IF @Frequencia <> 'MINUTOS' SET @IntervaloMinutos = 0;
        IF @Frequencia = 'MINUTOS'  SET @Hora = '00:00';
        IF @Frequencia <> 'MENSAL'  SET @DiaMes = 0;

        SET @Proxima = CASE WHEN @Ativa = 1 THEN SIS.fn_SIS_Rotina_Proxima(@Frequencia, @IntervaloMinutos, @Hora, @Dias, @DiaMes, SYSDATETIME()) END;
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE r
           SET r.ATIVA                = @Ativa,
               r.FREQUENCIA           = @Frequencia,
               r.INTERVALO_MINUTOS    = @IntervaloMinutos,
               r.HORARIO              = @Hora,
               r.DIAS_SEMANA          = @Dias,
               r.DIA_MES              = @DiaMes,
               r.TEMPO_LIMITE_MINUTOS = @TempoLimiteMinutos,
               r.PROXIMA_EXECUCAO     = CASE WHEN r.EM_EXECUCAO = 1 THEN r.PROXIMA_EXECUCAO ELSE @Proxima END,
               r.DT_ALTERACAO         = SYSDATETIME(),
               r.USUARIO_ALTERACAO    = @Usuario
        FROM SIS.Rotina r
        WHERE r.ID_ROTINA = @IdRotina;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Ativa = 0 THEN N'Rotina desligada: não roda mais pela agenda.'
                         ELSE N'Agenda gravada. Próxima execução: ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@Proxima), N'-') + N'.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdRotina AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a rotina. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdRotina AS ID;
    END CATCH;
END;
GO
