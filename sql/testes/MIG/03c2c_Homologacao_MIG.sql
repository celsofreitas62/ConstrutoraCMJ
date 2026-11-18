/*******************************************************************************
  Homologação : etapa 03c2, tela "Casos da migração" (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Testa as procedures da tela (MIG_Caso_Listar, Obter, Opcoes,
                Gravar, Conferir), a conferência de um documento só
                (MIG_Movimento_Transformar @Unidade), a auditoria das correções
                e o menu. Usa um caso real e, no fim, desfaz tudo o que gravou
                (o caso volta a ficar pendente). Nada é gravado no financeiro.
                Cada teste mostra ESPERADO x OBTIDO e RESULTADO (OK/FALHOU).
                Aborta se não estiver no SISTEMACMJ_LOCAL.
                Pré-requisito: pacote 03c2b e a migração (03c2b_Migracao_Movimento_LOCAL.sql).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos).
    v1.1 (18/11/2026) - Arquivo morto recebe o documento marcado na tela.
    v1.2 (18/11/2026) - Aviso "Revisar" quando o Access muda depois da correção
                        e arquivo das correções para a instalação.
    v1.3 (18/11/2026) - Ações em lote ("selecionar todos"): ignorar, conferir e
                        desfazer vários documentos de uma vez.

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

DROP TABLE IF EXISTS #Teste, #Ret, #Lista, #Caso, #Opc, #Conf;
CREATE TABLE #Teste (ID INT IDENTITY(1,1), TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));
CREATE TABLE #Ret   (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);
CREATE TABLE #Lista (UNIDADE VARCHAR(40), DOCUMENTO NVARCHAR(60), DT_DOCUMENTO DATE, ANO INT, EMPRESA NVARCHAR(1000), HISTORICO NVARCHAR(1000),
                     MOTIVO NVARCHAR(400), MOTIVO_ORIGINAL NVARCHAR(400), DETALHE NVARCHAR(400), REGRA_ATUAL VARCHAR(15), LINHAS INT,
                     VALOR_DEBITO DECIMAL(18,2), VALOR_CREDITO DECIMAL(18,2), DIFERENCA DECIMAL(18,2), SITUACAO VARCHAR(15),
                     LINHAS_CORRIGIDAS INT, CORRIGIDO_POR NVARCHAR(100), CORRIGIDO_EM DATETIME2(0), REVISAR NVARCHAR(400));
CREATE TABLE #Caso  (UNIDADE VARCHAR(40), REGRA_ATUAL VARCHAR(15), REVISAR NVARCHAR(400), MOTIVO NVARCHAR(400), MOTIVO_ORIGINAL NVARCHAR(400), DETALHE NVARCHAR(400),
                     PADRAO VARCHAR(200), DT_DOCUMENTO DATE, DT_CALCULO DATETIME2(0), ACAO VARCHAR(15), ACAO_MOTIVO NVARCHAR(400),
                     ACAO_USUARIO NVARCHAR(100), ACAO_DT DATETIME2(0), CORRECAO_MOTIVO NVARCHAR(400), LINHAS_JSON NVARCHAR(MAX));
CREATE TABLE #Opc   (OBRAS NVARCHAR(MAX), CONTAS NVARCHAR(MAX), PLANOS NVARCHAR(MAX), PESSOAS NVARCHAR(MAX));
CREATE TABLE #Conf  (UNIDADE VARCHAR(40), REGRA VARCHAR(15), MOTIVO NVARCHAR(400), DETALHE NVARCHAR(400), REVISAR NVARCHAR(400));
DROP TABLE IF EXISTS #Exp;
CREATE TABLE #Exp   (LINHA NVARCHAR(MAX));
DROP TABLE IF EXISTS #AM;
CREATE TABLE #AM    (ORIGEM_ACCESS VARCHAR(20), LINHAS INT, DEBITOS DECIMAL(18,2), CREDITOS DECIMAL(18,2), DE DATE, ATE DATE, SEM_PESSOA INT, SEM_CONTA INT);

DECLARE @IdCelso    INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
DECLARE @IdRenata   INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'renata');
DECLARE @AudInicio  BIGINT = ISNULL((SELECT MAX(a.ID_AUDITORIA) FROM SIS.Auditoria a), 0);
DECLARE @ErroInicio BIGINT = ISNULL((SELECT MAX(e.ID_LOG_ERRO) FROM SIS.Log_Erro e), 0);
DECLARE @U          VARCHAR(40);
DECLARE @MotivoAntes NVARCHAR(400);
DECLARE @Json       NVARCHAR(MAX);
DECLARE @Msg        NVARCHAR(400);

-- caso real, pendente e sem correção, com mais de uma linha
SELECT TOP (1) @U = c.UNIDADE, @MotivoAntes = c.MOTIVO
FROM MIG.Caso c
WHERE c.REGRA_ATUAL = 'CASO' AND c.LINHAS > 1
  AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao x WHERE x.UNIDADE = c.UNIDADE)
  AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha x WHERE x.UNIDADE = c.UNIDADE)
ORDER BY c.UNIDADE;

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-03C2C', @Origem = N'teste-03c2c';

-- 1) Estrutura e menu
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Há caso pendente para testar', N'1', CASE WHEN @U IS NULL THEN N'0' ELSE N'1' END),
 (N'MIG.Caso tem REGRA_ATUAL e MOTIVO_ORIGINAL', N'1', CASE WHEN COL_LENGTH(N'MIG.Caso', N'REGRA_ATUAL') IS NOT NULL AND COL_LENGTH(N'MIG.Caso', N'MOTIVO_ORIGINAL') IS NOT NULL THEN N'1' ELSE N'0' END),
 (N'Correções com chave numérica', N'1', CASE WHEN COL_LENGTH(N'MIG.Caso_Correcao', N'ID_CASO_CORRECAO') IS NOT NULL AND COL_LENGTH(N'MIG.Caso_Correcao_Linha', N'ID_CASO_CORRECAO_LINHA') IS NOT NULL THEN N'1' ELSE N'0' END),
 (N'Auditoria nas duas tabelas de correção', N'2', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.triggers t WHERE t.name IN (N'tg_MIG_Caso_Correcao_Auditoria', N'tg_MIG_Caso_Correcao_Linha_Auditoria')))),
 (N'Menu: Sistema > Migração > Casos da migração', N'sis/migracao-casos.html', (SELECT i.CAMINHO FROM SIS.Item i INNER JOIN SIS.Item p ON p.ID_ITEM = i.ID_ITEM_PAI WHERE i.CODIGO = 'MIG_CASOS' AND p.CODIGO = 'SIS_MIGRACAO')),
 (N'Renata (administradora, nível 1) pode corrigir', N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdRenata, 'MIG_CASOS', 'ALTERAR'))),
 (N'Celso (nível 2) pode corrigir', N'1', CONVERT(NVARCHAR(5), SIS.fn_SIS_Tem_Permissao(@IdCelso, 'MIG_CASOS', 'ALTERAR')));

-- 2) Listar, obter, opções
INSERT INTO #Lista EXEC MIG.MIG_Caso_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Listar traz todos os documentos de MIG.Caso', CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso)), CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM #Lista))),
 (N'Caso de teste aparece pendente', N'PENDENTE', (SELECT l.SITUACAO FROM #Lista l WHERE l.UNIDADE = @U)),
 (N'Todo caso tem empresa', N'0', CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM #Lista l WHERE l.EMPRESA = N'')));

INSERT INTO #Caso EXEC MIG.MIG_Caso_Obter @IdUsuario = @IdCelso, @Unidade = @U;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Obter: linhas do documento em JSON', CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Movimento m WHERE m.UNIDADE = @U AND m.DESTINO = 'SISTEMA')),
  CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM #Caso c CROSS APPLY OPENJSON(c.LINHAS_JSON) j))),
 (N'Obter: toda linha com nome da conta e da obra', N'0',
  CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM #Caso c CROSS APPLY OPENJSON(c.LINHAS_JSON) WITH (contaNome NVARCHAR(200), empNome NVARCHAR(200)) j WHERE j.contaNome = N'' OR j.empNome = N'')));

INSERT INTO #Opc EXEC MIG.MIG_Caso_Opcoes @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Opções: obras, contas, planos e pessoas preenchidas', N'1',
       CASE WHEN (SELECT COUNT(*) FROM OPENJSON(o.OBRAS)) > 0 AND (SELECT COUNT(*) FROM OPENJSON(o.CONTAS)) > 0
             AND (SELECT COUNT(*) FROM OPENJSON(o.PLANOS)) > 0 AND (SELECT COUNT(*) FROM OPENJSON(o.PESSOAS)) > 100 THEN N'1' ELSE N'0' END
FROM #Opc o;

-- 3) Ignorar o documento
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = @U, @Acao = 'IGNORAR', @Motivo = N'ok';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Ignorar sem motivo é recusado', N'0', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret));
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = @U, @Acao = 'IGNORAR', @Motivo = N'HML 03c2c: teste de ignorar';
INSERT INTO #Conf EXEC MIG.MIG_Caso_Conferir @IdUsuario = @IdCelso, @Unidade = @U;
DELETE FROM #Lista;
INSERT INTO #Lista EXEC MIG.MIG_Caso_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Ignorar com motivo grava', N'1', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret)),
 (N'Conferir depois de ignorar', N'IGNORAR', (SELECT TOP (1) REGRA FROM #Conf)),
 (N'Lista mostra Ignorado', N'IGNORADO', (SELECT l.SITUACAO FROM #Lista l WHERE l.UNIDADE = @U)),
 (N'Auditoria registrou a decisão', N'1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'MIG.Caso_Correcao' AND a.OPERACAO = 'I')));

-- 4) Corrigir uma linha (débito da primeira linha + 1,00)
SELECT @Json = (SELECT m.ORIGEM AS origem, m.NUM AS num, m.EMP_VINCULADA AS emp, ISNULL(m.PARCEIRO, 0) AS parceiro, m.CONTA AS conta, m.PLANO3 AS plano,
                       m.DT_MOVTO AS dtMovto, m.DT_VENCTO AS dtVencto, m.DT_PAGTO AS dtPagto,
                       CASE WHEN m.NUM = (SELECT MIN(x.NUM) FROM MIG.Movimento x WHERE x.UNIDADE = @U AND x.DESTINO = 'SISTEMA' AND x.VALOR_CREDITO = 0)
                            THEN m.VALOR_DEBITO + 1 ELSE m.VALOR_DEBITO END AS debito,
                       m.VALOR_CREDITO AS credito, m.CONFIRMADO AS confirmado, CAST(0 AS BIT) AS ignorar
                FROM MIG.Movimento m WHERE m.UNIDADE = @U AND m.DESTINO = 'SISTEMA' FOR JSON PATH);
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = @U, @Acao = 'CORRIGIR', @Motivo = N'', @LinhasJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Correção sem motivo é recusada', N'0', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret));
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = @U, @Acao = 'CORRIGIR', @Motivo = N'HML 03c2c: teste de correção', @LinhasJson = @Json;
DELETE FROM #Conf;
INSERT INTO #Conf EXEC MIG.MIG_Caso_Conferir @IdUsuario = @IdCelso, @Unidade = @U;
DELETE FROM #Lista;
INSERT INTO #Lista EXEC MIG.MIG_Caso_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Correção de 1 linha grava', N'Correção gravada (1 linha).', (SELECT TOP (1) MENSAGEM FROM #Ret)),
 (N'Correção tira a decisão de ignorar', N'0', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM MIG.Caso_Correcao x WHERE x.UNIDADE = @U))),
 (N'Só o valor alterado fica guardado', N'1|0', (SELECT CONVERT(NVARCHAR(5), COUNT(*)) + N'|' + CONVERT(NVARCHAR(5), SUM(CASE WHEN o.EMP_VINCULADA IS NOT NULL OR o.CONTA IS NOT NULL OR o.DT_MOVTO IS NOT NULL OR o.CONFIRMADO IS NOT NULL THEN 1 ELSE 0 END))
                                                  FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = @U)),
 (N'Conferir devolve a regra', N'1', CASE WHEN (SELECT TOP (1) REGRA FROM #Conf) IN ('CASO', 'LOTE', 'VENDA', 'AVULSO', 'TRANSF', 'TRANSF_PAR') THEN N'1' ELSE N'0' END),
 (N'Lista mostra em correção ou resolvido', N'1', CASE WHEN (SELECT l.SITUACAO FROM #Lista l WHERE l.UNIDADE = @U) IN ('EM_CORRECAO', 'RESOLVIDO') THEN N'1' ELSE N'0' END),
 (N'Motivo original preservado', @MotivoAntes, (SELECT c.MOTIVO_ORIGINAL FROM MIG.Caso c WHERE c.UNIDADE = @U));

-- 4b) O Access mudou depois da correção: aviso "Revisar"
DECLARE @NumMudou INT = (SELECT TOP (1) o.NUM FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = @U);
DECLARE @HashOrig VARBINARY(32) = (SELECT m.HASH_CONTEUDO FROM MIG.Movimento m WHERE m.UNIDADE = @U AND m.NUM = @NumMudou AND m.DESTINO = 'SISTEMA');
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Correção guarda a impressão digital do Access', N'1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = @U AND o.HASH_ACCESS = @HashOrig)));
UPDATE MIG.Movimento SET HASH_CONTEUDO = 0x01 WHERE UNIDADE = @U AND NUM = @NumMudou AND DESTINO = 'SISTEMA';   -- simula alteração no Access
DELETE FROM #Conf;
INSERT INTO #Conf EXEC MIG.MIG_Caso_Conferir @IdUsuario = @IdCelso, @Unidade = @U;
DELETE FROM #Lista;
INSERT INTO #Lista EXEC MIG.MIG_Caso_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Conferir avisa que a linha mudou no Access', N'A linha ' + CONVERT(NVARCHAR(12), @NumMudou) + N' mudou no Access depois da correção', (SELECT TOP (1) REVISAR FROM #Conf)),
 (N'Lista mostra a situação Revisar', N'REVISAR', (SELECT l.SITUACAO FROM #Lista l WHERE l.UNIDADE = @U));
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = @U, @Acao = 'CORRIGIR', @Motivo = N'HML 03c2c: teste de correção', @LinhasJson = @Json;
DELETE FROM #Conf;
INSERT INTO #Conf EXEC MIG.MIG_Caso_Conferir @IdUsuario = @IdCelso, @Unidade = @U;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Gravar de novo tira o aviso', N'', (SELECT TOP (1) REVISAR FROM #Conf));
UPDATE MIG.Movimento SET HASH_CONTEUDO = @HashOrig WHERE UNIDADE = @U AND NUM = @NumMudou AND DESTINO = 'SISTEMA';    -- volta ao original

-- 4c) Arquivo das correções para a instalação
INSERT INTO #Exp EXEC MIG.MIG_Caso_Correcao_Exportar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Arquivo das correções: cabeçalho, uma linha por correção e fim', CONVERT(NVARCHAR(10), 2 + (SELECT COUNT(*) FROM MIG.Caso_Correcao) + (SELECT COUNT(*) FROM MIG.Caso_Correcao_Linha)),
  CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM #Exp))),
 (N'Arquivo traz a linha corrigida com a impressão digital', N'1',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM #Exp e WHERE e.LINHA LIKE N'%' + CONVERT(NVARCHAR(12), @NumMudou) + N'%' AND e.LINHA LIKE N'%0x01%')));

-- 5) Recusas
DELETE FROM #Ret;
SET @Json = REPLACE(@Json, N'"conta":', N'"conta":99999');   -- vira número inválido no início do valor
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = @U, @Acao = 'CORRIGIR', @Motivo = N'HML 03c2c: conta inválida', @LinhasJson = @Json;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Conta inexistente é recusada', N'0', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret));
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = 'X:NAO-EXISTE', @Acao = 'IGNORAR', @Motivo = N'HML 03c2c: inexistente';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Documento inexistente é recusado', N'0', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret));

-- 6) Arquivo morto (e decisão também guarda a impressão digital): o documento marcado na tela entra no FIN.Arquivo_Morto
-- base: arquivo morto já com as decisões gravadas antes do teste (pela tela)
INSERT INTO #AM EXEC MIG.MIG_Arquivo_Morto_Processar;
DELETE FROM #AM;
DECLARE @AmAntes INT = (SELECT COUNT(*) FROM FIN.Arquivo_Morto);
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = @U, @Acao = 'ARQUIVO_MORTO', @Motivo = N'HML 03c2c: teste de arquivo morto';
INSERT INTO #AM EXEC MIG.MIG_Arquivo_Morto_Processar;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Marcar para o arquivo morto grava', N'1', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret)),
 (N'Arquivo morto recebe as linhas do documento', CONVERT(NVARCHAR(10), @AmAntes + (SELECT COUNT(*) FROM MIG.Movimento m WHERE m.UNIDADE = @U AND m.DESTINO = 'SISTEMA')),
  CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM FIN.Arquivo_Morto))),
 (N'Decisão guarda a impressão digital do documento', N'1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM MIG.Caso_Correcao x WHERE x.UNIDADE = @U AND x.HASH_ACCESS = MIG.fn_MIG_Hash_Unidade(@U)))),
 (N'Observação traz o motivo da tela', N'1', CASE WHEN EXISTS (SELECT 1 FROM FIN.Arquivo_Morto a WHERE a.OBSERVACAO LIKE N'%HML 03c2c: teste de arquivo morto%') THEN N'1' ELSE N'0' END);

-- 6b) Ações em lote: dois outros casos pendentes
DECLARE @Lote NVARCHAR(MAX) = (SELECT N'[' + STRING_AGG(N'"' + x.UNIDADE + N'"', N',') + N']'
                               FROM (SELECT TOP (2) c.UNIDADE FROM MIG.Caso c
                                     WHERE c.REGRA_ATUAL = 'CASO' AND c.UNIDADE <> @U AND c.REVISAR = N''
                                       AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao x WHERE x.UNIDADE = c.UNIDADE)
                                       AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha x WHERE x.UNIDADE = c.UNIDADE)
                                     ORDER BY c.UNIDADE) x);
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Lote_Gravar @IdUsuario = @IdCelso, @Acao = 'IGNORAR', @Motivo = N'ok', @UnidadesJson = @Lote;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Lote: ignorar sem motivo é recusado', N'0', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret));
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Lote_Gravar @IdUsuario = @IdCelso, @Acao = 'IGNORAR', @Motivo = N'HML 03c2c: teste de lote', @UnidadesJson = @Lote;
DELETE FROM #Conf;
INSERT INTO #Conf EXEC MIG.MIG_Caso_Conferir @IdUsuario = @IdCelso, @Unidades = @Lote;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Lote: ignorar 2 documentos', N'2 documentos marcados para não migrar.', (SELECT TOP (1) MENSAGEM FROM #Ret)),
 (N'Lote: conferir devolve os 2 ignorados', N'2', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM #Conf WHERE REGRA = 'IGNORAR'))),
 (N'Lote: decisões guardam a impressão digital', N'2', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM MIG.Caso_Correcao x WHERE x.UNIDADE IN (SELECT value FROM OPENJSON(@Lote)) AND x.HASH_ACCESS = MIG.fn_MIG_Hash_Unidade(x.UNIDADE))));
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Lote_Gravar @IdUsuario = @IdCelso, @Acao = 'DESFAZER', @UnidadesJson = @Lote;
DELETE FROM #Conf;
INSERT INTO #Conf EXEC MIG.MIG_Caso_Conferir @IdUsuario = @IdCelso, @Unidades = @Lote;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Lote: desfazer volta os 2 a caso', N'2|2', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM #Conf WHERE REGRA = 'CASO')) + N'|'
  + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM MIG.Caso c WHERE c.UNIDADE IN (SELECT value FROM OPENJSON(@Lote)) AND c.REGRA_ATUAL = 'CASO'))),
 (N'Lote: nenhuma decisão sobrou', N'0', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM MIG.Caso_Correcao x WHERE x.UNIDADE IN (SELECT value FROM OPENJSON(@Lote)))));
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Lote_Gravar @IdUsuario = @IdCelso, @Acao = 'IGNORAR', @Motivo = N'HML 03c2c: lote inválido', @UnidadesJson = N'["X:NAO-EXISTE"]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Lote: documento fora da lista é recusado', N'0', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret));

-- 7) Desfazer: volta a ser como está no Access
DELETE FROM #Ret;
INSERT INTO #Ret EXEC MIG.MIG_Caso_Gravar @IdUsuario = @IdCelso, @Unidade = @U, @Acao = 'DESFAZER';
DELETE FROM #Conf;
INSERT INTO #Conf EXEC MIG.MIG_Caso_Conferir @IdUsuario = @IdCelso, @Unidade = @U;
DELETE FROM #AM;
INSERT INTO #AM EXEC MIG.MIG_Arquivo_Morto_Processar;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Arquivo morto volta ao tamanho de antes', CONVERT(NVARCHAR(10), @AmAntes), CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM FIN.Arquivo_Morto))),
 (N'Desfazer grava', N'1', (SELECT TOP (1) CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret)),
 (N'Nenhuma correção sobrou', N'0', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = @U) + (SELECT COUNT(*) FROM MIG.Caso_Correcao x WHERE x.UNIDADE = @U))),
 (N'Caso volta a ser caso, com o mesmo motivo e sem aviso', N'CASO|' + @MotivoAntes + N'|', (SELECT c.REGRA_ATUAL + N'|' + c.MOTIVO + N'|' + c.REVISAR FROM MIG.Caso c WHERE c.UNIDADE = @U)),
 (N'Auditoria registrou as linhas (inclusão e exclusão)', N'1', CASE WHEN (SELECT COUNT(DISTINCT a.OPERACAO) FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'MIG.Caso_Correcao_Linha') >= 2 THEN N'1' ELSE N'0' END),
 (N'Nenhum erro novo no SIS.Log_Erro', N'0', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Log_Erro e WHERE e.ID_LOG_ERRO > @ErroInicio)));

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

SELECT 'TESTES' AS GRADE, ID, TESTE, ESPERADO, OBTIDO,
       CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 'OK' ELSE 'FALHOU' END AS RESULTADO
FROM #Teste ORDER BY ID;

SELECT 'RESUMO' AS GRADE, COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste;
GO

SET NOEXEC OFF;
GO
