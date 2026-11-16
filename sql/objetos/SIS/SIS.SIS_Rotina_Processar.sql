/*******************************************************************************
  Objeto      : [SIS].[SIS_Rotina_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Agendador das rotinas automáticas (substitui o SQL Agent, que
                o Express não tem). O serviço do sistema chama a cada minuto.
                1) Rotina presa além do TEMPO_LIMITE_MINUTOS (o serviço caiu
                   no meio): fecha a execução como ERRO e reagenda.
                2) Roda, uma de cada vez e até @Maximo, as rotinas vencidas:
                   ativas (ou pedidas em "executar agora"), não em execução,
                   com o módulo na licença e habilitado. A captura usa
                   UPDLOCK + READPAST: duas chamadas nunca rodam a mesma.
                3) Cada rotina roda com o contexto do usuário interno
                   "sistema" (a auditoria mostra "sistema" e a origem
                   "rotina:<CODIGO>"), por EXEC da procedure cadastrada em
                   SIS.Rotina (precisa existir e não ter parâmetros).
                4) Grava o resultado em SIS.Rotina_Execucao e em SIS.Rotina e
                   calcula a próxima execução (fn_SIS_Rotina_Proxima). Erro
                   da rotina vai também para SIS.Log_Erro e não impede as
                   outras de rodar.
                Devolve 1 linha: QTD_EXECUTADAS, QTD_ERRO, QTD_LIBERADAS
                (@Silencioso = 1: não devolve nada).
                Não roda dentro de transação aberta (nem via INSERT-EXEC):
                cada rotina precisa controlar a própria transação.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Rotina_Processar @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Rotina_Processar]
    @Servidor  NVARCHAR(128),
    @Maximo      INT = 10,
    @Silencioso  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Rotina_Processar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Rotinas presas';
    DECLARE @IdSistema   INT           = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema');
    DECLARE @Feitas      INT           = 0;
    DECLARE @Erros       INT           = 0;
    DECLARE @Liberadas   INT           = 0;
    DECLARE @IdRotina    INT;
    DECLARE @Codigo      VARCHAR(40);
    DECLARE @Proc        NVARCHAR(256);
    DECLARE @Solicitante NVARCHAR(100);
    DECLARE @IdExecucao  BIGINT;
    DECLARE @Inicio      DATETIME2(0);
    DECLARE @ObjId       INT;
    DECLARE @Sql         NVARCHAR(600);
    DECLARE @Resultado   VARCHAR(10);
    DECLARE @Msg         NVARCHAR(1000);
    DECLARE @OrigemCtx   NVARCHAR(256);
    DECLARE @Presas      TABLE (ID_ROTINA INT PRIMARY KEY);

    IF @@TRANCOUNT > 0
        THROW 50001, N'O agendador de rotinas não pode rodar dentro de uma transação.', 1;

    BEGIN TRY
        SET @Servidor = LEFT(ISNULL(@Servidor, N''), 128);
        SET @Maximo   = CASE WHEN ISNULL(@Maximo, 0) < 1 THEN 10 WHEN @Maximo > 100 THEN 100 ELSE @Maximo END;

        -- 1) Presas além do tempo limite
        BEGIN TRANSACTION;

        UPDATE r
           SET r.EM_EXECUCAO      = 0,
               r.ULTIMO_RESULTADO = 'ERRO',
               r.ULTIMA_MENSAGEM  = N'Passou do tempo limite de ' + CAST(r.TEMPO_LIMITE_MINUTOS AS NVARCHAR(10)) + N' min sem terminar (o serviço pode ter parado).',
               r.SOLICITADA_POR   = N'',
               r.PROXIMA_EXECUCAO = CASE WHEN r.ATIVA = 1 THEN SIS.fn_SIS_Rotina_Proxima(r.FREQUENCIA, r.INTERVALO_MINUTOS, r.HORARIO, r.DIAS_SEMANA, r.DIA_MES, SYSDATETIME()) END
        OUTPUT inserted.ID_ROTINA INTO @Presas (ID_ROTINA)
        FROM SIS.Rotina r WITH (UPDLOCK, READPAST, ROWLOCK)
        WHERE r.EM_EXECUCAO = 1
          AND r.DT_INICIO_EXECUCAO < DATEADD(MINUTE, -r.TEMPO_LIMITE_MINUTOS, SYSDATETIME());

        UPDATE e
           SET e.RESULTADO = 'ERRO', e.DT_FIM = SYSDATETIME(), e.MENSAGEM = N'Passou do tempo limite sem terminar.'
        FROM SIS.Rotina_Execucao e
        INNER JOIN @Presas p ON p.ID_ROTINA = e.ID_ROTINA
        WHERE e.RESULTADO = 'EXECUTANDO';

        SET @Liberadas = (SELECT COUNT(*) FROM @Presas);
        COMMIT TRANSACTION;

        -- 2) Vencidas, uma de cada vez
        WHILE @Feitas < @Maximo
        BEGIN
            SET @EtapaAtual = 'Captura';
            SET @IdRotina = NULL;

            BEGIN TRANSACTION;

            SELECT TOP (1) @IdRotina = r.ID_ROTINA, @Codigo = r.CODIGO, @Proc = r.PROCEDIMENTO, @Solicitante = r.SOLICITADA_POR
            FROM SIS.Rotina r WITH (UPDLOCK, READPAST, ROWLOCK)
            INNER JOIN SIS.Modulo m ON m.ID_MODULO = r.ID_MODULO
            WHERE r.EM_EXECUCAO = 0
              AND r.PROXIMA_EXECUCAO <= SYSDATETIME()
              AND (r.ATIVA = 1 OR r.SOLICITADA_POR <> N'')
              AND m.ATIVO = 1 AND m.LIBERADO_LICENCA = 1 AND m.HABILITADO = 1
            ORDER BY r.PROXIMA_EXECUCAO, r.ID_ROTINA;

            IF @IdRotina IS NULL
            BEGIN
                COMMIT TRANSACTION;
                BREAK;
            END;

            SET @Inicio = SYSDATETIME();
            UPDATE SIS.Rotina SET EM_EXECUCAO = 1, DT_INICIO_EXECUCAO = @Inicio WHERE ID_ROTINA = @IdRotina;

            INSERT INTO SIS.Rotina_Execucao (ID_ROTINA, ORIGEM, SOLICITANTE, SERVIDOR, DT_INICIO)
            VALUES (@IdRotina, CASE WHEN @Solicitante <> N'' THEN 'MANUAL' ELSE 'AGENDA' END, @Solicitante, @Servidor, @Inicio);
            SET @IdExecucao = SCOPE_IDENTITY();

            COMMIT TRANSACTION;

            -- 3) Execução
            SET @EtapaAtual = LEFT('Rotina ' + @Codigo, 100);
            SET @Resultado  = 'OK';
            SET @Msg        = N'';

            BEGIN TRY
                SET @OrigemCtx = N'rotina:' + @Codigo;
                EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Estacao = @Servidor, @Origem = @OrigemCtx;

                SET @ObjId = OBJECT_ID(@Proc, N'P');
                IF @ObjId IS NULL
                    THROW 50001, N'A procedure cadastrada para a rotina não existe.', 1;
                IF EXISTS (SELECT 1 FROM sys.parameters p WHERE p.object_id = @ObjId)
                    THROW 50001, N'A procedure da rotina não pode ter parâmetros.', 1;

                SET @Sql = N'EXEC ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N';';
                EXEC sys.sp_executesql @Sql;

                IF @@TRANCOUNT > 0
                BEGIN
                    ROLLBACK TRANSACTION;
                    THROW 50001, N'A rotina terminou com uma transação aberta (desfeita).', 1;
                END;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

                SET @Resultado = 'ERRO';
                SET @Msg       = LEFT(ERROR_MESSAGE(), 1000);

                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
            END CATCH;

            EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

            -- 4) Resultado e próxima execução
            SET @EtapaAtual = 'Resultado';
            UPDATE r
               SET r.EM_EXECUCAO      = 0,
                   r.ULTIMA_EXECUCAO  = @Inicio,
                   r.ULTIMO_RESULTADO = @Resultado,
                   r.ULTIMA_MENSAGEM  = @Msg,
                   r.SOLICITADA_POR   = N'',
                   r.PROXIMA_EXECUCAO = CASE WHEN r.ATIVA = 1 THEN SIS.fn_SIS_Rotina_Proxima(r.FREQUENCIA, r.INTERVALO_MINUTOS, r.HORARIO, r.DIAS_SEMANA, r.DIA_MES, SYSDATETIME()) END
            FROM SIS.Rotina r
            WHERE r.ID_ROTINA = @IdRotina;

            UPDATE SIS.Rotina_Execucao
               SET DT_FIM = SYSDATETIME(), RESULTADO = @Resultado, MENSAGEM = @Msg
            WHERE ID_EXECUCAO = @IdExecucao;

            SET @Feitas = @Feitas + 1;
            IF @Resultado = 'ERRO' SET @Erros = @Erros + 1;
        END;

        IF ISNULL(@Silencioso, 0) = 0
            SELECT @Feitas AS QTD_EXECUTADAS, @Erros AS QTD_ERRO, @Liberadas AS QTD_LIBERADAS;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
