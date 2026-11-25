/*******************************************************************************
  Teste       : 04e - cadastros-base: empresas (rodapé dos e-mails, pasta do OFX,
                conta padrão da própria empresa), contas bancárias (travas com
                movimento e mês fechado); depois centros de custo e plano de contas.
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 25/11/2026 (v1.0, parte A). Roda no SISTEMACMJ_LOCAL e no banco do MASTER.
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
ROLLBACK;

SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHOU' END AS RESULTADO FROM @r;
SELECT SUM(CASE WHEN ESPERADO = OBTIDO THEN 1 ELSE 0 END) AS OK, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHOU FROM @r;
