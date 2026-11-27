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
    v1.2 (26/11/2026) - Etapa 04f2c (P27): tela "Tipos de pendência"
                        (FIN_PENDENCIA_TIPO, nasce desabilitada); ação PENDENCIA
                        nas telas de pagar e receber, dada (só quando nasce) a
                        quem já tinha ALTERAR; FIN.Lancamento_Pendencia nas
                        tabelas das duas telas.
    v1.3 (26/11/2026) - Etapa 04g: ações BAIXAR e ESTORNAR nas telas de
                        pagar e receber, dadas (só quando nascem) a quem já
                        tinha ALTERAR; LIBERAR_PENDENCIA e
                        DESCONTO_LIMITE nascem sem ninguém (os
                        administradores dão pela tela Perfis e permissões);
                        FIN.Baixa nas tabelas das duas telas.
    v1.4 (27/11/2026) - Etapa 04g2: telas do módulo Bancos "Transferências"
                        (BANCO_TRANSFERENCIA), "Extrato e saldos"
                        (BANCO_EXTRATO) e "Fechamento de caixa"
                        (BANCO_CAIXA), nascem desabilitadas. Ações do dia a
                        dia (ver, incluir, estornar, exportar, fechar o
                        caixa) dadas, só quando nascem, a quem já tinha
                        ALTERAR em Contas a pagar; LANCAR_RETROATIVO,
                        REABRIR e AJUSTE_CAIXA nascem sem ninguém.
    v1.5 (27/11/2026) - Etapa 04h1 (P03, P04): tela "Agenda financeira"
                        (FIN_AGENDA = a tela inicial, index.html), nasce
                        desabilitada, com VER, EXPORTAR e VER_TOTAIS. Só
                        quando nascem: VER para quem já via Contas a pagar
                        ou a receber e EXPORTAR para quem já exportava
                        numa delas (perfil e permissão individual);
                        VER_TOTAIS nasce sem ninguém (P04: dada pelos
                        administradores).
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

-- Etapa 04f2c (P27): tabelas das telas de pagar e receber
UPDATE i
   SET i.TABELAS_DA_TELA = 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia', i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
  AND i.TABELAS_DA_TELA <> 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia';
GO

-- Tela Financeiro › Tipos de pendência
INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_PENDENCIA_TIPO', N'Tipos de pendência', 'TELA', 'fin/pendencia-tipos.html', 80, 0, 0, 'FIN.Pendencia_Tipo'
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_PENDENCIA_TIPO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('INCLUIR'), ('ALTERAR'), ('EXCLUIR'), ('DESATIVAR'), ('EXPORTAR'), ('DESFAZER')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'FIN_PENDENCIA_TIPO'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- Ação PENDENCIA nas telas de pagar e receber: quem tinha ALTERAR recebe, só quando a ação nasce
DECLARE @NovosPendencia TABLE (ID_ITEM_ACAO INT NOT NULL, ID_ITEM INT NOT NULL);
DECLARE @IdAlterar INT = (SELECT a.ID_ACAO FROM SIS.Acao a WHERE a.CODIGO = 'ALTERAR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, inserted.ID_ITEM INTO @NovosPendencia (ID_ITEM_ACAO, ID_ITEM)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) v (ITEM)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = 'PENDENCIA'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosPendencia n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosPendencia n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);
GO

-- Etapa 04g: baixa e estorno nas telas de pagar e receber
UPDATE i
   SET i.TABELAS_DA_TELA = 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia,FIN.Baixa', i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
  AND i.TABELAS_DA_TELA <> 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia,FIN.Baixa';
GO

-- BAIXAR e ESTORNAR: quem tinha ALTERAR recebe, só quando a ação nasce na tela
DECLARE @NovosBaixa TABLE (ID_ITEM_ACAO INT NOT NULL, ID_ITEM INT NOT NULL, ACAO VARCHAR(20) NOT NULL);
DECLARE @IdAlterar INT = (SELECT a.ID_ACAO FROM SIS.Acao a WHERE a.CODIGO = 'ALTERAR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, inserted.ID_ITEM, '' INTO @NovosBaixa (ID_ITEM_ACAO, ID_ITEM, ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('BAIXAR' AS VARCHAR(20))), ('ESTORNAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT DISTINCT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosBaixa n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT DISTINCT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosBaixa n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);
GO

-- LIBERAR_PENDENCIA e DESCONTO_LIMITE: nascem sem ninguém
INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('LIBERAR_PENDENCIA' AS VARCHAR(20))), ('DESCONTO_LIMITE')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- 04g2: telas do módulo Bancos
INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, v.CODIGO, v.NOME, 'TELA', v.CAMINHO, v.ORDEM, 0, 0, v.TABELAS
FROM (VALUES (CAST('BANCO_TRANSFERENCIA' AS VARCHAR(40)), CAST(N'Transferências' AS NVARCHAR(80)), CAST('banco/transferencias.html' AS VARCHAR(200)), CAST(30 AS SMALLINT), CAST('FIN.Transferencia,BANCO.Movimento' AS VARCHAR(400))),
             ('BANCO_EXTRATO', N'Extrato e saldos',    'banco/extrato.html', 40, 'BANCO.Movimento'),
             ('BANCO_CAIXA',   N'Fechamento de caixa', 'banco/caixa.html',   50, 'BANCO.Caixa_Fechamento')) v (CODIGO, NOME, CAMINHO, ORDEM, TABELAS)
