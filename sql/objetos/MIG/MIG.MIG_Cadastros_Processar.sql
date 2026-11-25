/*******************************************************************************
  Objeto      : [MIG].[MIG_Cadastros_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Migração dos cadastros do Access para o sistema novo (etapa
                03c2, parte A), na ordem: empresas, contas (BANCO.Conta, mais o
                "Caixa contábil" de cada empresa), pessoas e contatos, centros
                de custo (obras do Access e imóveis próprios), históricos
                padrão e plano de contas; no fim refaz os de-paras usados na
                transformação do movimento (MIG.DePara_Centro e
                MIG.DePara_Plano).
                Regras: tabelas MIG.Classif_* / Config_* / DePara_Plano_Excecao
                (decisões conferidas pela CMJ) e regra automática para o que
                não estiver nelas. "Usado" = tem linha que vai para o sistema
                novo (MIG.Movimento, DESTINO = 'SISTEMA'): define o que nasce
                ativo.
                Repetível: cada cadastro é localizado pelo código do Access
                (CODIGO_ACCESS) ou pelo número (plano) e só é alterado quando
                algum valor mudou; nada é apagado. CNPJ e razão social vazios
                na classificação não apagam o que já foi digitado pela tela.
                Tudo-ou-nada (uma transação). Grava como usuário "sistema",
                origem MIGRACAO (auditoria).
                Pré-requisito: MIG_Carga_Processar e MIG_Movimento_Preparar
                rodados; Carga_MIG_Classificacao.sql aplicada.
                Devolve o resumo por cadastro.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).
    v1.1 (22/11/2026) - 03f: conta padrão do centro pode vir da classificação
                        (Classif_Centro.CODIGO_CONTA_PADRAO, decisão da CMJ) no
                        lugar da do Access; centro extra com ATIVO decidido na
                        classificação (ex.: imóvel vendido) prevalece sobre a
                        regra automática.
    v1.2 (25/11/2026) - 04d2: número e complemento separados do logradouro
                        (MIG.fn_MIG_Endereco_Separar, regra aprovada pelo
                        Celso); o não reconhecido fica inteiro no logradouro,
                        com o número vazio (pendência da Renata).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Cadastros_Processar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Cadastros_Processar]
    @NomeCaixaContabil  NVARCHAR(60) = N'Caixa contábil'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[MIG].[MIG_Cadastros_Processar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @IdSistema   INT;
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @Agora       DATETIME2(0)  = SYSDATETIME();
    DECLARE @MasterPrinc INT;
    DECLARE @IdPrincipal INT;

    BEGIN TRY
        DROP TABLE IF EXISTS #UsoCentro, #UsoConta, #UsoPessoa, #UsoPlano, #UsoPlanoTotal, #Emp, #Cta, #Pes, #Ctt, #CC,
                             #Hist, #P3, #Grupo, #SubNum, #SubDest, #ContaDest, #Mapa;

        IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
            THROW 50001, N'Rode antes o MIG.MIG_Movimento_Preparar.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.Access_Parceiros) OR NOT EXISTS (SELECT 1 FROM MIG.Access_EmpVinculada) OR NOT EXISTS (SELECT 1 FROM MIG.Access_Plano3)
            THROW 50001, N'As tabelas do Access estão vazias: rode antes o MIG.MIG_Carga_Processar.', 1;
        IF (SELECT COUNT(*) FROM MIG.Classif_Empresa c WHERE c.PRINCIPAL = 1 AND c.DESTINO = 'EMPRESA') <> 1
            THROW 50001, N'A classificação precisa de exatamente uma empresa principal (Carga_MIG_Classificacao.sql).', 1;
        IF EXISTS (SELECT 1 FROM MIG.Classif_Conta c WHERE c.DESTINO = 'CONTA' AND c.BANCO_CODIGO IS NOT NULL
                   AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.CODIGO = c.BANCO_CODIGO))
            THROW 50001, N'Falta no cadastro de bancos algum banco usado nas contas (BANCO.Banco).', 1;

        SELECT @IdSistema = u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema';
        IF @IdSistema IS NULL
            THROW 50001, N'Usuário "sistema" não encontrado.', 1;
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdSistema);
        EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Origem = N'MIGRACAO';

        SELECT @MasterPrinc = c.CODIGO_MASTER FROM MIG.Classif_Empresa c WHERE c.PRINCIPAL = 1 AND c.DESTINO = 'EMPRESA';

        SET @EtapaAtual = 'Uso desde o corte';
        SELECT DISTINCT m.EMP_VINCULADA AS COD INTO #UsoCentro FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' AND m.EMP_VINCULADA IS NOT NULL;
        SELECT DISTINCT m.CONTA         AS COD INTO #UsoConta  FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' AND m.CONTA IS NOT NULL;
        SELECT DISTINCT m.PARCEIRO      AS COD INTO #UsoPessoa FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' AND m.PARCEIRO IS NOT NULL;
        SELECT DISTINCT m.PLANO3        AS COD INTO #UsoPlano  FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' AND m.PLANO3 IS NOT NULL;
        SELECT DISTINCT m.PLANO3        AS COD INTO #UsoPlanoTotal FROM MIG.Movimento m WHERE m.PLANO3 IS NOT NULL;

        BEGIN TRANSACTION;

        /* ------------------------------------------------------------------
           1. Empresas do grupo
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Empresas';
        SELECT c.CODIGO_MASTER,
               CAST(LEFT(COALESCE(NULLIF(c.RAZAO_SOCIAL, N''), LTRIM(RTRIM(m.NomeMaster)), N'Empresa ' + CONVERT(NVARCHAR(10), c.CODIGO_MASTER)), 150) AS NVARCHAR(150)) AS RAZAO_SOCIAL,
               CAST(LEFT(c.NOME_FANTASIA, 100) AS NVARCHAR(100)) AS NOME_FANTASIA,
               c.CNPJ, c.CNPJ_COMPRAS, c.TIPO, c.REGIME_TRIBUTARIO
        INTO #Emp
        FROM MIG.Classif_Empresa c
        LEFT JOIN MIG.Access_EmpMaster m ON TRY_CONVERT(INT, m.CodigoMaster) = c.CODIGO_MASTER
        WHERE c.DESTINO = 'EMPRESA';

        UPDATE e
           SET e.RAZAO_SOCIAL      = s.RAZAO_SOCIAL,
               e.NOME_FANTASIA     = CASE WHEN s.NOME_FANTASIA <> N'' THEN s.NOME_FANTASIA ELSE e.NOME_FANTASIA END,
               e.CNPJ              = CASE WHEN s.CNPJ <> '' THEN s.CNPJ ELSE e.CNPJ END,
               e.CNPJ_COMPRAS      = CASE WHEN s.CNPJ_COMPRAS <> '' THEN s.CNPJ_COMPRAS ELSE e.CNPJ_COMPRAS END,
               e.TIPO              = s.TIPO,
               e.REGIME_TRIBUTARIO = CASE WHEN s.REGIME_TRIBUTARIO <> '' THEN s.REGIME_TRIBUTARIO ELSE e.REGIME_TRIBUTARIO END,
               e.ATIVO             = 1,
               e.DT_ALTERACAO      = @Agora,
               e.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Empresa e
        INNER JOIN #Emp s ON s.CODIGO_MASTER = e.CODIGO_ACCESS
        WHERE e.RAZAO_SOCIAL <> s.RAZAO_SOCIAL
           OR (s.NOME_FANTASIA <> N'' AND e.NOME_FANTASIA <> s.NOME_FANTASIA)
           OR (s.CNPJ <> '' AND e.CNPJ <> s.CNPJ)
           OR (s.CNPJ_COMPRAS <> '' AND e.CNPJ_COMPRAS <> s.CNPJ_COMPRAS)
           OR e.TIPO <> s.TIPO
           OR (s.REGIME_TRIBUTARIO <> '' AND e.REGIME_TRIBUTARIO <> s.REGIME_TRIBUTARIO)
           OR e.ATIVO = 0;

        INSERT INTO CAD.Empresa (RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, TIPO, REGIME_TRIBUTARIO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.RAZAO_SOCIAL, s.NOME_FANTASIA, s.CNPJ, s.CNPJ_COMPRAS, s.TIPO, s.REGIME_TRIBUTARIO, 1, s.CODIGO_MASTER, @Usuario
        FROM #Emp s
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.CODIGO_ACCESS = s.CODIGO_MASTER);

        SELECT @IdPrincipal = e.ID_EMPRESA FROM CAD.Empresa e WHERE e.CODIGO_ACCESS = @MasterPrinc;

        /* ------------------------------------------------------------------
           2. Contas bancárias, caixas e permuta; "Caixa contábil" por empresa
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Contas';
        SELECT c.CODIGO_CONTA,
               e.ID_EMPRESA,
               CAST(LEFT(COALESCE(NULLIF(c.DESCRICAO, N''), LTRIM(RTRIM(a.Descricao))), 60) AS NVARCHAR(60)) AS DESCRICAO,
               c.TIPO, b.ID_BANCO, c.AGENCIA, c.NUMERO, c.NUMERO_DV,
               ISNULL(ROUND(TRY_CONVERT(DECIMAL(19,6), a.[Limite Credito]), 2), 0) AS LIMITE_CREDITO,
               CAST(CASE WHEN a.Conciliacao = N'True' THEN 1 ELSE 0 END AS BIT) AS CONCILIA,
               CAST(CASE WHEN a.NaoListarResumo = N'True' THEN 0 ELSE 1 END AS BIT) AS MOSTRA_SALDO,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM #UsoConta u WHERE u.COD = c.CODIGO_CONTA) THEN 1 ELSE 0 END AS BIT) AS ATIVO
        INTO #Cta
        FROM MIG.Classif_Conta c
        INNER JOIN CAD.Empresa e ON e.CODIGO_ACCESS = c.CODIGO_MASTER_EMPRESA
        LEFT JOIN MIG.Access_Contas_Financeiras a ON TRY_CONVERT(INT, a.CodigoConta) = c.CODIGO_CONTA
        LEFT JOIN BANCO.Banco b ON b.CODIGO = c.BANCO_CODIGO
        WHERE c.DESTINO = 'CONTA';

        UPDATE d
           SET d.ID_EMPRESA = s.ID_EMPRESA, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.ID_BANCO = s.ID_BANCO,
               d.AGENCIA = s.AGENCIA, d.NUMERO = s.NUMERO, d.NUMERO_DV = s.NUMERO_DV, d.LIMITE_CREDITO = s.LIMITE_CREDITO,
               d.CONCILIA = s.CONCILIA, d.MOSTRA_SALDO = s.MOSTRA_SALDO, d.ATIVO = s.ATIVO,
               d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM BANCO.Conta d
        INNER JOIN #Cta s ON s.CODIGO_CONTA = d.CODIGO_ACCESS
        WHERE EXISTS (SELECT d.ID_EMPRESA, d.DESCRICAO, d.TIPO, d.ID_BANCO, d.AGENCIA, d.NUMERO, d.NUMERO_DV, d.LIMITE_CREDITO, d.CONCILIA, d.MOSTRA_SALDO, d.ATIVO
                      EXCEPT
                      SELECT s.ID_EMPRESA, s.DESCRICAO, s.TIPO, s.ID_BANCO, s.AGENCIA, s.NUMERO, s.NUMERO_DV, s.LIMITE_CREDITO, s.CONCILIA, s.MOSTRA_SALDO, s.ATIVO);

        INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, ID_BANCO, AGENCIA, NUMERO, NUMERO_DV, LIMITE_CREDITO, CONCILIA, MOSTRA_SALDO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.ID_EMPRESA, s.DESCRICAO, s.TIPO, s.ID_BANCO, s.AGENCIA, s.NUMERO, s.NUMERO_DV, s.LIMITE_CREDITO, s.CONCILIA, s.MOSTRA_SALDO, s.ATIVO, s.CODIGO_CONTA, @Usuario
        FROM #Cta s
        WHERE NOT EXISTS (SELECT 1 FROM BANCO.Conta d WHERE d.CODIGO_ACCESS = s.CODIGO_CONTA);

        INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, CONCILIA, MOSTRA_SALDO, ATIVO, USUARIO_CRIACAO)
        SELECT e.ID_EMPRESA, @NomeCaixaContabil, 'CAIXA', 0, 1, 1, @Usuario
        FROM CAD.Empresa e
        INNER JOIN #Emp s ON s.CODIGO_MASTER = e.CODIGO_ACCESS
        WHERE NOT EXISTS (SELECT 1 FROM BANCO.Conta d WHERE d.ID_EMPRESA = e.ID_EMPRESA AND d.DESCRICAO = @NomeCaixaContabil);

        /* ------------------------------------------------------------------
           3. Pessoas (Parceiros) e contatos
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Pessoas';
        ;WITH Fonte AS
        (
            SELECT TRY_CONVERT(INT, p.CodigoParceiro) AS COD, p.*,
                   CAD.fn_CAD_Somente_Digitos(p.CNPJ) AS CNPJ_D,
                   CAD.fn_CAD_Somente_Digitos(p.CPF)  AS CPF_D
            FROM MIG.Access_Parceiros p
            WHERE TRY_CONVERT(INT, p.CodigoParceiro) > 1
              AND ISNULL(p.Master, N'False') <> N'True'
              AND LTRIM(RTRIM(ISNULL(p.NomeParceiro, N''))) <> N''
        ),
        Doc AS
        (
            SELECT f.*,
                   CASE WHEN LEN(f.CNPJ_D) BETWEEN 12 AND 14 THEN RIGHT('00' + f.CNPJ_D, 14) ELSE '' END AS CNPJ_OK,
                   CASE WHEN LEN(f.CPF_D)  BETWEEN 9  AND 11 THEN RIGHT('00' + f.CPF_D, 11)  ELSE '' END AS CPF_OK
            FROM Fonte f
        )
        SELECT d.COD,
               CAST(LEFT(LTRIM(RTRIM(d.NomeParceiro)), 150) AS NVARCHAR(150)) AS NOME,
               CAST(CASE WHEN d.CNPJ_OK <> '' THEN d.CNPJ_OK WHEN d.CPF_OK <> '' THEN d.CPF_OK ELSE '' END AS VARCHAR(14)) AS CPF_CNPJ,
               CAST(CASE WHEN d.CNPJ_OK <> '' THEN 'J'
                         WHEN d.CPF_OK  <> '' THEN 'F'
                         WHEN d.NomeParceiro LIKE N'%ltda%' OR d.NomeParceiro LIKE N'% s/a%' OR d.NomeParceiro LIKE N'% s.a%' OR d.NomeParceiro LIKE N'% sa'
                           OR d.NomeParceiro LIKE N'% me' OR d.NomeParceiro LIKE N'% epp' OR d.NomeParceiro LIKE N'%eireli%' OR d.NomeParceiro LIKE N'%com_rcio%'
                           OR d.NomeParceiro LIKE N'%ind_stria%' OR d.NomeParceiro LIKE N'%construtora%' OR d.NomeParceiro LIKE N'%condom_nio%'
                           OR d.NomeParceiro LIKE N'%associa__o%' OR d.NomeParceiro LIKE N'%prefeitura%' OR d.NomeParceiro LIKE N'%banco %'
                           OR d.NomeParceiro LIKE N'% cia%' OR d.NomeParceiro LIKE N'%companhia%' OR d.NomeParceiro LIKE N'%servi_os%'
                           OR d.NomeParceiro LIKE N'%distribuidora%' OR d.NomeParceiro LIKE N'%materiais%' OR d.NomeParceiro LIKE N'%engenharia%'
                           OR d.NomeParceiro LIKE N'%transporte%' OR d.NomeParceiro LIKE N'%imobili_ri%' OR d.NomeParceiro LIKE N'%cart_rio%'
                           OR d.NomeParceiro LIKE N'%receita federal%' OR d.NomeParceiro LIKE N'%sindicato%' OR d.NomeParceiro LIKE N'%hotel%'
                           OR d.NomeParceiro LIKE N'%depto%' OR d.NomeParceiro LIKE N'%departamento%' OR d.NomeParceiro LIKE N'%funda__o%'
                           OR d.NomeParceiro LIKE N'%instituto%' OR d.NomeParceiro LIKE N'%escrit_rio%' OR d.NomeParceiro LIKE N'%incorporadora%'
                           OR d.NomeParceiro LIKE N'% spe%' OR d.NomeParceiro LIKE N'%loja%' OR d.NomeParceiro LIKE N'%posto %'
                           OR d.NomeParceiro LIKE N'%concreto%' OR d.NomeParceiro LIKE N'%madeireira%' OR d.NomeParceiro LIKE N'%ferragens%'
                           OR d.NomeParceiro LIKE N'%telecom%' OR d.NomeParceiro LIKE N'%cemig%' OR d.NomeParceiro LIKE N'%copasa%'
                           OR d.NomeParceiro LIKE N'%dmae%' OR d.NomeParceiro LIKE N'%sicredi%' OR d.NomeParceiro LIKE N'%ita[uú]%'
                         THEN 'J' ELSE 'F' END AS CHAR(1)) AS TIPO_PESSOA,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.RG, N''))), 20) AS VARCHAR(20)) AS RG,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.IE, N''))), 20) AS VARCHAR(20)) AS INSCRICAO_ESTADUAL,
               CAST(CASE WHEN LEN(CAD.fn_CAD_Somente_Digitos(d.CEP)) = 8 THEN CAD.fn_CAD_Somente_Digitos(d.CEP) ELSE '' END AS VARCHAR(8)) AS CEP,
               en.LOGRADOURO, en.NUMERO, en.COMPLEMENTO, en.RECONHECIDO AS ENDERECO_RECONHECIDO,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.Bairro, N''))), 60) AS NVARCHAR(60)) AS BAIRRO,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.Cidade, N''))), 60) AS NVARCHAR(60)) AS CIDADE,
               CAST(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(d.Estado, N'')))) = 2 AND UPPER(LTRIM(RTRIM(d.Estado))) NOT LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2
                         THEN UPPER(LTRIM(RTRIM(d.Estado))) ELSE '' END AS CHAR(2)) AS UF,
               CAST(CASE WHEN d.Cliente = N'True' THEN 1 ELSE 0 END AS BIT) AS CLIENTE,
               CAST(CASE WHEN d.Fornecedor = N'True' THEN 1 ELSE 0 END AS BIT) AS FORNECEDOR,
               CAST(CASE WHEN d.Funcionario = N'True' THEN 1 ELSE 0 END AS BIT) AS FUNCIONARIO,
               CAST(CASE WHEN d.Inativo = N'True' THEN 0 ELSE 1 END AS BIT) AS ATIVO,
               CAST(LEFT(CONCAT_WS(N' | ',
                        NULLIF(LTRIM(RTRIM(ISNULL(d.Observacoes, N''))), N''),
                        N'Contato: ' + NULLIF(LTRIM(RTRIM(ISNULL(d.Contato, N''))), N''),
                        N'Trabalho: ' + NULLIF(LTRIM(RTRIM(ISNULL(d.Trabalho, N''))), N''),
                        N'Ramal: ' + NULLIF(LTRIM(RTRIM(ISNULL(d.Ramal, N''))), N''),
                        CASE WHEN d.CNPJ_OK <> '' AND d.CPF_OK <> '' THEN N'CPF no Access: ' + d.CPF_OK END,
                        CASE WHEN d.CNPJ_OK = '' AND d.CNPJ_D <> '' THEN N'CNPJ no Access (incompleto): ' + d.CNPJ_D END,
                        CASE WHEN d.CPF_OK = '' AND d.CPF_D <> '' THEN N'CPF no Access (incompleto): ' + d.CPF_D END,
                        CASE WHEN LEN(CAD.fn_CAD_Somente_Digitos(d.CEP)) NOT IN (0, 8) THEN N'CEP no Access: ' + d.CEP END,
                        CASE WHEN LEN(LTRIM(RTRIM(ISNULL(d.Estado, N'')))) NOT IN (0, 2) THEN N'UF no Access: ' + d.Estado END
                    ), 1800) AS NVARCHAR(2000)) AS OBSERVACAO,
               d.Email, d.Telefone, d.TelefoneComercial, d.Fax
        INTO #Pes
        FROM Doc d
        CROSS APPLY MIG.fn_MIG_Endereco_Separar(LEFT(LTRIM(RTRIM(ISNULL(d.Endereco, N''))), 150)) en;  -- v1.2: número e complemento separados

        -- contatos candidatos (e-mail separado por ; , espaço ou #mailto:; telefone só dígitos)
        SELECT x.COD, x.TIPO, x.VALOR, x.ORIGEM, x.ORDEM,
               CAST(CASE WHEN x.TIPO = 'EMAIL' THEN SIS.fn_SIS_Email_Valido(x.VALOR)
                         WHEN LEN(x.VALOR) BETWEEN 10 AND 13 THEN 1 ELSE 0 END AS BIT) AS VALIDO
        INTO #Ctt
        FROM (
            SELECT p.COD, CAST('EMAIL' AS VARCHAR(10)) AS TIPO, CAST(LOWER(LTRIM(RTRIM(s.value))) AS NVARCHAR(256)) AS VALOR,
                   CAST(N'E-mail' AS NVARCHAR(30)) AS ORIGEM, s.ordinal AS ORDEM
            FROM #Pes p
            CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p.Email, N''), N'mailto:', N';'), N'#', N';'), N',', N';'), N' ', N';'), N';', 1) s
            WHERE LTRIM(RTRIM(s.value)) <> N''
            UNION ALL
            SELECT p.COD,
                   CAST(CASE WHEN LEN(t.D) = 11 AND SUBSTRING(t.D, 3, 1) = '9' THEN 'CELULAR' ELSE 'TELEFONE' END AS VARCHAR(10)),
                   CAST(t.D AS NVARCHAR(256)), t.ORIGEM, 100 + t.ORDEM
            FROM #Pes p
            CROSS APPLY (VALUES (CAD.fn_CAD_Somente_Digitos(p.Telefone), N'Telefone', 1),
                                (CAD.fn_CAD_Somente_Digitos(p.TelefoneComercial), N'Telefone comercial', 2),
                                (CAD.fn_CAD_Somente_Digitos(p.Fax), N'Fax', 3)) t (D, ORIGEM, ORDEM)
            WHERE t.D <> ''
        ) x;

        -- o que não é contato válido vai para a observação (nada se perde)
        UPDATE p
           SET p.OBSERVACAO = CAST(LEFT(CONCAT_WS(N' | ', NULLIF(p.OBSERVACAO, N''), i.TEXTO), 2000) AS NVARCHAR(2000))
        FROM #Pes p
        INNER JOIN (SELECT c.COD, STRING_AGG(CAST(c.ORIGEM + N' no Access: ' + c.VALOR AS NVARCHAR(MAX)), N' | ') AS TEXTO
                    FROM #Ctt c WHERE c.VALIDO = 0 GROUP BY c.COD) i ON i.COD = p.COD;

        UPDATE d
           SET d.TIPO_PESSOA = s.TIPO_PESSOA, d.NOME = s.NOME, d.CPF_CNPJ = s.CPF_CNPJ, d.RG = s.RG, d.INSCRICAO_ESTADUAL = s.INSCRICAO_ESTADUAL,
               d.CEP = s.CEP, d.LOGRADOURO = s.LOGRADOURO, d.NUMERO = s.NUMERO, d.COMPLEMENTO = s.COMPLEMENTO, d.BAIRRO = s.BAIRRO, d.CIDADE = s.CIDADE, d.UF = s.UF,
               d.CLIENTE = s.CLIENTE, d.FORNECEDOR = s.FORNECEDOR, d.FUNCIONARIO = s.FUNCIONARIO, d.OBSERVACAO = s.OBSERVACAO, d.ATIVO = s.ATIVO,
               d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Pessoa d
        INNER JOIN #Pes s ON s.COD = d.CODIGO_ACCESS
        WHERE EXISTS (SELECT d.TIPO_PESSOA, d.NOME, d.CPF_CNPJ, d.RG, d.INSCRICAO_ESTADUAL, d.CEP, d.LOGRADOURO, d.NUMERO, d.COMPLEMENTO, d.BAIRRO, d.CIDADE, d.UF,
                             d.CLIENTE, d.FORNECEDOR, d.FUNCIONARIO, d.OBSERVACAO, d.ATIVO
                      EXCEPT
                      SELECT s.TIPO_PESSOA, s.NOME, s.CPF_CNPJ, s.RG, s.INSCRICAO_ESTADUAL, s.CEP, s.LOGRADOURO, s.NUMERO, s.COMPLEMENTO, s.BAIRRO, s.CIDADE, s.UF,
                             s.CLIENTE, s.FORNECEDOR, s.FUNCIONARIO, s.OBSERVACAO, s.ATIVO);

        INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ, RG, INSCRICAO_ESTADUAL, CEP, LOGRADOURO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF,
                                CLIENTE, FORNECEDOR, FUNCIONARIO, OBSERVACAO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.TIPO_PESSOA, s.NOME, s.CPF_CNPJ, s.RG, s.INSCRICAO_ESTADUAL, s.CEP, s.LOGRADOURO, s.NUMERO, s.COMPLEMENTO, s.BAIRRO, s.CIDADE, s.UF,
               s.CLIENTE, s.FORNECEDOR, s.FUNCIONARIO, s.OBSERVACAO, s.ATIVO, s.COD, @Usuario
        FROM #Pes s
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa d WHERE d.CODIGO_ACCESS = s.COD);

        ;WITH V AS
        (
            SELECT p.ID_PESSOA, c.TIPO, c.VALOR, MIN(c.ORDEM) AS ORDEM, MAX(CAST(pe.CLIENTE AS INT)) AS CLIENTE
            FROM #Ctt c
            INNER JOIN #Pes pe ON pe.COD = c.COD
            INNER JOIN CAD.Pessoa p ON p.CODIGO_ACCESS = c.COD
            WHERE c.VALIDO = 1
            GROUP BY p.ID_PESSOA, c.TIPO, c.VALOR
        ),
        N AS
        (
            SELECT v.*, ROW_NUMBER() OVER (PARTITION BY v.ID_PESSOA, CASE WHEN v.TIPO = 'EMAIL' THEN 1 ELSE 2 END ORDER BY v.ORDEM) AS RN
            FROM V v
        )
        INSERT INTO CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR, PRINCIPAL, RECEBE_COBRANCA, USUARIO_CRIACAO)
        SELECT n.ID_PESSOA, n.TIPO, n.VALOR,
               CAST(CASE WHEN n.RN = 1 THEN 1 ELSE 0 END AS BIT),
               CAST(CASE WHEN n.TIPO = 'EMAIL' AND n.CLIENTE = 1 THEN 1 ELSE 0 END AS BIT),
               @Usuario
        FROM N n
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato x WHERE x.ID_PESSOA = n.ID_PESSOA AND x.TIPO = n.TIPO AND x.VALOR = n.VALOR);

        /* ------------------------------------------------------------------
           4. Centros de custo: obras/empresas vinculadas do Access + extras
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Centros de custo';
        SELECT TRY_CONVERT(INT, v.CodigoVinculada) AS COD,
               CAST(CASE WHEN c.CODIGO_VINCULADA IS NOT NULL THEN c.DESTINO
                         WHEN ce.DESTINO = 'NAO_MIGRA' THEN 'NAO_MIGRA'
                         ELSE 'CENTRO' END AS VARCHAR(10)) AS DESTINO,
               CAST(COALESCE(NULLIF(c.CODIGO, ''), 'A' + LTRIM(RTRIM(v.CodigoVinculada))) AS VARCHAR(20)) AS CODIGO,
               CAST(LEFT(COALESCE(NULLIF(c.DESCRICAO, N''), NULLIF(LTRIM(RTRIM(v.NomeVinculada)), N''), LTRIM(RTRIM(m.NomeMaster)),
                                  N'Centro ' + LTRIM(RTRIM(v.CodigoVinculada))), 100) AS NVARCHAR(100)) AS DESCRICAO,
               CAST(COALESCE(NULLIF(c.TIPO, ''),
                             CASE WHEN v.Administracao = N'True' OR v.Custos = N'True' OR v.ImovelEmVenda = N'True' THEN 'OBRA' ELSE 'ADMINISTRATIVO' END) AS VARCHAR(15)) AS TIPO,
               COALESCE(c.CODIGO_MASTER_EMPRESA, CASE WHEN ce.DESTINO = 'EMPRESA' THEN ce.CODIGO_MASTER END, @MasterPrinc) AS MASTER_EMPRESA,
               CAST(CASE WHEN v.Contabil = N'True' THEN 1 ELSE 0 END AS BIT) AS CONTABIL,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM #UsoCentro u WHERE u.COD = TRY_CONVERT(INT, v.CodigoVinculada)) THEN 1 ELSE 0 END AS BIT) AS ATIVO,
               COALESCE(c.CODIGO_CONTA_PADRAO, TRY_CONVERT(INT, v.FinanceiraPadrao)) AS CONTA_ACCESS,
               c.PARCEIRO_CLIENTE,
               ISNULL(TRY_CONVERT(DECIMAL(9,4), v.PercentualAdm), 0) AS PERCENTUAL_ADM,
               CAST(CASE WHEN c.CODIGO_VINCULADA IS NULL OR c.TIPO = '' THEN 1 ELSE 0 END AS BIT) AS AUTOMATICA,
               CAST(NULL AS INT) AS ID_EMPRESA,
               CAST(NULL AS INT) AS ID_CONTA_PADRAO
        INTO #CC
        FROM MIG.Access_EmpVinculada v
        LEFT JOIN MIG.Classif_Centro c   ON c.CODIGO_VINCULADA = TRY_CONVERT(INT, v.CodigoVinculada)
        LEFT JOIN MIG.Access_EmpMaster m ON m.CodigoMaster = v.CodigoMaster
        LEFT JOIN MIG.Classif_Empresa ce ON ce.CODIGO_MASTER = TRY_CONVERT(INT, v.CodigoMaster)
        WHERE TRY_CONVERT(INT, v.CodigoVinculada) IS NOT NULL;

        DELETE FROM #CC WHERE DESTINO = 'NAO_MIGRA';

        UPDATE c SET c.ID_EMPRESA = ISNULL(e.ID_EMPRESA, @IdPrincipal)
        FROM #CC c LEFT JOIN CAD.Empresa e ON e.CODIGO_ACCESS = c.MASTER_EMPRESA;

        -- conta padrão só quando a conta é da mesma empresa do centro
        UPDATE c SET c.ID_CONTA_PADRAO = k.ID_CONTA
        FROM #CC c INNER JOIN BANCO.Conta k ON k.CODIGO_ACCESS = c.CONTA_ACCESS AND k.ID_EMPRESA = c.ID_EMPRESA;

        IF EXISTS (SELECT c.CODIGO FROM #CC c GROUP BY c.CODIGO HAVING COUNT(*) > 1)
            THROW 50001, N'Há código de centro de custo repetido na classificação (MIG.Classif_Centro).', 1;

        UPDATE d
           SET d.ID_EMPRESA = s.ID_EMPRESA, d.CODIGO = s.CODIGO, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CONTABIL = s.CONTABIL,
               d.ID_CONTA_BANCARIA_PADRAO = s.ID_CONTA_PADRAO, d.ATIVO = s.ATIVO, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Centro_Custo d
        INNER JOIN #CC s ON s.COD = d.CODIGO_ACCESS
        WHERE EXISTS (SELECT d.ID_EMPRESA, d.CODIGO, d.DESCRICAO, d.TIPO, d.CONTABIL, d.ID_CONTA_BANCARIA_PADRAO, d.ATIVO
                      EXCEPT
                      SELECT s.ID_EMPRESA, s.CODIGO, s.DESCRICAO, s.TIPO, s.CONTABIL, s.ID_CONTA_PADRAO, s.ATIVO);

        INSERT INTO CAD.Centro_Custo (ID_EMPRESA, CODIGO, DESCRICAO, TIPO, CONTABIL, ID_CONTA_BANCARIA_PADRAO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.ID_EMPRESA, s.CODIGO, s.DESCRICAO, s.TIPO, s.CONTABIL, s.ID_CONTA_PADRAO, s.ATIVO, s.COD, @Usuario
        FROM #CC s
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo d WHERE d.CODIGO_ACCESS = s.COD);

        -- centros extras (imóveis próprios e particulares): ativos se alguma conta do plano que aponta para eles foi usada
        ;WITH X AS
        (
            SELECT x.CODIGO, x.DESCRICAO, x.TIPO, x.CONTABIL, ISNULL(e.ID_EMPRESA, @IdPrincipal) AS ID_EMPRESA,
                   CAST(CASE WHEN x.ATIVO IS NOT NULL THEN x.ATIVO
                             WHEN EXISTS (SELECT 1 FROM MIG.DePara_Plano_Excecao p INNER JOIN #UsoPlano u ON u.COD = p.PLANO3_ACCESS
                                          WHERE p.CENTRO_CODIGO = x.CODIGO) THEN 1 ELSE 0 END AS BIT) AS ATIVO
            FROM MIG.Classif_Centro_Extra x
            LEFT JOIN CAD.Empresa e ON e.CODIGO_ACCESS = x.CODIGO_MASTER_EMPRESA
        )
        MERGE CAD.Centro_Custo AS d
        USING X AS s ON d.CODIGO = s.CODIGO AND d.CODIGO_ACCESS IS NULL
        WHEN MATCHED AND EXISTS (SELECT d.ID_EMPRESA, d.DESCRICAO, d.TIPO, d.CONTABIL, d.ATIVO EXCEPT SELECT s.ID_EMPRESA, s.DESCRICAO, s.TIPO, s.CONTABIL, s.ATIVO)
            THEN UPDATE SET d.ID_EMPRESA = s.ID_EMPRESA, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CONTABIL = s.CONTABIL, d.ATIVO = s.ATIVO,
                            d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        WHEN NOT MATCHED THEN INSERT (ID_EMPRESA, CODIGO, DESCRICAO, TIPO, CONTABIL, ATIVO, USUARIO_CRIACAO)
            VALUES (s.ID_EMPRESA, s.CODIGO, s.DESCRICAO, s.TIPO, s.CONTABIL, s.ATIVO, @Usuario);

        -- conta padrão da empresa (só se estiver vazia): a do centro administrativo, senão a da obra ativa mais usada
        UPDATE e
           SET e.ID_CONTA_BANCARIA_PADRAO = k.ID_CONTA, e.DT_ALTERACAO = @Agora, e.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Empresa e
        CROSS APPLY (SELECT TOP (1) c.ID_CONTA_PADRAO AS ID_CONTA
                     FROM #CC c
                     WHERE c.ID_EMPRESA = e.ID_EMPRESA AND c.ID_CONTA_PADRAO IS NOT NULL
                     ORDER BY CASE WHEN c.TIPO = 'ADMINISTRATIVO' THEN 0 ELSE 1 END, c.ATIVO DESC, c.COD) k
        WHERE e.ID_CONTA_BANCARIA_PADRAO IS NULL
          AND e.CODIGO_ACCESS IS NOT NULL;

        DELETE FROM MIG.DePara_Centro;
        INSERT INTO MIG.DePara_Centro (CODIGO_VINCULADA, ID_CENTRO_CUSTO, ID_EMPRESA, ID_PESSOA_CLIENTE, PERCENTUAL_ADM, ID_CONTA_PADRAO, CLASSIF_AUTOMATICA)
        SELECT s.COD, d.ID_CENTRO_CUSTO, d.ID_EMPRESA, p.ID_PESSOA, s.PERCENTUAL_ADM, s.ID_CONTA_PADRAO, s.AUTOMATICA
        FROM #CC s
        INNER JOIN CAD.Centro_Custo d ON d.CODIGO_ACCESS = s.COD
        LEFT JOIN CAD.Pessoa p ON p.CODIGO_ACCESS = s.PARCEIRO_CLIENTE;

        /* ------------------------------------------------------------------
           5. Históricos padrão (mesmo texto em dois códigos vira um só)
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Históricos';
        SELECT MIN(TRY_CONVERT(INT, h.CodHistorico)) AS COD, CAST(LEFT(LTRIM(RTRIM(h.Descricao)), 80) AS NVARCHAR(80)) AS DESCRICAO
        INTO #Hist
        FROM MIG.Access_Historico h
        WHERE LTRIM(RTRIM(ISNULL(h.Descricao, N''))) NOT IN (N'', N'sistema')   -- os marcados Master no Access (Pgto Efetuado, Depósito...) são usados
          AND TRY_CONVERT(INT, h.CodHistorico) IS NOT NULL
        GROUP BY CAST(LEFT(LTRIM(RTRIM(h.Descricao)), 80) AS NVARCHAR(80));

        INSERT INTO FIN.Historico_Padrao (DESCRICAO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.DESCRICAO, 1, s.COD, @Usuario
        FROM #Hist s
        WHERE NOT EXISTS (SELECT 1 FROM FIN.Historico_Padrao d WHERE d.CODIGO_ACCESS = s.COD OR d.DESCRICAO = s.DESCRICAO);

        /* ------------------------------------------------------------------
           6. Plano de contas
              NOVO      = grupo do Access com número no nome (00 a 18): número
                          e texto separados pelo fn_MIG_Plano_Desmontar;
              HISTORICO = grupo antigo listado em Config_Plano_Grupo
                          (PLANO1_ACCESS): inativo, numeração sequencial;
              EXCECAO   = DePara_Plano_Excecao.
              Só migram contas com algum movimento no Access.
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Plano: leitura';
        SELECT TRY_CONVERT(INT, p3.Plano3) AS P3, TRY_CONVERT(INT, p2.Plano2) AS P2, TRY_CONVERT(INT, p1.Plano1) AS P1,
               CAST(CASE WHEN g.NUMERO IS NOT NULL THEN 'HISTORICO'
                         WHEN LTRIM(p1.DescricaoPlano1) LIKE N'[0-9][0-9]%' THEN 'NOVO' END AS VARCHAR(12)) AS REGRA,
               CAST(COALESCE(g.NUMERO, TRY_CONVERT(SMALLINT, LEFT(LTRIM(p1.DescricaoPlano1), 2))) AS SMALLINT) AS G_NUM,
               d2.NUMERO_2 AS S_NUM_ACCESS, d2.QTD_NUMEROS AS S_QTD,
               CAST(LEFT(CASE WHEN g.NUMERO IS NULL THEN COALESCE(NULLIF(d2.TEXTO, N''), LTRIM(RTRIM(p2.DescricaoPlano2))) ELSE LTRIM(RTRIM(p2.DescricaoPlano2)) END, 80) AS NVARCHAR(80)) AS S_DESC,
               d3.NUMERO_ULTIMO AS C_NUM_ACCESS, d3.QTD_NUMEROS AS C_QTD,
               CAST(LEFT(CASE WHEN g.NUMERO IS NULL THEN COALESCE(NULLIF(d3.TEXTO, N''), LTRIM(RTRIM(p3.DescricaoPlano3))) ELSE LTRIM(RTRIM(p3.DescricaoPlano3)) END, 80) AS NVARCHAR(80)) AS C_DESC,
               CAST(NULL AS SMALLINT) AS S_NUM, CAST(NULL AS SMALLINT) AS C_NUM,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM MIG.DePara_Plano_Excecao x WHERE x.PLANO3_ACCESS = TRY_CONVERT(INT, p3.Plano3)) THEN 1 ELSE 0 END AS BIT) AS TEM_EXCECAO
        INTO #P3
        FROM MIG.Access_Plano3 p3
        INNER JOIN MIG.Access_Plano2 p2 ON p2.Plano2 = p3.Plano2
        INNER JOIN MIG.Access_Plano1 p1 ON p1.Plano1 = p2.Plano1
        LEFT JOIN MIG.Config_Plano_Grupo g ON g.PLANO1_ACCESS = TRY_CONVERT(INT, p1.Plano1)
        CROSS APPLY MIG.fn_MIG_Plano_Desmontar(p2.DescricaoPlano2) d2
        CROSS APPLY MIG.fn_MIG_Plano_Desmontar(p3.DescricaoPlano3) d3
        WHERE EXISTS (SELECT 1 FROM #UsoPlanoTotal u WHERE u.COD = TRY_CONVERT(INT, p3.Plano3))
          AND LTRIM(RTRIM(ISNULL(p3.DescricaoPlano3, N''))) <> N''
          AND ISNULL(p3.Master, N'False') <> N'True';

        DELETE FROM #P3 WHERE REGRA IS NULL OR S_DESC = N'' OR C_DESC = N'';
        -- conta do plano novo que muda inteira de lugar (exceção) não fica vazia no lugar antigo
        DELETE FROM #P3 WHERE REGRA = 'NOVO' AND TEM_EXCECAO = 1;

        IF EXISTS (SELECT 1 FROM #P3 p WHERE NOT EXISTS (SELECT 1 FROM MIG.Config_Plano_Grupo g WHERE g.NUMERO = p.G_NUM))
            THROW 50001, N'Há grupo do plano de contas do Access sem configuração (MIG.Config_Plano_Grupo).', 1;

        SET @EtapaAtual = 'Plano: numeração';
        -- subgrupo: número do Access (plano novo) ou sequencial; mesmo nome no mesmo grupo vira um só
        ;WITH S AS
        (
            SELECT DISTINCT p.G_NUM, p.P2, p.REGRA, p.S_DESC,
                   CASE WHEN p.REGRA = 'NOVO' AND p.S_QTD >= 2 AND p.S_NUM_ACCESS BETWEEN 1 AND 99 THEN p.S_NUM_ACCESS END AS N_ACCESS
            FROM #P3 p
        ),
        S1 AS
        (
            SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.G_NUM, s.N_ACCESS ORDER BY s.P2) AS RN_NUM,
                        MIN(s.P2) OVER (PARTITION BY s.G_NUM, s.S_DESC) AS P2_DONO
            FROM S s
        ),
        S2 AS
        (
            SELECT s.*, CASE WHEN s.N_ACCESS IS NOT NULL AND s.RN_NUM = 1 THEN s.N_ACCESS END AS N_FIXO
            FROM S1 s WHERE s.P2 = s.P2_DONO
        ),
        S3 AS
        (
            SELECT s.*, ISNULL(MAX(s.N_FIXO) OVER (PARTITION BY s.G_NUM), 0)
                        + ROW_NUMBER() OVER (PARTITION BY s.G_NUM, CASE WHEN s.N_FIXO IS NULL THEN 1 ELSE 0 END ORDER BY s.P2) AS N_SEQ
            FROM S2 s
        )
        SELECT s.G_NUM, s.P2, CAST(ISNULL(s.N_FIXO, s.N_SEQ) AS SMALLINT) AS S_NUM, s.S_DESC
        INTO #SubNum
        FROM S3 s;

        UPDATE p SET p.S_NUM = s.S_NUM
        FROM #P3 p
        INNER JOIN #SubNum s ON s.G_NUM = p.G_NUM AND (s.P2 = p.P2 OR (s.S_DESC = p.S_DESC AND NOT EXISTS (SELECT 1 FROM #SubNum z WHERE z.P2 = p.P2)));

        -- conta: número do Access (plano novo, 3 partes) ou sequencial; mesmo nome no mesmo subgrupo vira uma só
        ;WITH C AS
        (
            SELECT p.P3, p.G_NUM, p.S_NUM, p.C_DESC,
                   CASE WHEN p.REGRA = 'NOVO' AND p.C_QTD >= 3 AND p.C_NUM_ACCESS BETWEEN 1 AND 999 THEN p.C_NUM_ACCESS END AS N_ACCESS
            FROM #P3 p
        ),
        C1 AS
        (
            SELECT c.*, MIN(c.P3) OVER (PARTITION BY c.G_NUM, c.S_NUM, c.C_DESC) AS P3_DONO,
                        ROW_NUMBER() OVER (PARTITION BY c.G_NUM, c.S_NUM, c.N_ACCESS ORDER BY c.P3) AS RN_NUM
            FROM C c
        ),
        C2 AS
        (
            SELECT c.*, CASE WHEN c.N_ACCESS IS NOT NULL AND c.RN_NUM = 1 THEN c.N_ACCESS END AS N_FIXO
            FROM C1 c WHERE c.P3 = c.P3_DONO
        ),
        C3 AS
        (
            SELECT c.*, ISNULL(MAX(c.N_FIXO) OVER (PARTITION BY c.G_NUM, c.S_NUM), 0)
                        + ROW_NUMBER() OVER (PARTITION BY c.G_NUM, c.S_NUM, CASE WHEN c.N_FIXO IS NULL THEN 1 ELSE 0 END ORDER BY c.P3) AS N_SEQ
            FROM C2 c
        )
        UPDATE p SET p.C_NUM = CAST(ISNULL(c.N_FIXO, c.N_SEQ) AS SMALLINT)
        FROM #P3 p
        INNER JOIN C3 c ON c.G_NUM = p.G_NUM AND c.S_NUM = p.S_NUM AND c.C_DESC = p.C_DESC;

        IF EXISTS (SELECT 1 FROM #P3 p WHERE p.S_NUM IS NULL OR p.C_NUM IS NULL OR p.C_NUM > 999 OR p.S_NUM > 99)
            THROW 50001, N'Não foi possível numerar alguma conta do plano (subgrupo acima de 99 ou conta acima de 999).', 1;

        -- grupos, subgrupos e contas de destino
        SELECT p.G_NUM AS NUMERO INTO #Grupo FROM #P3 p
        UNION SELECT x.GRUPO_NUMERO FROM MIG.DePara_Plano_Excecao x WHERE x.GRUPO_NUMERO IS NOT NULL;

        SELECT p.G_NUM, p.S_NUM, MIN(p.S_DESC) AS S_DESC, MAX(CASE WHEN p.REGRA = 'HISTORICO' THEN 0 ELSE 1 END) AS ATIVO
        INTO #SubDest
        FROM #P3 p
        GROUP BY p.G_NUM, p.S_NUM;
        INSERT INTO #SubDest (G_NUM, S_NUM, S_DESC, ATIVO)
        SELECT x.GRUPO_NUMERO, x.SUBGRUPO_NUMERO, MIN(x.SUBGRUPO_DESCRICAO), 1
        FROM MIG.DePara_Plano_Excecao x
        WHERE x.GRUPO_NUMERO IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM #SubDest s WHERE s.G_NUM = x.GRUPO_NUMERO AND s.S_NUM = x.SUBGRUPO_NUMERO)
        GROUP BY x.GRUPO_NUMERO, x.SUBGRUPO_NUMERO;

        SELECT p.G_NUM, p.S_NUM, p.C_NUM, MIN(p.C_DESC) AS C_DESC, MIN(p.P3) AS P3, MAX(CASE WHEN p.REGRA = 'HISTORICO' THEN 0 ELSE 1 END) AS ATIVO
        INTO #ContaDest
        FROM #P3 p
        GROUP BY p.G_NUM, p.S_NUM, p.C_NUM;
        INSERT INTO #ContaDest (G_NUM, S_NUM, C_NUM, C_DESC, P3, ATIVO)
        SELECT x.GRUPO_NUMERO, x.SUBGRUPO_NUMERO, x.CONTA_NUMERO, MIN(x.CONTA_DESCRICAO), NULL, 1
        FROM MIG.DePara_Plano_Excecao x
        WHERE x.GRUPO_NUMERO IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM #ContaDest c WHERE c.G_NUM = x.GRUPO_NUMERO AND c.S_NUM = x.SUBGRUPO_NUMERO AND c.C_NUM = x.CONTA_NUMERO)
        GROUP BY x.GRUPO_NUMERO, x.SUBGRUPO_NUMERO, x.CONTA_NUMERO;

        SET @EtapaAtual = 'Plano: gravação';
        MERGE CAD.Plano_Grupo AS d
        USING (SELECT g.NUMERO, c.DESCRICAO, c.TIPO, c.CUSTO_OBRA, c.ATIVO, c.NUMERO AS ORDEM
               FROM #Grupo g INNER JOIN MIG.Config_Plano_Grupo c ON c.NUMERO = g.NUMERO) AS s
        ON d.NUMERO = s.NUMERO
        WHEN MATCHED AND EXISTS (SELECT d.DESCRICAO, d.TIPO, d.CUSTO_OBRA, d.ATIVO EXCEPT SELECT s.DESCRICAO, s.TIPO, s.CUSTO_OBRA, s.ATIVO)
            THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CUSTO_OBRA = s.CUSTO_OBRA, d.ATIVO = s.ATIVO,
                            d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        WHEN NOT MATCHED THEN INSERT (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ORDEM, ATIVO, USUARIO_CRIACAO)
            VALUES (s.NUMERO, s.DESCRICAO, s.TIPO, s.CUSTO_OBRA, s.ORDEM, s.ATIVO, @Usuario);

        MERGE CAD.Plano_Subgrupo AS d
        USING (SELECT g.ID_PLANO_GRUPO, s.S_NUM AS NUMERO, CAST(s.S_DESC AS NVARCHAR(80)) AS DESCRICAO, CAST(s.ATIVO AS BIT) AS ATIVO
               FROM #SubDest s INNER JOIN CAD.Plano_Grupo g ON g.NUMERO = s.G_NUM) AS s
        ON d.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO AND d.NUMERO = s.NUMERO
        WHEN MATCHED AND EXISTS (SELECT d.DESCRICAO, d.ATIVO EXCEPT SELECT s.DESCRICAO, s.ATIVO)
            THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.ATIVO = s.ATIVO, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        WHEN NOT MATCHED THEN INSERT (ID_PLANO_GRUPO, NUMERO, DESCRICAO, ORDEM, ATIVO, USUARIO_CRIACAO)
            VALUES (s.ID_PLANO_GRUPO, s.NUMERO, s.DESCRICAO, s.NUMERO, s.ATIVO, @Usuario);

        MERGE CAD.Plano_Conta AS d
        USING (SELECT sg.ID_PLANO_SUBGRUPO, c.C_NUM AS NUMERO, CAST(c.C_DESC AS NVARCHAR(80)) AS DESCRICAO, CAST(c.ATIVO AS BIT) AS ATIVO, c.P3
               FROM #ContaDest c
               INNER JOIN CAD.Plano_Grupo g     ON g.NUMERO = c.G_NUM
               INNER JOIN CAD.Plano_Subgrupo sg ON sg.ID_PLANO_GRUPO = g.ID_PLANO_GRUPO AND sg.NUMERO = c.S_NUM) AS s
        ON d.ID_PLANO_SUBGRUPO = s.ID_PLANO_SUBGRUPO AND d.NUMERO = s.NUMERO
        WHEN MATCHED AND EXISTS (SELECT d.DESCRICAO, d.ATIVO, d.CODIGO_ACCESS EXCEPT SELECT s.DESCRICAO, s.ATIVO, s.P3)
            THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.ATIVO = s.ATIVO, d.CODIGO_ACCESS = s.P3, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        WHEN NOT MATCHED THEN INSERT (ID_PLANO_SUBGRUPO, NUMERO, DESCRICAO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
            VALUES (s.ID_PLANO_SUBGRUPO, s.NUMERO, s.DESCRICAO, s.ATIVO, s.P3, @Usuario);

        SET @EtapaAtual = 'Plano: de-para';
        -- conta de destino de cada Plano3 do Access (a própria; a exceção manda para outro lugar)
        SELECT p.P3, p.G_NUM, p.S_NUM, p.C_NUM, CAST(NULL AS VARCHAR(20)) AS CENTRO_CODIGO,
               CAST(CASE WHEN p.REGRA = 'NOVO' AND EXISTS (SELECT 1 FROM #P3 z WHERE z.G_NUM = p.G_NUM AND z.S_NUM = p.S_NUM AND z.C_NUM = p.C_NUM AND z.P3 < p.P3)
                         THEN 'DUPLICADA' ELSE p.REGRA END AS VARCHAR(12)) AS REGRA
        INTO #Mapa
        FROM #P3 p
        WHERE p.TEM_EXCECAO = 0;

        INSERT INTO #Mapa (P3, G_NUM, S_NUM, C_NUM, CENTRO_CODIGO, REGRA)
        SELECT x.PLANO3_ACCESS,
               COALESCE(x.GRUPO_NUMERO, a.G_NUM), COALESCE(x.SUBGRUPO_NUMERO, a.S_NUM), COALESCE(x.CONTA_NUMERO, a.C_NUM),
               x.CENTRO_CODIGO, 'EXCECAO'
        FROM MIG.DePara_Plano_Excecao x
        LEFT JOIN #P3 a ON a.P3 = x.ALVO_PLANO3_ACCESS AND a.REGRA = 'NOVO' AND a.TEM_EXCECAO = 0
        WHERE EXISTS (SELECT 1 FROM MIG.Access_Plano3 p3 WHERE TRY_CONVERT(INT, p3.Plano3) = x.PLANO3_ACCESS)
          AND (x.GRUPO_NUMERO IS NOT NULL OR a.P3 IS NOT NULL);

        DELETE FROM MIG.DePara_Plano;
        INSERT INTO MIG.DePara_Plano (PLANO3_ACCESS, ID_PLANO_CONTA, ID_CENTRO_CUSTO, REGRA)
        SELECT m.P3, c.ID_PLANO_CONTA, cc.ID_CENTRO_CUSTO, m.REGRA
        FROM #Mapa m
        INNER JOIN CAD.Plano_Grupo g     ON g.NUMERO = m.G_NUM
        INNER JOIN CAD.Plano_Subgrupo s  ON s.ID_PLANO_GRUPO = g.ID_PLANO_GRUPO AND s.NUMERO = m.S_NUM
        INNER JOIN CAD.Plano_Conta c     ON c.ID_PLANO_SUBGRUPO = s.ID_PLANO_SUBGRUPO AND c.NUMERO = m.C_NUM
        LEFT JOIN CAD.Centro_Custo cc    ON cc.CODIGO = m.CENTRO_CODIGO AND cc.CODIGO_ACCESS IS NULL;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #UsoCentro, #UsoConta, #UsoPessoa, #UsoPlano, #UsoPlanoTotal, #Emp, #Cta, #Pes, #Ctt, #CC,
                             #Hist, #P3, #Grupo, #SubNum, #SubDest, #ContaDest, #Mapa;

        /* ------------------------------------------------------------------
           Resumo
           ------------------------------------------------------------------ */
        SELECT r.ORDEM, r.CADASTRO, r.NO_SISTEMA_NOVO, r.ATIVOS
        FROM (
            SELECT 1 AS ORDEM, N'Empresas'         AS CADASTRO, COUNT(*) AS NO_SISTEMA_NOVO, SUM(CAST(e.ATIVO AS INT)) AS ATIVOS FROM CAD.Empresa e WHERE e.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 2, N'Contas (do Access)', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM BANCO.Conta c WHERE c.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 3, N'Contas "' + @NomeCaixaContabil + N'"', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM BANCO.Conta c WHERE c.CODIGO_ACCESS IS NULL AND c.DESCRICAO = @NomeCaixaContabil
            UNION ALL SELECT 4, N'Pessoas', COUNT(*), SUM(CAST(p.ATIVO AS INT)) FROM CAD.Pessoa p WHERE p.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 5, N'Contatos das pessoas', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM CAD.Pessoa_Contato c INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = c.ID_PESSOA WHERE p.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 6, N'Centros de custo (obras do Access)', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM CAD.Centro_Custo c WHERE c.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 7, N'Centros de custo (imóveis próprios e particulares)', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM CAD.Centro_Custo c INNER JOIN MIG.Classif_Centro_Extra x ON x.CODIGO = c.CODIGO WHERE c.CODIGO_ACCESS IS NULL
            UNION ALL SELECT 8, N'Históricos padrão', COUNT(*), SUM(CAST(h.ATIVO AS INT)) FROM FIN.Historico_Padrao h WHERE h.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 9, N'Plano: grupos', COUNT(*), SUM(CAST(g.ATIVO AS INT)) FROM CAD.Plano_Grupo g INNER JOIN MIG.Config_Plano_Grupo c ON c.NUMERO = g.NUMERO
            UNION ALL SELECT 10, N'Plano: subgrupos', COUNT(*), SUM(CAST(s.ATIVO AS INT)) FROM CAD.Plano_Subgrupo s INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO INNER JOIN MIG.Config_Plano_Grupo c ON c.NUMERO = g.NUMERO
            UNION ALL SELECT 11, N'Plano: contas', COUNT(*), SUM(CAST(k.ATIVO AS INT)) FROM CAD.Plano_Conta k INNER JOIN CAD.Plano_Subgrupo s ON s.ID_PLANO_SUBGRUPO = k.ID_PLANO_SUBGRUPO INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO INNER JOIN MIG.Config_Plano_Grupo c ON c.NUMERO = g.NUMERO
            UNION ALL SELECT 12, N'De-para: centros (EmpVinculada)', COUNT(*), SUM(CASE WHEN d.CLASSIF_AUTOMATICA = 0 THEN 1 ELSE 0 END) FROM MIG.DePara_Centro d
            UNION ALL SELECT 13, N'De-para: plano (Plano3)', COUNT(*), SUM(CASE WHEN d.REGRA = 'EXCECAO' THEN 1 ELSE 0 END) FROM MIG.DePara_Plano d
        ) r
        ORDER BY r.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #UsoCentro, #UsoConta, #UsoPessoa, #UsoPlano, #UsoPlanoTotal, #Emp, #Cta, #Pes, #Ctt, #CC,
                             #Hist, #P3, #Grupo, #SubNum, #SubDest, #ContaDest, #Mapa;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
