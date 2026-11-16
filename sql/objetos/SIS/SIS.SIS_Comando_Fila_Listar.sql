/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Fila_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Histórico dos pedidos de comandos (tela "Instalação e
                manutenção"), mais recente primeiro. @IdPedido informado:
                só aquele pedido, com a saída completa (para a janela de
                detalhe); sem ele, a saída vem cortada em 500 caracteres.
                Permissão: VER em SIS_INSTALACAO.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Fila_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Fila_Listar]
    @IdUsuario  INT,
    @IdPedido   BIGINT = NULL,
    @MaxLinhas  INT    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Fila_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para a tela de instalação e manutenção.', 1;

        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 2000 THEN 200 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               f.ID_PEDIDO, c.CODIGO, c.NOME, f.PARAMETRO, f.STATUS, f.DT_PEDIDO, f.USUARIO_PEDIDO, f.ESTACAO_PEDIDO,
               f.DT_INICIO, f.DT_FIM, f.SERVIDOR, f.CODIGO_SAIDA,
               CASE WHEN @IdPedido IS NULL AND LEN(f.SAIDA) > 500 THEN LEFT(f.SAIDA, 500) + N' (...)' ELSE f.SAIDA END AS SAIDA,
               f.DT_CANCELAMENTO, f.USUARIO_CANCELAMENTO
        FROM SIS.Comando_Fila f WITH (NOLOCK)
        INNER JOIN SIS.Comando c ON c.ID_COMANDO = f.ID_COMANDO
        WHERE (@IdPedido IS NULL OR f.ID_PEDIDO = @IdPedido)
        ORDER BY f.ID_PEDIDO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os pedidos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
