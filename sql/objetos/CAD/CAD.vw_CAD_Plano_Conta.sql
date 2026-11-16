/*******************************************************************************
  Objeto      : [CAD].[vw_CAD_Plano_Conta]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Plano de contas achatado: uma linha por conta (nível 3) com o
                subgrupo e o grupo. CODIGO no formato 09.1.05 (grupo com 2 dígitos,
                subgrupo, conta com 2 ou 3 dígitos). ATIVO_EFETIVO: conta, subgrupo e
                grupo ativos (só essas aparecem para escolher no lançamento).
                ORDEM_ARVORE: texto para ordenar na sequência numérica.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- SELECT * FROM CAD.vw_CAD_Plano_Conta ORDER BY ORDEM_ARVORE;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW [CAD].[vw_CAD_Plano_Conta]
AS
SELECT c.ID_PLANO_CONTA,
       CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + CONVERT(VARCHAR(3), s.NUMERO) + '.'
             + CASE WHEN c.NUMERO < 10 THEN '0' ELSE '' END + CONVERT(VARCHAR(4), c.NUMERO)) AS CODIGO,
       c.DESCRICAO,
       c.NUMERO          AS NUMERO_CONTA,
       c.CONTABIL,
       c.CONTA_CONTABIL_REF,
       c.ATIVO           AS CONTA_ATIVA,
       s.ID_PLANO_SUBGRUPO,
       s.NUMERO          AS NUMERO_SUBGRUPO,
       s.DESCRICAO       AS SUBGRUPO_DESCRICAO,
       g.ID_PLANO_GRUPO,
       g.NUMERO          AS NUMERO_GRUPO,
       g.DESCRICAO       AS GRUPO_DESCRICAO,
       g.TIPO,
       g.CUSTO_OBRA,
       CAST(CASE WHEN c.ATIVO = 1 AND s.ATIVO = 1 AND g.ATIVO = 1 THEN 1 ELSE 0 END AS BIT) AS ATIVO_EFETIVO,
       CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + RIGHT('00' + CONVERT(VARCHAR(3), s.NUMERO), 2) + '.'
             + RIGHT('000' + CONVERT(VARCHAR(4), c.NUMERO), 3)) AS ORDEM_ARVORE
FROM CAD.Plano_Conta c
INNER JOIN CAD.Plano_Subgrupo s ON s.ID_PLANO_SUBGRUPO = c.ID_PLANO_SUBGRUPO
INNER JOIN CAD.Plano_Grupo    g ON g.ID_PLANO_GRUPO    = s.ID_PLANO_GRUPO;
GO
