/*******************************************************************************
  Teste       : 04e - cadastros-base: empresas (rodapé dos e-mails, pasta do OFX,
                conta padrão da própria empresa), contas bancárias (travas com
                movimento e mês fechado); depois centros de custo e plano de contas.
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 25/11/2026 (v1.0, parte A; v1.1 parte B: centros e seletor). Roda no SISTEMACMJ_LOCAL e no banco do MASTER.
  Observação  : não muda nada (tudo desfeito com ROLLBACK).
*******************************************************************************/
SET NOCOUNT ON;
DECLARE @r TABLE (CASO NVARCHAR(90), ESPERADO NVARCHAR(80), OBTIDO NVARCHAR(80));
DECLARE @g TABLE (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
DECLARE @Celso INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'celso');
DECLARE @Claude INT = (SELECT ID_USUARIO FROM SIS.Usuario WHERE LOGIN = 'claude');
DECLARE @E INT, @E2 INT, @C INT, @C2 INT, @Bco INT = (SELECT TOP 1 ID_BANCO FROM BANCO.Banco WHERE ATIVO = 1 ORDER BY CODIGO);

INSERT @r SELECT N'coluna RODAPE_EMAIL em CAD.Empresa', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM sys.columns WHERE object_id = OBJECT_ID('CAD.Empresa') AND name = 'RODAPE_EMAIL';
INSERT @r SELECT N'tipo de anexo CERTIDAO', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Anexo_Tipo WHERE CODIGO = 'CERTIDAO';

BEGIN TRAN;
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'BANCO') AND HABILITADO = 0;
UPDATE SIS.Item SET HABILITADO = 1 WHERE CODIGO IN ('CAD_EMPRESA', 'BANCO_CONTA') AND HABILITADO = 0;

-- empresa nova com rodapé e pasta do OFX
INSERT @g EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @Celso, @RazaoSocial = N'Empresa Teste 04e Ltda', @Cnpj = '11.222.333/0001-81', @Tipo = 'SPE',
     @RodapeEmail = N'  contato@teste.com.br  ', @PastaOfx = N'C:\OFX\Teste';
SET @E = (SELECT ID FROM @g);
INSERT @r SELECT N'inclui empresa', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
INSERT @r SELECT N'rodapé gravado sem espaços nas pontas', N'contato@teste.com.br', (SELECT RODAPE_EMAIL FROM CAD.Empresa WHERE ID_EMPRESA = @E);
INSERT @r SELECT N'pasta do OFX gravada pelo administrador', N'C:\OFX\Teste', (SELECT PASTA_OFX FROM CAD.Empresa WHERE ID_EMPRESA = @E);
DELETE @g;
INSERT @g EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @Celso, @IdEmpresa = @E, @RazaoSocial = N'Empresa Teste 04e Ltda', @Cnpj = '11222333000181', @Tipo = 'SPE';
INSERT @r SELECT N'rodapé e pasta NULL = não mexe', N'contato@teste.com.br|C:\OFX\Teste', (SELECT RODAPE_EMAIL + N'|' + PASTA_OFX FROM CAD.Empresa WHERE ID_EMPRESA = @E);
DELETE @g;
INSERT @g EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @Claude, @IdEmpresa = @E, @RazaoSocial = N'X', @Cnpj = '11222333000181';
INSERT @r SELECT N'usuário só de consulta não grava empresa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);

-- Obter
INSERT @r SELECT N'Empresa_Obter devolve as colunas novas', N'5', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC CAD.CAD_Empresa_Obter @IdUsuario = 1, @IdEmpresa = 1', NULL, 0)
       WHERE name IN ('RODAPE_EMAIL', 'PASTA_OFX', 'PODE_PASTA_OFX', 'QTD_CONTAS', 'NA_LIXEIRA');

-- contas
DELETE @g;
INSERT @g EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @Celso, @IdEmpresa = @E, @Descricao = N'Conta Teste 04e', @Tipo = 'CORRENTE', @IdBanco = @Bco,
     @Agencia = '0217', @Numero = '12345', @NumeroDv = '6', @SaldoInicial = 100, @DtSaldoInicial = '20261101';
