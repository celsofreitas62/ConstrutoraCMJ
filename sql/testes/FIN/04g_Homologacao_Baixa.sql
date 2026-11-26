/*******************************************************************************
  Teste       : 04g1 - baixa e estorno: estrutura e cargas, sugestão de juros,
                multa e limite de desconto, baixa parcial e total, encargo
                ajustado (aviso), valor acima do saldo, desconto acima do limite
                (bloqueio e motivo com a permissão), baixa em lote com tarifa
                (um movimento), estorno do lote inteiro, pendência que bloqueia
                (bloqueio e liberação com justificativa), caixa fechado, tipos
                misturados e permissão BAIXAR.
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 26/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do MASTER
                (no banco sem empresa ou sem o usuário de teste, os casos com
                dados passam direto).
  Observação  : não muda nada (tudo desfeito com ROLLBACK). Datas calculadas a
                partir de hoje, para o teste valer em qualquer dia.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(200), OBTIDO NVARCHAR(200));
DECLARE @g TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);
DECLARE @b TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, ID_MOVIMENTO BIGINT, ID_LOTE BIGINT, PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @e TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, QTD_BAIXAS INT, VALOR DECIMAL(18,2), PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @Fin INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'teste.tela04a');
DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @Amanha DATE = DATEADD(DAY, 1, CONVERT(DATE, SYSDATETIME()));
DECLARE @Empresa INT, @Conta INT, @Forn INT, @Cli INT, @LR BIGINT, @LP BIGINT, @PR BIGINT, @PP1 BIGINT, @PP2 BIGINT, @IdNF INT, @Baixa BIGINT, @Mov BIGINT, @Itens NVARCHAR(MAX);

-- estrutura e cargas
INSERT @r SELECT N'tabela BANCO.Caixa_Fechamento', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.tables WHERE object_id = OBJECT_ID('BANCO.Caixa_Fechamento');
INSERT @r SELECT N'funções novas', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.objects WHERE object_id IN (OBJECT_ID('FIN.fn_FIN_Baixa_Sugerir'), OBJECT_ID('BANCO.fn_BANCO_Caixa_Recusa'));
INSERT @r SELECT N'procedures novas', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.procedures WHERE object_id IN (OBJECT_ID('FIN.FIN_Baixa_Gravar'), OBJECT_ID('FIN.FIN_Baixa_Estornar'));
INSERT @r SELECT N'ações novas', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Acao WHERE CODIGO IN ('LIBERAR_PENDENCIA', 'DESCONTO_LIMITE');
INSERT @r SELECT N'ações da baixa nas telas de pagar e receber', N'8', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item_Acao ia
       INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
       WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND a.CODIGO IN ('BAIXAR', 'ESTORNAR', 'LIBERAR_PENDENCIA', 'DESCONTO_LIMITE');
INSERT @r SELECT N'parâmetros da baixa e do caixa de nível 1', N'7', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro
       WHERE (CHAVE LIKE 'FIN[_]BAIXA[_]%' OR CHAVE IN ('FIN_CAIXA_FECHAMENTO_TIPOS', 'FIN_TRANSF_ENTRE_EMPRESAS')) AND NIVEL_MINIMO = 1 AND CHAVE <> 'FIN_BAIXA_DIAS_FUTURO';
INSERT @r SELECT N'auditoria do fechamento de caixa', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.triggers WHERE name = 'tg_BANCO_Caixa_Fechamento_Auditoria';

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'BANCO', 'FIN') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND HABILITADO = 0;
UPDATE p SET p.VALOR = v.VALOR
FROM SIS.Parametro p
INNER JOIN (VALUES ('FIN_BAIXA_MULTA_PERC', N'2.00'), ('FIN_BAIXA_JUROS_MES_PERC', N'1.00'), ('FIN_BAIXA_CARENCIA_DIAS', N'0'),
                   ('FIN_BAIXA_CALCULA_PAGAR', N'N'), ('FIN_BAIXA_DESCONTO_LIMITE_PERC', N'5.00'), ('FIN_TRAVA_DATAS_ATIVA', N'S')) v (CHAVE, VALOR) ON v.CHAVE = p.CHAVE;
-- usuário de teste: tudo nas telas de pagar e receber, menos retroativo, liberar pendência e desconto acima do limite
DELETE up FROM SIS.Usuario_Permissao up WHERE up.ID_USUARIO = @Fin;
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO
FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
WHERE u.ID_USUARIO = @Fin AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND a.CODIGO NOT IN ('LANCAR_RETROATIVO', 'LIBERAR_PENDENCIA', 'DESCONTO_LIMITE')
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);
DELETE pp FROM SIS.Perfil_Permissao pp
INNER JOIN SIS.Usuario u ON u.ID_PERFIL = pp.ID_PERFIL AND u.ID_USUARIO = @Fin
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO
INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO IN ('LIBERAR_PENDENCIA', 'DESCONTO_LIMITE');

SET @Empresa = (SELECT TOP 1 e.ID_EMPRESA FROM CAD.Empresa e WHERE e.ATIVO = 1 ORDER BY e.ID_EMPRESA);
SET @IdNF    = (SELECT ID_PENDENCIA_TIPO FROM FIN.Pendencia_Tipo WHERE CODIGO = 'AGUARDA_NF');

IF @Empresa IS NOT NULL AND @Fin IS NOT NULL
BEGIN
    IF @IdNF IS NULL
    BEGIN
        INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, APLICA_A, BLOQUEIA_BAIXA) VALUES ('AGUARDA_NF', N'Aguardando nota fiscal', 'P', 1);
        SET @IdNF = SCOPE_IDENTITY();
    END;
    UPDATE FIN.Pendencia_Tipo SET BLOQUEIA_BAIXA = 1, ATIVO = 1 WHERE ID_PENDENCIA_TIPO = @IdNF;

    INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO) VALUES (@Empresa, N'Caixa Teste 04g', 'CAIXA');
    SET @Conta = SCOPE_IDENTITY();
    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, FORNECEDOR, ATIVO) VALUES ('J', N'Fornecedor Teste 04g', 1, 1);
    SET @Forn = SCOPE_IDENTITY();
    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, CLIENTE, ATIVO) VALUES ('F', N'Cliente Teste 04g', 1, 1);
    SET @Cli = SCOPE_IDENTITY();

    -- a receber: R$ 1.000, vencida há 30 dias
    INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, ID_PESSOA, DT_EMISSAO, DT_COMPETENCIA, VALOR_TOTAL, HISTORICO)
    VALUES ('R', @Empresa, @Cli, DATEADD(DAY, -40, @Hoje), DATEFROMPARTS(YEAR(DATEADD(DAY, -40, @Hoje)), MONTH(DATEADD(DAY, -40, @Hoje)), 1), 1000.00, N'Teste 04g receber');
    SET @LR = SCOPE_IDENTITY();
    INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR) VALUES (@LR, 1, 1, DATEADD(DAY, -30, @Hoje), 1000.00);
    SET @PR = SCOPE_IDENTITY();
    -- a pagar: R$ 500 em 2 parcelas (uma vencida há 10 dias, outra a vencer)
    INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, ID_PESSOA, DT_EMISSAO, DT_COMPETENCIA, VALOR_TOTAL, HISTORICO, DOCUMENTO)
    VALUES ('P', @Empresa, @Forn, DATEADD(DAY, -20, @Hoje), DATEFROMPARTS(YEAR(DATEADD(DAY, -20, @Hoje)), MONTH(DATEADD(DAY, -20, @Hoje)), 1), 500.00, N'Teste 04g pagar', N'NF 4040');
    SET @LP = SCOPE_IDENTITY();
    INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR) VALUES (@LP, 1, 2, DATEADD(DAY, -10, @Hoje), 250.00);
    SET @PP1 = SCOPE_IDENTITY();
    INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR) VALUES (@LP, 2, 2, DATEADD(DAY, 10, @Hoje), 250.00);
    SET @PP2 = SCOPE_IDENTITY();

    -- sugestão
    INSERT @r SELECT N'sugerir a receber: dias/multa/juros/limite desconto', N'30/20.00/10.00/50.00',
           (SELECT CONCAT(DIAS_ATRASO, '/', MULTA, '/', JUROS, '/', DESCONTO_LIMITE) FROM FIN.fn_FIN_Baixa_Sugerir(@PR, @Hoje, NULL));
    INSERT @r SELECT N'sugerir a receber, parcial 400: multa/juros', N'8.00/4.00', (SELECT CONCAT(MULTA, '/', JUROS) FROM FIN.fn_FIN_Baixa_Sugerir(@PR, @Hoje, 400));
    INSERT @r SELECT N'sugerir a pagar: não calcula', N'0/0.00/0.00/-', (SELECT CONCAT(CAST(CALCULA AS INT), '/', MULTA, '/', JUROS, '/', ISNULL(CAST(DESCONTO_LIMITE AS NVARCHAR(20)), '-')) FROM FIN.fn_FIN_Baixa_Sugerir(@PP1, @Hoje, NULL));
    INSERT @r SELECT N'sugerir dentro da carência (35 dias)', N'0', (SELECT CAST(CALCULA AS NVARCHAR(1)) FROM FIN.fn_FIN_Baixa_Sugerir(@PR, DATEADD(DAY, -30, @Hoje), NULL));

    -- baixa parcial com encargo diferente do calculado: aviso
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PR) + N',"principal":400,"juros":5,"multa":8}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    INSERT @r SELECT N'encargo ajustado: pendente com aviso', N'0/1/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CAST(PENDENTE AS INT), '/', CASE WHEN AVISOS LIKE N'%ENCARGO_AJUSTADO%' THEN 1 ELSE 0 END) FROM @b); DELETE @b;

    -- baixa parcial com o calculado
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PR) + N',"principal":400,"juros":4,"multa":8}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    SELECT @Mov = ID_MOVIMENTO FROM @b;
    INSERT @r SELECT N'baixa parcial gravada', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @b); DELETE @b;
    INSERT @r SELECT N'parcela parcial: saldo/situação', N'600.00/PARCIAL', (SELECT CONCAT(SALDO, '/', SITUACAO) FROM FIN.Parcela WHERE ID_PARCELA = @PR);
    INSERT @r SELECT N'movimento de entrada (líquido)', N'412.00/BAIXA', (SELECT CONCAT(VALOR, '/', TIPO) FROM BANCO.Movimento WHERE ID_MOVIMENTO = @Mov);
    INSERT @r SELECT N'segunda baixa não sugere multa de novo', N'0.00/6.00', (SELECT CONCAT(MULTA, '/', JUROS) FROM FIN.fn_FIN_Baixa_Sugerir(@PR, @Hoje, NULL));

    -- valor acima do saldo
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PR) + N',"principal":700,"juros":7}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    INSERT @r SELECT N'valor acima do saldo: recusa', N'0/0', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CAST(PENDENTE AS INT)) FROM @b); DELETE @b;

    -- desconto acima do limite (limite 30,00 do saldo 600)
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PR) + N',"principal":600,"juros":6,"desconto":40}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'DINHEIRO', @Itens = @Itens;
    INSERT @r SELECT N'desconto acima do limite sem permissão: recusa', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN AVISOS LIKE N'%"DESCONTO_LIMITE","nivel":"BLOQUEIO"%' THEN 1 ELSE 0 END) FROM @b); DELETE @b;
    INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
    SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
    WHERE u.ID_USUARIO = @Fin AND i.CODIGO = 'FIN_RECEBER' AND a.CODIGO = 'DESCONTO_LIMITE';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'DINHEIRO', @Itens = @Itens;
    INSERT @r SELECT N'com a permissão: pede motivo', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CAST(PENDENTE AS INT)) FROM @b); DELETE @b;
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'DINHEIRO', @Itens = @Itens, @Motivo = N'Cliente antigo, acordo';
    SELECT @Baixa = ID FROM @b;
    INSERT @r SELECT N'com motivo: baixa total gravada', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @b); DELETE @b;
    INSERT @r SELECT N'parcela quitada: saldo/situação', N'0.00/PAGA', (SELECT CONCAT(SALDO, '/', SITUACAO) FROM FIN.Parcela WHERE ID_PARCELA = @PR);
    INSERT @r SELECT N'motivo do desconto registrado', N'1', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Aviso_Confirmado WHERE TABELA = N'FIN.Baixa' AND ID_REGISTRO = @Baixa AND CODIGO_REGRA = 'DESCONTO_LIMITE' AND MOTIVO <> N'');
    INSERT @r SELECT N'parcela sem saldo: recusa', N'0', '';
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PR) + N',"principal":1}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    UPDATE @r SET OBTIDO = (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @b) WHERE CASO = N'parcela sem saldo: recusa'; DELETE @b;

    -- tipos misturados
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PP1) + N',"principal":10},{"idParcela":' + CONVERT(NVARCHAR(20), @PR) + N',"principal":1}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    INSERT @r SELECT N'pagar e receber juntos: recusa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @b); DELETE @b;

    -- baixa em lote a pagar com tarifa: um movimento
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PP1) + N',"principal":250,"tarifa":2.5},{"idParcela":' + CONVERT(NVARCHAR(20), @PP2) + N',"principal":250}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'TED', @Itens = @Itens;
    SELECT @Mov = ID_MOVIMENTO, @Baixa = ID FROM @b;
    INSERT @r SELECT N'lote a pagar gravado', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @b);
    INSERT @r SELECT N'um movimento de saída pelo total', N'-500.00/2', (SELECT CONCAT(m.VALOR, '/', (SELECT COUNT(*) FROM FIN.Baixa b WHERE b.ID_MOVIMENTO = @Mov)) FROM BANCO.Movimento m WHERE m.ID_MOVIMENTO = @Mov);
    INSERT @r SELECT N'tarifa em movimento próprio', N'-2.50', (SELECT CAST(SUM(m.VALOR) AS NVARCHAR(20)) FROM BANCO.Movimento m INNER JOIN @b x ON x.ID_LOTE = m.ID_LOTE WHERE m.TIPO = 'TARIFA');
    INSERT @r SELECT N'lote com 2 baixas', N'2', (SELECT CAST(QTD_REGISTROS AS NVARCHAR(5)) FROM SIS.Lote l INNER JOIN @b x ON x.ID_LOTE = l.ID_LOTE); DELETE @b;

    -- estorno
    INSERT @e EXEC FIN.FIN_Baixa_Estornar @IdUsuario = @Fin, @IdBaixa = @Baixa, @Motivo = N'';
    INSERT @r SELECT N'estorno sem motivo: recusa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @e); DELETE @e;
    INSERT @e EXEC FIN.FIN_Baixa_Estornar @IdUsuario = @Fin, @IdBaixa = @Baixa, @SomenteConferir = 1;
    INSERT @r SELECT N'prévia do estorno: lote inteiro', N'1/2/500.00', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', QTD_BAIXAS, '/', VALOR) FROM @e); DELETE @e;
    INSERT @e EXEC FIN.FIN_Baixa_Estornar @IdUsuario = @Fin, @IdBaixa = @Baixa, @Motivo = N'Pago na conta errada';
    INSERT @r SELECT N'estorno do lote gravado', N'1/2', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', QTD_BAIXAS) FROM @e); DELETE @e;
    INSERT @r SELECT N'parcelas voltam abertas', N'250.00/ABERTA|250.00/ABERTA',
           (SELECT STRING_AGG(CONCAT(SALDO, '/', SITUACAO), '|') WITHIN GROUP (ORDER BY NUMERO) FROM FIN.Parcela WHERE ID_LANCAMENTO = @LP);
    INSERT @r SELECT N'movimentos do pagamento estornados e zerados', N'0.00/4',
           (SELECT CONCAT(SUM(m.VALOR), '/', COUNT(*)) FROM BANCO.Movimento m WHERE m.ID_CONTA = @Conta AND m.SITUACAO = 'ESTORNADO');
    INSERT @r SELECT N'saldo da conta (só o receber)', N'978.00', (SELECT CAST(SUM(m.VALOR) AS NVARCHAR(20)) FROM BANCO.Movimento m WHERE m.ID_CONTA = @Conta);
    INSERT @e EXEC FIN.FIN_Baixa_Estornar @IdUsuario = @Fin, @IdBaixa = @Baixa, @Motivo = N'De novo';
    INSERT @r SELECT N'estornar de novo: recusa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @e); DELETE @e;

    -- pendência que bloqueia a baixa
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamento = @LP, @IdPendenciaTipo = @IdNF; DELETE @g;
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PP1) + N',"principal":250}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    INSERT @r SELECT N'pendência que bloqueia: recusa', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN AVISOS LIKE N'%"PENDENCIA_BLOQUEIA","nivel":"BLOQUEIO"%' THEN 1 ELSE 0 END) FROM @b); DELETE @b;
    INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
    SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
    WHERE u.ID_USUARIO = @Fin AND i.CODIGO = 'FIN_PAGAR' AND a.CODIGO = 'LIBERAR_PENDENCIA';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    INSERT @r SELECT N'com LIBERAR_PENDENCIA: pede justificativa', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CAST(PENDENTE AS INT)) FROM @b); DELETE @b;
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens, @Motivo = N'NF chega amanhã, pagamento urgente';
    SELECT @Baixa = ID FROM @b;
    INSERT @r SELECT N'liberada com justificativa: gravada e registrada', N'1/1',
           CONCAT((SELECT CAST(SUCESSO AS INT) FROM @b), '/', (SELECT COUNT(*) FROM SIS.Aviso_Confirmado WHERE TABELA = N'FIN.Baixa' AND ID_REGISTRO = @Baixa AND CODIGO_REGRA = 'PENDENCIA_BLOQUEIA')); DELETE @b;

    -- caixa fechado
    INSERT INTO BANCO.Caixa_Fechamento (ID_CONTA, DT_FECHAMENTO, SALDO_SISTEMA, SALDO_CONTADO) VALUES (@Conta, @Hoje, 728.00, 728.00);
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @PP2) + N',"principal":250}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens, @Motivo = N'NF chega amanhã, pagamento urgente';
    INSERT @r SELECT N'caixa fechado: baixa recusada', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN AVISOS LIKE N'%CAIXA_FECHADO%' THEN 1 ELSE 0 END) FROM @b); DELETE @b;
    INSERT @e EXEC FIN.FIN_Baixa_Estornar @IdUsuario = @Fin, @IdBaixa = @Baixa, @Motivo = N'Teste caixa fechado';
    INSERT @r SELECT N'caixa fechado: estorno recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @e); DELETE @e;
    INSERT @r SELECT N'caixa fechado: data seguinte aceita', N'', BANCO.fn_BANCO_Caixa_Recusa(@Conta, DATEADD(DAY, 1, @Hoje));

    -- sem a permissão BAIXAR
    DELETE pp FROM SIS.Perfil_Permissao pp
    INNER JOIN SIS.Usuario u ON u.ID_PERFIL = pp.ID_PERFIL AND u.ID_USUARIO = @Fin
    INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO
    INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'BAIXAR';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Amanha, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    INSERT @r SELECT N'sem a ação BAIXAR: recusado', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN MENSAGEM LIKE N'%permissão%' THEN 1 ELSE 0 END) FROM @b); DELETE @b;
END;
ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
