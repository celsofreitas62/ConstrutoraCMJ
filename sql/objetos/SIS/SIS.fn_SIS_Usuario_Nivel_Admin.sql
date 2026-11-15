/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Nivel_Admin]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Nível de administrador de um usuário (SIS.Perfil.NIVEL_ADMIN):
                0 = comum, 1 = Administrador (CMJ), 2 = Administrador geral.
                Usuário INTERNO ativo (sistema) = 2. Usuário ou perfil inativo,
                ou inexistente = 0. Nunca NULL.
                Usada para esconder de quem não é nível 2 os usuários e perfis
                de nível 2, e para impedir que alguém dê um nível acima do seu.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b, dois níveis de administrador).

  Homologação:
    -- SELECT SIS.fn_SIS_Usuario_Nivel_Admin(2);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Nivel_Admin] (@IdUsuario INT)
RETURNS TINYINT
AS
BEGIN
    DECLARE @Nivel TINYINT;

    SELECT @Nivel = CASE WHEN u.INTERNO = 1 THEN 2 ELSE p.NIVEL_ADMIN END
    FROM SIS.Usuario u
    INNER JOIN SIS.Perfil p ON p.ID_PERFIL = u.ID_PERFIL
    WHERE u.ID_USUARIO = @IdUsuario
      AND u.ATIVO = 1
      AND (p.ATIVO = 1 OR u.INTERNO = 1);

    RETURN ISNULL(@Nivel, 0);
END;
GO
