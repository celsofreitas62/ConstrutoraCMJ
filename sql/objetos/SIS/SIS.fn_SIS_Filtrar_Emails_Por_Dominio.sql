/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Filtrar_Emails_Por_Dominio]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Separa uma lista de e-mails em internos e externos (PADRAO_EMAIL
                regra 10), para enviar por contas diferentes sem duplicar
                grupo. Interno = domínio listado no parâmetro
                EMAIL_DOMINIO_INTERNO (pode ter vários, separados por
                vírgula; ex.: cmj.com.br). Parâmetro vazio = todos internos.
                @Interno = 1 devolve os internos; 0 devolve os externos.
                Aceita ";" ou "," como separador; devolve "; ", sem
                repetidos, na ordem em que vieram. Nunca devolve NULL.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Filtrar_Emails_Por_Dominio(N'a@cmj.com.br; b@gmail.com', 0);
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Filtrar_Emails_Por_Dominio] (@Emails NVARCHAR(MAX), @Interno BIT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Dominios NVARCHAR(4000) = LOWER(REPLACE(ISNULL(SIS.fn_SIS_Parametro('EMAIL_DOMINIO_INTERNO'), N''), N' ', N''));
    DECLARE @Saida    NVARCHAR(MAX);

    WITH e AS
    (
        SELECT LTRIM(RTRIM(s.value)) AS EMAIL, MIN(s.ordinal) AS ORDEM
        FROM STRING_SPLIT(REPLACE(ISNULL(@Emails, N''), N',', N';'), N';', 1) s
        WHERE LTRIM(RTRIM(s.value)) <> N''
        GROUP BY LTRIM(RTRIM(s.value))
    ),
    c AS
    (
        SELECT e.EMAIL, e.ORDEM,
               CASE WHEN @Dominios = N'' THEN 1
                    WHEN EXISTS (SELECT 1 FROM STRING_SPLIT(@Dominios, N',') d
                                 WHERE d.value <> N''
                                   AND LOWER(SUBSTRING(e.EMAIL, CHARINDEX(N'@', e.EMAIL) + 1, 256)) = d.value) THEN 1
                    ELSE 0 END AS INTERNO
        FROM e
    )
    SELECT @Saida = STRING_AGG(CONVERT(NVARCHAR(MAX), c.EMAIL), N'; ') WITHIN GROUP (ORDER BY c.ORDEM)
    FROM c
    WHERE c.INTERNO = ISNULL(@Interno, 1);

    RETURN ISNULL(@Saida, N'');
END;
GO