SET @C = (SELECT ID FROM @g);
INSERT @r SELECT N'inclui conta corrente', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
DELETE @g;
INSERT @g EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @Celso, @IdEmpresa = @E, @Descricao = N'Caixa Teste 04e', @Tipo = 'CAIXA';
SET @C2 = (SELECT ID FROM @g);
DELETE @g;
INSERT @g EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @Celso, @IdConta = @C, @IdEmpresa = @E, @Descricao = N'Conta Teste 04e', @Tipo = 'CORRENTE', @IdBanco = @Bco,
     @Agencia = '0217', @Numero = '12345', @NumeroDv = '6', @SaldoInicial = 150, @DtSaldoInicial = '20261101';
INSERT @r SELECT N'sem movimento: saldo inicial muda', N'150.00', (SELECT CAST(SALDO_INICIAL AS NVARCHAR(20)) FROM BANCO.Conta WHERE ID_CONTA = @C);

-- conta padrão precisa ser da própria empresa
SET @E2 = (SELECT TOP 1 ID_EMPRESA FROM CAD.Empresa WHERE ID_EMPRESA <> @E AND ATIVO = 1);
DELETE @g;
INSERT @g EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @Celso, @IdEmpresa = @E, @RazaoSocial = N'Empresa Teste 04e Ltda', @Cnpj = '11222333000181', @Tipo = 'SPE', @IdContaBancariaPadrao = @C;
INSERT @r SELECT N'conta padrão da própria empresa aceita', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
IF @E2 IS NOT NULL
BEGIN
    DELETE @g;
    DECLARE @CnpjE2 VARCHAR(14), @RsE2 NVARCHAR(150), @TipoE2 VARCHAR(12);
    SELECT @CnpjE2 = CNPJ, @RsE2 = RAZAO_SOCIAL, @TipoE2 = TIPO FROM CAD.Empresa WHERE ID_EMPRESA = @E2;
    INSERT @g EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @Celso, @IdEmpresa = @E2, @RazaoSocial = @RsE2, @Cnpj = @CnpjE2, @Tipo = @TipoE2, @IdContaBancariaPadrao = @C;
    INSERT @r SELECT N'conta de outra empresa recusada como padrão', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
END
ELSE INSERT @r VALUES (N'conta de outra empresa recusada como padrão', N'0', N'0');

-- com movimento: trava empresa, tipo e saldo inicial
INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO) VALUES (@C, '20261110', 10, 'AJUSTE', N'teste 04e');
DELETE @g;
INSERT @g EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @Celso, @IdConta = @C, @IdEmpresa = @E, @Descricao = N'Conta Teste 04e', @Tipo = 'CORRENTE', @IdBanco = @Bco,
     @Agencia = '0217', @Numero = '12345', @NumeroDv = '6', @SaldoInicial = 200, @DtSaldoInicial = '20261101';
INSERT @r SELECT N'com movimento: saldo inicial travado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
DELETE @g;
INSERT @g EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @Celso, @IdConta = @C, @IdEmpresa = @E, @Descricao = N'Conta Teste 04e', @Tipo = 'POUPANCA', @IdBanco = @Bco,
     @Agencia = '0217', @Numero = '12345', @NumeroDv = '6', @SaldoInicial = 150, @DtSaldoInicial = '20261101';
INSERT @r SELECT N'com movimento: tipo travado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
DELETE @g;
INSERT @g EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @Celso, @IdConta = @C, @IdEmpresa = @E, @Descricao = N'Conta Teste 04e renomeada', @Tipo = 'CORRENTE', @IdBanco = @Bco,
     @Agencia = '0217', @Numero = '12345', @NumeroDv = '6', @SaldoInicial = 150, @DtSaldoInicial = '20261101', @Concilia = 1;
INSERT @r SELECT N'com movimento: descrição e conciliação mudam', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);

