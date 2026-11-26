/*******************************************************************************
  Objeto      : [FIN].[FIN_Pendencia_Responsavel_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - usuários que podem ser responsáveis por uma pendência
                (escolha na ficha do lançamento): ativos e não internos (o
                usuário de teste e o de consulta do Claude ficam de fora).
                Só ID, nome e login: nada de e-mail, perfil ou senha.
                Permissão: VER em FIN_PAGAR ou FIN_RECEBER.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Pendencia_Responsavel_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Pendencia_Responsavel_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER') = 0
    BEGIN
        SELECT TOP (0) CAST(NULL AS INT) AS ID_USUARIO, CAST(N'' AS NVARCHAR(100)) AS NOME, CAST('' AS VARCHAR(40)) AS LOGIN;
        RETURN;
    END;

    SELECT u.ID_USUARIO, u.NOME, u.LOGIN
    FROM SIS.Usuario u WITH (NOLOCK)
    WHERE u.ATIVO = 1
      AND u.INTERNO = 0
    ORDER BY u.NOME;
END;
GO
