/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Previa_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Rotina semanal (SIS.Rotina COMUNICADO_PREVIA, sexta 9h): gera a
                prévia de cada comunicado ativo. Um comunicado com problema não
                impede os outros (laço isolado, regra 13); no fim, se algum falhou,
                relança um erro agregado para a rotina registrar ERRO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Previa_Processar]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Previa_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Laço';
    DECLARE @Id         INT           = 0;
    DECLARE @Proximo    INT;
    DECLARE @Falhas     NVARCHAR(MAX) = N'';
    DECLARE @Res        TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);

    WHILE 1 = 1
    BEGIN
        SET @Proximo = NULL;
        SELECT TOP (1) @Proximo = c.ID_COMUNICADO
        FROM SIS.Comunicado c
        WHERE c.ATIVO = 1 AND c.ID_COMUNICADO > @Id
        ORDER BY c.ID_COMUNICADO;
        IF @Proximo IS NULL BREAK;
        SET @Id = @Proximo;

        BEGIN TRY
            DELETE FROM @Res;
            INSERT INTO @Res (SUCESSO, MENSAGEM, ID)
            EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = NULL, @IdComunicado = @Id;

            SELECT @Falhas = @Falhas + N' [' + CONVERT(NVARCHAR(10), @Id) + N'] ' + r.MENSAGEM
            FROM @Res r
            WHERE r.SUCESSO = 0;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SET @Falhas = @Falhas + N' [' + CONVERT(NVARCHAR(10), @Id) + N'] ' + ERROR_MESSAGE();
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;
    END;

    IF @Falhas <> N''
    BEGIN
        SET @Falhas = LEFT(N'Comunicados com problema:' + @Falhas, 2000);
        THROW 50001, @Falhas, 1;
    END;
END;
GO
