/*******************************************************************************
  Objeto      : [MIG].[MIG_Carga_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Carga crua: apaga e recarrega as tabelas MIG.Access_* a partir
                dos CSV exportados do Access (Extrair_Access.ps1 -ExportarDados),
                na pasta @Pasta. CSV UTF-8 com ';' e aspas (BULK INSERT
                FORMAT = 'CSV', CODEPAGE 65001). Cada arquivo é isolado: um com
                problema não impede os outros (regra 13); o resultado de cada um
                vai para MIG.Carga_Log e é devolvido no fim. A conta de serviço do
                SQL Server precisa ler a pasta.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Carga_Processar]
    @Pasta  NVARCHAR(260) = N'C:\SistemaCMJ\legado\dados_brutos'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NomeProc NVARCHAR(128)    = N'[MIG].[MIG_Carga_Processar]';
    DECLARE @RunId    UNIQUEIDENTIFIER = NEWID();
    DECLARE @Tabela   NVARCHAR(128);
    DECLARE @Arquivo  NVARCHAR(400);
    DECLARE @Sql      NVARCHAR(MAX);
    DECLARE @Linhas   INT;
    DECLARE @Lista    TABLE (ORDEM INT IDENTITY(1,1), TABELA NVARCHAR(128), ARQUIVO NVARCHAR(400));

    SET @Pasta = RTRIM(ISNULL(@Pasta, N''));
    IF RIGHT(@Pasta, 1) <> N'\' SET @Pasta = @Pasta + N'\';

    INSERT INTO @Lista (TABELA, ARQUIVO)
    VALUES
        (N'Access_Movimento', N'F Movimento Contas.csv'),
        (N'Access_ArquivoMorto', N'ArquivoMorto.csv'),
        (N'Access_Parceiros', N'Parceiros.csv'),
        (N'Access_EmpVinculada', N'EmpVinculada.csv'),
        (N'Access_EmpMaster', N'EmpMaster.csv'),
        (N'Access_Contas_Financeiras', N'F Contas Financeiras.csv'),
        (N'Access_Plano1', N'Plano1.csv'),
        (N'Access_Plano2', N'Plano2.csv'),
        (N'Access_Plano3', N'Plano3.csv'),
        (N'Access_Historico', N'Historico.csv'),
        (N'Access_Imoveis', N'Imoveis.csv');

    DECLARE @Ordem INT = 0;
    WHILE 1 = 1
    BEGIN
        SELECT TOP (1) @Ordem = l.ORDEM, @Tabela = l.TABELA, @Arquivo = @Pasta + l.ARQUIVO
        FROM @Lista l WHERE l.ORDEM > @Ordem ORDER BY l.ORDEM;
        IF @@ROWCOUNT = 0 BREAK;

        BEGIN TRY
            SET @Sql = N'TRUNCATE TABLE [MIG].' + QUOTENAME(@Tabela) + N';'
                     + N' BULK INSERT [MIG].' + QUOTENAME(@Tabela) + N' FROM ' + QUOTENAME(@Arquivo, N'''')
                     + N' WITH (FORMAT = ''CSV'', FIELDQUOTE = ''"'', FIELDTERMINATOR = '';'', ROWTERMINATOR = ''0x0d0a'','
                     + N' FIRSTROW = 2, CODEPAGE = ''65001'', TABLOCK);'
                     + N' SELECT @n = COUNT(*) FROM [MIG].' + QUOTENAME(@Tabela) + N';';
            EXEC sys.sp_executesql @Sql, N'@n INT OUTPUT', @n = @Linhas OUTPUT;
            INSERT INTO MIG.Carga_Log (RUN_ID, TABELA, ARQUIVO, LINHAS, RESULTADO) VALUES (@RunId, @Tabela, @Arquivo, @Linhas, 'OK');
        END TRY
        BEGIN CATCH
            INSERT INTO MIG.Carga_Log (RUN_ID, TABELA, ARQUIVO, LINHAS, RESULTADO, MENSAGEM)
            VALUES (@RunId, @Tabela, @Arquivo, NULL, 'ERRO', LEFT(ERROR_MESSAGE(), 2000));
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, LEFT(N'Carga ' + @Tabela, 100), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;
    END;

    SELECT c.TABELA, c.ARQUIVO, c.LINHAS, c.RESULTADO, c.MENSAGEM FROM MIG.Carga_Log c WHERE c.RUN_ID = @RunId ORDER BY c.ID_CARGA_LOG;
END;
GO
