/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Detalhe de um e-mail da fila para a tela (pré-visualizar o
                corpo, ver anexos e o histórico de tentativas).
                Devolve 3 conjuntos: 1) o e-mail com o corpo; 2) os anexos;
                3) o histórico (SIS.Email_Log), mais recente primeiro.
                Permissão: VER em SIS_EMAIL_FILA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Obter @IdUsuario = 2, @IdEmail = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Obter]
    @IdUsuario  INT,
    @IdEmail    BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os e-mails do sistema.', 1;

        IF NOT EXISTS (SELECT 1 FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @IdEmail)
            THROW 50001, N'E-mail não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT f.ID_EMAIL, f.DT_CRIACAO, f.TIPO, f.CONTA, f.STATUS, f.PARA, f.CC, f.CCO, f.PARA_ORIGINAL, f.ASSUNTO, f.CORPO_HTML,
               f.TENTATIVAS, f.DT_ENVIO, f.ULTIMO_ERRO, f.MODO_TESTE, f.ORIGEM, f.GRUPO, f.CHAVE_ORIGEM, f.ID_LOTE, f.USUARIO_CRIACAO
        FROM SIS.Email_Fila f
        WHERE f.ID_EMAIL = @IdEmail;

        SELECT a.ID_EMAIL_ANEXO, a.NOME_EXIBICAO, a.CAMINHO, a.CID, a.ORDEM
        FROM SIS.Email_Fila_Anexo a
        WHERE a.ID_EMAIL = @IdEmail
        ORDER BY a.ORDEM, a.ID_EMAIL_ANEXO;

        SELECT l.ID_EMAIL_LOG, l.DT_REGISTRO, l.TENTATIVA, l.RESULTADO, l.MENSAGEM, l.SERVIDOR, l.USUARIO
        FROM SIS.Email_Log l
        WHERE l.ID_EMAIL = @IdEmail
        ORDER BY l.ID_EMAIL_LOG DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível abrir o e-mail. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
