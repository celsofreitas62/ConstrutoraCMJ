/*******************************************************************************
  Objeto      : [MIG].[fn_MIG_Plano_Desmontar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Separa o número que o Access guardava dentro do nome do plano
                de contas ("9.1.5 - Material Eletrico", "3..1.9 - Vale",
                "5.1-DESP. EMPREITAS", "11.2.1 Devolução", "00- PERMUTAS") do
                texto. Devolve o 1º número, o 2º, o último, quantos números
                havia e o texto sem o número e sem o traço. Pontos repetidos
                e espaços no meio do número são ignorados.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).

  Homologação (LOCAL):
    -- SELECT * FROM MIG.fn_MIG_Plano_Desmontar(N'3..1.9 - Vale Alimentação');   -- 3, 1, 9, 3, Vale Alimentação
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [MIG].[fn_MIG_Plano_Desmontar] (@Texto NVARCHAR(1000))
RETURNS TABLE
AS
RETURN
    WITH T AS (SELECT LTRIM(RTRIM(ISNULL(@Texto, N''))) AS D),
         P AS (SELECT T.D, LEFT(T.D, PATINDEX(N'%[^0-9. ]%', T.D + N'x') - 1) AS PREFIXO FROM T),
         R AS (SELECT P.PREFIXO, LTRIM(SUBSTRING(P.D, LEN(P.PREFIXO + N'x'), 1000)) AS RESTO FROM P),
         N AS (SELECT s.value AS V, ROW_NUMBER() OVER (ORDER BY s.ordinal) AS POSICAO
               FROM R CROSS APPLY STRING_SPLIT(REPLACE(R.PREFIXO, N' ', N''), N'.', 1) s
               WHERE s.value <> N'')
    SELECT (SELECT TRY_CONVERT(SMALLINT, N.V) FROM N WHERE N.POSICAO = 1)                  AS NUMERO_1,
           (SELECT TRY_CONVERT(SMALLINT, N.V) FROM N WHERE N.POSICAO = 2)                  AS NUMERO_2,
           (SELECT TOP (1) TRY_CONVERT(SMALLINT, N.V) FROM N ORDER BY N.POSICAO DESC)      AS NUMERO_ULTIMO,
           (SELECT COUNT(*) FROM N)                                                        AS QTD_NUMEROS,
           CAST(LTRIM(CASE WHEN LEFT(R.RESTO, 1) = N'-' THEN SUBSTRING(R.RESTO, 2, 1000) ELSE R.RESTO END) AS NVARCHAR(1000)) AS TEXTO
    FROM R;
GO
