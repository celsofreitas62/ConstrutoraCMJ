/*******************************************************************************
  Objeto      : [SIS].[SIS_Instalacao_Senha_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : PRIMEIRO ACESSO da instalação (uso exclusivo da API, tela que só
                abre no próprio servidor): grava de uma vez (tudo-ou-nada) a
                senha do administrador geral (nível 2) e a do administrador da
                empresa (nível 1). O banco recebe só o PBKDF2-SHA256 calculado
                pela API (como em SIS_Usuario_Senha_Gravar).
                Só funciona enquanto NENHUM administrador tem senha
                (SIS_Instalacao_Situacao.PENDENTE = 1); depois disso recusa
                sempre: senha nova passa pelo caminho normal (tela Usuários).
                Administrador geral: TROCAR_SENHA = 0 (ele mesmo digitou).
                Administrador da empresa: TROCAR_SENHA = 1 (senha provisória,
                troca no primeiro login).
                Gravado em nome do usuário "sistema" (auditoria), estação
                "Instalação (servidor)".
                Devolve 1 linha: SUCESSO, MENSAGEM.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL): ver sql/testes/SIS/03d_Homologacao_Instalacao.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Instalacao_Senha_Gravar]
    @HashGeral     VARBINARY(64),
    @SaltGeral     VARBINARY(64),
    @HashEmpresa   VARBINARY(64),
    @SaltEmpresa   VARBINARY(64),
    @Iteracoes     INT,
    @Algoritmo     VARCHAR(30),
    @Ip            VARCHAR(45)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc      NVARCHAR(128) = N'[SIS].[SIS_Instalacao_Senha_Gravar]';
    DECLARE @EtapaAtual    VARCHAR(100)  = 'Validação';
    DECLARE @Recusa        NVARCHAR(400) = N'';
    DECLARE @MinIteracoes  INT;
    DECLARE @IdSistema     INT;
    DECLARE @IdGeral       INT;
    DECLARE @IdEmpresa     INT;

    BEGIN TRY
        SET @MinIteracoes = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SENHA_PBKDF2_ITERACOES'), 600000);
        IF @MinIteracoes < 100000 SET @MinIteracoes = 100000;
        SET @IdSistema = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema' AND u.INTERNO = 1);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM SIS.Usuario u WITH (UPDLOCK, HOLDLOCK) INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                       WHERE p.NIVEL_ADMIN >= 1 AND u.INTERNO = 0 AND u.ATIVO = 1 AND u.SENHA_HASH IS NOT NULL)
                SET @Recusa = N'A instalação já foi concluída: os administradores já têm senha. Para trocar uma senha, use a tela de usuários.';

            SELECT TOP (1) @IdGeral = u.ID_USUARIO FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
            WHERE p.NIVEL_ADMIN = 2 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO;
            SELECT TOP (1) @IdEmpresa = u.ID_USUARIO FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
            WHERE p.NIVEL_ADMIN = 1 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO;

            IF @Recusa = N'' AND (@IdGeral IS NULL OR @IdEmpresa IS NULL OR @IdSistema IS NULL)
                SET @Recusa = N'Faltam os usuários iniciais no banco (rode o MASTER).';
            IF @Recusa = N'' AND ISNULL(@Algoritmo, '') <> 'PBKDF2-SHA256'
                SET @Recusa = N'Falha técnica: algoritmo de senha não suportado.';
            IF @Recusa = N'' AND (DATALENGTH(ISNULL(@HashGeral, 0x)) <> 32 OR DATALENGTH(ISNULL(@HashEmpresa, 0x)) <> 32)
                SET @Recusa = N'Falha técnica: hash de senha inválido.';
            IF @Recusa = N'' AND (DATALENGTH(ISNULL(@SaltGeral, 0x)) < 16 OR DATALENGTH(ISNULL(@SaltEmpresa, 0x)) < 16)
                SET @Recusa = N'Falha técnica: salt de senha inválido.';
            IF @Recusa = N'' AND ISNULL(@Iteracoes, 0) < @MinIteracoes
                SET @Recusa = N'Falha técnica: quantidade de iterações da senha abaixo do mínimo.';

            IF @Recusa <> N''
            BEGIN
                COMMIT TRANSACTION;
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM;
                RETURN;
            END;

            EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Estacao = N'Instalação (servidor)', @Origem = N'Tela de primeiro acesso';

            UPDATE u
               SET u.SENHA_HASH         = CASE WHEN u.ID_USUARIO = @IdGeral THEN @HashGeral ELSE @HashEmpresa END,
                   u.SENHA_SALT         = CASE WHEN u.ID_USUARIO = @IdGeral THEN @SaltGeral ELSE @SaltEmpresa END,
                   u.SENHA_ITERACOES    = @Iteracoes,
                   u.SENHA_ALGORITMO    = @Algoritmo,
                   u.DT_SENHA           = SYSDATETIME(),
                   u.TROCAR_SENHA       = CASE WHEN u.ID_USUARIO = @IdGeral THEN 0 ELSE 1 END,
                   u.TENTATIVAS_ERRADAS = 0,
                   u.BLOQUEADO          = 0,
                   u.DT_BLOQUEIO        = NULL,
                   u.DT_ALTERACAO       = SYSDATETIME(),
                   u.USUARIO_ALTERACAO  = N'instalacao'
            FROM SIS.Usuario u
            WHERE u.ID_USUARIO IN (@IdGeral, @IdEmpresa);

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Senhas gravadas. Entre com o administrador geral; o administrador da empresa troca a senha no primeiro acesso.' AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar as senhas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO
