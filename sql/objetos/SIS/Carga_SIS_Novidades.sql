/*******************************************************************************
  Objeto      : carga do aviso de versões (grupo de e-mail VERSAO_AVISO e
                ponto de partida do "O que há de novo")
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : (1) Grupo de e-mail VERSAO_AVISO, que recebe a nota da versão
                depois de cada atualização: nasce com o e-mail interno do
                sistema; a CMJ ajusta na tela Grupos de e-mail.
                (2) Usuários ativos sem registro em SIS.Usuario_Novidade
                nascem com a versão instalada ANTES deste MASTER (este arquivo
                roda antes de Carga_SIS_Versao.sql), para verem as novidades da
                versão que está sendo instalada. Na instalação do zero a versão
                ainda é vazia: o administrador vê as últimas versões.
                Idempotente: não mexe em quem já tem registro.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT 'VERSAO_AVISO', N'Nota da versão', N'Recebem a nota da versão (o que é novo e o que foi corrigido) depois de cada atualização do sistema.', N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = 'VERSAO_AVISO');

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, N'construtora.m.judice@gmail.com', N'Administração do sistema', N'instalacao'
FROM SIS.Grupo_Email g
WHERE g.CODIGO = 'VERSAO_AVISO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL);

INSERT INTO SIS.Usuario_Novidade (ID_USUARIO, VERSAO_VISTA)
SELECT u.ID_USUARIO, ISNULL(SIS.fn_SIS_Versao_Banco(), '')
FROM SIS.Usuario u
WHERE u.ATIVO = 1
  AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Novidade n WHERE n.ID_USUARIO = u.ID_USUARIO);
GO
