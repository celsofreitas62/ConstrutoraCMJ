/*******************************************************************************
  Teste       : 04h - agenda financeira da tela inicial e preferências do
                usuário (P03, P04, P06; etapa 04h1): estrutura, permissões,
                período, totais conferidos contra uma conta feita à parte
                (em aberto e com o realizado), calendário por dia e por grupo
                de meses batendo com o resumo, saldo previsto, lista e "Em
                atraso", P04 (sem VER_TOTAIS não vem valor somado) e
                preferências (gravar, recusar, voltar ao padrão).
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 27/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do
                MASTER (no banco sem movimento, as contas dão zero e batem do
                mesmo jeito). O que grava fica dentro de transação desfeita.
                v1.1 (27/11/2026, 04h2): resumo com PERIODO_MAX_DIAS e
                ATUALIZAR_MINUTOS, conferidos contra os parâmetros.
*******************************************************************************/
SET NOCOUNT ON;
SET XACT_ABORT OFF;
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(160), OBTIDO NVARCHAR(160));
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @De DATE = DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1);
DECLARE @Ate DATE = EOMONTH(@Hoje);
DECLARE @Ate6 DATE = EOMONTH(DATEADD(MONTH, 5, @De));
DECLARE @Erro NVARCHAR(400), @Esp NVARCHAR(160), @Obt NVARCHAR(160);

DECLARE @res TABLE (DE DATE, ATE DATE, HOJE DATE, PERIODO_MAX_DIAS INT, ATUALIZAR_MINUTOS INT, VER_PAGAR BIT, VER_RECEBER BIT, VER_TOTAIS BIT, PODE_EXPORTAR BIT, PODE_INCLUIR_PAGAR BIT,
                    PODE_INCLUIR_RECEBER BIT, PODE_EXTRATO BIT, PODE_CAIXA BIT, PODE_TRANSFERIR BIT, INCLUI_REALIZADO BIT, SALDO_ACUMULADO BIT,
                    QTD_PAGAR INT, QTD_RECEBER INT, QTD_PREVISAO INT, TOTAL_D DECIMAL(18,2), TOTAL_C DECIMAL(18,2), SALDO DECIMAL(18,2),
                    REALIZADO_D DECIMAL(18,2), REALIZADO_C DECIMAL(18,2), ATRASO_QTD_PAGAR INT, ATRASO_QTD_RECEBER INT, ATRASO_D DECIMAL(18,2),
                    ATRASO_C DECIMAL(18,2), SALDO_CONTAS_HOJE DECIMAL(18,2), SALDO_PREVISTO_FIM DECIMAL(18,2));
DECLARE @per TABLE (ORDEM INT, INICIO DATE, FIM DATE, TEM_HOJE BIT, QTD_PAGAR INT, QTD_RECEBER INT, QTD_VENCIDAS INT, QTD_PREVISAO INT,
                    TOTAL_D DECIMAL(18,2), TOTAL_C DECIMAL(18,2), SALDO DECIMAL(18,2), SALDO_PREVISTO DECIMAL(18,2));
DECLARE @lis TABLE (ID_PARCELA BIGINT, ID_LANCAMENTO BIGINT, TIPO CHAR(1), DT_VENCIMENTO DATE, NUMERO SMALLINT, QTD_PARCELAS SMALLINT, SITUACAO VARCHAR(10),
                    PREVISAO BIT, PROJECAO BIT, VENCIDA BIT, DIAS_ATRASO INT, VALOR DECIMAL(18,2), SALDO_ABERTO DECIMAL(18,2), VALOR_REALIZADO DECIMAL(18,2),
                    VALOR_AGENDA DECIMAL(18,2), ID_EMPRESA INT, EMPRESA_NOME NVARCHAR(200), ID_PESSOA INT, PESSOA_NOME NVARCHAR(200), HISTORICO NVARCHAR(200),
                    DOCUMENTO NVARCHAR(40), CENTRO_CODIGO NVARCHAR(20), CENTRO_DESCRICAO NVARCHAR(200), TOTAL_LINHAS INT, PAGINA INT, POR_PAGINA INT);
DECLARE @pref TABLE (CODIGO VARCHAR(40), NOME NVARCHAR(80), DESCRICAO NVARCHAR(400), GRUPO NVARCHAR(60), TIPO VARCHAR(10), OPCOES NVARCHAR(400),
                     VALOR_MINIMO INT, VALOR_MAXIMO INT, VALOR_PADRAO NVARCHAR(400), VALOR_USUARIO NVARCHAR(400), VALOR NVARCHAR(400), PERSONALIZADA BIT, ORDEM SMALLINT);
