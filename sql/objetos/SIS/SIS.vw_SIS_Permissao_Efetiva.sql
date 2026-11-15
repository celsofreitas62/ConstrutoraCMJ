/*******************************************************************************
  Objeto      : [SIS].[vw_SIS_Permissao_Efetiva]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : O que cada usuário pode fazer de fato (uma linha por usuário +
                tela + ação permitida):
                  perfil nível 2 (administrador geral) -> todas as ações;
                  perfil nível 1 (administrador) -> todas, menos as telas
                    EXCLUSIVO_GERAL;
                  perfil comum: (ações do perfil + concessões 'C') -
                    retiradas 'R', nunca em tela EXCLUSIVO_GERAL.
                Só entram: usuário ativo, não bloqueado e não interno; perfil
                ativo; tela, ação e módulo ativos; módulo liberado na licença.
                Fonte única de permissão: fn_SIS_Tem_Permissao e
                SIS_Menu_Listar leem daqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - Dois níveis de administrador (NIVEL_ADMIN, EXCLUSIVO_GERAL).

  Homologação:
    -- SELECT * FROM SIS.vw_SIS_Permissao_Efetiva WHERE ID_USUARIO = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW [SIS].[vw_SIS_Permissao_Efetiva]
AS
SELECT u.ID_USUARIO,
       ia.ID_ITEM_ACAO,
       i.ID_ITEM,
       i.CODIGO  AS ITEM_CODIGO,
       a.ID_ACAO,
       a.CODIGO  AS ACAO_CODIGO,
       m.ID_MODULO,
       m.CODIGO  AS MODULO_CODIGO
FROM SIS.Usuario u
INNER JOIN SIS.Perfil    p  ON p.ID_PERFIL  = u.ID_PERFIL
CROSS JOIN SIS.Item_Acao ia
INNER JOIN SIS.Item      i  ON i.ID_ITEM    = ia.ID_ITEM
INNER JOIN SIS.Acao      a  ON a.ID_ACAO    = ia.ID_ACAO
INNER JOIN SIS.Modulo    m  ON m.ID_MODULO  = i.ID_MODULO
WHERE u.ATIVO = 1
  AND u.BLOQUEADO = 0
  AND u.INTERNO = 0
  AND p.ATIVO = 1
  AND ia.ATIVO = 1
  AND i.ATIVO = 1
  AND a.ATIVO = 1
  AND m.ATIVO = 1
  AND m.LIBERADO_LICENCA = 1
  AND (i.EXCLUSIVO_GERAL = 0 OR p.NIVEL_ADMIN = 2)
  AND (    p.NIVEL_ADMIN >= 1
       OR (    (   EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp
                           WHERE pp.ID_PERFIL = u.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO)
                OR EXISTS (SELECT 1 FROM SIS.Usuario_Permissao up
                           WHERE up.ID_USUARIO = u.ID_USUARIO AND up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO AND up.TIPO = 'C'))
           AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao up
                           WHERE up.ID_USUARIO = u.ID_USUARIO AND up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO AND up.TIPO = 'R')));
GO
