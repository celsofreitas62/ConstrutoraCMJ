/*******************************************************************************
  Homologação : etapa 02c da base SIS (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Testa habilitação de módulo e tela, contexto da sessão,
                auditoria (inclusão, alteração, exclusão, campo sigiloso,
                campo ignorado, proteção contra alterar/apagar), gerador de
                trigger, lote e anexo.
                Cada teste mostra ESPERADO x OBTIDO e RESULTADO (OK/FALHOU).
                Dados de teste (usuário hml.c02, tipos HML_*, anexo) são
                apagados no fim; as linhas de auditoria que eles geraram ficam
                (a auditoria não se apaga) e o lote de teste fica registrado.
                Aborta se não estiver no SISTEMACMJ_LOCAL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (16/11/2026) - Tela Módulos com a mesma árvore do menu (agrupadores).
    v1.2 (16/11/2026) - Aba Histórico grava em #AudReg (11 colunas, sem TABELA/ID_REGISTRO).
    v1.3 (16/11/2026) - Contagens de menu, tela Módulos e triggers restritas aos
                        itens da 02c (a 02d acrescenta itens, módulo e triggers).
    v1.4 (26/11/2026) - Etapa 04f2d: tabelas temporárias com as colunas novas
                        de SIS_Auditoria_Listar/_Registro_Listar (04b2) e
                        SIS_Anexo_Listar (04d); 10 tipos de anexo (04e) e
                        Auditoria no menu do admin (04b2).

  Como rodar: SSMS > Arquivo > Abrir > este arquivo > F5.
  Copiar para o Claude: a grade "RESUMO" e, se houver falha, a grade "TESTES".
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Este teste só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

SET NOCOUNT ON;

-- Restos de um teste anterior
DELETE FROM SIS.Anexo WHERE NOME_ORIGINAL LIKE N'hml[_]%';
DELETE ll FROM SIS.Login_Log ll WHERE ll.LOGIN_INFORMADO LIKE N'hml.c02%';
DELETE s FROM SIS.Sessao s INNER JOIN SIS.Usuario u ON u.ID_USUARIO = s.ID_USUARIO WHERE u.LOGIN = 'hml.c02';
DELETE FROM SIS.Usuario WHERE LOGIN = 'hml.c02';
DELETE FROM SIS.Anexo_Tipo WHERE CODIGO LIKE 'HML[_]%';

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
DROP TABLE IF EXISTS #Ret64;
DROP TABLE IF EXISTS #Menu;
DROP TABLE IF EXISTS #Mod;
DROP TABLE IF EXISTS #Aud;
DROP TABLE IF EXISTS #AudReg;
DROP TABLE IF EXISTS #Script;
DROP TABLE IF EXISTS #Lote;
DROP TABLE IF EXISTS #Anexo;
DROP TABLE IF EXISTS #AnexoObter;

CREATE TABLE #Teste  (ID INT IDENTITY(1,1), TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));
CREATE TABLE #Ret    (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
CREATE TABLE #Ret64  (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);
CREATE TABLE #Menu   (TIPO VARCHAR(10), CHAVE VARCHAR(12), CHAVE_PAI VARCHAR(12), CODIGO VARCHAR(40), NOME NVARCHAR(80), CAMINHO VARCHAR(200), ICONE VARCHAR(40), NIVEL INT, ACOES VARCHAR(400));
CREATE TABLE #Mod    (TIPO VARCHAR(10), CHAVE VARCHAR(12), CHAVE_PAI VARCHAR(12), NIVEL INT, CODIGO VARCHAR(40), NOME NVARCHAR(80), CAMINHO NVARCHAR(400), MODULO_CODIGO VARCHAR(10),
                      EXCLUSIVO_GERAL BIT, PODE_HABILITAR BIT, NA_LICENCA BIT, HABILITADO BIT, EM_USO BIT, PROTEGIDO BIT);
CREATE TABLE #Aud    (ID_AUDITORIA BIGINT, DT_OPERACAO DATETIME2(0), TABELA NVARCHAR(256), ID_REGISTRO BIGINT, OPERACAO CHAR(1), OPERACAO_NOME NVARCHAR(20), CAMPO NVARCHAR(128),
                      VALOR_ANTES NVARCHAR(4000), VALOR_DEPOIS NVARCHAR(4000), USUARIO NVARCHAR(100), ESTACAO NVARCHAR(128), ORIGEM NVARCHAR(256), ID_LOTE BIGINT,
                      TRANSACAO BIGINT, TELA_NOME NVARCHAR(200));  -- 04f2d: colunas da v1.1 do SIS_Auditoria_Listar (04b2)
CREATE TABLE #AudReg (ID_AUDITORIA BIGINT, DT_OPERACAO DATETIME2(0), OPERACAO CHAR(1), OPERACAO_NOME NVARCHAR(20), CAMPO NVARCHAR(128),
                      VALOR_ANTES NVARCHAR(4000), VALOR_DEPOIS NVARCHAR(4000), USUARIO NVARCHAR(100), ESTACAO NVARCHAR(128), ORIGEM NVARCHAR(256), ID_LOTE BIGINT,
                      TRANSACAO BIGINT);  -- 04f2d: coluna da v1.1 do SIS_Auditoria_Registro_Listar (04b2)
CREATE TABLE #Script (SCRIPT NVARCHAR(MAX));
CREATE TABLE #Lote   (ID_LOTE BIGINT, ORIGEM VARCHAR(30), DESCRICAO NVARCHAR(400), TABELA_REFERENCIA NVARCHAR(256), ID_REFERENCIA BIGINT, QTD_REGISTROS INT, SITUACAO VARCHAR(10), DT_CRIACAO DATETIME2(0), USUARIO_CRIACAO NVARCHAR(100));
CREATE TABLE #Anexo  (ID_ANEXO BIGINT, TIPO_CODIGO VARCHAR(30), TIPO_NOME NVARCHAR(60), NOME_ORIGINAL NVARCHAR(260), EXTENSAO VARCHAR(10), TAMANHO_BYTES BIGINT, DESCRICAO NVARCHAR(400),
                      DT_VALIDADE DATE, VENCIDO BIT,  -- 04f2d: colunas da v1.1 do SIS_Anexo_Listar (04d)
                      SITUACAO VARCHAR(10), DT_CRIACAO DATETIME2(0), USUARIO_CRIACAO NVARCHAR(100), DT_EXCLUSAO DATETIME2(0), USUARIO_EXCLUSAO NVARCHAR(100), MOTIVO_EXCLUSAO NVARCHAR(400));
CREATE TABLE #AnexoObter (ID_ANEXO BIGINT, NOME_ORIGINAL NVARCHAR(260), EXTENSAO VARCHAR(10), TAMANHO_BYTES BIGINT, HASH_SHA256 VARBINARY(32), CAMINHO_COMPLETO NVARCHAR(4000));

DECLARE @IdCelso    INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
DECLARE @IdAdmin    INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'admin');
DECLARE @IdPerfilAdmin INT = (SELECT TOP (1) p.ID_PERFIL FROM SIS.Perfil p WHERE p.NIVEL_ADMIN = 1 ORDER BY p.ID_PERFIL);
DECLARE @IdParam    INT = (SELECT p.ID_PARAMETRO FROM SIS.Parametro p WHERE p.CHAVE = 'CIDADE_PADRAO');
DECLARE @CidadeOrig NVARCHAR(4000) = SIS.fn_SIS_Parametro('CIDADE_PADRAO');
DECLARE @AudInicio  BIGINT = ISNULL((SELECT MAX(a.ID_AUDITORIA) FROM SIS.Auditoria a), 0);
DECLARE @IdHml      INT;
DECLARE @IdTipoHml  INT;
DECLARE @Erro       INT;
DECLARE @IdLote     BIGINT;
DECLARE @IdAnexo    BIGINT;
DECLARE @Hash       VARBINARY(32) = HASHBYTES('SHA2_256', CONVERT(NVARCHAR(36), NEWID()));
DECLARE @HashSenha  VARBINARY(64) = HASHBYTES('SHA2_256', N'senha-02c');
DECLARE @Salt       VARBINARY(64) = CRYPT_GEN_RANDOM(16);
DECLARE @Arquivo    VARCHAR(100)  = CONVERT(VARCHAR(36), NEWID()) + '.pdf';

-- 1) Objetos
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Objeto ' + v.NOME, v.TIPO, ISNULL((SELECT o.type_desc FROM sys.objects o WHERE o.object_id = OBJECT_ID(v.NOME)), N'(não existe)')
FROM (VALUES
        (N'SIS.Auditoria', N'USER_TABLE'), (N'SIS.Lote', N'USER_TABLE'), (N'SIS.Anexo_Tipo', N'USER_TABLE'), (N'SIS.Anexo', N'USER_TABLE'),
        (N'SIS.fn_SIS_Item_Tem_Tabela', N'SQL_SCALAR_FUNCTION'), (N'SIS.tg_SIS_Auditoria_Protecao', N'SQL_TRIGGER'),
        (N'SIS.SIS_Contexto_Gravar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Auditoria_Trigger_Gerar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Auditoria_Registro_Listar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Auditoria_Listar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Lote_Gerar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Lote_Concluir', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Lote_Listar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Anexo_Gravar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Anexo_Listar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Anexo_Obter', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Anexo_Excluir', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Modulo_Listar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Habilitacao_Gravar', N'SQL_STORED_PROCEDURE')
     ) v (NOME, TIPO);

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Triggers de auditoria criadas', N'13', CONVERT(NVARCHAR(10), COUNT(*))
FROM sys.triggers t WHERE t.parent_id IN (OBJECT_ID(N'SIS.Parametro'), OBJECT_ID(N'SIS.Modulo'), OBJECT_ID(N'SIS.Item'), OBJECT_ID(N'SIS.Acao'), OBJECT_ID(N'SIS.Item_Acao'),
      OBJECT_ID(N'SIS.Perfil'), OBJECT_ID(N'SIS.Perfil_Permissao'), OBJECT_ID(N'SIS.Usuario'), OBJECT_ID(N'SIS.Usuario_Permissao'), OBJECT_ID(N'SIS.Licenca'),
      OBJECT_ID(N'SIS.Licenca_Empresa'), OBJECT_ID(N'SIS.Anexo_Tipo'), OBJECT_ID(N'SIS.Anexo'))
  AND t.name LIKE N'tg[_]SIS[_]%[_]Auditoria';

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Carga: tipos de anexo', N'10', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Anexo_Tipo;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Tipo LOGOMARCA aceita', N'png,jpg,jpeg,svg', t.EXTENSOES FROM SIS.Anexo_Tipo t WHERE t.CODIGO = 'LOGOMARCA';

-- 2) Habilitação
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Módulos SIS e CAD habilitados', N'1/1',   -- v1.x (20/11/2026): CAD habilitado desde a 03a
       CONVERT(NVARCHAR(5), (SELECT m.HABILITADO FROM SIS.Modulo m WHERE m.CODIGO = 'SIS')) + N'/' + CONVERT(NVARCHAR(5), (SELECT m.HABILITADO FROM SIS.Modulo m WHERE m.CODIGO = 'CAD'));

INSERT INTO #Menu EXEC SIS.SIS_Menu_Listar @IdUsuario = @IdAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Menu do admin (1 módulo + 2 menus + 6 telas)', N'9', CONVERT(NVARCHAR(10), COUNT(*)) FROM #Menu WHERE CODIGO IN ('SIS','SIS_CONFIGURACAO','SIS_LICENCA','SIS_PARAMETRO','SIS_MODULO','SIS_SEGURANCA','SIS_USUARIO','SIS_PERFIL','SIS_MONITORAMENTO','SIS_LOG_ERRO','SIS_AUDITORIA','SIS_LOTE'); DELETE FROM #Menu;
INSERT INTO #Menu EXEC SIS.SIS_Menu_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Menu do celso (1 módulo + 3 menus + 8 telas)', N'12', CONVERT(NVARCHAR(10), COUNT(*)) FROM #Menu WHERE CODIGO IN ('SIS','SIS_CONFIGURACAO','SIS_LICENCA','SIS_PARAMETRO','SIS_MODULO','SIS_SEGURANCA','SIS_USUARIO','SIS_PERFIL','SIS_MONITORAMENTO','SIS_LOG_ERRO','SIS_AUDITORIA','SIS_LOTE'); DELETE FROM #Menu;

INSERT INTO #Mod EXEC SIS.SIS_Modulo_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Tela Módulos: 9 módulos + 3 agrupadores + 8 telas', N'20', CONVERT(NVARCHAR(10), COUNT(*)) FROM #Mod
 WHERE CODIGO IN ('CAD','IMOB','VENDA','FIN','BANCO','COBR','OBRA','GER') OR CODIGO IN ('SIS','SIS_CONFIGURACAO','SIS_LICENCA','SIS_PARAMETRO','SIS_MODULO','SIS_SEGURANCA','SIS_USUARIO','SIS_PERFIL','SIS_MONITORAMENTO','SIS_LOG_ERRO','SIS_AUDITORIA','SIS_LOTE');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Tela Módulos na ordem do menu (SIS)', N'SIS|SIS_CONFIGURACAO|SIS_LICENCA|SIS_PARAMETRO|SIS_MODULO|SIS_SEGURANCA|SIS_USUARIO|SIS_PERFIL|SIS_MONITORAMENTO|SIS_LOG_ERRO|SIS_AUDITORIA|SIS_LOTE',
       ISNULL((SELECT STRING_AGG(CAST(m.CODIGO AS NVARCHAR(MAX)), N'|') FROM #Mod m WHERE m.MODULO_CODIGO = 'SIS' AND m.CODIGO IN ('SIS','SIS_CONFIGURACAO','SIS_LICENCA','SIS_PARAMETRO','SIS_MODULO','SIS_SEGURANCA','SIS_USUARIO','SIS_PERFIL','SIS_MONITORAMENTO','SIS_LOG_ERRO','SIS_AUDITORIA','SIS_LOTE')), N'');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Agrupador não tem liga/desliga', N'0', CONVERT(NVARCHAR(5), MAX(CAST(PODE_HABILITAR AS INT))) FROM #Mod WHERE TIPO = 'MENU';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Pai da tela Licença é o agrupador Configuração', N'S',
       CASE WHEN (SELECT l.CHAVE_PAI FROM #Mod l WHERE l.CODIGO = 'SIS_LICENCA') = (SELECT c.CHAVE FROM #Mod c WHERE c.CODIGO = 'SIS_CONFIGURACAO') THEN N'S' ELSE N'N' END;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Protegidos: módulo SIS e tela Módulos', N'SIS,SIS_MODULO',
       ISNULL(STRING_AGG(CAST(m.CODIGO AS NVARCHAR(MAX)), N',') WITHIN GROUP (ORDER BY m.CODIGO), N'') FROM #Mod m WHERE m.PROTEGIDO = 1;

INSERT INTO #Ret (SUCESSO, MENSAGEM) EXEC SIS.SIS_Habilitacao_Gravar @IdUsuario = @IdAdmin, @Tipo = 'TELA', @Codigo = 'SIS_LOG_ERRO', @Habilitado = 0;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin (CMJ) habilita/desabilita (sem permissão)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret (SUCESSO, MENSAGEM) EXEC SIS.SIS_Habilitacao_Gravar @IdUsuario = @IdCelso, @Tipo = 'TELA', @Codigo = 'SIS_LOG_ERRO', @Habilitado = 0;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'celso desabilita a tela Log de erros', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'admin perde Log de erros/VER', N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_LOG_ERRO', 'VER')));

INSERT INTO #Ret (SUCESSO, MENSAGEM) EXEC SIS.SIS_Habilitacao_Gravar @IdUsuario = @IdCelso, @Tipo = 'TELA', @Codigo = 'SIS_LOG_ERRO', @Habilitado = 1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'celso habilita de novo', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'admin volta a ter Log de erros/VER', N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_LOG_ERRO', 'VER')));

INSERT INTO #Ret (SUCESSO, MENSAGEM) EXEC SIS.SIS_Habilitacao_Gravar @IdUsuario = @IdCelso, @Tipo = 'MODULO', @Codigo = 'SIS', @Habilitado = 0;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Desligar o módulo SIS (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret (SUCESSO, MENSAGEM) EXEC SIS.SIS_Habilitacao_Gravar @IdUsuario = @IdCelso, @Tipo = 'TELA', @Codigo = 'SIS_MODULO', @Habilitado = 0;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Desligar a tela Módulos (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 3) Contexto e auditoria
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-02C', @Origem = N'teste-02c';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Contexto: usuário', N'celso', ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), N'')),
 (N'Contexto: origem',  N'teste-02c', ISNULL(CONVERT(NVARCHAR(256), SESSION_CONTEXT(N'ORIGEM')), N''));

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'CIDADE_PADRAO', @Valor = N'Cidade Teste 02c';
DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT TOP (1) N'Alteração auditada (antes > depois)', @CidadeOrig + N' > Cidade Teste 02c', a.VALOR_ANTES + N' > ' + a.VALOR_DEPOIS
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Parametro' AND a.ID_REGISTRO = @IdParam AND a.CAMPO = N'VALOR' ORDER BY a.ID_AUDITORIA DESC;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT TOP (1) N'Auditoria leva usuário, estação e origem', N'celso|HOMOLOGACAO-02C|teste-02c', a.USUARIO + N'|' + a.ESTACAO + N'|' + a.ORIGEM
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Parametro' AND a.ID_REGISTRO = @IdParam ORDER BY a.ID_AUDITORIA DESC;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Campos de controle não auditados (DT/USUARIO_ALTERACAO)', N'0', CONVERT(NVARCHAR(10), COUNT(*))
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.CAMPO IN (N'DT_ALTERACAO', N'USUARIO_ALTERACAO');

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'CIDADE_PADRAO', @Valor = @CidadeOrig;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Restaurar cidade padrão', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #AudReg EXEC SIS.SIS_Auditoria_Registro_Listar @IdUsuario = @IdCelso, @Item = 'SIS_PARAMETRO', @Tabela = N'SIS.Parametro', @IdRegistro = @IdParam;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Aba Histórico do parâmetro (2 alterações ou mais)', N'S', CASE WHEN COUNT(*) >= 2 THEN N'S' ELSE N'N' END FROM #AudReg; DELETE FROM #AudReg;

INSERT INTO #Aud EXEC SIS.SIS_Auditoria_Listar @IdUsuario = @IdCelso, @Tabela = N'Parametro', @Operacao = 'A';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Consulta geral da auditoria encontra', N'S', CASE WHEN COUNT(*) >= 2 THEN N'S' ELSE N'N' END FROM #Aud; DELETE FROM #Aud;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Tela Usuários mantém SIS.Usuario',  N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Item_Tem_Tabela('SIS_USUARIO', N'SIS.Usuario'))),
 (N'Tela Perfis não mantém SIS.Usuario', N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Item_Tem_Tabela('SIS_PERFIL', N'SIS.Usuario')));

-- Inclusão, alteração só de maiúscula e exclusão
INSERT INTO SIS.Anexo_Tipo (CODIGO, NOME, EXTENSOES) VALUES ('HML_TESTE', N'Hml teste', 'pdf');
SET @IdTipoHml = CAST(SCOPE_IDENTITY() AS INT);
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Inclusão auditada com a foto em JSON', N'S', CASE WHEN COUNT(*) = 1 AND MAX(a.VALOR_DEPOIS) LIKE N'%"CODIGO":"HML_TESTE"%' THEN N'S' ELSE N'N' END
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Anexo_Tipo' AND a.ID_REGISTRO = @IdTipoHml AND a.OPERACAO = 'I';

UPDATE SIS.Anexo_Tipo SET NOME = N'HML TESTE' WHERE ID_ANEXO_TIPO = @IdTipoHml;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Mudança só de maiúsculas é auditada', N'Hml teste > HML TESTE', ISNULL(MAX(a.VALOR_ANTES + N' > ' + a.VALOR_DEPOIS), N'')
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Anexo_Tipo' AND a.ID_REGISTRO = @IdTipoHml AND a.OPERACAO = 'A' AND a.CAMPO = N'NOME';

DELETE FROM SIS.Anexo_Tipo WHERE ID_ANEXO_TIPO = @IdTipoHml;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Exclusão auditada com a foto em JSON', N'S', CASE WHEN COUNT(*) = 1 AND MAX(a.VALOR_ANTES) LIKE N'%"NOME":"HML TESTE"%' THEN N'S' ELSE N'N' END
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Anexo_Tipo' AND a.ID_REGISTRO = @IdTipoHml AND a.OPERACAO = 'E';

-- Senha sigilosa e contador de tentativas ignorado
INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdCelso, @Login = 'hml.c02', @Nome = N'Teste 02c', @IdPerfil = @IdPerfilAdmin;
SELECT @IdHml = r.ID FROM #Ret r; DELETE FROM #Ret;
INSERT INTO #Ret EXEC SIS.SIS_Usuario_Senha_Gravar @IdUsuario = @IdCelso, @IdUsuarioAlvo = @IdHml, @SenhaHash = @HashSenha, @SenhaSalt = @Salt, @Iteracoes = 600000, @Algoritmo = 'PBKDF2-SHA256';
DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Hash da senha auditado como ***', N'***', ISNULL(MAX(a.VALOR_DEPOIS), N'')
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Usuario' AND a.ID_REGISTRO = @IdHml AND a.CAMPO = N'SENHA_HASH';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Foto da inclusão sem o hash', N'S', CASE WHEN MAX(a.VALOR_DEPOIS) LIKE N'%"SENHA_HASH":null%' THEN N'S' ELSE N'N' END
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Usuario' AND a.ID_REGISTRO = @IdHml AND a.OPERACAO = 'I';

DROP TABLE IF EXISTS #RetLogin;
CREATE TABLE #RetLogin (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_USUARIO INT, ID_SESSAO BIGINT, NOME NVARCHAR(100), TROCAR_SENHA BIT);
INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.c02', @SenhaConferida = 0;
DROP TABLE IF EXISTS #RetLogin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Contador de tentativas não é auditado', N'0', CONVERT(NVARCHAR(10), COUNT(*))
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Usuario' AND a.ID_REGISTRO = @IdHml AND a.CAMPO = N'TENTATIVAS_ERRADAS';

-- Ninguém altera nem apaga a auditoria
SET @Erro = 0;
BEGIN TRY
    UPDATE SIS.Auditoria SET USUARIO = N'fraude' WHERE ID_AUDITORIA = (SELECT MAX(ID_AUDITORIA) FROM SIS.Auditoria);
END TRY
BEGIN CATCH
    SET @Erro = ERROR_NUMBER();
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Alterar auditoria (bloqueado)', N'50010', CONVERT(NVARCHAR(10), @Erro));

SET @Erro = 0;
BEGIN TRY
    DELETE FROM SIS.Auditoria WHERE ID_AUDITORIA = (SELECT MAX(ID_AUDITORIA) FROM SIS.Auditoria);
END TRY
BEGIN CATCH
    SET @Erro = ERROR_NUMBER();
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Apagar auditoria (bloqueado)', N'50010', CONVERT(NVARCHAR(10), @Erro));
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Nenhuma linha virou "fraude"', N'0', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Auditoria WHERE USUARIO = N'fraude';

-- Gerador (só mostra o script)
INSERT INTO #Script EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Gerador devolve o script da trigger', N'S', CASE WHEN MAX(s.SCRIPT) LIKE N'CREATE OR ALTER TRIGGER [[]SIS].[[]tg[_]SIS[_]Parametro[_]Auditoria]%' THEN N'S' ELSE N'N' END FROM #Script s;

SET @Erro = 0;
BEGIN TRY
    EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.NaoExiste';
END TRY
BEGIN CATCH
    SET @Erro = ERROR_NUMBER();
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Gerador com tabela inexistente (recusa)', N'50001', CONVERT(NVARCHAR(10), @Erro));

-- 4) Lote
EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdCelso, @Origem = 'teste', @Descricao = N'Homologação 02c', @IdLote = @IdLote OUTPUT;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Lote gerado e no contexto', N'S',
       CASE WHEN @IdLote IS NOT NULL AND TRY_CONVERT(BIGINT, SESSION_CONTEXT(N'ID_LOTE')) = @IdLote THEN N'S' ELSE N'N' END);

INSERT INTO SIS.Anexo_Tipo (CODIGO, NOME, EXTENSOES) VALUES ('HML_LOTE', N'Hml lote', 'pdf');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Auditoria leva o número do lote', N'S', CASE WHEN MAX(a.ID_LOTE) = @IdLote THEN N'S' ELSE N'N' END
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Anexo_Tipo' AND a.VALOR_DEPOIS LIKE N'%HML_LOTE%';

EXEC SIS.SIS_Lote_Concluir @IdLote = @IdLote, @QtdRegistros = 1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Lote concluído sai do contexto', N'S',
       CASE WHEN SESSION_CONTEXT(N'ID_LOTE') IS NULL THEN N'S' ELSE N'N' END);
DELETE FROM SIS.Anexo_Tipo WHERE CODIGO = 'HML_LOTE';

INSERT INTO #Lote EXEC SIS.SIS_Lote_Listar @IdUsuario = @IdCelso, @IdLote = @IdLote;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Lote na lista (origem e quantidade)', N'TESTE/1', ISNULL(MAX(ORIGEM + '/' + CONVERT(VARCHAR(10), QTD_REGISTROS)), '') FROM #Lote;

SET @Erro = 0;
BEGIN TRY
    DECLARE @LoteRuim BIGINT;
    EXEC SIS.SIS_Lote_Gerar @IdUsuario = @IdCelso, @Origem = 'teste x', @IdLote = @LoteRuim OUTPUT;
END TRY
BEGIN CATCH
    SET @Erro = ERROR_NUMBER();
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Lote com origem inválida (recusa)', N'50001', CONVERT(NVARCHAR(10), @Erro));

-- 5) Anexo
INSERT INTO #Ret64 EXEC SIS.SIS_Anexo_Gravar @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = @IdAdmin,
     @CodigoTipo = 'DOCUMENTO', @NomeOriginal = N'hml_documento.pdf', @NomeArquivo = @Arquivo, @PastaRelativa = '2026\11', @TamanhoBytes = 1000, @HashSha256 = @Hash;
SELECT @IdAnexo = r.ID FROM #Ret64 r;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Anexar arquivo', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;

INSERT INTO #Ret64 EXEC SIS.SIS_Anexo_Gravar @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = @IdAdmin,
     @CodigoTipo = 'DOCUMENTO', @NomeOriginal = N'hml_documento.pdf', @NomeArquivo = 'outro-nome.pdf', @PastaRelativa = '2026\11', @TamanhoBytes = 1000, @HashSha256 = @Hash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Mesmo arquivo de novo (recusa)', N'Este arquivo já está anexado a este registro.', MENSAGEM FROM #Ret64; DELETE FROM #Ret64;

INSERT INTO #Ret64 EXEC SIS.SIS_Anexo_Gravar @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = @IdAdmin,
     @CodigoTipo = 'LOGOMARCA', @NomeOriginal = N'hml_logo.pdf', @NomeArquivo = 'abc-1.pdf', @PastaRelativa = '2026\11', @TamanhoBytes = 1000, @HashSha256 = 0x00;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Logomarca em PDF (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;

INSERT INTO #Ret64 EXEC SIS.SIS_Anexo_Gravar @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = @IdAdmin,
     @CodigoTipo = 'DOCUMENTO', @NomeOriginal = N'hml_grande.pdf', @NomeArquivo = 'abc-2.pdf', @PastaRelativa = '2026\11', @TamanhoBytes = 999999999, @HashSha256 = @Hash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Arquivo grande demais (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;

INSERT INTO #Ret64 EXEC SIS.SIS_Anexo_Gravar @IdUsuario = @IdCelso, @Item = 'SIS_PERFIL', @Tabela = N'SIS.Usuario', @IdRegistro = @IdAdmin,
     @CodigoTipo = 'DOCUMENTO', @NomeOriginal = N'hml_x.pdf', @NomeArquivo = 'abc-3.pdf', @PastaRelativa = '2026\11', @TamanhoBytes = 10, @HashSha256 = @Hash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Tabela que não é da tela (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;

INSERT INTO #Ret64 EXEC SIS.SIS_Anexo_Gravar @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = 999999,
     @CodigoTipo = 'DOCUMENTO', @NomeOriginal = N'hml_x.pdf', @NomeArquivo = 'abc-4.pdf', @PastaRelativa = '2026\11', @TamanhoBytes = 10, @HashSha256 = @Hash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Registro inexistente (recusa)', N'Registro não encontrado.', MENSAGEM FROM #Ret64; DELETE FROM #Ret64;

INSERT INTO #Anexo EXEC SIS.SIS_Anexo_Listar @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = @IdAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Lista de anexos', N'hml_documento.pdf', ISNULL(MAX(NOME_ORIGINAL), N'') FROM #Anexo WHERE ID_ANEXO = @IdAnexo; DELETE FROM #Anexo;

INSERT INTO #AnexoObter EXEC SIS.SIS_Anexo_Obter @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @IdAnexo = @IdAnexo;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Caminho completo do anexo', N'C:\SistemaCMJ_Arquivos\Anexos\2026\11\' + CONVERT(NVARCHAR(100), @Arquivo), ISNULL(MAX(CAMINHO_COMPLETO), N'') FROM #AnexoObter;

INSERT INTO #Ret64 EXEC SIS.SIS_Anexo_Excluir @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @IdAnexo = @IdAnexo, @Motivo = N'';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Excluir anexo sem motivo (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Anexo_Excluir @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @IdAnexo = @IdAnexo, @Motivo = N'Teste de homologação';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Excluir anexo com motivo', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;

INSERT INTO #Anexo EXEC SIS.SIS_Anexo_Listar @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = @IdAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Excluído some da lista', N'0', CONVERT(NVARCHAR(10), COUNT(*)) FROM #Anexo WHERE ID_ANEXO = @IdAnexo; DELETE FROM #Anexo;
INSERT INTO #Anexo EXEC SIS.SIS_Anexo_Listar @IdUsuario = @IdCelso, @Item = 'SIS_USUARIO', @Tabela = N'SIS.Usuario', @IdRegistro = @IdAdmin, @IncluirExcluidos = 1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Excluído aparece em "mostrar excluídos"', N'EXCLUIDO/Teste de homologação', ISNULL(MAX(SITUACAO + '/' + MOTIVO_EXCLUSAO), N'') FROM #Anexo WHERE ID_ANEXO = @IdAnexo; DELETE FROM #Anexo;

-- 6) Resultado
SELECT N'TESTES' AS GRADE, t.ID, t.TESTE, t.ESPERADO, t.OBTIDO,
       CASE WHEN t.OBTIDO COLLATE Latin1_General_CS_AS = t.ESPERADO THEN N'OK' ELSE N'FALHOU' END AS RESULTADO
FROM #Teste t
ORDER BY t.ID;

SELECT N'RESUMO' AS GRADE,
       COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN t.OBTIDO COLLATE Latin1_General_CS_AS = t.ESPERADO THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste t;

-- 7) Limpeza (a auditoria fica)
DELETE FROM SIS.Anexo WHERE NOME_ORIGINAL LIKE N'hml[_]%';
DELETE ll FROM SIS.Login_Log ll WHERE ll.LOGIN_INFORMADO LIKE N'hml.c02%';
DELETE s FROM SIS.Sessao s INNER JOIN SIS.Usuario u ON u.ID_USUARIO = s.ID_USUARIO WHERE u.LOGIN = 'hml.c02';
DELETE FROM SIS.Usuario WHERE LOGIN = 'hml.c02';
DELETE FROM SIS.Anexo_Tipo WHERE CODIGO LIKE 'HML[_]%';

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
DROP TABLE IF EXISTS #Ret64;
DROP TABLE IF EXISTS #Menu;
DROP TABLE IF EXISTS #Mod;
DROP TABLE IF EXISTS #Aud;
DROP TABLE IF EXISTS #AudReg;
DROP TABLE IF EXISTS #Script;
DROP TABLE IF EXISTS #Lote;
DROP TABLE IF EXISTS #Anexo;
DROP TABLE IF EXISTS #AnexoObter;
GO

SET NOEXEC OFF;
GO
