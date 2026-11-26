/*******************************************************************************
  Teste       : 04f2d - resumo da aba Movimentação do Parceiro
                (FIN_Parceiro_Movimento_Resumo): conferido contra uma conta
                feita à parte, nos parceiros com mais movimento a pagar e a
                receber; permissões e parceiro inexistente.
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 26/11/2026 (v1.0). Roda no SISTEMACMJ_LOCAL e no banco do
                MASTER (no banco sem movimento, os casos com dados passam
                direto). Não muda nada.
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(100), ESPERADO NVARCHAR(120), OBTIDO NVARCHAR(120));
DECLARE @res TABLE (TIPO CHAR(1), QTD_EM_ABERTO INT, VALOR_EM_ABERTO DECIMAL(18,2), QTD_VENCIDAS INT, VALOR_VENCIDAS DECIMAL(18,2),
                    QTD_PAGO_12M INT, VALOR_PAGO_12M DECIMAL(18,2), MEDIA_MENSAL_12M DECIMAL(18,2), DT_ULTIMO_PAGAMENTO DATE, DT_DESDE DATE);
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @Desde DATE = DATEADD(DAY, 1, DATEADD(MONTH, -12, @Hoje));
DECLARE @Tipo CHAR(1), @Pessoa INT, @Erro NVARCHAR(400), @Esp NVARCHAR(120), @Obt NVARCHAR(120);

-- estrutura
INSERT @r SELECT N'procedure nova', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.procedures WHERE object_id = OBJECT_ID('FIN.FIN_Parceiro_Movimento_Resumo');

-- permissões
BEGIN TRY EXEC FIN.FIN_Parceiro_Movimento_Resumo @IdUsuario = -1, @IdPessoa = 1; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = CAST(ERROR_NUMBER() AS NVARCHAR(10)); END CATCH;
INSERT @r VALUES (N'sem permissão: recusa', N'50001', @Erro);
BEGIN TRY EXEC FIN.FIN_Parceiro_Movimento_Resumo @IdUsuario = @Celso, @IdPessoa = -5; SET @Erro = N'sem erro'; END TRY BEGIN CATCH SET @Erro = ERROR_MESSAGE(); END CATCH;
INSERT @r VALUES (N'parceiro inexistente: recusa', N'Parceiro não encontrado.', @Erro);

-- parceiro sem movimento: as duas linhas zeradas
SET @Pessoa = (SELECT TOP 1 p.ID_PESSOA FROM CAD.Pessoa p WHERE NOT EXISTS (SELECT 1 FROM FIN.Lancamento l WHERE l.ID_PESSOA = p.ID_PESSOA) ORDER BY p.ID_PESSOA);
IF @Pessoa IS NOT NULL
BEGIN
    INSERT @res EXEC FIN.FIN_Parceiro_Movimento_Resumo @IdUsuario = @Celso, @IdPessoa = @Pessoa;
    INSERT @r SELECT N'sem movimento: P e R zerados', N'PR/0.00', CONCAT(STRING_AGG(TIPO, '') WITHIN GROUP (ORDER BY TIPO), '/', SUM(VALOR_EM_ABERTO + VALOR_PAGO_12M)) FROM @res;
    DELETE @res;
END
ELSE INSERT @r VALUES (N'sem movimento: P e R zerados', N'-', N'-');

-- conferência contra a conta feita à parte, para P e R
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT TIPO FROM (VALUES ('P'), ('R')) t (TIPO);
OPEN c; FETCH NEXT FROM c INTO @Tipo;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Pessoa = (SELECT TOP 1 l.ID_PESSOA FROM FIN.Baixa b JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
                   WHERE l.TIPO = @Tipo AND l.ID_PESSOA IS NOT NULL AND l.DT_EXCLUSAO IS NULL GROUP BY l.ID_PESSOA ORDER BY COUNT(*) DESC);
    IF @Pessoa IS NULL
    BEGIN
        INSERT @r VALUES (CONCAT(N'tipo ', @Tipo, N': em aberto'), N'-', N'-'), (CONCAT(N'tipo ', @Tipo, N': pago 12 meses e média'), N'-', N'-'), (CONCAT(N'tipo ', @Tipo, N': último pagamento'), N'-', N'-');
    END
    ELSE
    BEGIN
        INSERT @res EXEC FIN.FIN_Parceiro_Movimento_Resumo @IdUsuario = @Celso, @IdPessoa = @Pessoa;

        SELECT @Esp = CONCAT(COUNT(*), '/', ISNULL(SUM(p.SALDO), 0), '/', ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END), 0), '/', ISNULL(SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN p.SALDO END), 0))
        FROM FIN.Parcela p JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE l.ID_PESSOA = @Pessoa AND l.TIPO = @Tipo AND l.DT_EXCLUSAO IS NULL AND l.SITUACAO = 'ATIVO' AND p.SITUACAO IN ('ABERTA', 'PARCIAL');
        SELECT @Obt = CONCAT(QTD_EM_ABERTO, '/', VALOR_EM_ABERTO, '/', QTD_VENCIDAS, '/', VALOR_VENCIDAS) FROM @res WHERE TIPO = @Tipo;
        INSERT @r VALUES (CONCAT(N'tipo ', @Tipo, N': em aberto'), @Esp, @Obt);

        SELECT @Esp = CONCAT(CAST(ISNULL(SUM(b.VALOR_LIQUIDO), 0) AS DECIMAL(18,2)), '/', CAST(ROUND(ISNULL(SUM(b.VALOR_LIQUIDO), 0) / 12.0, 2) AS DECIMAL(18,2)))
        FROM FIN.Baixa b JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE l.ID_PESSOA = @Pessoa AND l.TIPO = @Tipo AND l.DT_EXCLUSAO IS NULL AND b.DT_PAGAMENTO >= @Desde AND b.DT_PAGAMENTO <= @Hoje;
        SELECT @Obt = CONCAT(VALOR_PAGO_12M, '/', MEDIA_MENSAL_12M) FROM @res WHERE TIPO = @Tipo;
        INSERT @r VALUES (CONCAT(N'tipo ', @Tipo, N': pago 12 meses e média'), @Esp, @Obt);

        SELECT @Esp = ISNULL(CONVERT(NVARCHAR(10), MAX(b.DT_PAGAMENTO), 23), N'-')
        FROM FIN.Baixa b JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE l.ID_PESSOA = @Pessoa AND l.TIPO = @Tipo AND l.DT_EXCLUSAO IS NULL AND b.ID_BAIXA_ESTORNADA IS NULL;
        SELECT @Obt = ISNULL(CONVERT(NVARCHAR(10), DT_ULTIMO_PAGAMENTO, 23), N'-') FROM @res WHERE TIPO = @Tipo;
        INSERT @r VALUES (CONCAT(N'tipo ', @Tipo, N': último pagamento'), @Esp, @Obt);
        DELETE @res;
    END
    FETCH NEXT FROM c INTO @Tipo;
END
CLOSE c; DEALLOCATE c;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
