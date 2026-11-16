/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Rotina_Proxima]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Próxima data e hora de execução de uma rotina, depois de
                @Base (sempre maior que @Base):
                  MINUTOS : @Base + intervalo;
                  DIARIA  : próximo dia no HORARIO;
                  SEMANAL : próximo dia da lista DIAS_SEMANA (1 = domingo
                            ... 7 = sábado) no HORARIO;
                  MENSAL  : próximo mês no DIA_MES (se o mês não tem o dia,
                            ex.: 31 em abril, usa o último dia) no HORARIO.
                Dia da semana calculado sem depender do SET DATEFIRST
                (07/01/1900 foi domingo). Agenda inválida devolve NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '08:00', '2,4', 0, '2026-11-16T09:00:00');  -- 18/11 08:00
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Rotina_Proxima]
(
    @Frequencia  VARCHAR(10),
    @Intervalo   INT,
    @Horario     TIME(0),
    @DiasSemana  VARCHAR(20),
    @DiaMes      TINYINT,
    @Base        DATETIME2(0)
)
RETURNS DATETIME2(0)
AS
BEGIN
    DECLARE @Dia       DATE         = CAST(@Base AS DATE);
    DECLARE @Hora      TIME(0)      = ISNULL(@Horario, '00:00');
    DECLARE @Candidato DATETIME2(0);
    DECLARE @N         INT          = 0;
    DECLARE @Mes1      DATE;
    DECLARE @DiaUsado  INT;

    IF @Base IS NULL RETURN NULL;

    IF @Frequencia = 'MINUTOS'
    BEGIN
        IF ISNULL(@Intervalo, 0) < 1 RETURN NULL;
        RETURN DATEADD(MINUTE, @Intervalo, @Base);
    END;

    IF @Frequencia = 'DIARIA'
    BEGIN
        SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora), CAST(@Dia AS DATETIME2(0)));
        IF @Candidato <= @Base SET @Candidato = DATEADD(DAY, 1, @Candidato);
        RETURN @Candidato;
    END;

    IF @Frequencia = 'SEMANAL'
    BEGIN
        WHILE @N <= 7
        BEGIN
            IF CHARINDEX(',' + CAST(DATEDIFF(DAY, '19000107', DATEADD(DAY, @N, @Dia)) % 7 + 1 AS VARCHAR(1)) + ',', ',' + ISNULL(@DiasSemana, '') + ',') > 0
            BEGIN
                SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora), CAST(DATEADD(DAY, @N, @Dia) AS DATETIME2(0)));
                IF @Candidato > @Base RETURN @Candidato;
            END;
            SET @N = @N + 1;
        END;
        RETURN NULL;
    END;

    IF @Frequencia = 'MENSAL'
    BEGIN
        IF ISNULL(@DiaMes, 0) NOT BETWEEN 1 AND 31 RETURN NULL;
        SET @Mes1 = DATEFROMPARTS(YEAR(@Dia), MONTH(@Dia), 1);
        WHILE @N <= 2
        BEGIN
            SET @DiaUsado = CASE WHEN @DiaMes > DAY(EOMONTH(DATEADD(MONTH, @N, @Mes1))) THEN DAY(EOMONTH(DATEADD(MONTH, @N, @Mes1))) ELSE @DiaMes END;
            SET @Candidato = DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00' AS TIME(0)), @Hora),
                                     CAST(DATEADD(DAY, @DiaUsado - 1, DATEADD(MONTH, @N, @Mes1)) AS DATETIME2(0)));
            IF @Candidato > @Base RETURN @Candidato;
            SET @N = @N + 1;
        END;
        RETURN NULL;
    END;

    RETURN NULL;
END;
GO
