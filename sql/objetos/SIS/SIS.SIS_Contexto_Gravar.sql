/*******************************************************************************
  Objeto      : [SIS].[SIS_Contexto_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Grava no SESSION_CONTEXT da conexão quem está usando o
                sistema, para os valores padrão das colunas USUARIO_CRIACAO,
                o log de erros e as triggers de auditoria saberem o usuário de
                verdade (e não o login técnico da API). A API chama no início
                de cada requisição, logo depois de abrir a conexão:
                  USUARIO    : login do usuário (fn_SIS_Usuario_Login)
                  ID_USUARIO : ID do usuário
                  ESTACAO    : IP ou nome da máquina do usuário
                  ORIGEM     : tela ou rotina (ex.: 'sis/usuarios.html',
                               'ROTINA:EMAIL_FILA')
                  ID_LOTE    : lote em andamento (NULL quando não há)
                A conexão devolvida ao pool é limpa pelo SQL Server
                (sp_reset_connection), então um usuário nunca herda o contexto
                de outro. Rotina automática usa o usuário interno "sistema".
                Sem result set (é chamada antes da procedure da tela).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Contexto_Gravar @IdUsuario = 2, @Estacao = N'127.0.0.1', @Origem = N'SSMS';
    -- SELECT SESSION_CONTEXT(N'USUARIO'), SESSION_CONTEXT(N'ORIGEM');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Contexto_Gravar]
    @IdUsuario  INT,
    @Estacao    NVARCHAR(128) = NULL,
    @Origem     NVARCHAR(256) = NULL,
    @IdLote     BIGINT        = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Contexto_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Contexto';
    DECLARE @Login      NVARCHAR(100);

    BEGIN TRY
        SELECT @Login = CONVERT(NVARCHAR(100), u.LOGIN)
        FROM SIS.Usuario u
        WHERE u.ID_USUARIO = @IdUsuario;

        SET @Login   = ISNULL(@Login, N'');
        SET @Estacao = ISNULL(@Estacao, N'');
        SET @Origem  = ISNULL(@Origem, N'');

        EXEC sys.sp_set_session_context @key = N'USUARIO',    @value = @Login;
        EXEC sys.sp_set_session_context @key = N'ID_USUARIO', @value = @IdUsuario;
        EXEC sys.sp_set_session_context @key = N'ESTACAO',    @value = @Estacao;
        EXEC sys.sp_set_session_context @key = N'ORIGEM',     @value = @Origem;
        EXEC sys.sp_set_session_context @key = N'ID_LOTE',    @value = @IdLote;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
