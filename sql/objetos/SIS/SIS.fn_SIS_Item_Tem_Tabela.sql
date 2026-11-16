/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Item_Tem_Tabela]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : 1 se a tela (@Item) mantém registros da tabela (@Tabela, no
                formato 'SCHEMA.Tabela'), conforme SIS.Item.TABELAS_DA_TELA;
                0 caso contrário. Nunca NULL.
                Usada pelo Histórico (auditoria) e pelos anexos: o usuário só
                vê histórico e anexos das tabelas da tela que ele pode abrir.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).

  Homologação:
    -- SELECT SIS.fn_SIS_Item_Tem_Tabela('SIS_USUARIO', 'SIS.Usuario');   -- 1
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Item_Tem_Tabela] (@Item VARCHAR(40), @Tabela NVARCHAR(256))
RETURNS BIT
AS
BEGIN
    IF ISNULL(@Item, '') = '' OR ISNULL(@Tabela, N'') = N'' RETURN 0;

    IF EXISTS (SELECT 1
               FROM SIS.Item i
               CROSS APPLY STRING_SPLIT(i.TABELAS_DA_TELA, ',') s
               WHERE i.CODIGO = @Item
                 AND LTRIM(RTRIM(s.value)) = LTRIM(RTRIM(@Tabela)))
        RETURN 1;

    RETURN 0;
END;
GO
