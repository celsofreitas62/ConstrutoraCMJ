/*******************************************************************************
  Objeto      : carga de [SIS].[Item] e [SIS].[Item_Acao] dos módulos CAD e BANCO
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Telas da etapa 03a no menu: Cadastros (Empresas, Pessoas, Centros de
                custo, Plano de contas) e Bancos (Contas bancárias, Bancos), com as
                ações de cada tela. Só insere o que falta (regra 39). Telas de módulo
                novo nascem DESABILITADAS (HABILITADO = 0): o administrador geral liga
                na tela "Módulos e telas" quando quiser liberar. Acertado também em
                item já existente: TABELAS_DA_TELA (itens só mudam por carga).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaItem;

SELECT v.MODULO, v.CODIGO, v.NOME, v.CAMINHO, v.ORDEM, v.TABELAS
INTO #CargaItem
FROM (VALUES
        (CAST('CAD' AS VARCHAR(10)), CAST('CAD_EMPRESA' AS VARCHAR(40)), CAST(N'Empresas' AS NVARCHAR(80)), CAST('cad/empresas.html' AS VARCHAR(200)),
         CAST(10 AS SMALLINT), CAST('CAD.Empresa' AS VARCHAR(500))),
        ('CAD',   'CAD_PESSOA',       N'Pessoas',          'cad/pessoas.html',        20, 'CAD.Pessoa,CAD.Pessoa_Contato,CAD.Pessoa_Vinculo,CAD.Pessoa_Dado_Bancario'),
        ('CAD',   'CAD_CENTRO_CUSTO', N'Centros de custo', 'cad/centros-custo.html',  30, 'CAD.Centro_Custo'),
        ('CAD',   'CAD_PLANO_CONTA',  N'Plano de contas',  'cad/plano-contas.html',   40, 'CAD.Plano_Grupo,CAD.Plano_Subgrupo,CAD.Plano_Conta'),
        ('BANCO', 'BANCO_CONTA',      N'Contas bancárias', 'banco/contas.html',       10, 'BANCO.Conta'),
        ('BANCO', 'BANCO_BANCO',      N'Bancos',           'banco/bancos.html',       20, 'BANCO.Banco')
     ) v (MODULO, CODIGO, NOME, CAMINHO, ORDEM, TABELAS);

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, c.CODIGO, c.NOME, 'TELA', c.CAMINHO, c.ORDEM, 0, 0, c.TABELAS
FROM #CargaItem c
INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = c.CODIGO);

UPDATE i
   SET i.TABELAS_DA_TELA = c.TABELAS, i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
INNER JOIN #CargaItem c ON c.CODIGO = i.CODIGO
WHERE i.TABELAS_DA_TELA <> c.TABELAS;

DROP TABLE IF EXISTS #CargaItem;
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES
        (CAST('CAD_EMPRESA' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))),
        ('CAD_EMPRESA', 'INCLUIR'), ('CAD_EMPRESA', 'ALTERAR'), ('CAD_EMPRESA', 'EXCLUIR'), ('CAD_EMPRESA', 'EXPORTAR'),
        ('CAD_PESSOA', 'VER'), ('CAD_PESSOA', 'INCLUIR'), ('CAD_PESSOA', 'ALTERAR'), ('CAD_PESSOA', 'EXCLUIR'), ('CAD_PESSOA', 'EXPORTAR'),
        ('CAD_CENTRO_CUSTO', 'VER'), ('CAD_CENTRO_CUSTO', 'INCLUIR'), ('CAD_CENTRO_CUSTO', 'ALTERAR'), ('CAD_CENTRO_CUSTO', 'EXCLUIR'), ('CAD_CENTRO_CUSTO', 'EXPORTAR'),
        ('CAD_PLANO_CONTA', 'VER'), ('CAD_PLANO_CONTA', 'INCLUIR'), ('CAD_PLANO_CONTA', 'ALTERAR'), ('CAD_PLANO_CONTA', 'EXCLUIR'), ('CAD_PLANO_CONTA', 'EXPORTAR'),
        ('BANCO_CONTA', 'VER'), ('BANCO_CONTA', 'INCLUIR'), ('BANCO_CONTA', 'ALTERAR'), ('BANCO_CONTA', 'EXCLUIR'), ('BANCO_CONTA', 'EXPORTAR'),
        ('BANCO_BANCO', 'VER'), ('BANCO_BANCO', 'INCLUIR'), ('BANCO_BANCO', 'ALTERAR'), ('BANCO_BANCO', 'EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO
