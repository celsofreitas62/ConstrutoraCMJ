/*******************************************************************************
  Objeto      : [SIS].[SIS_Comando_Solicitar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Botão de um comando na tela "Instalação e manutenção": grava o
                pedido em SIS.Comando_Fila para o serviço executar. Não
                executa nada no Windows.
                - Comando PERIGOSO: a API só chama esta procedure depois de
                  pedir a senha de novo e a confirmação.
                - @Parametro: só para comando que aceita (e aí é
                  obrigatório). Recusa caracteres que poderiam virar outro
                  comando (& | ; < > ` " ' % ^ e quebra de linha); o serviço
                  valida de novo.
                - Recusa se o mesmo comando já está pendente ou executando.
                Permissão: EXECUTAR em SIS_INSTALACAO (tela exclusiva do
                administrador geral). Devolve SUCESSO, MENSAGEM, ID
                (ID = número do pedido).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Comando_Solicitar @IdUsuario = 2, @Codigo = 'DISCO_ESPACO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comando_Solicitar]
    @IdUsuario  INT,
    @Codigo     VARCHAR(40),
    @Parametro  NVARCHAR(400) = NULL,
    @Estacao    NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comando_Solicitar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @IdComando  INT;
    DECLARE @Aceita     BIT;
    DECLARE @IdPedido   BIGINT;

    BEGIN TRY
        SET @Codigo    = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Parametro = LTRIM(RTRIM(ISNULL(@Parametro, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_INSTALACAO', 'EXECUTAR') = 0
            SET @Recusa = N'Você não tem permissão para executar comandos de instalação e manutenção.';

        IF @Recusa = N''
        BEGIN
            SELECT @IdComando = c.ID_COMANDO, @Aceita = c.ACEITA_PARAMETRO
            FROM SIS.Comando c WHERE c.CODIGO = @Codigo AND c.ATIVO = 1;
            IF @IdComando IS NULL SET @Recusa = N'Comando não encontrado.';
        END;

        IF @Recusa = N'' AND @Aceita = 0 AND @Parametro <> N''
            SET @Recusa = N'Este comando não recebe valor.';
        IF @Recusa = N'' AND @Aceita = 1 AND @Parametro = N''
            SET @Recusa = N'Informe o valor pedido pelo comando.';
        IF @Recusa = N'' AND @Parametro <> N''
           AND (   @Parametro LIKE N'%[&|;<>`"''%^]%'
                OR CHARINDEX(NCHAR(13), @Parametro) > 0 OR CHARINDEX(NCHAR(10), @Parametro) > 0 OR CHARINDEX(N'..', @Parametro) > 0)
            SET @Recusa = N'O valor tem caracteres não permitidos.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM SIS.Comando_Fila f WITH (UPDLOCK, HOLDLOCK)
                   WHERE f.ID_COMANDO = @IdComando AND f.STATUS IN ('PENDENTE', 'EXECUTANDO'))
        BEGIN
            COMMIT TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Este comando já está na fila ou em execução.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        INSERT INTO SIS.Comando_Fila (ID_COMANDO, PARAMETRO, USUARIO_PEDIDO, ESTACAO_PEDIDO)
        VALUES (@IdComando, @Parametro, SIS.fn_SIS_Usuario_Login(@IdUsuario),
                LEFT(ISNULL(NULLIF(@Estacao, N''), ISNULL(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'ESTACAO')), N'')), 128));
        SET @IdPedido = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Pedido registrado. Acompanhe o resultado nesta tela.' AS NVARCHAR(400)) AS MENSAGEM, @IdPedido AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
        VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível registrar o pedido. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
