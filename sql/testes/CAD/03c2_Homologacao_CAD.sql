/*******************************************************************************
  Homologação : etapa 03c2, CNPJ para notas de compra e DDA na empresa e
                function de desmontar o número do plano do Access
                (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Testa CAD.Empresa v1.1 (coluna CNPJ_COMPRAS), CAD_Empresa_Gravar
                v1.1 (grava, recusa inválido e igual ao CNPJ, mantém quando não
                informado, apaga com ''), CAD_Empresa_Listar v1.1 (colunas
                novas), auditoria da coluna nova e MIG.fn_MIG_Plano_Desmontar.
                Cada teste mostra ESPERADO x OBTIDO e RESULTADO (OK/FALHOU).
                Dados de teste ("HML 03c2") apagados no fim; a habilitação do
                módulo CAD e da tela de empresas volta ao que era.
                Aborta se não estiver no SISTEMACMJ_LOCAL.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).

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

DELETE FROM CAD.Empresa WHERE RAZAO_SOCIAL LIKE N'HML 03c2%';
DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
DROP TABLE IF EXISTS #Hab;

CREATE TABLE #Teste (ID INT IDENTITY(1,1), TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));
CREATE TABLE #Ret   (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);
CREATE TABLE #Hab   (TIPO CHAR(1), CODIGO VARCHAR(40), HABILITADO BIT);

DECLARE @IdCelso    INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
DECLARE @AudInicio  BIGINT = ISNULL((SELECT MAX(a.ID_AUDITORIA) FROM SIS.Auditoria a), 0);
DECLARE @ErroInicio BIGINT = ISNULL((SELECT MAX(e.ID_LOG_ERRO) FROM SIS.Log_Erro e), 0);
DECLARE @IdEmp      INT;

INSERT INTO #Hab (TIPO, CODIGO, HABILITADO)
SELECT 'M', m.CODIGO, m.HABILITADO FROM SIS.Modulo m WHERE m.CODIGO = 'CAD'
UNION ALL
SELECT 'I', i.CODIGO, i.HABILITADO FROM SIS.Item i WHERE i.CODIGO = 'CAD_EMPRESA';
UPDATE SIS.Modulo SET HABILITADO = 1 WHERE CODIGO = 'CAD' AND HABILITADO = 0;
UPDATE SIS.Item   SET HABILITADO = 1 WHERE CODIGO = 'CAD_EMPRESA' AND HABILITADO = 0;

EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdCelso, @Estacao = N'HOMOLOGACAO-03C2', @Origem = N'teste-03c2';

-- 1) Estrutura
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Coluna CNPJ_COMPRAS em CAD.Empresa', N'1', CONVERT(NVARCHAR(5), CASE WHEN COL_LENGTH(N'CAD.Empresa', N'CNPJ_COMPRAS') = 14 THEN 1 ELSE 0 END)),
 (N'Restrição de formato do CNPJ_COMPRAS', N'1', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.check_constraints c WHERE c.name = 'CK_Empresa_CNPJ_COMPRAS'))),
 (N'Listar devolve as colunas novas', N'2', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM sys.dm_exec_describe_first_result_set(N'EXEC CAD.CAD_Empresa_Listar @IdUsuario = 1', NULL, 0) r
                                                                WHERE r.name IN ('CNPJ_COMPRAS', 'CNPJ_COMPRAS_FORMATADO'))));

-- 2) Gravação
INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @RazaoSocial = N'HML 03c2 SPE', @Cnpj = '11.444.777/0001-61', @Tipo = 'SPE',
     @RegimeTributario = 'RET', @CnpjCompras = '11.444.777/0002-42';
SELECT @IdEmp = r.ID FROM #Ret r;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Inclui com CNPJ de notas/DDA (só dígitos)', N'1|11444777000242', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + e.CNPJ_COMPRAS
FROM #Ret r INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = r.ID;
DELETE FROM #Ret;

INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmp, @RazaoSocial = N'HML 03c2 SPE', @Cnpj = '11444777000161', @Tipo = 'SPE',
     @CnpjCompras = '11.444.777/0002-40';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Recusa CNPJ de notas/DDA com dígito errado', N'0|CNPJ para notas de compra e DDA inválido. Confira os números.', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + r.MENSAGEM FROM #Ret r;
DELETE FROM #Ret;

INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmp, @RazaoSocial = N'HML 03c2 SPE', @Cnpj = '11444777000161', @Tipo = 'SPE',
     @CnpjCompras = '11444777000161';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Recusa CNPJ de notas/DDA igual ao CNPJ', N'0', CONVERT(NVARCHAR(1), r.SUCESSO) FROM #Ret r;
DELETE FROM #Ret;

INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmp, @RazaoSocial = N'HML 03c2 SPE alterada', @Cnpj = '11444777000161', @Tipo = 'SPE';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Alterar sem informar o CNPJ de notas/DDA mantém o gravado', N'1|11444777000242', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + e.CNPJ_COMPRAS
FROM #Ret r INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = r.ID;
DELETE FROM #Ret;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Auditoria registra a coluna nova na inclusão', N'1',
       CONVERT(NVARCHAR(5), COUNT(*)) FROM SIS.Auditoria a
WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA LIKE N'%Empresa%' AND a.ID_REGISTRO = @IdEmp AND a.OPERACAO = 'I' AND a.VALOR_DEPOIS LIKE N'%CNPJ_COMPRAS%';

INSERT INTO #Ret EXEC CAD.CAD_Empresa_Gravar @IdUsuario = @IdCelso, @IdEmpresa = @IdEmp, @RazaoSocial = N'HML 03c2 SPE alterada', @Cnpj = '11444777000161', @Tipo = 'SPE',
     @CnpjCompras = '';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Informar vazio apaga o CNPJ de notas/DDA', N'1|', CONVERT(NVARCHAR(1), r.SUCESSO) + N'|' + e.CNPJ_COMPRAS
FROM #Ret r INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = r.ID;
DELETE FROM #Ret;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Auditoria registra a alteração do CNPJ de notas/DDA (antes|depois)', N'11444777000242|',
       (SELECT TOP (1) ISNULL(a.VALOR_ANTES, N'') + N'|' + ISNULL(a.VALOR_DEPOIS, N'') FROM SIS.Auditoria a
        WHERE a.ID_AUDITORIA > @AudInicio AND a.TABELA LIKE N'%Empresa%' AND a.ID_REGISTRO = @IdEmp AND a.OPERACAO = 'A' AND a.CAMPO = N'CNPJ_COMPRAS'
        ORDER BY a.ID_AUDITORIA DESC);

-- 3) Número do plano de contas do Access
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Desmontar "' + x.T + N'"', x.ESPERADO,
       ISNULL(CONVERT(NVARCHAR(5), d.NUMERO_1), N'-') + N'|' + ISNULL(CONVERT(NVARCHAR(5), d.NUMERO_2), N'-') + N'|'
     + ISNULL(CONVERT(NVARCHAR(5), d.NUMERO_ULTIMO), N'-') + N'|' + CONVERT(NVARCHAR(5), d.QTD_NUMEROS) + N'|' + d.TEXTO
FROM (VALUES (1, N'3..1.9 - Vale Alimentação',  N'3|1|9|3|Vale Alimentação'),
             (2, N'00- PERMUTAS',               N'0|-|0|1|PERMUTAS'),
             (3, N'11.2.1 Devolução de venda',  N'11|2|1|3|Devolução de venda'),
             (4, N'5.1-DESP. EMPREITAS',        N'5|1|1|2|DESP. EMPREITAS'),
             (5, N'TIJOLOS',                    N'-|-|-|0|TIJOLOS'),
             (6, N'5.1.8  - Pintor',            N'5|1|8|3|Pintor'),
             (7, N'01 -  DESP. MÃO OBRA',       N'1|-|1|1|DESP. MÃO OBRA')) x (ORDEM, T, ESPERADO)
CROSS APPLY MIG.fn_MIG_Plano_Desmontar(x.T) d
ORDER BY x.ORDEM;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Nenhum erro técnico gravado no log durante o teste', N'0', CONVERT(NVARCHAR(5), COUNT(*)) FROM SIS.Log_Erro e WHERE e.ID_LOG_ERRO > @ErroInicio;

-- 4) Limpeza
DELETE FROM CAD.Empresa WHERE RAZAO_SOCIAL LIKE N'HML 03c2%';
UPDATE m SET m.HABILITADO = h.HABILITADO FROM SIS.Modulo m INNER JOIN #Hab h ON h.TIPO = 'M' AND h.CODIGO = m.CODIGO WHERE m.HABILITADO <> h.HABILITADO;
UPDATE i SET i.HABILITADO = h.HABILITADO FROM SIS.Item i   INNER JOIN #Hab h ON h.TIPO = 'I' AND h.CODIGO = i.CODIGO WHERE i.HABILITADO <> h.HABILITADO;
EXEC SIS.SIS_Contexto_Gravar @IdUsuario = NULL;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Limpeza: nada do teste ficou', N'0', CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM CAD.Empresa e WHERE e.RAZAO_SOCIAL LIKE N'HML 03c2%'))),
 (N'Habilitação voltou ao original', N'0',
  CONVERT(NVARCHAR(5), (SELECT COUNT(*) FROM #Hab h WHERE h.HABILITADO <> CASE h.TIPO WHEN 'M' THEN (SELECT m.HABILITADO FROM SIS.Modulo m WHERE m.CODIGO = h.CODIGO)
                                                                                     ELSE (SELECT i.HABILITADO FROM SIS.Item i WHERE i.CODIGO = h.CODIGO) END)));

SELECT 'TESTES' AS GRADE, ID, TESTE, ESPERADO, OBTIDO,
       CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 'OK' ELSE 'FALHOU' END AS RESULTADO
FROM #Teste ORDER BY ID;

SELECT 'RESUMO' AS GRADE, COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste;
GO

SET NOEXEC OFF;
GO
