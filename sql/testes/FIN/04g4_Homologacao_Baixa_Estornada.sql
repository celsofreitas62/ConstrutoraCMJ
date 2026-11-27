/*******************************************************************************
  Teste       : 04g4 - baixa estornada não trava o lançamento (decisão do
                Celso, 27/11/2026): com baixa viva, valor/parcela/cancelar
                recusados; depois do estorno, a parcela muda de valor, o
                lançamento cancela, mas a parcela com baixa estornada não sai e
                excluir continua proibido (PODE_EXCLUIR = 0).
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 27/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do MASTER
                (sem centro, plano ou o usuário de teste, os casos com dados
                passam direto).
  Observação  : não muda nada (tudo desfeito com ROLLBACK). Datas calculadas a
                partir de hoje.
*******************************************************************************/
SET NOCOUNT ON;
DROP TABLE IF EXISTS #obt;
CREATE TABLE #obt (C01 NVARCHAR(MAX), C02 NVARCHAR(MAX), C03 NVARCHAR(MAX), C04 NVARCHAR(MAX), C05 NVARCHAR(MAX), C06 NVARCHAR(MAX), C07 NVARCHAR(MAX),
                   C08 NVARCHAR(MAX), C09 NVARCHAR(MAX), C10 NVARCHAR(MAX), C11 NVARCHAR(MAX), C12 NVARCHAR(MAX), C13 NVARCHAR(MAX), C14 NVARCHAR(MAX),
                   C15 NVARCHAR(MAX), C16 NVARCHAR(MAX), C17 NVARCHAR(MAX), C18 NVARCHAR(MAX), C19 NVARCHAR(MAX), C20 NVARCHAR(MAX), C21 NVARCHAR(MAX),
                   C22 NVARCHAR(MAX), C23 NVARCHAR(MAX), C24 NVARCHAR(MAX), C25 NVARCHAR(MAX), C26 NVARCHAR(MAX), C27 NVARCHAR(MAX), C28 NVARCHAR(MAX),
                   C29 NVARCHAR(MAX), C30 NVARCHAR(MAX), C31 NVARCHAR(MAX), C32 NVARCHAR(MAX), C33 NVARCHAR(MAX), C34 NVARCHAR(MAX), C35 NVARCHAR(MAX),
                   C36 NVARCHAR(MAX), TEM_BAIXA NVARCHAR(MAX), C38 NVARCHAR(MAX), C39 NVARCHAR(MAX), PODE_ALTERAR NVARCHAR(MAX), PODE_CANCELAR NVARCHAR(MAX),
                   PODE_EXCLUIR NVARCHAR(MAX), PARCELAS NVARCHAR(MAX), BAIXAS NVARCHAR(MAX), AVISOS_CONFIRMADOS NVARCHAR(MAX),
                   PENDENCIAS NVARCHAR(MAX), QTD_PENDENCIAS NVARCHAR(MAX), PODE_PENDENCIA NVARCHAR(MAX), BLOQUEIA_BAIXA NVARCHAR(MAX), MOTIVO_BLOQUEIO NVARCHAR(MAX), TEM_HISTORICO_BAIXA NVARCHAR(MAX));
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(200), OBTIDO NVARCHAR(400));
DECLARE @g TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @c TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT);
DECLARE @b TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, ID_MOVIMENTO BIGINT, ID_LOTE BIGINT, PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @e TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID BIGINT, QTD_BAIXAS INT, VALOR DECIMAL(18,2), PENDENTE BIT, AVISOS NVARCHAR(MAX));
DECLARE @Fin INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'teste.tela04a');
DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @Centro INT, @PlanoR INT, @Empresa INT, @Conta INT, @Cli INT, @L BIGINT, @P1 BIGINT, @P2 BIGINT, @Baixa BIGINT, @J NVARCHAR(MAX), @Itens NVARCHAR(MAX);
DECLARE @V1 NVARCHAR(10) = CONVERT(NVARCHAR(10), DATEADD(DAY, 30, @Hoje), 23), @V2 NVARCHAR(10) = CONVERT(NVARCHAR(10), DATEADD(DAY, 60, @Hoje), 23);

INSERT @r SELECT N'função FIN.fn_FIN_Parcela_Baixa_Viva', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.objects WHERE object_id = OBJECT_ID('FIN.fn_FIN_Parcela_Baixa_Viva');

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'BANCO', 'FIN') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND HABILITADO = 0;
UPDATE SIS.Parametro SET VALOR = N'S' WHERE CHAVE = 'FIN_TRAVA_DATAS_ATIVA';
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT u.ID_PERFIL, ia.ID_ITEM_ACAO
FROM SIS.Usuario u CROSS JOIN SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO
WHERE u.ID_USUARIO = @Fin AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER') AND a.CODIGO NOT IN ('LANCAR_RETROATIVO', 'LIBERAR_PENDENCIA', 'DESCONTO_LIMITE')
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);