-- mês fechado trava o saldo inicial da conta sem movimento
INSERT INTO FIN.Mes_Fechado (ID_EMPRESA, MES) VALUES (@E, '20261101');
DELETE @g;
INSERT @g EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @Celso, @IdConta = @C2, @IdEmpresa = @E, @Descricao = N'Caixa Teste 04e', @Tipo = 'CAIXA', @SaldoInicial = 50, @DtSaldoInicial = '20261115';
INSERT @r SELECT N'saldo inicial em mês fechado recusado', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
DELETE @g;
INSERT @g EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @Celso, @IdConta = @C2, @IdEmpresa = @E, @Descricao = N'Caixa Teste 04e', @Tipo = 'CAIXA', @SaldoInicial = 50, @DtSaldoInicial = '20261201';
INSERT @r SELECT N'saldo inicial em mês aberto aceito', N'1', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);

INSERT @r SELECT N'Conta_Obter devolve TEM_MOVIMENTO e PADRAO_DA_EMPRESA', N'2', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC BANCO.BANCO_Conta_Obter @IdUsuario = 1, @IdConta = 1', NULL, 0)
       WHERE name IN ('TEM_MOVIMENTO', 'PADRAO_DA_EMPRESA');
-- ---------- parte B: centros de custo e seletor ----------
DECLARE @CC INT, @CC2 INT;
DELETE @g;
INSERT @g EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = @Celso, @IdEmpresa = @E, @Codigo = 'tst04e', @Descricao = N'Obra Teste 04e', @Tipo = 'OBRA',
     @IdContaBancariaPadrao = @C2, @DtEncerramento = '20261201', @MexerEncerramento = 1;
SET @CC = (SELECT ID FROM @g);
INSERT @r SELECT N'inclui centro (código em maiúsculas, encerramento)', N'TST04E 2026-12-01', (SELECT CODIGO + N' ' + CONVERT(NVARCHAR(10), DT_ENCERRAMENTO, 23) FROM CAD.Centro_Custo WHERE ID_CENTRO_CUSTO = @CC);
DELETE @g;
INSERT @g EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = @Celso, @IdCentroCusto = @CC, @IdEmpresa = @E, @Codigo = 'TST04E', @Descricao = N'Obra Teste 04e', @Tipo = 'OBRA', @IdContaBancariaPadrao = @C2;
INSERT @r SELECT N'sem @MexerEncerramento: data mantida', N'2026-12-01', (SELECT CONVERT(NVARCHAR(10), DT_ENCERRAMENTO, 23) FROM CAD.Centro_Custo WHERE ID_CENTRO_CUSTO = @CC);
DELETE @g;
INSERT @g EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = @Celso, @IdCentroCusto = @CC, @IdEmpresa = @E, @Codigo = 'TST04E', @Descricao = N'Obra Teste 04e', @Tipo = 'OBRA', @MexerEncerramento = 1;
INSERT @r SELECT N'com @MexerEncerramento e NULL: reabre o centro', N'S', CASE WHEN (SELECT DT_ENCERRAMENTO FROM CAD.Centro_Custo WHERE ID_CENTRO_CUSTO = @CC) IS NULL THEN N'S' ELSE N'N' END;
IF @E2 IS NOT NULL
BEGIN
    DECLARE @ContaE2 INT = (SELECT TOP 1 ID_CONTA FROM BANCO.Conta WHERE ID_EMPRESA = @E2 AND ATIVO = 1);
    DELETE @g;
    INSERT @g EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = @Celso, @IdCentroCusto = @CC, @IdEmpresa = @E, @Codigo = 'TST04E', @Descricao = N'Obra Teste 04e', @Tipo = 'OBRA',
         @IdContaBancariaPadrao = @ContaE2;
    INSERT @r SELECT N'conta padrão de outra empresa recusada no centro', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
END
ELSE INSERT @r VALUES (N'conta padrão de outra empresa recusada no centro', N'0', N'0');
SET @CC2 = (SELECT TOP 1 l.ID_CENTRO_CUSTO FROM FIN.Lancamento l);
IF @CC2 IS NOT NULL AND @E2 IS NOT NULL
BEGIN
    DECLARE @CodCC2 VARCHAR(20), @DescCC2 NVARCHAR(100), @TipoCC2 VARCHAR(15), @EmpCC2 INT;
    SELECT @CodCC2 = CODIGO, @DescCC2 = DESCRICAO, @TipoCC2 = TIPO, @EmpCC2 = ID_EMPRESA FROM CAD.Centro_Custo WHERE ID_CENTRO_CUSTO = @CC2;
    DELETE @g;
    INSERT @g EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = @Celso, @IdCentroCusto = @CC2, @IdEmpresa = @E, @Codigo = @CodCC2, @Descricao = @DescCC2, @Tipo = @TipoCC2;
    INSERT @r SELECT N'centro com lançamento não muda de empresa', N'0', (SELECT CAST(SUCESSO AS NVARCHAR(1)) FROM @g);
