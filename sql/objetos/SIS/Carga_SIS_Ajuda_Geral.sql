/*******************************************************************************
  Objeto      : carga da ajuda do administrador geral
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Tela Sistema > Configuração > Ajuda do administrador geral
                (SIS_AJUDA_GERAL), EXCLUSIVO_GERAL: só o nível 2 vê; não pode
                ser dada a ninguém por marcação. Ação VER.
                Só insere o que falta (regra 39).

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 03g).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'SIS_AJUDA_GERAL', N'Ajuda do administrador geral', 'TELA', 'sis/ajuda-geral.html', 60, 1, 1, ''
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_CONFIGURACAO'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_AJUDA_GERAL');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM SIS.Item i
INNER JOIN SIS.Acao a ON a.CODIGO = 'VER'
WHERE i.CODIGO = 'SIS_AJUDA_GERAL'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO
