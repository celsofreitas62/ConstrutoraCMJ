/*******************************************************************************
  Teste       : 03d - primeiro acesso da instalação (SIS_Instalacao_Situacao e
                SIS_Instalacao_Senha_Gravar)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 20/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL (administradores
                já com senha: tem de recusar) e no banco de ensaio SISTEMACMJ
                (sem senha: fluxo completo). Tudo numa transação desfeita
                (ROLLBACK): nada fica gravado. Hash e salt de teste (não são
                senhas reais).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @R TABLE (CASO VARCHAR(80), ESPERADO NVARCHAR(60), OBTIDO NVARCHAR(400));
DECLARE @S TABLE (PENDENTE BIT, LOGIN_GERAL VARCHAR(40), LOGIN_EMPRESA VARCHAR(40));
DECLARE @G TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400));
DECLARE @H VARBINARY(32) = HASHBYTES('SHA2_256', 'hash de teste 1'), @H2 VARBINARY(32) = HASHBYTES('SHA2_256', 'hash de teste 2');
DECLARE @Sal VARBINARY(16) = CAST(HASHBYTES('MD5', 'salt de teste') AS VARBINARY(16));
DECLARE @Pendente BIT;

BEGIN TRANSACTION;
INSERT @S EXEC SIS.SIS_Instalacao_Situacao;
SET @Pendente = (SELECT PENDENTE FROM @S);
INSERT @R SELECT 'banco ' + DB_NAME() + ': situacao lida', 'SIM', CASE WHEN LOGIN_GERAL <> '' AND LOGIN_EMPRESA <> '' THEN 'SIM' ELSE 'NAO' END FROM @S;

IF @Pendente = 0
BEGIN
    INSERT @G EXEC SIS.SIS_Instalacao_Senha_Gravar @HashGeral = @H, @SaltGeral = @Sal, @HashEmpresa = @H2, @SaltEmpresa = @Sal, @Iteracoes = 600000, @Algoritmo = 'PBKDF2-SHA256';
    INSERT @R SELECT 'ja instalado: recusa', 'SUCESSO 0', CONCAT('SUCESSO ', SUCESSO) FROM @G;
    INSERT @R SELECT 'ja instalado: mensagem', 'SIM', CASE WHEN MENSAGEM LIKE N'%já foi concluída%' THEN 'SIM' ELSE MENSAGEM END FROM @G;
END
ELSE
BEGIN
    INSERT @G EXEC SIS.SIS_Instalacao_Senha_Gravar @HashGeral = @H, @SaltGeral = @Sal, @HashEmpresa = @H2, @SaltEmpresa = @Sal, @Iteracoes = 1000, @Algoritmo = 'PBKDF2-SHA256';
    INSERT @R SELECT 'iteracoes abaixo do minimo: recusa', 'SUCESSO 0', CONCAT('SUCESSO ', SUCESSO) FROM @G;
    DELETE @G;
    INSERT @G EXEC SIS.SIS_Instalacao_Senha_Gravar @HashGeral = @H, @SaltGeral = @Sal, @HashEmpresa = @H2, @SaltEmpresa = @Sal, @Iteracoes = 600000, @Algoritmo = 'PBKDF2-SHA256';
    INSERT @R SELECT 'primeiro acesso: grava', 'SUCESSO 1', CONCAT('SUCESSO ', SUCESSO) FROM @G;
    INSERT @R SELECT 'geral: senha gravada, sem troca obrigatoria', 'SIM', CASE WHEN SENHA_HASH = @H AND TROCAR_SENHA = 0 THEN 'SIM' ELSE 'NAO' END
    FROM SIS.Usuario WHERE LOGIN = (SELECT LOGIN_GERAL FROM @S);
    INSERT @R SELECT 'empresa: senha provisoria (troca no 1o acesso)', 'SIM', CASE WHEN SENHA_HASH = @H2 AND TROCAR_SENHA = 1 THEN 'SIM' ELSE 'NAO' END
    FROM SIS.Usuario WHERE LOGIN = (SELECT LOGIN_EMPRESA FROM @S);
    INSERT @R SELECT 'auditoria em nome do sistema', 'SIM', CASE WHEN EXISTS (SELECT 1 FROM SIS.Auditoria a WHERE a.TABELA = 'SIS.Usuario' AND a.CAMPO = 'SENHA_HASH'
                                                                                AND a.DT_OPERACAO >= DATEADD(MINUTE, -1, SYSDATETIME()) AND a.USUARIO = 'sistema') THEN 'SIM' ELSE 'NAO' END;
    DELETE @S; INSERT @S EXEC SIS.SIS_Instalacao_Situacao;
    INSERT @R SELECT 'depois: nao esta mais pendente', '0', CAST(PENDENTE AS NVARCHAR(1)) FROM @S;
    DELETE @G;
    INSERT @G EXEC SIS.SIS_Instalacao_Senha_Gravar @HashGeral = @H2, @SaltGeral = @Sal, @HashEmpresa = @H, @SaltEmpresa = @Sal, @Iteracoes = 600000, @Algoritmo = 'PBKDF2-SHA256';
    INSERT @R SELECT 'segunda vez: recusa', 'SUCESSO 0', CONCAT('SUCESSO ', SUCESSO) FROM @G;
END;
ROLLBACK TRANSACTION;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @R;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @R;
GO
