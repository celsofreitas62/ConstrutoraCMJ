/*******************************************************************************
  Homologação : etapa 02d da base SIS (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Testa módulo Compras (COMP), e-mail (validação, domínio,
                grupos, moldura HTML, fila com modo teste, captura,
                resultado, nova tentativa, alerta, reenviar/cancelar, presos),
                agenda das rotinas (próxima execução, gravar agenda, rodar,
                erro, executar agora, presa) e comandos de instalação
                (pedido, recusas, captura um por vez, resultado, cancelar),
                além do papel da API.
                Cada teste mostra ESPERADO x OBTIDO e RESULTADO (OK/FALHOU).
                Dados de teste (HML_*, e-mails "Hml 02d", pedidos de comando
                do teste) são apagados no fim; parâmetros e agendas mexidos
                voltam ao valor original (agendas reais recalculadas a partir de agora).
                Aborta se não estiver no SISTEMACMJ_LOCAL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

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
DELETE l FROM SIS.Email_Log l INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = l.ID_EMAIL WHERE f.TIPO = 'HML_TESTE' OR f.ASSUNTO LIKE N'%Hml 02d%';
DELETE a FROM SIS.Email_Fila_Anexo a INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = a.ID_EMAIL WHERE f.TIPO = 'HML_TESTE' OR f.ASSUNTO LIKE N'%Hml 02d%';
DELETE FROM SIS.Email_Fila WHERE TIPO = 'HML_TESTE' OR ASSUNTO LIKE N'%Hml 02d%';
DELETE l FROM SIS.Email_Log l INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = l.ID_EMAIL WHERE f.TIPO = 'ALERTA_EMAIL' AND f.PARA_ORIGINAL = N'alerta.hml@teste.com.br';
DELETE FROM SIS.Email_Fila WHERE TIPO = 'ALERTA_EMAIL' AND PARA_ORIGINAL = N'alerta.hml@teste.com.br';
DELETE e FROM SIS.Rotina_Execucao e INNER JOIN SIS.Rotina r ON r.ID_ROTINA = e.ID_ROTINA WHERE r.CODIGO LIKE 'HML[_]%';
DELETE FROM SIS.Rotina WHERE CODIGO LIKE 'HML[_]%';
DELETE d FROM SIS.Grupo_Email_Destinatario d INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = d.ID_GRUPO_EMAIL WHERE g.CODIGO LIKE 'HML[_]%';
DELETE FROM SIS.Grupo_Email WHERE CODIGO LIKE 'HML[_]%';
DELETE FROM SIS.Comando_Fila WHERE STATUS IN ('PENDENTE', 'EXECUTANDO');

EXEC (N'CREATE OR ALTER PROCEDURE SIS.SIS_Hml_Rotina_Ok AS BEGIN SET NOCOUNT ON; DECLARE @x INT = 1; END;');
EXEC (N'CREATE OR ALTER PROCEDURE SIS.SIS_Hml_Rotina_Erro AS BEGIN SET NOCOUNT ON; THROW 50000, N''Erro de teste da rotina'', 1; END;');

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
DROP TABLE IF EXISTS #Ret64;
DROP TABLE IF EXISTS #Cap;
DROP TABLE IF EXISTS #Grupo;
DROP TABLE IF EXISTS #EmailLista;
DROP TABLE IF EXISTS #Rot;
DROP TABLE IF EXISTS #Cmd;
DROP TABLE IF EXISTS #CmdCap;
DROP TABLE IF EXISTS #ProxRotina;

CREATE TABLE #Teste  (ID INT IDENTITY(1,1), TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));
CREATE TABLE #Ret    (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
CREATE TABLE #Ret64  (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);
CREATE TABLE #Cap    (ID_EMAIL BIGINT, TIPO VARCHAR(30), CONTA VARCHAR(10), PARA NVARCHAR(2000), CC NVARCHAR(2000), CCO NVARCHAR(2000), ASSUNTO NVARCHAR(400),
                      CORPO_HTML NVARCHAR(MAX), TENTATIVAS INT, MODO_TESTE BIT, ANEXOS_JSON NVARCHAR(MAX));
CREATE TABLE #Grupo  (ID_GRUPO_EMAIL INT, CODIGO VARCHAR(30), NOME NVARCHAR(80), DESCRICAO NVARCHAR(400), ATIVO BIT, QTD_DESTINATARIOS INT, DESTINATARIOS NVARCHAR(MAX),
                      DT_ALTERACAO DATETIME2(0), USUARIO_ALTERACAO NVARCHAR(100));
CREATE TABLE #EmailLista (ID_EMAIL BIGINT, DT_CRIACAO DATETIME2(0), TIPO VARCHAR(30), CONTA VARCHAR(10), STATUS VARCHAR(12), PARA NVARCHAR(2000), PARA_ORIGINAL NVARCHAR(4000),
                      ASSUNTO NVARCHAR(400), TENTATIVAS INT, PROXIMA_TENTATIVA DATETIME2(0), DT_ENVIO DATETIME2(0), ULTIMO_ERRO NVARCHAR(1000), MODO_TESTE BIT,
                      ORIGEM NVARCHAR(256), GRUPO VARCHAR(30), ID_LOTE BIGINT, QTD_ANEXOS INT);
CREATE TABLE #Rot    (ID_ROTINA INT, CODIGO VARCHAR(40), NOME NVARCHAR(80), DESCRICAO NVARCHAR(400), MODULO_CODIGO VARCHAR(10), MODULO_DISPONIVEL BIT, FREQUENCIA VARCHAR(10),
                      INTERVALO_MINUTOS INT, HORARIO VARCHAR(5), DIAS_SEMANA VARCHAR(20), DIA_MES TINYINT, AGENDA_TEXTO NVARCHAR(200), TEMPO_LIMITE_MINUTOS INT, ATIVA BIT,
                      EM_EXECUCAO BIT, PROXIMA_EXECUCAO DATETIME2(0), SOLICITADA_POR NVARCHAR(100), ULTIMA_EXECUCAO DATETIME2(0), ULTIMO_RESULTADO VARCHAR(10),
                      ULTIMA_MENSAGEM NVARCHAR(1000), PROCEDIMENTO NVARCHAR(256));
CREATE TABLE #Cmd    (ID_COMANDO INT, CODIGO VARCHAR(40), NOME NVARCHAR(80), DESCRICAO NVARCHAR(1000), GRUPO VARCHAR(20), GRUPO_NOME NVARCHAR(40), ORDEM SMALLINT, PERIGOSO BIT,
                      ACEITA_PARAMETRO BIT, PARAMETRO_DESCRICAO NVARCHAR(200), ULTIMO_PEDIDO BIGINT, ULTIMO_STATUS VARCHAR(12), ULTIMO_DT_PEDIDO DATETIME2(0),
                      ULTIMO_USUARIO NVARCHAR(100), ULTIMO_DT_FIM DATETIME2(0));
CREATE TABLE #CmdCap (ID_PEDIDO BIGINT, CODIGO VARCHAR(40), PARAMETRO NVARCHAR(400));
CREATE TABLE #ProxRotina (CODIGO VARCHAR(40), PROXIMA DATETIME2(0));

DECLARE @IdCelso      INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
DECLARE @IdAdmin      INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'admin');
DECLARE @IdModSis     INT = (SELECT m.ID_MODULO FROM SIS.Modulo m WHERE m.CODIGO = 'SIS');
DECLARE @EmailTeste   NVARCHAR(4000) = SIS.fn_SIS_Parametro('EMAIL_TESTE');
DECLARE @DominioOrig  NVARCHAR(4000) = (SELECT p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_DOMINIO_INTERNO');
DECLARE @AlertaOrig   NVARCHAR(4000) = (SELECT p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_ADMIN_ALERTA');
DECLARE @AudInicio    BIGINT = ISNULL((SELECT MAX(a.ID_AUDITORIA) FROM SIS.Auditoria a), 0);
DECLARE @ErroInicio   BIGINT = ISNULL((SELECT MAX(e.ID_LOG_ERRO) FROM SIS.Log_Erro e), 0);
DECLARE @CmdInicio    BIGINT = ISNULL((SELECT MAX(f.ID_PEDIDO) FROM SIS.Comando_Fila f), 0);
DECLARE @IdGrupo      INT;
DECLARE @Id1          BIGINT;
DECLARE @Id1b         BIGINT;
DECLARE @Id2          BIGINT;
DECLARE @Id3          BIGINT;
DECLARE @IdNada       BIGINT;
DECLARE @Html         NVARCHAR(MAX);
DECLARE @PedidoA      BIGINT;
DECLARE @PedidoB      BIGINT;
DECLARE @PedidoC      BIGINT;

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-02D', @Origem = N'teste-02d';

-- Agendas reais ficam para depois durante o teste (só rodam as HML_)
INSERT INTO #ProxRotina (CODIGO, PROXIMA) SELECT r.CODIGO, r.PROXIMA_EXECUCAO FROM SIS.Rotina r WHERE r.CODIGO NOT LIKE 'HML[_]%';
UPDATE SIS.Rotina SET PROXIMA_EXECUCAO = DATEADD(DAY, 1, SYSDATETIME()) WHERE CODIGO NOT LIKE 'HML[_]%';

-- 1) Objetos e cargas
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Objeto ' + v.NOME, v.TIPO, ISNULL((SELECT o.type_desc FROM sys.objects o WHERE o.object_id = OBJECT_ID(v.NOME)), N'(não existe)')
FROM (VALUES
        (N'SIS.Grupo_Email', N'USER_TABLE'), (N'SIS.Grupo_Email_Destinatario', N'USER_TABLE'), (N'SIS.Email_Fila', N'USER_TABLE'),
        (N'SIS.Email_Fila_Anexo', N'USER_TABLE'), (N'SIS.Email_Log', N'USER_TABLE'), (N'SIS.Rotina', N'USER_TABLE'),
        (N'SIS.Rotina_Execucao', N'USER_TABLE'), (N'SIS.Comando', N'USER_TABLE'), (N'SIS.Comando_Fila', N'USER_TABLE'),
        (N'SIS.fn_SIS_Email_Valido', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Emails_Do_Grupo', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.fn_SIS_Filtrar_Emails_Por_Dominio', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Email_HTML', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.fn_SIS_Rotina_Proxima', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.SIS_Email_Enfileirar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Email_Capturar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Email_Resultado_Gravar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Email_Presos_Liberar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Email_Listar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Email_Obter', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Email_Situacao_Gravar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Grupo_Email_Listar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Grupo_Email_Gravar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Rotina_Processar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Rotina_Listar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Rotina_Gravar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Rotina_Executar_Agora', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Rotina_Execucao_Listar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Comando_Listar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Comando_Solicitar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Comando_Cancelar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Comando_Fila_Listar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Comando_Capturar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Comando_Resultado_Gravar', N'SQL_STORED_PROCEDURE')
     ) v (NOME, TIPO);

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Schema COMP criado', N'1', CASE WHEN SCHEMA_ID(N'COMP') IS NULL THEN N'0' ELSE N'1' END),
 (N'Módulo Compras: ordem/licença/habilitado', N'45/0/0',
  ISNULL((SELECT CONVERT(NVARCHAR(5), m.ORDEM_MENU) + N'/' + CONVERT(NVARCHAR(1), m.LIBERADO_LICENCA) + N'/' + CONVERT(NVARCHAR(1), m.HABILITADO) FROM SIS.Modulo m WHERE m.CODIGO = 'COMP'), N'(não existe)')),
 (N'Ação EXECUTAR cadastrada', N'1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Acao a WHERE a.CODIGO = 'EXECUTAR'))),
 (N'Itens novos da 02d', N'5', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Item i WHERE i.CODIGO IN ('SIS_ROTINA','SIS_INSTALACAO','SIS_EMAILS','SIS_GRUPO_EMAIL','SIS_EMAIL_FILA')))),
 (N'Parâmetros novos da 02d', N'5', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Parametro p WHERE p.CHAVE IN ('EMAIL_DOMINIO_INTERNO','EMAIL_MINUTOS_PRESO','BACKUP_PASTA','BACKUP_PASTA_EXTERNA','ATUALIZACAO_PASTA')))),
 (N'Rotinas da carga (com próxima execução)', N'2', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM #ProxRotina p WHERE p.CODIGO IN ('LOG_LIMPEZA','EMAIL_PRESOS') AND p.PROXIMA IS NOT NULL))),
 (N'Comandos da carga', N'14', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Comando c WHERE c.ATIVO = 1))),
 (N'Triggers de auditoria (13 + 4)', N'17', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.triggers t WHERE t.name LIKE N'tg[_]SIS[_]%[_]Auditoria' AND t.name <> N'tg_SIS_Auditoria_Protecao'))),
 (N'Fila de e-mail não é auditada', N'0', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.triggers t WHERE t.parent_id = OBJECT_ID(N'SIS.Email_Fila')))),
 (N'celso: Rotinas/EXECUTAR e Instalação/EXECUTAR', N'1/1',
  CONVERT(NVARCHAR(1), SIS.fn_SIS_Tem_Permissao(@IdCelso, 'SIS_ROTINA', 'EXECUTAR')) + N'/' + CONVERT(NVARCHAR(1), SIS.fn_SIS_Tem_Permissao(@IdCelso, 'SIS_INSTALACAO', 'EXECUTAR'))),
 (N'admin (CMJ): sem Rotinas e sem Instalação (exclusivas)', N'0/0',
  CONVERT(NVARCHAR(1), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_ROTINA', 'VER')) + N'/' + CONVERT(NVARCHAR(1), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_INSTALACAO', 'VER'))),
 (N'admin (CMJ): grupos de e-mail e reenviar e-mail', N'1/1',
  CONVERT(NVARCHAR(1), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_GRUPO_EMAIL', 'INCLUIR')) + N'/' + CONVERT(NVARCHAR(1), SIS.fn_SIS_Tem_Permissao(@IdAdmin, 'SIS_EMAIL_FILA', 'ENVIAR'))),
 (N'Papel da API criado', N'1', CASE WHEN DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NULL THEN N'0' ELSE N'1' END),
 (N'Papel da API: EXECUTE no schema SIS', N'GRANT',
  ISNULL((SELECT TOP (1) p.state_desc FROM sys.database_permissions p WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api')
          AND p.class_desc = N'SCHEMA' AND p.major_id = SCHEMA_ID(N'SIS') AND p.permission_name = N'EXECUTE'), N'(nada)')),
 (N'Papel da API: DENY na auditoria (insert/update/delete)', N'3',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.database_permissions p WHERE p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api')
          AND p.major_id = OBJECT_ID(N'SIS.Auditoria') AND p.state_desc = N'DENY' AND p.permission_name IN (N'INSERT', N'UPDATE', N'DELETE'))));

-- 2) Funções de e-mail
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'E-mail válido / sem @ / sem ponto / acento / ".." / ponto no fim', N'1|0|0|0|0|0',
  CONVERT(NVARCHAR(1), SIS.fn_SIS_Email_Valido(N'financeiro@cmj.com.br')) + N'|' + CONVERT(NVARCHAR(1), SIS.fn_SIS_Email_Valido(N'sem arroba.com')) + N'|'
  + CONVERT(NVARCHAR(1), SIS.fn_SIS_Email_Valido(N'a@b')) + N'|' + CONVERT(NVARCHAR(1), SIS.fn_SIS_Email_Valido(N'joão@x.com')) + N'|'
  + CONVERT(NVARCHAR(1), SIS.fn_SIS_Email_Valido(N'a..b@x.com')) + N'|' + CONVERT(NVARCHAR(1), SIS.fn_SIS_Email_Valido(N'a@x.com.'))),
 (N'E-mail com _ + - aceito', N'1', CONVERT(NVARCHAR(1), SIS.fn_SIS_Email_Valido(N'nao_responda+fin-01@cmj.com.br')));

UPDATE SIS.Parametro SET VALOR = N'' WHERE CHAVE = 'EMAIL_DOMINIO_INTERNO';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Domínio interno vazio: todos internos', N'a@cmj.com.br; b@gmail.com', SIS.fn_SIS_Filtrar_Emails_Por_Dominio(N'a@cmj.com.br, b@gmail.com; a@cmj.com.br', 1)),
 (N'Domínio interno vazio: nenhum externo', N'', SIS.fn_SIS_Filtrar_Emails_Por_Dominio(N'a@cmj.com.br, b@gmail.com', 0));
UPDATE SIS.Parametro SET VALOR = N'cmj.com.br' WHERE CHAVE = 'EMAIL_DOMINIO_INTERNO';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Domínio cmj.com.br: internos', N'a@cmj.com.br; c@CMJ.com.br', SIS.fn_SIS_Filtrar_Emails_Por_Dominio(N'a@cmj.com.br; b@gmail.com; c@CMJ.com.br', 1)),
 (N'Domínio cmj.com.br: externos', N'b@gmail.com', SIS.fn_SIS_Filtrar_Emails_Por_Dominio(N'a@cmj.com.br; b@gmail.com; c@CMJ.com.br', 0));
UPDATE SIS.Parametro SET VALOR = ISNULL(@DominioOrig, N'') WHERE CHAVE = 'EMAIL_DOMINIO_INTERNO';

SET @Html = SIS.fn_SIS_Email_HTML(N'Teste <1>', 'INFO', N'<p>miolo</p>', N'[SIS].[Teste]', 'HML_GRUPO', 0);
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'HTML informativo: cor principal, logomarca, título escapado, rodapé', N'1|1|1|1|1',
  CASE WHEN @Html LIKE N'%' + SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL') + N'%' THEN N'1' ELSE N'0' END + N'|'
  + CASE WHEN @Html LIKE N'%cid:logo[_]empresa%' THEN N'1' ELSE N'0' END + N'|'
  + CASE WHEN @Html LIKE N'%TESTE &lt;1&gt;%' THEN N'1' ELSE N'0' END + N'|'
  + CASE WHEN @Html LIKE N'%Gerado automaticamente pelo sistema SistemaCMJ: `[SIS`]`.`[Teste`]%' ESCAPE N'`' THEN N'1' ELSE N'0' END + N'|'
  + CASE WHEN @Html LIKE N'%Grupo de Destinatários: HML[_]GRUPO%' THEN N'1' ELSE N'0' END);
SET @Html = SIS.fn_SIS_Email_HTML(N'Vencido', 'ALERTA', N'', N'[SIS].[Teste]', '', 1);
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'HTML alerta externo: cor de alerta, "ALERTA -", sem dados técnicos', N'1|1|1',
  CASE WHEN @Html LIKE N'%' + SIS.fn_SIS_Parametro_Cor('EMAIL_COR_ALERTA') + N'%' THEN N'1' ELSE N'0' END + N'|'
  + CASE WHEN @Html LIKE N'%ALERTA - VENCIDO%' THEN N'1' ELSE N'0' END + N'|'
  + CASE WHEN @Html NOT LIKE N'%Gerado automaticamente%' AND @Html LIKE N'%não responda%' THEN N'1' ELSE N'0' END);

-- 3) Grupos de e-mail
INSERT INTO #Ret EXEC SIS.SIS_Grupo_Email_Gravar @IdUsuario = @IdCelso, @IdGrupoEmail = NULL, @Codigo = 'hml_grupo', @Nome = N'Hml grupo',
     @Destinatarios = N'x@teste.com.br; y@teste.com.br, X@teste.com.br';
SELECT @IdGrupo = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Grupo incluído (código em maiúscula)', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Destinatários sem repetir', N'x@teste.com.br; y@teste.com.br', SIS.fn_SIS_Emails_Do_Grupo('HML_GRUPO'));

INSERT INTO #Ret EXEC SIS.SIS_Grupo_Email_Gravar @IdUsuario = @IdCelso, @IdGrupoEmail = @IdGrupo, @Codigo = 'HML_GRUPO', @Nome = N'Hml grupo',
     @Destinatarios = N'y@teste.com.br; endereco errado';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Endereço inválido recusado', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Grupo_Email_Gravar @IdUsuario = @IdCelso, @IdGrupoEmail = @IdGrupo, @Codigo = 'HML_OUTRO', @Nome = N'Hml grupo',
     @Destinatarios = N'y@teste.com.br';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Troca de código recusada', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Grupo_Email_Gravar @IdUsuario = @IdCelso, @IdGrupoEmail = @IdGrupo, @Codigo = 'HML_GRUPO', @Nome = N'Hml grupo',
     @Destinatarios = N'y@teste.com.br
z@teste.com.br';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Lista trocada (sai x, entra z)', N'1|y@teste.com.br; z@teste.com.br', CONVERT(NVARCHAR(5), SUCESSO) + N'|' + SIS.fn_SIS_Emails_Do_Grupo('HML_GRUPO') FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Saída do x ficou na auditoria', N'1', CONVERT(NVARCHAR(5), COUNT(*))
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Grupo_Email_Destinatario' AND a.OPERACAO = 'E' AND a.VALOR_ANTES LIKE N'%x@teste.com.br%';

INSERT INTO #Grupo EXEC SIS.SIS_Grupo_Email_Listar @IdUsuario = @IdAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Tela de grupos (admin) mostra o grupo', N'2', CONVERT(NVARCHAR(5), QTD_DESTINATARIOS) FROM #Grupo WHERE CODIGO = 'HML_GRUPO';

-- 4) Fila de e-mail
EXEC SIS.SIS_Email_Enfileirar @Para = N'cliente@exemplo.com.br; invalido', @Assunto = N'Hml 02d um
quebra', @CorpoHTML = N'<p>1</p>', @Tipo = 'hml_teste', @Origem = N'teste-02d', @ChaveOrigem = N'HML02D:1',
     @Anexos = N'[{"caminho":"C:\\SistemaCMJ_Arquivos\\Anexos\\x\\boleto.pdf"},{"caminho":"C:\\t\\a.pdf","nome":"Boleto_CMJ.pdf"}]', @IdEmail = @Id1 OUTPUT;
EXEC SIS.SIS_Email_Enfileirar @Para = N'outro@exemplo.com.br', @Assunto = N'Hml 02d um de novo', @CorpoHTML = N'<p>1</p>', @Tipo = 'HML_TESTE',
     @Origem = N'teste-02d', @ChaveOrigem = N'HML02D:1', @IdEmail = @Id1b OUTPUT;
EXEC SIS.SIS_Email_Enfileirar @Para = N'sem-arroba; tambem errado', @Assunto = N'Hml 02d nada', @CorpoHTML = N'<p>x</p>', @Tipo = 'HML_TESTE',
     @Origem = N'teste-02d', @IdEmail = @IdNada OUTPUT;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Enfileirado em modo teste (para, assunto, original, modo)', ISNULL(@EmailTeste, N'') + N'|[TESTE] Hml 02d um quebra|cliente@exemplo.com.br|1',
       f.PARA + N'|' + f.ASSUNTO + N'|' + f.PARA_ORIGINAL + N'|' + CONVERT(NVARCHAR(1), f.MODO_TESTE)
FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @Id1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Mesma chave de origem devolve o mesmo e-mail', N'S', CASE WHEN @Id1b = @Id1 THEN N'S' ELSE N'N' END),
 (N'Sem destinatário válido: não enfileira', N'(nulo)', ISNULL(CONVERT(NVARCHAR(20), @IdNada), N'(nulo)')),
 (N'Anexos (nome tirado do caminho / nome dado)', N'boleto.pdf|Boleto_CMJ.pdf',
  ISNULL((SELECT STRING_AGG(a.NOME_EXIBICAO, N'|') WITHIN GROUP (ORDER BY a.ORDEM) FROM SIS.Email_Fila_Anexo a WHERE a.ID_EMAIL = @Id1), N'')),
 (N'Tipo gravado em maiúscula', N'HML_TESTE', ISNULL((SELECT f.TIPO FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @Id1), N''));
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Endereços descartados registrados no log', N'S', CASE WHEN COUNT(*) >= 2 THEN N'S' ELSE N'N' END
FROM SIS.Log_Erro e WHERE e.ID_LOG_ERRO > @ErroInicio AND e.ROTINA = N'[SIS].[SIS_Email_Enfileirar]';

INSERT INTO #Cap EXEC SIS.SIS_Email_Capturar @Servidor = N'HML-SERVIDOR', @Quantidade = 50;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Captura: processando, 1ª tentativa, 2 anexos no JSON', N'PROCESSANDO|1|2',
       (SELECT f.STATUS FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @Id1) + N'|' + CONVERT(NVARCHAR(5), c.TENTATIVAS) + N'|'
       + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM OPENJSON(c.ANEXOS_JSON)))
FROM #Cap c WHERE c.ID_EMAIL = @Id1;
DELETE FROM #Cap;
INSERT INTO #Cap EXEC SIS.SIS_Email_Capturar @Servidor = N'HML-SERVIDOR', @Quantidade = 50;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Captura de novo não pega o mesmo', N'0', CONVERT(NVARCHAR(5), COUNT(*)) FROM #Cap WHERE ID_EMAIL = @Id1; DELETE FROM #Cap;

INSERT INTO #Ret64 EXEC SIS.SIS_Email_Resultado_Gravar @IdEmail = @Id1, @Resultado = 'ERRO_TEMPORARIO', @Mensagem = N'SMTP fora (teste)', @Servidor = N'HML-SERVIDOR';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Erro temporário: volta para a fila em 1 min', N'1|PENDENTE|S', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + f.STATUS + N'|'
       + CASE WHEN f.PROXIMA_TENTATIVA > SYSDATETIME() THEN N'S' ELSE N'N' END
FROM #Ret64 r CROSS JOIN SIS.Email_Fila f WHERE f.ID_EMAIL = @Id1; DELETE FROM #Ret64;

UPDATE SIS.Email_Fila SET PROXIMA_TENTATIVA = DATEADD(MINUTE, -1, SYSDATETIME()) WHERE ID_EMAIL = @Id1;
INSERT INTO #Cap EXEC SIS.SIS_Email_Capturar @Servidor = N'HML-SERVIDOR', @Quantidade = 50; DELETE FROM #Cap;
INSERT INTO #Ret64 EXEC SIS.SIS_Email_Resultado_Gravar @IdEmail = @Id1, @Resultado = 'ENVIADO', @Servidor = N'HML-SERVIDOR';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Enviado na 2ª tentativa (2 linhas no histórico)', N'ENVIADO|2|2', f.STATUS + N'|' + CONVERT(NVARCHAR(5), f.TENTATIVAS) + N'|'
       + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Email_Log l WHERE l.ID_EMAIL = @Id1))
FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @Id1; DELETE FROM #Ret64;

INSERT INTO #Ret64 EXEC SIS.SIS_Email_Resultado_Gravar @IdEmail = @Id1, @Resultado = 'ENVIADO';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Resultado de e-mail que não está processando (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;

-- Erro permanente com alerta ao administrador
UPDATE SIS.Parametro SET VALOR = N'alerta.hml@teste.com.br' WHERE CHAVE = 'EMAIL_ADMIN_ALERTA';
EXEC SIS.SIS_Email_Enfileirar @Para = N'dois@exemplo.com.br', @Assunto = N'Hml 02d dois', @CorpoHTML = N'<p>2</p>', @Tipo = 'HML_TESTE',
     @Origem = N'teste-02d', @ChaveOrigem = N'HML02D:2', @IdEmail = @Id2 OUTPUT;
INSERT INTO #Cap EXEC SIS.SIS_Email_Capturar @Servidor = N'HML-SERVIDOR', @Quantidade = 50; DELETE FROM #Cap;
INSERT INTO #Ret64 EXEC SIS.SIS_Email_Resultado_Gravar @IdEmail = @Id2, @Resultado = 'ERRO_PERMANENTE', @Mensagem = N'Caixa não existe (teste)';
DELETE FROM #Ret64;
UPDATE SIS.Parametro SET VALOR = ISNULL(@AlertaOrig, N'') WHERE CHAVE = 'EMAIL_ADMIN_ALERTA';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Erro permanente: marcado como erro', N'ERRO', ISNULL((SELECT f.STATUS FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @Id2), N'')),
 (N'Alerta técnico enfileirado (1 vez, tipo ALERTA_EMAIL)', N'1|ALERTA_EMAIL',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Email_Fila f WHERE f.CHAVE_ORIGEM = N'ALERTA_EMAIL:' + CONVERT(NVARCHAR(20), @Id2))) + N'|'
  + ISNULL((SELECT f.TIPO FROM SIS.Email_Fila f WHERE f.CHAVE_ORIGEM = N'ALERTA_EMAIL:' + CONVERT(NVARCHAR(20), @Id2)), N''));

-- Reenviar e cancelar pela tela
INSERT INTO #Ret64 EXEC SIS.SIS_Email_Situacao_Gravar @IdUsuario = @IdAdmin, @IdEmail = @Id2, @Acao = 'REENVIAR';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Reenviar e-mail com erro (admin)', N'1|PENDENTE|0', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + f.STATUS + N'|' + CONVERT(NVARCHAR(5), f.TENTATIVAS)
FROM #Ret64 r CROSS JOIN SIS.Email_Fila f WHERE f.ID_EMAIL = @Id2; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Email_Situacao_Gravar @IdUsuario = @IdCelso, @IdEmail = @Id1, @Acao = 'REENVIAR';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Reenviar e-mail já enviado (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Email_Situacao_Gravar @IdUsuario = @IdCelso, @IdEmail = @Id2, @Acao = 'CANCELAR';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Cancelar sem motivo (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Email_Situacao_Gravar @IdUsuario = @IdCelso, @IdEmail = @Id2, @Acao = 'CANCELAR', @Motivo = N'Teste 02d';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Cancelar com motivo', N'1|CANCELADO', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + f.STATUS
FROM #Ret64 r CROSS JOIN SIS.Email_Fila f WHERE f.ID_EMAIL = @Id2; DELETE FROM #Ret64;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Histórico do e-mail 2 (erro, reenvio, cancelado)', N'ERRO_PERMANENTE,REENVIO,CANCELADO',
       ISNULL(STRING_AGG(CAST(l.RESULTADO AS NVARCHAR(30)), N',') WITHIN GROUP (ORDER BY l.ID_EMAIL_LOG), N'') FROM SIS.Email_Log l WHERE l.ID_EMAIL = @Id2;

-- Preso em processamento
EXEC SIS.SIS_Email_Enfileirar @Para = N'tres@exemplo.com.br', @Assunto = N'Hml 02d tres', @CorpoHTML = N'<p>3</p>', @Tipo = 'HML_TESTE',
     @Origem = N'teste-02d', @ChaveOrigem = N'HML02D:3', @IdEmail = @Id3 OUTPUT;
INSERT INTO #Cap EXEC SIS.SIS_Email_Capturar @Servidor = N'HML-SERVIDOR', @Quantidade = 50; DELETE FROM #Cap;
UPDATE SIS.Email_Fila SET DT_CAPTURA = DATEADD(MINUTE, -60, SYSDATETIME()) WHERE ID_EMAIL = @Id3;
EXEC SIS.SIS_Email_Presos_Liberar;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Preso há 60 min volta para a fila', N'PENDENTE|LIBERADO', f.STATUS + N'|'
       + ISNULL((SELECT TOP (1) l.RESULTADO FROM SIS.Email_Log l WHERE l.ID_EMAIL = @Id3 ORDER BY l.ID_EMAIL_LOG DESC), N'')
FROM SIS.Email_Fila f WHERE f.ID_EMAIL = @Id3;

INSERT INTO #EmailLista EXEC SIS.SIS_Email_Listar @IdUsuario = @IdAdmin, @Texto = N'Hml 02d';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Tela E-mails enviados encontra os 3 do teste', N'3', CONVERT(NVARCHAR(5), COUNT(*)) FROM #EmailLista WHERE TIPO = 'HML_TESTE';

-- 5) Próxima execução das rotinas
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Próxima: a cada 10 min', N'2026-11-16 09:10', CONVERT(VARCHAR(16), SIS.fn_SIS_Rotina_Proxima('MINUTOS', 10, NULL, '', 0, '2026-11-16T09:00:00'), 120)),
 (N'Próxima: diária 03:10 (já passou hoje)', N'2026-11-17 03:10', CONVERT(VARCHAR(16), SIS.fn_SIS_Rotina_Proxima('DIARIA', 0, '03:10', '', 0, '2026-11-16T09:00:00'), 120)),
 (N'Próxima: semanal seg e qua 08:00 (segunda 09h)', N'2026-11-18 08:00', CONVERT(VARCHAR(16), SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '08:00', '2,4', 0, '2026-11-16T09:00:00'), 120)),
 (N'Próxima: semanal seg 10:00 (mesmo dia)', N'2026-11-16 10:00', CONVERT(VARCHAR(16), SIS.fn_SIS_Rotina_Proxima('SEMANAL', 0, '10:00', '2', 0, '2026-11-16T09:00:00'), 120)),
 (N'Próxima: mensal último dia (novembro)', N'2026-11-30 07:00', CONVERT(VARCHAR(16), SIS.fn_SIS_Rotina_Proxima('MENSAL', 0, '07:00', '', 31, '2026-11-16T09:00:00'), 120)),
 (N'Próxima: mensal dia 31 depois de 30/11 08h', N'2026-12-31 07:00', CONVERT(VARCHAR(16), SIS.fn_SIS_Rotina_Proxima('MENSAL', 0, '07:00', '', 31, '2026-11-30T08:00:00'), 120)),
 (N'Próxima: mensal dia 30 em fevereiro', N'2027-02-28 07:00', CONVERT(VARCHAR(16), SIS.fn_SIS_Rotina_Proxima('MENSAL', 0, '07:00', '', 30, '2027-02-01T09:00:00'), 120));

-- 6) Agenda pela tela
INSERT INTO #Ret EXEC SIS.SIS_Rotina_Gravar @IdUsuario = @IdCelso, @Codigo = 'LOG_LIMPEZA', @Ativa = 1, @Frequencia = 'SEMANAL', @Horario = '03:10', @DiasSemana = '4, 2,2';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Agenda semanal gravada (dias em ordem, sem repetir)', N'1|2,4', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + x.DIAS_SEMANA
FROM #Ret r CROSS JOIN SIS.Rotina x WHERE x.CODIGO = 'LOG_LIMPEZA'; DELETE FROM #Ret;
INSERT INTO #Rot EXEC SIS.SIS_Rotina_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Agenda em texto', N'Semanal (seg, qua) às 03:10', AGENDA_TEXTO FROM #Rot WHERE CODIGO = 'LOG_LIMPEZA'; DELETE FROM #Rot;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Mudança de agenda auditada', N'S', CASE WHEN COUNT(*) >= 1 THEN N'S' ELSE N'N' END
FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'SIS.Rotina' AND a.CAMPO = N'FREQUENCIA';
INSERT INTO #Ret EXEC SIS.SIS_Rotina_Gravar @IdUsuario = @IdCelso, @Codigo = 'LOG_LIMPEZA', @Ativa = 1, @Frequencia = 'DIARIA', @Horario = '3:10';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Horário fora do formato (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC SIS.SIS_Rotina_Gravar @IdUsuario = @IdAdmin, @Codigo = 'LOG_LIMPEZA', @Ativa = 0, @Frequencia = 'DIARIA', @Horario = '03:10';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin (CMJ) muda agenda (sem permissão)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC SIS.SIS_Rotina_Gravar @IdUsuario = @IdCelso, @Codigo = 'LOG_LIMPEZA', @Ativa = 1, @Frequencia = 'DIARIA', @Horario = '03:10';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Agenda volta a diária 03:10', N'1|', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + x.DIAS_SEMANA
FROM #Ret r CROSS JOIN SIS.Rotina x WHERE x.CODIGO = 'LOG_LIMPEZA'; DELETE FROM #Ret;
UPDATE SIS.Rotina SET PROXIMA_EXECUCAO = DATEADD(DAY, 1, SYSDATETIME()) WHERE CODIGO = 'LOG_LIMPEZA';

-- 7) Agendador
INSERT INTO SIS.Rotina (CODIGO, NOME, PROCEDIMENTO, ID_MODULO, FREQUENCIA, INTERVALO_MINUTOS, ATIVA, PROXIMA_EXECUCAO, TEMPO_LIMITE_MINUTOS) VALUES
 ('HML_ROTINA_OK',    N'Hml ok',    N'SIS.SIS_Hml_Rotina_Ok',   @IdModSis, 'MINUTOS', 60, 1, DATEADD(MINUTE, -2, SYSDATETIME()), 60),
 ('HML_ROTINA_ERRO',  N'Hml erro',  N'SIS.SIS_Hml_Rotina_Erro', @IdModSis, 'MINUTOS', 60, 1, DATEADD(MINUTE, -1, SYSDATETIME()), 60),
 ('HML_ROTINA_PARAM', N'Hml param', N'SIS.SIS_Email_Listar',    @IdModSis, 'MINUTOS', 60, 1, DATEADD(MINUTE, -1, SYSDATETIME()), 60);

EXEC SIS.SIS_Rotina_Processar @Servidor = N'HML-SERVIDOR', @Silencioso = 1;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Rotina ' + r.CODIGO, v.ESPERADO,
       r.ULTIMO_RESULTADO + N'|' + CONVERT(NVARCHAR(1), r.EM_EXECUCAO) + N'|' + CASE WHEN r.PROXIMA_EXECUCAO > SYSDATETIME() THEN N'próxima ok' ELSE N'sem próxima' END
FROM (VALUES ('HML_ROTINA_OK', N'OK|0|próxima ok'), ('HML_ROTINA_ERRO', N'ERRO|0|próxima ok'), ('HML_ROTINA_PARAM', N'ERRO|0|próxima ok')) v (CODIGO, ESPERADO)
LEFT JOIN SIS.Rotina r ON r.CODIGO = v.CODIGO;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Erro da rotina no log de erros', N'S',
  CASE WHEN EXISTS (SELECT 1 FROM SIS.Log_Erro e WHERE e.ID_LOG_ERRO > @ErroInicio AND e.ETAPA = 'Rotina HML_ROTINA_ERRO' AND e.MENSAGEM LIKE N'%Erro de teste%') THEN N'S' ELSE N'N' END),
 (N'Procedure com parâmetros recusada', N'S',
  CASE WHEN (SELECT r.ULTIMA_MENSAGEM FROM SIS.Rotina r WHERE r.CODIGO = 'HML_ROTINA_PARAM') LIKE N'%parâmetros%' THEN N'S' ELSE N'N' END),
 (N'Execuções gravadas (3, pela agenda)', N'3',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Rotina_Execucao e INNER JOIN SIS.Rotina r ON r.ID_ROTINA = e.ID_ROTINA WHERE r.CODIGO LIKE 'HML[_]%' AND e.ORIGEM = 'AGENDA' AND e.DT_FIM IS NOT NULL))),
 (N'Contexto da sessão limpo depois das rotinas', N'', ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), N''));

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-02D', @Origem = N'teste-02d';

UPDATE SIS.Rotina SET ATIVA = 0, PROXIMA_EXECUCAO = NULL WHERE CODIGO = 'HML_ROTINA_OK';
INSERT INTO #Ret EXEC SIS.SIS_Rotina_Executar_Agora @IdUsuario = @IdCelso, @Codigo = 'HML_ROTINA_OK';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Executar agora (rotina desligada)', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC SIS.SIS_Rotina_Executar_Agora @IdUsuario = @IdAdmin, @Codigo = 'HML_ROTINA_OK';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin (CMJ) executar agora (sem permissão)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
EXEC SIS.SIS_Rotina_Processar @Servidor = N'HML-SERVIDOR', @Silencioso = 1;
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-02D', @Origem = N'teste-02d';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Execução manual registrada com quem pediu', N'MANUAL|celso|OK', e.ORIGEM + N'|' + e.SOLICITANTE + N'|' + e.RESULTADO
FROM SIS.Rotina_Execucao e
WHERE e.ID_EXECUCAO = (SELECT MAX(x.ID_EXECUCAO) FROM SIS.Rotina_Execucao x INNER JOIN SIS.Rotina r ON r.ID_ROTINA = x.ID_ROTINA WHERE r.CODIGO = 'HML_ROTINA_OK');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Rotina desligada fica sem próxima execução', N'(nulo)|', ISNULL(CONVERT(NVARCHAR(20), r.PROXIMA_EXECUCAO, 120), N'(nulo)') + N'|' + r.SOLICITADA_POR
FROM SIS.Rotina r WHERE r.CODIGO = 'HML_ROTINA_OK';

-- Rotina presa
UPDATE SIS.Rotina SET ATIVA = 1, EM_EXECUCAO = 1, DT_INICIO_EXECUCAO = DATEADD(MINUTE, -120, SYSDATETIME()), PROXIMA_EXECUCAO = DATEADD(DAY, 1, SYSDATETIME())
WHERE CODIGO = 'HML_ROTINA_OK';
INSERT INTO SIS.Rotina_Execucao (ID_ROTINA, ORIGEM, SERVIDOR, DT_INICIO)
SELECT r.ID_ROTINA, 'AGENDA', N'HML-SERVIDOR', DATEADD(MINUTE, -120, SYSDATETIME()) FROM SIS.Rotina r WHERE r.CODIGO = 'HML_ROTINA_OK';
EXEC SIS.SIS_Rotina_Processar @Servidor = N'HML-SERVIDOR', @Silencioso = 1;
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-02D', @Origem = N'teste-02d';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Rotina presa além do limite: liberada como erro', N'0|ERRO|ERRO', CONVERT(NVARCHAR(1), r.EM_EXECUCAO) + N'|' + r.ULTIMO_RESULTADO + N'|'
       + ISNULL((SELECT TOP (1) e.RESULTADO FROM SIS.Rotina_Execucao e WHERE e.ID_ROTINA = r.ID_ROTINA ORDER BY e.ID_EXECUCAO DESC), N'')
FROM SIS.Rotina r WHERE r.CODIGO = 'HML_ROTINA_OK';

-- 8) Comandos de instalação e manutenção
INSERT INTO #Cmd EXEC SIS.SIS_Comando_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Tela de comandos: 14 botões, 6 perigosos', N'14|6', CONVERT(NVARCHAR(5), COUNT(*)) + N'|' + CONVERT(NVARCHAR(5), SUM(CAST(PERIGOSO AS INT))) FROM #Cmd;

INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdCelso, @Codigo = 'DISCO_ESPACO', @Estacao = N'HML-PC';
SELECT @PedidoA = ID FROM #Ret64;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Pedido de comando registrado', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdCelso, @Codigo = 'DISCO_ESPACO';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Mesmo comando já na fila (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdAdmin, @Codigo = 'BACKUP_AGORA';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin (CMJ) pede comando (sem permissão)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdCelso, @Codigo = 'BACKUP_AGORA', @Parametro = N'x';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Valor em comando que não recebe (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdCelso, @Codigo = 'ATUALIZACAO_BANCO';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Comando sem o valor exigido (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdCelso, @Codigo = 'ATUALIZACAO_BANCO', @Parametro = N'pacote.sql & del *.*';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Valor com caractere perigoso (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdCelso, @Codigo = 'ATUALIZACAO_BANCO', @Parametro = N'..\..\Windows\x.sql';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Valor com ".." (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdCelso, @Codigo = 'ATUALIZACAO_BANCO', @Parametro = N'02e_SIS.sql';
SELECT @PedidoB = ID FROM #Ret64;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Comando com valor válido', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;

INSERT INTO #CmdCap EXEC SIS.SIS_Comando_Capturar @Servidor = N'HML-SERVIDOR';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Serviço pega o pedido mais antigo', N'DISCO_ESPACO', ISNULL(MAX(CODIGO), N'(nada)') FROM #CmdCap; DELETE FROM #CmdCap;
INSERT INTO #CmdCap EXEC SIS.SIS_Comando_Capturar @Servidor = N'HML-SERVIDOR';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Um comando por vez (nada enquanto executa)', N'0', CONVERT(NVARCHAR(5), COUNT(*)) FROM #CmdCap; DELETE FROM #CmdCap;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Resultado_Gravar @IdPedido = @PedidoA, @Sucesso = 1, @CodigoSaida = 0, @Saida = N'C: 120 GB livres (teste)';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Resultado gravado (concluído, saída)', N'1|CONCLUIDO|C: 120 GB livres (teste)', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + f.STATUS + N'|' + f.SAIDA
FROM #Ret64 r CROSS JOIN SIS.Comando_Fila f WHERE f.ID_PEDIDO = @PedidoA; DELETE FROM #Ret64;

INSERT INTO #CmdCap EXEC SIS.SIS_Comando_Capturar @Servidor = N'HML-SERVIDOR';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Próximo pedido com o valor', N'ATUALIZACAO_BANCO|02e_SIS.sql', ISNULL(MAX(CODIGO + N'|' + PARAMETRO), N'(nada)') FROM #CmdCap; DELETE FROM #CmdCap;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Cancelar @IdUsuario = @IdCelso, @IdPedido = @PedidoB;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Cancelar comando em execução (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Resultado_Gravar @IdPedido = @PedidoB, @Sucesso = 0, @CodigoSaida = 1, @Saida = N'arquivo não encontrado (teste)';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Comando com erro', N'ERRO|1', f.STATUS + N'|' + CONVERT(NVARCHAR(5), f.CODIGO_SAIDA) FROM SIS.Comando_Fila f WHERE f.ID_PEDIDO = @PedidoB; DELETE FROM #Ret64;

INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Solicitar @IdUsuario = @IdCelso, @Codigo = 'BACKUP_AGORA';
SELECT @PedidoC = ID FROM #Ret64; DELETE FROM #Ret64;
INSERT INTO #Ret64 EXEC SIS.SIS_Comando_Cancelar @IdUsuario = @IdCelso, @IdPedido = @PedidoC;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Cancelar pedido pendente', N'1|CANCELADO|celso', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + f.STATUS + N'|' + f.USUARIO_CANCELAMENTO
FROM #Ret64 r CROSS JOIN SIS.Comando_Fila f WHERE f.ID_PEDIDO = @PedidoC; DELETE FROM #Ret64;

-- 9) Limpeza
DELETE l FROM SIS.Email_Log l INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = l.ID_EMAIL
WHERE f.TIPO = 'HML_TESTE' OR f.CHAVE_ORIGEM = N'ALERTA_EMAIL:' + CONVERT(NVARCHAR(20), @Id2);
DELETE a FROM SIS.Email_Fila_Anexo a INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = a.ID_EMAIL
WHERE f.TIPO = 'HML_TESTE' OR f.CHAVE_ORIGEM = N'ALERTA_EMAIL:' + CONVERT(NVARCHAR(20), @Id2);
DELETE FROM SIS.Email_Fila WHERE TIPO = 'HML_TESTE' OR CHAVE_ORIGEM = N'ALERTA_EMAIL:' + CONVERT(NVARCHAR(20), @Id2);
DELETE e FROM SIS.Rotina_Execucao e INNER JOIN SIS.Rotina r ON r.ID_ROTINA = e.ID_ROTINA WHERE r.CODIGO LIKE 'HML[_]%';
DELETE FROM SIS.Rotina WHERE CODIGO LIKE 'HML[_]%';
DELETE d FROM SIS.Grupo_Email_Destinatario d INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = d.ID_GRUPO_EMAIL WHERE g.CODIGO LIKE 'HML[_]%';
DELETE FROM SIS.Grupo_Email WHERE CODIGO LIKE 'HML[_]%';
DELETE FROM SIS.Comando_Fila WHERE ID_PEDIDO > @CmdInicio;
UPDATE r SET r.PROXIMA_EXECUCAO = CASE WHEN r.ATIVA = 1 THEN SIS.fn_SIS_Rotina_Proxima(r.FREQUENCIA, r.INTERVALO_MINUTOS, r.HORARIO, r.DIAS_SEMANA, r.DIA_MES, SYSDATETIME()) END
FROM SIS.Rotina r WHERE r.CODIGO NOT LIKE 'HML[_]%';
DROP PROCEDURE IF EXISTS SIS.SIS_Hml_Rotina_Ok;
DROP PROCEDURE IF EXISTS SIS.SIS_Hml_Rotina_Erro;
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Parâmetros mexidos voltaram ao original', N'S',
  CASE WHEN ISNULL((SELECT p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_DOMINIO_INTERNO'), N'') = ISNULL(@DominioOrig, N'')
        AND ISNULL((SELECT p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_ADMIN_ALERTA'), N'') = ISNULL(@AlertaOrig, N'') THEN N'S' ELSE N'N' END),
 (N'Limpeza: nada do teste ficou nas filas', N'0',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Email_Fila f WHERE f.TIPO = 'HML_TESTE') + (SELECT COUNT(*) FROM SIS.Comando_Fila f WHERE f.ID_PEDIDO > @CmdInicio)));

-- Resultado
SELECT 'TESTES' AS GRADE, ID, TESTE, ESPERADO, OBTIDO,
       CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 'OK' ELSE 'FALHOU' END AS RESULTADO
FROM #Teste ORDER BY ID;

SELECT 'RESUMO' AS GRADE, COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste;
GO

SET NOEXEC OFF;
GO