SET @Centro = (SELECT TOP 1 cc.ID_CENTRO_CUSTO FROM CAD.Centro_Custo cc INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = cc.ID_EMPRESA AND e.ATIVO = 1
               WHERE cc.ATIVO = 1 AND cc.DT_EXCLUSAO IS NULL AND (cc.DT_ENCERRAMENTO IS NULL OR cc.DT_ENCERRAMENTO > @Hoje) ORDER BY cc.ID_CENTRO_CUSTO);
SET @Empresa = (SELECT ID_EMPRESA FROM CAD.Centro_Custo WHERE ID_CENTRO_CUSTO = @Centro);
SET @PlanoR = (SELECT TOP 1 v.ID_PLANO_CONTA FROM CAD.vw_CAD_Plano_Conta v INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = v.ID_PLANO_CONTA
               WHERE v.ATIVO_EFETIVO = 1 AND v.TIPO = 'RECEITA' AND pc.DT_EXCLUSAO IS NULL ORDER BY v.ORDEM_ARVORE);

IF @Centro IS NOT NULL AND @PlanoR IS NOT NULL AND @Fin IS NOT NULL
BEGIN
    UPDATE CAD.Plano_Conta SET CONTABIL = 0 WHERE ID_PLANO_CONTA = @PlanoR;
    INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO) VALUES (@Empresa, N'Caixa Teste 04g4', 'CAIXA');
    SET @Conta = SCOPE_IDENTITY();
    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, CLIENTE, ATIVO) VALUES ('F', N'Cliente Teste 04g4', 1, 1);
    SET @Cli = SCOPE_IDENTITY();

    -- lançamento a receber de 200 em 2 parcelas
    SET @J = N'[{"vencimento":"' + @V1 + N'","valor":100},{"vencimento":"' + @V2 + N'","valor":100}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @Tipo = 'R', @IdCentroCusto = @Centro, @IdPessoa = @Cli, @IdPlanoConta = @PlanoR,
         @Documento = N'T04G4', @DtEmissao = @Hoje, @ValorTotal = 200, @Historico = N'Teste 04g4', @Parcelas = @J;
    SET @L = (SELECT ID FROM @g);
    INSERT @r SELECT N'lançamento gravado', N'1', (SELECT CONCAT(CAST(SUCESSO AS INT), CASE WHEN SUCESSO = 0 THEN N' ' + MENSAGEM + N' ' + ISNULL(AVISOS, N'') ELSE N'' END) FROM @g); DELETE @g;
    SELECT @P1 = MIN(ID_PARCELA), @P2 = MAX(ID_PARCELA) FROM FIN.Parcela WHERE ID_LANCAMENTO = @L;

    -- baixa viva na 1ª parcela
    SET @Itens = N'[{"idParcela":' + CONVERT(NVARCHAR(20), @P1) + N',"principal":40}]';
    INSERT @b EXEC FIN.FIN_Baixa_Gravar @IdUsuario = @Fin, @DtPagamento = @Hoje, @IdConta = @Conta, @Forma = 'PIX', @Itens = @Itens;
    SET @Baixa = (SELECT TOP 1 ID_BAIXA FROM FIN.Baixa WHERE ID_PARCELA = @P1 ORDER BY ID_BAIXA);
    INSERT @r SELECT N'baixa parcial de 40 gravada', N'1', (SELECT CONCAT(CAST(SUCESSO AS INT), CASE WHEN SUCESSO = 0 THEN N' ' + MENSAGEM ELSE N'' END) FROM @b); DELETE @b;
    INSERT @r SELECT N'baixa viva conta', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM FIN.fn_FIN_Parcela_Baixa_Viva(@P1);

    INSERT #obt EXEC FIN.FIN_Lancamento_Obter @IdUsuario = @Fin, @IdLancamento = @L;
    INSERT @r SELECT N'com baixa viva: TEM_BAIXA/hist/cancelar/excluir', N'1/1/0/0', (SELECT CONCAT(TEM_BAIXA, '/', TEM_HISTORICO_BAIXA, '/', PODE_CANCELAR, '/', PODE_EXCLUIR) FROM #obt);
    INSERT @r SELECT N'com baixa viva: parcela 1 travada', N'true', (SELECT CAST(JSON_VALUE(PARCELAS, '$[0].travada') AS NVARCHAR(5)) FROM #obt); DELETE #obt;

    SET @J = N'[{"id":' + CONVERT(NVARCHAR(20), @P1) + N',"vencimento":"' + @V1 + N'","valor":90},{"id":' + CONVERT(NVARCHAR(20), @P2) + N',"vencimento":"' + @V2 + N'","valor":110}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @IdLancamento = @L, @IdCentroCusto = @Centro, @IdPessoa = @Cli, @IdPlanoConta = @PlanoR,
         @Documento = N'T04G4', @DtEmissao = @Hoje, @ValorTotal = 200, @Historico = N'Teste 04g4', @Parcelas = @J;
    INSERT @r SELECT N'com baixa viva: parcela 1 não muda de valor', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g); DELETE @g;
    INSERT @c EXEC FIN.FIN_Lancamento_Cancelar @IdUsuario = @Fin, @IdLancamento = @L, @Motivo = N'Teste';
    INSERT @r SELECT N'com baixa viva: cancelar recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @c); DELETE @c;

    -- estorno
    INSERT @e EXEC FIN.FIN_Baixa_Estornar @IdUsuario = @Fin, @IdBaixa = @Baixa, @Motivo = N'Teste 04g4';
    INSERT @r SELECT N'estorno gravado', N'1', (SELECT CONCAT(CAST(SUCESSO AS INT), CASE WHEN SUCESSO = 0 THEN N' ' + MENSAGEM ELSE N'' END) FROM @e); DELETE @e;
    INSERT @r SELECT N'depois do estorno: nenhuma baixa viva', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM FIN.fn_FIN_Parcela_Baixa_Viva(@P1);

    INSERT #obt EXEC FIN.FIN_Lancamento_Obter @IdUsuario = @Fin, @IdLancamento = @L;
    INSERT @r SELECT N'estornada: TEM_BAIXA/hist/cancelar/excluir', N'0/1/1/0', (SELECT CONCAT(TEM_BAIXA, '/', TEM_HISTORICO_BAIXA, '/', PODE_CANCELAR, '/', PODE_EXCLUIR) FROM #obt);
    INSERT @r SELECT N'estornada: parcela 1 não travada mas fixa', N'false/true', (SELECT CONCAT(JSON_VALUE(PARCELAS, '$[0].travada'), '/', JSON_VALUE(PARCELAS, '$[0].fixa')) FROM #obt); DELETE #obt;

    -- retirar a parcela com baixa estornada: recusa
    SET @J = N'[{"id":' + CONVERT(NVARCHAR(20), @P2) + N',"vencimento":"' + @V2 + N'","valor":200}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @IdLancamento = @L, @IdCentroCusto = @Centro, @IdPessoa = @Cli, @IdPlanoConta = @PlanoR,
         @Documento = N'T04G4', @DtEmissao = @Hoje, @ValorTotal = 200, @Historico = N'Teste 04g4', @Parcelas = @J;
    INSERT @r SELECT N'estornada: parcela não pode ser retirada', N'0/estornada', (SELECT CONCAT(CAST(SUCESSO AS INT), '/', CASE WHEN MENSAGEM LIKE N'%estornada%' THEN N'estornada' ELSE MENSAGEM END) FROM @g); DELETE @g;

    -- mudar o valor das parcelas e o total: aceita
    SET @J = N'[{"id":' + CONVERT(NVARCHAR(20), @P1) + N',"vencimento":"' + @V1 + N'","valor":120},{"id":' + CONVERT(NVARCHAR(20), @P2) + N',"vencimento":"' + @V2 + N'","valor":130}]';
    INSERT @g EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = @Fin, @IdLancamento = @L, @IdCentroCusto = @Centro, @IdPessoa = @Cli, @IdPlanoConta = @PlanoR,
         @Documento = N'T04G4', @DtEmissao = @Hoje, @ValorTotal = 250, @Historico = N'Teste 04g4', @Parcelas = @J, @AvisosConfirmados = N'VALOR_FORA_MEDIA,VALOR_ALTO';
    INSERT @r SELECT N'estornada: muda valor da parcela e o total', N'1', (SELECT CONCAT(CAST(SUCESSO AS INT), CASE WHEN SUCESSO = 0 THEN N' ' + MENSAGEM + N' ' + ISNULL(AVISOS, N'') ELSE N'' END) FROM @g); DELETE @g;
    INSERT @r SELECT N'parcela 1: valor/saldo/situação', N'120.00/120.00/ABERTA', (SELECT CONCAT(VALOR, '/', SALDO, '/', SITUACAO) FROM FIN.Parcela WHERE ID_PARCELA = @P1);

    -- cancelar: aceita
    INSERT @c EXEC FIN.FIN_Lancamento_Cancelar @IdUsuario = @Fin, @IdLancamento = @L, @Motivo = N'Teste 04g4';
    INSERT @r SELECT N'estornada: cancelar aceito', N'1', (SELECT CONCAT(CAST(SUCESSO AS INT), CASE WHEN SUCESSO = 0 THEN N' ' + MENSAGEM ELSE N'' END) FROM @c); DELETE @c;
END;
ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
DROP TABLE IF EXISTS #obt;
