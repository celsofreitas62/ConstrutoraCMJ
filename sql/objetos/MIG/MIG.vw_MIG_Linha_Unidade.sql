/*******************************************************************************
  Objeto      : [MIG].[vw_MIG_Linha_Unidade]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Para cada linha do Access que vai para o sistema (MIG.Movimento,
                DESTINO = 'SISTEMA'), o documento (unidade) do Access e o
                documento em uso depois da troca de lote feita pela tela de
                casos (Caso_Correcao_Linha.LOTE): lote do Access, outro lote do
                Access, lote novo da migração (900001 em diante) ou, com 0,
                fora do lote (venda ou avulso). Mesma regra do
                MIG_Movimento_Preparar. Usada pela tela de casos e pela
                migração para achar as linhas de um documento.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (19/11/2026) - Criação (etapa 03c2, lote novo da migração).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW [MIG].[vw_MIG_Linha_Unidade]
AS
SELECT m.ORIGEM, m.NUM, m.UNIDADE AS UNIDADE_ACCESS,
       CAST(CASE WHEN o.LOTE IS NULL THEN m.UNIDADE
                 WHEN o.LOTE > 0 THEN 'L:' + CONVERT(VARCHAR(20), o.LOTE)
                 WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
                 ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END AS VARCHAR(40)) AS UNIDADE,
       CAST(CASE WHEN o.LOTE IS NULL THEN 0 ELSE 1 END AS BIT) AS MOVIDA
FROM MIG.Movimento m
LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
WHERE m.DESTINO = 'SISTEMA';
GO
