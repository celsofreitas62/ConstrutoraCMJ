/*******************************************************************************
  Teste       : 04g2 - transferência, extrato, saldos e fechamento de caixa:
                estrutura e cargas; transferência (prévia, aviso entre
                empresas e de saldo, bloqueio pelo parâmetro, caixa fechado,
                trava de datas, gravação com dois movimentos, estorno das
                duas pontas, estorno repetido, lista); extrato (saldo anterior,
                saldo inicial, histórico, estornos); saldos por conta;
                fechamento de caixa (prévia, tipos, datas, diferença com
                motivo, ajuste com permissão, reabrir o último com o ajuste
                desfeito, lista); permissões.
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 27/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do MASTER
                (no banco sem empresa ou sem o usuário de teste, os casos com
                dados passam direto).
  Observação  : não muda nada (tudo desfeito com ROLLBACK). Datas calculadas a
                partir de hoje, para o teste valer em qualquer dia.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(200), OBTIDO NVARCHAR(200));
DECLARE @t TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, ID_LOTE BIGINT, PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @e TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, VALOR DECIMAL(18,2), PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @Fin INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'teste.tela04a');
DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @Ontem DATE = DATEADD(DAY, -1, CONVERT(DATE, SYSDATETIME()));
DECLARE @Empresa INT, @Empresa2 INT, @CxA INT, @CxB INT, @BcC INT, @Tr BIGINT, @Saldo DECIMAL(18,2);
DECLARE @f TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, SALDO_SISTEMA DECIMAL(18,2), SALDO_CONTADO DECIMAL(18,2), DIFERENCA DECIMAL(18,2),
                  DT_ULTIMO_FECHAMENTO VARCHAR(10), ENTRADAS DECIMAL(18,2), SAIDAS DECIMAL(18,2), QTD_MOVIMENTOS INT, PODE_AJUSTE BIT,
                  ID_MOVIMENTO_AJUSTE BIGINT, PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @ra TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, VALOR_AJUSTE DECIMAL(18,2), PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @FOntem BIGINT, @FHoje BIGINT, @Amanha DATE = DATEADD(DAY, 1, CONVERT(DATE, SYSDATETIME())), @Perm INT;

-- estrutura e cargas
INSERT @r SELECT N'colunas novas de FIN.Transferencia', N'6', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.columns
       WHERE object_id = OBJECT_ID('FIN.Transferencia') AND name IN ('DOCUMENTO', 'DT_ESTORNO', 'MOTIVO_ESTORNO', 'USUARIO_ESTORNO', 'DT_HORA_ESTORNO', 'ID_LOTE_ESTORNO');
INSERT @r SELECT N'função do saldo', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.objects WHERE object_id = OBJECT_ID('BANCO.fn_BANCO_Conta_Saldo');
INSERT @r SELECT N'procedures da transferência', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.procedures
       WHERE object_id IN (OBJECT_ID('FIN.FIN_Transferencia_Gravar'), OBJECT_ID('FIN.FIN_Transferencia_Estornar'), OBJECT_ID('FIN.FIN_Transferencia_Listar'));
INSERT @r SELECT N'ação AJUSTE_CAIXA', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Acao WHERE CODIGO = 'AJUSTE_CAIXA';
INSERT @r SELECT N'telas novas do módulo Bancos', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item i INNER JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO AND m.CODIGO = 'BANCO'
       WHERE i.CODIGO IN ('BANCO_TRANSFERENCIA', 'BANCO_EXTRATO', 'BANCO_CAIXA');
INSERT @r SELECT N'ações das telas novas', N'12', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM
       WHERE i.CODIGO IN ('BANCO_TRANSFERENCIA', 'BANCO_EXTRATO', 'BANCO_CAIXA');
INSERT @r SELECT N'auditoria da transferência pega as colunas novas', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.triggers t
       WHERE t.name = 'tg_FIN_Transferencia_Auditoria' AND OBJECT_DEFINITION(t.object_id) LIKE '%MOTIVO_ESTORNO%';

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'BANCO', 'FIN') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('BANCO_TRANSFERENCIA', 'BANCO_EXTRATO', 'BANCO_CAIXA') AND HABILITADO = 0;
UPDATE p SET p.VALOR = v.VALOR
FROM SIS.Parametro p
INNER JOIN (VALUES ('FIN_TRANSF_ENTRE_EMPRESAS', N'AVISO'), ('FIN_TRAVA_DATAS_ATIVA', N'S'), ('FIN_CAIXA_FECHAMENTO_TIPOS', N'CAIXA')) v (CHAVE, VALOR) ON v.CHAVE = p.CHAVE;
-- usuário de teste: tudo nas telas novas, menos retroativo, reabrir e ajuste
DELETE up FROM SIS.Usuario_Permissao up WHERE up.ID_USUARIO = @Fin;
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO
FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
WHERE u.ID_USUARIO = @Fin AND i.CODIGO IN ('BANCO_TRANSFERENCIA', 'BANCO_EXTRATO', 'BANCO_CAIXA') AND a.CODIGO NOT IN ('LANCAR_RETROATIVO', 'REABRIR', 'AJUSTE_CAIXA')
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);
DELETE pp FROM SIS.Perfil_Permissao pp
INNER JOIN SIS.Usuario u ON u.ID_PERFIL = pp.ID_PERFIL AND u.ID_USUARIO = @Fin
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO
INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM AND i.CODIGO IN ('BANCO_TRANSFERENCIA', 'BANCO_EXTRATO', 'BANCO_CAIXA')
INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO IN ('LANCAR_RETROATIVO', 'REABRIR', 'AJUSTE_CAIXA');

SET @Empresa  = (SELECT TOP 1 e.ID_EMPRESA FROM CAD.Empresa e WHERE e.ATIVO = 1 ORDER BY e.ID_EMPRESA);
SET @Empresa2 = (SELECT TOP 1 e.ID_EMPRESA FROM CAD.Empresa e WHERE e.ATIVO = 1 AND e.ID_EMPRESA <> ISNULL(@Empresa, 0) ORDER BY e.ID_EMPRESA);

IF @Empresa IS NOT NULL AND @Fin IS NOT NULL
BEGIN
    INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, SALDO_INICIAL, DT_SALDO_INICIAL) VALUES (@Empresa, N'Caixa A Teste 04g2', 'CAIXA', 1000.00, DATEADD(DAY, -10, @Hoje));
    SET @CxA = SCOPE_IDENTITY();
    INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO) VALUES (@Empresa, N'Caixa B Teste 04g2', 'CAIXA');
    SET @CxB = SCOPE_IDENTITY();
    IF @Empresa2 IS NOT NULL
    BEGIN
        INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO) VALUES (@Empresa2, N'Caixa C Teste 04g2', 'CAIXA');
        SET @BcC = SCOPE_IDENTITY();
    END;

    -- movimento anterior ao saldo inicial não conta
    INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO) VALUES (@CxA, DATEADD(DAY, -20, @Hoje), 999.00, 'AJUSTE', N'histórico antigo');
    INSERT @r SELECT N'saldo: movimento antes do saldo inicial não conta', N'1000.00', (SELECT CONVERT(NVARCHAR(20), SALDO) FROM BANCO.fn_BANCO_Conta_Saldo(@CxA, @Hoje));
    INSERT @r SELECT N'saldo: antes do saldo inicial a conta não tem saldo', N'0', (SELECT CONVERT(NVARCHAR(1), TEM_SALDO) FROM BANCO.fn_BANCO_Conta_Saldo(@CxA, DATEADD(DAY, -15, @Hoje)));

    -- recusas simples
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxA, @IdContaDestino = @CxA, @Valor = 10;
    INSERT @r SELECT N'mesma conta: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @t); DELETE @t;
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxA, @IdContaDestino = @CxB, @Valor = 0;
    INSERT @r SELECT N'valor zero: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @t); DELETE @t;

    -- prévia e gravação
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxA, @IdContaDestino = @CxB, @Valor = 300, @Historico = N'Troco', @SomenteConferir = 1;
    INSERT @r SELECT N'prévia sem aviso', N'1/0', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CAST(PENDENTE AS INT)) FROM @t); DELETE @t;
    INSERT @r SELECT N'prévia não grava', N'0', CAST((SELECT COUNT(*) FROM BANCO.Movimento WHERE ID_CONTA = @CxB) AS NVARCHAR(5));
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxA, @IdContaDestino = @CxB, @Valor = 300, @Historico = N'Troco';
    SELECT @Tr = ID FROM @t;
    INSERT @r SELECT N'gravada', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @t); DELETE @t;
    INSERT @r SELECT N'dois movimentos (-300 e +300)', N'2/0.00', CONCAT((SELECT COUNT(*) FROM BANCO.Movimento WHERE ID_TRANSFERENCIA = @Tr), '/', (SELECT CONVERT(NVARCHAR(20), SUM(VALOR)) FROM BANCO.Movimento WHERE ID_TRANSFERENCIA = @Tr));
    INSERT @r SELECT N'saldo da origem depois', N'700.00', (SELECT CONVERT(NVARCHAR(20), SALDO) FROM BANCO.fn_BANCO_Conta_Saldo(@CxA, @Hoje));
    INSERT @r SELECT N'histórico com a outra conta', N'1', CAST((SELECT COUNT(*) FROM BANCO.Movimento WHERE ID_TRANSFERENCIA = @Tr AND ID_CONTA = @CxA AND HISTORICO = N'Transferência para Caixa B Teste 04g2: Troco') AS NVARCHAR(5));

    -- aviso de saldo insuficiente
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxA, @IdContaDestino = @CxB, @Valor = 5000;
    INSERT @r SELECT N'saldo insuficiente: pede confirmação', N'0/1/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CAST(PENDENTE AS INT), '/', CASE WHEN AVISOS LIKE N'%SALDO_INSUFICIENTE%' THEN 1 ELSE 0 END) FROM @t); DELETE @t;
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxA, @IdContaDestino = @CxB, @Valor = 5000, @AvisosConfirmados = N'SALDO_INSUFICIENTE';
    INSERT @r SELECT N'saldo insuficiente confirmado: gravada e registrada', N'1/1',
           CONCAT((SELECT CAST(SUCESSO AS INT) FROM @t), '/', (SELECT COUNT(*) FROM SIS.Aviso_Confirmado a INNER JOIN @t x ON x.ID = a.ID_REGISTRO WHERE a.TABELA = N'FIN.Transferencia' AND a.CODIGO_REGRA = 'SALDO_INSUFICIENTE')); DELETE @t;

    -- entre empresas
    IF @BcC IS NOT NULL
    BEGIN
        INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxB, @IdContaDestino = @BcC, @Valor = 10, @SomenteConferir = 1;
        INSERT @r SELECT N'entre empresas (AVISO): pede confirmação', N'1/1', (SELECT CONCAT(CAST(PENDENTE AS INT), '/', CASE WHEN AVISOS LIKE N'%ENTRE_EMPRESAS%' THEN 1 ELSE 0 END) FROM @t); DELETE @t;
        UPDATE SIS.Parametro SET VALOR = N'BLOQUEIO' WHERE CHAVE = 'FIN_TRANSF_ENTRE_EMPRESAS';
        INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxB, @IdContaDestino = @BcC, @Valor = 10, @AvisosConfirmados = N'ENTRE_EMPRESAS';
        INSERT @r SELECT N'entre empresas (BLOQUEIO): recusado', N'0/0', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CAST(PENDENTE AS INT)) FROM @t); DELETE @t;
        UPDATE SIS.Parametro SET VALOR = N'NAO' WHERE CHAVE = 'FIN_TRANSF_ENTRE_EMPRESAS';
        INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxB, @IdContaDestino = @BcC, @Valor = 10, @SomenteConferir = 1;
        INSERT @r SELECT N'entre empresas (NAO): sem aviso', N'0', (SELECT CAST(PENDENTE AS NVARCHAR(1)) FROM @t); DELETE @t;
        UPDATE SIS.Parametro SET VALOR = N'AVISO' WHERE CHAVE = 'FIN_TRANSF_ENTRE_EMPRESAS';
    END
    ELSE
        INSERT @r VALUES (N'entre empresas (AVISO): pede confirmação', N'1/1', N'1/1'), (N'entre empresas (BLOQUEIO): recusado', N'0/0', N'0/0'), (N'entre empresas (NAO): sem aviso', N'0', N'0');

    -- trava de datas: sem LANCAR_RETROATIVO bloqueia
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = '2020-01-01', @IdContaOrigem = @CxA, @IdContaDestino = @CxB, @Valor = 10;
    INSERT @r SELECT N'data antiga sem permissão: recusada', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN AVISOS LIKE N'%DATA_TRANSFERENCIA%' THEN 1 ELSE 0 END) FROM @t); DELETE @t;

    -- caixa fechado na ponta de destino
    INSERT INTO BANCO.Caixa_Fechamento (ID_CONTA, DT_FECHAMENTO, SALDO_SISTEMA, SALDO_CONTADO) VALUES (@CxB, @Hoje, 0, 0);
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxA, @IdContaDestino = @CxB, @Valor = 10;
    INSERT @r SELECT N'caixa fechado no destino: recusada', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN AVISOS LIKE N'%CAIXA_FECHADO%' THEN 1 ELSE 0 END) FROM @t); DELETE @t;
    INSERT @e EXEC FIN.FIN_Transferencia_Estornar @IdUsuario = @Fin, @IdTransferencia = @Tr, @Motivo = N'Teste com caixa fechado';
    INSERT @r SELECT N'caixa fechado: estorno recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @e); DELETE @e;
    DELETE FROM BANCO.Caixa_Fechamento WHERE ID_CONTA = @CxB;

    -- estorno
    INSERT @e EXEC FIN.FIN_Transferencia_Estornar @IdUsuario = @Fin, @IdTransferencia = @Tr;
    INSERT @r SELECT N'estorno sem motivo: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @e); DELETE @e;
    INSERT @e EXEC FIN.FIN_Transferencia_Estornar @IdUsuario = @Fin, @IdTransferencia = @Tr, @Motivo = N'Conta errada', @SomenteConferir = 1;
    INSERT @r SELECT N'prévia do estorno', N'1/300.00', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CONVERT(NVARCHAR(20), VALOR)) FROM @e); DELETE @e;
    INSERT @e EXEC FIN.FIN_Transferencia_Estornar @IdUsuario = @Fin, @IdTransferencia = @Tr, @Motivo = N'Conta errada';
    INSERT @r SELECT N'estornada', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @e); DELETE @e;
    INSERT @r SELECT N'4 movimentos ESTORNADO, soma zero', N'4/0.00', CONCAT((SELECT COUNT(*) FROM BANCO.Movimento WHERE ID_TRANSFERENCIA = @Tr AND SITUACAO = 'ESTORNADO'), '/', (SELECT CONVERT(NVARCHAR(20), SUM(VALOR)) FROM BANCO.Movimento WHERE ID_TRANSFERENCIA = @Tr));
    INSERT @r SELECT N'transferência ESTORNADA com motivo', N'ESTORNADA/Conta errada', (SELECT CONCAT(SITUACAO, '/', MOTIVO_ESTORNO) FROM FIN.Transferencia WHERE ID_TRANSFERENCIA = @Tr);
    INSERT @e EXEC FIN.FIN_Transferencia_Estornar @IdUsuario = @Fin, @IdTransferencia = @Tr, @Motivo = N'De novo';
    INSERT @r SELECT N'estorno repetido: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @e); DELETE @e;

    -- lista
    DECLARE @lst TABLE (ID_TRANSFERENCIA BIGINT, DT_TRANSFERENCIA DATE, ID_CONTA_ORIGEM INT, CONTA_ORIGEM NVARCHAR(60), ID_EMPRESA_ORIGEM INT, EMPRESA_ORIGEM NVARCHAR(150),
                        ID_CONTA_DESTINO INT, CONTA_DESTINO NVARCHAR(60), ID_EMPRESA_DESTINO INT, EMPRESA_DESTINO NVARCHAR(150), ENTRE_EMPRESAS BIT, VALOR DECIMAL(18,2),
                        HISTORICO NVARCHAR(200), DOCUMENTO NVARCHAR(40), SITUACAO VARCHAR(10), DT_ESTORNO VARCHAR(10), MOTIVO_ESTORNO NVARCHAR(400), USUARIO_ESTORNO NVARCHAR(100),
                        USUARIO_CRIACAO NVARCHAR(100), DT_CRIACAO DATETIME2(0), ID_LOTE BIGINT, MIGRADA BIT, PODE_ESTORNAR BIT, TOTAL_LINHAS INT, TOTAL_VALOR DECIMAL(18,2));
    INSERT @lst EXEC FIN.FIN_Transferencia_Listar @IdUsuario = @Fin, @IdConta = @CxA;
    INSERT @r SELECT N'lista pela conta: 2 linhas, total só das ativas', N'2/5000.00', (SELECT TOP 1 CONCAT(TOTAL_LINHAS, '/', CONVERT(NVARCHAR(20), TOTAL_VALOR)) FROM @lst);
    INSERT @r SELECT N'estornada não pode estornar de novo', N'0', (SELECT CAST(PODE_ESTORNAR AS NVARCHAR(1)) FROM @lst WHERE ID_TRANSFERENCIA = @Tr);

    -- extrato
    DECLARE @ext TABLE (DT_MOVIMENTO DATE, ID_MOVIMENTO BIGINT, TIPO VARCHAR(15), HISTORICO NVARCHAR(200), DOCUMENTO NVARCHAR(40), VALOR DECIMAL(18,2),
                        ENTRADA DECIMAL(18,2), SAIDA DECIMAL(18,2), SALDO_ACUMULADO DECIMAL(18,2), CONTA_SALDO BIT, SITUACAO VARCHAR(10), CONCILIADO BIT,
                        ID_TRANSFERENCIA BIGINT, ID_LOTE BIGINT, USUARIO_CRIACAO NVARCHAR(100), ID_LANCAMENTO BIGINT, LANCAMENTO_TIPO CHAR(1), PESSOA NVARCHAR(150),
                        QTD_BAIXAS INT, OUTRA_CONTA NVARCHAR(60), SALDO_ANTERIOR DECIMAL(18,2), TOTAL_ENTRADAS DECIMAL(18,2), TOTAL_SAIDAS DECIMAL(18,2), SALDO_FINAL DECIMAL(18,2));
    DECLARE @De DATE = DATEADD(DAY, -10, @Hoje), @De2 DATE = DATEADD(DAY, -25, @Hoje);
    INSERT @ext EXEC BANCO.BANCO_Extrato_Listar @IdUsuario = @Fin, @IdConta = @CxA, @DtDe = @De, @DtAte = @Hoje;
    INSERT @r SELECT N'extrato: linhas (anterior, saldo inicial, 3 movimentos)', N'5', CAST((SELECT COUNT(*) FROM @ext) AS NVARCHAR(5));
    INSERT @r SELECT N'extrato: entradas/saídas/saldo final', N'300.00/5300.00/-4000.00', (SELECT TOP 1 CONCAT(CONVERT(NVARCHAR(20), TOTAL_ENTRADAS), '/', CONVERT(NVARCHAR(20), TOTAL_SAIDAS), '/', CONVERT(NVARCHAR(20), SALDO_FINAL)) FROM @ext);
    INSERT @r SELECT N'extrato: última linha acumulada = saldo da conta', N'1', CAST((SELECT COUNT(*) FROM (SELECT TOP 1 SALDO_ACUMULADO FROM @ext ORDER BY DT_MOVIMENTO DESC, ID_MOVIMENTO DESC) x
           WHERE x.SALDO_ACUMULADO = (SELECT SALDO FROM BANCO.fn_BANCO_Conta_Saldo(@CxA, @Hoje))) AS NVARCHAR(5));
    INSERT @r SELECT N'extrato: outra conta na transferência', N'Caixa B Teste 04g2', (SELECT TOP 1 OUTRA_CONTA FROM @ext WHERE ID_TRANSFERENCIA = @Tr);
    DELETE @ext;
    INSERT @ext EXEC BANCO.BANCO_Extrato_Listar @IdUsuario = @Fin, @IdConta = @CxA, @DtDe = @De2, @DtAte = @Hoje;
    INSERT @r SELECT N'extrato: movimento antes do saldo inicial é só histórico', N'6/0/-4000.00',
           CONCAT((SELECT COUNT(*) FROM @ext), '/', (SELECT CAST(CONTA_SALDO AS INT) FROM @ext WHERE VALOR = 999.00), '/', (SELECT TOP 1 CONVERT(NVARCHAR(20), SALDO_FINAL) FROM @ext));
    DELETE @ext;
    INSERT @ext EXEC BANCO.BANCO_Extrato_Listar @IdUsuario = @Fin, @IdConta = @CxA, @DtDe = @De, @DtAte = @Hoje, @OcultarEstornados = 1;
    INSERT @r SELECT N'extrato sem os estornados', N'3', CAST((SELECT COUNT(*) FROM @ext) AS NVARCHAR(5));

    -- saldos por conta
    INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO) VALUES (@CxB, @Ontem, 50.00, 'AJUSTE', N'teste atraso');
    DECLARE @sal TABLE (ID_CONTA INT, ID_EMPRESA INT, EMPRESA NVARCHAR(150), DESCRICAO NVARCHAR(60), TIPO VARCHAR(10), BANCO NVARCHAR(80), AGENCIA VARCHAR(10), NUMERO VARCHAR(20),
                        ORDEM SMALLINT, ATIVO BIT, MOSTRA_SALDO BIT, CONCILIA BIT, SALDO DECIMAL(18,2), LIMITE_CREDITO DECIMAL(18,2), DISPONIVEL DECIMAL(18,2), TEM_SALDO BIT,
                        DT_SALDO_INICIAL VARCHAR(10), DT_ULTIMO_MOVIMENTO VARCHAR(10), QTD_NAO_CONCILIADOS INT, USA_FECHAMENTO BIT, DT_ULTIMO_FECHAMENTO VARCHAR(10),
                        FECHAMENTO_ATRASADO BIT, DT_PRIMEIRO_SEM_FECHAR VARCHAR(10));
    INSERT @sal EXEC BANCO.BANCO_Saldo_Listar @IdUsuario = @Fin, @IdEmpresa = @Empresa;
    INSERT @r SELECT N'saldos: conta A', N'-4000.00/1/0', (SELECT CONCAT(CONVERT(NVARCHAR(20), SALDO), '/', CAST(USA_FECHAMENTO AS INT), '/', CAST(FECHAMENTO_ATRASADO AS INT)) FROM @sal WHERE ID_CONTA = @CxA);
    INSERT @r SELECT N'saldos: conta B com movimento de ontem sem fechar', N'5050.00/1', (SELECT CONCAT(CONVERT(NVARCHAR(20), SALDO), '/', CAST(FECHAMENTO_ATRASADO AS INT)) FROM @sal WHERE ID_CONTA = @CxB);

    -- fechamento de caixa
    INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO) VALUES (@Empresa, N'Permuta Teste 04g2', 'PERMUTA');
    SET @Perm = SCOPE_IDENTITY();
    INSERT @f EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = @Fin, @IdConta = @Perm, @DtFechamento = @Ontem, @SaldoContado = 0;
    INSERT @r SELECT N'caixa: tipo de conta fora do parâmetro recusado', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN MENSAGEM LIKE N'%não usa%' THEN 1 ELSE 0 END) FROM @f); DELETE @f;
    INSERT @f EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = @Fin, @IdConta = @CxA, @DtFechamento = @Ontem, @SomenteConferir = 1;
    INSERT @r SELECT N'caixa: prévia de ontem com o saldo do sistema', N'1/1000.00', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CONVERT(NVARCHAR(20), SALDO_SISTEMA)) FROM @f); DELETE @f;
    INSERT @f EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = @Fin, @IdConta = @CxA, @DtFechamento = @Amanha, @SaldoContado = 0;
    INSERT @r SELECT N'caixa: dia que não chegou recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @f); DELETE @f;
    INSERT @f EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = @Fin, @IdConta = @CxA, @DtFechamento = @Ontem, @SaldoContado = 1000.00;
    SELECT @FOntem = ID FROM @f;
    INSERT @r SELECT N'caixa: ontem fechado sem diferença', N'1/0.00', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CONVERT(NVARCHAR(20), DIFERENCA)) FROM @f); DELETE @f;
    INSERT @f EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = @Fin, @IdConta = @CxA, @DtFechamento = @Ontem, @SaldoContado = 1000.00;
    INSERT @r SELECT N'caixa: mesma data de novo recusada', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN MENSAGEM LIKE N'%já está fechado%' THEN 1 ELSE 0 END) FROM @f); DELETE @f;
    INSERT @r SELECT N'caixa: baixa/transferência de ontem bloqueada', N'1', CASE WHEN BANCO.fn_BANCO_Caixa_Recusa(@CxA, @Ontem) <> N'' THEN N'1' ELSE N'0' END;
    INSERT @f EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = @Fin, @IdConta = @CxA, @DtFechamento = @Hoje, @SaldoContado = -3990.00;
    INSERT @r SELECT N'caixa: diferença sem motivo pede o motivo', N'0/1/10.00', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CAST(PENDENTE AS INT), '/', CONVERT(NVARCHAR(20), DIFERENCA)) FROM @f);
    INSERT @r SELECT N'caixa: entradas e saídas desde o último fechamento', N'300.00/5300.00', (SELECT CONCAT(CONVERT(NVARCHAR(20), ENTRADAS), '/', CONVERT(NVARCHAR(20), SAIDAS)) FROM @f); DELETE @f;
    INSERT @f EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = @Fin, @IdConta = @CxA, @DtFechamento = @Hoje, @SaldoContado = -3990.00, @Motivo = N'Sobra de troco', @GerarAjuste = 1;
    INSERT @r SELECT N'caixa: ajuste sem a permissão recusado', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN AVISOS LIKE N'%AJUSTE_SEM_PERMISSAO%' THEN 1 ELSE 0 END) FROM @f); DELETE @f;
    INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
    SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM AND i.CODIGO = 'BANCO_CAIXA'
    INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'AJUSTE_CAIXA' WHERE u.ID_USUARIO = @Fin;
    INSERT @f EXEC BANCO.BANCO_Caixa_Fechar @IdUsuario = @Fin, @IdConta = @CxA, @DtFechamento = @Hoje, @SaldoContado = -3990.00, @Motivo = N'Sobra de troco', @GerarAjuste = 1;
    SELECT @FHoje = ID FROM @f;
    INSERT @r SELECT N'caixa: fechado com ajuste (movimento de 10,00)', N'1/10.00', CONCAT((SELECT CAST(SUCESSO AS INT) FROM @f), '/', (SELECT CONVERT(NVARCHAR(20), m.VALOR) FROM BANCO.Movimento m INNER JOIN @f x ON x.ID_MOVIMENTO_AJUSTE = m.ID_MOVIMENTO)); DELETE @f;
    INSERT @r SELECT N'caixa: saldo do sistema = contado depois do ajuste', N'-3990.00', (SELECT CONVERT(NVARCHAR(20), SALDO) FROM BANCO.fn_BANCO_Conta_Saldo(@CxA, @Hoje));
    INSERT @r SELECT N'caixa: motivo da diferença registrado', N'1', CAST((SELECT COUNT(*) FROM SIS.Aviso_Confirmado WHERE TABELA = N'BANCO.Caixa_Fechamento' AND ID_REGISTRO = @FHoje AND CODIGO_REGRA = 'DIFERENCA_CAIXA') AS NVARCHAR(5));

    INSERT @ra EXEC BANCO.BANCO_Caixa_Reabrir @IdUsuario = @Fin, @IdCaixaFechamento = @FHoje, @Motivo = N'Recebimento esquecido';
    INSERT @r SELECT N'reabrir sem a permissão REABRIR: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @ra); DELETE @ra;
    INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
    SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM AND i.CODIGO = 'BANCO_CAIXA'
    INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'REABRIR' WHERE u.ID_USUARIO = @Fin;
    INSERT @ra EXEC BANCO.BANCO_Caixa_Reabrir @IdUsuario = @Fin, @IdCaixaFechamento = @FOntem, @Motivo = N'Recebimento esquecido';
    INSERT @r SELECT N'reabrir o mais antigo antes do mais novo: recusado', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN MENSAGEM LIKE N'%mais novo%' THEN 1 ELSE 0 END) FROM @ra); DELETE @ra;
    INSERT @ra EXEC BANCO.BANCO_Caixa_Reabrir @IdUsuario = @Fin, @IdCaixaFechamento = @FHoje;
    INSERT @r SELECT N'reabrir sem motivo: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @ra); DELETE @ra;
    INSERT @ra EXEC BANCO.BANCO_Caixa_Reabrir @IdUsuario = @Fin, @IdCaixaFechamento = @FHoje, @Motivo = N'Recebimento esquecido', @SomenteConferir = 1;
    INSERT @r SELECT N'prévia da reabertura avisa o ajuste', N'1/10.00/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CONVERT(NVARCHAR(20), VALOR_AJUSTE), '/', CASE WHEN AVISOS LIKE N'%AJUSTE_DESFEITO%' THEN 1 ELSE 0 END) FROM @ra); DELETE @ra;
    INSERT @ra EXEC BANCO.BANCO_Caixa_Reabrir @IdUsuario = @Fin, @IdCaixaFechamento = @FHoje, @Motivo = N'Recebimento esquecido';
    INSERT @r SELECT N'reaberto', N'1/REABERTO', CONCAT((SELECT CAST(SUCESSO AS INT) FROM @ra), '/', (SELECT SITUACAO FROM BANCO.Caixa_Fechamento WHERE ID_CAIXA_FECHAMENTO = @FHoje)); DELETE @ra;
    INSERT @r SELECT N'reaberto: ajuste desfeito, saldo volta', N'-4000.00', (SELECT CONVERT(NVARCHAR(20), SALDO) FROM BANCO.fn_BANCO_Conta_Saldo(@CxA, @Hoje));
    INSERT @r SELECT N'reaberto: hoje aceita movimento de novo', N'', BANCO.fn_BANCO_Caixa_Recusa(@CxA, @Hoje);

    DECLARE @cx TABLE (ID_CAIXA_FECHAMENTO BIGINT, ID_CONTA INT, CONTA NVARCHAR(60), ID_EMPRESA INT, EMPRESA NVARCHAR(150), DT_FECHAMENTO DATE,
                       SALDO_SISTEMA DECIMAL(18,2), SALDO_CONTADO DECIMAL(18,2), DIFERENCA DECIMAL(18,2), MOTIVO_DIFERENCA NVARCHAR(400), OBSERVACAO NVARCHAR(400),
                       ID_MOVIMENTO_AJUSTE BIGINT, VALOR_AJUSTE DECIMAL(18,2), AJUSTE_DESFEITO BIT, SITUACAO VARCHAR(10), USUARIO_CRIACAO NVARCHAR(100),
                       DT_CRIACAO DATETIME2(0), DT_REABERTURA VARCHAR(19), USUARIO_REABERTURA NVARCHAR(100), MOTIVO_REABERTURA NVARCHAR(400), PODE_REABRIR BIT);
    INSERT @cx EXEC BANCO.BANCO_Caixa_Listar @IdUsuario = @Fin, @IdConta = @CxA;
    INSERT @r SELECT N'lista do caixa: 2 fechamentos, ontem pode reabrir', N'2/1/1', CONCAT((SELECT COUNT(*) FROM @cx), '/', (SELECT CAST(PODE_REABRIR AS INT) FROM @cx WHERE ID_CAIXA_FECHAMENTO = @FOntem),
           '/', (SELECT CAST(AJUSTE_DESFEITO AS INT) FROM @cx WHERE ID_CAIXA_FECHAMENTO = @FHoje));

    -- sem a ação INCLUIR
    DELETE pp FROM SIS.Perfil_Permissao pp
    INNER JOIN SIS.Usuario u ON u.ID_PERFIL = pp.ID_PERFIL AND u.ID_USUARIO = @Fin
    INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO
    INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM AND i.CODIGO = 'BANCO_TRANSFERENCIA'
    INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'INCLUIR';
    INSERT @t EXEC FIN.FIN_Transferencia_Gravar @IdUsuario = @Fin, @DtTransferencia = @Hoje, @IdContaOrigem = @CxA, @IdContaDestino = @CxB, @Valor = 10;
    INSERT @r SELECT N'sem a ação INCLUIR: recusado', N'0/1', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN MENSAGEM LIKE N'%permissão%' THEN 1 ELSE 0 END) FROM @t); DELETE @t;
END;
ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
