/*******************************************************************************
  Teste       : 04a - tela de Usuários e perfis (senha provisória que vence,
                perfis de fábrica Financeiro e Consulta, colunas novas)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 22/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do MASTER.
  Observação  : não muda nada (tudo desfeito com ROLLBACK).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(90), ESPERADO NVARCHAR(80), OBTIDO NVARCHAR(80));
DECLARE @g TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_USUARIO INT);
DECLARE @l TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_USUARIO INT, ID_SESSAO BIGINT, NOME NVARCHAR(100), TROCAR_SENHA BIT);
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Consulta INT = (SELECT ID_PERFIL FROM SIS.Perfil WHERE NOME = N'Consulta');
DECLARE @Financeiro INT = (SELECT ID_PERFIL FROM SIS.Perfil WHERE NOME = N'Financeiro');
DECLARE @lista TABLE (ID_USUARIO INT, LOGIN NVARCHAR(40), NOME NVARCHAR(100), EMAIL NVARCHAR(200), ID_PERFIL INT, PERFIL_NOME NVARCHAR(60), PERFIL_NIVEL_ADMIN TINYINT,
       ATIVO BIT, BLOQUEADO BIT, TROCAR_SENHA BIT, TEM_SENHA BIT, SENHA_PROVISORIA_VENCIDA BIT, DT_SENHA DATETIME2(0), DT_ULTIMO_LOGIN DATETIME2(0), QTD_EXCECOES INT);
DECLARE @Id INT, @Token VARBINARY(32) = CRYPT_GEN_RANDOM(32), @Token2 VARBINARY(32) = CRYPT_GEN_RANDOM(32), @Token3 VARBINARY(32) = CRYPT_GEN_RANDOM(32);

-- Parâmetros
INSERT @r SELECT N'parâmetro SENHA_PROVISORIA_PADRAO', N'@12345', SIS.fn_SIS_Parametro('SENHA_PROVISORIA_PADRAO');
INSERT @r SELECT N'parâmetro SENHA_PROVISORIA_HORAS', N'24', SIS.fn_SIS_Parametro('SENHA_PROVISORIA_HORAS');

-- Perfis de fábrica
INSERT @r SELECT N'perfis Financeiro e Consulta existem (nível 0)', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Perfil WHERE NOME IN (N'Financeiro', N'Consulta') AND NIVEL_ADMIN = 0 AND ATIVO = 1;
INSERT @r SELECT N'Consulta: só a ação VER', N'VER', ISNULL((SELECT STRING_AGG(x.CODIGO, ',') FROM (SELECT DISTINCT a.CODIGO FROM SIS.Perfil_Permissao pp
       JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO WHERE pp.ID_PERFIL = @Consulta) x), N'nenhuma');
INSERT @r SELECT N'Consulta vê Pessoas', N'1', CASE WHEN EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp
       JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
       WHERE pp.ID_PERFIL = @Consulta AND i.CODIGO = 'CAD_PESSOA' AND a.CODIGO = 'VER') THEN N'1' ELSE N'0' END;
INSERT @r SELECT N'nenhum perfil de fábrica tem tela do módulo Sistema', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Perfil_Permissao pp
       JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO
       WHERE pp.ID_PERFIL IN (@Consulta, @Financeiro) AND (m.CODIGO = 'SIS' OR i.EXCLUSIVO_GERAL = 1);
INSERT @r SELECT N'Financeiro inclui e exclui em Pessoas', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Perfil_Permissao pp
       JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
       WHERE pp.ID_PERFIL = @Financeiro AND i.CODIGO = 'CAD_PESSOA' AND a.CODIGO IN ('INCLUIR', 'EXCLUIR');
INSERT @r SELECT N'Financeiro sem REABRIR', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Perfil_Permissao pp
       JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
       WHERE pp.ID_PERFIL = @Financeiro AND a.CODIGO = 'REABRIR';

BEGIN TRAN;
-- Usuário de teste no perfil Consulta
INSERT @g EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @Celso, @Login = 'teste.04a', @Nome = N'Teste 04a', @Email = N'celsofreitas62@gmail.com', @IdPerfil = @Consulta;
SELECT @Id = ID_USUARIO FROM @g;
INSERT @r SELECT N'inclui usuário no perfil Consulta', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @g); DELETE @g;
INSERT @g EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @Celso, @Login = 'teste.04a', @Nome = N'Outro', @IdPerfil = @Consulta;
INSERT @r SELECT N'login repetido recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @g); DELETE @g;

-- Senha provisória dada há 25 horas: login recusa
UPDATE SIS.Usuario SET SENHA_HASH = CRYPT_GEN_RANDOM(32), SENHA_SALT = CRYPT_GEN_RANDOM(16), SENHA_ITERACOES = 600000, SENHA_ALGORITMO = 'PBKDF2-SHA256',
       TROCAR_SENHA = 1, DT_SENHA = DATEADD(HOUR, -25, SYSDATETIME()) WHERE ID_USUARIO = @Id;
INSERT @lista EXEC SIS.SIS_Usuario_Listar @IdUsuario = @Celso, @Texto = N'teste.04a';
INSERT @r SELECT N'lista mostra senha provisória vencida', N'1', (SELECT CAST(SENHA_PROVISORIA_VENCIDA AS NVARCHAR(1)) FROM @lista WHERE ID_USUARIO = @Id);
INSERT @l EXEC SIS.SIS_Usuario_Login_Processar @Login = N'teste.04a', @SenhaConferida = 1, @TokenHash = @Token, @Ip = '', @Estacao = N'teste';
INSERT @r SELECT N'provisória de 25 h: login recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @l);
INSERT @r SELECT N'mensagem fala em reiniciar a senha', N'S', (SELECT CASE WHEN MENSAGEM LIKE N'%reiniciar%' THEN N'S' ELSE N'N' END FROM @l); DELETE @l;
INSERT @r SELECT N'Login_Log registra PROVISORIA_VENCIDA', N'PROVISORIA_VENCIDA', (SELECT TOP 1 RESULTADO FROM SIS.Login_Log WHERE ID_USUARIO = @Id ORDER BY ID_LOGIN_LOG DESC);
INSERT @r SELECT N'sem sessão aberta', N'0', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Sessao WHERE ID_USUARIO = @Id);

-- Senha errada com a provisória vencida: continua contando tentativa (não revela nada)
INSERT @l EXEC SIS.SIS_Usuario_Login_Processar @Login = N'teste.04a', @SenhaConferida = 0, @Ip = '', @Estacao = N'teste';
INSERT @r SELECT N'senha errada continua SENHA_ERRADA', N'SENHA_ERRADA', (SELECT TOP 1 RESULTADO FROM SIS.Login_Log WHERE ID_USUARIO = @Id ORDER BY ID_LOGIN_LOG DESC); DELETE @l;
UPDATE SIS.Usuario SET TENTATIVAS_ERRADAS = 0 WHERE ID_USUARIO = @Id;

-- Provisória de 1 hora: entra (e é obrigado a trocar)
UPDATE SIS.Usuario SET DT_SENHA = DATEADD(HOUR, -1, SYSDATETIME()) WHERE ID_USUARIO = @Id;
INSERT @l EXEC SIS.SIS_Usuario_Login_Processar @Login = N'teste.04a', @SenhaConferida = 1, @TokenHash = @Token, @Ip = '', @Estacao = N'teste';
INSERT @r SELECT N'provisória de 1 h: entra com troca obrigatória', N'1|1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) + N'|' + CAST(TROCAR_SENHA AS NVARCHAR(2)) FROM @l); DELETE @l;

-- Parâmetro 0 = não vence
UPDATE SIS.Parametro SET VALOR = N'0' WHERE CHAVE = 'SENHA_PROVISORIA_HORAS';
UPDATE SIS.Usuario SET DT_SENHA = DATEADD(DAY, -30, SYSDATETIME()) WHERE ID_USUARIO = @Id;
INSERT @l EXEC SIS.SIS_Usuario_Login_Processar @Login = N'teste.04a', @SenhaConferida = 1, @TokenHash = @Token2, @Ip = '', @Estacao = N'teste';
INSERT @r SELECT N'parâmetro 0: provisória não vence', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @l); DELETE @l;
UPDATE SIS.Parametro SET VALOR = N'24' WHERE CHAVE = 'SENHA_PROVISORIA_HORAS';

-- Administrador geral nunca fica sem entrar
UPDATE SIS.Usuario SET TROCAR_SENHA = 1, DT_SENHA = DATEADD(DAY, -10, SYSDATETIME()) WHERE ID_USUARIO = @Celso;
INSERT @l EXEC SIS.SIS_Usuario_Login_Processar @Login = N'celso', @SenhaConferida = 1, @TokenHash = @Token3, @Ip = '', @Estacao = N'teste';
INSERT @r SELECT N'administrador geral: provisória antiga não trava', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(2)) FROM @l); DELETE @l;
ROLLBACK;

INSERT @r SELECT N'Listar devolve SENHA_PROVISORIA_VENCIDA', N'1', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC SIS.SIS_Usuario_Listar 2', NULL, 0) WHERE name = 'SENHA_PROVISORIA_VENCIDA';
INSERT @r SELECT N'Obter devolve SENHA_PROVISORIA_VENCIDA e QTD_EXCECOES', N'2', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC SIS.SIS_Usuario_Obter 2, 2', NULL, 0) WHERE name IN ('SENHA_PROVISORIA_VENCIDA', 'QTD_EXCECOES');
INSERT @r SELECT N'nada ficou gravado (ROLLBACK)', N'0', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Usuario WHERE LOGIN = 'teste.04a');

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @r;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @r;
