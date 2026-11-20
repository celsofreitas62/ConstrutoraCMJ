/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Usuario_Id]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : Código (ID_USUARIO) do usuário pelo login. NULL se não existe.
                Usada pela API para gravar em nome do usuário interno "sistema"
                (ex.: instalação da licença), sem ler tabela direto (o login da
                API só executa procedures e functions).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d, licença).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Usuario_Id('sistema');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Usuario_Id] (@Login VARCHAR(40))
RETURNS INT
AS
BEGIN
    RETURN (SELECT u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = LOWER(LTRIM(RTRIM(@Login))));
END;
GO