INNER JOIN SIS.Modulo m ON m.CODIGO = 'BANCO'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = v.CODIGO);
GO

DECLARE @NovosBanco TABLE (ID_ITEM_ACAO INT NOT NULL, ITEM VARCHAR(40) NULL, ACAO VARCHAR(20) NULL);
DECLARE @IdAlterarPagar INT = (SELECT ia.ID_ITEM_ACAO FROM SIS.Item_Acao ia
                               INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM AND i.CODIGO = 'FIN_PAGAR'
                               INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'ALTERAR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, NULL, NULL INTO @NovosBanco (ID_ITEM_ACAO, ITEM, ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('BANCO_TRANSFERENCIA' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))), ('BANCO_TRANSFERENCIA', 'INCLUIR'),
             ('BANCO_TRANSFERENCIA', 'ESTORNAR'), ('BANCO_TRANSFERENCIA', 'EXPORTAR'), ('BANCO_TRANSFERENCIA', 'LANCAR_RETROATIVO'),
             ('BANCO_EXTRATO', 'VER'), ('BANCO_EXTRATO', 'EXPORTAR'),
             ('BANCO_CAIXA', 'VER'), ('BANCO_CAIXA', 'INCLUIR'), ('BANCO_CAIXA', 'EXPORTAR'), ('BANCO_CAIXA', 'REABRIR'),
             ('BANCO_CAIXA', 'AJUSTE_CAIXA')) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

UPDATE n SET n.ITEM = i.CODIGO, n.ACAO = a.CODIGO
FROM @NovosBanco n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = n.ID_ITEM_ACAO
INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM
INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO;

DELETE FROM @NovosBanco WHERE ACAO IN ('LANCAR_RETROATIVO', 'REABRIR', 'AJUSTE_CAIXA');

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosBanco n
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = @IdAlterarPagar
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosBanco n
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = @IdAlterarPagar
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);
GO

-- 04h1: tela inicial = Agenda financeira (P03, P04)
INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_AGENDA', N'Agenda financeira', 'TELA', 'index.html', 5, 0, 0, ''
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_AGENDA');
GO

DECLARE @NovosAgenda TABLE (ID_ITEM_ACAO INT NOT NULL, ACAO VARCHAR(20) NULL);

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, NULL INTO @NovosAgenda (ID_ITEM_ACAO, ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('EXPORTAR'), ('VER_TOTAIS')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'FIN_AGENDA'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

UPDATE n SET n.ACAO = a.CODIGO
FROM @NovosAgenda n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = n.ID_ITEM_ACAO
INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO;

-- VER e EXPORTAR: para quem já tinha a mesma ação em Contas a pagar ou a receber (só quando nascem)
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT DISTINCT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosAgenda n
INNER JOIN SIS.Acao a ON a.CODIGO = n.ACAO
INNER JOIN SIS.Item_Acao iaf ON iaf.ID_ACAO = a.ID_ACAO
INNER JOIN SIS.Item i ON i.ID_ITEM = iaf.ID_ITEM AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = iaf.ID_ITEM_ACAO
WHERE n.ACAO IN ('VER', 'EXPORTAR')
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, 'C', N'instalacao'
FROM @NovosAgenda n
INNER JOIN SIS.Acao a ON a.CODIGO = n.ACAO
INNER JOIN SIS.Item_Acao iaf ON iaf.ID_ACAO = a.ID_ACAO
INNER JOIN SIS.Item i ON i.ID_ITEM = iaf.ID_ITEM AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = iaf.ID_ITEM_ACAO AND up.TIPO = 'C'
WHERE n.ACAO IN ('VER', 'EXPORTAR')
  AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO)
GROUP BY up.ID_USUARIO, n.ID_ITEM_ACAO;
GO
