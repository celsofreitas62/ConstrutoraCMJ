/*******************************************************************************
  Teste       : 04f2d - tela Parâmetros: motivo ao afrouxar uma proteção
                (SIS.fn_SIS_Parametro_Afrouxa, SIS_Parametro_Gravar v1.5),
                prévia do efeito (SIS_Parametro_Conferir) e o corpo único das
                pendências (fn_FIN_Lancamento_Pendencias = _Simular sem
                simulação).
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 26/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do
                MASTER. Não muda nada (gravações desfeitas com ROLLBACK).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(200), OBTIDO NVARCHAR(200));
DECLARE @pg TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_PARAMETRO INT);
DECLARE @cf TABLE (PEDE_MOTIVO BIT, QTD_ATUAL INT, QTD_NOVA INT, EFEITO NVARCHAR(400));
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Renata INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'renata');
DECLARE @Erro NVARCHAR(400), @Esp NVARCHAR(200), @Obt NVARCHAR(200), @Dias NVARCHAR(20);

-- estrutura
INSERT @r SELECT N'coluna MOTIVO_ALTERACAO', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.columns WHERE object_id = OBJECT_ID('SIS.Parametro') AND name = 'MOTIVO_ALTERACAO';
INSERT @r SELECT N'objetos novos', N'3', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.objects WHERE object_id IN
       (OBJECT_ID('SIS.fn_SIS_Parametro_Afrouxa'), OBJECT_ID('SIS.SIS_Parametro_Conferir'), OBJECT_ID('FIN.fn_FIN_Lancamento_Pendencias_Simular'));

-- quando afrouxa
INSERT @r VALUES (N'regra: BLOQUEIO para AVISO afrouxa', N'1', CAST(SIS.fn_SIS_Parametro_Afrouxa('FIN_REGRA_DUPLIC_DOCUMENTO', N'BLOQUEIO', N'AVISO') AS NVARCHAR(1)));
INSERT @r VALUES (N'regra: AVISO para NAO afrouxa', N'1', CAST(SIS.fn_SIS_Parametro_Afrouxa('FIN_REGRA_DUPLIC_DOCUMENTO', N'aviso', N'nao') AS NVARCHAR(1)));
INSERT @r VALUES (N'regra: AVISO para BLOQUEIO não afrouxa', N'0', CAST(SIS.fn_SIS_Parametro_Afrouxa('FIN_REGRA_DUPLIC_DOCUMENTO', N'AVISO', N'BLOQUEIO') AS NVARCHAR(1)));
INSERT @r VALUES (N'trava de datas S para N afrouxa', N'1', CAST(SIS.fn_SIS_Parametro_Afrouxa('FIN_TRAVA_DATAS_ATIVA', N'S', N'N') AS NVARCHAR(1)));
INSERT @r VALUES (N'trava de datas N para S não afrouxa', N'0', CAST(SIS.fn_SIS_Parametro_Afrouxa('FIN_TRAVA_DATAS_ATIVA', N'N', N'S') AS NVARCHAR(1)));
INSERT @r VALUES (N'outro parâmetro não afrouxa', N'0', CAST(SIS.fn_SIS_Parametro_Afrouxa('FIN_PEND_SEM_CENTRO', N'S', N'N') AS NVARCHAR(1)));

-- gravar com e sem motivo
BEGIN TRANSACTION;
    INSERT @pg EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @Celso, @Chave = 'FIN_REGRA_DUPLIC_DOCUMENTO', @Valor = N'BLOQUEIO';
    INSERT @r SELECT N'apertar não pede motivo', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @pg); DELETE @pg;
    INSERT @pg EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @Celso, @Chave = 'FIN_REGRA_DUPLIC_DOCUMENTO', @Valor = N'NAO';
    INSERT @r SELECT N'afrouxar sem motivo: recusa', N'0/' + N'Esta alteração afrouxa uma proteção do sistema: informe o motivo.', (SELECT CONCAT(CAST(SUCESSO AS NVARCHAR(1)), '/', MENSAGEM) FROM @pg); DELETE @pg;
    INSERT @r SELECT N'recusado: valor não mudou', N'BLOQUEIO', VALOR FROM SIS.Parametro WHERE CHAVE = 'FIN_REGRA_DUPLIC_DOCUMENTO';
    INSERT @pg EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @Celso, @Chave = 'FIN_REGRA_DUPLIC_DOCUMENTO', @Valor = N'NAO', @Motivo = N'  teste do motivo  ';
    INSERT @r SELECT N'afrouxar com motivo: grava', N'1/NAO/teste do motivo',
           (SELECT CONCAT(CAST(g.SUCESSO AS NVARCHAR(1)), '/', p.VALOR, '/', p.MOTIVO_ALTERACAO) FROM @pg g CROSS JOIN SIS.Parametro p WHERE p.CHAVE = 'FIN_REGRA_DUPLIC_DOCUMENTO'); DELETE @pg;
    INSERT @r SELECT N'motivo na auditoria', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Auditoria
           WHERE TABELA = N'SIS.Parametro' AND CAMPO = N'MOTIVO_ALTERACAO' AND VALOR_DEPOIS = N'teste do motivo';
ROLLBACK;

-- conferir (prévia)
INSERT @cf EXEC SIS.SIS_Parametro_Conferir @IdUsuario = @Celso, @Chave = 'FIN_TRAVA_DATAS_ATIVA', @Valor = N'N';
INSERT @r SELECT N'conferir: desligar a trava pede motivo', N'1/-', (SELECT CONCAT(CAST(PEDE_MOTIVO AS NVARCHAR(1)), '/', ISNULL(CAST(QTD_NOVA AS NVARCHAR(10)), '-')) FROM @cf); DELETE @cf;

SET @Dias = (SELECT VALOR FROM SIS.Parametro WHERE CHAVE = 'FIN_PEND_VENCIDA_DIAS');
SELECT @Esp = CONCAT(COUNT(DISTINCT l.ID_LANCAMENTO), '/0/0')
FROM FIN.Lancamento l CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) f
WHERE f.CODIGO = 'VENCIDA' AND f.ORIGEM = 'AUTOMATICA';
INSERT @cf EXEC SIS.SIS_Parametro_Conferir @IdUsuario = @Celso, @Chave = 'FIN_PEND_VENCIDA_DIAS', @Valor = N'0';
INSERT @r SELECT N'conferir: vencida desligada (atual/nova/motivo)', @Esp, (SELECT CONCAT(QTD_ATUAL, '/', QTD_NOVA, '/', CAST(PEDE_MOTIVO AS NVARCHAR(1))) FROM @cf);
INSERT @r SELECT N'conferir: frase do efeito', N'1', (SELECT CASE WHEN EFEITO LIKE N'%lançamentos em aberto%' THEN N'1' ELSE EFEITO END FROM @cf); DELETE @cf;
INSERT @cf EXEC SIS.SIS_Parametro_Conferir @IdUsuario = @Celso, @Chave = 'FIN_PEND_VENCIDA_DIAS', @Valor = @Dias;
INSERT @r SELECT N'conferir: mesmo valor não calcula', N'-/', (SELECT CONCAT(ISNULL(CAST(QTD_NOVA AS NVARCHAR(10)), '-'), '/', EFEITO) FROM @cf); DELETE @cf;

-- simular com valor maior conta menos ou igual
INSERT @cf EXEC SIS.SIS_Parametro_Conferir @IdUsuario = @Celso, @Chave = 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR', @Valor = N'999999999,00';
INSERT @r SELECT N'conferir: anexo com valor enorme = 0', N'0', (SELECT CAST(QTD_NOVA AS NVARCHAR(10)) FROM @cf); DELETE @cf;

-- corpo único: a função de sempre = simular sem simulação
SELECT @Esp = CAST(COUNT(*) AS NVARCHAR(20)) FROM FIN.Lancamento l CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) f;
SELECT @Obt = CAST(COUNT(*) AS NVARCHAR(20)) FROM FIN.Lancamento l CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias_Simular(l.ID_LANCAMENTO, NULL, NULL) f;
INSERT @r VALUES (N'pendências: função = simular sem simulação', @Esp, @Obt);

-- permissões
BEGIN TRY EXEC SIS.SIS_Parametro_Conferir @IdUsuario = -1, @Chave = 'FIN_PEND_SEM_CENTRO', @Valor = N'N'; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = CAST(ERROR_NUMBER() AS NVARCHAR(10)); END CATCH;
INSERT @r VALUES (N'conferir sem permissão: recusa', N'50001', @Erro);
IF @Renata IS NOT NULL
BEGIN
    BEGIN TRY EXEC SIS.SIS_Parametro_Conferir @IdUsuario = @Renata, @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'9'; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = ERROR_MESSAGE(); END CATCH;
    INSERT @r VALUES (N'administradora: parâmetro do geral recusado', N'Este parâmetro só pode ser visto pelo administrador geral.', @Erro);
END
ELSE INSERT @r VALUES (N'administradora: parâmetro do geral recusado', N'-', N'-');
BEGIN TRY EXEC SIS.SIS_Parametro_Conferir @IdUsuario = @Celso, @Chave = 'NAO_EXISTE', @Valor = N'1'; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = ERROR_MESSAGE(); END CATCH;
INSERT @r VALUES (N'parâmetro inexistente', N'Parâmetro não encontrado.', @Erro);

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
