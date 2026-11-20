/*******************************************************************************
  Teste       : 03d - rodapé dos e-mails sem CNPJ (EMAIL_RODAPE_CNPJ)
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 20/11/2026 (v1.0). Banco: SISTEMACMJ_LOCAL. Resultado em 20/11/2026: 5/0.
*******************************************************************************/
-- Teste 03d: rodape sem CNPJ (somente leitura; a troca do parametro e desfeita com ROLLBACK)
SET NOCOUNT ON;
DECLARE @r TABLE (CASO VARCHAR(60), ESPERADO VARCHAR(10), OBTIDO VARCHAR(10));
INSERT @r SELECT 'parametro existe com N', 'N', (SELECT VALOR FROM SIS.Parametro WHERE CHAVE = 'EMAIL_RODAPE_CNPJ');
INSERT @r SELECT 'externo sem CNPJ (N)', 'NAO', CASE WHEN SIS.fn_SIS_Email_HTML(N'T','INFO',N'x',N'r',NULL,1) LIKE N'%CNPJ%' THEN 'SIM' ELSE 'NAO' END;
INSERT @r SELECT 'externo mantem razao social', 'SIM', CASE WHEN SIS.fn_SIS_Email_HTML(N'T','INFO',N'x',N'r',NULL,1) LIKE N'%' + SIS.fn_SIS_Texto_HTML(SIS.fn_SIS_Empresa_Razao_Social()) + N'%' THEN 'SIM' ELSE 'NAO' END;
INSERT @r SELECT 'interno sem CNPJ', 'NAO', CASE WHEN SIS.fn_SIS_Email_HTML(N'T','INFO',N'x',N'r','G',0) LIKE N'%CNPJ%' THEN 'SIM' ELSE 'NAO' END;
BEGIN TRAN;
UPDATE SIS.Parametro SET VALOR = N'S' WHERE CHAVE = 'EMAIL_RODAPE_CNPJ';
INSERT @r SELECT 'externo com CNPJ (S)', 'SIM', CASE WHEN SIS.fn_SIS_Email_HTML(N'T','INFO',N'x',N'r',NULL,1) LIKE N'%CNPJ%' THEN 'SIM' ELSE 'NAO' END;
ROLLBACK;
SELECT CASO, ESPERADO, OBTIDO, CASE WHEN ESPERADO = OBTIDO THEN 'OK' ELSE 'FALHA' END AS RESULTADO FROM @r;
SELECT COUNT(*) AS TOTAL, SUM(CASE WHEN ESPERADO = OBTIDO THEN 0 ELSE 1 END) AS FALHAS FROM @r;
