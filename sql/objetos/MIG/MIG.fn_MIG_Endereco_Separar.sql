/*******************************************************************************
  Objeto      : [MIG].[fn_MIG_Endereco_Separar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Separa o endereço do Access ("Rua X, 60 Apto. 102") em
                LOGRADOURO, NUMERO e COMPLEMENTO (regra aprovada pelo Celso em
                25/11/2026, 04d2 passo 6):
                  1) "s/n", "s/nº" ou "SN" no fim = número S/N (o que vem depois = complemento);
                  2) com "nº" ou vírgula seguida de número: o número é o que vem
                     logo depois, o resto é o complemento ("Rua Y, 1210, fundos");
                  3) sem vírgula, número no fim ("Avenida Brasilia 1730 A");
                  4) "115/1" fica inteiro no número;
                  5) não reconhecido (rodovia, Km, sem número): devolve o
                     endereço como veio, número e complemento vazios e
                     RECONHECIDO = 0 (vai para as pendências da Renata).
                Endereço vazio: tudo vazio e RECONHECIDO = 1.
                Function de tabela com várias instruções (exceção à regra 30,
                registrada no diário em 25/11/2026: a versão inline estourava o
                limite de expressões do SQL Server); só a migração usa.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d2, passo 6).

  Homologação (LOCAL): ver sql/testes/MIG/04d2_Homologacao_Endereco.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [MIG].[fn_MIG_Endereco_Separar] (@Endereco NVARCHAR(150))
RETURNS @R TABLE (LOGRADOURO NVARCHAR(150) NOT NULL, NUMERO NVARCHAR(20) NOT NULL, COMPLEMENTO NVARCHAR(60) NOT NULL, RECONHECIDO BIT NOT NULL)
AS
BEGIN
    DECLARE @E NVARCHAR(150) = LTRIM(RTRIM(REPLACE(REPLACE(ISNULL(@Endereco, N''), NCHAR(9), N' '), N'  ', N' '))) COLLATE Latin1_General_CI_AI;
    DECLARE @Regra VARCHAR(10) = '', @Log NVARCHAR(150) = N'', @Rabo NVARCHAR(150) = N'', @Num NVARCHAR(150) = N'', @Resto NVARCHAR(150) = N'';
    DECLARE @Psn INT, @Pno INT, @Pc INT, @Pc2 INT, @DepoisNo NVARCHAR(150), @T1 NVARCHAR(150) = N'', @P1 NVARCHAR(150) = N'', @T2 NVARCHAR(150) = N'', @P2 NVARCHAR(150) = N'', @N INT;

    -- vírgula ou hífen sobrando no fim ("Rua Piaui 729,")
    IF PATINDEX(N'%[^ ,-]%', REVERSE(@E)) > 1
        SET @E = LEFT(@E, LEN(@E) - (PATINDEX(N'%[^ ,-]%', REVERSE(@E)) - 1));

    IF @E = N''
    BEGIN
        INSERT INTO @R VALUES (N'', N'', N'', 1);
        RETURN;
    END;

    -- marcas: s/n, nº e vírgula seguida de número
    SET @Psn = PATINDEX(N'%[ ,]s/n%', @E);
    SET @Pno = PATINDEX(N'% n[º°]%', @E);
    SET @Pc  = NULLIF(PATINDEX(N'%,[0-9]%', @E), 0);
    SET @Pc2 = NULLIF(PATINDEX(N'%, [0-9]%', @E), 0);
    IF @Pc IS NULL OR (@Pc2 IS NOT NULL AND @Pc2 < @Pc) SET @Pc = @Pc2;
    SET @DepoisNo = LTRIM(SUBSTRING(@E, @Pno + 3, 150));
    IF LEFT(@DepoisNo, 1) = N'.' SET @DepoisNo = LTRIM(SUBSTRING(@DepoisNo, 2, 150));

    -- últimos dois pedaços separados por espaço (regra 3)
    IF CHARINDEX(N' ', @E) > 0
    BEGIN
        SET @T1 = RIGHT(@E, CHARINDEX(N' ', REVERSE(@E)) - 1);
        SET @P1 = RTRIM(LEFT(@E, LEN(@E) - CHARINDEX(N' ', REVERSE(@E))));
        IF CHARINDEX(N' ', @P1) > 0
        BEGIN
            SET @T2 = RIGHT(@P1, CHARINDEX(N' ', REVERSE(@P1)) - 1);
            SET @P2 = RTRIM(LEFT(@P1, LEN(@P1) - CHARINDEX(N' ', REVERSE(@P1))));
        END;
    END;

    IF @Psn = 0 AND @E LIKE N'%[ ,]sn'
        SELECT @Regra = 'SN', @Log = LEFT(@E, LEN(@E) - 3), @Resto = N'', @Num = N'S/N';
    ELSE IF @Psn > 0
        SELECT @Regra = 'SN', @Log = LEFT(@E, @Psn - 1),
               @Resto = SUBSTRING(@E, @Psn + 4 + CASE WHEN SUBSTRING(@E, @Psn + 4, 1) IN (N'º', N'°', N'o', N'.') THEN 1 ELSE 0 END, 150), @Num = N'S/N';
    ELSE IF @Pno > 0 AND @DepoisNo LIKE N'[0-9]%'
        SELECT @Regra = 'NO', @Log = LEFT(@E, @Pno - 1), @Rabo = @DepoisNo;
    ELSE IF @Pc IS NOT NULL
        SELECT @Regra = 'VIRGULA', @Log = LEFT(@E, @Pc - 1), @Rabo = LTRIM(SUBSTRING(@E, @Pc + 1, 150));
    ELSE IF @T1 LIKE N'[0-9]%' AND @T1 NOT LIKE N'%[^0-9/]%'
        SELECT @Regra = 'FIM', @Log = @P1, @Rabo = @T1;
    ELSE IF LEN(@T1) BETWEEN 1 AND 2 AND @T1 NOT LIKE N'%[^a-z]%' AND @T2 LIKE N'[0-9]%' AND @T2 NOT LIKE N'%[^0-9/]%'
        SELECT @Regra = 'FIM_LETRA', @Log = @P2, @Rabo = @T2 + N' ' + @T1;

    -- número: dígitos, com "/dígitos" opcional (regra 4)
    IF @Regra NOT IN ('', 'SN')
    BEGIN
        SET @N = PATINDEX(N'%[^0-9]%', @Rabo + N'x') - 1;
        IF SUBSTRING(@Rabo, @N + 1, 2) LIKE N'/[0-9]'
            SET @N = @N + 1 + PATINDEX(N'%[^0-9]%', SUBSTRING(@Rabo, @N + 2, 150) + N'x') - 1;
        SELECT @Num = LEFT(@Rabo, @N), @Resto = SUBSTRING(@Rabo, @N + 1, 150);
    END;

    -- tira separadores do fim do logradouro e do começo do complemento
    SET @Log = CASE WHEN PATINDEX(N'%[^ ,-]%', REVERSE(@Log)) = 0 THEN N''
                    ELSE LEFT(@Log, LEN(@Log) - (PATINDEX(N'%[^ ,-]%', REVERSE(@Log)) - 1)) END;
    SET @Resto = CASE WHEN PATINDEX(N'%[^ ,-]%', @Resto) = 0 THEN N''
                      ELSE LTRIM(RTRIM(SUBSTRING(@Resto, PATINDEX(N'%[^ ,-]%', @Resto), 150))) END;

    IF @Regra <> '' AND @Num <> N'' AND LEN(@Num) <= 20 AND LEN(@Resto) <= 60
       AND LEN(@Log) >= 3 AND @Log LIKE N'%[a-z]%'
       -- rodovia e Km não se separam pelo número do fim
       AND NOT (@Regra IN ('FIM', 'FIM_LETRA') AND (@Log LIKE N'rod%' OR @Log LIKE N'%[ .]km' OR @Log LIKE N'% br' OR @Log LIKE N'% sp' OR @Log LIKE N'% mg'))
        INSERT INTO @R VALUES (@Log, @Num, @Resto, 1);
    ELSE
        INSERT INTO @R VALUES (@E, N'', N'', 0);
    RETURN;
END;
GO
