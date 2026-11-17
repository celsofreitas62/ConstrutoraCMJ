/*******************************************************************************
  Pacote      : 03c - ensaio da migração do movimento (schema MIG: carga crua do Access, classificação, arquivo morto, conferência). NÃO vai para o MASTER
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 17/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacote 03c já rodado; CSV do Access na pasta legado/dados_brutos.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/local/03c_Ensaio_Migracao_LOCAL.sql.
*******************************************************************************/
USE [SISTEMACMJ_LOCAL];
GO

IF DB_NAME() <> N'SISTEMACMJ_LOCAL'
BEGIN
    RAISERROR(N'Banco errado: este pacote só roda no SISTEMACMJ_LOCAL. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.Tabelas_Access.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG] (schema) e tabelas cruas do Access
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Uma tabela por arquivo exportado do Access, com as colunas
                exatamente como no CSV (tudo texto: a conversão de tipo é feita
                depois, por regra). Recarregadas a cada ensaio por
                MIG.MIG_Carga_Processar. Movimento e arquivo morto têm a mesma
                estrutura: Access_Movimento (movimento atual) e
                Access_ArquivoMorto.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'MIG') IS NULL EXEC (N'CREATE SCHEMA [MIG] AUTHORIZATION [dbo];');
GO

IF OBJECT_ID(N'[MIG].[Access_Movimento]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_Movimento]
    (
        [NumMovimento] NVARCHAR(1000) NULL,
        [EmpVinculada] NVARCHAR(1000) NULL,
        [CodigoParceiro] NVARCHAR(1000) NULL,
        [CodHistorico] NVARCHAR(1000) NULL,
        [DataMovto] NVARCHAR(1000) NULL,
        [ValorDebito] NVARCHAR(1000) NULL,
        [ValorCredito] NVARCHAR(1000) NULL,
        [Complemento] NVARCHAR(1000) NULL,
        [Plano1] NVARCHAR(1000) NULL,
        [Plano2] NVARCHAR(1000) NULL,
        [Plano3] NVARCHAR(1000) NULL,
        [ContaFinanceira] NVARCHAR(1000) NULL,
        [Confirmado] NVARCHAR(1000) NULL,
        [Integracao] NVARCHAR(1000) NULL,
        [DataPagto] NVARCHAR(1000) NULL,
        [DataVencto] NVARCHAR(1000) NULL,
        [MovPagtoLote] NVARCHAR(1000) NULL,
        [SelPagtoLote] NVARCHAR(1000) NULL,
        [Observacao] NVARCHAR(MAX) NULL,
        [NumDoc] NVARCHAR(1000) NULL,
        [CodImovel] NVARCHAR(1000) NULL,
        [AgrupadorVenda] NVARCHAR(1000) NULL,
        [ClassificacaoVenda] NVARCHAR(1000) NULL,
        [SofreReajuste] NVARCHAR(1000) NULL,
        [IndiceReajuste] NVARCHAR(1000) NULL,
        [CodAtribuiParceiro] NVARCHAR(1000) NULL,
        [CodAtribuiEmpresa] NVARCHAR(1000) NULL,
        [CodAnteriorParceiro] NVARCHAR(1000) NULL,
        [CodAnteriorEmpresa] NVARCHAR(1000) NULL,
        [Efetuado] NVARCHAR(1000) NULL,
        [LinkVenda] NVARCHAR(1000) NULL,
        [PagoAntecipado] NVARCHAR(1000) NULL,
        [ValorReajustado] NVARCHAR(1000) NULL,
        [ReferenteNotaFiscal] NVARCHAR(1000) NULL,
        [PagamentoLote] NVARCHAR(1000) NULL,
        [PadraoRelatorio] NVARCHAR(1000) NULL,
        [SomenteIntegracao] NVARCHAR(1000) NULL,
        [AnoOcorrenciaMensal] NVARCHAR(1000) NULL,
        [MesOcorrenciaMensal] NVARCHAR(1000) NULL,
        [EmitirCheque] NVARCHAR(1000) NULL,
        [ChequeEmitido] NVARCHAR(1000) NULL,
        [ValorOriginalImovel] NVARCHAR(1000) NULL,
        [CodigoCondPagto] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_ArquivoMorto]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_ArquivoMorto]
    (
        [NumMovimento] NVARCHAR(1000) NULL,
        [EmpVinculada] NVARCHAR(1000) NULL,
        [CodigoParceiro] NVARCHAR(1000) NULL,
        [CodHistorico] NVARCHAR(1000) NULL,
        [DataMovto] NVARCHAR(1000) NULL,
        [ValorDebito] NVARCHAR(1000) NULL,
        [ValorCredito] NVARCHAR(1000) NULL,
        [Complemento] NVARCHAR(1000) NULL,
        [Plano1] NVARCHAR(1000) NULL,
        [Plano2] NVARCHAR(1000) NULL,
        [Plano3] NVARCHAR(1000) NULL,
        [ContaFinanceira] NVARCHAR(1000) NULL,
        [Confirmado] NVARCHAR(1000) NULL,
        [Integracao] NVARCHAR(1000) NULL,
        [DataPagto] NVARCHAR(1000) NULL,
        [DataVencto] NVARCHAR(1000) NULL,
        [MovPagtoLote] NVARCHAR(1000) NULL,
        [SelPagtoLote] NVARCHAR(1000) NULL,
        [Observacao] NVARCHAR(MAX) NULL,
        [NumDoc] NVARCHAR(1000) NULL,
        [CodImovel] NVARCHAR(1000) NULL,
        [AgrupadorVenda] NVARCHAR(1000) NULL,
        [ClassificacaoVenda] NVARCHAR(1000) NULL,
        [SofreReajuste] NVARCHAR(1000) NULL,
        [IndiceReajuste] NVARCHAR(1000) NULL,
        [CodAtribuiParceiro] NVARCHAR(1000) NULL,
        [CodAtribuiEmpresa] NVARCHAR(1000) NULL,
        [CodAnteriorParceiro] NVARCHAR(1000) NULL,
        [CodAnteriorEmpresa] NVARCHAR(1000) NULL,
        [Efetuado] NVARCHAR(1000) NULL,
        [LinkVenda] NVARCHAR(1000) NULL,
        [PagoAntecipado] NVARCHAR(1000) NULL,
        [ValorReajustado] NVARCHAR(1000) NULL,
        [ReferenteNotaFiscal] NVARCHAR(1000) NULL,
        [PagamentoLote] NVARCHAR(1000) NULL,
        [PadraoRelatorio] NVARCHAR(1000) NULL,
        [SomenteIntegracao] NVARCHAR(1000) NULL,
        [AnoOcorrenciaMensal] NVARCHAR(1000) NULL,
        [MesOcorrenciaMensal] NVARCHAR(1000) NULL,
        [EmitirCheque] NVARCHAR(1000) NULL,
        [ChequeEmitido] NVARCHAR(1000) NULL,
        [ValorOriginalImovel] NVARCHAR(1000) NULL,
        [CodigoCondPagto] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_Parceiros]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_Parceiros]
    (
        [CodigoParceiro] NVARCHAR(1000) NULL,
        [NomeParceiro] NVARCHAR(1000) NULL,
        [Cliente] NVARCHAR(1000) NULL,
        [Fornecedor] NVARCHAR(1000) NULL,
        [Funcionario] NVARCHAR(1000) NULL,
        [Master] NVARCHAR(1000) NULL,
        [Endereco] NVARCHAR(1000) NULL,
        [Bairro] NVARCHAR(1000) NULL,
        [Cidade] NVARCHAR(1000) NULL,
        [Estado] NVARCHAR(1000) NULL,
        [CEP] NVARCHAR(1000) NULL,
        [Telefone] NVARCHAR(1000) NULL,
        [Fax] NVARCHAR(1000) NULL,
        [Ramal] NVARCHAR(1000) NULL,
        [Contato] NVARCHAR(1000) NULL,
        [IE] NVARCHAR(1000) NULL,
        [CNPJ] NVARCHAR(1000) NULL,
        [Email] NVARCHAR(1000) NULL,
        [TelefoneComercial] NVARCHAR(1000) NULL,
        [Trabalho] NVARCHAR(1000) NULL,
        [CPF] NVARCHAR(1000) NULL,
        [RG] NVARCHAR(1000) NULL,
        [Observacoes] NVARCHAR(MAX) NULL,
        [AplicarReajuste] NVARCHAR(1000) NULL,
        [PagtoLote] NVARCHAR(1000) NULL,
        [Inativo] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_EmpVinculada]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_EmpVinculada]
    (
        [CodigoVinculada] NVARCHAR(1000) NULL,
        [CodigoMaster] NVARCHAR(1000) NULL,
        [NomeVinculada] NVARCHAR(1000) NULL,
        [CNPJ] NVARCHAR(1000) NULL,
        [PercentualAdm] NVARCHAR(1000) NULL,
        [FinanceiraPadrao] NVARCHAR(1000) NULL,
        [Master] NVARCHAR(1000) NULL,
        [Administracao] NVARCHAR(1000) NULL,
        [ImovelEmVenda] NVARCHAR(1000) NULL,
        [Contabil] NVARCHAR(1000) NULL,
        [SdoInicialDespesas] NVARCHAR(1000) NULL,
        [SdoInicialReceitas] NVARCHAR(1000) NULL,
        [CEI] NVARCHAR(1000) NULL,
        [Custos] NVARCHAR(1000) NULL,
        [DataInicialCustos] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_EmpMaster]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_EmpMaster]
    (
        [CodigoMaster] NVARCHAR(1000) NULL,
        [NomeMaster] NVARCHAR(1000) NULL,
        [Master] NVARCHAR(1000) NULL,
        [CNPJ] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_Contas_Financeiras]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_Contas_Financeiras]
    (
        [CodigoConta] NVARCHAR(1000) NULL,
        [Descricao] NVARCHAR(1000) NULL,
        [Numero Conta] NVARCHAR(1000) NULL,
        [Limite Credito] NVARCHAR(1000) NULL,
        [Tipo Conta] NVARCHAR(1000) NULL,
        [Conciliacao] NVARCHAR(1000) NULL,
        [NaoListarResumo] NVARCHAR(1000) NULL,
        [Observacao] NVARCHAR(MAX) NULL,
        [Master] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_Plano1]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_Plano1]
    (
        [Plano1] NVARCHAR(1000) NULL,
        [DescricaoPlano1] NVARCHAR(1000) NULL,
        [Master] NVARCHAR(1000) NULL,
        [OrdemCusto] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_Plano2]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_Plano2]
    (
        [Plano1] NVARCHAR(1000) NULL,
        [Plano2] NVARCHAR(1000) NULL,
        [DescricaoPlano2] NVARCHAR(1000) NULL,
        [Master] NVARCHAR(1000) NULL,
        [RelatorioCustos] NVARCHAR(1000) NULL,
        [Ativo] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_Plano3]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_Plano3]
    (
        [Plano2] NVARCHAR(1000) NULL,
        [Plano3] NVARCHAR(1000) NULL,
        [DescricaoPlano3] NVARCHAR(1000) NULL,
        [Master] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_Historico]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_Historico]
    (
        [CodHistorico] NVARCHAR(1000) NULL,
        [Descricao] NVARCHAR(1000) NULL,
        [Master] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Access_Imoveis]', N'U') IS NULL
    CREATE TABLE [MIG].[Access_Imoveis]
    (
        [EmpVinculada] NVARCHAR(1000) NULL,
        [CodImovel] NVARCHAR(1000) NULL,
        [NomeImovel] NVARCHAR(1000) NULL,
        [Divisao] NVARCHAR(1000) NULL,
        [Estilo] NVARCHAR(1000) NULL,
        [Proprietario] NVARCHAR(1000) NULL,
        [IndiceReajuste] NVARCHAR(1000) NULL,
        [PercentualComissao] NVARCHAR(1000) NULL,
        [Vendido] NVARCHAR(1000) NULL,
        [Vendedor] NVARCHAR(1000) NULL,
        [Modelo] NVARCHAR(1000) NULL
    );