DECLARE @grv TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), QTD_GRAVADAS INT);

-- ---------- estrutura ----------
INSERT @r SELECT N'objetos novos (2 tabelas, 2 functions, 5 procedures)', N'9', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.objects
WHERE object_id IN (OBJECT_ID('SIS.Preferencia'), OBJECT_ID('SIS.Usuario_Preferencia'), OBJECT_ID('SIS.fn_SIS_Preferencia_Valor'), OBJECT_ID('FIN.fn_FIN_Agenda_Base'),
                    OBJECT_ID('SIS.SIS_Preferencia_Listar'), OBJECT_ID('SIS.SIS_Preferencia_Gravar'), OBJECT_ID('FIN.FIN_Agenda_Resumo'),
                    OBJECT_ID('FIN.FIN_Agenda_Periodos'), OBJECT_ID('FIN.FIN_Agenda_Listar'));
INSERT @r SELECT N'tela FIN_AGENDA com VER, EXPORTAR e VER_TOTAIS', N'EXPORTAR,VER,VER_TOTAIS',
       ISNULL(STRING_AGG(a.CODIGO, ',') WITHIN GROUP (ORDER BY a.CODIGO), N'') FROM SIS.Item i JOIN SIS.Item_Acao ia ON ia.ID_ITEM = i.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
WHERE i.CODIGO = 'FIN_AGENDA';
INSERT @r SELECT N'catálogo de preferências (6, com parâmetro)', N'6', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Preferencia p JOIN SIS.Parametro pa ON pa.CHAVE = p.CHAVE_PARAMETRO WHERE p.ATIVO = 1;
INSERT @r SELECT N'VER_TOTAIS não dada a perfil nenhum', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Perfil_Permissao pp JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = pp.ID_ITEM_ACAO
JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM AND i.CODIGO = 'FIN_AGENDA' JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'VER_TOTAIS';

-- ---------- permissão e período ----------
BEGIN TRY EXEC FIN.FIN_Agenda_Resumo @IdUsuario = -1, @De = @De, @Ate = @Ate; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = CAST(ERROR_NUMBER() AS NVARCHAR(10)); END CATCH;
INSERT @r VALUES (N'resumo sem permissão: recusa', N'50001', @Erro);
BEGIN TRY EXEC FIN.FIN_Agenda_Periodos @IdUsuario = -1, @De = @De, @Ate = @Ate; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = CAST(ERROR_NUMBER() AS NVARCHAR(10)); END CATCH;
INSERT @r VALUES (N'calendário sem permissão: recusa', N'50001', @Erro);
BEGIN TRY EXEC FIN.FIN_Agenda_Listar @IdUsuario = -1, @De = @De, @Ate = @Ate; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = CAST(ERROR_NUMBER() AS NVARCHAR(10)); END CATCH;
INSERT @r VALUES (N'lista sem permissão: recusa', N'50001', @Erro);
BEGIN TRY EXEC FIN.FIN_Agenda_Resumo @IdUsuario = @Celso, @De = @Ate, @Ate = @De; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = ERROR_MESSAGE(); END CATCH;
INSERT @r VALUES (N'data final antes da inicial: recusa', N'A data final não pode ser antes da inicial.', @Erro);
BEGIN TRY EXEC FIN.FIN_Agenda_Periodos @IdUsuario = @Celso, @De = '2000-01-01', @Ate = '2030-12-31'; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = ERROR_MESSAGE(); END CATCH;
INSERT @r VALUES (N'período longo demais: recusa', N'Período longo demais para a agenda. Escolha um período menor.', @Erro);
BEGIN TRY EXEC FIN.FIN_Agenda_Periodos @IdUsuario = @Celso, @De = @De, @Ate = @Ate, @Agrupamento = 'SEMANA'; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = ERROR_MESSAGE(); END CATCH;
INSERT @r VALUES (N'agrupamento inválido: recusa', N'Agrupamento inválido.', @Erro);

