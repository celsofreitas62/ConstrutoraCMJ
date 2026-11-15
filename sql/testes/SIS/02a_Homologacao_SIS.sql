/*******************************************************************************
  Homologação : etapa 02a da base SIS (somente SISTEMACMJ_LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Confere os objetos da 02a e testa as functions e procedures.
                Cada teste mostra ESPERADO x OBTIDO e RESULTADO (OK/FALHOU).
                Os parâmetros alterados no teste voltam ao valor original.
                Grava 1 linha de teste em SIS.Log_Erro (rotina 'HOMOLOGACAO/02a').
                Aborta se não estiver no SISTEMACMJ_LOCAL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).

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

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;

CREATE TABLE #Teste (ID INT IDENTITY(1,1), TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));
CREATE TABLE #Ret   (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_PARAMETRO INT);

DECLARE @ValorOriginal NVARCHAR(4000);
DECLARE @EmailOriginal NVARCHAR(4000);

-- 1) Objetos esperados
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Objeto ' + v.NOME, v.TIPO, ISNULL((SELECT o.type_desc FROM sys.objects o WHERE o.object_id = OBJECT_ID(v.NOME)), N'(não existe)')
FROM (VALUES
        (N'SIS.Modulo', N'USER_TABLE'), (N'SIS.Log_Erro', N'USER_TABLE'), (N'SIS.Log_Passo', N'USER_TABLE'), (N'SIS.Parametro', N'USER_TABLE'),
        (N'SIS.fn_SIS_Usuario_Atual', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Parametro', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.fn_SIS_Parametro_Inteiro', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Parametro_Decimal', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.fn_SIS_Parametro_SN', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Texto_HTML', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.fn_SIS_Formatar_Moeda', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Formatar_Data', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.fn_SIS_Formatar_Data_Hora', N'SQL_SCALAR_FUNCTION'), (N'SIS.fn_SIS_Mascarar_CPF_CNPJ', N'SQL_SCALAR_FUNCTION'),
        (N'SIS.SIS_Log_Erro_Gravar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Log_Erro_Listar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Parametro_Listar', N'SQL_STORED_PROCEDURE'), (N'SIS.SIS_Parametro_Gravar', N'SQL_STORED_PROCEDURE'),
        (N'SIS.SIS_Log_Limpar_Processar', N'SQL_STORED_PROCEDURE')
     ) v (NOME, TIPO);

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Schemas criados (CAD BANCO IMOB VENDA FIN COBR OBRA GER SIS)', N'9',
       CONVERT(NVARCHAR(10), COUNT(*))
FROM sys.schemas s
WHERE s.name IN (N'CAD', N'BANCO', N'IMOB', N'VENDA', N'FIN', N'COBR', N'OBRA', N'GER', N'SIS');

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Carga: módulos', N'9', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Modulo;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Carga: parâmetros', N'10', CONVERT(NVARCHAR(10), COUNT(*)) FROM SIS.Parametro;

-- 2) Functions
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Moeda 1234.56',            N'R$ 1.234,56',          SIS.fn_SIS_Formatar_Moeda(1234.56)),
 (N'Moeda -0.5',               N'-R$ 0,50',             SIS.fn_SIS_Formatar_Moeda(-0.5)),
 (N'Moeda 1234567.8',          N'R$ 1.234.567,80',      SIS.fn_SIS_Formatar_Moeda(1234567.8)),
 (N'Moeda NULL',               N'R$ 0,00',              SIS.fn_SIS_Formatar_Moeda(NULL)),
 (N'Data 2026-12-10',          N'10/12/2026',           SIS.fn_SIS_Formatar_Data('2026-12-10')),
 (N'Data NULL',                N'',                     SIS.fn_SIS_Formatar_Data(NULL)),
 (N'Data/hora',                N'15/11/2026 09:05',     SIS.fn_SIS_Formatar_Data_Hora('2026-11-15 09:05:33')),
 (N'CPF formatado',            N'123.456.789-01',       SIS.fn_SIS_Mascarar_CPF_CNPJ('12345678901', 0)),
 (N'CPF oculto',               N'***.456.789-**',       SIS.fn_SIS_Mascarar_CPF_CNPJ('123.456.789-01', 1)),
 (N'CNPJ',                     N'12.345.678/0001-95',   SIS.fn_SIS_Mascarar_CPF_CNPJ('12345678000195', 1)),
 (N'CNPJ alfanumérico',        N'12.ABC.345/01DE-35',   SIS.fn_SIS_Mascarar_CPF_CNPJ('12abc34501de35', 0)),
 (N'Documento NULL',           N'',                     SIS.fn_SIS_Mascarar_CPF_CNPJ(NULL, 0)),
 (N'Texto HTML',               N'&lt;b&gt;A &amp; B&lt;/b&gt; &quot;x&quot; &#39;y&#39;', SIS.fn_SIS_Texto_HTML(N'<b>A & B</b> "x" ''y''')),
 (N'Texto HTML NULL',          N'',                     SIS.fn_SIS_Texto_HTML(NULL)),
 (N'Parâmetro texto',          N'celsofreitas62@gmail.com', SIS.fn_SIS_Parametro('EMAIL_TESTE')),
 (N'Parâmetro inexistente',    N'',                     SIS.fn_SIS_Parametro('NAO_EXISTE')),
 (N'Parâmetro inteiro',        N'8',                    CONVERT(NVARCHAR(20), SIS.fn_SIS_Parametro_Inteiro('SENHA_TAMANHO_MINIMO'))),
 (N'Parâmetro inteiro inexistente', N'0',               CONVERT(NVARCHAR(20), SIS.fn_SIS_Parametro_Inteiro('NAO_EXISTE'))),
 (N'Parâmetro decimal inexistente', N'0.000000',        CONVERT(NVARCHAR(30), SIS.fn_SIS_Parametro_Decimal('NAO_EXISTE'))),
 (N'Parâmetro SN inexistente', N'0',                    CONVERT(NVARCHAR(5), SIS.fn_SIS_Parametro_SN('NAO_EXISTE'))),
 (N'Usuário atual preenchido', N'S',                    CASE WHEN SIS.fn_SIS_Usuario_Atual() <> N'' THEN N'S' ELSE N'N' END);

-- 3) SIS_Parametro_Gravar
SELECT @ValorOriginal = p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'SENHA_TAMANHO_MINIMO';
SELECT @EmailOriginal = p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_ADMIN_ALERTA';

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'abc', @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar inteiro inválido (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N' 12 ', @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar inteiro válido', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Valor gravado sem espaços', N'12', p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'SENHA_TAMANHO_MINIMO';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Usuário da alteração', N'homologacao', ISNULL(p.USUARIO_ALTERACAO, N'') FROM SIS.Parametro p WHERE p.CHAVE = 'SENHA_TAMANHO_MINIMO';

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'12', @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar mesmo valor (sem alteração)', N'Nenhuma alteração: o valor já era este.', MENSAGEM FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = @ValorOriginal, @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Restaurar valor original', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'EMAIL_TESTE', @Valor = N'outro@exemplo.com', @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar parâmetro não editável (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'EMAIL_TESTE continua igual', N'celsofreitas62@gmail.com', p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_TESTE';

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'NAO_EXISTE', @Valor = N'1', @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar parâmetro inexistente (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'EMAIL_ADMIN_ALERTA', @Valor = N'a@b.com; c@d.com', @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar dois e-mails (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'email_admin_alerta', @Valor = N'Teste@Exemplo.com', @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar e-mail válido (chave minúscula)', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'E-mail gravado em minúsculas', N'teste@exemplo.com', p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = 'EMAIL_ADMIN_ALERTA';

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @Chave = 'EMAIL_ADMIN_ALERTA', @Valor = @EmailOriginal, @Usuario = N'homologacao';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Restaurar e-mail original', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 4) Log de erro
DROP TABLE IF EXISTS #RetLog;
CREATE TABLE #RetLog (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID_LOG_ERRO BIGINT);
INSERT INTO #RetLog EXEC SIS.SIS_Log_Erro_Gravar @Rotina = N'HOMOLOGACAO/02a', @Etapa = N'Teste', @NumeroErro = 0, @Mensagem = N'Teste de gravação de erro (pode ignorar)', @Linha = 0, @Origem = 'api';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Gravar log de erro', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #RetLog;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Log gravado com origem API', N'API', l.ORIGEM FROM SIS.Log_Erro l WHERE l.ID_LOG_ERRO = (SELECT r.ID_LOG_ERRO FROM #RetLog r);
DROP TABLE IF EXISTS #RetLog;

-- 5) Resultado
SELECT N'TESTES' AS GRADE, t.ID, t.TESTE, t.ESPERADO, t.OBTIDO,
       CASE WHEN t.OBTIDO COLLATE Latin1_General_CS_AS = t.ESPERADO THEN N'OK' ELSE N'FALHOU' END AS RESULTADO
FROM #Teste t
ORDER BY t.ID;

SELECT N'RESUMO' AS GRADE,
       COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN t.OBTIDO COLLATE Latin1_General_CS_AS = t.ESPERADO THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste t;

-- 6) Listas (só para conferir na tela)
EXEC SIS.SIS_Parametro_Listar;
EXEC SIS.SIS_Log_Erro_Listar @Rotina = N'HOMOLOGACAO';
EXEC SIS.SIS_Log_Limpar_Processar;

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
GO

SET NOEXEC OFF;
GO
