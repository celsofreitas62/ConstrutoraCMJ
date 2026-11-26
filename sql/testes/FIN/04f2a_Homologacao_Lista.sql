/*******************************************************************************
  Teste       : 04f2a - lista de contas a pagar e a receber: situações HOJE e
                A_VENCER, canceladas fora de "todas", período por emissão e
                competência, contadores do topo (FIN_Lancamento_Resumo) e
                filtros salvos (SIS_Filtro_Salvo_*).
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 25/11/2026 (v1.0). v1.1 (26/11/2026, 04f2c): colunas de pendências na lista e no resumo. Roda no SISTEMACMJ_LOCAL e no banco do MASTER
                (no banco sem cadastros, os casos com dados passam direto).
  Observação  : não muda nada (tudo desfeito com ROLLBACK). Datas calculadas a
                partir de hoje, para o teste valer em qualquer dia.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(80), OBTIDO NVARCHAR(80));
DECLARE @g TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @f TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
DECLARE @fl TABLE (ID_FILTRO_SALVO INT, NOME NVARCHAR(60), FILTRO NVARCHAR(2000), PADRAO BIT);
DECLARE @res TABLE (QTD_VENCIDAS INT, VALOR_VENCIDAS DECIMAL(18,2), QTD_HOJE INT, VALOR_HOJE DECIMAL(18,2), QTD_A_VENCER INT, VALOR_A_VENCER DECIMAL(18,2),
                    QTD_EM_ABERTO INT, VALOR_EM_ABERTO DECIMAL(18,2), DIAS_A_VENCER INT, POR_PAGINA INT, SITUACAO_INICIAL VARCHAR(12), VISAO_INICIAL VARCHAR(12),
                    QTD_COM_PENDENCIA INT, QTD_MINHAS_PENDENCIAS INT);
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Fin INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'teste.tela04a');
DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @Forn INT, @Centro INT, @PlanoD INT, @L1 BIGINT, @J NVARCHAR(MAX), @IdA INT, @IdB INT, @Erro NVARCHAR(400);

DROP TABLE IF EXISTS #lst;
CREATE TABLE #lst (C01 NVARCHAR(MAX), C02 NVARCHAR(MAX), C03 NVARCHAR(MAX), C04 NVARCHAR(MAX), C05 NVARCHAR(MAX), C06 NVARCHAR(MAX), C07 NVARCHAR(MAX),
                   C08 NVARCHAR(MAX), C09 NVARCHAR(MAX), SITUACAO NVARCHAR(MAX), C11 NVARCHAR(MAX), C12 NVARCHAR(MAX), C13 NVARCHAR(MAX), C14 NVARCHAR(MAX),
                   C15 NVARCHAR(MAX), C16 NVARCHAR(MAX), C17 NVARCHAR(MAX), C18 NVARCHAR(MAX), C19 NVARCHAR(MAX), C20 NVARCHAR(MAX), C21 NVARCHAR(MAX),
                   C22 NVARCHAR(MAX), C23 NVARCHAR(MAX), C24 NVARCHAR(MAX), C25 NVARCHAR(MAX), C26 NVARCHAR(MAX), C27 NVARCHAR(MAX), C28 NVARCHAR(MAX),
                   C29 NVARCHAR(MAX), C30 NVARCHAR(MAX), TOTAL_LINHAS NVARCHAR(MAX), C32 NVARCHAR(MAX), C33 NVARCHAR(MAX), C34 NVARCHAR(MAX),
                   QTD_PENDENCIAS NVARCHAR(MAX), PENDENCIAS NVARCHAR(MAX), PENDENCIA_BLOQUEIA NVARCHAR(MAX), PENDENCIA_ATRASADA NVARCHAR(MAX));

-- estrutura e cargas
INSERT @r SELECT N'tabela SIS.Filtro_Salvo', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.tables WHERE object_id = OBJECT_ID('SIS.Filtro_Salvo');
INSERT @r SELECT N'procedures novas', N'4', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.procedures WHERE object_id IN
       (OBJECT_ID('FIN.FIN_Lancamento_Resumo'), OBJECT_ID('SIS.SIS_Filtro_Salvo_Listar'), OBJECT_ID('SIS.SIS_Filtro_Salvo_Gravar'), OBJECT_ID('SIS.SIS_Filtro_Salvo_Excluir'));
INSERT @r SELECT N'parâmetros novos da lista', N'5', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro
       WHERE CHAVE IN ('FIN_LISTA_DIAS_A_VENCER', 'FIN_LISTA_SITUACAO_INICIAL', 'FIN_LISTA_VISAO_INICIAL', 'FIN_LISTA_OCULTA_CANCELADAS', 'FILTRO_SALVO_MAX');
INSERT @r SELECT N'situação inicial com opções', N'EM_ABERTO;VENCIDA;HOJE;A_VENCER;TODAS', ISNULL((SELECT OPCOES FROM SIS.Parametro WHERE CHAVE = 'FIN_LISTA_SITUACAO_INICIAL'), N'-');

-- tipo inválido (fora da transação: o erro desfaz a transação)
BEGIN TRY EXEC FIN.FIN_Lancamento_Resumo @IdUsuario = @Fin, @Tipo = 'X'; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = CAST(ERROR_NUMBER() AS NVARCHAR(10)); END CATCH;
INSERT @r SELECT N'resumo com tipo inválido: erro 50001', N'50001', @Erro;

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'BANCO', 'FIN') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND HABILITADO = 0;
UPDATE SIS.Parametro SET VALOR = N'7' WHERE CHAVE = 'FIN_LISTA_DIAS_A_VENCER';
UPDATE SIS.Parametro SET VALOR = N'S' WHERE CHAVE = 'FIN_LISTA_OCULTA_CANCELADAS';
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO
FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
WHERE u.ID_USUARIO = @Fin AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND a.CODIGO <> 'LANCAR_RETROATIVO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);


SET @Centro = (SELECT TOP 1 cc.ID_CENTRO_CUSTO FROM CAD.Centro_Custo cc INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = cc.ID_EMPRESA AND e.ATIVO = 1
               WHERE cc.ATIVO = 1 AND cc.DT_EXCLUSAO IS NULL AND (cc.DT_ENCERRAMENTO IS NULL OR cc.DT_ENCERRAMENTO > @Hoje) ORDER BY cc.ID_CENTRO_CUSTO);
SET @PlanoD = (SELECT TOP 1 v.ID_PLANO_CONTA FROM CAD.vw_CAD_Plano_Conta v INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = v.ID_PLANO_CONTA
               WHERE v.ATIVO_EFETIVO = 1 AND v.TIPO = 'DESPESA' AND pc.DT_EXCLUSAO IS NULL ORDER BY v.ORDEM_ARVORE);

IF @Centro IS NOT NULL AND @PlanoD IS NOT NULL
BEGIN
    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, FORNECEDOR, ATIVO) VALUES ('J', N'Fornecedor Teste 04f2a', 1, 1);
    SET @Forn = SCOPE_IDENTITY();
    UPDATE CAD.Plano_Conta SET CONTABIL = 0 WHERE ID_PLANO_CONTA = @PlanoD;

    -- 4 parcelas gravadas no futuro e depois levadas para: 3 dias atrás, hoje, daqui a 3 dias e daqui a 100 dias
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 30, @Hoje), 23) + N'","valor":100.00},{"vencimento":"'
           + CONVERT(NVARCHAR(10), DATEADD(DAY, 60, @Hoje), 23) + N'","valor":200.00},{"vencimento":"'
           + CONVERT(NVARCHAR(10), DATEADD(DAY, 90, @Hoje), 23) + N'","valor":300.00},{"vencimento":"'
           + CONVERT(NVARCHAR(10), DATEADD(DAY, 120, @Hoje), 23) + N'","valor":400.00}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 2A01', @DtEmissao = @Hoje, @ValorTotal = 1000.00, @Historico = N'Teste 04f2a', @Parcelas = @J;
    SET @L1 = (SELECT ID FROM @g WHERE SUCESSO = 1);
    INSERT @r SELECT N'grava lançamento de teste', N'1', ISNULL((SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g), N'-');
    UPDATE FIN.Parcela SET DT_VENCIMENTO = CASE NUMERO WHEN 1 THEN DATEADD(DAY, -3, @Hoje) WHEN 2 THEN @Hoje WHEN 3 THEN DATEADD(DAY, 3, @Hoje) ELSE DATEADD(DAY, 100, @Hoje) END
    WHERE ID_LANCAMENTO = @L1;

    -- contadores
    INSERT @res EXEC FIN.FIN_Lancamento_Resumo @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn;
    INSERT @r SELECT N'contadores: vencidas/hoje/a vencer/em aberto', N'1/1/1/4', (SELECT CONCAT(QTD_VENCIDAS, '/', QTD_HOJE, '/', QTD_A_VENCER, '/', QTD_EM_ABERTO) FROM @res);
    INSERT @r SELECT N'contadores: saldos', N'100.00/200.00/300.00/1000.00', (SELECT CONCAT(VALOR_VENCIDAS, '/', VALOR_HOJE, '/', VALOR_A_VENCER, '/', VALOR_EM_ABERTO) FROM @res);
    INSERT @r SELECT N'contadores: parâmetros da tela', N'7/EM_ABERTO/PARCELA', (SELECT CONCAT(DIAS_A_VENCER, '/', SITUACAO_INICIAL, '/', VISAO_INICIAL) FROM @res);
    DELETE @res;
    INSERT @res EXEC FIN.FIN_Lancamento_Resumo @IdUsuario = @Fin, @Tipo = 'R', @IdPessoa = @Forn;
    INSERT @r SELECT N'contadores do outro tipo não contam', N'0', (SELECT CAST(QTD_EM_ABERTO AS NVARCHAR(5)) FROM @res);

    -- situações
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Situacao = 'HOJE';
    INSERT @r SELECT N'situação HOJE', N'1/2', (SELECT CONCAT(COUNT(*), '/', MAX(C04)) FROM #lst);
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Situacao = 'A_VENCER';
    INSERT @r SELECT N'situação A_VENCER (até 7 dias)', N'1/3', (SELECT CONCAT(COUNT(*), '/', MAX(C04)) FROM #lst);
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Situacao = 'VENCIDA';
    INSERT @r SELECT N'situação VENCIDA', N'1/1', (SELECT CONCAT(COUNT(*), '/', MAX(C04)) FROM #lst);
    DELETE #lst;

    -- canceladas fora de "todas"
    UPDATE FIN.Parcela SET SITUACAO = 'CANCELADA' WHERE ID_LANCAMENTO = @L1 AND NUMERO = 4;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn;
    INSERT @r SELECT N'todas sem as canceladas', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Situacao = 'CANCELADA';
    INSERT @r SELECT N'canceladas pela situação Cancelada', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    UPDATE SIS.Parametro SET VALOR = N'N' WHERE CHAVE = 'FIN_LISTA_OCULTA_CANCELADAS';
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn;
    INSERT @r SELECT N'parâmetro N: todas com as canceladas', N'4', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    UPDATE SIS.Parametro SET VALOR = N'S' WHERE CHAVE = 'FIN_LISTA_OCULTA_CANCELADAS';

    -- período por emissão e por competência
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @CampoData = 'EMISSAO', @VencDe = @Hoje, @VencAte = @Hoje;
    INSERT @r SELECT N'período pela emissão (hoje)', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    SET @J = CONVERT(NVARCHAR(10), DATEADD(DAY, 1, @Hoje), 23);
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @CampoData = 'EMISSAO', @VencDe = @J;
    INSERT @r SELECT N'período pela emissão (de amanhã)', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @CampoData = 'COMPETENCIA', @VencDe = @Hoje, @VencAte = @Hoje;
    INSERT @r SELECT N'período pela competência (mês de hoje)', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @VencDe = @Hoje, @VencAte = @Hoje;
    INSERT @r SELECT N'período pelo vencimento (padrão)', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
END
ELSE
BEGIN
    INSERT @r VALUES (N'sem cadastros: casos com dados', N'pulados', N'pulados');
END;

-- filtros salvos
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Nome = N'Teste A', @Filtro = N'{"situacao":"VENCIDA"}', @Padrao = 1;
SET @IdA = (SELECT ID FROM @f);
INSERT @r SELECT N'salva filtro A (padrão)', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @f); DELETE @f;
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Nome = N'Teste B', @Filtro = N'{"situacao":"HOJE"}', @Padrao = 1;
SET @IdB = (SELECT ID FROM @f);
INSERT @r SELECT N'salva filtro B (padrão)', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @f); DELETE @f;
INSERT @r SELECT N'só um padrão por tela (B)', N'0/1', (SELECT CONCAT(MAX(CASE WHEN ID_FILTRO_SALVO = @IdA THEN CAST(PADRAO AS INT) END), '/', MAX(CASE WHEN ID_FILTRO_SALVO = @IdB THEN CAST(PADRAO AS INT) END)) FROM SIS.Filtro_Salvo WHERE ID_USUARIO = @Fin);
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Nome = N'Teste A', @Filtro = N'{"situacao":"A_VENCER"}', @Padrao = 0;
INSERT @r SELECT N'mesmo nome substitui', N'1/' + CAST(@IdA AS NVARCHAR(10)) + N'/A_VENCER', (SELECT CONCAT(f.SUCESSO, '/', f.ID, '/', JSON_VALUE(s.FILTRO, '$.situacao')) FROM @f f LEFT JOIN SIS.Filtro_Salvo s ON s.ID_FILTRO_SALVO = f.ID); DELETE @f;
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Nome = N'Teste C', @Filtro = N'isto não é json', @Padrao = 0;
INSERT @r SELECT N'filtro que não é JSON recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @f); DELETE @f;
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Nome = N'  ', @Filtro = N'{}', @Padrao = 0;
INSERT @r SELECT N'nome vazio recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @f); DELETE @f;
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = @Fin, @Item = 'SIS_PARAMETRO', @Nome = N'Teste D', @Filtro = N'{}', @Padrao = 0;
INSERT @r SELECT N'tela sem permissão recusada', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @f); DELETE @f;
UPDATE SIS.Parametro SET VALOR = N'2' WHERE CHAVE = 'FILTRO_SALVO_MAX';
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Gravar @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Nome = N'Teste E', @Filtro = N'{}', @Padrao = 0;
INSERT @r SELECT N'limite de filtros por tela', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @f); DELETE @f;
INSERT @fl EXEC SIS.SIS_Filtro_Salvo_Listar @IdUsuario = @Fin, @Item = 'FIN_PAGAR';
INSERT @r SELECT N'lista: 2 filtros, o padrão primeiro', N'2/Teste B', (SELECT CONCAT(COUNT(*), '/', (SELECT TOP 1 NOME FROM @fl WHERE PADRAO = 1)) FROM @fl);
DELETE @fl;
INSERT @fl EXEC SIS.SIS_Filtro_Salvo_Listar @IdUsuario = @Celso, @Item = 'FIN_PAGAR';
INSERT @r SELECT N'outro usuário não vê os filtros', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @fl WHERE NOME LIKE N'Teste%';
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Excluir @IdUsuario = @Celso, @IdFiltroSalvo = @IdA;
INSERT @r SELECT N'outro usuário não apaga', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @f); DELETE @f;
INSERT @f EXEC SIS.SIS_Filtro_Salvo_Excluir @IdUsuario = @Fin, @IdFiltroSalvo = @IdA;
INSERT @r SELECT N'o dono apaga', N'1/1', (SELECT CONCAT(f.SUCESSO, '/', (SELECT COUNT(*) FROM SIS.Filtro_Salvo WHERE ID_USUARIO = @Fin AND ITEM = 'FIN_PAGAR')) FROM @f f); DELETE @f;

ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
DROP TABLE IF EXISTS #lst;
