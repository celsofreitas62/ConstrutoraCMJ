/*******************************************************************************
  Objeto      : [MIG].[fn_MIG_Linhas_Documento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 19/11/2026
  Descrição   : Linhas (ORIGEM, NUM) de um documento da tela de casos: as do
                documento no Access e as que chegaram a ele por troca de lote
                (inclusive lote novo da migração, 900001 em diante). Função em
                linha, com busca pelo índice de MIG.Movimento (UNIDADE) e pela
                tabela pequena de correções: rápida mesmo chamada para cada
                caso da lista. Mesma regra de MIG.vw_MIG_Linha_Unidade.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (19/11/2026) - Criação (etapa 03c2, desempenho da tela de casos).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [MIG].[fn_MIG_Linhas_Documento] (@Unidade VARCHAR(40))
RETURNS TABLE
AS
RETURN
    SELECT m.ORIGEM, m.NUM
    FROM MIG.Movimento m
    WHERE m.UNIDADE = @Unidade AND m.DESTINO = 'SISTEMA'
    UNION
    SELECT o.ORIGEM, o.NUM
    FROM MIG.Caso_Correcao_Linha o
    INNER JOIN MIG.Movimento m ON m.ORIGEM = o.ORIGEM AND m.NUM = o.NUM AND m.DESTINO = 'SISTEMA'
    WHERE o.LOTE IS NOT NULL
      AND CASE WHEN o.LOTE > 0 THEN 'L:' + CONVERT(VARCHAR(20), o.LOTE)
               WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
               ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END = @Unidade;
GO
