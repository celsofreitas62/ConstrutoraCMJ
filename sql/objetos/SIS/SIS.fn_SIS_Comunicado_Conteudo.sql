/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Comunicado_Conteudo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Miolo HTML do comunicado (vai dentro da moldura de
                SIS.fn_SIS_Email_HTML): introdução + as três seções (Implantado, Em
                teste, Próxima fase) com os itens ativos em lista. Seção vazia mostra
                "Nada nesta semana." Texto escapado (PADRAO_EMAIL regra 12); cor dos
                títulos pelo parâmetro EMPRESA_COR_PRINCIPAL. Nunca devolve NULL.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Comunicado_Conteudo(1);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Comunicado_Conteudo] (@IdComunicado INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Cor     VARCHAR(7)    = ISNULL(NULLIF(SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL'), ''), '#333333');
    DECLARE @Intro   NVARCHAR(MAX) = N'';
    DECLARE @Html    NVARCHAR(MAX) = N'';

    SELECT @Intro = SIS.fn_SIS_Texto_HTML(ISNULL(c.INTRODUCAO, N''))
    FROM SIS.Comunicado c
    WHERE c.ID_COMUNICADO = @IdComunicado;

    IF ISNULL(@Intro, N'') <> N''
        SET @Html = N'<p style="margin:0 0 16px 0;">' + REPLACE(@Intro, NCHAR(10), N'<br>') + N'</p>';

    SET @Html = @Html + ISNULL((
        SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),
                   N'<div style="margin:0 0 16px 0;">'
                 + N'<div style="font-weight:bold;color:' + @Cor + N';border-bottom:2px solid ' + @Cor + N';padding-bottom:4px;margin-bottom:8px;">' + s.TITULO + N'</div>'
                 + ISNULL(l.LISTA, N'<div style="color:#777777;">Nada nesta semana.</div>')
                 + N'</div>'), N'') WITHIN GROUP (ORDER BY s.ORDEM)
        FROM (VALUES (CAST('IMPLANTADO' AS VARCHAR(15)), CAST(N'Implantado (em uso na empresa)' AS NVARCHAR(60)), 1),
                     ('EM_TESTE',     N'Em teste',      2),
                     ('PROXIMA_FASE', N'Próxima fase',  3)) s (SECAO, TITULO, ORDEM)
        OUTER APPLY (SELECT N'<ul style="margin:0;padding-left:20px;">'
                          + STRING_AGG(CONVERT(NVARCHAR(MAX), N'<li style="margin-bottom:4px;">' + SIS.fn_SIS_Texto_HTML(i.TEXTO) + N'</li>'), N'')
                            WITHIN GROUP (ORDER BY i.ORDEM, i.ID_COMUNICADO_ITEM)
                          + N'</ul>' AS LISTA
                     FROM SIS.Comunicado_Item i
                     WHERE i.ID_COMUNICADO = @IdComunicado AND i.SECAO = s.SECAO AND i.ATIVO = 1
                     HAVING COUNT(*) > 0) l
    ), N'');

    RETURN ISNULL(@Html, N'');
END;
GO
