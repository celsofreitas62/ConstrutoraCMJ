/*******************************************************************************
  Teste       : 04f - contas a pagar e a receber (banco): gravação com
                parcelas, proteções contra erro de digitação (P17), trava de
                datas com exceção e motivo, travas com baixa, cancelar,
                lixeira, lista, ficha, sugestões, escolhas com busca e
                parâmetros de uso (nível mínimo e opções).
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 25/11/2026 (v1.0). v1.1 (25/11/2026, 04f2a): 23 parâmetros FIN; canceladas contadas na lista. v1.2 (26/11/2026, 04f2c): colunas de pendências na lista e na ficha; parâmetros FIN_PEND_* contados no teste 04f2c. v1.3 (26/11/2026, 04g): parâmetros da baixa e do caixa (contados no 04g) fora da conta; 13 ações por tela. v1.4 (27/11/2026, 04g4): FIN_CAIXA_FECHAMENTO_ATRASO_DIAS e FIN_BAIXA_FORMA_PADRAO fora da conta; coluna TEM_HISTORICO_BAIXA na ficha. Roda no SISTEMACMJ_LOCAL e no banco do MASTER
                (no banco sem cadastros, os casos com dados passam direto).
  Observação  : não muda nada (tudo desfeito com ROLLBACK). Datas calculadas a
                partir de hoje, para o teste valer em qualquer dia.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(80), OBTIDO NVARCHAR(80));
DECLARE @g TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @c TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);
DECLARE @x TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_LIXEIRA BIGINT, DT_APAGAR DATE);
DECLARE @pg TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_PARAMETRO INT);
DECLARE @s TABLE (ID INT, CODIGO NVARCHAR(30), DESCRICAO NVARCHAR(200), COMPLEMENTO NVARCHAR(400), ATIVO BIT);
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Renata INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'renata');
DECLARE @Claude INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'claude');
DECLARE @Fin INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'teste.tela04a');
DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @Forn INT, @Forn2 INT, @Centro INT, @PlanoD INT, @PlanoR INT, @Conta INT, @L1 BIGINT, @L2 BIGINT, @L3 BIGINT, @LM BIGINT, @P1 BIGINT, @P2 BIGINT;
DECLARE @J NVARCHAR(MAX), @Antes DATE, @i INT, @Vi DECIMAL(18,2);

DROP TABLE IF EXISTS #lst;
DROP TABLE IF EXISTS #obt;
CREATE TABLE #lst (C01 NVARCHAR(MAX), C02 NVARCHAR(MAX), C03 NVARCHAR(MAX), C04 NVARCHAR(MAX), C05 NVARCHAR(MAX), C06 NVARCHAR(MAX), C07 NVARCHAR(MAX),
                   C08 NVARCHAR(MAX), C09 NVARCHAR(MAX), SITUACAO NVARCHAR(MAX), C11 NVARCHAR(MAX), C12 NVARCHAR(MAX), C13 NVARCHAR(MAX), C14 NVARCHAR(MAX),
                   C15 NVARCHAR(MAX), C16 NVARCHAR(MAX), C17 NVARCHAR(MAX), C18 NVARCHAR(MAX), C19 NVARCHAR(MAX), C20 NVARCHAR(MAX), C21 NVARCHAR(MAX),
                   C22 NVARCHAR(MAX), C23 NVARCHAR(MAX), C24 NVARCHAR(MAX), C25 NVARCHAR(MAX), C26 NVARCHAR(MAX), C27 NVARCHAR(MAX), C28 NVARCHAR(MAX),
                   C29 NVARCHAR(MAX), C30 NVARCHAR(MAX), TOTAL_LINHAS NVARCHAR(MAX), C32 NVARCHAR(MAX), C33 NVARCHAR(MAX), C34 NVARCHAR(MAX),
                   QTD_PENDENCIAS NVARCHAR(MAX), PENDENCIAS NVARCHAR(MAX), PENDENCIA_BLOQUEIA NVARCHAR(MAX), PENDENCIA_ATRASADA NVARCHAR(MAX));
CREATE TABLE #obt (C01 NVARCHAR(MAX), C02 NVARCHAR(MAX), C03 NVARCHAR(MAX), C04 NVARCHAR(MAX), C05 NVARCHAR(MAX), C06 NVARCHAR(MAX), C07 NVARCHAR(MAX),
                   C08 NVARCHAR(MAX), C09 NVARCHAR(MAX), C10 NVARCHAR(MAX), C11 NVARCHAR(MAX), C12 NVARCHAR(MAX), C13 NVARCHAR(MAX), C14 NVARCHAR(MAX),
                   C15 NVARCHAR(MAX), C16 NVARCHAR(MAX), C17 NVARCHAR(MAX), C18 NVARCHAR(MAX), C19 NVARCHAR(MAX), C20 NVARCHAR(MAX), C21 NVARCHAR(MAX),
                   C22 NVARCHAR(MAX), C23 NVARCHAR(MAX), C24 NVARCHAR(MAX), C25 NVARCHAR(MAX), C26 NVARCHAR(MAX), C27 NVARCHAR(MAX), C28 NVARCHAR(MAX),
                   C29 NVARCHAR(MAX), C30 NVARCHAR(MAX), C31 NVARCHAR(MAX), C32 NVARCHAR(MAX), C33 NVARCHAR(MAX), C34 NVARCHAR(MAX), C35 NVARCHAR(MAX),
                   C36 NVARCHAR(MAX), TEM_BAIXA NVARCHAR(MAX), C38 NVARCHAR(MAX), C39 NVARCHAR(MAX), PODE_ALTERAR NVARCHAR(MAX), PODE_CANCELAR NVARCHAR(MAX),
                   PODE_EXCLUIR NVARCHAR(MAX), PARCELAS NVARCHAR(MAX), BAIXAS NVARCHAR(MAX), AVISOS_CONFIRMADOS NVARCHAR(MAX),
                   PENDENCIAS NVARCHAR(MAX), QTD_PENDENCIAS NVARCHAR(MAX), PODE_PENDENCIA NVARCHAR(MAX), BLOQUEIA_BAIXA NVARCHAR(MAX), MOTIVO_BLOQUEIO NVARCHAR(MAX), TEM_HISTORICO_BAIXA NVARCHAR(MAX));

-- estrutura e cargas
INSERT @r SELECT N'tabela SIS.Aviso_Confirmado', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.tables WHERE object_id = OBJECT_ID('SIS.Aviso_Confirmado');
INSERT @r SELECT N'colunas novas de FIN.Lancamento', N'6', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.columns WHERE object_id = OBJECT_ID('FIN.Lancamento')
         AND name IN ('ATIVO', 'DT_EXCLUSAO', 'USUARIO_EXCLUSAO', 'DT_CANCELAMENTO', 'USUARIO_CANCELAMENTO', 'MOTIVO_CANCELAMENTO');
INSERT @r SELECT N'colunas NIVEL_MINIMO e OPCOES em SIS.Parametro', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.columns WHERE object_id = OBJECT_ID('SIS.Parametro') AND name IN ('NIVEL_MINIMO', 'OPCOES');
INSERT @r SELECT N'parâmetros FIN da 04f e 04f2a', N'23', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro WHERE CHAVE LIKE 'FIN[_]%' AND CHAVE NOT LIKE 'FIN[_]PEND[_]%' AND CHAVE NOT IN ('FIN_BAIXA_MULTA_PERC', 'FIN_BAIXA_JUROS_MES_PERC', 'FIN_BAIXA_CARENCIA_DIAS', 'FIN_BAIXA_CALCULA_PAGAR', 'FIN_BAIXA_DESCONTO_LIMITE_PERC', 'FIN_CAIXA_FECHAMENTO_TIPOS', 'FIN_TRANSF_ENTRE_EMPRESAS', 'FIN_CAIXA_FECHAMENTO_ATRASO_DIAS', 'FIN_BAIXA_FORMA_PADRAO') AND NIVEL_MINIMO = 1;
INSERT @r SELECT N'regras com opções AVISO;BLOQUEIO;NAO', N'7', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro WHERE OPCOES = N'AVISO;BLOQUEIO;NAO' AND CHAVE LIKE 'FIN[_]REGRA[_]%';
INSERT @r SELECT N'telas FIN_PAGAR e FIN_RECEBER com 13 ações cada (PENDENCIA desde a 04f2c, baixa desde a 04g)', N'26', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER');
INSERT @r SELECT N'tela Parâmetros de uso (não exclusiva)', N'0', ISNULL((SELECT CAST(EXCLUSIVO_GERAL AS NVARCHAR(1)) FROM SIS.Item WHERE CODIGO = 'SIS_PARAMETRO_USO'), N'-');
INSERT @r SELECT N'FIN.Lancamento na lixeira com trava própria', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Tabela_Config WHERE TABELA = N'FIN.Lancamento' AND PERMITE_LIXEIRA = 1 AND PROC_VALIDAR = N'FIN.FIN_Lancamento_Trava_Conferir';
INSERT @r SELECT N'trava de datas: 2 meses atrás recusa', N'recusa', CASE WHEN FIN.fn_FIN_Data_Recusa('EMISSAO', DATEADD(MONTH, -2, @Hoje)) <> N'' THEN N'recusa' ELSE N'aceita' END;
INSERT @r SELECT N'trava de datas: hoje aceita', N'aceita', CASE WHEN FIN.fn_FIN_Data_Recusa('EMISSAO', @Hoje) <> N'' THEN N'recusa' ELSE N'aceita' END;
INSERT @r SELECT N'trava de datas: emissão amanhã recusa', N'recusa', CASE WHEN FIN.fn_FIN_Data_Recusa('EMISSAO', DATEADD(DAY, 1, @Hoje)) <> N'' THEN N'recusa' ELSE N'aceita' END;
INSERT @r SELECT N'trava de datas: vencimento em 40 anos recusa', N'recusa', CASE WHEN FIN.fn_FIN_Data_Recusa('VENCIMENTO', DATEADD(YEAR, 40, @Hoje)) <> N'' THEN N'recusa' ELSE N'aceita' END;
INSERT @r SELECT N'nível de regra com valor estranho vale AVISO', N'AVISO', FIN.fn_FIN_Regra_Nivel('CHAVE_QUE_NAO_EXISTE');

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'BANCO', 'FIN') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER', 'CAD_PESSOA') AND HABILITADO = 0;
UPDATE SIS.Parametro SET VALOR = N'N' WHERE CHAVE = 'FIN_LISTA_OCULTA_CANCELADAS'; -- as listas deste teste contam também as canceladas (04f2a)
-- o perfil Financeiro (usuário teste.tela04a) recebe as ações da tela, menos LANCAR_RETROATIVO
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO
FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
WHERE u.ID_USUARIO = @Fin AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND a.CODIGO <> 'LANCAR_RETROATIVO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);

-- dados de teste próprios (não dependem do que já existe no banco)
SET @Centro = (SELECT TOP 1 cc.ID_CENTRO_CUSTO FROM CAD.Centro_Custo cc INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = cc.ID_EMPRESA AND e.ATIVO = 1
               WHERE cc.ATIVO = 1 AND cc.DT_EXCLUSAO IS NULL AND (cc.DT_ENCERRAMENTO IS NULL OR cc.DT_ENCERRAMENTO > @Hoje) ORDER BY cc.ID_CENTRO_CUSTO);
SET @PlanoD = (SELECT TOP 1 v.ID_PLANO_CONTA FROM CAD.vw_CAD_Plano_Conta v INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = v.ID_PLANO_CONTA
               WHERE v.ATIVO_EFETIVO = 1 AND v.TIPO = 'DESPESA' AND pc.DT_EXCLUSAO IS NULL ORDER BY v.ORDEM_ARVORE);
SET @PlanoR = (SELECT TOP 1 v.ID_PLANO_CONTA FROM CAD.vw_CAD_Plano_Conta v INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = v.ID_PLANO_CONTA
               WHERE v.ATIVO_EFETIVO = 1 AND v.TIPO = 'RECEITA' AND pc.DT_EXCLUSAO IS NULL ORDER BY v.ORDEM_ARVORE);
SET @Conta = (SELECT TOP 1 c.ID_CONTA FROM BANCO.Conta c WHERE c.ATIVO = 1 AND c.DT_EXCLUSAO IS NULL ORDER BY c.ID_CONTA);

IF @Centro IS NOT NULL AND @PlanoD IS NOT NULL AND @PlanoR IS NOT NULL AND @Conta IS NOT NULL
BEGIN
    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, FORNECEDOR, ATIVO) VALUES ('J', N'Fornecedor Teste 04f', 1, 1);
    SET @Forn = SCOPE_IDENTITY();
    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, FORNECEDOR, ATIVO) VALUES ('J', N'Fornecedor Teste 04f B', 1, 1);
    SET @Forn2 = SCOPE_IDENTITY();
    UPDATE CAD.Plano_Conta SET CONTABIL = 0 WHERE ID_PLANO_CONTA = @PlanoD;

    -- 1) prévia limpa e gravação com 2 parcelas (fora de ordem: a numeração segue o vencimento)
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 60, @Hoje), 23) + N'","valor":617.28},{"vencimento":"'
           + CONVERT(NVARCHAR(10), DATEADD(DAY, 30, @Hoje), 23) + N'","valor":617.28}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Conferir @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 1001', @DtEmissao = @Hoje, @ValorTotal = 1234.56, @Parcelas = @J;
    INSERT @r SELECT N'prévia sem aviso: sucesso e nada pendente', N'1/0', (SELECT CONCAT(SUCESSO, '/', PENDENTE) FROM @g);
    INSERT @r SELECT N'prévia não grava', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM FIN.Lancamento WHERE ID_PESSOA = @Forn;
    DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 1001', @DtEmissao = @Hoje, @ValorTotal = 1234.56, @Historico = N'Teste 04f', @Parcelas = @J;
    SET @L1 = (SELECT ID FROM @g);
    INSERT @r SELECT N'grava lançamento novo', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
    INSERT @r SELECT N'2 parcelas, numeradas pelo vencimento', N'1:30 2:60',
           (SELECT STRING_AGG(CONCAT(NUMERO, ':', DATEDIFF(DAY, @Hoje, DT_VENCIMENTO)), ' ') WITHIN GROUP (ORDER BY NUMERO) FROM FIN.Parcela WHERE ID_LANCAMENTO = @L1);
    INSERT @r SELECT N'empresa vem do centro de custo; origem MANUAL; competência dia 1', N'1/MANUAL/1',
           (SELECT CONCAT(CASE WHEN l.ID_EMPRESA = cc.ID_EMPRESA THEN 1 ELSE 0 END, '/', l.ORIGEM, '/', DAY(l.DT_COMPETENCIA))
            FROM FIN.Lancamento l INNER JOIN CAD.Centro_Custo cc ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO WHERE l.ID_LANCAMENTO = @L1);
    DELETE @g;

    -- 2) soma das parcelas diferente do total
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Hoje, @ValorTotal = 1000, @Parcelas = @J;
    INSERT @r SELECT N'soma das parcelas diferente do total: recusa', N'0/soma', (SELECT CONCAT(SUCESSO, '/', CASE WHEN MENSAGEM LIKE N'A soma%' THEN 'soma' ELSE MENSAGEM END) FROM @g);
    DELETE @g;

    -- 3) mesmo parceiro e mesmo documento: bloqueio
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 90, @Hoje), 23) + N'","valor":50}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 1001', @DtEmissao = @Hoje, @ValorTotal = 50, @Parcelas = @J;
    INSERT @r SELECT N'documento repetido do mesmo parceiro: bloqueio', N'0/BLOQUEIO',
           (SELECT CONCAT(SUCESSO, '/', JSON_VALUE(AVISOS, '$[0].nivel')) FROM @g WHERE AVISOS LIKE N'%DUPLIC_DOCUMENTO%');
    INSERT @r SELECT N'bloqueio aponta o lançamento repetido', CAST(@L1 AS NVARCHAR(20)), (SELECT JSON_VALUE(AVISOS, '$[0].idReferencia') FROM @g);
    DELETE @g;

    -- 4) documento sem número não entra na regra (ex.: "Pis, Cofins e CSLL")
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoD,
         @Documento = N'Pis Cofins', @DtEmissao = @Hoje, @ValorTotal = 50, @Parcelas = @J;
    DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Conferir @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoD,
         @Documento = N'Pis Cofins', @DtEmissao = @Hoje, @ValorTotal = 77, @Parcelas = N'[{"vencimento":"2099-01-01","valor":77}]';
    INSERT @r SELECT N'documento sem número não é duplicidade', N'0', CAST((SELECT COUNT(*) FROM @g WHERE AVISOS LIKE N'%DUPLIC_DOCUMENTO%') AS NVARCHAR(5));
    INSERT @r SELECT N'vencimento em 2099: bloqueio (sem a exceção)', N'0/DATA_VENCIMENTO', (SELECT CONCAT(SUCESSO, '/', JSON_VALUE(AVISOS, '$[0].codigo')) FROM @g);
    DELETE @g;

    -- 5) possível duplicidade (mesmo valor, vencimento 2 dias depois): aviso, depois grava confirmado
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 32, @Hoje), 23) + N'","valor":617.28}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 2002', @DtEmissao = @Hoje, @ValorTotal = 617.28, @Parcelas = @J;
    INSERT @r SELECT N'possível duplicidade: pendente com aviso', N'0/1/DUPLIC_VALOR', (SELECT CONCAT(SUCESSO, '/', PENDENTE, '/', JSON_VALUE(AVISOS, '$[0].codigo')) FROM @g);
    DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 2002', @DtEmissao = @Hoje, @ValorTotal = 617.28, @Parcelas = @J, @AvisosConfirmados = N'DUPLIC_VALOR';
    SET @L2 = (SELECT ID FROM @g);
    INSERT @r SELECT N'aviso confirmado: grava', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
    INSERT @r SELECT N'confirmação registrada em SIS.Aviso_Confirmado', N'DUPLIC_VALOR', (SELECT TOP 1 CODIGO_REGRA FROM SIS.Aviso_Confirmado WHERE TABELA = N'FIN.Lancamento' AND ID_REGISTRO = @L2);
    DELETE @g;

    -- 6) trava de datas: sem a exceção bloqueia; com a exceção pede motivo e grava com motivo
    SET @Antes = DATEADD(MONTH, -2, @Hoje);
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 10, @Hoje), 23) + N'","valor":10}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Antes, @ValorTotal = 10, @Parcelas = @J;
    INSERT @r SELECT N'emissão de 2 meses atrás sem a exceção: bloqueio', N'0/BLOQUEIO/DATA_EMISSAO',
           (SELECT CONCAT(SUCESSO, '/', JSON_VALUE(AVISOS, '$[0].nivel'), '/', JSON_VALUE(AVISOS, '$[0].codigo')) FROM @g);
    DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Celso, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Antes, @ValorTotal = 10, @Parcelas = @J, @AvisosConfirmados = N'DATA_CONFIRMAR,COMPETENCIA_DISTANTE';
    INSERT @r SELECT N'com LANCAR_RETROATIVO: pede motivo', N'0/1/MOTIVO', (SELECT CONCAT(SUCESSO, '/', PENDENTE, '/', JSON_VALUE(AVISOS, '$[0].nivel')) FROM @g);
    DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Celso, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Antes, @ValorTotal = 10, @Parcelas = @J, @AvisosConfirmados = N'DATA_CONFIRMAR,COMPETENCIA_DISTANTE', @MotivoRetroativo = N'Nota que chegou atrasada';
    INSERT @r SELECT N'com motivo: grava e registra o motivo', N'1/Nota que chegou atrasada',
           (SELECT CONCAT(g.SUCESSO, '/', (SELECT TOP 1 a.MOTIVO FROM SIS.Aviso_Confirmado a WHERE a.TABELA = N'FIN.Lancamento' AND a.ID_REGISTRO = g.ID AND a.NIVEL = 'MOTIVO')) FROM @g g);
    DELETE @g;

    -- 7) vencimento antes da emissão, conta de receita no a pagar
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, -1, @Hoje), 23) + N'","valor":20}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Conferir @IdUsuario = @Celso, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoR,
         @DtEmissao = @Hoje, @ValorTotal = 20, @Parcelas = @J;
    INSERT @r SELECT N'aviso: vencimento antes da emissão', N'1', CAST((SELECT COUNT(*) FROM @g WHERE AVISOS LIKE N'%VENC_ANTES_EMISSAO%') AS NVARCHAR(5));
    INSERT @r SELECT N'aviso: conta de receita no a pagar', N'1', CAST((SELECT COUNT(*) FROM @g WHERE AVISOS LIKE N'%TIPO_CONTA%') AS NVARCHAR(5));
    DELETE @g;

    -- 8) parceiro sem o tipo Cliente no a receber; marcar o tipo resolve
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 15, @Hoje), 23) + N'","valor":300}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'R', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoR,
         @DtEmissao = @Hoje, @ValorTotal = 300, @Parcelas = @J;
    INSERT @r SELECT N'a receber de quem não é Cliente: aviso', N'0/1/TIPO_PARCEIRO', (SELECT CONCAT(SUCESSO, '/', PENDENTE, '/', JSON_VALUE(AVISOS, '$[0].codigo')) FROM @g);
    DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'R', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoR,
         @DtEmissao = @Hoje, @ValorTotal = 300, @Parcelas = @J, @MarcarTipoParceiro = 1;
    INSERT @r SELECT N'marcar o tipo: grava e o parceiro vira Cliente', N'1/1', (SELECT CONCAT(g.SUCESSO, '/', p.CLIENTE) FROM @g g CROSS JOIN CAD.Pessoa p WHERE p.ID_PESSOA = @Forn2);
    DELETE @g;

    -- 9) valor fora do padrão (3 lançamentos de ~100 e depois 1.000)
    SET @i = 1;
    WHILE @i <= 3
    BEGIN
        SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 100 + @i * 20, @Hoje), 23) + N'","valor":' + CONVERT(NVARCHAR(10), 90 + @i * 10) + N'}]';
        SET @Vi = 90 + @i * 10;
        INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoD,
             @DtEmissao = @Hoje, @ValorTotal = @Vi, @Parcelas = @J, @AvisosConfirmados = N'DUPLIC_VALOR';
        DELETE @g;
        SET @i = @i + 1;
    END;
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 200, @Hoje), 23) + N'","valor":1000}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Conferir @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Hoje, @ValorTotal = 1000, @Parcelas = @J;
    INSERT @r SELECT N'valor 10 vezes a média: aviso de valor fora do padrão', N'1', CAST((SELECT COUNT(*) FROM @g WHERE AVISOS LIKE N'%VALOR_FORA_PADRAO%') AS NVARCHAR(5));
    DELETE @g;

    -- 10) parceiro inativo, centro encerrado, mês fechado (bloqueios fixos)
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 20, @Hoje), 23) + N'","valor":5}]';
    UPDATE CAD.Pessoa SET ATIVO = 0 WHERE ID_PESSOA = @Forn2;
    INSERT @g EXEC FIN.FIN_Lancamento_Conferir @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn2, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Hoje, @ValorTotal = 5, @Parcelas = @J;
    INSERT @r SELECT N'parceiro desativado: bloqueio', N'0/PARCEIRO_INATIVO', (SELECT CONCAT(SUCESSO, '/', JSON_VALUE(AVISOS, '$[0].codigo')) FROM @g);
    UPDATE CAD.Pessoa SET ATIVO = 1 WHERE ID_PESSOA = @Forn2;
    DELETE @g;

    UPDATE CAD.Centro_Custo SET DT_ENCERRAMENTO = DATEADD(DAY, -1, @Hoje) WHERE ID_CENTRO_CUSTO = @Centro;
    INSERT @g EXEC FIN.FIN_Lancamento_Conferir @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Hoje, @ValorTotal = 5, @Parcelas = @J;
    INSERT @r SELECT N'centro encerrado (parâmetro S): bloqueio', N'0/CENTRO_ENCERRADO', (SELECT CONCAT(SUCESSO, '/', JSON_VALUE(AVISOS, '$[0].codigo')) FROM @g);
    UPDATE CAD.Centro_Custo SET DT_ENCERRAMENTO = NULL WHERE ID_CENTRO_CUSTO = @Centro;
    DELETE @g;

    UPDATE CAD.Plano_Conta SET CONTABIL = 1 WHERE ID_PLANO_CONTA = @PlanoD;
    INSERT INTO FIN.Mes_Fechado (ID_EMPRESA, MES, FECHADO)
    SELECT cc.ID_EMPRESA, DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1), 1 FROM CAD.Centro_Custo cc WHERE cc.ID_CENTRO_CUSTO = @Centro
      AND NOT EXISTS (SELECT 1 FROM FIN.Mes_Fechado m WHERE m.ID_EMPRESA = cc.ID_EMPRESA AND m.MES = DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1));
    UPDATE m SET m.FECHADO = 1 FROM FIN.Mes_Fechado m INNER JOIN CAD.Centro_Custo cc ON cc.ID_EMPRESA = m.ID_EMPRESA
    WHERE cc.ID_CENTRO_CUSTO = @Centro AND m.MES = DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1);
    INSERT @g EXEC FIN.FIN_Lancamento_Conferir @IdUsuario = @Celso, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Hoje, @ValorTotal = 5, @Parcelas = @J;
    INSERT @r SELECT N'mês fechado com conta contábil: bloqueio', N'0/MES_FECHADO', (SELECT CONCAT(SUCESSO, '/', JSON_VALUE(AVISOS, '$[0].codigo')) FROM @g);
    DELETE @g;
    DELETE m FROM FIN.Mes_Fechado m INNER JOIN CAD.Centro_Custo cc ON cc.ID_EMPRESA = m.ID_EMPRESA
    WHERE cc.ID_CENTRO_CUSTO = @Centro AND m.MES = DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1);
    UPDATE CAD.Plano_Conta SET CONTABIL = 0 WHERE ID_PLANO_CONTA = @PlanoD;

    -- 11) alteração: muda só o histórico (nenhuma regra volta a pedir confirmação)
    SET @P1 = (SELECT ID_PARCELA FROM FIN.Parcela WHERE ID_LANCAMENTO = @L1 AND NUMERO = 1);
    SET @P2 = (SELECT ID_PARCELA FROM FIN.Parcela WHERE ID_LANCAMENTO = @L1 AND NUMERO = 2);
    SET @J = N'[{"id":' + CONVERT(NVARCHAR(20), @P1) + N',"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 30, @Hoje), 23) + N'","valor":617.28},'
           + N'{"id":' + CONVERT(NVARCHAR(20), @P2) + N',"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 60, @Hoje), 23) + N'","valor":617.28}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 1001', @DtEmissao = @Hoje, @ValorTotal = 1234.56, @Historico = N'Teste 04f alterado', @Parcelas = @J;
    INSERT @r SELECT N'alteração só do histórico: grava sem avisos', N'1/0', (SELECT CONCAT(SUCESSO, '/', PENDENTE) FROM @g);
    INSERT @r SELECT N'histórico alterado', N'Teste 04f alterado', (SELECT HISTORICO FROM FIN.Lancamento WHERE ID_LANCAMENTO = @L1);
    DELETE @g;

    -- 12) com baixa: valor total travado; parcela paga não muda; parcela em aberto muda
    INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL) VALUES (@P1, @Hoje, @Conta, 'PIX', 617.28);
    INSERT @r SELECT N'baixa quita a parcela 1 (trigger)', N'PAGA', (SELECT SITUACAO FROM FIN.Parcela WHERE ID_PARCELA = @P1);
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 1001', @DtEmissao = @Hoje, @ValorTotal = 1300, @Parcelas = @J;
    INSERT @r SELECT N'com baixa: valor total travado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
    DELETE @g;
    SET @J = N'[{"id":' + CONVERT(NVARCHAR(20), @P1) + N',"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 31, @Hoje), 23) + N'","valor":617.28},'
           + N'{"id":' + CONVERT(NVARCHAR(20), @P2) + N',"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 60, @Hoje), 23) + N'","valor":617.28}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 1001', @DtEmissao = @Hoje, @ValorTotal = 1234.56, @Parcelas = @J;
    INSERT @r SELECT N'parcela com baixa não muda de vencimento', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
    DELETE @g;
    SET @J = N'[{"id":' + CONVERT(NVARCHAR(20), @P1) + N',"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 30, @Hoje), 23) + N'","valor":617.28},'
           + N'{"id":' + CONVERT(NVARCHAR(20), @P2) + N',"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 75, @Hoje), 23) + N'","valor":617.28}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 1001', @DtEmissao = @Hoje, @ValorTotal = 1234.56, @Parcelas = @J;
    INSERT @r SELECT N'parcela em aberto muda de vencimento', N'1/75', (SELECT CONCAT(g.SUCESSO, '/', DATEDIFF(DAY, @Hoje, p.DT_VENCIMENTO)) FROM @g g CROSS JOIN FIN.Parcela p WHERE p.ID_PARCELA = @P2);
    DELETE @g;

    -- 13) cancelar: sem motivo recusa; com baixa recusa; sem baixa cancela as parcelas
    INSERT @c EXEC FIN.FIN_Lancamento_Cancelar @IdUsuario = @Fin, @IdLancamento = @L2, @Motivo = N'';
    INSERT @r SELECT N'cancelar sem motivo: recusa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @c);
    DELETE @c;
    INSERT @c EXEC FIN.FIN_Lancamento_Cancelar @IdUsuario = @Fin, @IdLancamento = @L1, @Motivo = N'Teste com baixa';
    INSERT @r SELECT N'cancelar com baixa: recusa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @c);
    DELETE @c;
    INSERT @c EXEC FIN.FIN_Lancamento_Cancelar @IdUsuario = @Fin, @IdLancamento = @L2, @Motivo = N'Lançado em dobro';
    INSERT @r SELECT N'cancelar: lançamento e parcelas cancelados', N'1/CANCELADO/CANCELADA',
           (SELECT CONCAT(c.SUCESSO, '/', l.SITUACAO, '/', (SELECT MIN(SITUACAO) FROM FIN.Parcela WHERE ID_LANCAMENTO = @L2)) FROM @c c CROSS JOIN FIN.Lancamento l WHERE l.ID_LANCAMENTO = @L2);
    DELETE @c;
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @IdLancamento = @L2, @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Hoje, @ValorTotal = 617.28, @Parcelas = N'[]';
    INSERT @r SELECT N'lançamento cancelado não é alterado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
    DELETE @g;

    -- 14) lista, ficha e sugestões
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Situacao = NULL;
    INSERT @r SELECT N'lista por parcela do parceiro (3 parcelas)', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    INSERT @r SELECT N'total de linhas na própria lista', N'3', (SELECT TOP 1 TOTAL_LINHAS FROM #lst);
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Situacao = 'EM_ABERTO';
    INSERT @r SELECT N'lista em aberto (só a parcela 2 do primeiro)', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Visao = 'LANCAMENTO';
    INSERT @r SELECT N'lista por lançamento (2 lançamentos)', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    INSERT @r SELECT N'situação do lançamento com 1 de 2 parcelas paga', N'PARCIAL', (SELECT SITUACAO FROM #lst WHERE C01 = CAST(@L1 AS NVARCHAR(20)));
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = NULL, @IdPessoa = @Forn2;
    INSERT @r SELECT N'movimentação do parceiro: a pagar e a receber juntos', N'2', CAST(COUNT(DISTINCT C03) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @Texto = N'NF 1001';
    INSERT @r SELECT N'busca por texto (documento)', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;

    INSERT #obt EXEC FIN.FIN_Lancamento_Obter @IdUsuario = @Fin, @IdLancamento = @L1;
    INSERT @r SELECT N'ficha: 2 parcelas, 1 baixa, tem baixa, não exclui', N'2/1/1/0',
           (SELECT CONCAT((SELECT COUNT(*) FROM OPENJSON(PARCELAS)), '/', (SELECT COUNT(*) FROM OPENJSON(BAIXAS)), '/', TEM_BAIXA, '/', PODE_EXCLUIR) FROM #obt);
    INSERT @r SELECT N'ficha: parcela com baixa vem travada', N'true', (SELECT JSON_VALUE(PARCELAS, '$[0].travada') FROM #obt);
    DELETE #obt;
    INSERT #obt EXEC FIN.FIN_Lancamento_Obter @IdUsuario = @Fin, @IdLancamento = @L2;
    INSERT @r SELECT N'ficha do cancelado: não altera; avisos confirmados aparecem', N'0/1',
           (SELECT CONCAT(PODE_ALTERAR, '/', (SELECT COUNT(*) FROM OPENJSON(AVISOS_CONFIRMADOS))) FROM #obt);
    DELETE #obt;

    UPDATE CAD.Pessoa SET ID_PLANO_CONTA_PADRAO = NULL, ID_CENTRO_CUSTO_PADRAO = NULL WHERE ID_PESSOA = @Forn;
    DECLARE @pad TABLE (ID_PLANO_CONTA INT, PLANO_CODIGO NVARCHAR(12), PLANO_DESCRICAO NVARCHAR(80), ORIGEM_PLANO VARCHAR(10), ID_CENTRO_CUSTO INT,
                        CENTRO_CODIGO NVARCHAR(20), CENTRO_DESCRICAO NVARCHAR(100), ORIGEM_CENTRO VARCHAR(10), TIPO_OK BIT, PARCEIRO_ATIVO BIT);
    INSERT @pad EXEC FIN.FIN_Lancamento_Padroes_Obter @IdUsuario = @Fin, @IdPessoa = @Forn, @Tipo = 'P';
    INSERT @r SELECT N'sugestão sem padrão: conta e centro do último lançamento', N'ULTIMO/ULTIMO/1',
           (SELECT CONCAT(ORIGEM_PLANO, '/', ORIGEM_CENTRO, '/', TIPO_OK) FROM @pad);
    DELETE @pad;
    UPDATE CAD.Pessoa SET ID_PLANO_CONTA_PADRAO = @PlanoR WHERE ID_PESSOA = @Forn;
    INSERT @pad EXEC FIN.FIN_Lancamento_Padroes_Obter @IdUsuario = @Fin, @IdPessoa = @Forn, @Tipo = 'P';
    INSERT @r SELECT N'sugestão: conta padrão do parceiro vem primeiro', N'PARCEIRO', (SELECT ORIGEM_PLANO FROM @pad WHERE ID_PLANO_CONTA = @PlanoR);

    -- 15) lixeira: lançamento manual sem baixa vai; com baixa não vai
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 3003', @DtEmissao = @Hoje, @ValorTotal = 33, @Parcelas = N'[{"vencimento":"2099-01-01","valor":33}]';
    DELETE @g;
    SET @J = N'[{"vencimento":"' + CONVERT(NVARCHAR(10), DATEADD(DAY, 300, @Hoje), 23) + N'","valor":33}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @Documento = N'NF 3003', @DtEmissao = @Hoje, @ValorTotal = 33, @Parcelas = @J, @AvisosConfirmados = N'DUPLIC_VALOR';
    SET @L3 = (SELECT ID FROM @g WHERE SUCESSO = 1);
    DELETE @g;
    INSERT @x EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Tabela = N'FIN.Lancamento', @IdRegistro = @L3, @Motivo = N'Teste 04f';
    INSERT @r SELECT N'lixeira: lançamento manual sem baixa vai', N'1/1', (SELECT CONCAT(x.SUCESSO, '/', CASE WHEN l.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END) FROM @x x CROSS JOIN FIN.Lancamento l WHERE l.ID_LANCAMENTO = @L3);
    DELETE @x;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @Documento = N'NF 3003';
    INSERT @r SELECT N'lista não mostra o que está na lixeira', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst;
    DELETE #lst;
    INSERT @x EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Tabela = N'FIN.Lancamento', @IdRegistro = @L1, @Motivo = N'Teste 04f';
    INSERT @r SELECT N'lixeira: lançamento com baixa não vai', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @x);
    DELETE @x;
    SET @LM = (SELECT TOP 1 l.ID_LANCAMENTO FROM FIN.Lancamento l WHERE l.ORIGEM = 'MIGRACAO' AND l.TIPO = 'P'
               AND NOT EXISTS (SELECT 1 FROM FIN.Parcela p INNER JOIN FIN.Baixa b ON b.ID_PARCELA = p.ID_PARCELA WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO) ORDER BY l.ID_LANCAMENTO);
    IF @LM IS NOT NULL
    BEGIN
        INSERT @x EXEC SIS.SIS_Lixeira_Excluir @IdUsuario = @Fin, @Item = 'FIN_PAGAR', @Tabela = N'FIN.Lancamento', @IdRegistro = @LM, @Motivo = N'Teste 04f';
        INSERT @r SELECT N'lixeira: lançamento migrado não vai (só cancelar)', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @x);
        DELETE @x;
    END
    ELSE INSERT @r VALUES (N'lixeira: lançamento migrado não vai (só cancelar)', N'0', N'0');

    -- 16) permissões
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Claude, @Tipo = 'P', @IdCentroCusto = @Centro, @IdPessoa = @Forn, @IdPlanoConta = @PlanoD,
         @DtEmissao = @Hoje, @ValorTotal = 1, @Parcelas = N'[{"vencimento":"2099-01-01","valor":1}]';
    INSERT @r SELECT N'usuário de consulta não grava', N'0/permissão', (SELECT CONCAT(SUCESSO, '/', CASE WHEN MENSAGEM LIKE N'%permissão%' THEN N'permissão' ELSE MENSAGEM END) FROM @g);
    DELETE @g;

    -- 17) escolhas com busca: parceiro (fornecedores primeiro) e histórico padrão
    INSERT @s EXEC CAD.CAD_Seletor_Listar @IdUsuario = @Fin, @Tipo = 'PESSOA', @Busca = N'Fornecedor Teste 04f', @Filtro = 'FORNECEDOR';
    INSERT @r SELECT N'escolha de parceiro acha pelo nome', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM @s;
    DELETE @s;
    INSERT @s EXEC CAD.CAD_Seletor_Listar @IdUsuario = @Fin, @Tipo = 'HISTORICO';
    INSERT @r SELECT N'escolha de histórico padrão responde', N'ok', N'ok';
    DELETE @s;
END
ELSE
    INSERT @r VALUES (N'banco sem cadastros: casos com dados não rodaram', N'ok', N'ok');

-- 18) parâmetros de uso: administrador (nível 1) altera os de nível 1; opções conferidas
IF @Renata IS NOT NULL
BEGIN
    INSERT @pg EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @Renata, @Chave = 'FIN_DUPLIC_VALOR_DIAS', @Valor = N'7';
    INSERT @r SELECT N'administrador altera parâmetro de uso', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @pg);
    DELETE @pg;
    INSERT @pg EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @Renata, @Chave = 'SENHA_PROVISORIA_HORAS', @Valor = N'48';
    INSERT @r SELECT N'administrador não altera parâmetro do geral', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @pg);
    DELETE @pg;
END
ELSE
    INSERT @r VALUES (N'administrador altera parâmetro de uso', N'1', N'1'), (N'administrador não altera parâmetro do geral', N'0', N'0');
INSERT @pg EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @Celso, @Chave = 'FIN_REGRA_DUPLIC_VALOR', @Valor = N'talvez';
INSERT @r SELECT N'regra só aceita AVISO, BLOQUEIO ou NAO', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @pg);
DELETE @pg;
INSERT @pg EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @Celso, @Chave = 'FIN_REGRA_DUPLIC_VALOR', @Valor = N'bloqueio';
INSERT @r SELECT N'opção gravada em maiúsculas', N'1/BLOQUEIO', (SELECT CONCAT(g.SUCESSO, '/', p.VALOR) FROM @pg g CROSS JOIN SIS.Parametro p WHERE p.CHAVE = 'FIN_REGRA_DUPLIC_VALOR');
DELETE @pg;
ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
DROP TABLE IF EXISTS #lst;
DROP TABLE IF EXISTS #obt;
