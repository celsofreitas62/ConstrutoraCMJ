/*******************************************************************************
  Objeto      : [SIS].[SIS_Backup_Registrar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Registra um backup em SIS.Backup_Execucao. Chamada SÓ pelo script de
                backup do servidor (instalacao\backup_servidor.ps1), que roda
                pelas tarefas do Windows; o login da API não pode executar
                (DENY no papel rl_sistemacmj_api).
                Situação ERRO: manda aviso por e-mail para o parâmetro
                EMAIL_ADMIN_ALERTA (se preenchido), uma vez por backup.
                @ArquivosExistentes (opcional): lista separada por "|" com os
                arquivos que ainda existem na pasta depois da limpeza; os
                demais registros ficam com ARQUIVO_EXISTE = 0.
                Devolve 1 linha: ID_BACKUP.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, backup no servidor).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Backup_Registrar]
    @Tipo                VARCHAR(10),
    @Arquivo             NVARCHAR(400),
    @DtInicio            DATETIME2(0),
    @DtFim               DATETIME2(0)   = NULL,
    @TamanhoMb           DECIMAL(12,1)  = 0,
    @Situacao            VARCHAR(10),
    @Mensagem            NVARCHAR(2000) = N'',
    @CopiaNuvem          BIT            = 0,
    @ArquivosExistentes  NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Id BIGINT, @Para NVARCHAR(400), @IdEmail BIGINT, @Corpo NVARCHAR(MAX), @Chave NVARCHAR(200);

    INSERT INTO SIS.Backup_Execucao (TIPO, ARQUIVO, DT_INICIO, DT_FIM, TAMANHO_MB, SITUACAO, MENSAGEM, COPIA_NUVEM)
    VALUES (@Tipo, ISNULL(@Arquivo, N''), @DtInicio, @DtFim, ISNULL(@TamanhoMb, 0), @Situacao, LEFT(ISNULL(@Mensagem, N''), 2000), ISNULL(@CopiaNuvem, 0));
    SET @Id = CAST(SCOPE_IDENTITY() AS BIGINT);

    IF @ArquivosExistentes IS NOT NULL
        UPDATE b SET b.ARQUIVO_EXISTE = 0
        FROM SIS.Backup_Execucao b
        WHERE b.ARQUIVO_EXISTE = 1 AND b.ARQUIVO <> N''
          AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@ArquivosExistentes, '|') s WHERE LTRIM(RTRIM(s.value)) = b.ARQUIVO);

    IF @Situacao = 'ERRO'
    BEGIN
        SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
        IF @Para <> N''
        BEGIN
            SET @Corpo = SIS.fn_SIS_Email_HTML(N'Falha no backup', 'ALERTA',
                N'<p>O backup <b>' + SIS.fn_SIS_Texto_HTML(@Tipo) + N'</b> do banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b> falhou em '
                + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(@DtInicio), N'') + N'.</p><p>Mensagem: ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Mensagem, N'')) + N'</p>'
                + N'<p>Confira o servidor e o registro do backup (pasta do backup, arquivo backup.log).</p>',
                N'[SIS].[SIS_Backup_Registrar]', NULL, 0);
            SET @Chave = N'BACKUP_ERRO_' + CONVERT(NVARCHAR(20), @Id);
            EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: falha no backup do sistema', @CorpoHTML = @Corpo,
                 @Tipo = 'ALERTA', @Origem = N'[SIS].[SIS_Backup_Registrar]', @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
        END;
    END;

    SELECT @Id AS ID_BACKUP;
END;
GO
