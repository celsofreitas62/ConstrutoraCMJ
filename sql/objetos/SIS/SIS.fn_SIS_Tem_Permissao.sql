/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Tem_Permissao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : 1 se o usuário pode fazer a ação na tela; 0 caso contrário
                (inclusive usuário, tela ou ação inexistente). Nunca NULL.
                Toda procedure chamada pela API confere logo no início:
                  IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_USUARIO', 'ALTERAR') = 0 ...
                Usuário INTERNO ativo (SISTEMA: rotinas automáticas e o
                primeiro acesso da instalação) tem permissão total.
                A API nunca usa o ID do usuário interno para quem fez login.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).

  Homologação:
    -- SELECT SIS.fn_SIS_Tem_Permissao(2, 'SIS_USUARIO', 'VER');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Tem_Permissao] (@IdUsuario INT, @Item VARCHAR(40), @Acao VARCHAR(20))
RETURNS BIT
AS
BEGIN
    IF @IdUsuario IS NULL OR ISNULL(@Item, '') = '' OR ISNULL(@Acao, '') = '' RETURN 0;

    IF EXISTS (SELECT 1 FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdUsuario AND u.INTERNO = 1 AND u.ATIVO = 1)
        RETURN 1;

    IF EXISTS (SELECT 1 FROM SIS.vw_SIS_Permissao_Efetiva v
               WHERE v.ID_USUARIO = @IdUsuario AND v.ITEM_CODIGO = @Item AND v.ACAO_CODIGO = @Acao)
        RETURN 1;

    RETURN 0;
END;
GO
