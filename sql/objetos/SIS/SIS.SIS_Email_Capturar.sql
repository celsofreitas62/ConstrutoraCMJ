/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Capturar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Usada só pelo serviço do sistema (a cada minuto). Pega até
                @Quantidade e-mails PENDENTES já no horário, marca como
                PROCESSANDO e soma 1 tentativa, numa única instrução com
                UPDLOCK + READPAST: dois serviços (ou duas chamadas) nunca
                pegam o mesmo e-mail.
                Devolve um e-mail por linha, com os anexos em JSON
                (ANEXOS_JSON: [{"CAMINHO","NOME_EXIBICAO","CID"}]).
                Depois de tentar enviar, o serviço chama
                SIS_Email_Resultado_Gravar para cada um.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Capturar @Servidor = N'TESTE', @Quantidade = 5;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Capturar]
    @Servidor    NVARCHAR(128),
    @Quantidade  INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Capturar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Captura';
    DECLARE @Agora      DATETIME2(0)  = SYSDATETIME();
    DECLARE @Pegos      TABLE (ID_EMAIL BIGINT PRIMARY KEY);

    BEGIN TRY
        SET @Quantidade = CASE WHEN ISNULL(@Quantidade, 0) < 1 THEN 20 WHEN @Quantidade > 200 THEN 200 ELSE @Quantidade END;

        WITH c AS
        (
            SELECT TOP (@Quantidade) f.ID_EMAIL, f.STATUS, f.TENTATIVAS, f.DT_CAPTURA, f.SERVIDOR
            FROM SIS.Email_Fila f WITH (UPDLOCK, READPAST, ROWLOCK)
            WHERE f.STATUS = 'PENDENTE'
              AND f.PROXIMA_TENTATIVA <= @Agora
            ORDER BY f.PROXIMA_TENTATIVA, f.ID_EMAIL
        )
        UPDATE c
           SET c.STATUS     = 'PROCESSANDO',
               c.TENTATIVAS = c.TENTATIVAS + 1,
               c.DT_CAPTURA = @Agora,
               c.SERVIDOR   = LEFT(ISNULL(@Servidor, N''), 128)
        OUTPUT inserted.ID_EMAIL INTO @Pegos (ID_EMAIL);

        SET @EtapaAtual = 'Retorno';
        SELECT f.ID_EMAIL, f.TIPO, f.CONTA, f.PARA, f.CC, f.CCO, f.ASSUNTO, f.CORPO_HTML, f.TENTATIVAS, f.MODO_TESTE,
               ISNULL((SELECT a.CAMINHO, a.NOME_EXIBICAO, a.CID
                       FROM SIS.Email_Fila_Anexo a
                       WHERE a.ID_EMAIL = f.ID_EMAIL
                       ORDER BY a.ORDEM, a.ID_EMAIL_ANEXO
                       FOR JSON PATH), N'[]') AS ANEXOS_JSON
        FROM SIS.Email_Fila f
        INNER JOIN @Pegos p ON p.ID_EMAIL = f.ID_EMAIL
        ORDER BY f.ID_EMAIL;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
