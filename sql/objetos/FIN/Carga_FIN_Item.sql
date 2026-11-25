/*******************************************************************************
  Objeto      : carga de [SIS].[Item] e [SIS].[Item_Acao] do módulo FIN
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Tela "Arquivo morto" (só consulta: VER e EXPORTAR, sem incluir,
                alterar ou excluir). Nasce DESABILITADA, como toda tela de módulo
                novo. As telas de lançamento, baixa e conciliação entram na fase 4.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
    v1.1 (25/11/2026) - Etapa 04f: telas "Contas a pagar" (FIN_PAGAR) e
                        "Contas a receber" (FIN_RECEBER), mesma tela com o tipo
                        no endereço, permissões separadas; nascem desabilitadas.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_ARQUIVO_MORTO', N'Arquivo morto', 'TELA', 'fin/arquivo-morto.html', 90, 0, 0, 'FIN.Arquivo_Morto'
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_ARQUIVO_MORTO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_ARQUIVO_MORTO' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))), ('FIN_ARQUIVO_MORTO', 'EXPORTAR')) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, v.CODIGO, v.NOME, 'TELA', v.CAMINHO, v.ORDEM, 0, 0, 'FIN.Lancamento,FIN.Parcela'
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40)), CAST(N'Contas a pagar' AS NVARCHAR(80)), CAST('fin/lancamentos.html?tipo=P' AS VARCHAR(200)), CAST(10 AS SMALLINT)),
             ('FIN_RECEBER', N'Contas a receber', 'fin/lancamentos.html?tipo=R', 20)) v (CODIGO, NOME, CAMINHO, ORDEM)
INNER JOIN SIS.Modulo m ON m.CODIGO = 'FIN'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = v.CODIGO);
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('VER' AS VARCHAR(20))), ('INCLUIR'), ('ALTERAR'), ('CANCELAR'), ('EXCLUIR'), ('EXPORTAR'), ('DESFAZER'), ('LANCAR_RETROATIVO')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO
