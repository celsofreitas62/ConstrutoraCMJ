/*******************************************************************************
  Objeto      : [CAD].[fn_CAD_Documento_Checar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Confere os dígitos de CPF (11) ou CNPJ (14, inclusive o CNPJ
                alfanumérico) e devolve 1 linha com VALIDO (1/0). Fonte única
                da regra: CAD.fn_CAD_Documento_Valido (escalar) chama esta.
                Função em linha: dentro de consultas de muitas linhas não
                força o cálculo linha a linha (a escalar, por não poder ser
                incorporada ao plano, deixava a lista de lançamentos a receber
                lenta: 200 s; etapa 04f2c).
                Mesma regra da escalar v1.0: documento limpo (sem . - / espaço
                e tabulação, maiúsculo); todos os caracteres iguais = inválido.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- SELECT * FROM CAD.fn_CAD_Documento_Checar(N'529.982.247-25');      -- 1
    -- SELECT * FROM CAD.fn_CAD_Documento_Checar(N'25.686.528/0001-97');  -- 1
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [CAD].[fn_CAD_Documento_Checar] (@Documento NVARCHAR(30))
RETURNS TABLE
AS
RETURN
(
    SELECT CAST(CASE
                  WHEN d.D = '' OR REPLACE(d.D, LEFT(d.D, 1), '') = '' THEN 0
                  WHEN LEN(d.D) = 11 AND d.D NOT LIKE '%[^0-9]%'
                       THEN CASE WHEN c.V1 = ASCII(SUBSTRING(d.D, 10, 1)) - 48 AND c.V2 = ASCII(SUBSTRING(d.D, 11, 1)) - 48 THEN 1 ELSE 0 END
                  WHEN LEN(d.D) = 14 AND LEFT(d.D, 12) NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2 AND RIGHT(d.D, 2) NOT LIKE '%[^0-9]%'
                       THEN CASE WHEN j.V1 = ASCII(SUBSTRING(d.D, 13, 1)) - 48 AND j.V2 = ASCII(SUBSTRING(d.D, 14, 1)) - 48 THEN 1 ELSE 0 END
                  ELSE 0 END AS BIT) AS VALIDO
    FROM (SELECT CONVERT(VARCHAR(30), UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@Documento, N''))),
                 N'.', N''), N'-', N''), N'/', N''), N' ', N''), NCHAR(9), N''))) AS D) d
    CROSS APPLY (
        SELECT CASE WHEN s.S1 % 11 < 2 THEN 0 ELSE 11 - s.S1 % 11 END AS V1,
               CASE WHEN s.S2 % 11 < 2 THEN 0 ELSE 11 - s.S2 % 11 END AS V2
        FROM (SELECT SUM(CASE WHEN q.N <= 9 THEN q.X * (11 - q.N) ELSE 0 END) AS S1,
                     SUM(q.X * (12 - q.N)) AS S2
              FROM (SELECT v.N, ASCII(SUBSTRING(d.D, v.N, 1)) - 48 AS X
                    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) v (N)) q) s
    ) c
    CROSS APPLY (
        SELECT CASE WHEN s.S1 % 11 < 2 THEN 0 ELSE 11 - s.S1 % 11 END AS V1,
               CASE WHEN s.S2 % 11 < 2 THEN 0 ELSE 11 - s.S2 % 11 END AS V2
        FROM (SELECT SUM(CASE WHEN q.N <= 12 THEN q.X * CASE WHEN q.N <= 4 THEN 6 - q.N ELSE 14 - q.N END ELSE 0 END) AS S1,
                     SUM(q.X * CASE WHEN q.N <= 5 THEN 7 - q.N ELSE 15 - q.N END) AS S2
              FROM (SELECT v.N, ASCII(SUBSTRING(d.D, v.N, 1)) - 48 AS X
                    FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13)) v (N)) q) s
    ) j
);
GO
