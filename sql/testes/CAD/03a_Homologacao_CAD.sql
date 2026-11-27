/*******************************************************************************
  Homologação : etapa 03a, cadastros CAD + BANCO (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Testa objetos e cargas da 03a, conferência de CPF/CNPJ
                (inclusive o CNPJ alfanumérico), módulo desabilitado,
                bancos, empresas, contas, centros de custo, pessoas (com
                contatos, vínculos e dados bancários em JSON, documento
                repetido só avisa, lista que tira contato desativa),
                lista com CPF mascarado, plano de contas (numeração
                automática, código 97.1.01, desativar grupo esconde as
                contas), auditoria e log de erros.
                Cada teste mostra ESPERADO x OBTIDO e RESULTADO (OK/FALHOU).
                Dados de teste (nomes "HML 03a", banco 999, grupo 97,
                centros HML-*) são apagados no fim; a habilitação dos
                módulos CAD e BANCO e das 6 telas volta ao que era.
                Aborta se não estiver no SISTEMACMJ_LOCAL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - Contagens de tabelas e triggers sem as tabelas do BANCO
                        criadas na 03c (movimento e extrato).
    v1.3 (25/11/2026) - Etapa 04d: colunas novas do CAD_Pessoa_Obter/Listar e limpeza de CAD.Pessoa_Tipo.
    v1.4 (25/11/2026) - Etapa 04e: colunas novas do CAD_Centro_Custo_Listar (encerramento) e do CAD_Plano_Conta_Listar (QTD_LANCAMENTOS).
    v1.5 (27/11/2026) - Etapa 04h1: contagens de estrutura atualizadas com o que a 04g
                        criou no BANCO (Caixa_Fechamento e a trigger dela, 5 procedures
                        de extrato, saldos e caixa, 3 telas novas).
    v1.2 (22/11/2026) - Etapa 04b: coluna NA_LIXEIRA do CAD_Pessoa_Obter e ações
                        DESATIVAR (5 telas) e DESFAZER (6 telas): 40.

  Como rodar: SSMS > Arquivo > Abrir > este arquivo > F5.
  Copiar para o Claude: a grade "RESUMO" e, se houver falha, a grade "TESTES".
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Este teste só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

SET NOCOUNT ON;

-- Restos de um teste anterior
UPDATE CAD.Empresa SET ID_CONTA_BANCARIA_PADRAO = NULL WHERE RAZAO_SOCIAL LIKE N'HML 03a%';
DELETE d FROM CAD.Pessoa_Dado_Bancario d INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = d.ID_PESSOA WHERE p.NOME LIKE N'HML 03a%';
DELETE c FROM CAD.Pessoa_Contato c INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = c.ID_PESSOA WHERE p.NOME LIKE N'HML 03a%';
DELETE v FROM CAD.Pessoa_Vinculo v INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = v.ID_PESSOA OR p.ID_PESSOA = v.ID_PESSOA_VINCULADA WHERE p.NOME LIKE N'HML 03a%';
DELETE x FROM CAD.Pessoa_Tipo x INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = x.ID_PESSOA WHERE p.NOME LIKE N'HML 03a%';
DELETE FROM CAD.Pessoa WHERE NOME LIKE N'HML 03a%';
DELETE FROM CAD.Centro_Custo WHERE CODIGO LIKE 'HML-%';
DELETE c FROM BANCO.Conta c INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = c.ID_EMPRESA WHERE e.RAZAO_SOCIAL LIKE N'HML 03a%';
DELETE FROM CAD.Empresa WHERE RAZAO_SOCIAL LIKE N'HML 03a%';
DELETE FROM BANCO.Banco WHERE CODIGO = '999';
DELETE c FROM CAD.Plano_Conta c INNER JOIN CAD.Plano_Subgrupo s ON s.ID_PLANO_SUBGRUPO = c.ID_PLANO_SUBGRUPO INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO WHERE g.DESCRICAO LIKE N'HML 03a%';
DELETE s FROM CAD.Plano_Subgrupo s INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO WHERE g.DESCRICAO LIKE N'HML 03a%';
DELETE FROM CAD.Plano_Grupo WHERE DESCRICAO LIKE N'HML 03a%';

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
DROP TABLE IF EXISTS #Hab;
DROP TABLE IF EXISTS #PesLista;
DROP TABLE IF EXISTS #PesObter;
DROP TABLE IF EXISTS #CcLista;
DROP TABLE IF EXISTS #Plano;

CREATE TABLE #Teste    (ID INT IDENTITY(1,1), TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));
CREATE TABLE #Ret      (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
CREATE TABLE #Hab      (TIPO CHAR(1), CODIGO VARCHAR(40), HABILITADO BIT);
CREATE TABLE #PesLista (ID_PESSOA INT, TIPO_PESSOA CHAR(1), NOME NVARCHAR(150), NOME_FANTASIA NVARCHAR(100), DOCUMENTO VARCHAR(20),
                        CLIENTE BIT, FORNECEDOR BIT, FUNCIONARIO BIT, CORRETOR BIT, CIDADE NVARCHAR(60), UF CHAR(2),
                        EMAIL_PRINCIPAL NVARCHAR(256), TELEFONE_PRINCIPAL NVARCHAR(256), ATIVO BIT, DT_ALTERACAO DATETIME2(0), USUARIO_ALTERACAO NVARCHAR(100),
                        TIPOS NVARCHAR(1000), APTO_COBRANCA BIT, PENDENCIA_COBRANCA NVARCHAR(400), TITULO_ABERTO BIT);
CREATE TABLE #PesObter (ID_PESSOA INT, TIPO_PESSOA CHAR(1), NOME NVARCHAR(150), NOME_FANTASIA NVARCHAR(100), CPF_CNPJ VARCHAR(14), DOCUMENTO_FORMATADO VARCHAR(20),
                        RG VARCHAR(20), ORGAO_EMISSOR VARCHAR(20), INSCRICAO_ESTADUAL VARCHAR(20), INSCRICAO_MUNICIPAL VARCHAR(20), DT_NASCIMENTO DATE,
                        NACIONALIDADE NVARCHAR(40), PROFISSAO NVARCHAR(60), ESTADO_CIVIL VARCHAR(15), REGIME_BENS VARCHAR(25), CEP VARCHAR(8),
                        LOGRADOURO NVARCHAR(150), NUMERO NVARCHAR(20), COMPLEMENTO NVARCHAR(60), BAIRRO NVARCHAR(60), CIDADE NVARCHAR(60), UF CHAR(2),
                        CLIENTE BIT, FORNECEDOR BIT, FUNCIONARIO BIT, CORRETOR BIT, OBSERVACAO NVARCHAR(2000), ATIVO BIT, CODIGO_ACCESS INT,
                        DT_CRIACAO DATETIME2(0), USUARIO_CRIACAO NVARCHAR(100), DT_ALTERACAO DATETIME2(0), USUARIO_ALTERACAO NVARCHAR(100), NA_LIXEIRA BIT,
                        ID_PLANO_CONTA_PADRAO INT, ID_CENTRO_CUSTO_PADRAO INT, PLANO_CONTA_PADRAO NVARCHAR(200), CENTRO_CUSTO_PADRAO NVARCHAR(200),
                        APTO_COBRANCA BIT, PENDENCIA_COBRANCA NVARCHAR(400), TIPOS NVARCHAR(MAX),
                        DOCUMENTO_REPETIDO INT, CONTATOS NVARCHAR(MAX), VINCULOS NVARCHAR(MAX), DADOS_BANCARIOS NVARCHAR(MAX));
CREATE TABLE #CcLista  (ID_CENTRO_CUSTO INT, CODIGO VARCHAR(20), DESCRICAO NVARCHAR(100), TIPO VARCHAR(15), CONTABIL BIT, ID_EMPRESA INT,
                        EMPRESA_RAZAO_SOCIAL NVARCHAR(150), EMPRESA_NOME_FANTASIA NVARCHAR(100), ID_CONTA_BANCARIA_PADRAO INT, CONTA_PADRAO_DESCRICAO NVARCHAR(60),
                        ID_CONTA_EFETIVA INT, CONTA_EFETIVA_DESCRICAO NVARCHAR(60), DT_ENCERRAMENTO DATE, ENCERRADO BIT,
                        ATIVO BIT, CODIGO_ACCESS INT, DT_ALTERACAO DATETIME2(0), USUARIO_ALTERACAO NVARCHAR(100));
CREATE TABLE #Plano    (NIVEL TINYINT, ID INT, ID_PAI INT, NUMERO SMALLINT, CODIGO VARCHAR(12), DESCRICAO NVARCHAR(80), TIPO VARCHAR(15), CUSTO_OBRA BIT,
                        CONTABIL BIT, CONTA_CONTABIL_REF VARCHAR(30), ORDEM SMALLINT, ATIVO BIT, ATIVO_EFETIVO BIT, ORDEM_ARVORE VARCHAR(12),
                        DT_ALTERACAO DATETIME2(0), USUARIO_ALTERACAO NVARCHAR(100), QTD_LANCAMENTOS INT);

DECLARE @IdCelso    INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
DECLARE @AudInicio  BIGINT = ISNULL((SELECT MAX(a.ID_AUDITORIA) FROM SIS.Auditoria a), 0);
DECLARE @ErroInicio BIGINT = ISNULL((SELECT MAX(e.ID_LOG_ERRO) FROM SIS.Log_Erro e), 0);
DECLARE @IdBanco    INT;
DECLARE @IdBanco748 INT = (SELECT b.ID_BANCO FROM BANCO.Banco b WHERE b.CODIGO = '748');
DECLARE @IdEmpA     INT;
DECLARE @IdEmpB     INT;
DECLARE @IdContaCC  INT;
DECLARE @IdContaCx  INT;
DECLARE @IdCc       INT;
DECLARE @IdPesA     INT;
DECLARE @IdPesB     INT;
DECLARE @IdContato1 INT;
DECLARE @IdGrupo    INT;
DECLARE @IdSub1     INT;
DECLARE @IdSub2     INT;
DECLARE @IdConta1   INT;
DECLARE @Json       NVARCHAR(MAX);
DECLARE @QtdAntes   INT;

-- Habilitação original (volta no fim)
INSERT INTO #Hab (TIPO, CODIGO, HABILITADO)
SELECT 'M', m.CODIGO, m.HABILITADO FROM SIS.Modulo m WHERE m.CODIGO IN ('CAD', 'BANCO')
UNION ALL
SELECT 'I', i.CODIGO, i.HABILITADO FROM SIS.Item i WHERE i.CODIGO IN ('CAD_EMPRESA', 'CAD_PESSOA', 'CAD_CENTRO_CUSTO', 'CAD_PLANO_CONTA', 'BANCO_CONTA', 'BANCO_BANCO');

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-03A', @Origem = N'teste-03a';

-- 1) Objetos e cargas
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Tabelas CAD + BANCO (15 desde a 04g)', N'15', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.tables t WHERE SCHEMA_NAME(t.schema_id) IN ('CAD', 'BANCO')
                                                    AND t.name NOT IN ('Movimento', 'Extrato_Arquivo', 'Extrato_Linha')))),
 (N'Procedures CAD + BANCO (33 desde a 04g)', N'33', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.procedures p WHERE SCHEMA_NAME(p.schema_id) IN ('CAD', 'BANCO')))),
 (N'Functions + view do CAD', N'3|1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.objects o WHERE SCHEMA_NAME(o.schema_id) = 'CAD' AND o.type = 'FN')) + N'|'
                                    + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.views v WHERE SCHEMA_NAME(v.schema_id) = 'CAD'))),
 (N'Triggers de auditoria CAD + BANCO (14 desde a 04g)', N'14', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.triggers t INNER JOIN sys.tables b ON b.object_id = t.parent_id
                                                                      WHERE SCHEMA_NAME(b.schema_id) IN ('CAD', 'BANCO')
                                                                        AND b.name NOT IN ('Movimento', 'Extrato_Arquivo', 'Extrato_Linha')))),
 (N'FK da conta padrão da empresa', N'1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.foreign_keys f WHERE f.name = 'FK_Empresa_Conta_Padrao'))),
 (N'Carga de bancos (Sicredi 748 e Itaú 341)', N'Sicredi|Itaú Unibanco', (SELECT b.NOME FROM BANCO.Banco b WHERE b.CODIGO = '748') + N'|' + (SELECT b.NOME FROM BANCO.Banco b WHERE b.CODIGO = '341')),
 (N'Telas no menu (CAD 5 desde a 04d, BANCO 5 desde a 04g)', N'5|5', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Item i INNER JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO WHERE m.CODIGO = 'CAD' AND i.TIPO = 'TELA')) + N'|'
                                                + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Item i INNER JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO WHERE m.CODIGO = 'BANCO' AND i.TIPO = 'TELA'))),
 (N'Ações das 6 telas (29 + DESATIVAR e DESFAZER da 04b)', N'40', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Item_Acao ia INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM
                                                      WHERE i.CODIGO IN ('CAD_EMPRESA', 'CAD_PESSOA', 'CAD_CENTRO_CUSTO', 'CAD_PLANO_CONTA', 'BANCO_CONTA', 'BANCO_BANCO'))));

-- 2) CPF / CNPJ
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'CPF válido com pontuação', N'1', CONVERT(NVARCHAR(1), CAD.fn_CAD_Documento_Valido(N'529.982.247-25'))),
 (N'CPF com dígito errado', N'0', CONVERT(NVARCHAR(1), CAD.fn_CAD_Documento_Valido(N'529.982.247-24'))),
 (N'CPF com números todos iguais', N'0', CONVERT(NVARCHAR(1), CAD.fn_CAD_Documento_Valido(N'111.111.111-11'))),
 (N'CNPJ numérico válido', N'1', CONVERT(NVARCHAR(1), CAD.fn_CAD_Documento_Valido(N'11.222.333/0001-81'))),
 (N'CNPJ alfanumérico válido (exemplo da Receita)', N'1', CONVERT(NVARCHAR(1), CAD.fn_CAD_Documento_Valido(N'12.abc.345/01de-35'))),
 (N'CNPJ alfanumérico com dígito errado', N'0', CONVERT(NVARCHAR(1), CAD.fn_CAD_Documento_Valido(N'12ABC34501DE34'))),
 (N'Documento limpo', N'12ABC34501DE35', CAD.fn_CAD_Documento_Limpo(N' 12.abc.345/01de-35 ')),
 (N'Somente dígitos', N'41999991234', CAD.fn_CAD_Somente_Digitos(N'(41) 99999-1234'));

-- 3) Módulo desabilitado: ninguém grava (nem o administrador geral)
UPDATE SIS.Modulo SET HABILITADO = 0 WHERE CODIGO = 'CAD';
INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @RazaoSocial = N'HML 03a Empresa A', @Cnpj = '11.222.333/0001-81';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Módulo CAD desabilitado recusa a gravação', N'0|Você não tem permissão para gravar empresas.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;

UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO IN ('CAD', 'BANCO');
UPDATE SIS.Item   SET HABILITADO = 1 WHERE CODIGO IN ('CAD_EMPRESA', 'CAD_PESSOA', 'CAD_CENTRO_CUSTO', 'CAD_PLANO_CONTA', 'BANCO_CONTA', 'BANCO_BANCO');

-- 4) Bancos
INSERT INTO #Ret EXEC BANCO.BANCO_Banco_Gravar @IdUsuario = @IdCelso, @Codigo = 'AB', @Nome = N'HML banco';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Banco com código inválido', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC BANCO.BANCO_Banco_Gravar @IdUsuario = @IdCelso, @Codigo = '999', @Ispb = '12.345.678', @Nome = N'HML banco';
SELECT @IdBanco = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Banco novo (ISPB só dígitos)', N'1|12345678', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + b.ISPB FROM #Ret r INNER JOIN BANCO.Banco b ON b.ID_BANCO = r.ID; DELETE FROM #Ret;
INSERT INTO #Ret EXEC BANCO.BANCO_Banco_Gravar @IdUsuario = @IdCelso, @Codigo = '999', @Nome = N'HML banco 2';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Banco com código repetido', N'0|Já existe um banco com este código.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;

-- 5) Empresas
INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @RazaoSocial = N'HML 03a Empresa A', @Cnpj = '11.222.333/0001-80';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Empresa com CNPJ inválido', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @RazaoSocial = N'HML 03a Empresa A', @Cnpj = '11.222.333/0001-81', @Tipo = 'construtora',
     @Cep = '80.000-000', @Uf = 'pr', @Email = N'Contato@HML.com.br', @RegimeTributario = 'LUCRO_PRESUMIDO';
SELECT @IdEmpA = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Empresa A gravada (normaliza CNPJ, CEP, UF, tipo, e-mail)', N'1|11222333000181|80000000|PR|CONSTRUTORA|contato@hml.com.br',
       CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + e.CNPJ + N'|' + e.CEP + N'|' + e.UF + N'|' + e.TIPO + N'|' + e.EMAIL
FROM #Ret r INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = r.ID; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @RazaoSocial = N'HML 03a Empresa repetida', @Cnpj = '11222333000181';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Empresa com CNPJ repetido', N'0|Já existe uma empresa cadastrada com este CNPJ.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @RazaoSocial = N'HML 03a SPE B', @Cnpj = '12.ABC.345/01DE-35', @Tipo = 'SPE';
SELECT @IdEmpB = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Empresa B com CNPJ alfanumérico', N'1', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 6) Contas
INSERT INTO #Ret EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @Descricao = N'Sicredi HML', @Tipo = 'CORRENTE';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Conta corrente sem banco', N'0|Escolha o banco da conta.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @Descricao = N'Sicredi HML', @Tipo = 'CORRENTE', @IdBanco = @IdBanco748,
     @Agencia = '0217', @Numero = '73.623', @NumeroDv = '5', @SaldoInicial = 1000.50;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Saldo inicial sem data', N'0|Informe a data do saldo inicial.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @Descricao = N'Sicredi HML', @Tipo = 'CORRENTE', @IdBanco = @IdBanco748,
     @Agencia = '0217', @Numero = '73.623', @NumeroDv = '5', @SaldoInicial = 1000.50, @DtSaldoInicial = '2026-11-01', @Concilia = 1;
SELECT @IdContaCC = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Conta corrente gravada (número só dígitos)', N'1|73623|5|1000.50', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + c.NUMERO + N'|' + c.NUMERO_DV + N'|' + CONVERT(NVARCHAR(20), c.SALDO_INICIAL)
FROM #Ret r INNER JOIN BANCO.Conta c ON c.ID_CONTA = r.ID; DELETE FROM #Ret;
INSERT INTO #Ret EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @Descricao = N'Caixa HML', @Tipo = 'CAIXA', @IdBanco = @IdBanco748, @Agencia = '1';
SELECT @IdContaCx = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Caixa gravado sem banco (banco informado é ignorado)', N'1|S', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + CASE WHEN c.ID_BANCO IS NULL AND c.AGENCIA = '' THEN N'S' ELSE N'N' END
FROM #Ret r INNER JOIN BANCO.Conta c ON c.ID_CONTA = r.ID; DELETE FROM #Ret;
INSERT INTO #Ret EXEC BANCO.BANCO_Conta_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @Descricao = N'Caixa HML', @Tipo = 'CAIXA';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Conta com descrição repetida na empresa', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @RazaoSocial = N'HML 03a Empresa A', @Cnpj = '11222333000181',
     @Tipo = 'CONSTRUTORA', @IdContaBancariaPadrao = @IdContaCC;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Empresa A com conta padrão', N'1|S', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + CASE WHEN e.ID_CONTA_BANCARIA_PADRAO = @IdContaCC THEN N'S' ELSE N'N' END
FROM #Ret r INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = r.ID; DELETE FROM #Ret;

-- 7) Centros de custo
INSERT INTO #Ret EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @Codigo = 'hml-01', @Descricao = N'HML obra 01', @Tipo = 'obra';
SELECT @IdCc = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Centro de custo gravado (código em maiúsculas)', N'1|HML-01|OBRA|1', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + c.CODIGO + N'|' + c.TIPO + N'|' + CONVERT(NVARCHAR(1), c.CONTABIL)
FROM #Ret r INNER JOIN CAD.Centro_Custo c ON c.ID_CENTRO_CUSTO = r.ID; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @Codigo = 'HML-01', @Descricao = N'HML outra', @Tipo = 'OBRA';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Centro de custo com código repetido', N'0|Já existe um centro de custo com este código.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Centro_Custo_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA, @Codigo = 'HML-02', @Descricao = N'HML outra', @Tipo = 'LOJA';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Centro de custo com tipo inválido', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #CcLista EXEC CAD.CAD_Centro_Custo_Listar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Centro sem conta usa a conta da empresa', N'Sicredi HML', CONTA_EFETIVA_DESCRICAO FROM #CcLista WHERE ID_CENTRO_CUSTO = @IdCc;

-- 8) Desativar
INSERT INTO #Ret EXEC CAD.CAD_Empresa_Excluir @IdUsuario = @IdCelso, @IdEmpresa = @IdEmpA;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Não desativa empresa com conta/centro ativo', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC BANCO.BANCO_Conta_Excluir @IdUsuario = @IdCelso, @IdConta = @IdContaCC;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Não desativa a conta padrão da empresa', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Centro_Custo_Excluir @IdUsuario = @IdCelso, @IdCentroCusto = @IdCc;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Desativar o centro de custo', N'1|0', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + CONVERT(NVARCHAR(1), (SELECT c.ATIVO FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCc)) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Centro_Custo_Excluir @IdUsuario = @IdCelso, @IdCentroCusto = @IdCc;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Desativar de novo é recusado', N'0|O registro já está desativado.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Centro_Custo_Excluir @IdUsuario = @IdCelso, @IdCentroCusto = @IdCc, @Reativar = 1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Reativar o centro de custo', N'1|1', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + CONVERT(NVARCHAR(1), (SELECT c.ATIVO FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCc)) FROM #Ret; DELETE FROM #Ret;

-- 9) Pessoas
INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @TipoPessoa = 'F', @Nome = N'HML 03a Maria', @CpfCnpj = '529.982.247-24', @Cliente = 1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Pessoa com CPF inválido', N'0|CPF inválido. Confira os números.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @TipoPessoa = 'F', @Nome = N'HML 03a Maria', @CpfCnpj = '529.982.247-25';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Pessoa sem nenhum papel nasce N/A (04d)', N'1|NA', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + ISNULL((SELECT STRING_AGG(t.CODIGO, ',') FROM CAD.Pessoa_Tipo x JOIN CAD.Parceiro_Tipo t ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO WHERE x.ID_PESSOA = r.ID AND x.ATIVO = 1), N'') FROM #Ret r;
DELETE x FROM CAD.Pessoa_Tipo x INNER JOIN #Ret r ON r.ID = x.ID_PESSOA; DELETE p FROM CAD.Pessoa p INNER JOIN #Ret r ON r.ID = p.ID_PESSOA; DELETE FROM #Ret;

SET @QtdAntes = (SELECT COUNT(*) FROM CAD.Pessoa p WHERE p.NOME LIKE N'HML 03a%');
INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @TipoPessoa = 'F', @Nome = N'HML 03a Maria', @CpfCnpj = '529.982.247-25', @Cliente = 1,
     @Contatos = N'[{"tipo":"EMAIL","valor":"maria@hml.com.br","principal":true},{"tipo":"EMAIL","valor":"maria@@hml"}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Contato com e-mail inválido: recusa com a linha e nada é gravado', N'0|Contato 2: e-mail inválido.|0',
       CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM + N'|' + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Pessoa p WHERE p.NOME LIKE N'HML 03a%') - @QtdAntes) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @TipoPessoa = 'F', @Nome = N'HML 03a Maria', @CpfCnpj = '529.982.247-25', @Cliente = 1,
     @Cep = '80000-000', @Cidade = N'Curitiba', @Uf = 'PR', @EstadoCivil = 'CASADO', @RegimeBens = 'COMUNHAO_PARCIAL',
     @Contatos = N'[{"tipo":"EMAIL","valor":"Maria@HML.com.br","nome":"pessoal","principal":true,"recebeCobranca":true},{"tipo":"CELULAR","valor":"(41) 99999-1234"}]',
     @DadosBancarios = N'[{"tipo":"TED","idBanco":0,"agencia":"0217","conta":"12345","contaDv":"6","tipoConta":"CORRENTE","principal":true},
                          {"tipo":"PIX","pixTipo":"EMAIL","pixChave":"Maria@HML.com.br"}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'TED sem banco válido', N'0|Dado bancário 1: escolha o banco.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;

SET @Json = N'[{"tipo":"TED","idBanco":' + CONVERT(NVARCHAR(10), @IdBanco748) + N',"agencia":"0217","conta":"12.345","contaDv":"6","tipoConta":"CORRENTE","principal":true},
              {"tipo":"PIX","pixTipo":"EMAIL","pixChave":"Maria@HML.com.br"}]';
INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @TipoPessoa = 'F', @Nome = N'HML 03a Maria', @CpfCnpj = '529.982.247-25', @Cliente = 1,
     @Cep = '80000-000', @Cidade = N'Curitiba', @Uf = 'PR', @EstadoCivil = 'CASADO', @RegimeBens = 'COMUNHAO_PARCIAL',
     @Contatos = N'[{"tipo":"EMAIL","valor":"Maria@HML.com.br","nome":"pessoal","principal":true,"recebeCobranca":true},{"tipo":"CELULAR","valor":"(41) 99999-1234"}]',
     @DadosBancarios = @Json;
SELECT @IdPesA = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Pessoa A com 2 contatos, TED e PIX', N'1|2|2|41999991234|12345|maria@hml.com.br',
       CONVERT(NVARCHAR(1), r.SUCESSO) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = r.ID AND c.ATIVO = 1)) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Pessoa_Dado_Bancario d WHERE d.ID_PESSOA = r.ID AND d.ATIVO = 1)) + N'|'
     + (SELECT c.VALOR FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = r.ID AND c.TIPO = 'CELULAR') + N'|'
     + (SELECT d.CONTA FROM CAD.Pessoa_Dado_Bancario d WHERE d.ID_PESSOA = r.ID AND d.TIPO = 'TED') + N'|'
     + (SELECT d.PIX_CHAVE FROM CAD.Pessoa_Dado_Bancario d WHERE d.ID_PESSOA = r.ID AND d.TIPO = 'PIX')
FROM #Ret r; DELETE FROM #Ret;

INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @TipoPessoa = 'F', @Nome = N'HML 03a Joao', @CpfCnpj = '52998224725', @Cliente = 1;
SELECT @IdPesB = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'CPF repetido grava e só avisa', N'1|S', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + CASE WHEN MENSAGEM LIKE N'%Atenção%1 outra(s) pessoa(s)%' THEN N'S' ELSE N'N' END FROM #Ret; DELETE FROM #Ret;

SET @IdContato1 = (SELECT c.ID_PESSOA_CONTATO FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = @IdPesA AND c.TIPO = 'EMAIL');
SET @Json = N'[{"id":' + CONVERT(NVARCHAR(10), @IdContato1) + N',"tipo":"EMAIL","valor":"maria@hml.com.br","principal":true,"recebeCobranca":true}]';
INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @IdPessoa = @IdPesA, @TipoPessoa = 'F', @Nome = N'HML 03a Maria', @CpfCnpj = '529.982.247-25',
     @Cliente = 1, @Contatos = @Json, @Vinculos = N'[{"idPessoaVinculada":0,"tipo":"CONJUGE"}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Vínculo com pessoa inexistente', N'0|Vínculo 1: pessoa vinculada não encontrada.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @IdPessoa = @IdPesA, @TipoPessoa = 'F', @Nome = N'HML 03a Maria', @CpfCnpj = '529.982.247-25',
     @Cliente = 1, @Contatos = @Json, @DadosBancarios = N'[{"tipo":"PIX","pixTipo":"ALEATORIA","pixChave":"123"}]';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Chave PIX aleatória inválida', N'0|Dado bancário 1: chave PIX aleatória inválida.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;

SET @Json = N'[{"id":' + CONVERT(NVARCHAR(10), @IdContato1) + N',"tipo":"EMAIL","valor":"maria@hml.com.br","principal":true,"recebeCobranca":true}]';
DECLARE @JsonV NVARCHAR(MAX) = N'[{"idPessoaVinculada":' + CONVERT(NVARCHAR(10), @IdPesB) + N',"tipo":"CONJUGE"}]';
INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Gravar @IdUsuario = @IdCelso, @IdPessoa = @IdPesA, @TipoPessoa = 'F', @Nome = N'HML 03a Maria', @CpfCnpj = '529.982.247-25',
     @Cliente = 1, @Contatos = @Json, @Vinculos = @JsonV;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Lista sem o celular: celular desativado, vínculo gravado, bancários intocados (NULL)', N'1|1|2|1|2',
       CONVERT(NVARCHAR(1), r.SUCESSO) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = @IdPesA AND c.ATIVO = 1)) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = @IdPesA)) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Pessoa_Vinculo v WHERE v.ID_PESSOA = @IdPesA AND v.ATIVO = 1)) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Pessoa_Dado_Bancario d WHERE d.ID_PESSOA = @IdPesA AND d.ATIVO = 1))
FROM #Ret r; DELETE FROM #Ret;

INSERT INTO #PesObter EXEC CAD.CAD_Pessoa_Obter @IdUsuario = @IdCelso, @IdPessoa = @IdPesA;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Obter: CPF completo, documento repetido, listas em JSON', N'529.982.247-25|1|1|CONJUGE|2',
       DOCUMENTO_FORMATADO + N'|' + CONVERT(NVARCHAR(5), DOCUMENTO_REPETIDO) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM OPENJSON(CONTATOS))) + N'|'
     + JSON_VALUE(VINCULOS, '$[0].tipo') + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM OPENJSON(DADOS_BANCARIOS)))
FROM #PesObter;

INSERT INTO #PesLista EXEC CAD.CAD_Pessoa_Listar @IdUsuario = @IdCelso, @Busca = N'hml 03a';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Lista por parte do nome, CPF mascarado', N'2|***.982.247-**|maria@hml.com.br',
       CONVERT(NVARCHAR(5), COUNT(*)) + N'|' + MAX(CASE WHEN ID_PESSOA = @IdPesA THEN DOCUMENTO END) + N'|' + MAX(CASE WHEN ID_PESSOA = @IdPesA THEN EMAIL_PRINCIPAL END)
FROM #PesLista; DELETE FROM #PesLista;
INSERT INTO #PesLista EXEC CAD.CAD_Pessoa_Listar @IdUsuario = @IdCelso, @Busca = N'529.982';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Lista pelo início do CPF', N'2', CONVERT(NVARCHAR(5), COUNT(*)) FROM #PesLista WHERE NOME LIKE N'HML 03a%'; DELETE FROM #PesLista;

INSERT INTO #Ret EXEC CAD.CAD_Pessoa_Excluir @IdUsuario = @IdCelso, @IdPessoa = @IdPesB;
INSERT INTO #PesLista EXEC CAD.CAD_Pessoa_Listar @IdUsuario = @IdCelso, @Busca = N'hml 03a';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Pessoa desativada some da lista de ativos', N'1|1', CONVERT(NVARCHAR(1), (SELECT SUCESSO FROM #Ret)) + N'|' + CONVERT(NVARCHAR(5), COUNT(*)) FROM #PesLista;
DELETE FROM #PesLista; DELETE FROM #Ret;

-- 10) Plano de contas
INSERT INTO #Ret EXEC CAD.CAD_Plano_Grupo_Gravar @IdUsuario = @IdCelso, @Numero = 97, @Descricao = N'HML 03a Receitas', @Tipo = 'receita';
SELECT @IdGrupo = ID FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Grupo 97 gravado', N'1|RECEITA', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + g.TIPO FROM #Ret r INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = r.ID; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Grupo_Gravar @IdUsuario = @IdCelso, @Numero = 97, @Descricao = N'HML 03a Outro', @Tipo = 'DESPESA';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Grupo com número repetido', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Grupo_Gravar @IdUsuario = @IdCelso, @Numero = 96, @Descricao = N'HML 03a Receitas', @Tipo = 'DESPESA';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Grupo com descrição repetida', N'0|Já existe um grupo com esta descrição.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Grupo_Gravar @IdUsuario = @IdCelso, @Numero = 96, @Descricao = N'HML 03a Outro', @Tipo = 'CUSTO';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Grupo com tipo inválido', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC CAD.CAD_Plano_Subgrupo_Gravar @IdUsuario = @IdCelso, @IdPlanoGrupo = @IdGrupo, @Descricao = N'Vendas de imóveis';
SELECT @IdSub1 = ID FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Subgrupo_Gravar @IdUsuario = @IdCelso, @IdPlanoGrupo = @IdGrupo, @Descricao = N'Aluguéis';
SELECT @IdSub2 = ID FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Subgrupos numerados sozinhos', N'1|2', CONVERT(NVARCHAR(5), (SELECT s.NUMERO FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @IdSub1)) + N'|'
                                              + CONVERT(NVARCHAR(5), (SELECT s.NUMERO FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @IdSub2));

INSERT INTO #Ret EXEC CAD.CAD_Plano_Conta_Gravar @IdUsuario = @IdCelso, @IdPlanoSubgrupo = @IdSub1, @Descricao = N'Venda de unidades', @Contabil = 1;
SELECT @IdConta1 = ID FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Conta_Gravar @IdUsuario = @IdCelso, @IdPlanoSubgrupo = @IdSub1, @Descricao = N'Juros e multas recebidos';
DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Conta_Gravar @IdUsuario = @IdCelso, @IdPlanoSubgrupo = @IdSub1, @Descricao = N'Venda de unidades';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Conta com descrição repetida no subgrupo', N'0|Já existe uma conta com esta descrição neste subgrupo.', CONVERT(NVARCHAR(1), SUCESSO) + N'|' + MENSAGEM FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Conta_Gravar @IdUsuario = @IdCelso, @IdPlanoSubgrupo = @IdSub2, @Descricao = N'Venda de unidades';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Mesma descrição em outro subgrupo é aceita', N'1', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Conta_Gravar @IdUsuario = @IdCelso, @IdPlanoSubgrupo = @IdSub1, @Numero = 1, @Descricao = N'Outra conta';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Conta com número em uso', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Código da conta na árvore (view)', N'97.1.01|97.1.02|RECEITA|1',
       (SELECT v.CODIGO FROM CAD.vw_CAD_Plano_Conta v WHERE v.ID_PLANO_CONTA = @IdConta1) + N'|'
     + (SELECT v.CODIGO FROM CAD.vw_CAD_Plano_Conta v WHERE v.ID_PLANO_SUBGRUPO = @IdSub1 AND v.NUMERO_CONTA = 2) + N'|'
     + (SELECT v.TIPO FROM CAD.vw_CAD_Plano_Conta v WHERE v.ID_PLANO_CONTA = @IdConta1) + N'|'
     + CONVERT(NVARCHAR(1), (SELECT v.CONTABIL FROM CAD.vw_CAD_Plano_Conta v WHERE v.ID_PLANO_CONTA = @IdConta1));

INSERT INTO #Plano EXEC CAD.CAD_Plano_Conta_Listar @IdUsuario = @IdCelso;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Árvore do grupo 97: 1 grupo + 2 subgrupos + 3 contas, na ordem', N'6|97|97.1|97.1.01',
       CONVERT(NVARCHAR(5), COUNT(*)) + N'|'
     + MAX(CASE WHEN NIVEL = 1 THEN CODIGO END) + N'|'
     + MIN(CASE WHEN NIVEL = 2 THEN CODIGO END) + N'|'
     + MIN(CASE WHEN NIVEL = 3 THEN CODIGO END)
FROM #Plano WHERE ORDEM_ARVORE LIKE '97.%'; DELETE FROM #Plano;

INSERT INTO #Ret EXEC CAD.CAD_Plano_Excluir @IdUsuario = @IdCelso, @Nivel = 1, @Id = @IdGrupo;
INSERT INTO #Plano EXEC CAD.CAD_Plano_Conta_Listar @IdUsuario = @IdCelso, @SomenteAtivos = 1;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Grupo desativado esconde subgrupos e contas', N'1|0|0',
       CONVERT(NVARCHAR(1), (SELECT SUCESSO FROM #Ret)) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM #Plano p WHERE p.ORDEM_ARVORE LIKE '97.%')) + N'|'
     + CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.vw_CAD_Plano_Conta v WHERE v.ID_PLANO_GRUPO = @IdGrupo AND v.ATIVO_EFETIVO = 1));
DELETE FROM #Ret; DELETE FROM #Plano;
INSERT INTO #Ret EXEC CAD.CAD_Plano_Excluir @IdUsuario = @IdCelso, @Nivel = 4, @Id = @IdGrupo;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Nível inválido', N'0', CONVERT(NVARCHAR(1), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 11) Auditoria e log de erros
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Auditoria: inclusão das pessoas (3 desde a 04d: a do caso 41 também) e alteração do celular (ATIVO)', N'3|S|S',
       CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'CAD.Pessoa' AND a.OPERACAO = 'I')) + N'|'
     + CASE WHEN EXISTS (SELECT 1 FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'CAD.Pessoa_Contato' AND a.OPERACAO = 'A' AND a.CAMPO = N'ATIVO') THEN N'S' ELSE N'N' END + N'|'
     + CASE WHEN EXISTS (SELECT 1 FROM SIS.Auditoria a WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA = N'CAD.Empresa' AND a.USUARIO = N'celso') THEN N'S' ELSE N'N' END;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Nenhum erro técnico gravado no log durante o teste', N'0', CONVERT(NVARCHAR(5), COUNT(*)) FROM SIS.Log_Erro e WHERE e.ID_LOG_ERRO > @ErroInicio;

-- 12) Limpeza
UPDATE CAD.Empresa SET ID_CONTA_BANCARIA_PADRAO = NULL WHERE RAZAO_SOCIAL LIKE N'HML 03a%';
DELETE d FROM CAD.Pessoa_Dado_Bancario d INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = d.ID_PESSOA WHERE p.NOME LIKE N'HML 03a%';
DELETE c FROM CAD.Pessoa_Contato c INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = c.ID_PESSOA WHERE p.NOME LIKE N'HML 03a%';
DELETE v FROM CAD.Pessoa_Vinculo v INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = v.ID_PESSOA OR p.ID_PESSOA = v.ID_PESSOA_VINCULADA WHERE p.NOME LIKE N'HML 03a%';
DELETE x FROM CAD.Pessoa_Tipo x INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = x.ID_PESSOA WHERE p.NOME LIKE N'HML 03a%';
DELETE FROM CAD.Pessoa WHERE NOME LIKE N'HML 03a%';
DELETE FROM CAD.Centro_Custo WHERE CODIGO LIKE 'HML-%';
DELETE c FROM BANCO.Conta c INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = c.ID_EMPRESA WHERE e.RAZAO_SOCIAL LIKE N'HML 03a%';
DELETE FROM CAD.Empresa WHERE RAZAO_SOCIAL LIKE N'HML 03a%';
DELETE FROM BANCO.Banco WHERE CODIGO = '999';
DELETE c FROM CAD.Plano_Conta c INNER JOIN CAD.Plano_Subgrupo s ON s.ID_PLANO_SUBGRUPO = c.ID_PLANO_SUBGRUPO INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO WHERE g.DESCRICAO LIKE N'HML 03a%';
DELETE s FROM CAD.Plano_Subgrupo s INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO WHERE g.DESCRICAO LIKE N'HML 03a%';
DELETE FROM CAD.Plano_Grupo WHERE DESCRICAO LIKE N'HML 03a%';

UPDATE m SET m.HABILITADO = h.HABILITADO FROM SIS.Modulo m INNER JOIN #Hab h ON h.TIPO = 'M' AND h.CODIGO = m.CODIGO WHERE m.HABILITADO <> h.HABILITADO;
UPDATE i SET i.HABILITADO = h.HABILITADO FROM SIS.Item i   INNER JOIN #Hab h ON h.TIPO = 'I' AND h.CODIGO = i.CODIGO WHERE i.HABILITADO <> h.HABILITADO;
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Limpeza: nada do teste ficou', N'0',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Pessoa p WHERE p.NOME LIKE N'HML 03a%') + (SELECT COUNT(*) FROM CAD.Empresa e WHERE e.RAZAO_SOCIAL LIKE N'HML 03a%')
                     + (SELECT COUNT(*) FROM CAD.Plano_Grupo g WHERE g.DESCRICAO LIKE N'HML 03a%') + (SELECT COUNT(*) FROM BANCO.Banco b WHERE b.CODIGO = '999'))),
 (N'Habilitação dos módulos e telas voltou ao original', N'0',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM #Hab h WHERE h.HABILITADO <> CASE h.TIPO WHEN 'M' THEN (SELECT m.HABILITADO FROM SIS.Modulo m WHERE m.CODIGO = h.CODIGO)
                                                                                             ELSE (SELECT i.HABILITADO FROM SIS.Item i WHERE i.CODIGO = h.CODIGO) END)));

-- Resultado
SELECT 'TESTES' AS GRADE, ID, TESTE, ESPERADO, OBTIDO,
       CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 'OK' ELSE 'FALHOU' END AS RESULTADO
FROM #Teste ORDER BY ID;

SELECT 'RESUMO' AS GRADE, COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste;
GO

SET NOEXEC OFF;
GO
