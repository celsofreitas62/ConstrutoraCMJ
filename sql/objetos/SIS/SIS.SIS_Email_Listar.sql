/*******************************************************************************
  Objeto      : [SIS].[SIS_Email_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "E-mails enviados" (Sistema > E-mails): a fila com
                filtro por situação, período (data de criação) e texto
                (assunto, destinatário ou tipo). Mais recente primeiro.
                Sem o corpo (ver SIS_Email_Obter).
                Permissão: VER em SIS_EMAIL_FILA.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Email_Listar @IdUsuario = 2, @Status = 'ERRO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Email_Listar]
    @IdUsuario  INT,
    @Status     VARCHAR(12)   = NULL,
    @DtInicio   DATE          = NULL,
    @DtFim      DATE          = NULL,
    @Texto      NVARCHAR(200) = NULL,
    @MaxLinhas  INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Email_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_EMAIL_FILA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os e-mails do sistema.', 1;

        SET @Status    = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Status, '')))), '');
        SET @Texto     = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @MaxLinhas = CASE WHEN ISNULL(@MaxLinhas, 0) < 1 OR @MaxLinhas > 5000 THEN 500 ELSE @MaxLinhas END;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               f.ID_EMAIL, f.DT_CRIACAO, f.TIPO, f.CONTA, f.STATUS, f.PARA, f.PARA_ORIGINAL, f.ASSUNTO,
               f.TENTATIVAS, f.PROXIMA_TENTATIVA, f.DT_ENVIO, f.ULTIMO_ERRO, f.MODO_TESTE, f.ORIGEM, f.GRUPO, f.ID_LOTE,
               (SELECT COUNT(*) FROM SIS.Email_Fila_Anexo a WHERE a.ID_EMAIL = f.ID_EMAIL AND a.CID = '') AS QTD_ANEXOS
        FROM SIS.Email_Fila f WITH (NOLOCK)
        WHERE (@Status   IS NULL OR f.STATUS = @Status)
          AND (@DtInicio IS NULL OR f.DT_CRIACAO >= @DtInicio)
          AND (@DtFim    IS NULL OR f.DT_CRIACAO <  DATEADD(DAY, 1, CAST(@DtFim AS DATETIME2(0))))
          AND (@Texto    IS NULL OR f.ASSUNTO LIKE N'%' + @Texto + N'%' OR f.PARA LIKE N'%' + @Texto + N'%'
                                 OR f.PARA_ORIGINAL LIKE N'%' + @Texto + N'%' OR f.TIPO LIKE N'%' + @Texto + N'%')
        ORDER BY f.ID_EMAIL DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os e-mails. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
