/*******************************************************************************
  Homologação : ajuste 02b2 da base SIS - identidade visual (só LOCAL)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Testa os tipos de parâmetro ARQUIVO e COR, os parâmetros de
                identidade visual (logomarcas e cores) e fn_SIS_Parametro_Cor.
                Os valores alterados no teste voltam ao original.
                Aborta se não estiver no SISTEMACMJ_LOCAL.

  Changelog:
    v1.0 (15/11/2026) - Criação.
    v1.1 (15/11/2026) - Testes de login com "_", "." e "-" (correção do
                        padrão do LIKE); usuário de teste apagado no fim.

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
CREATE TABLE #Ret   (SUCESSO BIT, MENSAGEM NVARCHAR(400), ID INT);

DECLARE @IdCelso    INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'celso');
DECLARE @IdAdmin    INT = (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'admin');
DECLARE @CorOrig    NVARCHAR(4000) = SIS.fn_SIS_Parametro('EMPRESA_COR_PRINCIPAL');
DECLARE @LogoOrig   NVARCHAR(4000) = SIS.fn_SIS_Parametro('EMPRESA_LOGO_EMAIL');

-- 1) Carga
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Parâmetro ' + v.CHAVE, v.ESPERADO, ISNULL((SELECT p.TIPO + N'=' + p.VALOR FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE), N'(não existe)')
FROM (VALUES
        (CAST('IDENTIDADE_PASTA' AS VARCHAR(60)), CAST(N'TEXTO=C:\SistemaCMJ_Arquivos\Identidade' AS NVARCHAR(400))),
        ('EMPRESA_LOGO',            N'ARQUIVO=logo.png'),
        ('EMPRESA_LOGO_HORIZONTAL', N'ARQUIVO=logo_horizontal.png'),
        ('EMPRESA_LOGO_EMAIL',      N'ARQUIVO=logo_email.png'),
        ('EMPRESA_LOGO_SIMBOLO',    N'ARQUIVO=logo_simbolo.png'),
        ('EMPRESA_COR_PRINCIPAL',   N'COR=#D43414'),
        ('EMPRESA_COR_SECUNDARIA',  N'COR=#A8A8A8'),
        ('EMAIL_COR_ALERTA',        N'COR=#E65100'),
        ('EMAIL_COR_SUCESSO',       N'COR=#2E7D32')
     ) v (CHAVE, ESPERADO);

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES
 (N'Cor principal pela function',      N'#D43414', SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL')),
 (N'Cor de parâmetro inexistente',     N'#555555', SIS.fn_SIS_Parametro_Cor('NAO_EXISTE')),
 (N'Cor de parâmetro que não é cor',   N'#555555', SIS.fn_SIS_Parametro_Cor('CIDADE_PADRAO'));

-- 2) Gravação de COR
INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_COR_PRINCIPAL', @Valor = N'vermelho';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Cor inválida (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_COR_PRINCIPAL', @Valor = N'#12ab3G';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Cor com letra fora de hexadecimal (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_COR_PRINCIPAL', @Valor = N'#1f4e79';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Cor válida', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) VALUES (N'Cor gravada em maiúsculas', N'#1F4E79', SIS.fn_SIS_Parametro('EMPRESA_COR_PRINCIPAL'));

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_COR_PRINCIPAL', @Valor = @CorOrig;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Restaurar cor original', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 3) Gravação de ARQUIVO
INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_LOGO_EMAIL', @Valor = N'C:\pasta\logo.png';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Arquivo com pasta (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_LOGO_EMAIL', @Valor = N'logomarca nova.png';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Arquivo com espaço (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_LOGO_EMAIL', @Valor = N'logo.exe';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Arquivo com extensão proibida (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_LOGO_EMAIL', @Valor = N'logo_cliente_2.JPG';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Arquivo válido (outro cliente)', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdCelso, @Chave = 'EMPRESA_LOGO_EMAIL', @Valor = @LogoOrig;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Restaurar logomarca original', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 4) Só o administrador geral altera a identidade visual
INSERT INTO #Ret EXEC SIS.SIS_Parametro_Gravar @IdUsuario = @IdAdmin, @Chave = 'EMPRESA_LOGO_EMAIL', @Valor = N'outra.png';
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'admin (CMJ) troca a logomarca (sem permissão)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;

-- 5) Login com sublinhado, ponto e hífen (mesma correção)
DELETE FROM SIS.Usuario WHERE LOGIN IN ('hml_teste-1.a', 'hml_x');
DECLARE @IdPerfilAdmin INT = (SELECT TOP (1) p.ID_PERFIL FROM SIS.Perfil p WHERE p.NIVEL_ADMIN = 1 ORDER BY p.ID_PERFIL);
INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdCelso, @Login = 'hml_teste-1.a', @Nome = N'Teste de login', @IdPerfil = @IdPerfilAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login com _ . - aceito', N'1', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
INSERT INTO #Ret EXEC SIS.SIS_Usuario_Gravar @IdUsuario = @IdCelso, @Login = 'hml_x#', @Nome = N'Teste de login', @IdPerfil = @IdPerfilAdmin;
INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO) SELECT N'Login com # (recusa)', N'0', CONVERT(NVARCHAR(5), SUCESSO) FROM #Ret; DELETE FROM #Ret;
DELETE FROM SIS.Usuario WHERE LOGIN IN ('hml_teste-1.a', 'hml_x');

-- 6) Resultado
SELECT N'TESTES' AS GRADE, t.ID, t.TESTE, t.ESPERADO, t.OBTIDO,
       CASE WHEN t.OBTIDO COLLATE Latin1_General_CS_AS = t.ESPERADO THEN N'OK' ELSE N'FALHOU' END AS RESULTADO
FROM #Teste t
ORDER BY t.ID;

SELECT N'RESUMO' AS GRADE,
       COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN t.OBTIDO COLLATE Latin1_General_CS_AS = t.ESPERADO THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste t;

DROP TABLE IF EXISTS #Teste;
DROP TABLE IF EXISTS #Ret;
GO

SET NOEXEC OFF;
GO