GO

IF OBJECT_ID(N'[MIG].[Carga_Log]', N'U') IS NULL
    CREATE TABLE [MIG].[Carga_Log]
    (
        ID_CARGA_LOG  INT            IDENTITY(1,1) NOT NULL CONSTRAINT PK_Carga_Log PRIMARY KEY,
        RUN_ID        UNIQUEIDENTIFIER NOT NULL,
        TABELA        NVARCHAR(128)  NOT NULL,
        ARQUIVO       NVARCHAR(400)  NOT NULL,
        LINHAS        INT            NULL,
        RESULTADO     VARCHAR(10)    NOT NULL,
        MENSAGEM      NVARCHAR(2000) NOT NULL CONSTRAINT DF_Carga_Log_MENSAGEM DEFAULT (N''),
        DT_CARGA      DATETIME2(0)   NOT NULL CONSTRAINT DF_Carga_Log_DT DEFAULT (SYSDATETIME())
    );
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Carga_Processar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Movimento_Preparar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Movimento_Preparar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Junta o movimento atual e o arquivo morto do Access numa tabela
                tipada (MIG.Movimento) e classifica cada linha, com as regras de
                docs/requisitos/Migracao_Movimento.md:
                - SD_ACUM: linha de saldo acumulado da virada de ano
                  (NumDoc "Sd Acum"): não é movimento;
                - DUPLICADA: linha do arquivo morto igual, campo a campo (fora o
                  número), a uma do movimento atual: fica a do movimento atual;
                - DT_VALIDA: data do movimento entre 2000 e 2035; se não, a de
                  vencimento; se nenhuma, NULL (lista de casos; regra 43);
                - UNIDADE: documento do sistema novo: o lote de pagamento
                  (MovPagtoLote, junta as duas tabelas), a venda (LinkVenda) ou
                  a própria linha;
                - DT_UNIDADE: maior data das linhas de banco/caixa da unidade
                  (ou de qualquer linha, se não houver banco); antes de @Corte
                  = arquivo morto;
                - CONTRATO de venda (imóvel + cliente da parcela): se alguma
                  parcela é de @Corte em diante, o contrato inteiro vai para o
                  sistema novo (extrato e ficha do contrato completos);
                - PADRAO: combinação dos tipos de conta e lados da unidade
                  (ex.: L|BCO-D|CRED-C|LOTE-D).
                Contas de sistema do Access: 1 Créditos, 2 Débitos, 3 Pagto em
                Lote, 9 N/A (caixinha). Repetível: recria MIG.Movimento.
                Devolve o resumo da classificação.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
    v1.1 (17/11/2026) - Corte em parâmetro (@Corte, padrão 01/01/2022, decisão
                        do Celso) e contrato de venda inteiro no sistema novo.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- MIG.Movimento é refeita a cada ensaio: apagar aqui evita erro de compilação