-- ---------- resumo do mês contra a conta feita à parte ----------
INSERT @res EXEC FIN.FIN_Agenda_Resumo @IdUsuario = @Celso, @De = @De, @Ate = @Ate, @IncluiRealizado = 0, @SaldoAcumulado = 1;
SELECT @Esp = CONCAT(ISNULL(SUM(CASE WHEN l.TIPO = 'P' THEN 1 ELSE 0 END), 0), '/', ISNULL(SUM(CASE WHEN l.TIPO = 'R' THEN 1 ELSE 0 END), 0), '/',
                     CAST(ISNULL(SUM(CASE WHEN l.TIPO = 'P' THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2)), '/', CAST(ISNULL(SUM(CASE WHEN l.TIPO = 'R' THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2)))
FROM FIN.Parcela p JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
WHERE p.DT_VENCIMENTO BETWEEN @De AND @Ate AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.SALDO <> 0 AND l.DT_EXCLUSAO IS NULL AND l.SITUACAO = 'ATIVO';
SELECT @Obt = CONCAT(QTD_PAGAR, '/', QTD_RECEBER, '/', TOTAL_D, '/', TOTAL_C) FROM @res;
INSERT @r VALUES (N'mês: quantidades e D/C em aberto', @Esp, @Obt);
INSERT @r SELECT N'resumo: período máximo e atualizar sozinha pelos parâmetros',
       CONCAT(ISNULL(SIS.fn_SIS_Parametro_Inteiro('AGENDA_PERIODO_MAX_DIAS'), 3700), '/', ISNULL(SIS.fn_SIS_Parametro_Inteiro('AGENDA_ATUALIZAR_MIN'), 5)),
       CONCAT(PERIODO_MAX_DIAS, '/', ATUALIZAR_MINUTOS) FROM @res;
INSERT @r SELECT N'mês: saldo = C - D', CAST(TOTAL_C - TOTAL_D AS NVARCHAR(30)), CAST(SALDO AS NVARCHAR(30)) FROM @res;

SELECT @Esp = CONCAT(ISNULL(SUM(CASE WHEN l.TIPO = 'P' THEN 1 ELSE 0 END), 0), '/', ISNULL(SUM(CASE WHEN l.TIPO = 'R' THEN 1 ELSE 0 END), 0), '/',
                     CAST(ISNULL(SUM(CASE WHEN l.TIPO = 'P' THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2)), '/', CAST(ISNULL(SUM(CASE WHEN l.TIPO = 'R' THEN p.SALDO ELSE 0 END), 0) AS DECIMAL(18,2)))
FROM FIN.Parcela p JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
WHERE p.DT_VENCIMENTO < @Hoje AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.SALDO <> 0 AND l.DT_EXCLUSAO IS NULL AND l.SITUACAO = 'ATIVO';
SELECT @Obt = CONCAT(ATRASO_QTD_PAGAR, '/', ATRASO_QTD_RECEBER, '/', ATRASO_D, '/', ATRASO_C) FROM @res;
INSERT @r VALUES (N'em atraso: quantidades e valores', @Esp, @Obt);

-- ---------- calendário por dia bate com o resumo ----------
INSERT @per EXEC FIN.FIN_Agenda_Periodos @IdUsuario = @Celso, @De = @De, @Ate = @Ate, @Agrupamento = 'DIA', @IncluiRealizado = 0, @SaldoAcumulado = 1;
SELECT @Esp = CONCAT(DAY(@Ate), '/', r.QTD_PAGAR, '/', r.QTD_RECEBER, '/', r.TOTAL_D, '/', r.TOTAL_C) FROM @res r;
SELECT @Obt = CONCAT(COUNT(*), '/', SUM(QTD_PAGAR), '/', SUM(QTD_RECEBER), '/', SUM(TOTAL_D), '/', SUM(TOTAL_C)) FROM @per;
INSERT @r VALUES (N'calendário por dia: todos os dias e soma = resumo', @Esp, @Obt);
INSERT @r SELECT N'calendário: só um dia marcado como hoje', N'1', CAST(SUM(CAST(TEM_HOJE AS INT)) AS NVARCHAR(5)) FROM @per;
INSERT @r SELECT N'saldo previsto: nulo antes de hoje', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @per WHERE FIM < @Hoje AND SALDO_PREVISTO IS NOT NULL;
SELECT @Esp = CAST(SALDO_PREVISTO_FIM AS NVARCHAR(30)) FROM @res;
SELECT @Obt = CAST(SALDO_PREVISTO AS NVARCHAR(30)) FROM @per WHERE FIM = @Ate;
INSERT @r VALUES (N'saldo previsto do último dia = do resumo', @Esp, @Obt);
SELECT @Esp = CONCAT(r.SALDO_CONTAS_HOJE + ISNULL((SELECT SUM(CASE WHEN l.TIPO = 'R' THEN p.SALDO ELSE -p.SALDO END) FROM FIN.Parcela p JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
                                                    WHERE p.DT_VENCIMENTO = @Hoje AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND l.DT_EXCLUSAO IS NULL AND l.SITUACAO = 'ATIVO'), 0), '') FROM @res r;
SELECT @Obt = CAST(SALDO_PREVISTO AS NVARCHAR(30)) FROM @per WHERE TEM_HOJE = 1;
INSERT @r VALUES (N'saldo previsto de hoje = contas + o que vence hoje', @Esp, @Obt);
DELETE @per; DELETE @res;

-- ---------- calendário por trimestre bate com o resumo dos 6 meses ----------
INSERT @res EXEC FIN.FIN_Agenda_Resumo @IdUsuario = @Celso, @De = @De, @Ate = @Ate6, @IncluiRealizado = 0, @SaldoAcumulado = 1;
INSERT @per EXEC FIN.FIN_Agenda_Periodos @IdUsuario = @Celso, @De = @De, @Ate = @Ate6, @Agrupamento = 'MESES', @MesesGrupo = 3, @IncluiRealizado = 0, @SaldoAcumulado = 1;
SELECT @Esp = CONCAT('2/', r.TOTAL_D, '/', r.TOTAL_C, '/', r.SALDO_PREVISTO_FIM) FROM @res r;
SELECT @Obt = CONCAT(COUNT(*), '/', SUM(TOTAL_D), '/', SUM(TOTAL_C), '/', MAX(CASE WHEN FIM = @Ate6 THEN SALDO_PREVISTO END)) FROM @per;
INSERT @r VALUES (N'trimestres: 2 quadros, soma e saldo previsto = resumo', @Esp, @Obt);
INSERT @r SELECT N'trimestres: quadros sem buraco', CONCAT(@De, '/', EOMONTH(DATEADD(MONTH, 2, @De)), '/', DATEADD(MONTH, 3, @De), '/', @Ate6),
       CONCAT(MIN(CASE WHEN ORDEM = 1 THEN INICIO END), '/', MIN(CASE WHEN ORDEM = 1 THEN FIM END), '/', MIN(CASE WHEN ORDEM = 2 THEN INICIO END), '/', MIN(CASE WHEN ORDEM = 2 THEN FIM END)) FROM @per;
DELETE @per; DELETE @res;

-- ---------- com o realizado ----------
INSERT @res EXEC FIN.FIN_Agenda_Resumo @IdUsuario = @Celso, @De = @De, @Ate = @Ate, @IncluiRealizado = 1, @SaldoAcumulado = 0;
SELECT @Esp = CONCAT(CAST(ISNULL(SUM(CASE WHEN l.TIPO = 'P' THEN CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') THEN p.SALDO ELSE 0 END + p.VALOR_BAIXADO ELSE 0 END), 0) AS DECIMAL(18,2)), '/',
                     CAST(ISNULL(SUM(CASE WHEN l.TIPO = 'P' THEN p.VALOR_BAIXADO ELSE 0 END), 0) AS DECIMAL(18,2)), '/',
                     CAST(ISNULL(SUM(CASE WHEN l.TIPO = 'R' THEN CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') THEN p.SALDO ELSE 0 END + p.VALOR_BAIXADO ELSE 0 END), 0) AS DECIMAL(18,2)))
FROM FIN.Parcela p JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
WHERE p.DT_VENCIMENTO BETWEEN @De AND @Ate AND p.SITUACAO IN ('ABERTA', 'PARCIAL', 'PAGA') AND l.DT_EXCLUSAO IS NULL AND l.SITUACAO = 'ATIVO';
SELECT @Obt = CONCAT(TOTAL_D, '/', REALIZADO_D, '/', TOTAL_C) FROM @res;
INSERT @r VALUES (N'com o realizado: D, realizado D e C', @Esp, @Obt);
INSERT @r SELECT N'opção do saldo desligada: sem saldo das contas', N'0/-', CONCAT(CAST(SALDO_ACUMULADO AS INT), '/', ISNULL(CAST(SALDO_CONTAS_HOJE AS NVARCHAR(30)), N'-')) FROM @res;
DELETE @res;

-- ---------- lista ----------
INSERT @res EXEC FIN.FIN_Agenda_Resumo @IdUsuario = @Celso, @De = @De, @Ate = @Ate, @IncluiRealizado = 0, @SaldoAcumulado = 0;
INSERT @lis EXEC FIN.FIN_Agenda_Listar @IdUsuario = @Celso, @De = @De, @Ate = @Ate, @IncluiRealizado = 0, @PorPagina = 1000;
SELECT @Esp = CONCAT(r.QTD_PAGAR + r.QTD_RECEBER, '/', r.TOTAL_D, '/', r.TOTAL_C) FROM @res r;
SELECT @Obt = CONCAT(ISNULL(MAX(TOTAL_LINHAS), 0), '/', CAST(ISNULL(SUM(CASE WHEN TIPO = 'P' THEN VALOR_AGENDA ELSE 0 END), 0) AS DECIMAL(18,2)), '/', CAST(ISNULL(SUM(CASE WHEN TIPO = 'R' THEN VALOR_AGENDA ELSE 0 END), 0) AS DECIMAL(18,2))) FROM @lis;
INSERT @r VALUES (N'lista do mês = resumo (linhas e valores)', @Esp, @Obt);
DELETE @lis;
INSERT @lis EXEC FIN.FIN_Agenda_Listar @IdUsuario = @Celso, @De = NULL, @Ate = NULL, @SoAtraso = 1, @PorPagina = 10;
SELECT @Esp = CONCAT(r.ATRASO_QTD_PAGAR + r.ATRASO_QTD_RECEBER, '/0') FROM @res r;
SELECT @Obt = CONCAT(ISNULL(MAX(TOTAL_LINHAS), 0), '/', ISNULL(SUM(CASE WHEN VENCIDA = 0 THEN 1 ELSE 0 END), 0)) FROM @lis;
INSERT @r VALUES (N'"Em atraso": linhas = quadro e todas vencidas', @Esp, @Obt);
DELETE @lis; DELETE @res;

-- ---------- P04 e tipos que o usuário vê (dentro de transação desfeita) ----------
DECLARE @Fin INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'teste.tela04a');
IF @Fin IS NULL
    INSERT @r VALUES (N'P04: sem VER_TOTAIS, sem valores somados', N'-', N'-'), (N'P04: só a pagar (sem ver a receber)', N'-', N'-');
ELSE
BEGIN
    BEGIN TRANSACTION;
    INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
    SELECT @Fin, ia.ID_ITEM_ACAO, 'C', N'teste'
    FROM SIS.Item_Acao ia JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
    WHERE ((i.CODIGO = 'FIN_AGENDA' AND a.CODIGO = 'VER') OR (i.CODIGO = 'FIN_PAGAR' AND a.CODIGO = 'VER'))
      AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = @Fin AND x.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);
    DELETE up FROM SIS.Usuario_Permissao up JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = up.ID_ITEM_ACAO JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM
    WHERE up.ID_USUARIO = @Fin AND i.CODIGO IN ('FIN_RECEBER') ;

    IF SIS.fn_SIS_Tem_Permissao(@Fin, 'FIN_AGENDA', 'VER') = 0 OR SIS.fn_SIS_Tem_Permissao(@Fin, 'FIN_AGENDA', 'VER_TOTAIS') = 1 OR SIS.fn_SIS_Tem_Permissao(@Fin, 'FIN_RECEBER', 'VER') = 1
        INSERT @r VALUES (N'P04: usuário de teste preparado', N'VER sem totais e sem receber', N'não deu para preparar');
    ELSE
    BEGIN
        INSERT @res EXEC FIN.FIN_Agenda_Resumo @IdUsuario = @Fin, @De = @De, @Ate = @Ate, @SaldoAcumulado = 1;
        INSERT @r SELECT N'P04: sem VER_TOTAIS, sem valores somados', N'0/-/-/-/-/0',
               CONCAT(CAST(VER_TOTAIS AS INT), '/', ISNULL(CAST(TOTAL_D AS NVARCHAR(30)), N'-'), '/', ISNULL(CAST(SALDO AS NVARCHAR(30)), N'-'), '/',
                      ISNULL(CAST(ATRASO_D AS NVARCHAR(30)), N'-'), '/', ISNULL(CAST(SALDO_CONTAS_HOJE AS NVARCHAR(30)), N'-'), '/', CAST(SALDO_ACUMULADO AS INT)) FROM @res;
        SELECT @Esp = CONCAT(ISNULL(SUM(CASE WHEN l.TIPO = 'P' THEN 1 ELSE 0 END), 0), '/0/0')
        FROM FIN.Parcela p JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE p.DT_VENCIMENTO BETWEEN @De AND @Ate AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.SALDO <> 0 AND l.DT_EXCLUSAO IS NULL AND l.SITUACAO = 'ATIVO';
        SELECT @Obt = CONCAT(QTD_PAGAR, '/', QTD_RECEBER, '/', ATRASO_QTD_RECEBER) FROM @res;
        INSERT @r VALUES (N'P04: só a pagar (sem ver a receber)', @Esp, @Obt);
        INSERT @per EXEC FIN.FIN_Agenda_Periodos @IdUsuario = @Fin, @De = @De, @Ate = @Ate, @Agrupamento = 'MES', @SaldoAcumulado = 1;
        INSERT @r SELECT N'P04: calendário sem valores', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @per WHERE TOTAL_D IS NOT NULL OR SALDO IS NOT NULL OR SALDO_PREVISTO IS NOT NULL;
        DELETE @per; DELETE @res;
    END;
    ROLLBACK TRANSACTION;
END;

-- ---------- preferências (dentro de transação desfeita) ----------
BEGIN TRANSACTION;
INSERT @grv EXEC SIS.SIS_Preferencia_Gravar @IdUsuario = @Celso, @Preferencias = N'[{"codigo":"TEMA","valor":"AZUL"}]';
INSERT @r SELECT N'preferência: opção inválida recusa', N'0/"Tema das telas": opção inválida.', CONCAT(CAST(SUCESSO AS INT), '/', MENSAGEM) FROM @grv; DELETE @grv;
INSERT @grv EXEC SIS.SIS_Preferencia_Gravar @IdUsuario = @Celso, @Preferencias = N'[{"codigo":"INICIO_ANOS","valor":"11"}]';
INSERT @r SELECT N'preferência: fora da faixa recusa', N'0/"Quantos anos em "Vários anos"": o maior valor aceito é 10.', CONCAT(CAST(SUCESSO AS INT), '/', MENSAGEM) FROM @grv; DELETE @grv;
INSERT @grv EXEC SIS.SIS_Preferencia_Gravar @IdUsuario = @Celso, @Preferencias = N'[{"codigo":"NAO_EXISTE","valor":"1"}]';
INSERT @r SELECT N'preferência: desconhecida recusa', N'0/Preferência desconhecida: NAO_EXISTE.', CONCAT(CAST(SUCESSO AS INT), '/', MENSAGEM) FROM @grv; DELETE @grv;
INSERT @grv EXEC SIS.SIS_Preferencia_Gravar @IdUsuario = @Celso, @Preferencias = N'[{"codigo":"TEMA","valor":"escuro"},{"codigo":"INICIO_ANOS","valor":"10"}]';
INSERT @grv EXEC SIS.SIS_Preferencia_Gravar @IdUsuario = @Celso, @Preferencias = N'[{"codigo":"TEMA","valor":"escuro"},{"codigo":"INICIO_ANOS","valor":"abc"}]';
INSERT @r SELECT N'preferência: uma inválida recusa todas', N'1/0', CONCAT(MAX(CAST(SUCESSO AS INT)), '/', MIN(CAST(SUCESSO AS INT))) FROM @grv; DELETE @grv;
INSERT @pref EXEC SIS.SIS_Preferencia_Listar @IdUsuario = @Celso;
INSERT @r SELECT N'preferência gravada vale (TEMA)', N'ESCURO/1', CONCAT(VALOR, '/', CAST(PERSONALIZADA AS INT)) FROM @pref WHERE CODIGO = 'TEMA';
INSERT @r VALUES (N'função da preferência', N'10', SIS.fn_SIS_Preferencia_Valor(@Celso, 'INICIO_ANOS'));
DELETE @pref;
INSERT @grv EXEC SIS.SIS_Preferencia_Gravar @IdUsuario = @Celso, @Preferencias = N'[{"codigo":"TEMA","valor":""},{"codigo":"INICIO_INCLUI_REALIZADO","valor":"S"}]';
INSERT @pref EXEC SIS.SIS_Preferencia_Listar @IdUsuario = @Celso;
INSERT @r SELECT N'valor vazio volta ao padrão', CONCAT(VALOR_PADRAO, '/0'), CONCAT(VALOR, '/', CAST(PERSONALIZADA AS INT)) FROM @pref WHERE CODIGO = 'TEMA';
INSERT @res EXEC FIN.FIN_Agenda_Resumo @IdUsuario = @Celso, @De = @De, @Ate = @Ate;
INSERT @r SELECT N'agenda segue a preferência do usuário', N'1', CAST(CAST(INCLUI_REALIZADO AS INT) AS NVARCHAR(5)) FROM @res;
DELETE @res; DELETE @pref; DELETE @grv;
ROLLBACK TRANSACTION;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
