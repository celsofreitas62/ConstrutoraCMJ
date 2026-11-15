/*******************************************************************************
  Objeto      : [SIS].[SIS_Usuario_Senha_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Grava a senha de um usuário. O banco recebe só o resultado do
                PBKDF2-SHA256 calculado pela API (hash de 32 bytes, salt de
                16+ bytes, iterações >= SENHA_PBKDF2_ITERACOES, mínimo
                100.000). Tamanho mínimo e regras da senha digitada são
                conferidos pela API antes do hash (SENHA_TAMANHO_MINIMO).
                Dois casos:
                  - o próprio usuário troca a sua senha (a API já conferiu a
                    senha atual): TROCAR_SENHA = 0;
                  - outro (administrador) define senha provisória: precisa de
                    SIS_USUARIO / REDEFINIR_SENHA; TROCAR_SENHA = 1, zera as
                    tentativas, desbloqueia e encerra as sessões do usuário.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_USUARIO.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador: só o nível 2 define senha
                        de usuário de nível 2.

  Homologação (LOCAL): ver sql/testes/SIS/02b_Homologacao_SIS.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Usuario_Senha_Gravar]
    @IdUsuario      INT,
    @IdUsuarioAlvo  INT,
    @SenhaHash      VARBINARY(64),
    @SenhaSalt      VARBINARY(64),
    @Iteracoes      INT,
    @Algoritmo      VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[SIS].[SIS_Usuario_Senha_Gravar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @Propria      BIT           = CASE WHEN @IdUsuario = @IdUsuarioAlvo THEN 1 ELSE 0 END;
    DECLARE @MinIteracoes INT;
    DECLARE @Nivel        TINYINT       = SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario);

    BEGIN TRY
        IF @Propria = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'REDEFINIR_SENHA') = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para definir a senha de outro usuário.' AS NVARCHAR(400)) AS MENSAGEM, @IdUsuarioAlvo AS ID_USUARIO;
            RETURN;
        END;

        SET @Usuario      = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Algoritmo    = UPPER(LTRIM(RTRIM(ISNULL(@Algoritmo, ''))));
        SET @MinIteracoes = SIS.fn_SIS_Parametro_Inteiro('SENHA_PBKDF2_ITERACOES');
        IF @MinIteracoes < 100000 SET @MinIteracoes = 100000;

        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u
                       INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                       WHERE u.ID_USUARIO = @IdUsuarioAlvo AND u.INTERNO = 0 AND u.ATIVO = 1
                         AND (p.NIVEL_ADMIN < 2 OR @Nivel = 2 OR @Propria = 1))
            SET @Recusa = N'Usuário não encontrado ou inativo.';
        IF @Recusa = N'' AND @Algoritmo <> 'PBKDF2-SHA256'
            SET @Recusa = N'Falha técnica: algoritmo de senha não suportado.';
        IF @Recusa = N'' AND DATALENGTH(ISNULL(@SenhaHash, 0x)) <> 32
            SET @Recusa = N'Falha técnica: hash de senha inválido.';
        IF @Recusa = N'' AND DATALENGTH(ISNULL(@SenhaSalt, 0x)) < 16
            SET @Recusa = N'Falha técnica: salt de senha inválido.';
        IF @Recusa = N'' AND ISNULL(@Iteracoes, 0) < @MinIteracoes
            SET @Recusa = N'Falha técnica: quantidade de iterações da senha abaixo do mínimo.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdUsuarioAlvo AS ID_USUARIO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            UPDATE u
               SET u.SENHA_HASH         = @SenhaHash,
                   u.SENHA_SALT         = @SenhaSalt,
                   u.SENHA_ITERACOES    = @Iteracoes,
                   u.SENHA_ALGORITMO    = @Algoritmo,
                   u.DT_SENHA           = SYSDATETIME(),
                   u.TROCAR_SENHA       = CASE WHEN @Propria = 1 THEN 0 ELSE 1 END,
                   u.TENTATIVAS_ERRADAS = CASE WHEN @Propria = 1 THEN u.TENTATIVAS_ERRADAS ELSE 0 END,
                   u.BLOQUEADO          = CASE WHEN @Propria = 1 THEN u.BLOQUEADO ELSE 0 END,
                   u.DT_BLOQUEIO        = CASE WHEN @Propria = 1 THEN u.DT_BLOQUEIO ELSE NULL END,
                   u.DT_ALTERACAO       = SYSDATETIME(),
                   u.USUARIO_ALTERACAO  = @Usuario
            FROM SIS.Usuario u
            WHERE u.ID_USUARIO = @IdUsuarioAlvo;

            IF @Propria = 0
                UPDATE s SET s.DT_FIM = SYSDATETIME(), s.MOTIVO_FIM = 'SENHA_ALTERADA'
                FROM SIS.Sessao s
                WHERE s.ID_USUARIO = @IdUsuarioAlvo
                  AND s.DT_FIM IS NULL;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Propria = 1 THEN N'Senha alterada.' ELSE N'Senha provisória definida. O usuário vai trocá-la no próximo acesso.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdUsuarioAlvo AS ID_USUARIO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar a senha. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdUsuarioAlvo AS ID_USUARIO;
    END CATCH;
END;
GO