-- quando a estrutura dela muda entre versões desta procedure.
DROP TABLE IF EXISTS MIG.Movimento;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Movimento_Preparar]
    @Corte  DATE = '2022-01-01'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Movimento_Preparar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Tipagem';

    BEGIN TRY
        DROP TABLE IF EXISTS MIG.Movimento;

        ;WITH Fonte AS
        (
            SELECT CAST('ACCESS_MOVTO' AS VARCHAR(20)) AS ORIGEM, m.* FROM MIG.Access_Movimento m
            UNION ALL
            SELECT CAST('ACCESS_ARQMORTO' AS VARCHAR(20)), a.* FROM MIG.Access_ArquivoMorto a
        )
        SELECT IDENTITY(BIGINT, 1, 1) AS ID_MIG,
               f.ORIGEM,
               TRY_CONVERT(INT, f.NumMovimento)                              AS NUM,
               TRY_CONVERT(INT, f.EmpVinculada)                              AS EMP_VINCULADA,
               TRY_CONVERT(INT, f.CodigoParceiro)                            AS PARCEIRO,
               TRY_CONVERT(INT, f.CodHistorico)                              AS HISTORICO,
               TRY_CONVERT(DATE, LEFT(f.DataMovto, 10), 23)                  AS DT_MOVTO,
               TRY_CONVERT(DATE, LEFT(f.DataVencto, 10), 23)                 AS DT_VENCTO,
               TRY_CONVERT(DATE, LEFT(f.DataPagto, 10), 23)                  AS DT_PAGTO,
               ROUND(ISNULL(TRY_CONVERT(DECIMAL(19,6), f.ValorDebito), 0), 2)  AS VALOR_DEBITO,
               ROUND(ISNULL(TRY_CONVERT(DECIMAL(19,6), f.ValorCredito), 0), 2) AS VALOR_CREDITO,
               ISNULL(f.Complemento, N'')                                    AS COMPLEMENTO,
               TRY_CONVERT(INT, f.Plano1) AS PLANO1, TRY_CONVERT(INT, f.Plano2) AS PLANO2, TRY_CONVERT(INT, f.Plano3) AS PLANO3,
               TRY_CONVERT(INT, f.ContaFinanceira)                           AS CONTA,
               CAST(CASE WHEN f.Confirmado = N'True' THEN 1 ELSE 0 END AS BIT)        AS CONFIRMADO,
               CAST(CASE WHEN f.Efetuado = N'True' THEN 1 ELSE 0 END AS BIT)          AS EFETUADO,
               CAST(CASE WHEN f.Integracao = N'True' THEN 1 ELSE 0 END AS BIT)        AS INTEGRACAO,
               CAST(CASE WHEN f.SomenteIntegracao = N'True' THEN 1 ELSE 0 END AS BIT) AS SOMENTE_INTEGRACAO,
               CAST(CASE WHEN f.PagamentoLote = N'True' THEN 1 ELSE 0 END AS BIT)     AS PAGAMENTO_LOTE,
               ISNULL(TRY_CONVERT(INT, f.MovPagtoLote), 0)                   AS LOTE,
               ISNULL(TRY_CONVERT(INT, f.LinkVenda), 0)                      AS LINK_VENDA,
               TRY_CONVERT(INT, f.CodImovel)                                 AS IMOVEL,
               ISNULL(f.ClassificacaoVenda, N'')                             AS CLASSIF_VENDA,
               ISNULL(f.NumDoc, N'')                                         AS NUM_DOC,
               ISNULL(f.ReferenteNotaFiscal, N'')                            AS NOTA_FISCAL,
               ISNULL(f.Observacao, N'')                                     AS OBSERVACAO,
               HASHBYTES('SHA2_256', CONCAT_WS(N'|', f.EmpVinculada, f.CodigoParceiro, f.CodHistorico, f.DataMovto, f.ValorDebito, f.ValorCredito,
                         f.Complemento, f.Plano1, f.Plano2, f.Plano3, f.ContaFinanceira, f.Confirmado, f.Integracao, f.DataPagto, f.DataVencto,
                         f.MovPagtoLote, f.SelPagtoLote, f.Observacao, f.NumDoc, f.CodImovel, f.AgrupadorVenda, f.ClassificacaoVenda, f.SofreReajuste,
                         f.IndiceReajuste, f.CodAtribuiParceiro, f.CodAtribuiEmpresa, f.CodAnteriorParceiro, f.CodAnteriorEmpresa, f.Efetuado,
                         f.LinkVenda, f.PagoAntecipado, f.ValorReajustado, f.ReferenteNotaFiscal, f.PagamentoLote, f.PadraoRelatorio,
                         f.SomenteIntegracao, f.AnoOcorrenciaMensal, f.MesOcorrenciaMensal, f.EmitirCheque, f.ChequeEmitido,
                         f.ValorOriginalImovel, f.CodigoCondPagto)) AS HASH_CONTEUDO,
               CAST(0 AS BIT)                 AS SD_ACUM,
               CAST(0 AS BIT)                 AS DUPLICADA,
               CAST(NULL AS DATE)             AS DT_VALIDA,
               CAST('' AS VARCHAR(6))         AS TIPO_CONTA,
               CAST('' AS CHAR(1))            AS LADO,
               CAST('' AS VARCHAR(40))        AS UNIDADE,
               CAST(NULL AS DATE)             AS DT_UNIDADE,
               CAST('' AS VARCHAR(200))       AS PADRAO,
               CAST('' AS VARCHAR(40))        AS CONTRATO,
               CAST('' AS VARCHAR(12))        AS DESTINO
        INTO MIG.Movimento
        FROM Fonte f;

        CREATE UNIQUE CLUSTERED INDEX IX_MIG_Movimento_ID ON MIG.Movimento (ID_MIG);

        SET @EtapaAtual = 'Classificação da linha';
        UPDATE m
           SET m.SD_ACUM    = CASE WHEN LTRIM(RTRIM(m.NUM_DOC)) = N'Sd Acum' THEN 1 ELSE 0 END,
               m.DT_VALIDA  = CASE WHEN m.DT_MOVTO  BETWEEN '2000-01-01' AND '2035-12-31' THEN m.DT_MOVTO
                                   WHEN m.DT_VENCTO BETWEEN '2000-01-01' AND '2035-12-31' THEN m.DT_VENCTO END,
               m.TIPO_CONTA = CASE m.CONTA WHEN 1 THEN 'CRED' WHEN 2 THEN 'DEB' WHEN 3 THEN 'LOTE' WHEN 9 THEN 'NA' ELSE 'BCO' END,
               m.LADO       = CASE WHEN m.VALOR_DEBITO > 0 THEN 'D' WHEN m.VALOR_CREDITO > 0 THEN 'C' ELSE '0' END
        FROM MIG.Movimento m;

        UPDATE a
           SET a.DUPLICADA = 1
        FROM MIG.Movimento a
        WHERE a.ORIGEM = 'ACCESS_ARQMORTO'
          AND EXISTS (SELECT 1 FROM MIG.Movimento m WHERE m.ORIGEM = 'ACCESS_MOVTO' AND m.HASH_CONTEUDO = a.HASH_CONTEUDO);

        SET @EtapaAtual = 'Unidades';
        UPDATE m
           SET m.UNIDADE = CASE WHEN m.LOTE > 0       THEN 'L:' + CONVERT(VARCHAR(20), m.LOTE)
                                WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
                                ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END
        FROM MIG.Movimento m
        WHERE m.SD_ACUM = 0 AND m.DUPLICADA = 0;

        CREATE INDEX IX_MIG_Movimento_UNIDADE ON MIG.Movimento (UNIDADE) INCLUDE (TIPO_CONTA, LADO, DT_VALIDA);

        SELECT x.UNIDADE,
               COALESCE(MAX(CASE WHEN x.TIPO_CONTA IN ('BCO', 'NA') THEN x.DT_VALIDA END), MAX(x.DT_VALIDA)) AS DT_UNIDADE,
               CAST('' AS VARCHAR(200)) AS PADRAO
        INTO #U
        FROM MIG.Movimento x
        WHERE x.UNIDADE <> ''
        GROUP BY x.UNIDADE;

        ;WITH P AS
        (
            SELECT d.UNIDADE, LEFT(d.UNIDADE, 1) + '|' + STRING_AGG(CAST(d.PAR AS VARCHAR(MAX)), '|') WITHIN GROUP (ORDER BY d.PAR) AS PADRAO
            FROM (SELECT DISTINCT x.UNIDADE, x.TIPO_CONTA + '-' + x.LADO AS PAR FROM MIG.Movimento x WHERE x.UNIDADE <> '') d
            GROUP BY d.UNIDADE
        )
        UPDATE u SET u.PADRAO = LEFT(p.PADRAO, 200) FROM #U u INNER JOIN P p ON p.UNIDADE = u.UNIDADE;

        UPDATE m
           SET m.DT_UNIDADE = u.DT_UNIDADE,
               m.PADRAO     = u.PADRAO
        FROM MIG.Movimento m
        INNER JOIN #U u ON u.UNIDADE = m.UNIDADE;

        SET @EtapaAtual = 'Destino';
        UPDATE m
           SET m.DESTINO = CASE WHEN m.DUPLICADA = 1                        THEN 'FORA_DUPLIC'
                                WHEN m.SD_ACUM = 1 AND m.DT_VALIDA <= @Corte THEN 'ARQ_MORTO'
                                WHEN m.SD_ACUM = 1                          THEN 'FORA_SDACUM'
                                WHEN m.DT_UNIDADE IS NULL                   THEN 'CASO_DATA'
                                WHEN m.DT_UNIDADE < @Corte                  THEN 'ARQ_MORTO'
                                ELSE 'SISTEMA' END
        FROM MIG.Movimento m;

        -- contrato de venda: imóvel + cliente da parcela (linha na conta 2 "Débitos")
        ;WITH C AS
        (
            SELECT d.UNIDADE, MIN(CONVERT(VARCHAR(12), d.IMOVEL) + ':' + CONVERT(VARCHAR(12), d.PARCEIRO)) AS CONTRATO
            FROM MIG.Movimento d
            WHERE d.UNIDADE LIKE 'V:%' AND d.CONTA = 2
            GROUP BY d.UNIDADE
        )
        UPDATE m SET m.CONTRATO = c.CONTRATO
        FROM MIG.Movimento m INNER JOIN C c ON c.UNIDADE = m.UNIDADE;

        UPDATE m
           SET m.DESTINO = 'SISTEMA'
        FROM MIG.Movimento m
        WHERE m.DESTINO = 'ARQ_MORTO' AND m.CONTRATO <> ''
          AND EXISTS (SELECT 1 FROM MIG.Movimento x WHERE x.CONTRATO = m.CONTRATO AND x.DESTINO = 'SISTEMA');

        DROP TABLE IF EXISTS #U;

        SELECT m.DESTINO, COUNT(*) AS LINHAS, COUNT(DISTINCT NULLIF(m.UNIDADE, '')) AS DOCUMENTOS,
               SUM(m.VALOR_DEBITO) AS DEBITOS, SUM(m.VALOR_CREDITO) AS CREDITOS
        FROM MIG.Movimento m
        GROUP BY m.DESTINO
        ORDER BY m.DESTINO;
    END TRY
    BEGIN CATCH
        DROP TABLE IF EXISTS #U;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Arquivo_Morto_Processar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Arquivo_Morto_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Carrega o arquivo morto (FIN.Arquivo_Morto) com as linhas que o
                MIG_Movimento_Preparar marcou com destino ARQ_MORTO: movimento
                anterior ao corte e os resumos "Sd Acum" até o corte,
                com os textos legíveis do Access (empresa, obra, pessoa, conta,
                plano, histórico, imóvel). Saldos por conta
                (FIN.Arquivo_Morto_Saldo): soma dos últimos resumos "Sd Acum"
                antes do corte (o Access só tem até 01/01/2020), como o Access
                mostrava (só referência: não são os saldos reais do banco).
                Tudo-ou-nada; repetível: apaga a carga anterior do Access e
                carrega de novo. Devolve quantidade e totais carregados.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
    v1.1 (17/11/2026) - Saldo pelo último resumo antes do corte (corte 2022).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Arquivo_Morto_Processar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Arquivo_Morto_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @DtResumo   DATE;

    BEGIN TRY
        IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
            THROW 50001, N'Rode antes o MIG.MIG_Movimento_Preparar.', 1;

        SET @EtapaAtual = 'Carga';
        BEGIN TRANSACTION;

        DELETE FROM FIN.Arquivo_Morto WHERE ORIGEM_ACCESS IN ('ACCESS_MOVTO', 'ACCESS_ARQMORTO');
        DELETE FROM FIN.Arquivo_Morto_Saldo;

        INSERT INTO FIN.Arquivo_Morto (ORIGEM_ACCESS, CODIGO_ACCESS, EMPRESA, OBRA, PESSOA, CONTA, PLANO1, PLANO2, PLANO3, HISTORICO,
                                       COMPLEMENTO, DOCUMENTO, NOTA_FISCAL, IMOVEL, OBSERVACAO, VALOR_DEBITO, VALOR_CREDITO,
                                       DT_MOVIMENTO, DT_VENCIMENTO, DT_PAGAMENTO, CONFIRMADO, EFETUADO)
        SELECT m.ORIGEM, m.NUM,
               LEFT(ISNULL(em.NomeMaster, N''), 150), LEFT(ISNULL(ev.NomeVinculada, N''), 150),
               LEFT(ISNULL(pa.NomeParceiro, N''), 150), LEFT(ISNULL(cf.Descricao, N''), 80),
               LEFT(ISNULL(p1.DescricaoPlano1, N''), 80), LEFT(ISNULL(p2.DescricaoPlano2, N''), 80), LEFT(ISNULL(p3.DescricaoPlano3, N''), 120),
               LEFT(ISNULL(hi.Descricao, N''), 80),
               LEFT(m.COMPLEMENTO, 255), LEFT(m.NUM_DOC, 60), LEFT(m.NOTA_FISCAL, 60), LEFT(ISNULL(im.NomeImovel, N''), 150),
               LEFT(m.OBSERVACAO, 2000), m.VALOR_DEBITO, m.VALOR_CREDITO,
               m.DT_VALIDA,
               CASE WHEN m.DT_VENCTO BETWEEN '2000-01-01' AND '2035-12-31' THEN m.DT_VENCTO END,
               CASE WHEN m.DT_PAGTO  BETWEEN '2000-01-01' AND '2035-12-31' THEN m.DT_PAGTO END,
               m.CONFIRMADO, m.EFETUADO
        FROM MIG.Movimento m
        LEFT JOIN MIG.Access_EmpVinculada ev       ON TRY_CONVERT(INT, ev.CodigoVinculada) = m.EMP_VINCULADA
        LEFT JOIN MIG.Access_EmpMaster em          ON em.CodigoMaster = ev.CodigoMaster
        LEFT JOIN MIG.Access_Parceiros pa          ON TRY_CONVERT(INT, pa.CodigoParceiro) = m.PARCEIRO
        LEFT JOIN MIG.Access_Contas_Financeiras cf ON TRY_CONVERT(INT, cf.CodigoConta) = m.CONTA
        LEFT JOIN MIG.Access_Plano1 p1             ON TRY_CONVERT(INT, p1.Plano1) = m.PLANO1
        LEFT JOIN MIG.Access_Plano2 p2             ON TRY_CONVERT(INT, p2.Plano2) = m.PLANO2
        LEFT JOIN MIG.Access_Plano3 p3             ON TRY_CONVERT(INT, p3.Plano3) = m.PLANO3
        LEFT JOIN MIG.Access_Historico hi          ON TRY_CONVERT(INT, hi.CodHistorico) = m.HISTORICO
        OUTER APPLY (SELECT TOP (1) i.NomeImovel FROM MIG.Access_Imoveis i
                     WHERE TRY_CONVERT(INT, i.CodImovel) = m.IMOVEL AND m.IMOVEL > 1 ORDER BY i.NomeImovel) im
        WHERE m.DESTINO = 'ARQ_MORTO';

        SELECT @DtResumo = MAX(m.DT_VALIDA) FROM MIG.Movimento m WHERE m.SD_ACUM = 1 AND m.DESTINO = 'ARQ_MORTO';

        INSERT INTO FIN.Arquivo_Morto_Saldo (CONTA, DT_SALDO, SALDO)
        SELECT LEFT(ISNULL(cf.Descricao, N'Conta ' + CONVERT(NVARCHAR(10), m.CONTA)), 80), DATEADD(DAY, -1, @DtResumo), SUM(m.VALOR_CREDITO - m.VALOR_DEBITO)
        FROM MIG.Movimento m
        LEFT JOIN MIG.Access_Contas_Financeiras cf ON TRY_CONVERT(INT, cf.CodigoConta) = m.CONTA
        WHERE m.SD_ACUM = 1 AND m.DUPLICADA = 0 AND m.DT_VALIDA = @DtResumo AND m.CONTA NOT IN (1, 2, 3)
        GROUP BY LEFT(ISNULL(cf.Descricao, N'Conta ' + CONVERT(NVARCHAR(10), m.CONTA)), 80);

        COMMIT TRANSACTION;

        SELECT a.ORIGEM_ACCESS, COUNT(*) AS LINHAS, SUM(a.VALOR_DEBITO) AS DEBITOS, SUM(a.VALOR_CREDITO) AS CREDITOS,
               MIN(a.DT_MOVIMENTO) AS DE, MAX(a.DT_MOVIMENTO) AS ATE,
               SUM(CASE WHEN a.PESSOA = N'' THEN 1 ELSE 0 END) AS SEM_PESSOA, SUM(CASE WHEN a.CONTA = N'' THEN 1 ELSE 0 END) AS SEM_CONTA
        FROM FIN.Arquivo_Morto a
        GROUP BY a.ORIGEM_ACCESS;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Conferencia_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [MIG].[MIG_Conferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Relatório de conferência do ensaio (4 grades):
                1) Access x MIG: linhas de cada tabela do Access contra o que foi
                   carregado e classificado (nada se perde);
                2) destino de cada linha (sistema, arquivo morto, resumos,
                   duplicadas, casos de data);
                3) documentos do sistema novo (a partir do corte) por padrão (quantidade, linhas,
                   valor), base das regras de transformação;
                4) arquivo morto por ano (linhas, débitos, créditos).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
    v1.1 (17/11/2026) - Rótulo da grade de padrões sem o ano fixo.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Conferencia_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 'ACCESS x MIG' AS GRADE, x.TABELA, x.LINHAS_ACCESS, x.LINHAS_MIG,
           CASE WHEN x.LINHAS_ACCESS = x.LINHAS_MIG THEN 'OK' ELSE 'DIFERENTE' END AS SITUACAO
    FROM (SELECT N'F Movimento Contas' AS TABELA, (SELECT COUNT(*) FROM MIG.Access_Movimento) AS LINHAS_ACCESS,
                 (SELECT COUNT(*) FROM MIG.Movimento WHERE ORIGEM = 'ACCESS_MOVTO') AS LINHAS_MIG
          UNION ALL
          SELECT N'ArquivoMorto', (SELECT COUNT(*) FROM MIG.Access_ArquivoMorto), (SELECT COUNT(*) FROM MIG.Movimento WHERE ORIGEM = 'ACCESS_ARQMORTO')
          UNION ALL
          SELECT N'Arquivo morto carregado', (SELECT COUNT(*) FROM MIG.Movimento WHERE DESTINO = 'ARQ_MORTO'),
                 (SELECT COUNT(*) FROM FIN.Arquivo_Morto WHERE ORIGEM_ACCESS IN ('ACCESS_MOVTO', 'ACCESS_ARQMORTO'))) x;

    SELECT 'DESTINO' AS GRADE, m.DESTINO, COUNT(*) AS LINHAS, COUNT(DISTINCT NULLIF(m.UNIDADE, '')) AS DOCUMENTOS,
           SUM(m.VALOR_DEBITO) AS DEBITOS, SUM(m.VALOR_CREDITO) AS CREDITOS
    FROM MIG.Movimento m
    GROUP BY m.DESTINO
    ORDER BY m.DESTINO;

    SELECT 'PADROES (SISTEMA NOVO)' AS GRADE, u.PADRAO, COUNT(*) AS DOCUMENTOS, SUM(u.LINHAS) AS LINHAS, SUM(u.VALOR) AS VALOR
    FROM (SELECT m.UNIDADE, MAX(m.PADRAO) AS PADRAO, COUNT(*) AS LINHAS, SUM(m.VALOR_DEBITO + m.VALOR_CREDITO) AS VALOR
          FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' GROUP BY m.UNIDADE) u
    GROUP BY u.PADRAO
    ORDER BY COUNT(*) DESC;

    SELECT 'ARQUIVO MORTO POR ANO' AS GRADE, YEAR(a.DT_MOVIMENTO) AS ANO, COUNT(*) AS LINHAS, SUM(a.VALOR_DEBITO) AS DEBITOS, SUM(a.VALOR_CREDITO) AS CREDITOS
    FROM FIN.Arquivo_Morto a
    WHERE a.ORIGEM_ACCESS IN ('ACCESS_MOVTO', 'ACCESS_ARQMORTO')
    GROUP BY YEAR(a.DT_MOVIMENTO)
    ORDER BY ANO;
END;
GO

PRINT N'Pacote 03c_mig concluído sem erro.';
GO

SET NOEXEC OFF;
GO
