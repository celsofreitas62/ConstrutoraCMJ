/*******************************************************************************
  Teste       : 03d - limite de tentativas de login por computador
                (SIS_Usuario_Login_Processar v1.1, parâmetros LOGIN_COMPUTADOR_*)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 20/11/2026 (v1.0). Banco: SISTEMACMJ_LOCAL.
  Tudo dentro de uma transação desfeita no fim (ROLLBACK): não deixa log,
  sessão nem tentativa gravada. Usa IPs falsos (10.99.99.x).
*******************************************************************************/
SET NOCOUNT ON;
IF DB_NAME() <> N'SISTEMACMJ_LOCAL' BEGIN RAISERROR(N'Banco errado.', 16, 1); SET NOEXEC ON; END;
GO
DECLARE @R TABLE (CASO VARCHAR(80), ESPERADO NVARCHAR(100), OBTIDO NVARCHAR(400));
DECLARE @L TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_USUARIO INT, ID_SESSAO BIGINT, NOME NVARCHAR(100), TROCAR_SENHA BIT);
DECLARE @Limite INT = SIS.fn_SIS_Parametro_Inteiro('LOGIN_COMPUTADOR_TENTATIVAS');
DECLARE @Tok VARBINARY(32) = HASHBYTES('SHA2_256', CONVERT(VARBINARY(64), NEWID()));
DECLARE @i INT = 1, @Antes SMALLINT;

BEGIN TRANSACTION;

INSERT @R SELECT 'parametros existem', '10 / 15', CONCAT(@Limite, ' / ', SIS.fn_SIS_Parametro_Inteiro('LOGIN_COMPUTADOR_MINUTOS'));

-- 1) IP 1: erra o limite inteiro com um login que nem existe
WHILE @i <= @Limite
BEGIN
    INSERT @L EXEC SIS.SIS_Usuario_Login_Processar @Login = N'nao_existe_teste', @SenhaConferida = 0, @Ip = '10.99.99.1', @Estacao = N'HML';
    SET @i += 1;
END;
INSERT @R SELECT 'IP1: tentativas recusadas ate o limite', CONCAT(@Limite, ' recusas'), CONCAT(SUM(CASE WHEN SUCESSO = 0 THEN 1 ELSE 0 END), ' recusas') FROM @L;

-- 2) IP 1: agora nem a senha certa entra (e nao conta tentativa no usuario)
SET @Antes = (SELECT TENTATIVAS_ERRADAS FROM SIS.Usuario WHERE LOGIN = 'claude');
DELETE @L;
INSERT @L EXEC SIS.SIS_Usuario_Login_Processar @Login = N'claude', @SenhaConferida = 1, @TokenHash = @Tok, @Ip = '10.99.99.1', @Estacao = N'HML';
INSERT @R SELECT 'IP1: senha certa recusada (computador em espera)', 'SUCESSO 0', CONCAT('SUCESSO ', SUCESSO) FROM @L;
INSERT @R SELECT 'IP1: mensagem fala do computador', 'SIM', CASE WHEN MENSAGEM LIKE N'%computador%' THEN 'SIM' ELSE MENSAGEM END FROM @L;
INSERT @R SELECT 'IP1: tentativas do usuario nao mudam', CAST(@Antes AS NVARCHAR(10)), CAST((SELECT TENTATIVAS_ERRADAS FROM SIS.Usuario WHERE LOGIN = 'claude') AS NVARCHAR(10));
INSERT @R SELECT 'IP1: log ESTACAO_BLOQUEADA', '1', CAST((SELECT COUNT(*) FROM SIS.Login_Log WHERE IP = '10.99.99.1' AND RESULTADO = 'ESTACAO_BLOQUEADA') AS NVARCHAR(10));

-- 3) IP 2 (outro computador): entra normalmente
DELETE @L;
SET @Tok = HASHBYTES('SHA2_256', CONVERT(VARBINARY(64), NEWID()));
INSERT @L EXEC SIS.SIS_Usuario_Login_Processar @Login = N'claude', @SenhaConferida = 1, @TokenHash = @Tok, @Ip = '10.99.99.2', @Estacao = N'HML';
INSERT @R SELECT 'IP2: outro computador entra', 'SUCESSO 1', CONCAT('SUCESSO ', SUCESSO) FROM @L;

-- 4) IP 3: erra (limite - 1), acerta, erra 1: o acerto zera a contagem
SET @i = 1;
WHILE @i < @Limite
BEGIN
    INSERT @L EXEC SIS.SIS_Usuario_Login_Processar @Login = N'nao_existe_teste', @SenhaConferida = 0, @Ip = '10.99.99.3', @Estacao = N'HML';
    SET @i += 1;
END;
SET @Tok = HASHBYTES('SHA2_256', CONVERT(VARBINARY(64), NEWID()));
INSERT @L EXEC SIS.SIS_Usuario_Login_Processar @Login = N'claude', @SenhaConferida = 1, @TokenHash = @Tok, @Ip = '10.99.99.3', @Estacao = N'HML';
INSERT @L EXEC SIS.SIS_Usuario_Login_Processar @Login = N'nao_existe_teste', @SenhaConferida = 0, @Ip = '10.99.99.3', @Estacao = N'HML';
DELETE @L;
SET @Tok = HASHBYTES('SHA2_256', CONVERT(VARBINARY(64), NEWID()));
INSERT @L EXEC SIS.SIS_Usuario_Login_Processar @Login = N'claude', @SenhaConferida = 1, @TokenHash = @Tok, @Ip = '10.99.99.3', @Estacao = N'HML';
INSERT @R SELECT 'IP3: acerto zera a contagem', 'SUCESSO 1', CONCAT('SUCESSO ', SUCESSO) FROM @L;

-- 5) sem IP (chamada interna): nao trava
DELETE @L;
INSERT @L EXEC SIS.SIS_Usuario_Login_Processar @Login = N'nao_existe_teste', @SenhaConferida = 0, @Ip = '', @Estacao = N'HML';
INSERT @R SELECT 'sem IP: recusa normal (usuario ou senha)', 'SIM', CASE WHEN MENSAGEM LIKE N'Usuário ou senha%' THEN 'SIM' ELSE MENSAGEM END FROM @L;

ROLLBACK TRANSACTION;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @R;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @R;
SELECT COUNT(*) AS LOG_DE_TESTE_RESTANTE FROM SIS.Login_Log WHERE IP LIKE '10.99.99.%';
GO
