/*******************************************************************************
  Objeto      : [CAD].[CAD_Parceiro_Tipo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Lista os tipos de parceiro (tela Tipos de parceiro e filtros
                das telas de Parceiros), com a quantidade de parceiros ativos
                de cada tipo. Não mostra o que está na lixeira.
                Permissão: VER em CAD_PARCEIRO_TIPO ou em CAD_PESSOA (a ficha do
                parceiro precisa da lista para marcar os tipos).

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Parceiro_Tipo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Parceiro_Tipo_Listar]
    @IdUsuario      INT,
    @Busca          NVARCHAR(60) = NULL,
    @SomenteAtivos  BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PARCEIRO_TIPO', 'VER') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
    BEGIN
        SELECT TOP (0) CAST(NULL AS INT) AS ID_PARCEIRO_TIPO;
        RETURN;
    END;

    SET @Busca = NULLIF(LTRIM(RTRIM(ISNULL(@Busca, N''))), N'');

    SELECT t.ID_PARCEIRO_TIPO, t.CODIGO, t.DESCRICAO, t.SISTEMA, t.ORDEM, t.ATIVO,
           ISNULL(q.QTD, 0) AS QTD_PARCEIROS
    FROM CAD.Parceiro_Tipo t
    OUTER APPLY (SELECT COUNT(*) AS QTD
                 FROM CAD.Pessoa_Tipo x
                 INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = x.ID_PESSOA AND p.ATIVO = 1
                 WHERE x.ID_PARCEIRO_TIPO = t.ID_PARCEIRO_TIPO AND x.ATIVO = 1) q
    WHERE t.DT_EXCLUSAO IS NULL
      AND (@SomenteAtivos = 0 OR t.ATIVO = 1)
      AND (@Busca IS NULL OR t.DESCRICAO LIKE N'%' + @Busca + N'%' OR t.CODIGO LIKE @Busca + '%')
    ORDER BY t.ORDEM, t.DESCRICAO;
END;
GO
