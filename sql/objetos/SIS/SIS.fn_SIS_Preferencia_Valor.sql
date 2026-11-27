/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Preferencia_Valor]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Valor que vale de uma preferência para o usuário: o que ele
                escolheu (SIS.Usuario_Preferencia), senão o padrão (parâmetro
                da preferência), senão ''. Nunca devolve NULL (regra 8).
                Usada uma vez por chamada (fora de consultas grandes).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Preferencia_Valor] (@IdUsuario INT, @Codigo VARCHAR(40))
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @Valor NVARCHAR(400);

    SELECT @Valor = ISNULL(up.VALOR, pa.VALOR)
    FROM SIS.Preferencia p WITH (NOLOCK)
    LEFT JOIN SIS.Parametro pa WITH (NOLOCK) ON pa.CHAVE = p.CHAVE_PARAMETRO
    LEFT JOIN SIS.Usuario_Preferencia up WITH (NOLOCK) ON up.ID_PREFERENCIA = p.ID_PREFERENCIA AND up.ID_USUARIO = @IdUsuario
    WHERE p.CODIGO = @Codigo;

    RETURN ISNULL(@Valor, N'');
END;
GO