END
ELSE INSERT @r VALUES (N'centro com lançamento não muda de empresa', N'0', N'0'); -- banco sem lançamentos (ensaio)
INSERT @r SELECT N'Centro_Obter devolve as colunas novas', N'4', CAST(COUNT(*) AS NVARCHAR(5))
       FROM sys.dm_exec_describe_first_result_set(N'EXEC CAD.CAD_Centro_Custo_Obter @IdUsuario = 1, @IdCentroCusto = 1', NULL, 0)
       WHERE name IN ('DT_ENCERRAMENTO', 'ENCERRADO', 'QTD_LANCAMENTOS', 'NA_LIXEIRA');

-- seletor
DECLARE @s TABLE (ID INT, CODIGO VARCHAR(20), DESCRICAO NVARCHAR(100), COMPLEMENTO NVARCHAR(400), ATIVO BIT);
INSERT @s EXEC CAD.CAD_Seletor_Listar @IdUsuario = @Celso, @Tipo = 'CENTRO', @Busca = N'teste 04', @IdEmpresa = @E;
INSERT @r SELECT N'seletor de centro acha por parte da descrição', N'TST04E', (SELECT TOP 1 CODIGO FROM @s);
DELETE @s;
INSERT @s EXEC CAD.CAD_Seletor_Listar @IdUsuario = @Celso, @Tipo = 'CONTA', @Busca = N'conta teste', @IdEmpresa = @E;
INSERT @r SELECT N'seletor de conta acha sem acento/maiúsculas', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM @s WHERE ID = @C;
DELETE @s;
UPDATE CAD.Centro_Custo SET ATIVO = 0 WHERE ID_CENTRO_CUSTO = @CC;
INSERT @s EXEC CAD.CAD_Seletor_Listar @IdUsuario = @Celso, @Tipo = 'CENTRO', @Busca = N'teste 04', @IdEmpresa = @E;
INSERT @r SELECT N'seletor não mostra centro inativo', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @s;
DELETE @s;
INSERT @s EXEC CAD.CAD_Seletor_Listar @IdUsuario = @Celso, @Tipo = 'CENTRO', @Busca = N'xyz', @IdAtual = @CC;
INSERT @r SELECT N'seletor devolve o valor atual mesmo inativo', N'1', CAST(COUNT(*) AS NVARCHAR(5)) FROM @s WHERE ID = @CC AND ATIVO = 0;
DELETE @s;
IF EXISTS (SELECT 1 FROM CAD.Plano_Conta WHERE ATIVO = 1)
BEGIN
    INSERT @s EXEC CAD.CAD_Seletor_Listar @IdUsuario = @Celso, @Tipo = 'PLANO';
    INSERT @r SELECT N'seletor do plano: código no formato 00.00.000', N'0', CAST(COUNT(*) AS NVARCHAR(5)) FROM @s WHERE CODIGO NOT LIKE '[0-9][0-9].[0-9][0-9].[0-9][0-9][0-9]';
END
ELSE INSERT @r VALUES (N'seletor do plano: código no formato 00.00.000', N'0', N'0');
BEGIN TRY
    DELETE @s;
    INSERT @s EXEC CAD.CAD_Seletor_Listar @IdUsuario = @Celso, @Tipo = 'X';
    INSERT @r VALUES (N'seletor recusa tipo inválido', N'erro', N'sem erro');
END TRY
BEGIN CATCH
    INSERT @r VALUES (N'seletor recusa tipo inválido', N'erro', N'erro');
END CATCH;
INSERT @r SELECT N'parâmetros novos da 04e', N'2', CAST(COUNT(*) AS NVARCHAR(5)) FROM SIS.Parametro WHERE CHAVE IN ('CENTRO_ENCERRADO_BLOQUEIA', 'SELETOR_LIMITE');
ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
