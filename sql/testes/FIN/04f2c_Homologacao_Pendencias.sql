/*******************************************************************************
  Teste       : 04f2c - pendências dos lançamentos (P27): estrutura e cargas,
                regras automáticas (parâmetros, só em aberto, data de corte),
                pendências manuais (gravar, regras, resolver, reabrir,
                desativar), bloqueio da baixa, tipos de pendência, filtro e
                colunas da lista, contadores do resumo e ficha; conferência de
                CPF/CNPJ em linha (CAD.fn_CAD_Documento_Checar).
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 26/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do MASTER
                (no banco sem empresa, os casos com dados passam direto).
  Observação  : não muda nada (tudo desfeito com ROLLBACK). Datas calculadas a
                partir de hoje, para o teste valer em qualquer dia.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(200), OBTIDO NVARCHAR(200));
DECLARE @g TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);
DECLARE @res TABLE (QTD_VENCIDAS INT, VALOR_VENCIDAS DECIMAL(18,2), QTD_HOJE INT, VALOR_HOJE DECIMAL(18,2), QTD_A_VENCER INT, VALOR_A_VENCER DECIMAL(18,2),
                    QTD_EM_ABERTO INT, VALOR_EM_ABERTO DECIMAL(18,2), DIAS_A_VENCER INT, POR_PAGINA INT, SITUACAO_INICIAL VARCHAR(12), VISAO_INICIAL VARCHAR(12),
                    QTD_COM_PENDENCIA INT, QTD_MINHAS_PENDENCIAS INT);
DECLARE @tp TABLE (ID_PENDENCIA_TIPO INT, CODIGO VARCHAR(20), DESCRICAO NVARCHAR(60), ORIENTACAO NVARCHAR(400), APLICA_A CHAR(1), BLOQUEIA_BAIXA BIT,
                   SISTEMA BIT, ORDEM INT, ATIVO BIT, QTD_ABERTAS INT);
DECLARE @pl TABLE (ID_LANCAMENTO_PENDENCIA BIGINT, ORIGEM VARCHAR(10), CODIGO VARCHAR(20), DESCRICAO NVARCHAR(400), ORIENTACAO NVARCHAR(400), SITUACAO VARCHAR(10),
                   BLOQUEIA_BAIXA BIT, ATRASADA BIT, ID_PENDENCIA_TIPO INT, ID_PARCELA BIGINT, PARCELA NVARCHAR(20), OBSERVACAO NVARCHAR(1000),
                   ID_USUARIO_RESPONSAVEL INT, RESPONSAVEL NVARCHAR(100), DT_PREVISAO DATE, DT_RESOLUCAO DATETIME2(0), USUARIO_RESOLUCAO NVARCHAR(100),
                   RESOLUCAO NVARCHAR(1000), DT_CRIACAO DATETIME2(0), USUARIO_CRIACAO NVARCHAR(100), PODE_ALTERAR BIT, PODE_REABRIR BIT);
DECLARE @Fin INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'teste.tela04a');
DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @Empresa INT, @Forn INT, @Cli INT, @L1 BIGINT, @L2 BIGINT, @P1 BIGINT, @P2 BIGINT, @IdNF INT, @IdConf INT, @Pend BIGINT, @Pend2 BIGINT, @IdTipo INT;

DROP TABLE IF EXISTS #lst;
DROP TABLE IF EXISTS #obt;
CREATE TABLE #lst (ID_LANCAMENTO NVARCHAR(MAX), C02 NVARCHAR(MAX), C03 NVARCHAR(MAX), C04 NVARCHAR(MAX), C05 NVARCHAR(MAX), C06 NVARCHAR(MAX), C07 NVARCHAR(MAX),
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
                   PENDENCIAS NVARCHAR(MAX), QTD_PENDENCIAS NVARCHAR(MAX), PODE_PENDENCIA NVARCHAR(MAX), BLOQUEIA_BAIXA NVARCHAR(MAX), MOTIVO_BLOQUEIO NVARCHAR(MAX));

-- estrutura e cargas
INSERT @r SELECT N'tabelas novas', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.tables WHERE object_id IN (OBJECT_ID('FIN.Pendencia_Tipo'), OBJECT_ID('FIN.Lancamento_Pendencia'));
INSERT @r SELECT N'funções novas', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.objects WHERE object_id IN
       (OBJECT_ID('FIN.fn_FIN_Lancamento_Pendencias'), OBJECT_ID('FIN.fn_FIN_Pendencia_Bloqueia'), OBJECT_ID('CAD.fn_CAD_Documento_Checar'));
INSERT @r SELECT N'procedures novas', N'6', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.procedures WHERE object_id IN
       (OBJECT_ID('FIN.FIN_Pendencia_Tipo_Listar'), OBJECT_ID('FIN.FIN_Pendencia_Tipo_Gravar'), OBJECT_ID('FIN.FIN_Lancamento_Pendencia_Listar'),
        OBJECT_ID('FIN.FIN_Lancamento_Pendencia_Gravar'), OBJECT_ID('FIN.FIN_Lancamento_Pendencia_Resolver'), OBJECT_ID('FIN.FIN_Lancamento_Pendencia_Reabrir'));
INSERT @r SELECT N'parâmetros FIN_PEND_* de nível 1', N'7', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro WHERE CHAVE LIKE 'FIN[_]PEND[_]%' AND NIVEL_MINIMO = 1;
INSERT @r SELECT N'tipo MIGRACAO do sistema', N'1/1', ISNULL((SELECT CONCAT(CAST(SISTEMA AS INT), '/', CAST(ATIVO AS INT)) FROM FIN.Pendencia_Tipo WHERE CODIGO = 'MIGRACAO'), N'-');
INSERT @r SELECT N'ação PENDENCIA nas telas de pagar e receber', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item_Acao ia
       INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
       WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND a.CODIGO = 'PENDENCIA';
INSERT @r SELECT N'tela FIN_PENDENCIA_TIPO', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Item WHERE CODIGO = 'FIN_PENDENCIA_TIPO';
INSERT @r SELECT N'pendências vão junto com o lançamento na lixeira', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Tabela_Config
       WHERE TABELA = N'FIN.Lancamento' AND TABELAS_FILHAS LIKE N'%FIN.Lancamento_Pendencia.ID_LANCAMENTO%';

-- conferência de CPF/CNPJ em linha
INSERT @r SELECT N'documento: CPF válido / CPF errado / iguais / CNPJ / CNPJ alfanumérico', N'1/0/0/1/1',
       CONCAT((SELECT CAST(VALIDO AS INT) FROM CAD.fn_CAD_Documento_Checar(N'529.982.247-25')), '/',
              (SELECT CAST(VALIDO AS INT) FROM CAD.fn_CAD_Documento_Checar(N'529.982.247-24')), '/',
              (SELECT CAST(VALIDO AS INT) FROM CAD.fn_CAD_Documento_Checar(N'111.111.111-11')), '/',
              (SELECT CAST(VALIDO AS INT) FROM CAD.fn_CAD_Documento_Checar(N'25.686.528/0001-97')), '/',
              (SELECT CAST(VALIDO AS INT) FROM CAD.fn_CAD_Documento_Checar(N'12.ABC.345/01DE-35')));
INSERT @r SELECT N'escalar continua igual', N'1/0', CONCAT(CAST(CAD.fn_CAD_Documento_Valido(N'25686528000197') AS INT), '/', CAST(CAD.fn_CAD_Documento_Valido(N'') AS INT));

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'BANCO', 'FIN') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER', 'FIN_PENDENCIA_TIPO') AND HABILITADO = 0;
UPDATE SIS.Parametro SET VALOR = v.VALOR
FROM SIS.Parametro p
INNER JOIN (VALUES ('FIN_PEND_SEM_CENTRO', N'S'), ('FIN_PEND_SEM_PLANO', N'S'), ('FIN_PEND_SEM_DOCUMENTO', N'P'), ('FIN_PEND_PAGAR_SEM_ANEXO_VALOR', N'1000.00'),
                   ('FIN_PEND_RECEBER_NAO_APTO', N'S'), ('FIN_PEND_VENCIDA_DIAS', N'30'), ('FIN_PEND_A_PARTIR_DE', N'2022-01-01')) v (CHAVE, VALOR) ON v.CHAVE = p.CHAVE;
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO
FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
WHERE u.ID_USUARIO = @Fin AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER', 'FIN_PENDENCIA_TIPO') AND a.CODIGO <> 'LANCAR_RETROATIVO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);

SET @Empresa = (SELECT TOP 1 e.ID_EMPRESA FROM CAD.Empresa e WHERE e.ATIVO = 1 ORDER BY e.ID_EMPRESA);
SET @IdNF    = (SELECT ID_PENDENCIA_TIPO FROM FIN.Pendencia_Tipo WHERE CODIGO = 'AGUARDA_NF');
SET @IdConf  = (SELECT ID_PENDENCIA_TIPO FROM FIN.Pendencia_Tipo WHERE CODIGO = 'CONFERIR_VALOR');

IF @Empresa IS NOT NULL AND @Fin IS NOT NULL
BEGIN
    IF @IdNF IS NULL
    BEGIN
        INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, APLICA_A, BLOQUEIA_BAIXA) VALUES ('AGUARDA_NF', N'Aguardando nota fiscal', 'P', 1);
        SET @IdNF = SCOPE_IDENTITY();
    END;
    IF @IdConf IS NULL
    BEGIN
        INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, APLICA_A, BLOQUEIA_BAIXA) VALUES ('CONFERIR_VALOR', N'Conferir valor', 'A', 0);
        SET @IdConf = SCOPE_IDENTITY();
    END;

    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, FORNECEDOR, ATIVO) VALUES ('J', N'Fornecedor Teste 04f2c', 1, 1);
    SET @Forn = SCOPE_IDENTITY();
    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, CLIENTE, ATIVO) VALUES ('F', N'Cliente Teste 04f2c', 1, 1);
    SET @Cli = SCOPE_IDENTITY();

    -- L1: a pagar de R$ 5.000, sem centro, sem conta, sem documento, sem anexo, parcela vencida há 40 dias
    INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, ID_PESSOA, DT_EMISSAO, DT_COMPETENCIA, VALOR_TOTAL, HISTORICO)
    VALUES ('P', @Empresa, @Forn, DATEADD(DAY, -45, @Hoje), DATEFROMPARTS(YEAR(DATEADD(DAY, -45, @Hoje)), MONTH(DATEADD(DAY, -45, @Hoje)), 1), 5000.00, N'Teste 04f2c pagar');
    SET @L1 = SCOPE_IDENTITY();
    INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR) VALUES (@L1, 1, 1, DATEADD(DAY, -40, @Hoje), 5000.00);
    SET @P1 = SCOPE_IDENTITY();
    -- L2: a receber de cliente sem CPF nem endereço, sem documento
    INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, ID_PESSOA, DT_EMISSAO, DT_COMPETENCIA, VALOR_TOTAL, HISTORICO)
    VALUES ('R', @Empresa, @Cli, @Hoje, DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1), 300.00, N'Teste 04f2c receber');
    SET @L2 = SCOPE_IDENTITY();
    INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR) VALUES (@L2, 1, 1, DATEADD(DAY, 10, @Hoje), 300.00);
    SET @P2 = SCOPE_IDENTITY();

    -- automáticas
    INSERT @r SELECT N'L1: automáticas', N'SEM_ANEXO,SEM_CENTRO,SEM_DOCUMENTO,SEM_PLANO,VENCIDA',
           ISNULL((SELECT STRING_AGG(CODIGO, ',') WITHIN GROUP (ORDER BY CODIGO) FROM FIN.fn_FIN_Lancamento_Pendencias(@L1)), N'-');
    INSERT @r SELECT N'L1: vencida aponta a parcela', N'1', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM FIN.fn_FIN_Lancamento_Pendencias(@L1) WHERE CODIGO = 'VENCIDA' AND ID_PARCELA = @P1);
    INSERT @r SELECT N'L2: automáticas (documento só no a pagar)', N'NAO_APTO,SEM_CENTRO,SEM_PLANO', ISNULL((SELECT STRING_AGG(CODIGO, ',') WITHIN GROUP (ORDER BY CODIGO) FROM FIN.fn_FIN_Lancamento_Pendencias(@L2)), N'-');
    UPDATE SIS.Parametro SET VALOR = N'A' WHERE CHAVE = 'FIN_PEND_SEM_DOCUMENTO';
    INSERT @r SELECT N'L2: documento em ambos', N'NAO_APTO,SEM_CENTRO,SEM_DOCUMENTO,SEM_PLANO', ISNULL((SELECT STRING_AGG(CODIGO, ',') WITHIN GROUP (ORDER BY CODIGO) FROM FIN.fn_FIN_Lancamento_Pendencias(@L2)), N'-');
    UPDATE SIS.Parametro SET VALOR = N'N' WHERE CHAVE IN ('FIN_PEND_SEM_DOCUMENTO', 'FIN_PEND_SEM_CENTRO');
    UPDATE SIS.Parametro SET VALOR = N'0' WHERE CHAVE IN ('FIN_PEND_VENCIDA_DIAS', 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR');
    INSERT @r SELECT N'L1: regras desligadas por parâmetro', N'SEM_PLANO', ISNULL((SELECT STRING_AGG(CODIGO, ',') FROM FIN.fn_FIN_Lancamento_Pendencias(@L1)), N'-');
    UPDATE SIS.Parametro SET VALOR = N'S' WHERE CHAVE = 'FIN_PEND_SEM_CENTRO';
    UPDATE SIS.Parametro SET VALOR = N'30' WHERE CHAVE = 'FIN_PEND_VENCIDA_DIAS';
    UPDATE SIS.Parametro SET VALOR = N'6000' WHERE CHAVE = 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR';
    INSERT @r SELECT N'L1: valor abaixo do limite não pede anexo', N'SEM_CENTRO,SEM_PLANO,VENCIDA', ISNULL((SELECT STRING_AGG(CODIGO, ',') WITHIN GROUP (ORDER BY CODIGO) FROM FIN.fn_FIN_Lancamento_Pendencias(@L1)), N'-');
    UPDATE SIS.Parametro SET VALOR = CONVERT(NVARCHAR(10), DATEADD(DAY, -10, @Hoje), 23) WHERE CHAVE = 'FIN_PEND_A_PARTIR_DE';
    INSERT @r SELECT N'L1: emitido antes da data de corte', N'0', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM FIN.fn_FIN_Lancamento_Pendencias(@L1));
    UPDATE SIS.Parametro SET VALOR = N'2022-01-01' WHERE CHAVE = 'FIN_PEND_A_PARTIR_DE';
    UPDATE FIN.Parcela SET SITUACAO = 'PAGA' WHERE ID_PARCELA = @P1;
    INSERT @r SELECT N'L1: lançamento pago não tem automáticas', N'0', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM FIN.fn_FIN_Lancamento_Pendencias(@L1));
    UPDATE FIN.Parcela SET SITUACAO = 'ABERTA' WHERE ID_PARCELA = @P1;

    -- manuais
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdPendenciaTipo = @IdNF, @Observacao = N'NF 123',
         @IdUsuarioResponsavel = @Fin, @DtPrevisao = '2000-01-01';
    SET @Pend = (SELECT ID FROM @g WHERE SUCESSO = 1);
    INSERT @r SELECT N'grava pendência manual', N'1', ISNULL((SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g), N'-'); DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdPendenciaTipo = @IdNF;
    INSERT @r SELECT N'mesmo tipo aberto recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamento = @L2, @IdPendenciaTipo = @IdNF;
    INSERT @r SELECT N'tipo só do a pagar recusado no a receber', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdPendenciaTipo = @IdConf, @IdParcela = @P2;
    INSERT @r SELECT N'parcela de outro lançamento recusada', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdPendenciaTipo = @IdConf, @IdUsuarioResponsavel = -5;
    INSERT @r SELECT N'responsável inexistente recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamento = @L2, @IdPendenciaTipo = @IdConf, @IdParcela = @P2;
    SET @Pend2 = (SELECT ID FROM @g WHERE SUCESSO = 1);
    INSERT @r SELECT N'pendência da parcela no a receber', N'1', ISNULL((SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g), N'-'); DELETE @g;

    INSERT @r SELECT N'L1: manual atrasada e bloqueando', N'1/1', ISNULL((SELECT CONCAT(CAST(ATRASADA AS INT), '/', CAST(BLOQUEIA_BAIXA AS INT)) FROM FIN.fn_FIN_Lancamento_Pendencias(@L1) WHERE ORIGEM = 'MANUAL'), N'-');
    INSERT @r SELECT N'bloqueio da baixa L1 / L2', N'1/0', CONCAT((SELECT CAST(BLOQUEIA AS INT) FROM FIN.fn_FIN_Pendencia_Bloqueia(@L1, @P1)), '/', (SELECT CAST(BLOQUEIA AS INT) FROM FIN.fn_FIN_Pendencia_Bloqueia(@L2, @P2)));

    -- quadro da ficha, lista e resumo
    INSERT @pl EXEC FIN.FIN_Lancamento_Pendencia_Listar @IdUsuario = @Fin, @IdLancamento = @L1;
    INSERT @r SELECT N'quadro: manual primeiro, total, pode alterar', N'MANUAL/4/1', (SELECT CONCAT((SELECT TOP 1 ORIGEM FROM @pl), '/', COUNT(*), '/', MAX(CAST(PODE_ALTERAR AS INT))) FROM @pl);
    DELETE @pl;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Pendencia = 'COM';
    INSERT @r SELECT N'lista: filtro "com pendência" e colunas', N'1/4/1/1', (SELECT CONCAT(COUNT(*), '/', MAX(QTD_PENDENCIAS), '/', MAX(PENDENCIA_BLOQUEIA), '/', MAX(PENDENCIA_ATRASADA)) FROM #lst);
    DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Pendencia = 'MINHAS';
    INSERT @r SELECT N'lista: minhas pendências', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst; DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @PendenciaCodigo = 'SEM_DOCUMENTO';
    INSERT @r SELECT N'lista: regra desligada não acha nada', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst; DELETE #lst;
    INSERT #lst EXEC FIN.FIN_Lancamento_Listar @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn, @Pendencia = 'BLOQUEIA';
    INSERT @r SELECT N'lista: bloqueando a baixa', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM #lst; DELETE #lst;
    INSERT @res EXEC FIN.FIN_Lancamento_Resumo @IdUsuario = @Fin, @Tipo = 'P', @IdPessoa = @Forn;
    INSERT @r SELECT N'resumo: com pendência / minhas', N'1/1', (SELECT CONCAT(QTD_COM_PENDENCIA, '/', QTD_MINHAS_PENDENCIAS) FROM @res); DELETE @res;

    -- resolver, reabrir, desativar
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Resolver @IdUsuario = @Fin, @IdLancamentoPendencia = @Pend, @Resolucao = N'';
    INSERT @r SELECT N'resolver sem nota recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Resolver @IdUsuario = @Fin, @IdLancamentoPendencia = @Pend, @Resolucao = N'NF anexada';
    INSERT @r SELECT N'resolve com nota; baixa liberada', N'1/0', CONCAT((SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g), '/', (SELECT CAST(BLOQUEIA AS INT) FROM FIN.fn_FIN_Pendencia_Bloqueia(@L1, NULL))); DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamentoPendencia = @Pend, @IdLancamento = @L1, @IdPendenciaTipo = @IdNF, @Observacao = N'x';
    INSERT @r SELECT N'pendência resolvida não é alterada', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @pl EXEC FIN.FIN_Lancamento_Pendencia_Listar @IdUsuario = @Fin, @IdLancamento = @L1;
    INSERT @r SELECT N'quadro mostra a resolvida (pode reabrir)', N'RESOLVIDA/1', ISNULL((SELECT CONCAT(SITUACAO, '/', CAST(PODE_REABRIR AS INT)) FROM @pl WHERE ID_LANCAMENTO_PENDENCIA = @Pend), N'-'); DELETE @pl;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Reabrir @IdUsuario = @Fin, @IdLancamentoPendencia = @Pend;
    INSERT @r SELECT N'reabre; bloqueia de novo', N'1/1', CONCAT((SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g), '/', (SELECT CAST(BLOQUEIA AS INT) FROM FIN.fn_FIN_Pendencia_Bloqueia(@L1, NULL))); DELETE @g;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamentoPendencia = @Pend, @IdLancamento = @L1, @IdPendenciaTipo = @IdNF, @Ativo = 0;
    INSERT @r SELECT N'desativa a lançada por engano', N'1/0', CONCAT((SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g), '/', (SELECT COUNT(*) FROM FIN.fn_FIN_Lancamento_Pendencias(@L1) WHERE ORIGEM = 'MANUAL')); DELETE @g;

    -- ficha
    INSERT #obt EXEC FIN.FIN_Lancamento_Obter @IdUsuario = @Fin, @IdLancamento = @L2;
    INSERT @r SELECT N'ficha: pendências, pode lançar, bloqueio', N'4/4/1/0',
           (SELECT CONCAT((SELECT COUNT(*) FROM OPENJSON(PENDENCIAS)), '/', QTD_PENDENCIAS, '/', PODE_PENDENCIA, '/', BLOQUEIA_BAIXA) FROM #obt);
    DELETE #obt;

    -- tipos de pendência
    INSERT @tp EXEC FIN.FIN_Pendencia_Tipo_Listar @IdUsuario = @Fin, @Tipo = 'R';
    INSERT @r SELECT N'tipos do a receber não trazem o só do a pagar', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @tp WHERE APLICA_A = 'P'; DELETE @tp;
    INSERT @g EXEC FIN.FIN_Pendencia_Tipo_Gravar @IdUsuario = @Fin, @Codigo = 'teste_04f2c', @Descricao = N'Teste 04f2c', @AplicaA = 'R', @BloqueiaBaixa = 1;
    SET @IdTipo = (SELECT ID FROM @g WHERE SUCESSO = 1);
    INSERT @r SELECT N'inclui tipo (código em maiúsculas)', N'1/TESTE_04F2C', CONCAT((SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g), '/', (SELECT CODIGO FROM FIN.Pendencia_Tipo WHERE ID_PENDENCIA_TIPO = @IdTipo)); DELETE @g;
    INSERT @g EXEC FIN.FIN_Pendencia_Tipo_Gravar @IdUsuario = @Fin, @Codigo = 'TESTE_04F2C', @Descricao = N'Outro';
    INSERT @r SELECT N'código repetido recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @g EXEC FIN.FIN_Pendencia_Tipo_Gravar @IdUsuario = @Fin, @Codigo = 'COM ESPACO', @Descricao = N'X';
    INSERT @r SELECT N'código inválido recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    SET @IdTipo = (SELECT ID_PENDENCIA_TIPO FROM FIN.Pendencia_Tipo WHERE CODIGO = 'MIGRACAO');
    INSERT @g EXEC FIN.FIN_Pendencia_Tipo_Gravar @IdUsuario = @Fin, @IdPendenciaTipo = @IdTipo, @Codigo = 'MIGRACAO_X', @Descricao = N'Veio da migração – conferir';
    INSERT @r SELECT N'tipo do sistema: código não muda', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @g EXEC FIN.FIN_Pendencia_Tipo_Gravar @IdUsuario = @Fin, @IdPendenciaTipo = @IdTipo, @Codigo = 'MIGRACAO', @Descricao = N'Veio da migração – conferir', @Ativo = 0;
    INSERT @r SELECT N'tipo do sistema: não desativa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @g EXEC FIN.FIN_Pendencia_Tipo_Gravar @IdUsuario = @Fin, @IdPendenciaTipo = @IdConf, @Codigo = 'CONFERIR_VALOR', @Descricao = N'Conferir valor', @AplicaA = 'A', @Ativo = 0;
    INSERT @r SELECT N'desativa tipo em uso (avisa)', N'1/1', CONCAT((SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g), '/', (SELECT CASE WHEN MENSAGEM LIKE N'%continuam%' THEN 1 ELSE 0 END FROM @g)); DELETE @g;
    INSERT @r SELECT N'pendência de tipo desativado continua valendo', N'1', (SELECT CAST(COUNT(*) AS NVARCHAR(5)) FROM FIN.fn_FIN_Lancamento_Pendencias(@L2) WHERE ORIGEM = 'MANUAL');
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Gravar @IdUsuario = @Fin, @IdLancamento = @L1, @IdPendenciaTipo = @IdConf;
    INSERT @r SELECT N'tipo desativado não entra em pendência nova', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;

    -- permissão: sem a ação PENDENCIA
    DELETE pp FROM SIS.Perfil_Permissao pp
    INNER JOIN SIS.Usuario u ON u.ID_PERFIL = pp.ID_PERFIL AND u.ID_USUARIO = @Fin
    INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO
    INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'PENDENCIA';
    DELETE up FROM SIS.Usuario_Permissao up
    INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = up.ID_ITEM_ACAO
    INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'PENDENCIA'
    WHERE up.ID_USUARIO = @Fin;
    INSERT @g EXEC FIN.FIN_Lancamento_Pendencia_Resolver @IdUsuario = @Fin, @IdLancamentoPendencia = @Pend2, @Resolucao = N'Conferido';
    INSERT @r SELECT N'sem a ação PENDENCIA: recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
END;
ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
DROP TABLE IF EXISTS #lst;
DROP TABLE IF EXISTS #obt;
