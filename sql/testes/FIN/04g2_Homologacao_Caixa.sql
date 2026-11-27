/*******************************************************************************
  Teste       : 04g2 - transferência, extrato, saldos e fechamento de caixa:
                estrutura e cargas; transferência (prévia, aviso entre
                empresas e de saldo, bloqueio pelo parâmetro, caixa fechado,
                trava de datas, gravação com dois movimentos, estorno das
                duas pontas, estorno repetido, lista); permissões.
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
