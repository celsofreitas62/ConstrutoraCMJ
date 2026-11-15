/*******************************************************************************
  Objeto      : [SIS].[SIS_Sessao_Validar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : A API chama a cada requisição com o SHA-256 do token do
                cookie. Confere se a sessão está aberta, se o usuário continua
                ativo e desbloqueado e se não passou do tempo de inatividade
                (SESSAO_MINUTOS_INATIVIDADE, mínimo 5). Fecha a sessão quando
                não vale mais (MOTIVO_FIM EXPIRADA / INATIVADO / BLOQUEIO).
                Atualiza DT_ULTIMO_ACESSO no máximo uma vez por minuto (evita
                gravar a cada clique).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO, ID_SESSAO,
                LOGIN, NOME, TROCAR_SENHA.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Sessao_Validar]
    @TokenHash VARBINARY(32)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[SIS].[SIS_Sessao_Validar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Consulta';
    DECLARE @Minutos       INT;
    DECLARE @Agora         DATETIME2(0)  = SYSDATETIME();
    DECLARE @IdSessao      BIGINT;
    DECLARE @IdUsuario     INT;
    DECLARE @UltimoAcesso  DATETIME2(0);
    DECLARE @Ativo         BIT;
    DECLARE @Bloqueado     BIT;
    DECLARE @Login         NVARCHAR(100);
    DECLARE @Nome          NVARCHAR(100);
    DECLARE @TrocarSenha   BIT;
    DECLARE @Motivo        VARCHAR(20)   = '';
    DECLARE @Mensagem      NVARCHAR(400) = N'';

    BEGIN TRY
        SET @Minutos = SIS.fn_SIS_Parametro_Inteiro('SESSAO_MINUTOS_INATIVIDADE');
        IF @Minutos < 5 SET @Minutos = 5;

        SELECT @IdSessao     = s.ID_SESSAO,
               @IdUsuario    = s.ID_USUARIO,
               @UltimoAcesso = s.DT_ULTIMO_ACESSO,
               @Ativo        = u.ATIVO,
               @Bloqueado    = u.BLOQUEADO,
               @Login        = CONVERT(NVARCHAR(100), u.LOGIN),
               @Nome         = u.NOME,
               @TrocarSenha  = u.TROCAR_SENHA
        FROM SIS.Sessao s
        INNER JOIN SIS.Usuario u ON u.ID_USUARIO = s.ID_USUARIO
        WHERE s.TOKEN_HASH = @TokenHash
          AND s.DT_FIM IS NULL;

        IF @IdSessao IS NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Sessão encerrada. Entre novamente.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS LOGIN,
                   CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
            RETURN;
        END;

        IF @Ativo = 0                                               SELECT @Motivo = 'INATIVADO', @Mensagem = N'Usuário inativo. Procure o administrador do sistema.';
        IF @Motivo = '' AND @Bloqueado = 1                          SELECT @Motivo = 'BLOQUEIO',  @Mensagem = N'Usuário bloqueado. Procure o administrador do sistema.';
        IF @Motivo = '' AND @UltimoAcesso < DATEADD(MINUTE, -@Minutos, @Agora)
                                                                    SELECT @Motivo = 'EXPIRADA',  @Mensagem = N'Sessão expirada por falta de uso. Entre novamente.';

        SET @EtapaAtual = 'Atualização';
        IF @Motivo <> ''
        BEGIN
            UPDATE s SET s.DT_FIM = @Agora, s.MOTIVO_FIM = @Motivo
            FROM SIS.Sessao s
            WHERE s.ID_SESSAO = @IdSessao AND s.DT_FIM IS NULL;

            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Mensagem AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS LOGIN,
                   CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
            RETURN;
        END;

        UPDATE s SET s.DT_ULTIMO_ACESSO = @Agora
        FROM SIS.Sessao s
        WHERE s.ID_SESSAO = @IdSessao
          AND s.DT_FIM IS NULL
          AND s.DT_ULTIMO_ACESSO < DATEADD(MINUTE, -1, @Agora);

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'' AS NVARCHAR(400)) AS MENSAGEM,
               @IdUsuario AS ID_USUARIO, @IdSessao AS ID_SESSAO, ISNULL(@Login, N'') AS LOGIN,
               ISNULL(@Nome, N'') AS NOME, ISNULL(@TrocarSenha, 0) AS TROCAR_SENHA;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível conferir a sessão. Entre novamente.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_USUARIO, CAST(NULL AS BIGINT) AS ID_SESSAO, CAST(N'' AS NVARCHAR(100)) AS LOGIN,
               CAST(N'' AS NVARCHAR(100)) AS NOME, CAST(0 AS BIT) AS TROCAR_SENHA;
    END CATCH;
END;
GO
