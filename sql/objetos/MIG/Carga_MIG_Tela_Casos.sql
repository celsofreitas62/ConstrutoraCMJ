/*******************************************************************************
  Objeto      : carga da tela "Casos da migração" (menu e permissões)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Menu Sistema > Migração > Casos da migração (MIG_CASOS), com as
                ações VER e ALTERAR. Para os dois administradores (geral e da
                CMJ); outro perfil só se receber a permissão. Só existe onde a
                migração roda (LOCAL e o servidor da CMJ até a virada); na
                virada, o item é desabilitado. Só insere o que falta (regra 39).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'SIS_MIGRACAO', N'Migração', 'MENU', '', 40, 0, 1, ''
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_MIGRACAO');
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'MIG_CASOS', N'Casos da migração', 'TELA', 'sis/migracao-casos.html', 10, 0, 1,
       'MIG.Caso_Correcao,MIG.Caso_Correcao_Linha'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_MIGRACAO'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'MIG_CASOS');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('ALTERAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'MIG_CASOS'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO
