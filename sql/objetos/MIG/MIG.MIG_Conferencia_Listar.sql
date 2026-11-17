/*******************************************************************************
  Objeto      : [MIG].[MIG_Conferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Relatório de conferência do ensaio (4 grades):
                1) Access x MIG: linhas de cada tabela do Access contra o que foi
                   carregado e classificado (nada se perde);
                2) destino de cada linha (sistema, arquivo morto, resumos,
                   duplicadas, casos de data);
                3) documentos do sistema novo (a partir do corte) por padrão (quantidade, linhas,
                   valor), base das regras de transformação;
                4) arquivo morto por ano (linhas, débitos, créditos).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
    v1.1 (17/11/2026) - Rótulo da grade de padrões sem o ano fixo.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Conferencia_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 'ACCESS x MIG' AS GRADE, x.TABELA, x.LINHAS_ACCESS, x.LINHAS_MIG,
           CASE WHEN x.LINHAS_ACCESS = x.LINHAS_MIG THEN 'OK' ELSE 'DIFERENTE' END AS SITUACAO
    FROM (SELECT N'F Movimento Contas' AS TABELA, (SELECT COUNT(*) FROM MIG.Access_Movimento) AS LINHAS_ACCESS,
                 (SELECT COUNT(*) FROM MIG.Movimento WHERE ORIGEM = 'ACCESS_MOVTO') AS LINHAS_MIG
          UNION ALL
          SELECT N'ArquivoMorto', (SELECT COUNT(*) FROM MIG.Access_ArquivoMorto), (SELECT COUNT(*) FROM MIG.Movimento WHERE ORIGEM = 'ACCESS_ARQMORTO')
          UNION ALL
          SELECT N'Arquivo morto carregado', (SELECT COUNT(*) FROM MIG.Movimento WHERE DESTINO = 'ARQ_MORTO'),
                 (SELECT COUNT(*) FROM FIN.Arquivo_Morto WHERE ORIGEM_ACCESS IN ('ACCESS_MOVTO', 'ACCESS_ARQMORTO'))) x;

    SELECT 'DESTINO' AS GRADE, m.DESTINO, COUNT(*) AS LINHAS, COUNT(DISTINCT NULLIF(m.UNIDADE, '')) AS DOCUMENTOS,
           SUM(m.VALOR_DEBITO) AS DEBITOS, SUM(m.VALOR_CREDITO) AS CREDITOS
    FROM MIG.Movimento m
    GROUP BY m.DESTINO
    ORDER BY m.DESTINO;

    SELECT 'PADROES (SISTEMA NOVO)' AS GRADE, u.PADRAO, COUNT(*) AS DOCUMENTOS, SUM(u.LINHAS) AS LINHAS, SUM(u.VALOR) AS VALOR
    FROM (SELECT m.UNIDADE, MAX(m.PADRAO) AS PADRAO, COUNT(*) AS LINHAS, SUM(m.VALOR_DEBITO + m.VALOR_CREDITO) AS VALOR
          FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' GROUP BY m.UNIDADE) u
    GROUP BY u.PADRAO
    ORDER BY COUNT(*) DESC;

    SELECT 'ARQUIVO MORTO POR ANO' AS GRADE, YEAR(a.DT_MOVIMENTO) AS ANO, COUNT(*) AS LINHAS, SUM(a.VALOR_DEBITO) AS DEBITOS, SUM(a.VALOR_CREDITO) AS CREDITOS
    FROM FIN.Arquivo_Morto a
    WHERE a.ORIGEM_ACCESS IN ('ACCESS_MOVTO', 'ACCESS_ARQMORTO')
    GROUP BY YEAR(a.DT_MOVIMENTO)
    ORDER BY ANO;
END;
GO
