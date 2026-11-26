/*******************************************************************************
  Objeto      : [FIN].[FIN_Pendencia_Tipo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - tipos de pendência (tela Financeiro › Tipos de
                pendência e escolha do tipo na ficha do lançamento).
                @Tipo P/R: só os tipos que valem para contas a pagar ou a
                receber (APLICA_A = @Tipo ou A). Não lista o que está na
                lixeira. QTD_ABERTAS: pendências abertas do tipo.
                Permissão: VER em FIN_PENDENCIA_TIPO, FIN_PAGAR ou FIN_RECEBER.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Pendencia_Tipo_Listar @IdUsuario = 2;
    -- EXEC FIN.FIN_Pendencia_Tipo_Listar @IdUsuario = 2, @Tipo = 'R', @SomenteAtivos = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Pendencia_Tipo_Listar]
    @IdUsuario      INT,
    @Busca          NVARCHAR(60) = NULL,
    @SomenteAtivos  BIT          = 0,
    @Tipo           CHAR(1)      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PENDENCIA_TIPO', 'VER') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER') = 0
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER') = 0
    BEGIN
        SELECT TOP (0) CAST(NULL AS INT) AS ID_PENDENCIA_TIPO;
        RETURN;
    END;

    SET @Busca = NULLIF(LTRIM(RTRIM(ISNULL(@Busca, N''))), N'');
    SET @Tipo  = NULLIF(UPPER(ISNULL(@Tipo, '')), '');

    SELECT t.ID_PENDENCIA_TIPO, t.CODIGO, t.DESCRICAO, t.ORIENTACAO, t.APLICA_A, t.BLOQUEIA_BAIXA, t.SISTEMA, t.ORDEM, t.ATIVO,
           ISNULL(q.QTD, 0) AS QTD_ABERTAS
    FROM FIN.Pendencia_Tipo t WITH (NOLOCK)
    OUTER APPLY (SELECT COUNT(*) AS QTD
                 FROM FIN.Lancamento_Pendencia lp WITH (NOLOCK)
                 WHERE lp.ID_PENDENCIA_TIPO = t.ID_PENDENCIA_TIPO AND lp.SITUACAO = 'ABERTA' AND lp.ATIVO = 1) q
    WHERE t.DT_EXCLUSAO IS NULL
      AND (@SomenteAtivos = 0 OR t.ATIVO = 1)
      AND (@Tipo IS NULL OR t.APLICA_A IN ('A', @Tipo))
      AND (@Busca IS NULL OR t.DESCRICAO LIKE N'%' + @Busca + N'%' OR t.CODIGO LIKE @Busca + '%')
    ORDER BY t.ORDEM, t.DESCRICAO;
END;
GO
