/*******************************************************************************
  Script      : lançamento fixo para o teste da baixa nas telas (SÓ LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026 (etapa 04g3d)
  Descrição   : Conta a receber "Teste automatico das telas - baixa (nao
                mexer)" de R$ 1.000,00, uma parcela com vencimento longe, do
                parceiro "Cliente Teste telas", e a conta "Caixa Teste telas".
                O passo 12 dos testes das telas (testes/telas) recebe 0,10
                dessa parcela pela janela de baixa e estorna em seguida: a
                parcela volta ao saldo de 1.000,00 a cada rodada (uma baixa
                com o estorno, que não podem ser apagados, fica no histórico).
                v1.1: conta "Caixa Teste telas B" para o passo 13 (transfere
                0,10 do "Caixa Teste telas" para ela, estorna, fecha o caixa B
                e reabre).
                Existe só no SISTEMACMJ_LOCAL: nunca vai ao MASTER nem à CMJ.
                Pode rodar de novo: não duplica.
  Changelog:
    v1.0 (27/11/2026) - Criação (04g3d).
    v1.1 (27/11/2026) - Conta "Caixa Teste telas B" (04g4d).
  Execução: pelo executor SQL (executor_sql\entrada) ou SSMS + F5.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO
SET NOCOUNT ON;

DECLARE @Hoje     DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @Historico NVARCHAR(200) = N'Teste automatico das telas - baixa (nao mexer)';
DECLARE @Empresa  INT = (SELECT TOP (1) e.ID_EMPRESA FROM CAD.Empresa e WHERE e.ATIVO = 1 ORDER BY e.ID_EMPRESA);
DECLARE @Conta    INT = (SELECT TOP (1) c.ID_CONTA FROM BANCO.Conta c WHERE c.DESCRICAO = N'Caixa Teste telas');
DECLARE @ContaB   INT = (SELECT TOP (1) c.ID_CONTA FROM BANCO.Conta c WHERE c.DESCRICAO = N'Caixa Teste telas B');
DECLARE @Cliente  INT = (SELECT TOP (1) p.ID_PESSOA FROM CAD.Pessoa p WHERE p.NOME = N'Cliente Teste telas');
DECLARE @Lanc     BIGINT = (SELECT TOP (1) l.ID_LANCAMENTO FROM FIN.Lancamento l WHERE l.HISTORICO = @Historico);

BEGIN TRANSACTION;
IF @Conta IS NULL
BEGIN
    INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO) VALUES (@Empresa, N'Caixa Teste telas', 'CAIXA');
    SET @Conta = SCOPE_IDENTITY();
END;
IF @ContaB IS NULL
    INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO) VALUES (@Empresa, N'Caixa Teste telas B', 'CAIXA');
IF @Cliente IS NULL
BEGIN
    INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, CLIENTE, ATIVO) VALUES ('F', N'Cliente Teste telas', 1, 1);
    SET @Cliente = SCOPE_IDENTITY();
END;
IF @Lanc IS NULL
BEGIN
    INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, ID_PESSOA, DT_EMISSAO, DT_COMPETENCIA, VALOR_TOTAL, HISTORICO)
    VALUES ('R', @Empresa, @Cliente, DATEADD(DAY, -1, @Hoje), DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1), 1000.00, @Historico);
    SET @Lanc = SCOPE_IDENTITY();
    INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR, ID_CONTA_PREVISTA)
    VALUES (@Lanc, 1, 1, DATEFROMPARTS(YEAR(@Hoje) + 5, 12, 31), 1000.00, @Conta);
END;
COMMIT;

SELECT l.ID_LANCAMENTO, l.HISTORICO, p.ID_PARCELA, p.SALDO, p.ID_CONTA_PREVISTA, c.DESCRICAO AS CONTA
FROM FIN.Lancamento l
INNER JOIN FIN.Parcela p ON p.ID_LANCAMENTO = l.ID_LANCAMENTO
LEFT JOIN BANCO.Conta c ON c.ID_CONTA = p.ID_CONTA_PREVISTA
WHERE l.ID_LANCAMENTO = @Lanc;
GO
