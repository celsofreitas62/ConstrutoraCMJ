/*******************************************************************************
  Homologação : etapa 03c, financeiro (FIN), movimento e extrato do BANCO,
                arquivo morto e boletim semanal (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Testa objetos e cargas da 03c; regras das tabelas do FIN
                (competência no dia 1, estorno com sinal negativo, um só
                estorno por baixa, movimento conciliado exige linha do
                extrato); trigger de saldo da parcela (parcial, paga,
                estorno volta para parcial, valor líquido com juros e
                desconto); consulta do arquivo morto; comunicado (itens,
                conteúdo, gravar, prévia, aprovar, segunda aprovação
                recusada, descartar). Dados "HML 03c" apagados no fim
                (inclusive os e-mails de teste da fila, que não chegam a
                sair). A auditoria do teste fica (ninguém apaga auditoria).
                Cada teste mostra ESPERADO x OBTIDO e RESULTADO (OK/FALHOU).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).

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
DELETE b FROM FIN.Baixa b INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.HISTORICO LIKE N'HML 03c%' AND b.ID_BAIXA_ESTORNADA IS NOT NULL;
DELETE b FROM FIN.Baixa b INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.HISTORICO LIKE N'HML 03c%';
DELETE p FROM FIN.Parcela p INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.HISTORICO LIKE N'HML 03c%';
DELETE FROM FIN.Lancamento WHERE HISTORICO LIKE N'HML 03c%';
DELETE FROM BANCO.Movimento WHERE HISTORICO LIKE N'HML 03c%';
DELETE FROM FIN.Arquivo_Morto WHERE ORIGEM_ACCESS = 'HML_03C';
DELETE c FROM BANCO.Conta c INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = c.ID_EMPRESA WHERE e.RAZAO_SOCIAL LIKE N'HML 03c%';
DELETE FROM CAD.Empresa WHERE RAZAO_SOCIAL LIKE N'HML 03c%';
DELETE l FROM SIS.Email_Log l INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = l.ID_EMAIL WHERE f.ASSUNTO LIKE N'%HML 03c%';
DELETE a FROM SIS.Email_Fila_Anexo a INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = a.ID_EMAIL WHERE f.ASSUNTO LIKE N'%HML 03c%';
DELETE FROM SIS.Email_Fila WHERE ASSUNTO LIKE N'%HML 03c%';
DELETE e FROM SIS.Comunicado_Edicao e INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = e.ID_COMUNICADO WHERE c.CODIGO = 'HML_03C';
DELETE i FROM SIS.Comunicado_Item i INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = i.ID_COMUNICADO WHERE c.CODIGO = 'HML_03C';
DELETE FROM SIS.Comunicado WHERE CODIGO = 'HML_03C';
DELETE d FROM SIS.Grupo_Email_Destinatario d INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = d.ID_GRUPO_EMAIL WHERE g.CODIGO LIKE 'HML[_]03C%';
DELETE FROM SIS.Grupo_Email WHERE CODIGO LIKE 'HML[_]03C%';

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
DROP TABLE IF EXISTS #Am;
DROP TABLE IF EXISTS #Com;
DROP TABLE IF EXISTS #Hab;

CREATE TABLE #Hab   (TIPO CHAR(1), CODIGO VARCHAR(40), HABILITADO BIT);
CREATE TABLE #Teste (ID INT IDENTITY(1,1), TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));
CREATE TABLE #Ret   (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);
CREATE TABLE #Am    (ID_ARQUIVO_MORTO BIGINT, DT_MOVIMENTO DATE, DT_VENCIMENTO DATE, DT_PAGAMENTO DATE, EMPRESA NVARCHAR(150), OBRA NVARCHAR(150),
                     PESSOA NVARCHAR(150), CONTA NVARCHAR(80), PLANO1 NVARCHAR(80), PLANO2 NVARCHAR(80), PLANO3 NVARCHAR(120), HISTORICO NVARCHAR(80),
                     COMPLEMENTO NVARCHAR(255), DOCUMENTO NVARCHAR(60), NOTA_FISCAL NVARCHAR(60), IMOVEL NVARCHAR(150), VALOR_DEBITO DECIMAL(18,2),
                     VALOR_CREDITO DECIMAL(18,2), CONFIRMADO BIT, ORIGEM_ACCESS VARCHAR(20), CODIGO_ACCESS INT);
CREATE TABLE #Com   (ID_COMUNICADO INT, CODIGO VARCHAR(30), TITULO NVARCHAR(150), INTRODUCAO NVARCHAR(1000), EXIGE_APROVACAO BIT, ATIVO BIT,
                     GRUPO VARCHAR(30), GRUPO_APROVACAO VARCHAR(30), DESTINATARIOS NVARCHAR(MAX), DESTINATARIOS_APROVACAO NVARCHAR(MAX),
                     ROTINA_HORARIO VARCHAR(5), ROTINA_DIAS VARCHAR(20), ROTINA_PROXIMA DATETIME2(0), ROTINA_ATIVA BIT, ITENS_JSON NVARCHAR(MAX), EDICOES_JSON NVARCHAR(MAX));

DECLARE @IdCelso    INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
DECLARE @IdEmp      INT;
DECLARE @IdConta    INT;
DECLARE @IdLanc     BIGINT;
DECLARE @IdParc     BIGINT;
DECLARE @IdMov      BIGINT;
DECLARE @IdB1       BIGINT;
DECLARE @IdB2       BIGINT;
DECLARE @IdCom      INT;
DECLARE @IdEd1      BIGINT;
DECLARE @IdEd2      BIGINT;
DECLARE @Erro       NVARCHAR(400);
DECLARE @Json       NVARCHAR(MAX);
DECLARE @Liberados  NVARCHAR(4000) = ISNULL((SELECT p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_LOCAL_LIBERADOS'), N'');

-- Habilitação original (volta no fim); o teste liga o FIN e a tela do arquivo morto
INSERT INTO #Hab (TIPO, CODIGO, HABILITADO)
SELECT 'M', m.CODIGO, m.HABILITADO FROM SIS.Modulo m WHERE m.CODIGO = 'FIN'
UNION ALL
SELECT 'I', i.CODIGO, i.HABILITADO FROM SIS.Item i WHERE i.CODIGO = 'FIN_ARQUIVO_MORTO';

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-03C', @Origem = N'teste-03c';

-- 1) Objetos e cargas
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Tabelas do FIN', N'8', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.tables t WHERE SCHEMA_NAME(t.schema_id) = 'FIN'))),
 (N'Tabelas novas do BANCO (movimento, extrato)', N'3', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.tables t WHERE SCHEMA_NAME(t.schema_id) = 'BANCO' AND t.name IN ('Movimento', 'Extrato_Arquivo', 'Extrato_Linha')))),
 (N'Tabelas do comunicado', N'3', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.tables t WHERE SCHEMA_NAME(t.schema_id) = 'SIS' AND t.name LIKE 'Comunicado%'))),
 (N'Coluna PASTA_OFX na empresa', N'1', CONVERT(NVARCHAR(5), CASE WHEN COL_LENGTH(N'CAD.Empresa', N'PASTA_OFX') IS NULL THEN 0 ELSE 1 END)),
 (N'Auditoria ligada nas tabelas do FIN/BANCO/comunicado', N'9',
  CONVERT(NVARCHAR(5), (SELECT COUNT(DISTINCT t.parent_id) FROM sys.triggers t WHERE t.name LIKE '%Auditoria%' AND t.parent_id IN
        (OBJECT_ID(N'FIN.Historico_Padrao'), OBJECT_ID(N'FIN.Mes_Fechado'), OBJECT_ID(N'FIN.Transferencia'), OBJECT_ID(N'BANCO.Movimento'),
         OBJECT_ID(N'FIN.Lancamento'), OBJECT_ID(N'FIN.Parcela'), OBJECT_ID(N'FIN.Baixa'), OBJECT_ID(N'SIS.Comunicado'), OBJECT_ID(N'SIS.Comunicado_Item'))))),
 (N'Arquivo morto sem auditoria (só consulta)', N'0', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.triggers t WHERE t.parent_id = OBJECT_ID(N'FIN.Arquivo_Morto')))),
 (N'Trigger de saldo da baixa', N'1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.triggers t WHERE t.name = 'tg_FIN_Baixa_Saldo'))),
 (N'Tela Arquivo morto (desabilitada, VER+EXPORTAR)', N'0|2',
  ISNULL((SELECT CONVERT(NVARCHAR(5), i.HABILITADO) + N'|' + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM)) FROM SIS.Item i WHERE i.CODIGO = 'FIN_ARQUIVO_MORTO'), N'')),
 (N'Tela Comunicados (habilitada, não exclusiva, 4 ações)', N'1|0|4',
  ISNULL((SELECT CONVERT(NVARCHAR(5), i.HABILITADO) + N'|' + CONVERT(NVARCHAR(5), i.EXCLUSIVO_GERAL) + N'|' + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM)) FROM SIS.Item i WHERE i.CODIGO = 'SIS_COMUNICADO'), N'')),
 (N'Rotina da prévia: sexta 09:00, ativa', N'SEMANAL|6|09:00|1',
  ISNULL((SELECT r.FREQUENCIA + N'|' + r.DIAS_SEMANA + N'|' + CONVERT(VARCHAR(5), r.HORARIO, 108) + N'|' + CONVERT(NVARCHAR(5), r.ATIVA) FROM SIS.Rotina r WHERE r.CODIGO = 'COMUNICADO_PREVIA'), N'')),
 (N'Próxima prévia cai numa sexta-feira às 09:00', N'4|09:00',
  ISNULL((SELECT CONVERT(NVARCHAR(5), DATEDIFF(DAY, '19000101', r.PROXIMA_EXECUCAO) % 7) + N'|' + CONVERT(VARCHAR(5), r.PROXIMA_EXECUCAO, 108) FROM SIS.Rotina r WHERE r.CODIGO = 'COMUNICADO_PREVIA'), N'')),
 (N'Destinatários do boletim', N'construtora.m.judice@gmail.com; dmjdaher@gmail.com', ISNULL(SIS.fn_SIS_Emails_Do_Grupo('BOLETIM_IMPLANTACAO'), N'')),
 (N'Aprovação do boletim', N'celsofreitas62@gmail.com', ISNULL(SIS.fn_SIS_Emails_Do_Grupo('BOLETIM_APROVACAO'), N'')),
 (N'Parâmetro EMAIL_LOCAL_LIBERADOS existe', N'1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_LOCAL_LIBERADOS'))),
 (N'Itens iniciais do boletim (1 implantado, 2 em teste, 2 próxima)', N'1|2|2',
  (SELECT CONVERT(NVARCHAR(5), SUM(CASE WHEN i.SECAO = 'IMPLANTADO' THEN 1 ELSE 0 END)) + N'|' + CONVERT(NVARCHAR(5), SUM(CASE WHEN i.SECAO = 'EM_TESTE' THEN 1 ELSE 0 END))
          + N'|' + CONVERT(NVARCHAR(5), SUM(CASE WHEN i.SECAO = 'PROXIMA_FASE' THEN 1 ELSE 0 END))
   FROM SIS.Comunicado_Item i INNER JOIN SIS.Comunicado c ON c.ID_COMUNICADO = i.ID_COMUNICADO WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO' AND i.ATIVO = 1));

-- 2) Dados de apoio
INSERT INTO CAD.Empresa (RAZAO_SOCIAL, NOME_FANTASIA, TIPO) VALUES (N'HML 03c Empresa', N'HML 03c', 'OUTRA');
SET @IdEmp = SCOPE_IDENTITY();
INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO) VALUES (@IdEmp, N'HML 03c Caixa', 'CAIXA');
SET @IdConta = SCOPE_IDENTITY();

-- 3) Regras das tabelas
BEGIN TRY
    INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, DT_EMISSAO, DT_COMPETENCIA, HISTORICO, VALOR_TOTAL) VALUES ('P', @IdEmp, '2026-11-17', '2026-11-17', N'HML 03c competencia', 10);
    SET @Erro = N'gravou';
END TRY
BEGIN CATCH
    SET @Erro = CASE WHEN ERROR_MESSAGE() LIKE N'%CK_Lancamento_COMPETENCIA%' THEN N'recusado' ELSE ERROR_MESSAGE() END;
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Competência fora do dia 1 é recusada', N'recusado', @Erro);

BEGIN TRY
    INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, DT_EMISSAO, DT_COMPETENCIA, HISTORICO, VALOR_TOTAL, INTEGRACAO) VALUES ('P', @IdEmp, '2026-11-17', '2026-11-01', N'HML 03c integ', 10, 'OUTRA');
    SET @Erro = N'gravou';
END TRY
BEGIN CATCH
    SET @Erro = CASE WHEN ERROR_MESSAGE() LIKE N'%CK_Lancamento_INTEGRACAO%' THEN N'recusado' ELSE ERROR_MESSAGE() END;
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Integração fora da lista é recusada', N'recusado', @Erro);

INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, DT_EMISSAO, DT_COMPETENCIA, HISTORICO, VALOR_TOTAL, INTEGRACAO)
VALUES ('P', @IdEmp, '2026-11-17', '2026-11-01', N'HML 03c fornecedor', 1000, 'COMPLETA');
SET @IdLanc = SCOPE_IDENTITY();
INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR) VALUES (@IdLanc, 1, 1, '2026-11-30', 1000);
SET @IdParc = SCOPE_IDENTITY();
INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO) VALUES (@IdConta, '2026-11-17', -1010, 'BAIXA', N'HML 03c pagamento');
SET @IdMov = SCOPE_IDENTITY();

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Parcela nova: aberta, saldo 1000', N'ABERTA|1000.00', p.SITUACAO + N'|' + CONVERT(NVARCHAR(30), p.SALDO) FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdParc;

INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, ID_MOVIMENTO) VALUES (@IdParc, '2026-11-17', @IdConta, 'PIX', 400, @IdMov);
SET @IdB1 = SCOPE_IDENTITY();
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Baixa parcial de 400', N'PARCIAL|400.00|600.00', p.SITUACAO + N'|' + CONVERT(NVARCHAR(30), p.VALOR_BAIXADO) + N'|' + CONVERT(NVARCHAR(30), p.SALDO) FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdParc;

INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, JUROS, MULTA, DESCONTO, ID_MOVIMENTO) VALUES (@IdParc, '2026-11-17', @IdConta, 'PIX', 600, 12, 8, 10, @IdMov);
SET @IdB2 = SCOPE_IDENTITY();
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Baixa do restante: paga, saldo 0', N'PAGA|0.00', p.SITUACAO + N'|' + CONVERT(NVARCHAR(30), p.SALDO) FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdParc;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Valor líquido = 600 + 12 + 8 - 10', N'610.00', CONVERT(NVARCHAR(30), b.VALOR_LIQUIDO) FROM FIN.Baixa b WHERE b.ID_BAIXA = @IdB2;

BEGIN TRY
    INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, VALOR_PRINCIPAL, ID_BAIXA_ESTORNADA) VALUES (@IdParc, '2026-11-17', @IdConta, 600, @IdB2);
    SET @Erro = N'gravou';
END TRY
BEGIN CATCH
    SET @Erro = CASE WHEN ERROR_MESSAGE() LIKE N'%CK_Baixa_SINAL%' THEN N'recusado' ELSE ERROR_MESSAGE() END;
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Estorno com valor positivo é recusado', N'recusado', @Erro);

INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, VALOR_PRINCIPAL, JUROS, MULTA, DESCONTO, ID_BAIXA_ESTORNADA) VALUES (@IdParc, '2026-11-18', @IdConta, -600, -12, -8, -10, @IdB2);
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Estorno da 2ª baixa: volta a parcial, saldo 600', N'PARCIAL|600.00', p.SITUACAO + N'|' + CONVERT(NVARCHAR(30), p.SALDO) FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdParc;

BEGIN TRY
    INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, VALOR_PRINCIPAL, ID_BAIXA_ESTORNADA) VALUES (@IdParc, '2026-11-18', @IdConta, -600, @IdB2);
    SET @Erro = N'gravou';
END TRY
BEGIN CATCH
    SET @Erro = CASE WHEN ERROR_MESSAGE() LIKE N'%UQ_Baixa_ESTORNO%' THEN N'recusado' ELSE ERROR_MESSAGE() END;
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Segundo estorno da mesma baixa é recusado', N'recusado', @Erro);

UPDATE FIN.Parcela SET SITUACAO = 'CANCELADA' WHERE ID_PARCELA = @IdParc;
INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, VALOR_PRINCIPAL) VALUES (@IdParc, '2026-11-19', @IdConta, 1);
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Parcela cancelada não muda de situação pela trigger', N'CANCELADA|599.00', p.SITUACAO + N'|' + CONVERT(NVARCHAR(30), p.SALDO) FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdParc;

BEGIN TRY
    UPDATE BANCO.Movimento SET CONCILIADO = 1 WHERE ID_MOVIMENTO = @IdMov;
    SET @Erro = N'gravou';
END TRY
BEGIN CATCH
    SET @Erro = CASE WHEN ERROR_MESSAGE() LIKE N'%CK_Movimento_CONCILIADO%' THEN N'recusado' ELSE ERROR_MESSAGE() END;
END CATCH;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Movimento conciliado sem linha do extrato é recusado', N'recusado', @Erro);

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Auditoria registrou a baixa', N'1', CONVERT(NVARCHAR(5), CASE WHEN EXISTS (SELECT 1 FROM SIS.Auditoria a WHERE a.TABELA = N'FIN.Baixa' AND a.ID_REGISTRO = @IdB1) THEN 1 ELSE 0 END));

-- 4) Arquivo morto
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO = 'FIN' AND HABILITADO = 0;
UPDATE SIS.Item   SET HABILITADO = 1 WHERE CODIGO = 'FIN_ARQUIVO_MORTO' AND HABILITADO = 0;
INSERT INTO FIN.Arquivo_Morto (ORIGEM_ACCESS, CODIGO_ACCESS, EMPRESA, PESSOA, CONTA, COMPLEMENTO, VALOR_DEBITO, DT_MOVIMENTO)
VALUES ('HML_03C', 1, N'HML 03c Empresa', N'HML 03c Pintor Fulano', N'Itau construtora', N'pintura da fachada', 1300, '2010-05-04'),
       ('HML_03C', 2, N'HML 03c Empresa', N'HML 03c Pedreiro', N'Itau construtora', N'reboco', 777.70, '2011-06-05');

INSERT INTO #Am EXEC FIN.FIN_Arquivo_Morto_Listar @IdUsuario = @IdCelso, @Busca = N'HML 03c pintor';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Arquivo morto: busca por parte do nome', N'1|1300.00', CONVERT(NVARCHAR(5), COUNT(*)) + N'|' + ISNULL(CONVERT(NVARCHAR(30), MAX(VALOR_DEBITO)), N'') FROM #Am WHERE ORIGEM_ACCESS = 'HML_03C';
DELETE FROM #Am;
INSERT INTO #Am EXEC FIN.FIN_Arquivo_Morto_Listar @IdUsuario = @IdCelso, @Busca = N'777,70';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Arquivo morto: busca pelo valor (777,70)', N'1', CONVERT(NVARCHAR(5), COUNT(*)) FROM #Am WHERE ORIGEM_ACCESS = 'HML_03C';
DELETE FROM #Am;
INSERT INTO #Am EXEC FIN.FIN_Arquivo_Morto_Listar @IdUsuario = @IdCelso, @Busca = N'HML 03c', @DtInicio = '2011-01-01', @DtFim = '2011-12-31';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Arquivo morto: filtro de período', N'1|2', CONVERT(NVARCHAR(5), COUNT(*)) + N'|' + ISNULL(CONVERT(NVARCHAR(5), MAX(CODIGO_ACCESS)), N'') FROM #Am WHERE ORIGEM_ACCESS = 'HML_03C';

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Arquivo morto: usuário sem permissão não vê', N'0', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(-1, 'FIN_ARQUIVO_MORTO', 'VER')));

-- 5) Comunicado (um comunicado de teste, com grupos de teste). Durante o teste
--    nenhum tipo fica liberado: todo e-mail vai para o EMAIL_TESTE (volta no fim).
UPDATE SIS.Parametro SET VALOR = N'' WHERE CHAVE = 'EMAIL_LOCAL_LIBERADOS' AND VALOR <> N'';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Conteúdo do boletim tem as três seções e os itens', N'1|1|1|1',
  (SELECT CONVERT(NVARCHAR(5), CASE WHEN x.H LIKE N'%Implantado (em uso na empresa)%' THEN 1 ELSE 0 END) + N'|'
        + CONVERT(NVARCHAR(5), CASE WHEN x.H LIKE N'%Em teste%' THEN 1 ELSE 0 END) + N'|'
        + CONVERT(NVARCHAR(5), CASE WHEN x.H LIKE N'%Próxima fase%' THEN 1 ELSE 0 END) + N'|'
        + CONVERT(NVARCHAR(5), CASE WHEN x.H LIKE N'%Cadastro de clientes e fornecedores.%' THEN 1 ELSE 0 END)
   FROM (SELECT SIS.fn_SIS_Comunicado_Conteudo(c.ID_COMUNICADO) AS H FROM SIS.Comunicado c WHERE c.CODIGO = 'BOLETIM_IMPLANTACAO') x));

INSERT INTO SIS.Grupo_Email (CODIGO, NOME) VALUES ('HML_03C_OFICIAL', N'HML 03c oficial'), ('HML_03C_APROVA', N'HML 03c aprovação');
INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL)
SELECT g.ID_GRUPO_EMAIL, v.EMAIL FROM (VALUES ('HML_03C_OFICIAL', N'oficial.hml@teste.com.br'), ('HML_03C_APROVA', N'aprova.hml@teste.com.br')) v (G, EMAIL)
INNER JOIN SIS.Grupo_Email g ON g.CODIGO = v.G;
INSERT INTO SIS.Comunicado (CODIGO, TITULO, INTRODUCAO, ID_GRUPO_EMAIL, ID_GRUPO_EMAIL_APROVACAO)
SELECT 'HML_03C', N'HML 03c Boletim', N'Introdução & teste', g.ID_GRUPO_EMAIL, ga.ID_GRUPO_EMAIL
FROM SIS.Grupo_Email g INNER JOIN SIS.Grupo_Email ga ON ga.CODIGO = 'HML_03C_APROVA' WHERE g.CODIGO = 'HML_03C_OFICIAL';
SET @IdCom = SCOPE_IDENTITY();

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Gravar @IdUsuario = @IdCelso, @IdComunicado = @IdCom, @Introducao = N'Intro HML', @ItensJson = N'[{"secao":"EM_TESTE","texto":"","ordem":1}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar: item sem texto recusado', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Gravar @IdUsuario = @IdCelso, @IdComunicado = @IdCom, @Introducao = N'Intro HML', @ItensJson = N'[{"secao":"OUTRA","texto":"x","ordem":1}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar: seção inválida recusada', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Gravar @IdUsuario = @IdCelso, @IdComunicado = @IdCom, @Introducao = N'Intro HML',
     @ItensJson = N'[{"secao":"EM_TESTE","texto":"Item A <b>","ordem":1},{"secao":"PROXIMA_FASE","texto":"Item B","ordem":1}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar: dois itens', N'1|2', CONVERT(NVARCHAR(5), SUCESSO) + N'|' + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Comunicado_Item i WHERE i.ID_COMUNICADO = @IdCom AND i.ATIVO = 1)) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Com EXEC SIS.SIS_Comunicado_Obter @IdUsuario = @IdCelso, @IdComunicado = @IdCom;
SELECT @Json = ITENS_JSON FROM #Com;
SET @Json = (SELECT j.id, j.secao, j.texto, j.ordem FROM OPENJSON(@Json) WITH (id INT, secao VARCHAR(15), texto NVARCHAR(300), ordem SMALLINT) j WHERE j.texto = N'Item B' FOR JSON PATH);
INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Gravar @IdUsuario = @IdCelso, @IdComunicado = @IdCom, @Introducao = N'Intro HML', @ItensJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar: item tirado da lista fica desativado (não apagado)', N'1|1|2',
  CONVERT(NVARCHAR(5), SUCESSO) + N'|' + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Comunicado_Item i WHERE i.ID_COMUNICADO = @IdCom AND i.ATIVO = 1))
  + N'|' + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Comunicado_Item i WHERE i.ID_COMUNICADO = @IdCom)) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Gravar @IdUsuario = @IdCelso, @IdComunicado = @IdCom, @Introducao = N'Intro HML',
     @ItensJson = N'[{"secao":"EM_TESTE","texto":"Item A <b>","ordem":1},{"secao":"PROXIMA_FASE","texto":"Item B","ordem":1}]';
DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Conteúdo escapa o texto (sem HTML do usuário) e mostra seção vazia', N'1|0|1',
  (SELECT CONVERT(NVARCHAR(5), CASE WHEN x.H LIKE N'%Item A &lt;b&gt;%' THEN 1 ELSE 0 END) + N'|'
        + CONVERT(NVARCHAR(5), CASE WHEN x.H LIKE N'%Item A <b>%' THEN 1 ELSE 0 END) + N'|'
        + CONVERT(NVARCHAR(5), CASE WHEN x.H LIKE N'%Nada nesta semana.%' THEN 1 ELSE 0 END)
   FROM (SELECT SIS.fn_SIS_Comunicado_Conteudo(@IdCom) AS H) x));

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = @IdCelso, @IdComunicado = @IdCom;
SELECT @IdEd1 = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Prévia gerada', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Prévia: segunda a sexta; e-mail só ao grupo de aprovação (no LOCAL vai ao EMAIL_TESTE)', N'PREVIA|0|4|aprova.hml@teste.com.br|1|1',
       e.SITUACAO + N'|' + CONVERT(NVARCHAR(5), DATEDIFF(DAY, '19000101', e.DT_INICIO) % 7) + N'|' + CONVERT(NVARCHAR(5), DATEDIFF(DAY, e.DT_INICIO, e.DT_FIM))
       + N'|' + ISNULL(f.PARA_ORIGINAL, N'') + N'|' + ISNULL(CONVERT(NVARCHAR(5), f.MODO_TESTE), N'') + N'|' + CASE WHEN f.ASSUNTO LIKE N'%PRÉVIA%' THEN N'1' ELSE N'0' END
FROM SIS.Comunicado_Edicao e LEFT JOIN SIS.Email_Fila f ON f.ID_EMAIL = e.ID_EMAIL_PREVIA
WHERE e.ID_COMUNICADO_EDICAO = @IdEd1;

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = @IdCelso, @IdComunicado = @IdCom;
SELECT @IdEd2 = ID FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Prévia nova descarta a anterior', N'DESCARTADA|PREVIA',
       ISNULL((SELECT e.SITUACAO FROM SIS.Comunicado_Edicao e WHERE e.ID_COMUNICADO_EDICAO = @IdEd1), N'') + N'|' + ISNULL((SELECT e.SITUACAO FROM SIS.Comunicado_Edicao e WHERE e.ID_COMUNICADO_EDICAO = @IdEd2), N'');

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Edicao_Aprovar @IdUsuario = @IdCelso, @IdEdicao = @IdEd1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Aprovar prévia descartada é recusado', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Edicao_Aprovar @IdUsuario = @IdCelso, @IdEdicao = @IdEd2;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Aprovar e enviar', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Oficial: assunto aprovado, grupo oficial, conta externa, sem aviso de prévia', N'ENVIADA|oficial.hml@teste.com.br|EXTERNA|1|0|celso',
       e.SITUACAO + N'|' + ISNULL(f.PARA_ORIGINAL, N'') + N'|' + ISNULL(f.CONTA, N'') + N'|' + CONVERT(NVARCHAR(5), CASE WHEN f.ASSUNTO LIKE N'%' + e.ASSUNTO THEN 1 ELSE 0 END)
       + N'|' + CONVERT(NVARCHAR(5), CASE WHEN f.CORPO_HTML LIKE N'%Prévia para aprovação%' THEN 1 ELSE 0 END) + N'|' + e.USUARIO_APROVACAO
FROM SIS.Comunicado_Edicao e LEFT JOIN SIS.Email_Fila f ON f.ID_EMAIL = e.ID_EMAIL_OFICIAL
WHERE e.ID_COMUNICADO_EDICAO = @IdEd2;

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Edicao_Aprovar @IdUsuario = @IdCelso, @IdEdicao = @IdEd2;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Aprovar de novo é recusado (não sai duas vezes)', N'0|Este comunicado já foi enviado.', CONVERT(NVARCHAR(5), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = @IdCelso, @IdComunicado = @IdCom;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Prévia na semana já enviada é recusada', N'0|O comunicado desta semana já foi enviado.', CONVERT(NVARCHAR(5), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;

UPDATE SIS.Comunicado_Edicao SET DT_INICIO = DATEADD(DAY, -7, DT_INICIO), DT_FIM = DATEADD(DAY, -7, DT_FIM) WHERE ID_COMUNICADO_EDICAO = @IdEd2;
INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Previa_Gerar @IdUsuario = @IdCelso, @IdComunicado = @IdCom;
SELECT @IdEd1 = ID FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Edicao_Descartar @IdUsuario = @IdCelso, @IdEdicao = @IdEd1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Descartar prévia', N'1|DESCARTADA', CONVERT(NVARCHAR(5), SUCESSO) + N'|' + ISNULL((SELECT e.SITUACAO FROM SIS.Comunicado_Edicao e WHERE e.ID_COMUNICADO_EDICAO = @IdEd1), N'') FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Comunicado_Edicao_Aprovar @IdUsuario = -1, @IdEdicao = @IdEd1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Aprovar sem permissão é recusado', N'0|Você não tem permissão para aprovar comunicados.', CONVERT(NVARCHAR(5), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;

DELETE FROM #Com;
INSERT INTO #Com EXEC SIS.SIS_Comunicado_Obter @IdUsuario = @IdCelso, @IdComunicado = @IdCom;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Obter: itens, edições e destinatários', N'2|3|oficial.hml@teste.com.br|aprova.hml@teste.com.br',
       CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM OPENJSON(ITENS_JSON))) + N'|' + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM OPENJSON(EDICOES_JSON))) + N'|' + DESTINATARIOS + N'|' + DESTINATARIOS_APROVACAO
FROM #Com;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Nenhum erro novo no log do comunicado durante o teste', N'0',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Log_Erro e WHERE e.DT_ERRO >= DATEADD(MINUTE, -10, SYSDATETIME()) AND e.ROTINA LIKE N'%Comunicado%')));

-- Limpeza
DELETE b FROM FIN.Baixa b WHERE b.ID_PARCELA = @IdParc AND b.ID_BAIXA_ESTORNADA IS NOT NULL;
DELETE FROM FIN.Baixa WHERE ID_PARCELA = @IdParc;
DELETE FROM FIN.Parcela WHERE ID_LANCAMENTO = @IdLanc;
DELETE FROM FIN.Lancamento WHERE HISTORICO LIKE N'HML 03c%';
DELETE FROM BANCO.Movimento WHERE HISTORICO LIKE N'HML 03c%';
DELETE FROM FIN.Arquivo_Morto WHERE ORIGEM_ACCESS = 'HML_03C';
DELETE FROM BANCO.Conta WHERE ID_CONTA = @IdConta;
DELETE FROM CAD.Empresa WHERE ID_EMPRESA = @IdEmp;
DELETE l FROM SIS.Email_Log l INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = l.ID_EMAIL WHERE f.ASSUNTO LIKE N'%HML 03c%';
DELETE a FROM SIS.Email_Fila_Anexo a INNER JOIN SIS.Email_Fila f ON f.ID_EMAIL = a.ID_EMAIL WHERE f.ASSUNTO LIKE N'%HML 03c%';
DELETE FROM SIS.Email_Fila WHERE ASSUNTO LIKE N'%HML 03c%';
DELETE FROM SIS.Comunicado_Edicao WHERE ID_COMUNICADO = @IdCom;
DELETE FROM SIS.Comunicado_Item WHERE ID_COMUNICADO = @IdCom;
DELETE FROM SIS.Comunicado WHERE ID_COMUNICADO = @IdCom;
DELETE d FROM SIS.Grupo_Email_Destinatario d INNER JOIN SIS.Grupo_Email g ON g.ID_GRUPO_EMAIL = d.ID_GRUPO_EMAIL WHERE g.CODIGO LIKE 'HML[_]03C%';
DELETE FROM SIS.Grupo_Email WHERE CODIGO LIKE 'HML[_]03C%';
UPDATE SIS.Parametro SET VALOR = @Liberados WHERE CHAVE = 'EMAIL_LOCAL_LIBERADOS' AND VALOR <> @Liberados;
UPDATE m SET m.HABILITADO = h.HABILITADO FROM SIS.Modulo m INNER JOIN #Hab h ON h.TIPO = 'M' AND h.CODIGO = m.CODIGO WHERE m.HABILITADO <> h.HABILITADO;
UPDATE i SET i.HABILITADO = h.HABILITADO FROM SIS.Item i   INNER JOIN #Hab h ON h.TIPO = 'I' AND h.CODIGO = i.CODIGO WHERE i.HABILITADO <> h.HABILITADO;
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Limpeza: nada do teste ficou', N'0',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM FIN.Lancamento l WHERE l.HISTORICO LIKE N'HML 03c%') + (SELECT COUNT(*) FROM CAD.Empresa e WHERE e.RAZAO_SOCIAL LIKE N'HML 03c%')
                     + (SELECT COUNT(*) FROM SIS.Comunicado c WHERE c.CODIGO = 'HML_03C') + (SELECT COUNT(*) FROM SIS.Email_Fila f WHERE f.ASSUNTO LIKE N'%HML 03c%')
                     + (SELECT COUNT(*) FROM FIN.Arquivo_Morto a WHERE a.ORIGEM_ACCESS = 'HML_03C'))),
 (N'Habilitação do FIN e da tela do arquivo morto voltou ao original', N'0',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM #Hab h WHERE h.HABILITADO <> CASE h.TIPO WHEN 'M' THEN (SELECT m.HABILITADO FROM SIS.Modulo m WHERE m.CODIGO = h.CODIGO)
                                                                                             ELSE (SELECT i.HABILITADO FROM SIS.Item i WHERE i.CODIGO = h.CODIGO) END)));

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
