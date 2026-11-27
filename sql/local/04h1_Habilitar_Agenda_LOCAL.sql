/*******************************************************************************
  Script      : 04h1 - habilitar no LOCAL a tela "Agenda financeira"
                (FIN_AGENDA = tela inicial) e dar VER_TOTAIS ao usuário de
                teste das telas (claude.teste), para os testes automáticos
                verem os totais. Na instalação da CMJ, habilitar pela tela
                (nasce desligada) e dar VER_TOTAIS pela tela Perfis e
                permissões a quem a CMJ escolher (P04).
  Autor       : Celso de Freitas / Refatorado: Claude
  Criação     : 27/11/2026
*******************************************************************************/
SET NOCOUNT ON;
UPDATE SIS.Item SET HABILITADO = 1, DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = N'instalacao'
WHERE CODIGO = 'FIN_AGENDA' AND HABILITADO = 0;

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT u.ID_USUARIO, ia.ID_ITEM_ACAO, 'C', N'instalacao'
FROM SIS.Usuario u
INNER JOIN SIS.Item i ON i.CODIGO = 'FIN_AGENDA'
INNER JOIN SIS.Acao a ON a.CODIGO = 'VER_TOTAIS'
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO
WHERE u.LOGIN = 'claude.teste'
  AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = u.ID_USUARIO AND x.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);

SELECT CODIGO, HABILITADO FROM SIS.Item WHERE CODIGO = 'FIN_AGENDA';
