/*******************************************************************************
  Objeto      : [MIG].[MIG_Cadastros_Conferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Conferência da migração dos cadastros (etapa 03c2, parte A).
                Grades, nesta ordem:
                  1. PENDÊNCIAS: o que precisa de decisão ou de cadastro antes
                     da transformação do movimento (linhas = quantas linhas do
                     movimento de 2022 em diante usam aquele código);
                  2. PESSOAS: números da conversão (documento, contatos, tipo);
                  3. EMPRESAS; 4. CONTAS; 5. CENTROS DE CUSTO;
                  6. PLANO: de-para das contas usadas desde o corte.
                Só leitura.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Cadastros_Conferencia_Listar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Cadastros_Conferencia_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #Uso;
    SELECT m.EMP_VINCULADA, m.CONTA, m.PARCEIRO, m.PLANO3, m.HISTORICO
    INTO #Uso
    FROM MIG.Movimento m WITH (NOLOCK)
    WHERE m.DESTINO = 'SISTEMA';

    /* 1. Pendências */
    SELECT x.ORDEM, x.TIPO, x.CODIGO_ACCESS, x.DESCRICAO_ACCESS, x.MOTIVO, x.LINHAS
    FROM (
        SELECT 1 AS ORDEM, N'Centro de custo' AS TIPO, u.EMP_VINCULADA AS CODIGO_ACCESS, MIN(ISNULL(v.NomeVinculada, N'')) AS DESCRICAO_ACCESS,
               CAST(CASE WHEN d.CODIGO_VINCULADA IS NULL THEN N'usado desde o corte e sem centro de custo (só a caixinha/contrapartida "N/A" é esperada aqui)'
                         ELSE N'classificação automática: conferir empresa, tipo e código' END AS NVARCHAR(200)) AS MOTIVO,
               COUNT(*) AS LINHAS
        FROM #Uso u
        LEFT JOIN MIG.DePara_Centro d ON d.CODIGO_VINCULADA = u.EMP_VINCULADA
        LEFT JOIN MIG.Access_EmpVinculada v ON TRY_CONVERT(INT, v.CodigoVinculada) = u.EMP_VINCULADA
        WHERE d.CODIGO_VINCULADA IS NULL OR d.CLASSIF_AUTOMATICA = 1
        GROUP BY u.EMP_VINCULADA, d.CODIGO_VINCULADA
        UNION ALL
        SELECT 2, N'Conta', u.CONTA, MIN(ISNULL(a.Descricao, N'')), N'usada desde o corte e sem conta no sistema novo', COUNT(*)
        FROM #Uso u
        LEFT JOIN MIG.Access_Contas_Financeiras a ON TRY_CONVERT(INT, a.CodigoConta) = u.CONTA
        WHERE u.CONTA NOT IN (1, 2, 3, 9)
          AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WITH (NOLOCK) WHERE c.CODIGO_ACCESS = u.CONTA)
        GROUP BY u.CONTA
        UNION ALL
        SELECT 3, N'Plano de contas', u.PLANO3, MIN(ISNULL(p3.DescricaoPlano3, N'')),
               CAST(CASE WHEN d.PLANO3_ACCESS IS NULL THEN N'usada desde o corte e sem conta no plano novo'
                         ELSE N'usada desde o corte, mas cai numa conta inativa (plano antigo): falta de-para' END AS NVARCHAR(200)), COUNT(*)
        FROM #Uso u
        LEFT JOIN MIG.DePara_Plano d ON d.PLANO3_ACCESS = u.PLANO3
        LEFT JOIN CAD.Plano_Conta k WITH (NOLOCK) ON k.ID_PLANO_CONTA = d.ID_PLANO_CONTA
        LEFT JOIN MIG.Access_Plano3 p3 ON TRY_CONVERT(INT, p3.Plano3) = u.PLANO3
        LEFT JOIN MIG.Access_Plano2 p2 ON p2.Plano2 = p3.Plano2
        WHERE ISNULL(p2.Plano1, N'') NOT IN (N'1', N'2', N'3', N'7')      -- contrapartida, sistema e saldo acumulado não são conta de resultado
          AND (d.PLANO3_ACCESS IS NULL OR k.ATIVO = 0)
        GROUP BY u.PLANO3, d.PLANO3_ACCESS
        UNION ALL
        SELECT 4, N'Pessoa', u.PARCEIRO, MIN(ISNULL(a.NomeParceiro, N'')), N'usada desde o corte e sem cadastro no sistema novo', COUNT(*)
        FROM #Uso u
        LEFT JOIN MIG.Access_Parceiros a ON TRY_CONVERT(INT, a.CodigoParceiro) = u.PARCEIRO
        WHERE u.PARCEIRO > 1
          AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WITH (NOLOCK) WHERE p.CODIGO_ACCESS = u.PARCEIRO)
        GROUP BY u.PARCEIRO
        UNION ALL
        SELECT 5, N'Histórico', u.HISTORICO, MIN(ISNULL(h.Descricao, N'')), N'usado desde o corte e sem histórico padrão no sistema novo', COUNT(*)
        FROM #Uso u
        LEFT JOIN MIG.Access_Historico h ON TRY_CONVERT(INT, h.CodHistorico) = u.HISTORICO
        WHERE u.HISTORICO IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM FIN.Historico_Padrao f WITH (NOLOCK)
                          WHERE f.CODIGO_ACCESS = u.HISTORICO OR f.DESCRICAO = LEFT(LTRIM(RTRIM(ISNULL(h.Descricao, N''))), 80))
          AND LTRIM(RTRIM(ISNULL(h.Descricao, N''))) NOT IN (N'', N'sistema')
        GROUP BY u.HISTORICO
        UNION ALL
        SELECT 6, N'Empresa', e.CODIGO_ACCESS, e.RAZAO_SOCIAL, N'sem CNPJ: preencher pela tela de Empresas', 0
        FROM CAD.Empresa e WITH (NOLOCK)
        WHERE e.CODIGO_ACCESS IS NOT NULL AND e.CNPJ = ''
    ) x
    ORDER BY x.ORDEM, x.LINHAS DESC, x.CODIGO_ACCESS;

    /* 2. Pessoas */
    SELECT COUNT(*)                                                                  AS PESSOAS,
           SUM(CAST(p.ATIVO AS INT))                                                 AS ATIVAS,
           SUM(f.USADA)                                                              AS USADAS_DESDE_O_CORTE,
           SUM(CASE WHEN p.TIPO_PESSOA = 'J' THEN 1 ELSE 0 END)                      AS JURIDICAS,
           SUM(CASE WHEN p.TIPO_PESSOA = 'F' THEN 1 ELSE 0 END)                      AS FISICAS,
           SUM(CASE WHEN p.CPF_CNPJ = '' THEN 1 ELSE 0 END)                          AS SEM_DOCUMENTO,
           SUM(f.DOC_INVALIDO)                                                       AS DOCUMENTO_INVALIDO,
           SUM(f.EMAIL)                                                              AS COM_EMAIL,
           SUM(f.TELEFONE)                                                           AS COM_TELEFONE,
           SUM(CASE WHEN p.OBSERVACAO LIKE N'%no Access:%' THEN 1 ELSE 0 END)        AS COM_DADO_DO_ACCESS_NA_OBSERVACAO
    FROM CAD.Pessoa p WITH (NOLOCK)
    CROSS APPLY (SELECT CASE WHEN EXISTS (SELECT 1 FROM #Uso u WHERE u.PARCEIRO = p.CODIGO_ACCESS) THEN 1 ELSE 0 END AS USADA,
                        CASE WHEN p.CPF_CNPJ <> '' AND CAD.fn_CAD_Documento_Valido(p.CPF_CNPJ) = 0 THEN 1 ELSE 0 END AS DOC_INVALIDO,
                        CASE WHEN EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = p.ID_PESSOA AND c.TIPO = 'EMAIL') THEN 1 ELSE 0 END AS EMAIL,
                        CASE WHEN EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = p.ID_PESSOA AND c.TIPO <> 'EMAIL') THEN 1 ELSE 0 END AS TELEFONE) f
    WHERE p.CODIGO_ACCESS IS NOT NULL;

    /* 3. Empresas */
    SELECT e.ID_EMPRESA, e.CODIGO_ACCESS, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.TIPO, e.REGIME_TRIBUTARIO,
           SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ, 0) AS CNPJ, SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ_COMPRAS, 0) AS CNPJ_NOTAS_COMPRA_DDA,
           ISNULL(k.DESCRICAO, N'') AS CONTA_PADRAO, e.ATIVO
    FROM CAD.Empresa e WITH (NOLOCK)
    LEFT JOIN BANCO.Conta k WITH (NOLOCK) ON k.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
    WHERE e.CODIGO_ACCESS IS NOT NULL
    ORDER BY CASE e.TIPO WHEN 'CONSTRUTORA' THEN 1 WHEN 'HOLDING' THEN 2 ELSE 3 END, e.NOME_FANTASIA;

    /* 4. Contas */
    SELECT ISNULL(e.NOME_FANTASIA, N'') AS EMPRESA, c.DESCRICAO, c.TIPO, ISNULL(b.CODIGO + N' ' + b.NOME, N'') AS BANCO,
           c.AGENCIA, c.NUMERO + CASE WHEN c.NUMERO_DV <> '' THEN '-' + c.NUMERO_DV ELSE '' END AS CONTA,
           c.CONCILIA, c.ATIVO, c.CODIGO_ACCESS,
           (SELECT COUNT(*) FROM #Uso u WHERE u.CONTA = c.CODIGO_ACCESS) AS LINHAS_DESDE_O_CORTE
    FROM BANCO.Conta c WITH (NOLOCK)
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
    LEFT JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = c.ID_BANCO
    WHERE e.CODIGO_ACCESS IS NOT NULL
    ORDER BY c.ATIVO DESC, e.NOME_FANTASIA, c.DESCRICAO;

    /* 5. Centros de custo */
    SELECT c.CODIGO, c.DESCRICAO, c.TIPO, e.NOME_FANTASIA AS EMPRESA, c.CONTABIL, c.ATIVO,
           ISNULL(k.DESCRICAO, N'') AS CONTA_PADRAO, ISNULL(p.NOME, N'') AS CLIENTE_ADMINISTRACAO, ISNULL(d.PERCENTUAL_ADM, 0) AS PERCENTUAL_ADM,
           c.CODIGO_ACCESS, ISNULL(v.NomeVinculada, N'') AS NOME_NO_ACCESS, ISNULL(d.CLASSIF_AUTOMATICA, 0) AS CLASSIF_AUTOMATICA,
           (SELECT COUNT(*) FROM #Uso u WHERE u.EMP_VINCULADA = c.CODIGO_ACCESS) AS LINHAS_DESDE_O_CORTE
    FROM CAD.Centro_Custo c WITH (NOLOCK)
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
    LEFT JOIN MIG.DePara_Centro d ON d.ID_CENTRO_CUSTO = c.ID_CENTRO_CUSTO
    LEFT JOIN CAD.Pessoa p WITH (NOLOCK) ON p.ID_PESSOA = d.ID_PESSOA_CLIENTE
    LEFT JOIN BANCO.Conta k WITH (NOLOCK) ON k.ID_CONTA = c.ID_CONTA_BANCARIA_PADRAO
    LEFT JOIN MIG.Access_EmpVinculada v ON TRY_CONVERT(INT, v.CodigoVinculada) = c.CODIGO_ACCESS
    WHERE c.CODIGO_ACCESS IS NOT NULL OR EXISTS (SELECT 1 FROM MIG.Classif_Centro_Extra x WHERE x.CODIGO = c.CODIGO)
    ORDER BY c.ATIVO DESC, e.NOME_FANTASIA, c.CODIGO;

    /* 6. Plano: de-para das contas usadas desde o corte */
    SELECT d.PLANO3_ACCESS,
           LTRIM(RTRIM(ISNULL(p1.DescricaoPlano1, N''))) + N' > ' + LTRIM(RTRIM(ISNULL(p2.DescricaoPlano2, N''))) + N' > ' + LTRIM(RTRIM(ISNULL(p3.DescricaoPlano3, N''))) AS NO_ACCESS,
           v.CODIGO AS CODIGO_NOVO, v.GRUPO_DESCRICAO + N' > ' + v.SUBGRUPO_DESCRICAO + N' > ' + v.DESCRICAO AS NO_SISTEMA_NOVO,
           ISNULL(cc.CODIGO + N' - ' + cc.DESCRICAO, N'') AS CENTRO_DO_IMOVEL, d.REGRA, v.ATIVO_EFETIVO AS ATIVA,
           (SELECT COUNT(*) FROM #Uso u WHERE u.PLANO3 = d.PLANO3_ACCESS) AS LINHAS_DESDE_O_CORTE
    FROM MIG.DePara_Plano d
    INNER JOIN CAD.Plano_Conta k WITH (NOLOCK) ON k.ID_PLANO_CONTA = d.ID_PLANO_CONTA
    INNER JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = d.ID_PLANO_CONTA
    LEFT JOIN CAD.Centro_Custo cc WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = d.ID_CENTRO_CUSTO
    LEFT JOIN MIG.Access_Plano3 p3 ON TRY_CONVERT(INT, p3.Plano3) = d.PLANO3_ACCESS
    LEFT JOIN MIG.Access_Plano2 p2 ON p2.Plano2 = p3.Plano2
    LEFT JOIN MIG.Access_Plano1 p1 ON p1.Plano1 = p2.Plano1
    WHERE EXISTS (SELECT 1 FROM #Uso u WHERE u.PLANO3 = d.PLANO3_ACCESS)
    ORDER BY v.ORDEM_ARVORE, d.PLANO3_ACCESS;

    DROP TABLE IF EXISTS #Uso;
END;
GO
