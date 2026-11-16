/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Exclui um anexo sem apagar (regra 56): marca SITUACAO =
                'EXCLUIDO' com quem, quando e o motivo (obrigatório). O arquivo
                continua em disco e o anexo continua visível com "mostrar
                excluídos".
                Permissão: ALTERAR na tela (@Item), que precisa manter a tabela.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_ANEXO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL): ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Excluir]
    @IdUsuario  INT,
    @Item       VARCHAR(40),
    @IdAnexo    BIGINT,
    @Motivo     NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Anexo_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Tabela     NVARCHAR(256);
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Linhas     INT           = 0;

    BEGIN TRY
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        SELECT @Tabela = a.TABELA_REFERENCIA FROM SIS.Anexo a WHERE a.ID_ANEXO = @IdAnexo AND a.SITUACAO = 'ATIVO';

        IF @Tabela IS NULL
            SET @Recusa = N'Anexo não encontrado ou já excluído.';
        IF @Recusa = N'' AND (SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 0 OR SIS.fn_SIS_Item_Tem_Tabela(@Item, @Tabela) = 0)
            SET @Recusa = N'Você não tem permissão para excluir este anexo.';
        IF @Recusa = N'' AND @Motivo = N''
            SET @Recusa = N'Informe o motivo da exclusão.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdAnexo AS ID_ANEXO;
            RETURN;
        END;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @EtapaAtual = 'Gravação';

        UPDATE a
           SET a.SITUACAO          = 'EXCLUIDO',
               a.DT_EXCLUSAO       = SYSDATETIME(),
               a.USUARIO_EXCLUSAO  = @Usuario,
               a.MOTIVO_EXCLUSAO   = @Motivo,
               a.DT_ALTERACAO      = SYSDATETIME(),
               a.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Anexo a
        WHERE a.ID_ANEXO = @IdAnexo
          AND a.SITUACAO = 'ATIVO';
        SET @Linhas = @@ROWCOUNT;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Anexo excluído.' ELSE N'O anexo já tinha sido excluído por outra pessoa.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdAnexo AS ID_ANEXO;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível excluir o anexo. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdAnexo AS ID_ANEXO;
    END CATCH;
END;
GO
