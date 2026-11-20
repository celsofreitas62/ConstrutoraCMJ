/*******************************************************************************
  Objeto      : [SIS].[SIS_Instalacao_Situacao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Diz se o banco está esperando o PRIMEIRO ACESSO da instalação:
                nenhum usuário administrador (perfil de nível 1 ou 2, ativo, não
                interno) tem senha definida. Só nesse caso a tela de instalação
                (que a API abre apenas no próprio servidor) pode definir as
                senhas do administrador geral e do administrador da empresa.
                Devolve 1 linha: PENDENTE, LOGIN_GERAL, LOGIN_EMPRESA.

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d).

  Homologação (LOCAL): ver sql/testes/SIS/03d_Homologacao_Instalacao.sql.
    -- EXEC SIS.SIS_Instalacao_Situacao;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Instalacao_Situacao]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(CASE WHEN EXISTS (SELECT 1 FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                                  WHERE p.NIVEL_ADMIN >= 1 AND u.INTERNO = 0 AND u.ATIVO = 1 AND u.SENHA_HASH IS NOT NULL)
                     THEN 0 ELSE 1 END AS BIT) AS PENDENTE,
           ISNULL((SELECT TOP (1) u.LOGIN FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                   WHERE p.NIVEL_ADMIN = 2 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO), '') AS LOGIN_GERAL,
           ISNULL((SELECT TOP (1) u.LOGIN FROM SIS.Usuario u INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
                   WHERE p.NIVEL_ADMIN = 1 AND u.INTERNO = 0 AND u.ATIVO = 1 ORDER BY u.ID_USUARIO), '') AS LOGIN_EMPRESA;
END;
GO
