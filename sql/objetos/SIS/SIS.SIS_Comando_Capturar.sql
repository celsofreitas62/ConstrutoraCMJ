/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Capturar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço do sistema. Pega o pedido de comando
                PENDENTE mais antigo e marca EXECUTANDO; um comando de cada
                vez (se já existe um executando, não devolve nada).
                Devolve 0 ou 1 linha: ID_PEDIDO, CODIGO, PARAMETRO. O
                serviço executa o que estiver na SUA lista fixa para o
                CODIGO e chama SIS_Comando_Resultado_Gravar.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Capturar @Servidor = N'TESTE';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Capturar]
    @Servidor  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Capturar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Captura';
    DECLARE @IdPedido   BIGINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM SIS.Comando_Fila f WITH (UPDLOCK, HOLDLOCK) WHERE f.STATUS = 'EXECUTANDO')
        BEGIN
            SELECT TOP (1) @IdPedido = f.ID_PEDIDO
            FROM SIS.Comando_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE f.STATUS = 'PENDENTE'
            ORDER BY f.ID_PEDIDO;

            IF @IdPedido IS NOT NULL
                UPDATE SIS.Comando_Fila
                   SET STATUS = 'EXECUTANDO', DT_INICIO = SYSDATETIME(), SERVIDOR = LEFT(ISNULL(@Servidor, N''), 128)
                WHERE ID_PEDIDO = @IdPedido;
        END;

        COMMIT TRANSACTION;

        SELECT f.ID_PEDIDO, c.CODIGO, f.PARAMETRO
        FROM SIS.Comando_Fila f
        INNER JOIN SIS.Comando c ON c.ID_COMANDO = f.ID_COMANDO
        WHERE f.ID_PEDIDO = @IdPedido;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
