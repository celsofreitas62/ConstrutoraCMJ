/*******************************************************************************
  Homologação : etapa 02b da base SIS (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Testa licença, perfis, usuários, permissões, menu, senha,
                login (com bloqueio), sessão (validar, expirar, encerrar).
                Cada teste mostra ESPERADO x OBTIDO e RESULTADO (OK/FALHOU).
                Usa um perfil "HML Financeiro" e o usuário "hml.fin", que são
                apagados no início e no fim (só existem durante o teste).
                Instala no LOCAL uma licença de DESENVOLVIMENTO com todos os
                módulos (CNPJ fictício); ela fica instalada para o
                desenvolvimento. Rodando de novo: "já está instalada".
                Aborta se não estiver no SISTEMACMJ_LOCAL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.2 (16/11/2026) - Contagens de itens, ações e menus restritas aos
                        itens da 02b (etapas seguintes acrescentam telas).
    v1.3 (16/11/2026) - Contagem de ações restrita às 14 da 02b (a 02d acrescenta EXECUTAR).
    v1.1 (15/11/2026) - Dois níveis de administrador: celso (geral) x admin
                        (CMJ); testes de visibilidade e de telas exclusivas;
                        exceções de usuário testadas no Log de erros.

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

-- Limpeza de restos de um teste anterior
DELETE ll FROM SIS.Login_Log ll WHERE ll.LOGIN_INFORMADO LIKE N'hml.%' OR ll.LOGIN_INFORMADO = N'sistema'
                                   OR ll.ID_USUARIO IN (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN LIKE 'hml.%');
DELETE s  FROM SIS.Sessao s INNER JOIN SIS.Usuario u ON u.ID_USUARIO = s.ID_USUARIO WHERE u.LOGIN LIKE 'hml.%';
DELETE up FROM SIS.Usuario_Permissao up INNER JOIN SIS.Usuario u ON u.ID_USUARIO = up.ID_USUARIO WHERE u.LOGIN LIKE 'hml.%';
DELETE u  FROM SIS.Usuario u WHERE u.LOGIN LIKE 'hml.%';
DELETE pp FROM SIS.Perfil_Permissao pp INNER JOIN SIS.Perfil p ON p.ID_PERFIL = pp.ID_PERFIL WHERE p.NOME LIKE N'HML %';
DELETE p  FROM SIS.Perfil p WHERE p.NOME LIKE N'HML %';

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
DROP TABLE IF EXISTS #RetLogin;
DROP TABLE IF EXISTS #RetSessao;
DROP TABLE IF EXISTS #RetEnc;
DROP TABLE IF EXISTS #Obter;
DROP TABLE IF EXISTS #Menu;
DROP TABLE IF EXISTS #Lic;
DROP TABLE IF EXISTS #ListaUsu;
DROP TABLE IF EXISTS #ListaPerfil;

CREATE TABLE #ListaUsu    (ID_USUARIO INT, LOGIN NVARCHAR(40), NOME NVARCHAR(100), EMAIL NVARCHAR(200), ID_PERFIL INT, PERFIL_NOME NVARCHAR(60),
                           PERFIL_NIVEL_ADMIN TINYINT, ATIVO BIT, BLOQUEADO BIT, TROCAR_SENHA BIT, TEM_SENHA BIT, DT_ULTIMO_LOGIN DATETIME2(0), QTD_EXCECOES INT);
CREATE TABLE #ListaPerfil (ID_PERFIL INT, NOME NVARCHAR(60), DESCRICAO NVARCHAR(400), NIVEL_ADMIN TINYINT, ATIVO BIT, QTD_USUARIOS_ATIVOS INT, QTD_PERMISSOES INT);
CREATE TABLE #Teste     (ID INT IDENTITY(1,1), TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));
CREATE TABLE #Ret       (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
CREATE TABLE #RetLogin  (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_USUARIO INT, ID_SESSAO BIGINT, NOME NVARCHAR(100), TROCAR_SENHA BIT);
CREATE TABLE #RetSessao (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_USUARIO INT, ID_SESSAO BIGINT, LOGIN NVARCHAR(100), NOME NVARCHAR(100), TROCAR_SENHA BIT);
CREATE TABLE #RetEnc    (SUCESSO BIT, MENSAGEM NVARCHAR(400));
CREATE TABLE #Obter     (ENCONTRADO BIT, ID_USUARIO INT, SENHA_HASH VARBINARY(64), SENHA_SALT VARBINARY(64), SENHA_ITERACOES INT, SENHA_ALGORITMO VARCHAR(30));
CREATE TABLE #Menu      (TIPO VARCHAR(10), CHAVE VARCHAR(12), CHAVE_PAI VARCHAR(12), CODIGO VARCHAR(40), NOME NVARCHAR(80), CAMINHO VARCHAR(200), ICONE VARCHAR(40), NIVEL INT, ACOES VARCHAR(400));
CREATE TABLE #Lic       (ENCONTRADA BIT, ID_LICENCA INT, CHAVE_LICENCA NVARCHAR(MAX), ID_SERVIDOR VARCHAR(200), DT_EMISSAO DATE, DT_VALIDADE DATE,
                         MODULOS VARCHAR(400), DT_INSTALACAO DATETIME2(0), USUARIO_INSTALACAO NVARCHAR(100), EMPRESAS_JSON NVARCHAR(MAX));

DECLARE @IdAdmin        INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'admin');
DECLARE @IdSistema      INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema');
DECLARE @IdCelso        INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
DECLARE @IdPerfilGeral  INT = (SELECT TOP (1) p.ID_PERFIL FROM SIS.Perfil p WHERE p.NIVEL_ADMIN = 2 ORDER BY p.ID_PERFIL);
DECLARE @IdPerfilAdmin  INT = (SELECT TOP (1) p.ID_PERFIL FROM SIS.Perfil p WHERE p.NIVEL_ADMIN = 1 ORDER BY p.ID_PERFIL);
DECLARE @IaParamVer     INT = (SELECT ia.ID_ITEM_ACAO FROM SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO WHERE i.CODIGO = 'SIS_PARAMETRO' AND a.CODIGO = 'VER');
DECLARE @IaLogVer       INT = (SELECT ia.ID_ITEM_ACAO FROM SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO WHERE i.CODIGO = 'SIS_LOG_ERRO' AND a.CODIGO = 'VER');
DECLARE @IaLogExp       INT = (SELECT ia.ID_ITEM_ACAO FROM SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO WHERE i.CODIGO = 'SIS_LOG_ERRO' AND a.CODIGO = 'EXPORTAR');
DECLARE @IdPerfilHml    INT;
DECLARE @IdHml          INT;
DECLARE @Json           NVARCHAR(MAX);
DECLARE @Hash           VARBINARY(64) = HASHBYTES('SHA2_256', N'senha-de-teste');
DECLARE @Hash2          VARBINARY(64) = HASHBYTES('SHA2_256', N'outra-senha-de-teste');
DECLARE @Salt           VARBINARY(64) = CRYPT_GEN_RANDOM(16);
DECLARE @Token          VARBINARY(32) = CRYPT_GEN_RANDOM(32);
DECLARE @TokenHash      VARBINARY(32);
DECLARE @Vez            INT;

SET @TokenHash = HASHBYTES('SHA2_256', @Token);

-- 1) Objetos e carga
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Objeto ' + v.NOME, v.TIPO, ISNULL((SELECT o.type_desc FROM sys.objects o WHERE o.object_id = OBJECT_ID(v.NOME)), N'(não existe)')
FROM (VALUES
        (N'SIS.Licenca', N'USER_TABLE'), (N'SIS.Licenca_Empresa', N'USER_TABLE'), (N'SIS.Item', N'USER_TABLE'), (N'SIS.Acao', N'USER_TABLE'),
        (N'SIS.Item_Acao', N'USER_TABLE'), (N'SIS.Perfil', N'USER_TABLE'), (N'SIS.Perfil_Permissao', N'USER_TABLE'), (N'SIS.Usuario', N'USER_TABLE'),
        (N'SIS.Usuario_Permissao', N'USER_TABLE'), (N'SIS.Sessao', N'USER_TABLE'), (N'SIS.Login_Log', N'USER_TABLE'),
        (N'SIS.vw_SIS_Permissao_Efetiva', N'VIEW'),
        (N'SIS.fn_SIS_Usuario_Login', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Usuario_Nivel_Admin', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Tem_Permissao', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.fn_SIS_Empresa_Razao_Social', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Empresa_CNPJ', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.SIS_Licenca_Modulos_Aplicar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Licenca_Gravar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Licenca_Obter', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Usuario_Login_Obter', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Usuario_Login_Processar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Sessao_Validar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Sessao_Encerrar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Usuario_Listar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Usuario_Obter', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Usuario_Gravar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Usuario_Senha_Gravar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Usuario_Desbloquear', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Perfil_Listar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Perfil_Gravar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Permissao_Listar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Permissao_Gravar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Menu_Listar', N'SQL_STORED_PROCEDURE')
     ) v (NOME, TIPO);

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Carga: ações (02b)', N'14', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Acao a
WHERE a.CODIGO IN ('VER','INCLUIR','ALTERAR','EXCLUIR','EXPORTAR','IMPORTAR','BAIXAR','ESTORNAR','CANCELAR','REABRIR','APROVAR','ENVIAR','DESBLOQUEAR','REDEFINIR_SENHA');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Carga: itens do SIS (02b)', N'8', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Item i WHERE i.CODIGO IN ('SIS_CONFIGURACAO','SIS_LICENCA','SIS_PARAMETRO','SIS_SEGURANCA','SIS_USUARIO','SIS_PERFIL','SIS_MONITORAMENTO','SIS_LOG_ERRO');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Carga: ações das telas do SIS', N'17', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM WHERE i.CODIGO IN ('SIS_CONFIGURACAO','SIS_LICENCA','SIS_PARAMETRO','SIS_SEGURANCA','SIS_USUARIO','SIS_PERFIL','SIS_MONITORAMENTO','SIS_LOG_ERRO');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Carga: perfis de administrador (nível 1 / nível 2)', N'1/1',
       CONVERT(NVARCHAR(10), SUM(CASE WHEN p.NIVEL_ADMIN = 1 THEN 1 ELSE 0 END)) + N'/' + CONVERT(NVARCHAR(10), SUM(CASE WHEN p.NIVEL_ADMIN = 2 THEN 1 ELSE 0 END)) FROM SIS.Perfil p;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Nível do celso (administrador geral)', N'2', CONVERT(NVARCHAR(5), SIS.fn_SIS_Usuario_Nivel_Admin(@IdCelso))),
 (N'Nível do admin (administrador da CMJ)', N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Usuario_Nivel_Admin(@IdAdmin))),
 (N'Nível do sistema (interno)', N'2', CONVERT(NVARCHAR(5), SIS.fn_SIS_Usuario_Nivel_Admin(@IdSistema)));
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Telas exclusivas do administrador geral', N'SIS_LICENCA,SIS_PARAMETRO',
       ISNULL(STRING_AGG(CAST(i.CODIGO AS NVARCHAR(MAX)), N',') WITHIN GROUP (ORDER BY i.CODIGO), N'') FROM SIS.Item i WHERE i.EXCLUSIVO_GERAL = 1 AND i.CODIGO IN ('SIS_CONFIGURACAO','SIS_LICENCA','SIS_PARAMETRO','SIS_SEGURANCA','SIS_USUARIO','SIS_PERFIL','SIS_MONITORAMENTO','SIS_LOG_ERRO');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Carga: usuário sistema é interno', N'1', CONVERT(NVARCHAR(5), u.INTERNO) FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdSistema;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Carga: admin sem senha e com troca obrigatória', N'1/1',
       CONVERT(NVARCHAR(5), CASE WHEN u.SENHA_HASH IS NULL THEN 1 ELSE 0 END) + N'/' + CONVERT(NVARCHAR(5), u.TROCAR_SENHA) FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Parâmetro SENHA_PBKDF2_ITERACOES', N'600000', SIS.fn_SIS_Parametro('SENHA_PBKDF2_ITERACOES');

-- 2) Licença
INSERT INTO #Ret EXEC SIS.SIS_Licenca_Gravar @IdUsuario = @IdSistema, @ChaveLicenca = N'X', @IdServidor = 'NOTEBOOK-CELSO', @DtEmissao = '2026-11-15', @Modulos = 'CAD', @EmpresasJson = N'[]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Licença sem empresa (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Licenca_Gravar @IdUsuario = @IdSistema, @ChaveLicenca = N'X', @IdServidor = 'NOTEBOOK-CELSO', @DtEmissao = '2026-11-15', @Modulos = 'CAD',
     @EmpresasJson = N'[{"cnpj":"11222333000181","razao_social":"A","principal":true},{"cnpj":"11222333000262","razao_social":"B","principal":true}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Licença com duas principais (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Licenca_Gravar @IdUsuario = @IdSistema, @ChaveLicenca = N'X', @IdServidor = 'NOTEBOOK-CELSO', @DtEmissao = '2026-11-15', @DtValidade = '2026-01-01', @Modulos = 'CAD',
     @EmpresasJson = N'[{"cnpj":"11222333000181","razao_social":"A"}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Licença com validade antes da emissão (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Licenca_Gravar @IdUsuario = @IdSistema, @ChaveLicenca = N'LICENCA-DESENVOLVIMENTO-LOCAL', @IdServidor = 'NOTEBOOK-CELSO',
     @DtEmissao = '2026-11-15', @DtValidade = NULL, @Modulos = 'cad, fin,IMOB,VENDA,BANCO,COBR,OBRA,GER,XYZ',
     @EmpresasJson = N'[{"cnpj":"11.222.333/0001-81","razao_social":"Construtora Marcilio Judice Ltda (DESENVOLVIMENTO)","nome_fantasia":"CMJ"}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Licença de desenvolvimento instalada', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret;
SELECT N'MENSAGEM DA LICENÇA' AS GRADE, r.MENSAGEM FROM #Ret r; DELETE FROM #Ret;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Módulos liberados', N'9', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Modulo m WHERE m.LIBERADO_LICENCA = 1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Razão social da licença', N'Construtora Marcilio Judice Ltda (DESENVOLVIMENTO)', SIS.fn_SIS_Empresa_Razao_Social());
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'CNPJ da licença (sem pontuação)', N'11222333000181', SIS.fn_SIS_Empresa_CNPJ());

INSERT INTO #Lic EXEC SIS.SIS_Licenca_Obter;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Licença ativa encontrada', N'1', CONVERT(NVARCHAR(5), ENCONTRADA) FROM #Lic;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Módulos gravados (normalizados)', N'BANCO,CAD,COBR,FIN,GER,IMOB,OBRA,VENDA,XYZ', MODULOS FROM #Lic;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Licenças ativas', N'1', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Licenca l WHERE l.ATIVA = 1;

INSERT INTO #Ret EXEC SIS.SIS_Licenca_Gravar @IdUsuario = @IdAdmin, @ChaveLicenca = N'Y', @IdServidor = 'X', @DtEmissao = '2026-11-15', @Modulos = '', @EmpresasJson = N'[]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin (CMJ) instala licença (sem permissão)', N'Você não tem permissão para instalar licença.', MENSAGEM FROM #Ret; DELETE FROM #Ret;

-- 3) Perfis e permissões de perfil
INSERT INTO #Ret EXEC SIS.SIS_Perfil_Gravar @IdUsuario = @IdAdmin, @Nome = N'HML Financeiro', @Descricao = N'Perfil de teste';
SELECT @IdPerfilHml = r.ID FROM #Ret r;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Incluir perfil', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Perfil_Gravar @IdUsuario = @IdAdmin, @Nome = N'HML Financeiro';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Perfil com nome repetido (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Perfil_Gravar @IdUsuario = @IdAdmin, @IdPerfil = @IdPerfilAdmin, @Nome = N'Administrador', @Ativo = 0;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Desativar perfil Administrador (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

SET @Json = N'[{"id_item_acao":' + CONVERT(NVARCHAR(10), @IaParamVer) + N',"valor":"S"}]';
INSERT INTO #Ret EXEC SIS.SIS_Permissao_Gravar @IdUsuario = @IdCelso, @IdPerfil = @IdPerfilHml, @ListaJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Dar tela exclusiva (Parâmetros) a perfil (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

SET @Json = N'[{"id_item_acao":' + CONVERT(NVARCHAR(10), @IaLogVer) + N',"valor":"S"}]';
INSERT INTO #Ret EXEC SIS.SIS_Permissao_Gravar @IdUsuario = @IdAdmin, @IdPerfil = @IdPerfilHml, @ListaJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Dar Log de erros/VER ao perfil (qtd)', N'1', CONVERT(NVARCHAR(10), ID) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Permissao_Gravar @IdUsuario = @IdAdmin, @IdPerfil = @IdPerfilAdmin, @ListaJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Mexer nas permissões do Administrador (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 4) Usuários
INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdAdmin, @Login = 'hml.fin', @Nome = N'Usuário de teste', @Email = N'HML@Exemplo.com', @IdPerfil = @IdPerfilHml;
SELECT @IdHml = r.ID FROM #Ret r;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Incluir usuário', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'E-mail gravado em minúsculas', N'hml@exemplo.com', u.EMAIL FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdHml;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdAdmin, @Login = 'HML.FIN', @Nome = N'Outro', @IdPerfil = @IdPerfilHml;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login repetido em maiúsculas (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdAdmin, @Login = 'hml fin', @Nome = N'Outro', @IdPerfil = @IdPerfilHml;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login com espaço (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdAdmin, @Login = 'admin', @Nome = N'Administrador do sistema', @IdPerfil = @IdPerfilAdmin, @Ativo = 0;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Desativar o próprio usuário (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdCelso, @IdUsuarioAlvo = @IdCelso, @Login = 'celso', @Nome = N'Celso de Freitas', @IdPerfil = @IdPerfilAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Tirar o único administrador geral (recusa)', N'Este é o único administrador geral ativo: não é possível mudar o perfil nem desativar.', MENSAGEM FROM #Ret; DELETE FROM #Ret;

-- Visibilidade do administrador geral para o admin da CMJ
INSERT INTO #ListaUsu EXEC SIS.SIS_Usuario_Listar @IdUsuario = @IdAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin não vê o usuário celso', N'0', CONVERT(NVARCHAR(10), COUNT(*)) FROM #ListaUsu WHERE LOGIN = N'celso';
DELETE FROM #ListaUsu;
INSERT INTO #ListaUsu EXEC SIS.SIS_Usuario_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'celso vê o próprio usuário e o admin', N'2', CONVERT(NVARCHAR(10), COUNT(*)) FROM #ListaUsu WHERE LOGIN IN (N'celso', N'admin');
DELETE FROM #ListaUsu;
INSERT INTO #ListaPerfil EXEC SIS.SIS_Perfil_Listar @IdUsuario = @IdAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin não vê o perfil Administrador geral', N'0', CONVERT(NVARCHAR(10), COUNT(*)) FROM #ListaPerfil WHERE NIVEL_ADMIN = 2;
DELETE FROM #ListaPerfil;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdCelso, @Login = 'celso', @Nome = N'Celso', @IdPerfil = @IdPerfilAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin altera o usuário celso (recusa)', N'Usuário não encontrado.', MENSAGEM FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Senha_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdCelso, @SenhaHash = @Hash, @SenhaSalt = @Salt, @Iteracoes = 600000, @Algoritmo = 'PBKDF2-SHA256';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin define senha do celso (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml, @Login = 'hml.fin', @Nome = N'Usuário de teste', @IdPerfil = @IdPerfilGeral;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin dá perfil Administrador geral (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 5) Permissão efetiva e exceções do usuário
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'hml: Log de erros/VER (do perfil)', N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdHml, 'SIS_LOG_ERRO', 'VER'))),
 (N'hml: Log de erros/EXPORTAR',        N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdHml, 'SIS_LOG_ERRO', 'EXPORTAR'))),
 (N'hml: Usuários/VER',                 N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdHml, 'SIS_USUARIO', 'VER'))),
 (N'admin: Usuários/VER',               N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_USUARIO', 'VER'))),
 (N'admin: Parâmetros/VER (exclusiva)', N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_PARAMETRO', 'VER'))),
 (N'admin: Licença/INCLUIR (exclusiva)',N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_LICENCA', 'INCLUIR'))),
 (N'celso: Parâmetros/ALTERAR',         N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdCelso, 'SIS_PARAMETRO', 'ALTERAR'))),
 (N'celso: Licença/INCLUIR',            N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdCelso, 'SIS_LICENCA', 'INCLUIR'))),
 (N'sistema (interno): qualquer ação',  N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdSistema, 'SIS_USUARIO', 'ALTERAR'))),
 (N'Tela inexistente',                  N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'NAO_EXISTE', 'VER')));

SET @Json = N'[{"id_item_acao":' + CONVERT(NVARCHAR(10), @IaLogExp) + N',"valor":"C"},{"id_item_acao":' + CONVERT(NVARCHAR(10), @IaLogVer) + N',"valor":"R"}]';
INSERT INTO #Ret EXEC SIS.SIS_Permissao_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml, @ListaJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Exceções do usuário: concede EXPORTAR e retira VER (qtd)', N'2', CONVERT(NVARCHAR(10), ID) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'hml: Log de erros/EXPORTAR (concedido)', N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdHml, 'SIS_LOG_ERRO', 'EXPORTAR'))),
 (N'hml: Log de erros/VER (retirado)',       N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdHml, 'SIS_LOG_ERRO', 'VER')));

SET @Json = N'[{"id_item_acao":' + CONVERT(NVARCHAR(10), @IaLogExp) + N',"valor":""},{"id_item_acao":' + CONVERT(NVARCHAR(10), @IaLogVer) + N',"valor":""}]';
INSERT INTO #Ret EXEC SIS.SIS_Permissao_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml, @ListaJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Exceções voltam ao perfil (qtd)', N'2', CONVERT(NVARCHAR(10), ID) FROM #Ret; DELETE FROM #Ret;

SET @Json = N'[{"id_item_acao":' + CONVERT(NVARCHAR(10), @IaLogVer) + N',"valor":"C"}]';
INSERT INTO #Ret EXEC SIS.SIS_Permissao_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml, @ListaJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Conceder o que o perfil já dá não grava (qtd)', N'0', CONVERT(NVARCHAR(10), ID) FROM #Ret; DELETE FROM #Ret;

SET @Json = N'[{"id_item_acao":' + CONVERT(NVARCHAR(10), @IaLogVer) + N',"valor":"R"}]';
INSERT INTO #Ret EXEC SIS.SIS_Permissao_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdAdmin, @ListaJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Retirar permissão do administrador (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 6) Menu
INSERT INTO #Menu EXEC SIS.SIS_Menu_Listar @IdUsuario = @IdHml;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Menu do hml: SIS > Monitoramento > Log de erros', N'MODULO:SIS|MENU:SIS_MONITORAMENTO|TELA:SIS_LOG_ERRO',
       ISNULL(STRING_AGG(CAST(m.TIPO + ':' + m.CODIGO AS NVARCHAR(MAX)), N'|') WITHIN GROUP (ORDER BY m.NIVEL), N'') FROM #Menu m;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Ações da tela no menu do hml', N'VER', ISNULL(MAX(m.ACOES), '') FROM #Menu m WHERE m.TIPO = 'TELA';
DELETE FROM #Menu;

INSERT INTO #Menu EXEC SIS.SIS_Menu_Listar @IdUsuario = @IdAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Menu do admin, sem Configuração (1 módulo + 2 menus + 3 telas)', N'6', CONVERT(NVARCHAR(10), COUNT(*)) FROM #Menu WHERE CODIGO IN ('SIS', 'SIS_SEGURANCA', 'SIS_USUARIO', 'SIS_PERFIL', 'SIS_MONITORAMENTO', 'SIS_LOG_ERRO');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Menu do admin não tem Licença nem Parâmetros', N'0', CONVERT(NVARCHAR(10), COUNT(*)) FROM #Menu WHERE CODIGO IN ('SIS_CONFIGURACAO', 'SIS_LICENCA', 'SIS_PARAMETRO');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Ações de Usuários no menu do admin', N'VER,INCLUIR,ALTERAR,EXPORTAR,DESBLOQUEAR,REDEFINIR_SENHA', ISNULL(MAX(m.ACOES), '') FROM #Menu m WHERE m.CODIGO = 'SIS_USUARIO';
DELETE FROM #Menu;

INSERT INTO #Menu EXEC SIS.SIS_Menu_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Menu do celso (1 módulo + 3 menus + 5 telas)', N'9', CONVERT(NVARCHAR(10), COUNT(*)) FROM #Menu WHERE CODIGO = 'SIS' OR CODIGO IN ('SIS_CONFIGURACAO','SIS_LICENCA','SIS_PARAMETRO','SIS_SEGURANCA','SIS_USUARIO','SIS_PERFIL','SIS_MONITORAMENTO','SIS_LOG_ERRO');
DELETE FROM #Menu;

-- 7) Sem permissão
INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdHml, @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'9';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'hml altera parâmetro (sem permissão)', N'Você não tem permissão para alterar parâmetros.', MENSAGEM FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Licenca_Gravar @IdUsuario = @IdHml, @ChaveLicenca = N'Y', @IdServidor = 'X', @DtEmissao = '2026-11-15', @Modulos = '', @EmpresasJson = N'[]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'hml instala licença (sem permissão)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 8) Senha e login
INSERT INTO #Ret EXEC SIS.SIS_Usuario_Senha_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml, @SenhaHash = @Hash, @SenhaSalt = @Salt, @Iteracoes = 1000, @Algoritmo = 'PBKDF2-SHA256';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Senha com poucas iterações (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Senha_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml, @SenhaHash = @Hash, @SenhaSalt = @Salt, @Iteracoes = 600000, @Algoritmo = 'PBKDF2-SHA256';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Admin define senha provisória', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Senha provisória obriga a trocar', N'1', CONVERT(NVARCHAR(5), u.TROCAR_SENHA) FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdHml;

INSERT INTO #Obter EXEC SIS.SIS_Usuario_Login_Obter @Login = N' HML.FIN ';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login_Obter acha o usuário (maiúsculas e espaços)', N'1', CONVERT(NVARCHAR(5), ENCONTRADO) FROM #Obter;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login_Obter devolve o hash gravado', N'1', CONVERT(NVARCHAR(5), CASE WHEN o.SENHA_HASH = @Hash THEN 1 ELSE 0 END) FROM #Obter o;
DELETE FROM #Obter;

INSERT INTO #Obter EXEC SIS.SIS_Usuario_Login_Obter @Login = N'sistema';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login_Obter não acha o usuário interno', N'0', CONVERT(NVARCHAR(5), ENCONTRADO) FROM #Obter;
DELETE FROM #Obter;

SET @Vez = 1;
WHILE @Vez <= 4
BEGIN
    INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.fin', @SenhaConferida = 0, @Ip = '127.0.0.1', @Estacao = N'HOMOLOGACAO';
    SET @Vez = @Vez + 1;
END;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'4 senhas erradas: nenhuma entrou', N'0', CONVERT(NVARCHAR(5), SUM(CAST(SUCESSO AS INT))) FROM #RetLogin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT TOP (1) N'Aviso na 4ª tentativa', N'Usuário ou senha inválidos. Restam 1 tentativa(s) antes do bloqueio.', MENSAGEM FROM #RetLogin ORDER BY MENSAGEM;
DELETE FROM #RetLogin;

INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.fin', @SenhaConferida = 0, @Ip = '127.0.0.1', @Estacao = N'HOMOLOGACAO';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'5ª senha errada bloqueia', N'1', CONVERT(NVARCHAR(5), u.BLOQUEADO) FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdHml;
DELETE FROM #RetLogin;

INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.fin', @SenhaConferida = 1, @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Senha certa com usuário bloqueado (recusa)', N'Usuário bloqueado por excesso de tentativas. Procure o administrador do sistema.', MENSAGEM FROM #RetLogin;
DELETE FROM #RetLogin;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Desbloquear @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Desbloquear', N'Usuário desbloqueado.', MENSAGEM FROM #Ret; DELETE FROM #Ret;

INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.fin', @SenhaConferida = 1, @TokenHash = @TokenHash, @Ip = '127.0.0.1', @Estacao = N'HOMOLOGACAO', @Navegador = N'SSMS';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login correto', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #RetLogin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login pede troca de senha', N'1', CONVERT(NVARCHAR(5), TROCAR_SENHA) FROM #RetLogin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login abriu sessão', N'S', CASE WHEN ID_SESSAO IS NOT NULL THEN N'S' ELSE N'N' END FROM #RetLogin;
DELETE FROM #RetLogin;

INSERT INTO #RetSessao EXEC SIS.SIS_Sessao_Validar @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Sessão válida', N'hml.fin', LOGIN FROM #RetSessao; DELETE FROM #RetSessao;

INSERT INTO #Ret EXEC SIS.SIS_Usuario_Senha_Gravar @IdUsuario = @IdHml, @IdUsuarioAlvo = @IdHml, @SenhaHash = @Hash2, @SenhaSalt = @Salt, @Iteracoes = 600000, @Algoritmo = 'PBKDF2-SHA256';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Usuário troca a própria senha', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Troca própria tira a obrigação', N'0', CONVERT(NVARCHAR(5), u.TROCAR_SENHA) FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdHml;

INSERT INTO #RetSessao EXEC SIS.SIS_Sessao_Validar @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Sessão continua após troca própria', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #RetSessao; DELETE FROM #RetSessao;

INSERT INTO #RetEnc EXEC SIS.SIS_Sessao_Encerrar @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Sair (encerrar sessão)', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #RetEnc; DELETE FROM #RetEnc;

INSERT INTO #RetSessao EXEC SIS.SIS_Sessao_Validar @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Sessão encerrada não vale', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #RetSessao; DELETE FROM #RetSessao;

-- Expiração por inatividade
SET @Token = CRYPT_GEN_RANDOM(32);
SET @TokenHash = HASHBYTES('SHA2_256', @Token);
INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.fin', @SenhaConferida = 1, @TokenHash = @TokenHash;
DELETE FROM #RetLogin;
UPDATE s SET s.DT_ULTIMO_ACESSO = DATEADD(HOUR, -5, SYSDATETIME()) FROM SIS.Sessao s WHERE s.TOKEN_HASH = @TokenHash;
INSERT INTO #RetSessao EXEC SIS.SIS_Sessao_Validar @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Sessão parada há 5 horas expira', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #RetSessao; DELETE FROM #RetSessao;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Motivo do fim da sessão', N'EXPIRADA', s.MOTIVO_FIM FROM SIS.Sessao s WHERE s.TOKEN_HASH = @TokenHash;

-- Senha provisória do admin encerra as sessões do usuário
SET @Token = CRYPT_GEN_RANDOM(32);
SET @TokenHash = HASHBYTES('SHA2_256', @Token);
INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.fin', @SenhaConferida = 1, @TokenHash = @TokenHash;
DELETE FROM #RetLogin;
INSERT INTO #Ret EXEC SIS.SIS_Usuario_Senha_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml, @SenhaHash = @Hash, @SenhaSalt = @Salt, @Iteracoes = 600000, @Algoritmo = 'PBKDF2-SHA256';
DELETE FROM #Ret;
INSERT INTO #RetSessao EXEC SIS.SIS_Sessao_Validar @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Nova senha provisória derruba a sessão', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #RetSessao; DELETE FROM #RetSessao;

-- Usuário desativado não entra
INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdAdmin, @IdUsuarioAlvo = @IdHml, @Login = 'hml.fin', @Nome = N'Usuário de teste', @IdPerfil = @IdPerfilHml, @Ativo = 0;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Desativar usuário', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.fin', @SenhaConferida = 1, @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Usuário inativo não entra', N'Usuário inativo. Procure o administrador do sistema.', MENSAGEM FROM #RetLogin; DELETE FROM #RetLogin;

-- Login inexistente e interno
INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'hml.naoexiste', @SenhaConferida = 0;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login inexistente (mensagem genérica)', N'Usuário ou senha inválidos.', MENSAGEM FROM #RetLogin; DELETE FROM #RetLogin;
INSERT INTO #RetLogin EXEC SIS.SIS_Usuario_Login_Processar @Login = N'sistema', @SenhaConferida = 1, @TokenHash = @TokenHash;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Usuário interno não entra', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #RetLogin; DELETE FROM #RetLogin;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Login_Log das tentativas do teste', N'BLOQUEADO,BLOQUEOU,INATIVO,INEXISTENTE,OK,SENHA_ERRADA',
       ISNULL(STRING_AGG(CAST(x.RESULTADO AS NVARCHAR(MAX)), N',') WITHIN GROUP (ORDER BY x.RESULTADO), N'')
FROM (SELECT DISTINCT ll.RESULTADO FROM SIS.Login_Log ll WHERE ll.LOGIN_INFORMADO LIKE N'hml.%') x;

-- 9) Resultado
SELECT N'TESTES' AS GRADE, t.ID, t.TESTE, t.ESPERADO, t.OBTIDO,
       CASE WHEN t.OBTIDO COLLATE Latin1_General_CS_AS = t.ESPERADO THEN N'OK' ELSE N'FALHOU' END AS RESULTADO
FROM #Teste t
ORDER BY t.ID;

SELECT N'RESUMO' AS GRADE,
       COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN t.OBTIDO COLLATE Latin1_General_CS_AS = t.ESPERADO THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste t;

-- 10) Limpeza (a licença de desenvolvimento fica instalada)
DELETE ll FROM SIS.Login_Log ll WHERE ll.LOGIN_INFORMADO LIKE N'hml.%' OR ll.LOGIN_INFORMADO = N'sistema'
                                   OR ll.ID_USUARIO IN (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN LIKE 'hml.%');
DELETE s  FROM SIS.Sessao s INNER JOIN SIS.Usuario u ON u.ID_USUARIO = s.ID_USUARIO WHERE u.LOGIN LIKE 'hml.%';
DELETE up FROM SIS.Usuario_Permissao up INNER JOIN SIS.Usuario u ON u.ID_USUARIO = up.ID_USUARIO WHERE u.LOGIN LIKE 'hml.%';
DELETE u  FROM SIS.Usuario u WHERE u.LOGIN LIKE 'hml.%';
DELETE pp FROM SIS.Perfil_Permissao pp INNER JOIN SIS.Perfil p ON p.ID_PERFIL = pp.ID_PERFIL WHERE p.NOME LIKE N'HML %';
DELETE p  FROM SIS.Perfil p WHERE p.NOME LIKE N'HML %';

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
DROP TABLE IF EXISTS #RetLogin;
DROP TABLE IF EXISTS #RetSessao;
DROP TABLE IF EXISTS #RetEnc;
DROP TABLE IF EXISTS #Obter;
DROP TABLE IF EXISTS #Menu;
DROP TABLE IF EXISTS #Lic;
DROP TABLE IF EXISTS #ListaUsu;
DROP TABLE IF EXISTS #ListaPerfil;
GO

SET NOEXEC OFF;
GO
