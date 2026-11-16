/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Rotinas automáticas" (exclusiva do administrador
                geral): cada rotina com a agenda em texto ("A cada 10 min",
                "Diária às 03:10", "Semanal (seg, qua) às 08:00", "Mensal
                no dia 5 às 07:00"), situação, última e próxima execução.
                MODULO_DISPONIVEL = 0: o módulo da rotina está fora da
                licença ou desabilitado (a rotina não roda).
                Permissão: VER em SIS_ROTINA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Rotina_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_ROTINA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as rotinas automáticas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT r.ID_ROTINA, r.CODIGO, r.NOME, r.DESCRICAO, m.CODIGO AS MODULO_CODIGO,
               CAST(CASE WHEN m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1 THEN 1 ELSE 0 END AS BIT) AS MODULO_DISPONIVEL,
               r.FREQUENCIA, r.INTERVALO_MINUTOS, CONVERT(VARCHAR(5), r.HORARIO, 108) AS HORARIO, r.DIAS_SEMANA, r.DIA_MES,
               CAST(CASE r.FREQUENCIA
                        WHEN 'MINUTOS' THEN N'A cada ' + CAST(r.INTERVALO_MINUTOS AS NVARCHAR(10)) + N' min'
                        WHEN 'DIARIA'  THEN N'Diária às ' + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                        WHEN 'SEMANAL' THEN N'Semanal (' + ISNULL((SELECT STRING_AGG(CHOOSE(TRY_CAST(s.value AS INT), N'dom', N'seg', N'ter', N'qua', N'qui', N'sex', N'sáb'), N', ')
                                                                          WITHIN GROUP (ORDER BY TRY_CAST(s.value AS INT))
                                                                   FROM STRING_SPLIT(r.DIAS_SEMANA, ',') s WHERE s.value <> ''), N'') + N') às ' + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                        ELSE CASE WHEN r.DIA_MES = 31 THEN N'Mensal no último dia às ' ELSE N'Mensal no dia ' + CAST(r.DIA_MES AS NVARCHAR(3)) + N' às ' END + CONVERT(NVARCHAR(5), r.HORARIO, 108)
                    END AS NVARCHAR(200)) AS AGENDA_TEXTO,
               r.TEMPO_LIMITE_MINUTOS, r.ATIVA, r.EM_EXECUCAO, r.PROXIMA_EXECUCAO, r.SOLICITADA_POR,
               r.ULTIMA_EXECUCAO, r.ULTIMO_RESULTADO, r.ULTIMA_MENSAGEM, r.PROCEDIMENTO
        FROM SIS.Rotina r
        INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
        ORDER BY m.ORDEM_MENU, r.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as rotinas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
