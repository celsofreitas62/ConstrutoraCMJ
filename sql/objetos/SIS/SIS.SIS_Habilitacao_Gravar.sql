/*******************************************************************************
  Objeto      : [SIS].[SIS_Habilitacao_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga ou desliga um módulo ou uma tela para uso (pedido 5 do
                Celso): @Tipo 'MODULO' (código do módulo, ex.: FIN) ou 'TELA'
                (código do item, ex.: FIN_CONCILIACAO).
                Não desliga o que é protegido (módulo SIS e a tela "Módulos e
                telas"), para o administrador geral nunca se trancar fora.
                Habilitar não libera o que a licença não libera: o uso exige
                os dois.
                Permissão: SIS_MODULO / ALTERAR (só o administrador geral).
                Devolve 1 linha: SUCESSO, MENSAGEM.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL): ver sql/testes/SIS/02c_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Habilitacao_Gravar]
    @IdUsuario   INT,
    @Tipo        VARCHAR(10),
    @Codigo      VARCHAR(40),
    @Habilitado  BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Habilitacao_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Linhas     INT           = 0;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_MODULO', 'ALTERAR') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para habilitar módulos e telas.' AS NVARCHAR(400)) AS MENSAGEM;
            RETURN;
        END;

        SET @Usuario    = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Tipo       = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Codigo     = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Habilitado = ISNULL(@Habilitado, 0);

        IF @Tipo NOT IN ('MODULO', 'TELA')
            SET @Recusa = N'Informe se é módulo ou tela.';
        IF @Recusa = N'' AND @Tipo = 'MODULO' AND NOT EXISTS (SELECT 1 FROM SIS.Modulo m WHERE m.CODIGO = @Codigo)
            SET @Recusa = N'Módulo não encontrado.';
        IF @Recusa = N'' AND @Tipo = 'TELA' AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = @Codigo AND i.TIPO = 'TELA')
            SET @Recusa = N'Tela não encontrada.';
        IF @Recusa = N'' AND @Habilitado = 0 AND ((@Tipo = 'MODULO' AND @Codigo = 'SIS') OR (@Tipo = 'TELA' AND @Codigo = 'SIS_MODULO'))
            SET @Recusa = N'Este item é protegido e não pode ser desligado.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        IF @Tipo = 'MODULO'
        BEGIN
            UPDATE m SET m.HABILITADO = @Habilitado, m.DT_ALTERACAO = SYSDATETIME(), m.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Modulo m
            WHERE m.CODIGO = @Codigo AND m.HABILITADO <> @Habilitado;
            SET @Linhas = @@ROWCOUNT;
        END;

        IF @Tipo = 'TELA'
        BEGIN
            UPDATE i SET i.HABILITADO = @Habilitado, i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Item i
            WHERE i.CODIGO = @Codigo AND i.HABILITADO <> @Habilitado;
            SET @Linhas = @@ROWCOUNT;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 0 THEN N'Nenhuma alteração.'
                         WHEN @Habilitado = 1 THEN N'Habilitado para uso.'
                         ELSE N'Desabilitado: não aparece mais para os usuários.' END AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a habilitação. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO
