/*******************************************************************************
  Script      : homologação da separação de número e complemento do endereço
                (MIG.fn_MIG_Endereco_Separar e MIG_Cadastros_Processar v1.2)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026 (etapa 04d2, passo 6)
  Descrição   : Casos reais do Access: ESPERADO "logradouro | número |
                complemento | reconhecido" x OBTIDO; e a migração gravando o
                número em CAD.Pessoa. Só leitura. Roda no LOCAL ou no ensaio.
*******************************************************************************/
IF DB_NAME() NOT IN (N'SISTEMACMJ_LOCAL', N'SISTEMACMJ')
BEGIN
    RAISERROR(N'Rode no SISTEMACMJ_LOCAL ou no ensaio SISTEMACMJ.', 16, 1);
    SET NOEXEC ON;
END;
GO
SET NOCOUNT ON;
DROP TABLE IF EXISTS #Teste;
CREATE TABLE #Teste (ID INT IDENTITY, TESTE NVARCHAR(200), ESPERADO NVARCHAR(400), OBTIDO NVARCHAR(400));

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Separar: ' + x.E, x.ESPERADO, s.LOGRADOURO + N' | ' + s.NUMERO + N' | ' + s.COMPLEMENTO + N' | ' + CASE WHEN s.RECONHECIDO = 1 THEN N'1' ELSE N'0' END
FROM (VALUES
    (N'Rua Antonio Pacheco Valente, 60 Apto. 102', N'Rua Antonio Pacheco Valente | 60 | Apto. 102 | 1'),
    (N'Rua Piramboia, 1210, fundos',               N'Rua Piramboia | 1210 | fundos | 1'),
    (N'Avenida Brasilia 1730 A',                   N'Avenida Brasilia | 1730 | A | 1'),
    (N'Av. Ferreiro s/nº',                         N'Av. Ferreiro | S/N |  | 1'),
    (N'Rua Vereador Gumercindo Fernandes, SN',     N'Rua Vereador Gumercindo Fernandes | S/N |  | 1'),
    (N'Rua Roberto Augusto de Paiva s/n, Galpão 1', N'Rua Roberto Augusto de Paiva | S/N | Galpão 1 | 1'),
    (N'Rua Bem Basto, 115/1',                      N'Rua Bem Basto | 115/1 |  | 1'),
    (N'R. Dr. Arthur de Mendonça Chaves nº 201',   N'R. Dr. Arthur de Mendonça Chaves | 201 |  | 1'),
    (N'Av. das Nações Unidas, nº 12995 - 10º Andar', N'Av. das Nações Unidas | 12995 | 10º Andar | 1'),
    (N'Av.Dr.Mauro Lindemberg Monteiro,121 -Armz.2', N'Av.Dr.Mauro Lindemberg Monteiro | 121 | Armz.2 | 1'),
    (N'Rua 7 de Setembro, 100',                    N'Rua 7 de Setembro | 100 |  | 1'),
    (N'Rua Piaui 729,',                            N'Rua Piaui | 729 |  | 1'),
    (N'Rod Sp -147',                               N'Rod Sp -147 |  |  | 0'),
    (N'Rod. BR 116 Km 140',                        N'Rod. BR 116 Km 140 |  |  | 0'),
    (N'Via de acesso Faz. Itapeva',                N'Via de acesso Faz. Itapeva |  |  | 0'),
    (N'',                                          N' |  |  | 1')) x(E, ESPERADO)
CROSS APPLY MIG.fn_MIG_Endereco_Separar(x.E) s;

INSERT INTO #Teste (TESTE, ESPERADO, OBTIDO)
SELECT N'Migração: pessoa com logradouro reconhecido e número vazio', N'0',
       CONVERT(NVARCHAR(20), COUNT(*))
FROM MIG.Access_Parceiros a
CROSS APPLY MIG.fn_MIG_Endereco_Separar(LEFT(LTRIM(RTRIM(ISNULL(a.Endereco, N''))), 150)) s
INNER JOIN CAD.Pessoa p ON p.CODIGO_ACCESS = TRY_CONVERT(INT, a.CodigoParceiro)
WHERE s.RECONHECIDO = 1 AND s.NUMERO <> N'' AND p.NUMERO <> s.NUMERO;

SELECT 'TESTES' AS GRADE, ID, TESTE, ESPERADO, OBTIDO,
       CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 'OK' ELSE 'FALHOU' END AS RESULTADO
FROM #Teste ORDER BY ID;

SELECT 'RESUMO' AS GRADE, COUNT(*) AS TOTAL_TESTES,
       SUM(CASE WHEN ISNULL(ESPERADO, N'') = ISNULL(OBTIDO, N'') COLLATE Latin1_General_BIN2 THEN 0 ELSE 1 END) AS FALHAS
FROM #Teste;
GO

SET NOEXEC OFF;
GO
