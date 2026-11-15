/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Login]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Login de um usuário pelo ID (para gravar em USUARIO_CRIACAO /
                USUARIO_ALTERACAO). ID nulo ou inexistente: devolve o usuário
                da sessão (fn_SIS_Usuario_Atual). Nunca devolve NULL.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação:
    -- SELECT SIS.fn_SIS_Usuario_Login(2);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Login] (@IdUsuario INT)
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @Login NVARCHAR(100);

    SELECT @Login = CONVERT(NVARCHAR(100), u.LOGIN)
    FROM SIS.Usuario u WITH (NOLOCK)
    WHERE u.ID_USUARIO = @IdUsuario;

    RETURN ISNULL(@Login, SIS.fn_SIS_Usuario_Atual());
END;
GO
