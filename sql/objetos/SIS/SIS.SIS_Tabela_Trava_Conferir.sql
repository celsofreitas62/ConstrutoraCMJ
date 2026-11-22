/*******************************************************************************
  Objeto      : [SIS].[SIS_Tabela_Trava_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Travas configuradas em SIS.Tabela_Config para mexer num
                registro pela lixeira ou pelo desfazer (P20):
                  1) mês fechado: com COLUNA_EMPRESA e COLUNA_DATA_MES
                     preenchidas, recusa se o mês da data do registro (ou da
                     data nova, @DataNova) estiver fechado em FIN.Mes_Fechado;
                  2) PROC_VALIDAR: chama a procedure própria da tabela
                     (@Tabela, @IdRegistro, @Operacao, @Mensagem OUTPUT).
                @Mensagem vazia = pode. Uso interno (chamada pelas procedures
                da lixeira e do desfazer); a API não chama (DENY).
                @Operacao: LIXEIRA, RECUPERAR, APAGAR ou DESFAZER.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Tabela_Trava_Conferir]
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Operacao    VARCHAR(20),
    @DataNova    DATE = NULL,
    @Mensagem    NVARCHAR(400) OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ColEmpresa NVARCHAR(128), @ColData NVARCHAR(128), @Proc NVARCHAR(256);
    DECLARE @ObjId INT = OBJECT_ID(@Tabela, N'U');
    DECLARE @Pk NVARCHAR(128) = SIS.fn_SIS_Tabela_PK(@Tabela);
    DECLARE @Sql NVARCHAR(MAX), @IdEmpresa INT, @Data DATE, @Mes DATE, @Msg NVARCHAR(400);

    SET @Mensagem = N'';

    SELECT @ColEmpresa = c.COLUNA_EMPRESA, @ColData = c.COLUNA_DATA_MES, @Proc = c.PROC_VALIDAR
    FROM SIS.Tabela_Config c
    WHERE c.TABELA = @Tabela AND c.ATIVO = 1;

    IF @ObjId IS NULL OR @Pk = N'' RETURN;

    -- 1) Mês fechado
    IF ISNULL(@ColEmpresa, N'') <> N'' AND ISNULL(@ColData, N'') <> N''
    BEGIN
        SET @Sql = N'SELECT @e = TRY_CONVERT(INT, t.' + QUOTENAME(@ColEmpresa) + N'), @d = TRY_CONVERT(DATE, t.' + QUOTENAME(@ColData) + N')'
                 + N' FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(@ObjId)) + N'.' + QUOTENAME(OBJECT_NAME(@ObjId)) + N' t'
                 + N' WHERE t.' + QUOTENAME(@Pk) + N' = @Id;';
        EXEC sys.sp_executesql @Sql, N'@Id BIGINT, @e INT OUTPUT, @d DATE OUTPUT', @Id = @IdRegistro, @e = @IdEmpresa OUTPUT, @d = @Data OUTPUT;

        SELECT TOP 1 @Mes = m.MES
        FROM FIN.Mes_Fechado m
        WHERE m.ID_EMPRESA = @IdEmpresa
          AND m.FECHADO = 1
          AND (   (@Data IS NOT NULL     AND m.MES = DATEFROMPARTS(YEAR(@Data), MONTH(@Data), 1))
               OR (@DataNova IS NOT NULL AND m.MES = DATEFROMPARTS(YEAR(@DataNova), MONTH(@DataNova), 1)))
        ORDER BY m.MES;

        IF @Mes IS NOT NULL
        BEGIN
            SET @Mensagem = N'O mês ' + RIGHT(N'0' + CAST(MONTH(@Mes) AS NVARCHAR(2)), 2) + N'/' + CAST(YEAR(@Mes) AS NVARCHAR(4))
                          + N' está fechado para esta empresa. Reabra o mês antes.';
            RETURN;
        END;
    END;

    -- 2) Trava própria da tabela
    IF ISNULL(@Proc, N'') <> N'' AND OBJECT_ID(@Proc, N'P') IS NOT NULL
    BEGIN
        SET @Sql = N'EXEC ' + QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@Proc, N'P'))) + N'.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(@Proc, N'P')))
                 + N' @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = @Operacao, @Mensagem = @Msg OUTPUT;';
        EXEC sys.sp_executesql @Sql, N'@Tabela NVARCHAR(256), @IdRegistro BIGINT, @Operacao VARCHAR(20), @Msg NVARCHAR(400) OUTPUT',
             @Tabela = @Tabela, @IdRegistro = @IdRegistro, @Operacao = @Operacao, @Msg = @Msg OUTPUT;
        SET @Mensagem = ISNULL(@Msg, N'');
    END;
END;
GO
