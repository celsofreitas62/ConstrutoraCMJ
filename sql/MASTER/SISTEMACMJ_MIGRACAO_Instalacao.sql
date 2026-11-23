/*******************************************************************************
  Arquivo     : SISTEMACMJ_MIGRACAO_Instalacao.sql   (MIGRACAO v1.3)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Gerado em   : 23/11/2026 por sql/ferramentas/montar_migracao.py, juntando
                os arquivos de sql/objetos/MIG dos pacotes homologados (03c_mig,
                03c2 e 03c2b). NAO EDITAR: corrigir o arquivo do objeto e gerar de
                novo.
  Descricao   : Instala no servidor o schema MIG (migracao do Access): tabelas de
                carga crua, classificacao, transformacao, tela "Casos da
                migracao" e arquivo morto. Fica FORA do MASTER (PADRAO_SQL regra
                60): roda so na virada e e removido depois que a migracao e os
                casos resolvidos terminarem. Idempotente.
  Pre-requisito: banco SISTEMACMJ com o MASTER ja rodado.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > conferir o banco > F5.
  Objetos     : 24 arquivos.
*******************************************************************************/
IF DB_NAME() <> N'SISTEMACMJ'
BEGIN
    RAISERROR(N'Banco errado: a migracao so e instalada no banco SISTEMACMJ. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO
IF OBJECT_ID(N'SIS.Modulo') IS NULL OR OBJECT_ID(N'FIN.Lancamento') IS NULL
BEGIN
    RAISERROR(N'O MASTER ainda nao foi rodado neste banco. Rode o SISTEMACMJ_MASTER_Instalacao.sql primeiro. Nada foi executado.', 16, 1);
    SET NOEXEC ON;
END;
GO
PRINT N'MIGRACAO v1.3: inicio em ' + DB_NAME() + N' (' + CONVERT(NVARCHAR(30), SYSDATETIME(), 120) + N').';
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.Tabelas_Access.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Carga_Processar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Movimento_Preparar.sql
-- -----------------------------------------------------------------------------
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
    v1.2 (19/11/2026) - Índice por (ORIGEM, NUM), para a tela de casos.
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
        CREATE INDEX IX_MIG_Movimento_ORIGEM_NUM ON MIG.Movimento (ORIGEM, NUM) INCLUDE (UNIDADE, DESTINO, LINK_VENDA, LOTE);

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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Arquivo_Morto_Processar.sql
-- -----------------------------------------------------------------------------
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
                Também entram os documentos que a tela "Casos da migração"
                mandou para o arquivo morto (MIG.Caso_Correcao, ACAO
                ARQUIVO_MORTO), com o motivo no início da observação; esses
                ficam fora do financeiro novo (MIG_Movimento_Transformar).
                Tudo-ou-nada; repetível: apaga a carga anterior do Access e
                carrega de novo. Devolve quantidade e totais carregados.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
    v1.1 (17/11/2026) - Saldo pelo último resumo antes do corte (corte 2022).
    v1.2 (18/11/2026) - Recebe os documentos mandados ao arquivo morto pela tela
                        de casos (etapa 03c2).
    v1.3 (19/11/2026) - Vale também para documento formado por troca de lote.
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
               LEFT(CASE WHEN cm.UNIDADE IS NULL THEN m.OBSERVACAO
                         ELSE N'[Migração: mandado ao arquivo morto pela tela de casos por ' + ISNULL(cm.USUARIO_ALTERACAO, cm.USUARIO_CRIACAO)
                              + N': ' + cm.MOTIVO + N'] ' + m.OBSERVACAO END, 2000),
               m.VALOR_DEBITO, m.VALOR_CREDITO,
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
        LEFT JOIN MIG.vw_MIG_Linha_Unidade lu      ON lu.ORIGEM = m.ORIGEM AND lu.NUM = m.NUM
        LEFT JOIN MIG.Caso_Correcao cm             ON cm.UNIDADE = lu.UNIDADE AND cm.ACAO = 'ARQUIVO_MORTO' AND m.DESTINO = 'SISTEMA'
        WHERE m.DESTINO = 'ARQ_MORTO' OR cm.UNIDADE IS NOT NULL;

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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Conferencia_Listar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.Tabelas_Cadastros.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : tabelas de classificação e de-para dos cadastros (schema MIG)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Migração dos cadastros do Access (etapa 03c2).
                Tabelas de CLASSIFICAÇÃO (decisões, preenchidas pela carga
                Carga_MIG_Classificacao.sql e conferidas pela CMJ; o que não
                estiver nelas segue a regra automática da procedure e aparece
                na conferência):
                  MIG.Classif_Empresa      EmpMaster -> empresa do grupo ou não
                  MIG.Classif_Centro       EmpVinculada -> centro de custo
                  MIG.Classif_Centro_Extra centros que não existem no Access
                                           (imóveis próprios, decisão do plano)
                  MIG.Classif_Conta        F Contas Financeiras -> BANCO.Conta
                  MIG.Config_Plano_Grupo   grupos do plano (número, nome, tipo,
                                           custo de obra; grupos de histórico)
                  MIG.DePara_Plano_Excecao contas do plano que mudam de lugar
                                           (plano antigo usado desde o corte,
                                           receitas, não operacional)
                Tabelas de DE-PARA (resultado, refeitas a cada carga, usadas
                na transformação do movimento):
                  MIG.DePara_Centro        EmpVinculada -> centro, empresa, cliente
                  MIG.DePara_Plano         Plano3 -> conta do plano (+ centro do imóvel)
                Pessoas, empresas, contas e históricos: pela coluna
                CODIGO_ACCESS das próprias tabelas.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).
    v1.1 (22/11/2026) - 03f (respostas da CMJ ao 3º documento):
                        Classif_Centro.CODIGO_CONTA_PADRAO (conta padrão do
                        centro decidida pela CMJ, no lugar da do Access) e
                        Classif_Centro_Extra.ATIVO (NULL = regra automática;
                        0/1 = decisão da CMJ, ex.: imóvel vendido).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'MIG') IS NULL EXEC (N'CREATE SCHEMA [MIG] AUTHORIZATION [dbo];');
GO

IF OBJECT_ID(N'[MIG].[Classif_Empresa]', N'U') IS NULL
    CREATE TABLE [MIG].[Classif_Empresa]
    (
        CODIGO_MASTER     INT            NOT NULL CONSTRAINT PK_Classif_Empresa PRIMARY KEY,
        DESTINO           VARCHAR(12)    NOT NULL,          -- EMPRESA / CONSTRUTORA (obras ficam na empresa principal) / NAO_MIGRA
        PRINCIPAL         BIT            NOT NULL CONSTRAINT DF_Classif_Empresa_PRINCIPAL DEFAULT (0),
        TIPO              VARCHAR(12)    NOT NULL CONSTRAINT DF_Classif_Empresa_TIPO      DEFAULT ('OUTRA'),
        RAZAO_SOCIAL      NVARCHAR(150)  NOT NULL CONSTRAINT DF_Classif_Empresa_RAZAO     DEFAULT (N''),
        NOME_FANTASIA     NVARCHAR(100)  NOT NULL CONSTRAINT DF_Classif_Empresa_FANTASIA  DEFAULT (N''),
        CNPJ              VARCHAR(14)    NOT NULL CONSTRAINT DF_Classif_Empresa_CNPJ      DEFAULT (''),
        CNPJ_COMPRAS      VARCHAR(14)    NOT NULL CONSTRAINT DF_Classif_Empresa_CNPJ_COMP DEFAULT (''),
        REGIME_TRIBUTARIO VARCHAR(20)    NOT NULL CONSTRAINT DF_Classif_Empresa_REGIME    DEFAULT (''),
        OBSERVACAO        NVARCHAR(400)  NOT NULL CONSTRAINT DF_Classif_Empresa_OBS       DEFAULT (N''),
        CONSTRAINT CK_Classif_Empresa_DESTINO CHECK (DESTINO IN ('EMPRESA', 'CONSTRUTORA', 'NAO_MIGRA'))
    );
GO

IF OBJECT_ID(N'[MIG].[Classif_Centro]', N'U') IS NULL
    CREATE TABLE [MIG].[Classif_Centro]
    (
        CODIGO_VINCULADA       INT            NOT NULL CONSTRAINT PK_Classif_Centro PRIMARY KEY,
        DESTINO                VARCHAR(10)    NOT NULL,      -- CENTRO / NAO_MIGRA
        CODIGO                 VARCHAR(20)    NOT NULL CONSTRAINT DF_Classif_Centro_CODIGO DEFAULT (''),
        DESCRICAO              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Classif_Centro_DESC   DEFAULT (N''),
        TIPO                   VARCHAR(15)    NOT NULL CONSTRAINT DF_Classif_Centro_TIPO   DEFAULT (''),
        CODIGO_MASTER_EMPRESA  INT            NULL,          -- dona do centro; NULL = regra (empresa do EmpMaster ou a principal)
        PARCEIRO_CLIENTE       INT            NULL,          -- cliente da obra por administração (código do Parceiros)
        CODIGO_CONTA_PADRAO    INT            NULL,          -- conta padrão (código do F Contas Financeiras); NULL = a do Access
        OBSERVACAO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Classif_Centro_OBS    DEFAULT (N''),
        CONSTRAINT CK_Classif_Centro_DESTINO CHECK (DESTINO IN ('CENTRO', 'NAO_MIGRA')),
        CONSTRAINT CK_Classif_Centro_TIPO    CHECK (TIPO IN ('', 'OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR'))
    );
GO

IF OBJECT_ID(N'[MIG].[Classif_Centro_Extra]', N'U') IS NULL
    CREATE TABLE [MIG].[Classif_Centro_Extra]
    (
        CODIGO                 VARCHAR(20)    NOT NULL CONSTRAINT PK_Classif_Centro_Extra PRIMARY KEY,
        DESCRICAO              NVARCHAR(100)  NOT NULL,
        TIPO                   VARCHAR(15)    NOT NULL,
        CODIGO_MASTER_EMPRESA  INT            NOT NULL,
        CONTABIL               BIT            NOT NULL CONSTRAINT DF_Classif_Centro_Extra_CONTABIL DEFAULT (1),
        ATIVO                  BIT            NULL,          -- NULL = regra (ativo se usado); 0/1 = decisão da CMJ
        OBSERVACAO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Classif_Centro_Extra_OBS      DEFAULT (N''),
        CONSTRAINT CK_Classif_Centro_Extra_TIPO CHECK (TIPO IN ('OBRA', 'ADMINISTRATIVO', 'IMOVEL_PROPRIO', 'PARTICULAR'))
    );
GO

-- v1.1 (03f): colunas novas em tabela já existente
IF COL_LENGTH(N'MIG.Classif_Centro', N'CODIGO_CONTA_PADRAO') IS NULL
    ALTER TABLE [MIG].[Classif_Centro] ADD CODIGO_CONTA_PADRAO INT NULL;
GO
IF COL_LENGTH(N'MIG.Classif_Centro_Extra', N'ATIVO') IS NULL
    ALTER TABLE [MIG].[Classif_Centro_Extra] ADD ATIVO BIT NULL;
GO

IF OBJECT_ID(N'[MIG].[Classif_Conta]', N'U') IS NULL
    CREATE TABLE [MIG].[Classif_Conta]
    (
        CODIGO_CONTA           INT            NOT NULL CONSTRAINT PK_Classif_Conta PRIMARY KEY,
        DESTINO                VARCHAR(10)    NOT NULL,      -- CONTA / NAO_MIGRA
        CODIGO_MASTER_EMPRESA  INT            NULL,
        DESCRICAO              NVARCHAR(60)   NOT NULL CONSTRAINT DF_Classif_Conta_DESC    DEFAULT (N''),
        TIPO                   VARCHAR(10)    NOT NULL CONSTRAINT DF_Classif_Conta_TIPO    DEFAULT (''),
        BANCO_CODIGO           CHAR(3)        NULL,
        AGENCIA                VARCHAR(10)    NOT NULL CONSTRAINT DF_Classif_Conta_AGENCIA DEFAULT (''),
        NUMERO                 VARCHAR(20)    NOT NULL CONSTRAINT DF_Classif_Conta_NUMERO  DEFAULT (''),
        NUMERO_DV              VARCHAR(2)     NOT NULL CONSTRAINT DF_Classif_Conta_DV      DEFAULT (''),
        OBSERVACAO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Classif_Conta_OBS     DEFAULT (N''),
        CONSTRAINT CK_Classif_Conta_DESTINO CHECK (DESTINO IN ('CONTA', 'NAO_MIGRA')),
        CONSTRAINT CK_Classif_Conta_TIPO    CHECK (TIPO IN ('', 'CORRENTE', 'POUPANCA', 'APLICACAO', 'CAIXA', 'PERMUTA'))
    );
GO

IF OBJECT_ID(N'[MIG].[Config_Plano_Grupo]', N'U') IS NULL
    CREATE TABLE [MIG].[Config_Plano_Grupo]
    (
        NUMERO         SMALLINT       NOT NULL CONSTRAINT PK_Config_Plano_Grupo PRIMARY KEY,
        DESCRICAO      NVARCHAR(80)   NOT NULL,
        TIPO           VARCHAR(15)    NOT NULL,
        CUSTO_OBRA     BIT            NOT NULL CONSTRAINT DF_Config_Plano_Grupo_CUSTO DEFAULT (0),
        ATIVO          BIT            NOT NULL CONSTRAINT DF_Config_Plano_Grupo_ATIVO DEFAULT (1),
        PLANO1_ACCESS  INT            NULL,      -- grupo do plano ANTIGO que vira este grupo de histórico (inativo)
        CONSTRAINT CK_Config_Plano_Grupo_TIPO CHECK (TIPO IN ('RECEITA', 'DESPESA', 'NAO_OPERACIONAL'))
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Plano_Excecao]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Plano_Excecao]
    (
        PLANO3_ACCESS       INT            NOT NULL CONSTRAINT PK_DePara_Plano_Excecao PRIMARY KEY,
        ALVO_PLANO3_ACCESS  INT            NULL,       -- vai para a conta nova que veio deste Plano3 do Access, ou:
        GRUPO_NUMERO        SMALLINT       NULL,       -- ... para a conta abaixo (criada se não existir)
        SUBGRUPO_NUMERO     SMALLINT       NULL,
        SUBGRUPO_DESCRICAO  NVARCHAR(80)   NOT NULL CONSTRAINT DF_DePara_Plano_Excecao_SUB   DEFAULT (N''),
        CONTA_NUMERO        SMALLINT       NULL,
        CONTA_DESCRICAO     NVARCHAR(80)   NOT NULL CONSTRAINT DF_DePara_Plano_Excecao_CONTA DEFAULT (N''),
        CENTRO_CODIGO       VARCHAR(20)    NULL,       -- centro de custo do imóvel (Classif_Centro_Extra)
        OBSERVACAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_DePara_Plano_Excecao_OBS   DEFAULT (N''),
        CONSTRAINT CK_DePara_Plano_Excecao_ALVO CHECK (ALVO_PLANO3_ACCESS IS NOT NULL
                                                    OR (GRUPO_NUMERO IS NOT NULL AND SUBGRUPO_NUMERO IS NOT NULL AND CONTA_NUMERO IS NOT NULL
                                                        AND SUBGRUPO_DESCRICAO <> N'' AND CONTA_DESCRICAO <> N''))
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Centro]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Centro]
    (
        CODIGO_VINCULADA    INT            NOT NULL CONSTRAINT PK_DePara_Centro PRIMARY KEY,
        ID_CENTRO_CUSTO     INT            NOT NULL,
        ID_EMPRESA          INT            NOT NULL,
        ID_PESSOA_CLIENTE   INT            NULL,
        PERCENTUAL_ADM      DECIMAL(9,4)   NOT NULL CONSTRAINT DF_DePara_Centro_PERC DEFAULT (0),
        ID_CONTA_PADRAO     INT            NULL,
        CLASSIF_AUTOMATICA  BIT            NOT NULL CONSTRAINT DF_DePara_Centro_AUTO DEFAULT (0)
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Plano]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Plano]
    (
        PLANO3_ACCESS       INT            NOT NULL CONSTRAINT PK_DePara_Plano PRIMARY KEY,
        ID_PLANO_CONTA      INT            NOT NULL,
        ID_CENTRO_CUSTO     INT            NULL,       -- imóvel próprio identificado pela conta antiga
        REGRA               VARCHAR(12)    NOT NULL    -- NOVO / HISTORICO / EXCECAO / DUPLICADA
    );
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.fn_MIG_Plano_Desmontar.sql
-- -----------------------------------------------------------------------------
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
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Cadastros_Processar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Cadastros_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Migração dos cadastros do Access para o sistema novo (etapa
                03c2, parte A), na ordem: empresas, contas (BANCO.Conta, mais o
                "Caixa contábil" de cada empresa), pessoas e contatos, centros
                de custo (obras do Access e imóveis próprios), históricos
                padrão e plano de contas; no fim refaz os de-paras usados na
                transformação do movimento (MIG.DePara_Centro e
                MIG.DePara_Plano).
                Regras: tabelas MIG.Classif_* / Config_* / DePara_Plano_Excecao
                (decisões conferidas pela CMJ) e regra automática para o que
                não estiver nelas. "Usado" = tem linha que vai para o sistema
                novo (MIG.Movimento, DESTINO = 'SISTEMA'): define o que nasce
                ativo.
                Repetível: cada cadastro é localizado pelo código do Access
                (CODIGO_ACCESS) ou pelo número (plano) e só é alterado quando
                algum valor mudou; nada é apagado. CNPJ e razão social vazios
                na classificação não apagam o que já foi digitado pela tela.
                Tudo-ou-nada (uma transação). Grava como usuário "sistema",
                origem MIGRACAO (auditoria).
                Pré-requisito: MIG_Carga_Processar e MIG_Movimento_Preparar
                rodados; Carga_MIG_Classificacao.sql aplicada.
                Devolve o resumo por cadastro.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).
    v1.1 (22/11/2026) - 03f: conta padrão do centro pode vir da classificação
                        (Classif_Centro.CODIGO_CONTA_PADRAO, decisão da CMJ) no
                        lugar da do Access; centro extra com ATIVO decidido na
                        classificação (ex.: imóvel vendido) prevalece sobre a
                        regra automática.

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Cadastros_Processar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Cadastros_Processar]
    @NomeCaixaContabil  NVARCHAR(60) = N'Caixa contábil'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[MIG].[MIG_Cadastros_Processar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @IdSistema   INT;
    DECLARE @Usuario     NVARCHAR(100);
    DECLARE @Agora       DATETIME2(0)  = SYSDATETIME();
    DECLARE @MasterPrinc INT;
    DECLARE @IdPrincipal INT;

    BEGIN TRY
        DROP TABLE IF EXISTS #UsoCentro, #UsoConta, #UsoPessoa, #UsoPlano, #UsoPlanoTotal, #Emp, #Cta, #Pes, #Ctt, #CC,
                             #Hist, #P3, #Grupo, #SubNum, #SubDest, #ContaDest, #Mapa;

        IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
            THROW 50001, N'Rode antes o MIG.MIG_Movimento_Preparar.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.Access_Parceiros) OR NOT EXISTS (SELECT 1 FROM MIG.Access_EmpVinculada) OR NOT EXISTS (SELECT 1 FROM MIG.Access_Plano3)
            THROW 50001, N'As tabelas do Access estão vazias: rode antes o MIG.MIG_Carga_Processar.', 1;
        IF (SELECT COUNT(*) FROM MIG.Classif_Empresa c WHERE c.PRINCIPAL = 1 AND c.DESTINO = 'EMPRESA') <> 1
            THROW 50001, N'A classificação precisa de exatamente uma empresa principal (Carga_MIG_Classificacao.sql).', 1;
        IF EXISTS (SELECT 1 FROM MIG.Classif_Conta c WHERE c.DESTINO = 'CONTA' AND c.BANCO_CODIGO IS NOT NULL
                   AND NOT EXISTS (SELECT 1 FROM BANCO.Banco b WHERE b.CODIGO = c.BANCO_CODIGO))
            THROW 50001, N'Falta no cadastro de bancos algum banco usado nas contas (BANCO.Banco).', 1;

        SELECT @IdSistema = u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema';
        IF @IdSistema IS NULL
            THROW 50001, N'Usuário "sistema" não encontrado.', 1;
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdSistema);
        EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Origem = N'MIGRACAO';

        SELECT @MasterPrinc = c.CODIGO_MASTER FROM MIG.Classif_Empresa c WHERE c.PRINCIPAL = 1 AND c.DESTINO = 'EMPRESA';

        SET @EtapaAtual = 'Uso desde o corte';
        SELECT DISTINCT m.EMP_VINCULADA AS COD INTO #UsoCentro FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' AND m.EMP_VINCULADA IS NOT NULL;
        SELECT DISTINCT m.CONTA         AS COD INTO #UsoConta  FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' AND m.CONTA IS NOT NULL;
        SELECT DISTINCT m.PARCEIRO      AS COD INTO #UsoPessoa FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' AND m.PARCEIRO IS NOT NULL;
        SELECT DISTINCT m.PLANO3        AS COD INTO #UsoPlano  FROM MIG.Movimento m WHERE m.DESTINO = 'SISTEMA' AND m.PLANO3 IS NOT NULL;
        SELECT DISTINCT m.PLANO3        AS COD INTO #UsoPlanoTotal FROM MIG.Movimento m WHERE m.PLANO3 IS NOT NULL;

        BEGIN TRANSACTION;

        /* ------------------------------------------------------------------
           1. Empresas do grupo
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Empresas';
        SELECT c.CODIGO_MASTER,
               CAST(LEFT(COALESCE(NULLIF(c.RAZAO_SOCIAL, N''), LTRIM(RTRIM(m.NomeMaster)), N'Empresa ' + CONVERT(NVARCHAR(10), c.CODIGO_MASTER)), 150) AS NVARCHAR(150)) AS RAZAO_SOCIAL,
               CAST(LEFT(c.NOME_FANTASIA, 100) AS NVARCHAR(100)) AS NOME_FANTASIA,
               c.CNPJ, c.CNPJ_COMPRAS, c.TIPO, c.REGIME_TRIBUTARIO
        INTO #Emp
        FROM MIG.Classif_Empresa c
        LEFT JOIN MIG.Access_EmpMaster m ON TRY_CONVERT(INT, m.CodigoMaster) = c.CODIGO_MASTER
        WHERE c.DESTINO = 'EMPRESA';

        UPDATE e
           SET e.RAZAO_SOCIAL      = s.RAZAO_SOCIAL,
               e.NOME_FANTASIA     = CASE WHEN s.NOME_FANTASIA <> N'' THEN s.NOME_FANTASIA ELSE e.NOME_FANTASIA END,
               e.CNPJ              = CASE WHEN s.CNPJ <> '' THEN s.CNPJ ELSE e.CNPJ END,
               e.CNPJ_COMPRAS      = CASE WHEN s.CNPJ_COMPRAS <> '' THEN s.CNPJ_COMPRAS ELSE e.CNPJ_COMPRAS END,
               e.TIPO              = s.TIPO,
               e.REGIME_TRIBUTARIO = CASE WHEN s.REGIME_TRIBUTARIO <> '' THEN s.REGIME_TRIBUTARIO ELSE e.REGIME_TRIBUTARIO END,
               e.ATIVO             = 1,
               e.DT_ALTERACAO      = @Agora,
               e.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Empresa e
        INNER JOIN #Emp s ON s.CODIGO_MASTER = e.CODIGO_ACCESS
        WHERE e.RAZAO_SOCIAL <> s.RAZAO_SOCIAL
           OR (s.NOME_FANTASIA <> N'' AND e.NOME_FANTASIA <> s.NOME_FANTASIA)
           OR (s.CNPJ <> '' AND e.CNPJ <> s.CNPJ)
           OR (s.CNPJ_COMPRAS <> '' AND e.CNPJ_COMPRAS <> s.CNPJ_COMPRAS)
           OR e.TIPO <> s.TIPO
           OR (s.REGIME_TRIBUTARIO <> '' AND e.REGIME_TRIBUTARIO <> s.REGIME_TRIBUTARIO)
           OR e.ATIVO = 0;

        INSERT INTO CAD.Empresa (RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, TIPO, REGIME_TRIBUTARIO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.RAZAO_SOCIAL, s.NOME_FANTASIA, s.CNPJ, s.CNPJ_COMPRAS, s.TIPO, s.REGIME_TRIBUTARIO, 1, s.CODIGO_MASTER, @Usuario
        FROM #Emp s
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.CODIGO_ACCESS = s.CODIGO_MASTER);

        SELECT @IdPrincipal = e.ID_EMPRESA FROM CAD.Empresa e WHERE e.CODIGO_ACCESS = @MasterPrinc;

        /* ------------------------------------------------------------------
           2. Contas bancárias, caixas e permuta; "Caixa contábil" por empresa
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Contas';
        SELECT c.CODIGO_CONTA,
               e.ID_EMPRESA,
               CAST(LEFT(COALESCE(NULLIF(c.DESCRICAO, N''), LTRIM(RTRIM(a.Descricao))), 60) AS NVARCHAR(60)) AS DESCRICAO,
               c.TIPO, b.ID_BANCO, c.AGENCIA, c.NUMERO, c.NUMERO_DV,
               ISNULL(ROUND(TRY_CONVERT(DECIMAL(19,6), a.[Limite Credito]), 2), 0) AS LIMITE_CREDITO,
               CAST(CASE WHEN a.Conciliacao = N'True' THEN 1 ELSE 0 END AS BIT) AS CONCILIA,
               CAST(CASE WHEN a.NaoListarResumo = N'True' THEN 0 ELSE 1 END AS BIT) AS MOSTRA_SALDO,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM #UsoConta u WHERE u.COD = c.CODIGO_CONTA) THEN 1 ELSE 0 END AS BIT) AS ATIVO
        INTO #Cta
        FROM MIG.Classif_Conta c
        INNER JOIN CAD.Empresa e ON e.CODIGO_ACCESS = c.CODIGO_MASTER_EMPRESA
        LEFT JOIN MIG.Access_Contas_Financeiras a ON TRY_CONVERT(INT, a.CodigoConta) = c.CODIGO_CONTA
        LEFT JOIN BANCO.Banco b ON b.CODIGO = c.BANCO_CODIGO
        WHERE c.DESTINO = 'CONTA';

        UPDATE d
           SET d.ID_EMPRESA = s.ID_EMPRESA, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.ID_BANCO = s.ID_BANCO,
               d.AGENCIA = s.AGENCIA, d.NUMERO = s.NUMERO, d.NUMERO_DV = s.NUMERO_DV, d.LIMITE_CREDITO = s.LIMITE_CREDITO,
               d.CONCILIA = s.CONCILIA, d.MOSTRA_SALDO = s.MOSTRA_SALDO, d.ATIVO = s.ATIVO,
               d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM BANCO.Conta d
        INNER JOIN #Cta s ON s.CODIGO_CONTA = d.CODIGO_ACCESS
        WHERE EXISTS (SELECT d.ID_EMPRESA, d.DESCRICAO, d.TIPO, d.ID_BANCO, d.AGENCIA, d.NUMERO, d.NUMERO_DV, d.LIMITE_CREDITO, d.CONCILIA, d.MOSTRA_SALDO, d.ATIVO
                      EXCEPT
                      SELECT s.ID_EMPRESA, s.DESCRICAO, s.TIPO, s.ID_BANCO, s.AGENCIA, s.NUMERO, s.NUMERO_DV, s.LIMITE_CREDITO, s.CONCILIA, s.MOSTRA_SALDO, s.ATIVO);

        INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, ID_BANCO, AGENCIA, NUMERO, NUMERO_DV, LIMITE_CREDITO, CONCILIA, MOSTRA_SALDO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.ID_EMPRESA, s.DESCRICAO, s.TIPO, s.ID_BANCO, s.AGENCIA, s.NUMERO, s.NUMERO_DV, s.LIMITE_CREDITO, s.CONCILIA, s.MOSTRA_SALDO, s.ATIVO, s.CODIGO_CONTA, @Usuario
        FROM #Cta s
        WHERE NOT EXISTS (SELECT 1 FROM BANCO.Conta d WHERE d.CODIGO_ACCESS = s.CODIGO_CONTA);

        INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, CONCILIA, MOSTRA_SALDO, ATIVO, USUARIO_CRIACAO)
        SELECT e.ID_EMPRESA, @NomeCaixaContabil, 'CAIXA', 0, 1, 1, @Usuario
        FROM CAD.Empresa e
        INNER JOIN #Emp s ON s.CODIGO_MASTER = e.CODIGO_ACCESS
        WHERE NOT EXISTS (SELECT 1 FROM BANCO.Conta d WHERE d.ID_EMPRESA = e.ID_EMPRESA AND d.DESCRICAO = @NomeCaixaContabil);

        /* ------------------------------------------------------------------
           3. Pessoas (Parceiros) e contatos
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Pessoas';
        ;WITH Fonte AS
        (
            SELECT TRY_CONVERT(INT, p.CodigoParceiro) AS COD, p.*,
                   CAD.fn_CAD_Somente_Digitos(p.CNPJ) AS CNPJ_D,
                   CAD.fn_CAD_Somente_Digitos(p.CPF)  AS CPF_D
            FROM MIG.Access_Parceiros p
            WHERE TRY_CONVERT(INT, p.CodigoParceiro) > 1
              AND ISNULL(p.Master, N'False') <> N'True'
              AND LTRIM(RTRIM(ISNULL(p.NomeParceiro, N''))) <> N''
        ),
        Doc AS
        (
            SELECT f.*,
                   CASE WHEN LEN(f.CNPJ_D) BETWEEN 12 AND 14 THEN RIGHT('00' + f.CNPJ_D, 14) ELSE '' END AS CNPJ_OK,
                   CASE WHEN LEN(f.CPF_D)  BETWEEN 9  AND 11 THEN RIGHT('00' + f.CPF_D, 11)  ELSE '' END AS CPF_OK
            FROM Fonte f
        )
        SELECT d.COD,
               CAST(LEFT(LTRIM(RTRIM(d.NomeParceiro)), 150) AS NVARCHAR(150)) AS NOME,
               CAST(CASE WHEN d.CNPJ_OK <> '' THEN d.CNPJ_OK WHEN d.CPF_OK <> '' THEN d.CPF_OK ELSE '' END AS VARCHAR(14)) AS CPF_CNPJ,
               CAST(CASE WHEN d.CNPJ_OK <> '' THEN 'J'
                         WHEN d.CPF_OK  <> '' THEN 'F'
                         WHEN d.NomeParceiro LIKE N'%ltda%' OR d.NomeParceiro LIKE N'% s/a%' OR d.NomeParceiro LIKE N'% s.a%' OR d.NomeParceiro LIKE N'% sa'
                           OR d.NomeParceiro LIKE N'% me' OR d.NomeParceiro LIKE N'% epp' OR d.NomeParceiro LIKE N'%eireli%' OR d.NomeParceiro LIKE N'%com_rcio%'
                           OR d.NomeParceiro LIKE N'%ind_stria%' OR d.NomeParceiro LIKE N'%construtora%' OR d.NomeParceiro LIKE N'%condom_nio%'
                           OR d.NomeParceiro LIKE N'%associa__o%' OR d.NomeParceiro LIKE N'%prefeitura%' OR d.NomeParceiro LIKE N'%banco %'
                           OR d.NomeParceiro LIKE N'% cia%' OR d.NomeParceiro LIKE N'%companhia%' OR d.NomeParceiro LIKE N'%servi_os%'
                           OR d.NomeParceiro LIKE N'%distribuidora%' OR d.NomeParceiro LIKE N'%materiais%' OR d.NomeParceiro LIKE N'%engenharia%'
                           OR d.NomeParceiro LIKE N'%transporte%' OR d.NomeParceiro LIKE N'%imobili_ri%' OR d.NomeParceiro LIKE N'%cart_rio%'
                           OR d.NomeParceiro LIKE N'%receita federal%' OR d.NomeParceiro LIKE N'%sindicato%' OR d.NomeParceiro LIKE N'%hotel%'
                           OR d.NomeParceiro LIKE N'%depto%' OR d.NomeParceiro LIKE N'%departamento%' OR d.NomeParceiro LIKE N'%funda__o%'
                           OR d.NomeParceiro LIKE N'%instituto%' OR d.NomeParceiro LIKE N'%escrit_rio%' OR d.NomeParceiro LIKE N'%incorporadora%'
                           OR d.NomeParceiro LIKE N'% spe%' OR d.NomeParceiro LIKE N'%loja%' OR d.NomeParceiro LIKE N'%posto %'
                           OR d.NomeParceiro LIKE N'%concreto%' OR d.NomeParceiro LIKE N'%madeireira%' OR d.NomeParceiro LIKE N'%ferragens%'
                           OR d.NomeParceiro LIKE N'%telecom%' OR d.NomeParceiro LIKE N'%cemig%' OR d.NomeParceiro LIKE N'%copasa%'
                           OR d.NomeParceiro LIKE N'%dmae%' OR d.NomeParceiro LIKE N'%sicredi%' OR d.NomeParceiro LIKE N'%ita[uú]%'
                         THEN 'J' ELSE 'F' END AS CHAR(1)) AS TIPO_PESSOA,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.RG, N''))), 20) AS VARCHAR(20)) AS RG,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.IE, N''))), 20) AS VARCHAR(20)) AS INSCRICAO_ESTADUAL,
               CAST(CASE WHEN LEN(CAD.fn_CAD_Somente_Digitos(d.CEP)) = 8 THEN CAD.fn_CAD_Somente_Digitos(d.CEP) ELSE '' END AS VARCHAR(8)) AS CEP,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.Endereco, N''))), 150) AS NVARCHAR(150)) AS LOGRADOURO,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.Bairro, N''))), 60) AS NVARCHAR(60)) AS BAIRRO,
               CAST(LEFT(LTRIM(RTRIM(ISNULL(d.Cidade, N''))), 60) AS NVARCHAR(60)) AS CIDADE,
               CAST(CASE WHEN LEN(LTRIM(RTRIM(ISNULL(d.Estado, N'')))) = 2 AND UPPER(LTRIM(RTRIM(d.Estado))) NOT LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2
                         THEN UPPER(LTRIM(RTRIM(d.Estado))) ELSE '' END AS CHAR(2)) AS UF,
               CAST(CASE WHEN d.Cliente = N'True' THEN 1 ELSE 0 END AS BIT) AS CLIENTE,
               CAST(CASE WHEN d.Fornecedor = N'True' THEN 1 ELSE 0 END AS BIT) AS FORNECEDOR,
               CAST(CASE WHEN d.Funcionario = N'True' THEN 1 ELSE 0 END AS BIT) AS FUNCIONARIO,
               CAST(CASE WHEN d.Inativo = N'True' THEN 0 ELSE 1 END AS BIT) AS ATIVO,
               CAST(LEFT(CONCAT_WS(N' | ',
                        NULLIF(LTRIM(RTRIM(ISNULL(d.Observacoes, N''))), N''),
                        N'Contato: ' + NULLIF(LTRIM(RTRIM(ISNULL(d.Contato, N''))), N''),
                        N'Trabalho: ' + NULLIF(LTRIM(RTRIM(ISNULL(d.Trabalho, N''))), N''),
                        N'Ramal: ' + NULLIF(LTRIM(RTRIM(ISNULL(d.Ramal, N''))), N''),
                        CASE WHEN d.CNPJ_OK <> '' AND d.CPF_OK <> '' THEN N'CPF no Access: ' + d.CPF_OK END,
                        CASE WHEN d.CNPJ_OK = '' AND d.CNPJ_D <> '' THEN N'CNPJ no Access (incompleto): ' + d.CNPJ_D END,
                        CASE WHEN d.CPF_OK = '' AND d.CPF_D <> '' THEN N'CPF no Access (incompleto): ' + d.CPF_D END,
                        CASE WHEN LEN(CAD.fn_CAD_Somente_Digitos(d.CEP)) NOT IN (0, 8) THEN N'CEP no Access: ' + d.CEP END,
                        CASE WHEN LEN(LTRIM(RTRIM(ISNULL(d.Estado, N'')))) NOT IN (0, 2) THEN N'UF no Access: ' + d.Estado END
                    ), 1800) AS NVARCHAR(2000)) AS OBSERVACAO,
               d.Email, d.Telefone, d.TelefoneComercial, d.Fax
        INTO #Pes
        FROM Doc d;

        -- contatos candidatos (e-mail separado por ; , espaço ou #mailto:; telefone só dígitos)
        SELECT x.COD, x.TIPO, x.VALOR, x.ORIGEM, x.ORDEM,
               CAST(CASE WHEN x.TIPO = 'EMAIL' THEN SIS.fn_SIS_Email_Valido(x.VALOR)
                         WHEN LEN(x.VALOR) BETWEEN 10 AND 13 THEN 1 ELSE 0 END AS BIT) AS VALIDO
        INTO #Ctt
        FROM (
            SELECT p.COD, CAST('EMAIL' AS VARCHAR(10)) AS TIPO, CAST(LOWER(LTRIM(RTRIM(s.value))) AS NVARCHAR(256)) AS VALOR,
                   CAST(N'E-mail' AS NVARCHAR(30)) AS ORIGEM, s.ordinal AS ORDEM
            FROM #Pes p
            CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p.Email, N''), N'mailto:', N';'), N'#', N';'), N',', N';'), N' ', N';'), N';', 1) s
            WHERE LTRIM(RTRIM(s.value)) <> N''
            UNION ALL
            SELECT p.COD,
                   CAST(CASE WHEN LEN(t.D) = 11 AND SUBSTRING(t.D, 3, 1) = '9' THEN 'CELULAR' ELSE 'TELEFONE' END AS VARCHAR(10)),
                   CAST(t.D AS NVARCHAR(256)), t.ORIGEM, 100 + t.ORDEM
            FROM #Pes p
            CROSS APPLY (VALUES (CAD.fn_CAD_Somente_Digitos(p.Telefone), N'Telefone', 1),
                                (CAD.fn_CAD_Somente_Digitos(p.TelefoneComercial), N'Telefone comercial', 2),
                                (CAD.fn_CAD_Somente_Digitos(p.Fax), N'Fax', 3)) t (D, ORIGEM, ORDEM)
            WHERE t.D <> ''
        ) x;

        -- o que não é contato válido vai para a observação (nada se perde)
        UPDATE p
           SET p.OBSERVACAO = CAST(LEFT(CONCAT_WS(N' | ', NULLIF(p.OBSERVACAO, N''), i.TEXTO), 2000) AS NVARCHAR(2000))
        FROM #Pes p
        INNER JOIN (SELECT c.COD, STRING_AGG(CAST(c.ORIGEM + N' no Access: ' + c.VALOR AS NVARCHAR(MAX)), N' | ') AS TEXTO
                    FROM #Ctt c WHERE c.VALIDO = 0 GROUP BY c.COD) i ON i.COD = p.COD;

        UPDATE d
           SET d.TIPO_PESSOA = s.TIPO_PESSOA, d.NOME = s.NOME, d.CPF_CNPJ = s.CPF_CNPJ, d.RG = s.RG, d.INSCRICAO_ESTADUAL = s.INSCRICAO_ESTADUAL,
               d.CEP = s.CEP, d.LOGRADOURO = s.LOGRADOURO, d.BAIRRO = s.BAIRRO, d.CIDADE = s.CIDADE, d.UF = s.UF,
               d.CLIENTE = s.CLIENTE, d.FORNECEDOR = s.FORNECEDOR, d.FUNCIONARIO = s.FUNCIONARIO, d.OBSERVACAO = s.OBSERVACAO, d.ATIVO = s.ATIVO,
               d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Pessoa d
        INNER JOIN #Pes s ON s.COD = d.CODIGO_ACCESS
        WHERE EXISTS (SELECT d.TIPO_PESSOA, d.NOME, d.CPF_CNPJ, d.RG, d.INSCRICAO_ESTADUAL, d.CEP, d.LOGRADOURO, d.BAIRRO, d.CIDADE, d.UF,
                             d.CLIENTE, d.FORNECEDOR, d.FUNCIONARIO, d.OBSERVACAO, d.ATIVO
                      EXCEPT
                      SELECT s.TIPO_PESSOA, s.NOME, s.CPF_CNPJ, s.RG, s.INSCRICAO_ESTADUAL, s.CEP, s.LOGRADOURO, s.BAIRRO, s.CIDADE, s.UF,
                             s.CLIENTE, s.FORNECEDOR, s.FUNCIONARIO, s.OBSERVACAO, s.ATIVO);

        INSERT INTO CAD.Pessoa (TIPO_PESSOA, NOME, CPF_CNPJ, RG, INSCRICAO_ESTADUAL, CEP, LOGRADOURO, BAIRRO, CIDADE, UF,
                                CLIENTE, FORNECEDOR, FUNCIONARIO, OBSERVACAO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.TIPO_PESSOA, s.NOME, s.CPF_CNPJ, s.RG, s.INSCRICAO_ESTADUAL, s.CEP, s.LOGRADOURO, s.BAIRRO, s.CIDADE, s.UF,
               s.CLIENTE, s.FORNECEDOR, s.FUNCIONARIO, s.OBSERVACAO, s.ATIVO, s.COD, @Usuario
        FROM #Pes s
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa d WHERE d.CODIGO_ACCESS = s.COD);

        ;WITH V AS
        (
            SELECT p.ID_PESSOA, c.TIPO, c.VALOR, MIN(c.ORDEM) AS ORDEM, MAX(CAST(pe.CLIENTE AS INT)) AS CLIENTE
            FROM #Ctt c
            INNER JOIN #Pes pe ON pe.COD = c.COD
            INNER JOIN CAD.Pessoa p ON p.CODIGO_ACCESS = c.COD
            WHERE c.VALIDO = 1
            GROUP BY p.ID_PESSOA, c.TIPO, c.VALOR
        ),
        N AS
        (
            SELECT v.*, ROW_NUMBER() OVER (PARTITION BY v.ID_PESSOA, CASE WHEN v.TIPO = 'EMAIL' THEN 1 ELSE 2 END ORDER BY v.ORDEM) AS RN
            FROM V v
        )
        INSERT INTO CAD.Pessoa_Contato (ID_PESSOA, TIPO, VALOR, PRINCIPAL, RECEBE_COBRANCA, USUARIO_CRIACAO)
        SELECT n.ID_PESSOA, n.TIPO, n.VALOR,
               CAST(CASE WHEN n.RN = 1 THEN 1 ELSE 0 END AS BIT),
               CAST(CASE WHEN n.TIPO = 'EMAIL' AND n.CLIENTE = 1 THEN 1 ELSE 0 END AS BIT),
               @Usuario
        FROM N n
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Contato x WHERE x.ID_PESSOA = n.ID_PESSOA AND x.TIPO = n.TIPO AND x.VALOR = n.VALOR);

        /* ------------------------------------------------------------------
           4. Centros de custo: obras/empresas vinculadas do Access + extras
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Centros de custo';
        SELECT TRY_CONVERT(INT, v.CodigoVinculada) AS COD,
               CAST(CASE WHEN c.CODIGO_VINCULADA IS NOT NULL THEN c.DESTINO
                         WHEN ce.DESTINO = 'NAO_MIGRA' THEN 'NAO_MIGRA'
                         ELSE 'CENTRO' END AS VARCHAR(10)) AS DESTINO,
               CAST(COALESCE(NULLIF(c.CODIGO, ''), 'A' + LTRIM(RTRIM(v.CodigoVinculada))) AS VARCHAR(20)) AS CODIGO,
               CAST(LEFT(COALESCE(NULLIF(c.DESCRICAO, N''), NULLIF(LTRIM(RTRIM(v.NomeVinculada)), N''), LTRIM(RTRIM(m.NomeMaster)),
                                  N'Centro ' + LTRIM(RTRIM(v.CodigoVinculada))), 100) AS NVARCHAR(100)) AS DESCRICAO,
               CAST(COALESCE(NULLIF(c.TIPO, ''),
                             CASE WHEN v.Administracao = N'True' OR v.Custos = N'True' OR v.ImovelEmVenda = N'True' THEN 'OBRA' ELSE 'ADMINISTRATIVO' END) AS VARCHAR(15)) AS TIPO,
               COALESCE(c.CODIGO_MASTER_EMPRESA, CASE WHEN ce.DESTINO = 'EMPRESA' THEN ce.CODIGO_MASTER END, @MasterPrinc) AS MASTER_EMPRESA,
               CAST(CASE WHEN v.Contabil = N'True' THEN 1 ELSE 0 END AS BIT) AS CONTABIL,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM #UsoCentro u WHERE u.COD = TRY_CONVERT(INT, v.CodigoVinculada)) THEN 1 ELSE 0 END AS BIT) AS ATIVO,
               COALESCE(c.CODIGO_CONTA_PADRAO, TRY_CONVERT(INT, v.FinanceiraPadrao)) AS CONTA_ACCESS,
               c.PARCEIRO_CLIENTE,
               ISNULL(TRY_CONVERT(DECIMAL(9,4), v.PercentualAdm), 0) AS PERCENTUAL_ADM,
               CAST(CASE WHEN c.CODIGO_VINCULADA IS NULL OR c.TIPO = '' THEN 1 ELSE 0 END AS BIT) AS AUTOMATICA,
               CAST(NULL AS INT) AS ID_EMPRESA,
               CAST(NULL AS INT) AS ID_CONTA_PADRAO
        INTO #CC
        FROM MIG.Access_EmpVinculada v
        LEFT JOIN MIG.Classif_Centro c   ON c.CODIGO_VINCULADA = TRY_CONVERT(INT, v.CodigoVinculada)
        LEFT JOIN MIG.Access_EmpMaster m ON m.CodigoMaster = v.CodigoMaster
        LEFT JOIN MIG.Classif_Empresa ce ON ce.CODIGO_MASTER = TRY_CONVERT(INT, v.CodigoMaster)
        WHERE TRY_CONVERT(INT, v.CodigoVinculada) IS NOT NULL;

        DELETE FROM #CC WHERE DESTINO = 'NAO_MIGRA';

        UPDATE c SET c.ID_EMPRESA = ISNULL(e.ID_EMPRESA, @IdPrincipal)
        FROM #CC c LEFT JOIN CAD.Empresa e ON e.CODIGO_ACCESS = c.MASTER_EMPRESA;

        -- conta padrão só quando a conta é da mesma empresa do centro
        UPDATE c SET c.ID_CONTA_PADRAO = k.ID_CONTA
        FROM #CC c INNER JOIN BANCO.Conta k ON k.CODIGO_ACCESS = c.CONTA_ACCESS AND k.ID_EMPRESA = c.ID_EMPRESA;

        IF EXISTS (SELECT c.CODIGO FROM #CC c GROUP BY c.CODIGO HAVING COUNT(*) > 1)
            THROW 50001, N'Há código de centro de custo repetido na classificação (MIG.Classif_Centro).', 1;

        UPDATE d
           SET d.ID_EMPRESA = s.ID_EMPRESA, d.CODIGO = s.CODIGO, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CONTABIL = s.CONTABIL,
               d.ID_CONTA_BANCARIA_PADRAO = s.ID_CONTA_PADRAO, d.ATIVO = s.ATIVO, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Centro_Custo d
        INNER JOIN #CC s ON s.COD = d.CODIGO_ACCESS
        WHERE EXISTS (SELECT d.ID_EMPRESA, d.CODIGO, d.DESCRICAO, d.TIPO, d.CONTABIL, d.ID_CONTA_BANCARIA_PADRAO, d.ATIVO
                      EXCEPT
                      SELECT s.ID_EMPRESA, s.CODIGO, s.DESCRICAO, s.TIPO, s.CONTABIL, s.ID_CONTA_PADRAO, s.ATIVO);

        INSERT INTO CAD.Centro_Custo (ID_EMPRESA, CODIGO, DESCRICAO, TIPO, CONTABIL, ID_CONTA_BANCARIA_PADRAO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.ID_EMPRESA, s.CODIGO, s.DESCRICAO, s.TIPO, s.CONTABIL, s.ID_CONTA_PADRAO, s.ATIVO, s.COD, @Usuario
        FROM #CC s
        WHERE NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo d WHERE d.CODIGO_ACCESS = s.COD);

        -- centros extras (imóveis próprios e particulares): ativos se alguma conta do plano que aponta para eles foi usada
        ;WITH X AS
        (
            SELECT x.CODIGO, x.DESCRICAO, x.TIPO, x.CONTABIL, ISNULL(e.ID_EMPRESA, @IdPrincipal) AS ID_EMPRESA,
                   CAST(CASE WHEN x.ATIVO IS NOT NULL THEN x.ATIVO
                             WHEN EXISTS (SELECT 1 FROM MIG.DePara_Plano_Excecao p INNER JOIN #UsoPlano u ON u.COD = p.PLANO3_ACCESS
                                          WHERE p.CENTRO_CODIGO = x.CODIGO) THEN 1 ELSE 0 END AS BIT) AS ATIVO
            FROM MIG.Classif_Centro_Extra x
            LEFT JOIN CAD.Empresa e ON e.CODIGO_ACCESS = x.CODIGO_MASTER_EMPRESA
        )
        MERGE CAD.Centro_Custo AS d
        USING X AS s ON d.CODIGO = s.CODIGO AND d.CODIGO_ACCESS IS NULL
        WHEN MATCHED AND EXISTS (SELECT d.ID_EMPRESA, d.DESCRICAO, d.TIPO, d.CONTABIL, d.ATIVO EXCEPT SELECT s.ID_EMPRESA, s.DESCRICAO, s.TIPO, s.CONTABIL, s.ATIVO)
            THEN UPDATE SET d.ID_EMPRESA = s.ID_EMPRESA, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CONTABIL = s.CONTABIL, d.ATIVO = s.ATIVO,
                            d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        WHEN NOT MATCHED THEN INSERT (ID_EMPRESA, CODIGO, DESCRICAO, TIPO, CONTABIL, ATIVO, USUARIO_CRIACAO)
            VALUES (s.ID_EMPRESA, s.CODIGO, s.DESCRICAO, s.TIPO, s.CONTABIL, s.ATIVO, @Usuario);

        -- conta padrão da empresa (só se estiver vazia): a do centro administrativo, senão a da obra ativa mais usada
        UPDATE e
           SET e.ID_CONTA_BANCARIA_PADRAO = k.ID_CONTA, e.DT_ALTERACAO = @Agora, e.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Empresa e
        CROSS APPLY (SELECT TOP (1) c.ID_CONTA_PADRAO AS ID_CONTA
                     FROM #CC c
                     WHERE c.ID_EMPRESA = e.ID_EMPRESA AND c.ID_CONTA_PADRAO IS NOT NULL
                     ORDER BY CASE WHEN c.TIPO = 'ADMINISTRATIVO' THEN 0 ELSE 1 END, c.ATIVO DESC, c.COD) k
        WHERE e.ID_CONTA_BANCARIA_PADRAO IS NULL
          AND e.CODIGO_ACCESS IS NOT NULL;

        DELETE FROM MIG.DePara_Centro;
        INSERT INTO MIG.DePara_Centro (CODIGO_VINCULADA, ID_CENTRO_CUSTO, ID_EMPRESA, ID_PESSOA_CLIENTE, PERCENTUAL_ADM, ID_CONTA_PADRAO, CLASSIF_AUTOMATICA)
        SELECT s.COD, d.ID_CENTRO_CUSTO, d.ID_EMPRESA, p.ID_PESSOA, s.PERCENTUAL_ADM, s.ID_CONTA_PADRAO, s.AUTOMATICA
        FROM #CC s
        INNER JOIN CAD.Centro_Custo d ON d.CODIGO_ACCESS = s.COD
        LEFT JOIN CAD.Pessoa p ON p.CODIGO_ACCESS = s.PARCEIRO_CLIENTE;

        /* ------------------------------------------------------------------
           5. Históricos padrão (mesmo texto em dois códigos vira um só)
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Históricos';
        SELECT MIN(TRY_CONVERT(INT, h.CodHistorico)) AS COD, CAST(LEFT(LTRIM(RTRIM(h.Descricao)), 80) AS NVARCHAR(80)) AS DESCRICAO
        INTO #Hist
        FROM MIG.Access_Historico h
        WHERE LTRIM(RTRIM(ISNULL(h.Descricao, N''))) NOT IN (N'', N'sistema')   -- os marcados Master no Access (Pgto Efetuado, Depósito...) são usados
          AND TRY_CONVERT(INT, h.CodHistorico) IS NOT NULL
        GROUP BY CAST(LEFT(LTRIM(RTRIM(h.Descricao)), 80) AS NVARCHAR(80));

        INSERT INTO FIN.Historico_Padrao (DESCRICAO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT s.DESCRICAO, 1, s.COD, @Usuario
        FROM #Hist s
        WHERE NOT EXISTS (SELECT 1 FROM FIN.Historico_Padrao d WHERE d.CODIGO_ACCESS = s.COD OR d.DESCRICAO = s.DESCRICAO);

        /* ------------------------------------------------------------------
           6. Plano de contas
              NOVO      = grupo do Access com número no nome (00 a 18): número
                          e texto separados pelo fn_MIG_Plano_Desmontar;
              HISTORICO = grupo antigo listado em Config_Plano_Grupo
                          (PLANO1_ACCESS): inativo, numeração sequencial;
              EXCECAO   = DePara_Plano_Excecao.
              Só migram contas com algum movimento no Access.
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Plano: leitura';
        SELECT TRY_CONVERT(INT, p3.Plano3) AS P3, TRY_CONVERT(INT, p2.Plano2) AS P2, TRY_CONVERT(INT, p1.Plano1) AS P1,
               CAST(CASE WHEN g.NUMERO IS NOT NULL THEN 'HISTORICO'
                         WHEN LTRIM(p1.DescricaoPlano1) LIKE N'[0-9][0-9]%' THEN 'NOVO' END AS VARCHAR(12)) AS REGRA,
               CAST(COALESCE(g.NUMERO, TRY_CONVERT(SMALLINT, LEFT(LTRIM(p1.DescricaoPlano1), 2))) AS SMALLINT) AS G_NUM,
               d2.NUMERO_2 AS S_NUM_ACCESS, d2.QTD_NUMEROS AS S_QTD,
               CAST(LEFT(CASE WHEN g.NUMERO IS NULL THEN COALESCE(NULLIF(d2.TEXTO, N''), LTRIM(RTRIM(p2.DescricaoPlano2))) ELSE LTRIM(RTRIM(p2.DescricaoPlano2)) END, 80) AS NVARCHAR(80)) AS S_DESC,
               d3.NUMERO_ULTIMO AS C_NUM_ACCESS, d3.QTD_NUMEROS AS C_QTD,
               CAST(LEFT(CASE WHEN g.NUMERO IS NULL THEN COALESCE(NULLIF(d3.TEXTO, N''), LTRIM(RTRIM(p3.DescricaoPlano3))) ELSE LTRIM(RTRIM(p3.DescricaoPlano3)) END, 80) AS NVARCHAR(80)) AS C_DESC,
               CAST(NULL AS SMALLINT) AS S_NUM, CAST(NULL AS SMALLINT) AS C_NUM,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM MIG.DePara_Plano_Excecao x WHERE x.PLANO3_ACCESS = TRY_CONVERT(INT, p3.Plano3)) THEN 1 ELSE 0 END AS BIT) AS TEM_EXCECAO
        INTO #P3
        FROM MIG.Access_Plano3 p3
        INNER JOIN MIG.Access_Plano2 p2 ON p2.Plano2 = p3.Plano2
        INNER JOIN MIG.Access_Plano1 p1 ON p1.Plano1 = p2.Plano1
        LEFT JOIN MIG.Config_Plano_Grupo g ON g.PLANO1_ACCESS = TRY_CONVERT(INT, p1.Plano1)
        CROSS APPLY MIG.fn_MIG_Plano_Desmontar(p2.DescricaoPlano2) d2
        CROSS APPLY MIG.fn_MIG_Plano_Desmontar(p3.DescricaoPlano3) d3
        WHERE EXISTS (SELECT 1 FROM #UsoPlanoTotal u WHERE u.COD = TRY_CONVERT(INT, p3.Plano3))
          AND LTRIM(RTRIM(ISNULL(p3.DescricaoPlano3, N''))) <> N''
          AND ISNULL(p3.Master, N'False') <> N'True';

        DELETE FROM #P3 WHERE REGRA IS NULL OR S_DESC = N'' OR C_DESC = N'';
        -- conta do plano novo que muda inteira de lugar (exceção) não fica vazia no lugar antigo
        DELETE FROM #P3 WHERE REGRA = 'NOVO' AND TEM_EXCECAO = 1;

        IF EXISTS (SELECT 1 FROM #P3 p WHERE NOT EXISTS (SELECT 1 FROM MIG.Config_Plano_Grupo g WHERE g.NUMERO = p.G_NUM))
            THROW 50001, N'Há grupo do plano de contas do Access sem configuração (MIG.Config_Plano_Grupo).', 1;

        SET @EtapaAtual = 'Plano: numeração';
        -- subgrupo: número do Access (plano novo) ou sequencial; mesmo nome no mesmo grupo vira um só
        ;WITH S AS
        (
            SELECT DISTINCT p.G_NUM, p.P2, p.REGRA, p.S_DESC,
                   CASE WHEN p.REGRA = 'NOVO' AND p.S_QTD >= 2 AND p.S_NUM_ACCESS BETWEEN 1 AND 99 THEN p.S_NUM_ACCESS END AS N_ACCESS
            FROM #P3 p
        ),
        S1 AS
        (
            SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.G_NUM, s.N_ACCESS ORDER BY s.P2) AS RN_NUM,
                        MIN(s.P2) OVER (PARTITION BY s.G_NUM, s.S_DESC) AS P2_DONO
            FROM S s
        ),
        S2 AS
        (
            SELECT s.*, CASE WHEN s.N_ACCESS IS NOT NULL AND s.RN_NUM = 1 THEN s.N_ACCESS END AS N_FIXO
            FROM S1 s WHERE s.P2 = s.P2_DONO
        ),
        S3 AS
        (
            SELECT s.*, ISNULL(MAX(s.N_FIXO) OVER (PARTITION BY s.G_NUM), 0)
                        + ROW_NUMBER() OVER (PARTITION BY s.G_NUM, CASE WHEN s.N_FIXO IS NULL THEN 1 ELSE 0 END ORDER BY s.P2) AS N_SEQ
            FROM S2 s
        )
        SELECT s.G_NUM, s.P2, CAST(ISNULL(s.N_FIXO, s.N_SEQ) AS SMALLINT) AS S_NUM, s.S_DESC
        INTO #SubNum
        FROM S3 s;

        UPDATE p SET p.S_NUM = s.S_NUM
        FROM #P3 p
        INNER JOIN #SubNum s ON s.G_NUM = p.G_NUM AND (s.P2 = p.P2 OR (s.S_DESC = p.S_DESC AND NOT EXISTS (SELECT 1 FROM #SubNum z WHERE z.P2 = p.P2)));

        -- conta: número do Access (plano novo, 3 partes) ou sequencial; mesmo nome no mesmo subgrupo vira uma só
        ;WITH C AS
        (
            SELECT p.P3, p.G_NUM, p.S_NUM, p.C_DESC,
                   CASE WHEN p.REGRA = 'NOVO' AND p.C_QTD >= 3 AND p.C_NUM_ACCESS BETWEEN 1 AND 999 THEN p.C_NUM_ACCESS END AS N_ACCESS
            FROM #P3 p
        ),
        C1 AS
        (
            SELECT c.*, MIN(c.P3) OVER (PARTITION BY c.G_NUM, c.S_NUM, c.C_DESC) AS P3_DONO,
                        ROW_NUMBER() OVER (PARTITION BY c.G_NUM, c.S_NUM, c.N_ACCESS ORDER BY c.P3) AS RN_NUM
            FROM C c
        ),
        C2 AS
        (
            SELECT c.*, CASE WHEN c.N_ACCESS IS NOT NULL AND c.RN_NUM = 1 THEN c.N_ACCESS END AS N_FIXO
            FROM C1 c WHERE c.P3 = c.P3_DONO
        ),
        C3 AS
        (
            SELECT c.*, ISNULL(MAX(c.N_FIXO) OVER (PARTITION BY c.G_NUM, c.S_NUM), 0)
                        + ROW_NUMBER() OVER (PARTITION BY c.G_NUM, c.S_NUM, CASE WHEN c.N_FIXO IS NULL THEN 1 ELSE 0 END ORDER BY c.P3) AS N_SEQ
            FROM C2 c
        )
        UPDATE p SET p.C_NUM = CAST(ISNULL(c.N_FIXO, c.N_SEQ) AS SMALLINT)
        FROM #P3 p
        INNER JOIN C3 c ON c.G_NUM = p.G_NUM AND c.S_NUM = p.S_NUM AND c.C_DESC = p.C_DESC;

        IF EXISTS (SELECT 1 FROM #P3 p WHERE p.S_NUM IS NULL OR p.C_NUM IS NULL OR p.C_NUM > 999 OR p.S_NUM > 99)
            THROW 50001, N'Não foi possível numerar alguma conta do plano (subgrupo acima de 99 ou conta acima de 999).', 1;

        -- grupos, subgrupos e contas de destino
        SELECT p.G_NUM AS NUMERO INTO #Grupo FROM #P3 p
        UNION SELECT x.GRUPO_NUMERO FROM MIG.DePara_Plano_Excecao x WHERE x.GRUPO_NUMERO IS NOT NULL;

        SELECT p.G_NUM, p.S_NUM, MIN(p.S_DESC) AS S_DESC, MAX(CASE WHEN p.REGRA = 'HISTORICO' THEN 0 ELSE 1 END) AS ATIVO
        INTO #SubDest
        FROM #P3 p
        GROUP BY p.G_NUM, p.S_NUM;
        INSERT INTO #SubDest (G_NUM, S_NUM, S_DESC, ATIVO)
        SELECT x.GRUPO_NUMERO, x.SUBGRUPO_NUMERO, MIN(x.SUBGRUPO_DESCRICAO), 1
        FROM MIG.DePara_Plano_Excecao x
        WHERE x.GRUPO_NUMERO IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM #SubDest s WHERE s.G_NUM = x.GRUPO_NUMERO AND s.S_NUM = x.SUBGRUPO_NUMERO)
        GROUP BY x.GRUPO_NUMERO, x.SUBGRUPO_NUMERO;

        SELECT p.G_NUM, p.S_NUM, p.C_NUM, MIN(p.C_DESC) AS C_DESC, MIN(p.P3) AS P3, MAX(CASE WHEN p.REGRA = 'HISTORICO' THEN 0 ELSE 1 END) AS ATIVO
        INTO #ContaDest
        FROM #P3 p
        GROUP BY p.G_NUM, p.S_NUM, p.C_NUM;
        INSERT INTO #ContaDest (G_NUM, S_NUM, C_NUM, C_DESC, P3, ATIVO)
        SELECT x.GRUPO_NUMERO, x.SUBGRUPO_NUMERO, x.CONTA_NUMERO, MIN(x.CONTA_DESCRICAO), NULL, 1
        FROM MIG.DePara_Plano_Excecao x
        WHERE x.GRUPO_NUMERO IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM #ContaDest c WHERE c.G_NUM = x.GRUPO_NUMERO AND c.S_NUM = x.SUBGRUPO_NUMERO AND c.C_NUM = x.CONTA_NUMERO)
        GROUP BY x.GRUPO_NUMERO, x.SUBGRUPO_NUMERO, x.CONTA_NUMERO;

        SET @EtapaAtual = 'Plano: gravação';
        MERGE CAD.Plano_Grupo AS d
        USING (SELECT g.NUMERO, c.DESCRICAO, c.TIPO, c.CUSTO_OBRA, c.ATIVO, c.NUMERO AS ORDEM
               FROM #Grupo g INNER JOIN MIG.Config_Plano_Grupo c ON c.NUMERO = g.NUMERO) AS s
        ON d.NUMERO = s.NUMERO
        WHEN MATCHED AND EXISTS (SELECT d.DESCRICAO, d.TIPO, d.CUSTO_OBRA, d.ATIVO EXCEPT SELECT s.DESCRICAO, s.TIPO, s.CUSTO_OBRA, s.ATIVO)
            THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CUSTO_OBRA = s.CUSTO_OBRA, d.ATIVO = s.ATIVO,
                            d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        WHEN NOT MATCHED THEN INSERT (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ORDEM, ATIVO, USUARIO_CRIACAO)
            VALUES (s.NUMERO, s.DESCRICAO, s.TIPO, s.CUSTO_OBRA, s.ORDEM, s.ATIVO, @Usuario);

        MERGE CAD.Plano_Subgrupo AS d
        USING (SELECT g.ID_PLANO_GRUPO, s.S_NUM AS NUMERO, CAST(s.S_DESC AS NVARCHAR(80)) AS DESCRICAO, CAST(s.ATIVO AS BIT) AS ATIVO
               FROM #SubDest s INNER JOIN CAD.Plano_Grupo g ON g.NUMERO = s.G_NUM) AS s
        ON d.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO AND d.NUMERO = s.NUMERO
        WHEN MATCHED AND EXISTS (SELECT d.DESCRICAO, d.ATIVO EXCEPT SELECT s.DESCRICAO, s.ATIVO)
            THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.ATIVO = s.ATIVO, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        WHEN NOT MATCHED THEN INSERT (ID_PLANO_GRUPO, NUMERO, DESCRICAO, ORDEM, ATIVO, USUARIO_CRIACAO)
            VALUES (s.ID_PLANO_GRUPO, s.NUMERO, s.DESCRICAO, s.NUMERO, s.ATIVO, @Usuario);

        MERGE CAD.Plano_Conta AS d
        USING (SELECT sg.ID_PLANO_SUBGRUPO, c.C_NUM AS NUMERO, CAST(c.C_DESC AS NVARCHAR(80)) AS DESCRICAO, CAST(c.ATIVO AS BIT) AS ATIVO, c.P3
               FROM #ContaDest c
               INNER JOIN CAD.Plano_Grupo g     ON g.NUMERO = c.G_NUM
               INNER JOIN CAD.Plano_Subgrupo sg ON sg.ID_PLANO_GRUPO = g.ID_PLANO_GRUPO AND sg.NUMERO = c.S_NUM) AS s
        ON d.ID_PLANO_SUBGRUPO = s.ID_PLANO_SUBGRUPO AND d.NUMERO = s.NUMERO
        WHEN MATCHED AND EXISTS (SELECT d.DESCRICAO, d.ATIVO, d.CODIGO_ACCESS EXCEPT SELECT s.DESCRICAO, s.ATIVO, s.P3)
            THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.ATIVO = s.ATIVO, d.CODIGO_ACCESS = s.P3, d.DT_ALTERACAO = @Agora, d.USUARIO_ALTERACAO = @Usuario
        WHEN NOT MATCHED THEN INSERT (ID_PLANO_SUBGRUPO, NUMERO, DESCRICAO, ATIVO, CODIGO_ACCESS, USUARIO_CRIACAO)
            VALUES (s.ID_PLANO_SUBGRUPO, s.NUMERO, s.DESCRICAO, s.ATIVO, s.P3, @Usuario);

        SET @EtapaAtual = 'Plano: de-para';
        -- conta de destino de cada Plano3 do Access (a própria; a exceção manda para outro lugar)
        SELECT p.P3, p.G_NUM, p.S_NUM, p.C_NUM, CAST(NULL AS VARCHAR(20)) AS CENTRO_CODIGO,
               CAST(CASE WHEN p.REGRA = 'NOVO' AND EXISTS (SELECT 1 FROM #P3 z WHERE z.G_NUM = p.G_NUM AND z.S_NUM = p.S_NUM AND z.C_NUM = p.C_NUM AND z.P3 < p.P3)
                         THEN 'DUPLICADA' ELSE p.REGRA END AS VARCHAR(12)) AS REGRA
        INTO #Mapa
        FROM #P3 p
        WHERE p.TEM_EXCECAO = 0;

        INSERT INTO #Mapa (P3, G_NUM, S_NUM, C_NUM, CENTRO_CODIGO, REGRA)
        SELECT x.PLANO3_ACCESS,
               COALESCE(x.GRUPO_NUMERO, a.G_NUM), COALESCE(x.SUBGRUPO_NUMERO, a.S_NUM), COALESCE(x.CONTA_NUMERO, a.C_NUM),
               x.CENTRO_CODIGO, 'EXCECAO'
        FROM MIG.DePara_Plano_Excecao x
        LEFT JOIN #P3 a ON a.P3 = x.ALVO_PLANO3_ACCESS AND a.REGRA = 'NOVO' AND a.TEM_EXCECAO = 0
        WHERE EXISTS (SELECT 1 FROM MIG.Access_Plano3 p3 WHERE TRY_CONVERT(INT, p3.Plano3) = x.PLANO3_ACCESS)
          AND (x.GRUPO_NUMERO IS NOT NULL OR a.P3 IS NOT NULL);

        DELETE FROM MIG.DePara_Plano;
        INSERT INTO MIG.DePara_Plano (PLANO3_ACCESS, ID_PLANO_CONTA, ID_CENTRO_CUSTO, REGRA)
        SELECT m.P3, c.ID_PLANO_CONTA, cc.ID_CENTRO_CUSTO, m.REGRA
        FROM #Mapa m
        INNER JOIN CAD.Plano_Grupo g     ON g.NUMERO = m.G_NUM
        INNER JOIN CAD.Plano_Subgrupo s  ON s.ID_PLANO_GRUPO = g.ID_PLANO_GRUPO AND s.NUMERO = m.S_NUM
        INNER JOIN CAD.Plano_Conta c     ON c.ID_PLANO_SUBGRUPO = s.ID_PLANO_SUBGRUPO AND c.NUMERO = m.C_NUM
        LEFT JOIN CAD.Centro_Custo cc    ON cc.CODIGO = m.CENTRO_CODIGO AND cc.CODIGO_ACCESS IS NULL;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #UsoCentro, #UsoConta, #UsoPessoa, #UsoPlano, #UsoPlanoTotal, #Emp, #Cta, #Pes, #Ctt, #CC,
                             #Hist, #P3, #Grupo, #SubNum, #SubDest, #ContaDest, #Mapa;

        /* ------------------------------------------------------------------
           Resumo
           ------------------------------------------------------------------ */
        SELECT r.ORDEM, r.CADASTRO, r.NO_SISTEMA_NOVO, r.ATIVOS
        FROM (
            SELECT 1 AS ORDEM, N'Empresas'         AS CADASTRO, COUNT(*) AS NO_SISTEMA_NOVO, SUM(CAST(e.ATIVO AS INT)) AS ATIVOS FROM CAD.Empresa e WHERE e.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 2, N'Contas (do Access)', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM BANCO.Conta c WHERE c.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 3, N'Contas "' + @NomeCaixaContabil + N'"', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM BANCO.Conta c WHERE c.CODIGO_ACCESS IS NULL AND c.DESCRICAO = @NomeCaixaContabil
            UNION ALL SELECT 4, N'Pessoas', COUNT(*), SUM(CAST(p.ATIVO AS INT)) FROM CAD.Pessoa p WHERE p.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 5, N'Contatos das pessoas', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM CAD.Pessoa_Contato c INNER JOIN CAD.Pessoa p ON p.ID_PESSOA = c.ID_PESSOA WHERE p.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 6, N'Centros de custo (obras do Access)', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM CAD.Centro_Custo c WHERE c.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 7, N'Centros de custo (imóveis próprios e particulares)', COUNT(*), SUM(CAST(c.ATIVO AS INT)) FROM CAD.Centro_Custo c INNER JOIN MIG.Classif_Centro_Extra x ON x.CODIGO = c.CODIGO WHERE c.CODIGO_ACCESS IS NULL
            UNION ALL SELECT 8, N'Históricos padrão', COUNT(*), SUM(CAST(h.ATIVO AS INT)) FROM FIN.Historico_Padrao h WHERE h.CODIGO_ACCESS IS NOT NULL
            UNION ALL SELECT 9, N'Plano: grupos', COUNT(*), SUM(CAST(g.ATIVO AS INT)) FROM CAD.Plano_Grupo g INNER JOIN MIG.Config_Plano_Grupo c ON c.NUMERO = g.NUMERO
            UNION ALL SELECT 10, N'Plano: subgrupos', COUNT(*), SUM(CAST(s.ATIVO AS INT)) FROM CAD.Plano_Subgrupo s INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO INNER JOIN MIG.Config_Plano_Grupo c ON c.NUMERO = g.NUMERO
            UNION ALL SELECT 11, N'Plano: contas', COUNT(*), SUM(CAST(k.ATIVO AS INT)) FROM CAD.Plano_Conta k INNER JOIN CAD.Plano_Subgrupo s ON s.ID_PLANO_SUBGRUPO = k.ID_PLANO_SUBGRUPO INNER JOIN CAD.Plano_Grupo g ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO INNER JOIN MIG.Config_Plano_Grupo c ON c.NUMERO = g.NUMERO
            UNION ALL SELECT 12, N'De-para: centros (EmpVinculada)', COUNT(*), SUM(CASE WHEN d.CLASSIF_AUTOMATICA = 0 THEN 1 ELSE 0 END) FROM MIG.DePara_Centro d
            UNION ALL SELECT 13, N'De-para: plano (Plano3)', COUNT(*), SUM(CASE WHEN d.REGRA = 'EXCECAO' THEN 1 ELSE 0 END) FROM MIG.DePara_Plano d
        ) r
        ORDER BY r.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #UsoCentro, #UsoConta, #UsoPessoa, #UsoPlano, #UsoPlanoTotal, #Emp, #Cta, #Pes, #Ctt, #CC,
                             #Hist, #P3, #Grupo, #SubNum, #SubDest, #ContaDest, #Mapa;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Cadastros_Conferencia_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Cadastros_Conferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Conferência da migração dos cadastros (etapa 03c2, parte A).
                Grades, nesta ordem:
                  1. PENDÊNCIAS: o que precisa de decisão ou de cadastro antes
                     da transformação do movimento (linhas = quantas linhas do
                     movimento de 2022 em diante usam aquele código);
                  2. PESSOAS: números da conversão (documento, contatos, tipo);
                  3. EMPRESAS; 4. CONTAS; 5. CENTROS DE CUSTO;
                  6. PLANO: de-para das contas usadas desde o corte.
                Só leitura.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Cadastros_Conferencia_Listar;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Cadastros_Conferencia_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS #Uso;
    SELECT m.EMP_VINCULADA, m.CONTA, m.PARCEIRO, m.PLANO3, m.HISTORICO
    INTO #Uso
    FROM MIG.Movimento m WITH (NOLOCK)
    WHERE m.DESTINO = 'SISTEMA';

    /* 1. Pendências */
    SELECT x.ORDEM, x.TIPO, x.CODIGO_ACCESS, x.DESCRICAO_ACCESS, x.MOTIVO, x.LINHAS
    FROM (
        SELECT 1 AS ORDEM, N'Centro de custo' AS TIPO, u.EMP_VINCULADA AS CODIGO_ACCESS, MIN(ISNULL(v.NomeVinculada, N'')) AS DESCRICAO_ACCESS,
               CAST(CASE WHEN d.CODIGO_VINCULADA IS NULL THEN N'usado desde o corte e sem centro de custo (só a caixinha/contrapartida "N/A" é esperada aqui)'
                         ELSE N'classificação automática: conferir empresa, tipo e código' END AS NVARCHAR(200)) AS MOTIVO,
               COUNT(*) AS LINHAS
        FROM #Uso u
        LEFT JOIN MIG.DePara_Centro d ON d.CODIGO_VINCULADA = u.EMP_VINCULADA
        LEFT JOIN MIG.Access_EmpVinculada v ON TRY_CONVERT(INT, v.CodigoVinculada) = u.EMP_VINCULADA
        WHERE d.CODIGO_VINCULADA IS NULL OR d.CLASSIF_AUTOMATICA = 1
        GROUP BY u.EMP_VINCULADA, d.CODIGO_VINCULADA
        UNION ALL
        SELECT 2, N'Conta', u.CONTA, MIN(ISNULL(a.Descricao, N'')), N'usada desde o corte e sem conta no sistema novo', COUNT(*)
        FROM #Uso u
        LEFT JOIN MIG.Access_Contas_Financeiras a ON TRY_CONVERT(INT, a.CodigoConta) = u.CONTA
        WHERE u.CONTA NOT IN (1, 2, 3, 9)
          AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WITH (NOLOCK) WHERE c.CODIGO_ACCESS = u.CONTA)
        GROUP BY u.CONTA
        UNION ALL
        SELECT 3, N'Plano de contas', u.PLANO3, MIN(ISNULL(p3.DescricaoPlano3, N'')),
               CAST(CASE WHEN d.PLANO3_ACCESS IS NULL THEN N'usada desde o corte e sem conta no plano novo'
                         ELSE N'usada desde o corte, mas cai numa conta inativa (plano antigo): falta de-para' END AS NVARCHAR(200)), COUNT(*)
        FROM #Uso u
        LEFT JOIN MIG.DePara_Plano d ON d.PLANO3_ACCESS = u.PLANO3
        LEFT JOIN CAD.Plano_Conta k WITH (NOLOCK) ON k.ID_PLANO_CONTA = d.ID_PLANO_CONTA
        LEFT JOIN MIG.Access_Plano3 p3 ON TRY_CONVERT(INT, p3.Plano3) = u.PLANO3
        LEFT JOIN MIG.Access_Plano2 p2 ON p2.Plano2 = p3.Plano2
        WHERE ISNULL(p2.Plano1, N'') NOT IN (N'1', N'2', N'3', N'7')      -- contrapartida, sistema e saldo acumulado não são conta de resultado
          AND (d.PLANO3_ACCESS IS NULL OR k.ATIVO = 0)
        GROUP BY u.PLANO3, d.PLANO3_ACCESS
        UNION ALL
        SELECT 4, N'Pessoa', u.PARCEIRO, MIN(ISNULL(a.NomeParceiro, N'')), N'usada desde o corte e sem cadastro no sistema novo', COUNT(*)
        FROM #Uso u
        LEFT JOIN MIG.Access_Parceiros a ON TRY_CONVERT(INT, a.CodigoParceiro) = u.PARCEIRO
        WHERE u.PARCEIRO > 1
          AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WITH (NOLOCK) WHERE p.CODIGO_ACCESS = u.PARCEIRO)
        GROUP BY u.PARCEIRO
        UNION ALL
        SELECT 5, N'Histórico', u.HISTORICO, MIN(ISNULL(h.Descricao, N'')), N'usado desde o corte e sem histórico padrão no sistema novo', COUNT(*)
        FROM #Uso u
        LEFT JOIN MIG.Access_Historico h ON TRY_CONVERT(INT, h.CodHistorico) = u.HISTORICO
        WHERE u.HISTORICO IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM FIN.Historico_Padrao f WITH (NOLOCK)
                          WHERE f.CODIGO_ACCESS = u.HISTORICO OR f.DESCRICAO = LEFT(LTRIM(RTRIM(ISNULL(h.Descricao, N''))), 80))
          AND LTRIM(RTRIM(ISNULL(h.Descricao, N''))) NOT IN (N'', N'sistema')
        GROUP BY u.HISTORICO
        UNION ALL
        SELECT 6, N'Empresa', e.CODIGO_ACCESS, e.RAZAO_SOCIAL, N'sem CNPJ: preencher pela tela de Empresas', 0
        FROM CAD.Empresa e WITH (NOLOCK)
        WHERE e.CODIGO_ACCESS IS NOT NULL AND e.CNPJ = ''
    ) x
    ORDER BY x.ORDEM, x.LINHAS DESC, x.CODIGO_ACCESS;

    /* 2. Pessoas */
    SELECT COUNT(*)                                                                  AS PESSOAS,
           SUM(CAST(p.ATIVO AS INT))                                                 AS ATIVAS,
           SUM(f.USADA)                                                              AS USADAS_DESDE_O_CORTE,
           SUM(CASE WHEN p.TIPO_PESSOA = 'J' THEN 1 ELSE 0 END)                      AS JURIDICAS,
           SUM(CASE WHEN p.TIPO_PESSOA = 'F' THEN 1 ELSE 0 END)                      AS FISICAS,
           SUM(CASE WHEN p.CPF_CNPJ = '' THEN 1 ELSE 0 END)                          AS SEM_DOCUMENTO,
           SUM(f.DOC_INVALIDO)                                                       AS DOCUMENTO_INVALIDO,
           SUM(f.EMAIL)                                                              AS COM_EMAIL,
           SUM(f.TELEFONE)                                                           AS COM_TELEFONE,
           SUM(CASE WHEN p.OBSERVACAO LIKE N'%no Access:%' THEN 1 ELSE 0 END)        AS COM_DADO_DO_ACCESS_NA_OBSERVACAO
    FROM CAD.Pessoa p WITH (NOLOCK)
    CROSS APPLY (SELECT CASE WHEN EXISTS (SELECT 1 FROM #Uso u WHERE u.PARCEIRO = p.CODIGO_ACCESS) THEN 1 ELSE 0 END AS USADA,
                        CASE WHEN p.CPF_CNPJ <> '' AND CAD.fn_CAD_Documento_Valido(p.CPF_CNPJ) = 0 THEN 1 ELSE 0 END AS DOC_INVALIDO,
                        CASE WHEN EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = p.ID_PESSOA AND c.TIPO = 'EMAIL') THEN 1 ELSE 0 END AS EMAIL,
                        CASE WHEN EXISTS (SELECT 1 FROM CAD.Pessoa_Contato c WHERE c.ID_PESSOA = p.ID_PESSOA AND c.TIPO <> 'EMAIL') THEN 1 ELSE 0 END AS TELEFONE) f
    WHERE p.CODIGO_ACCESS IS NOT NULL;

    /* 3. Empresas */
    SELECT e.ID_EMPRESA, e.CODIGO_ACCESS, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.TIPO, e.REGIME_TRIBUTARIO,
           SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ, 0) AS CNPJ, SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ_COMPRAS, 0) AS CNPJ_NOTAS_COMPRA_DDA,
           ISNULL(k.DESCRICAO, N'') AS CONTA_PADRAO, e.ATIVO
    FROM CAD.Empresa e WITH (NOLOCK)
    LEFT JOIN BANCO.Conta k WITH (NOLOCK) ON k.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
    WHERE e.CODIGO_ACCESS IS NOT NULL
    ORDER BY CASE e.TIPO WHEN 'CONSTRUTORA' THEN 1 WHEN 'HOLDING' THEN 2 ELSE 3 END, e.NOME_FANTASIA;

    /* 4. Contas */
    SELECT ISNULL(e.NOME_FANTASIA, N'') AS EMPRESA, c.DESCRICAO, c.TIPO, ISNULL(b.CODIGO + N' ' + b.NOME, N'') AS BANCO,
           c.AGENCIA, c.NUMERO + CASE WHEN c.NUMERO_DV <> '' THEN '-' + c.NUMERO_DV ELSE '' END AS CONTA,
           c.CONCILIA, c.ATIVO, c.CODIGO_ACCESS,
           (SELECT COUNT(*) FROM #Uso u WHERE u.CONTA = c.CODIGO_ACCESS) AS LINHAS_DESDE_O_CORTE
    FROM BANCO.Conta c WITH (NOLOCK)
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
    LEFT JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = c.ID_BANCO
    WHERE e.CODIGO_ACCESS IS NOT NULL
    ORDER BY c.ATIVO DESC, e.NOME_FANTASIA, c.DESCRICAO;

    /* 5. Centros de custo */
    SELECT c.CODIGO, c.DESCRICAO, c.TIPO, e.NOME_FANTASIA AS EMPRESA, c.CONTABIL, c.ATIVO,
           ISNULL(k.DESCRICAO, N'') AS CONTA_PADRAO, ISNULL(p.NOME, N'') AS CLIENTE_ADMINISTRACAO, ISNULL(d.PERCENTUAL_ADM, 0) AS PERCENTUAL_ADM,
           c.CODIGO_ACCESS, ISNULL(v.NomeVinculada, N'') AS NOME_NO_ACCESS, ISNULL(d.CLASSIF_AUTOMATICA, 0) AS CLASSIF_AUTOMATICA,
           (SELECT COUNT(*) FROM #Uso u WHERE u.EMP_VINCULADA = c.CODIGO_ACCESS) AS LINHAS_DESDE_O_CORTE
    FROM CAD.Centro_Custo c WITH (NOLOCK)
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
    LEFT JOIN MIG.DePara_Centro d ON d.ID_CENTRO_CUSTO = c.ID_CENTRO_CUSTO
    LEFT JOIN CAD.Pessoa p WITH (NOLOCK) ON p.ID_PESSOA = d.ID_PESSOA_CLIENTE
    LEFT JOIN BANCO.Conta k WITH (NOLOCK) ON k.ID_CONTA = c.ID_CONTA_BANCARIA_PADRAO
    LEFT JOIN MIG.Access_EmpVinculada v ON TRY_CONVERT(INT, v.CodigoVinculada) = c.CODIGO_ACCESS
    WHERE c.CODIGO_ACCESS IS NOT NULL OR EXISTS (SELECT 1 FROM MIG.Classif_Centro_Extra x WHERE x.CODIGO = c.CODIGO)
    ORDER BY c.ATIVO DESC, e.NOME_FANTASIA, c.CODIGO;

    /* 6. Plano: de-para das contas usadas desde o corte */
    SELECT d.PLANO3_ACCESS,
           LTRIM(RTRIM(ISNULL(p1.DescricaoPlano1, N''))) + N' > ' + LTRIM(RTRIM(ISNULL(p2.DescricaoPlano2, N''))) + N' > ' + LTRIM(RTRIM(ISNULL(p3.DescricaoPlano3, N''))) AS NO_ACCESS,
           v.CODIGO AS CODIGO_NOVO, v.GRUPO_DESCRICAO + N' > ' + v.SUBGRUPO_DESCRICAO + N' > ' + v.DESCRICAO AS NO_SISTEMA_NOVO,
           ISNULL(cc.CODIGO + N' - ' + cc.DESCRICAO, N'') AS CENTRO_DO_IMOVEL, d.REGRA, v.ATIVO_EFETIVO AS ATIVA,
           (SELECT COUNT(*) FROM #Uso u WHERE u.PLANO3 = d.PLANO3_ACCESS) AS LINHAS_DESDE_O_CORTE
    FROM MIG.DePara_Plano d
    INNER JOIN CAD.Plano_Conta k WITH (NOLOCK) ON k.ID_PLANO_CONTA = d.ID_PLANO_CONTA
    INNER JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = d.ID_PLANO_CONTA
    LEFT JOIN CAD.Centro_Custo cc WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = d.ID_CENTRO_CUSTO
    LEFT JOIN MIG.Access_Plano3 p3 ON TRY_CONVERT(INT, p3.Plano3) = d.PLANO3_ACCESS
    LEFT JOIN MIG.Access_Plano2 p2 ON p2.Plano2 = p3.Plano2
    LEFT JOIN MIG.Access_Plano1 p1 ON p1.Plano1 = p2.Plano1
    WHERE EXISTS (SELECT 1 FROM #Uso u WHERE u.PLANO3 = d.PLANO3_ACCESS)
    ORDER BY v.ORDEM_ARVORE, d.PLANO3_ACCESS;

    DROP TABLE IF EXISTS #Uso;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/Carga_MIG_Classificacao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Carga       : classificação dos cadastros do Access (schema MIG)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Decisões da migração dos cadastros (etapa 03c2), conferidas
                pela CMJ nos documentos de perguntas de 17/11/2026
                (docs/requisitos/Migracao_Movimento.md, seção 8, e
                docs/requisitos/Migracao_Cadastros.md). Este arquivo é a fonte
                das decisões: rodar de novo aplica as correções (MERGE).
                O que não está aqui segue a regra automática do
                MIG.MIG_Cadastros_Processar e aparece na conferência.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c2).
    v1.1 (22/11/2026) - 03f: respostas da CMJ ao 3º documento
                        (docs/requisitos/Migracao_Cadastros.md, seção 6):
                        CNPJ e razão social das 4 SPEs; conta padrão da Holding
                        = Sicredi Holding; Casa Danielle e Casa 66 passam para a
                        Holding; La Sante Sala 110, Allegro 52 e Giuseppina 12
                        inativos (vendidos), Sala 113 ativa até a CMJ confirmar;
                        grupos 11 a 14 entram no custo de obra.
    v1.2 (23/11/2026) - Respostas da Renata à conferência 03f: Sala 113
                        vendida (centro inativo); a vaga vendida junto é a
                        15 (o Access dizia vaga 40; confirmado pelo Celso).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- -----------------------------------------------------------------------------
-- 1. Empresas (EmpMaster)
--    EMPRESA     = empresa do grupo (CAD.Empresa)
--    CONSTRUTORA = não é empresa do grupo (cliente de obra por administração,
--                  particular, estudo): as obras dela ficam na empresa principal
--    NAO_MIGRA   = registros de sistema do Access
-- -----------------------------------------------------------------------------
MERGE MIG.Classif_Empresa AS d
USING (VALUES
    ( 1, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'Master: registro do Access'),
    ( 2, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'sistema'),
    ( 3, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'sistema'),
    ( 4, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'sistema'),
    ( 5, 'NAO_MIGRA',   0, 'OUTRA',       N'', N'', '', '', '', N'sistema'),
    ( 6, 'EMPRESA',     1, 'CONSTRUTORA', N'Construtora Marcilio Judice Sociedade Empresária Ltda', N'Construtora Marcilio Judice', '25686528000197', '', '', N''),
    (21, 'EMPRESA',     0, 'SPE',         N'Ilha das Gales Incorporadora SPE Ltda',     N'Ilha das Galès',          '18757133000172', '', 'RET', N'CNPJ e razão social: CMJ, 20/11/2026'),
    (22, 'EMPRESA',     0, 'SPE',         N'Edifício Comercial La Sante SPE',           N'La Sante',                '21126427000100', '', 'RET', N'CNPJ e razão social: CMJ, 20/11/2026'),
    (23, 'EMPRESA',     0, 'SPE',         N'Judice e Daher Incorporadora e Construtora SPE Ltda', N'Villagio Allegro', '23465751000189', '', 'RET', N'CNPJ e razão social: CMJ, 20/11/2026'),
    (25, 'EMPRESA',     0, 'HOLDING',     N'Judice e Filhos Administração de Bens Ltda', N'Holding Judice e Filhos', '27546995000147', '', '', N''),
    (28, 'EMPRESA',     0, 'SPE',         N'MJ Incorporadora SPE Ltda',                 N'Res. Square',             '34939234000110', '', 'RET', N'CNPJ e razão social: CMJ, 20/11/2026'),
    (31, 'EMPRESA',     0, 'SPE',         N'Marcilio Judice Incorporadora SPE Ltda',    N'Maui',                    '36451082000138', '', 'RET', N''),
    (32, 'EMPRESA',     0, 'SPE',         N'Orion Incorporadora SPE Ltda',              N'Orion',                   '52095394000102', '', '', N'ainda sem RET'),
    (34, 'EMPRESA',     0, 'SPE',         N'Opera Residences',                          N'Opera',                   '56304064000130', '56304064000211', 'RET', N'razão social completa a confirmar; /0002-11 = CNPJ do RET (notas de compra e DDA)'),
    (35, 'EMPRESA',     0, 'SPE',         N'Music Incorporadora SPE Ltda',              N'Music',                   '68542803000101', '', '', N'ainda sem RET'),
    ( 7, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Climepe: cliente de obra por administração'),
    ( 8, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Adm. Bens Claudia: cliente de obra por administração'),
    ( 9, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Cond. Res. Vila Faria Lobato: obra a preço de custo'),
    (10, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Residencial Buenos Aires: obra a preço de custo'),
    (11, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Bolivar Zotti: cliente de obra por administração'),
    (12, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Construtora Epura: cliente de obra por administração'),
    (13, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'DMAE: cliente'),
    (14, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Fundação Jd. Botânico: cliente'),
    (15, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Cond. Res. Justino Ribeiro: cliente'),
    (16, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Carneiro Casa & Construção (reforma): cliente'),
    (17, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Residencial Giuseppina: obra a preço de custo (associação)'),
    (18, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Residencial Attualità: obra a preço de custo (associação)'),
    (19, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Luiz Henrique Costa da Cunha: cliente'),
    (20, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Carneiro Casa & Construção Ltda: cliente'),
    (24, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Adriana Granato: cliente (reforma do hotel)'),
    (26, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Res. Trix - Jd. Elvira Dias'),
    (27, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Empreendimento Country Club'),
    (29, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Novo Empreendimento Claudia Carneiro (Res. Mellia)'),
    (30, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'CADAP: cliente das obras por administração Indiara e Paladium (CMJ, 17/11/2026)'),
    (33, 'CONSTRUTORA', 0, 'OUTRA', N'', N'', '', '', '', N'Ronaldo Dellaroli: estudo de viabilidade, obra não executada (CMJ, 17/11/2026)')
) AS s (CODIGO_MASTER, DESTINO, PRINCIPAL, TIPO, RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, REGIME_TRIBUTARIO, OBSERVACAO)
ON d.CODIGO_MASTER = s.CODIGO_MASTER
WHEN MATCHED THEN UPDATE SET d.DESTINO = s.DESTINO, d.PRINCIPAL = s.PRINCIPAL, d.TIPO = s.TIPO, d.RAZAO_SOCIAL = s.RAZAO_SOCIAL,
     d.NOME_FANTASIA = s.NOME_FANTASIA, d.CNPJ = s.CNPJ, d.CNPJ_COMPRAS = s.CNPJ_COMPRAS, d.REGIME_TRIBUTARIO = s.REGIME_TRIBUTARIO, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (CODIGO_MASTER, DESTINO, PRINCIPAL, TIPO, RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, REGIME_TRIBUTARIO, OBSERVACAO)
     VALUES (s.CODIGO_MASTER, s.DESTINO, s.PRINCIPAL, s.TIPO, s.RAZAO_SOCIAL, s.NOME_FANTASIA, s.CNPJ, s.CNPJ_COMPRAS, s.REGIME_TRIBUTARIO, s.OBSERVACAO);
GO

-- -----------------------------------------------------------------------------
-- 2. Centros de custo (EmpVinculada). Campos vazios seguem a regra automática:
--    código "A" + código do Access, descrição do Access, tipo OBRA quando a
--    obra controla custo, é administração ou tem imóvel à venda.
-- -----------------------------------------------------------------------------
MERGE MIG.Classif_Centro AS d
USING (VALUES
    ( 1, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'N/A: caixinha e contrapartida do Access (cada lançamento recebe o centro pela regra do seu tipo)'),
    ( 2, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'Escolha a Empresa (sistema)'),
    ( 3, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'sistema'),
    ( 4, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'sistema'),
    ( 5, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'sistema'),
    (70, 'NAO_MIGRA', '',             N'',                                                 '',               NULL, NULL, NULL, N'TESTE'),
    ( 6, 'CENTRO',    'CMJ',          N'Construtora - administrativo',                     'ADMINISTRATIVO', NULL, NULL, NULL, N''),
    ( 9, 'CENTRO',    'PART-FAMILIA', N'Despesas particulares da família',                 'PARTICULAR',     6,    NULL, NULL, N'"Marco Aurelio" no Access (CMJ, 17/11/2026)'),
    (46, 'CENTRO',    '58',           N'58 - Ilha das Galès',                              'OBRA',           NULL, NULL, NULL, N''),
    (49, 'CENTRO',    '59',           N'59 - Edifício La Sante',                           'OBRA',           NULL, NULL, NULL, N''),
    (54, 'CENTRO',    '59-ANTES-SPE', N'La Sante - antes da SPE (conta 01321-7)',          'OBRA',           6,    NULL, NULL, N'controle da obra La Sante até sair a documentação da SPE (CMJ, 17/11/2026)'),
    (57, 'CENTRO',    '61',           N'61 - Villagio Allegro',                            'OBRA',           NULL, NULL, NULL, N''),
    (60, 'CENTRO',    'JD-CAROLINA',  N'Jd. Carolina - obra particular dos proprietários', 'PARTICULAR',     6,    NULL, NULL, N'CMJ, 17/11/2026'),
    (62, 'CENTRO',    'HOLDING',      N'Holding - administrativo',                         'ADMINISTRATIVO', NULL, NULL, 28  , N'conta padrão Sicredi Holding 0217/28656-3 (CMJ, 20/11/2026)'),
    (65, 'CENTRO',    '62',           N'62 - Res. Square',                                 'OBRA',           NULL, NULL, NULL, N''),
    (69, 'CENTRO',    '65',           N'65 - Res. Indiara (CADAP)',                        'OBRA',           6,    1029, NULL, N'obra por administração; cliente CADAP (CMJ, 17/11/2026)'),
    (72, 'CENTRO',    '63',           N'63 - Maui',                                        'OBRA',           NULL, NULL, NULL, N''),
    (73, 'CENTRO',    '66',           N'66 - Res. Paladium (CADAP)',                       'OBRA',           6,    1195, NULL, N'obra por administração; cliente CADAP (CMJ, 17/11/2026)'),
    (75, 'CENTRO',    '67',           N'67 - Orion',                                       'OBRA',           NULL, NULL, NULL, N''),
    (76, 'CENTRO',    'DELLAROLI',    N'Ronaldo Dellaroli - estudo de viabilidade',        'ADMINISTRATIVO', 6,    NULL, NULL, N'obra não executada (CMJ, 17/11/2026)'),
    (77, 'CENTRO',    '68',           N'68 - Opera Residences',                            'OBRA',           NULL, NULL, NULL, N''),
    (43, 'CENTRO',    '55',           N'55 - Residencial Attualità',                       'OBRA',           6,    NULL, NULL, N'obra a preço de custo (associação); 1 lançamento desde o corte'),
    (78, 'CENTRO',    '69',           N'69 - Music',                                       'OBRA',           NULL, NULL, NULL, N''),
    -- obras antigas por administração: só o cliente (o resto pela regra automática)
    (14, 'CENTRO',    '',             N'',                                                 '',               NULL, 880, NULL, N'cliente Climepe'),
    (15, 'CENTRO',    '',             N'',                                                 '',               NULL, 880, NULL, N'cliente Climepe'),
    (16, 'CENTRO',    '',             N'',                                                 '',               NULL, 623, NULL, N'cliente Adm. de Bens Claudia'),
    (22, 'CENTRO',    '',             N'',                                                 '',               NULL, 40, NULL, N'cliente DMAE'),
    (52, 'CENTRO',    '',             N'',                                                 '',               NULL, 633, NULL, N'cliente DMAE - ETA V'),
    (30, 'CENTRO',    '',             N'',                                                 '',               NULL, 607, NULL, N'cliente Cond. Res. Justino Ribeiro'),
    (35, 'CENTRO',    '',             N'',                                                 '',               NULL, 190, NULL, N'cliente Carneiro Casa & Construção'),
    (50, 'CENTRO',    '',             N'',                                                 '',               NULL, 586, NULL, N'cliente Carneiro Casa & Construção - Loja Nova'),
    (55, 'CENTRO',    '',             N'',                                                 '',               NULL, 902, NULL, N'cliente Hotel Granato')
) AS s (CODIGO_VINCULADA, DESTINO, CODIGO, DESCRICAO, TIPO, CODIGO_MASTER_EMPRESA, PARCEIRO_CLIENTE, CODIGO_CONTA_PADRAO, OBSERVACAO)
ON d.CODIGO_VINCULADA = s.CODIGO_VINCULADA
WHEN MATCHED THEN UPDATE SET d.DESTINO = s.DESTINO, d.CODIGO = s.CODIGO, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO,
     d.CODIGO_MASTER_EMPRESA = s.CODIGO_MASTER_EMPRESA, d.PARCEIRO_CLIENTE = s.PARCEIRO_CLIENTE, d.CODIGO_CONTA_PADRAO = s.CODIGO_CONTA_PADRAO, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (CODIGO_VINCULADA, DESTINO, CODIGO, DESCRICAO, TIPO, CODIGO_MASTER_EMPRESA, PARCEIRO_CLIENTE, CODIGO_CONTA_PADRAO, OBSERVACAO)
     VALUES (s.CODIGO_VINCULADA, s.DESTINO, s.CODIGO, s.DESCRICAO, s.TIPO, s.CODIGO_MASTER_EMPRESA, s.PARCEIRO_CLIENTE, s.CODIGO_CONTA_PADRAO, s.OBSERVACAO);
GO

-- -----------------------------------------------------------------------------
-- 3. Centros que não existem no Access: imóveis próprios e particulares que lá
--    eram contas do plano (decisão do plano de contas, 16/11/2026: conta
--    genérica + imóvel pelo centro de custo). Dona: a empresa que lança.
-- -----------------------------------------------------------------------------
MERGE MIG.Classif_Centro_Extra AS d
USING (VALUES
    ('IMO-LS-110',   N'La Sante - Sala 110 e vaga 9',           'IMOVEL_PROPRIO', 25, 0   , N'contas antigas 460 e 670 (aluguel); vendida (CMJ, 20/11/2026)'),
    ('IMO-LS-112',   N'La Sante - Sala 112 e vaga 10',          'IMOVEL_PROPRIO', 25, NULL, N'conta antiga 461; alugada pela Construtora (CMJ, 20/11/2026)'),
    ('IMO-LS-113',   N'La Sante - Sala 113 e vaga 15',          'IMOVEL_PROPRIO', 25, 0   , N'conta antiga 462 (no Access: vaga 40); vendida com a vaga 15 (CMJ, 23/11/2026)'),
    ('IMO-LS-VAGAS', N'La Sante - Vagas de estacionamento',     'IMOVEL_PROPRIO', 25, NULL, N'conta antiga 463'),
    ('IMO-ALG-13',   N'Allegro - Apto. 13',                     'IMOVEL_PROPRIO', 25, NULL, N'contas antigas 506 e 692 (aluguel)'),
    ('IMO-ALG-52',   N'Allegro - Apto. 52',                     'IMOVEL_PROPRIO', 25, 0   , N'conta antiga 507; vendido (CMJ, 20/11/2026)'),
    ('IMO-GIU-12',   N'Giuseppina - Apto. 12',                  'IMOVEL_PROPRIO',  6, 0   , N'conta antiga 669 (aluguel); vendido (CMJ, 20/11/2026)'),
    ('PART-CASA-DAN',N'Casa Danielle',                          'PARTICULAR', 25, NULL, N'conta antiga 381; dona: Holding (CMJ, 20/11/2026)'),
    ('PART-CASA-66', N'Casa 66 - Marco Bosque Araucárias',      'PARTICULAR', 25, NULL, N'conta antiga 465; dona: Holding (CMJ, 20/11/2026)')
) AS s (CODIGO, DESCRICAO, TIPO, CODIGO_MASTER_EMPRESA, ATIVO, OBSERVACAO)
ON d.CODIGO = s.CODIGO
WHEN MATCHED THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CODIGO_MASTER_EMPRESA = s.CODIGO_MASTER_EMPRESA, d.ATIVO = s.ATIVO, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (CODIGO, DESCRICAO, TIPO, CODIGO_MASTER_EMPRESA, ATIVO, OBSERVACAO)
     VALUES (s.CODIGO, s.DESCRICAO, s.TIPO, s.CODIGO_MASTER_EMPRESA, s.ATIVO, s.OBSERVACAO);
GO

-- -----------------------------------------------------------------------------
-- 4. Contas (F Contas Financeiras). Dona = empresa que mais usa a conta no
--    Access. Contas de clientes de obra antiga ficam na Construtora (inativas).
--    Itaú: agência 0267 (observação das contas no Access).
-- -----------------------------------------------------------------------------
MERGE MIG.Classif_Conta AS d
USING (VALUES
    ( 1, 'NAO_MIGRA', NULL, N'',                      '',         NULL,  '',     '',      '',  N'Créditos: conta de sistema (contrapartida)'),
    ( 2, 'NAO_MIGRA', NULL, N'',                      '',         NULL,  '',     '',      '',  N'Débitos: conta de sistema (contrapartida)'),
    ( 3, 'NAO_MIGRA', NULL, N'',                      '',         NULL,  '',     '',      '',  N'Pagto em Lote: conta de sistema'),
    ( 9, 'NAO_MIGRA', NULL, N'',                      '',         NULL,  '',     '',      '',  N'N/A: caixinha (vira o Caixa de cada empresa na transformação)'),
    ( 4, 'CONTA',  6, N'Itaú Construtora',            'CORRENTE', '341', '0267', '25629', '5', N''),
    ( 5, 'CONTA',  6, N'Itaú Faria Lobato',           'CORRENTE', '341', '0267', '58051', '2', N'obra a preço de custo (Vila Faria Lobato)'),
    ( 6, 'CONTA',  6, N'Itaú Buenos Aires',           'CORRENTE', '341', '0267', '65086', '3', N'obra a preço de custo (Buenos Aires)'),
    ( 7, 'CONTA',  6, N'Caixa Buenos Aires',          'CAIXA',    NULL,  '',     '',      '',  N'obra a preço de custo (Buenos Aires)'),
    (10, 'CONTA',  6, N'Caixa Construtora',           'CAIXA',    NULL,  '',     '',      '',  N''),
    (11, 'CONTA',  6, N'Permuta',                     'PERMUTA',  NULL,  '',     '',      '',  N'usada por várias empresas no Access'),
    (12, 'CONTA',  6, N'Itaú Construtora 2',          'CORRENTE', '341', '0267', '01321', '7', N'conta da obra La Sante antes da SPE'),
    (13, 'CONTA',  6, N'Itaú Giuseppina',             'CORRENTE', '341', '0267', '02005', '5', N'Associação Pró-construção do Ed. Res. Giuseppina'),
    (14, 'CONTA',  6, N'Itaú Attualità',              'CORRENTE', '341', '0267', '03877', '9', N'Associação Pró-construção do Ed. Res. Attualità'),
    (15, 'CONTA', 21, N'Itaú Ilha das Galès',         'CORRENTE', '341', '0267', '07284', '1', N''),
    (16, 'CONTA', 22, N'Itaú La Sante',               'CORRENTE', '341', '0267', '10556', '7', N''),
    (18, 'CONTA', 23, N'Itaú Allegro',                'CORRENTE', '341', '0267', '13861', '8', N''),
    (19, 'CONTA', 28, N'Itaú Square',                 'CORRENTE', '341', '0267', '28450', '3', N''),
    (20, 'CONTA', 31, N'Itaú Maui',                   'CORRENTE', '341', '0267', '28906', '4', N''),
    (21, 'CONTA', 32, N'Sicredi Orion',               'CORRENTE', '748', '0217', '73623', '5', N'cobrança: posto 55, beneficiário 55.73623'),
    (22, 'CONTA', 32, N'Caixa Orion',                 'CAIXA',    NULL,  '',     '',      '',  N''),
    (23, 'CONTA', 34, N'Sicredi Opera',               'CORRENTE', '748', '0217', '77315', '4', N'cobrança: posto 55, beneficiário 55.77315'),
    (24, 'CONTA', 34, N'Caixa Opera',                 'CAIXA',    NULL,  '',     '',      '',  N''),
    (25, 'CONTA', 31, N'Caixa Maui',                  'CAIXA',    NULL,  '',     '',      '',  N''),
    (26, 'CONTA',  6, N'Sicredi Construtora',         'CORRENTE', '748', '0217', '74953', '7', N''),
    (27, 'CONTA', 25, N'Caixa Holding',               'CAIXA',    NULL,  '',     '',      '',  N''),
    (28, 'CONTA', 25, N'Sicredi Holding',             'CORRENTE', '748', '0217', '28656', '3', N''),
    (29, 'CONTA', 35, N'Sicredi Music',               'CORRENTE', '748', '0217', '94652', '1', N'cobrança: posto 55, beneficiário 55.94652')
) AS s (CODIGO_CONTA, DESTINO, CODIGO_MASTER_EMPRESA, DESCRICAO, TIPO, BANCO_CODIGO, AGENCIA, NUMERO, NUMERO_DV, OBSERVACAO)
ON d.CODIGO_CONTA = s.CODIGO_CONTA
WHEN MATCHED THEN UPDATE SET d.DESTINO = s.DESTINO, d.CODIGO_MASTER_EMPRESA = s.CODIGO_MASTER_EMPRESA, d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO,
     d.BANCO_CODIGO = s.BANCO_CODIGO, d.AGENCIA = s.AGENCIA, d.NUMERO = s.NUMERO, d.NUMERO_DV = s.NUMERO_DV, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (CODIGO_CONTA, DESTINO, CODIGO_MASTER_EMPRESA, DESCRICAO, TIPO, BANCO_CODIGO, AGENCIA, NUMERO, NUMERO_DV, OBSERVACAO)
     VALUES (s.CODIGO_CONTA, s.DESTINO, s.CODIGO_MASTER_EMPRESA, s.DESCRICAO, s.TIPO, s.BANCO_CODIGO, s.AGENCIA, s.NUMERO, s.NUMERO_DV, s.OBSERVACAO);
GO

-- -----------------------------------------------------------------------------
-- 5. Grupos do plano de contas. 00 a 18: plano novo do Access (número tirado do
--    nome); 20 e 21: grupos novos aprovados em 16/11/2026; 90 a 92: plano
--    antigo como histórico inativo (só consulta). CUSTO_OBRA = entra no custo
--    da obra e no painel (proposta, a CMJ confere; muda pela tela).
-- -----------------------------------------------------------------------------
MERGE MIG.Config_Plano_Grupo AS d
USING (VALUES
    ( 0, N'Permutas',                              'DESPESA',         1, 1, NULL),
    ( 1, N'Mão de obra',                           'DESPESA',         1, 1, NULL),
    ( 2, N'Despesas administrativas gerais',       'DESPESA',         0, 1, NULL),
    ( 3, N'Encargos sociais',                      'DESPESA',         1, 1, NULL),
    ( 4, N'Equipamentos',                          'DESPESA',         1, 1, NULL),
    ( 5, N'Empreitas',                             'DESPESA',         1, 1, NULL),
    ( 6, N'Fundação e estrutura',                  'DESPESA',         1, 1, NULL),
    ( 7, N'Segurança do trabalho',                 'DESPESA',         1, 1, NULL),
    ( 8, N'Vedação e massa',                       'DESPESA',         1, 1, NULL),
    ( 9, N'Acabamentos',                           'DESPESA',         1, 1, NULL),
    (10, N'Projetos',                              'DESPESA',         1, 1, NULL),
    (11, N'Despesas de vendas',                    'DESPESA',         1, 1, NULL),
    (12, N'Impostos e taxas municipais',           'DESPESA',         1, 1, NULL),
    (13, N'Impostos e taxas estaduais',            'DESPESA',         1, 1, NULL),
    (14, N'Impostos e taxas federais',             'DESPESA',         1, 1, NULL),
    (15, N'Cartórios',                             'DESPESA',         1, 1, NULL),
    (16, N'Canteiro de obras',                     'DESPESA',         1, 1, NULL),
    (17, N'Reembolsos e acertos',                  'DESPESA',         0, 1, NULL),
    (18, N'Medidas compensatórias',                'DESPESA',         1, 1, NULL),
    (20, N'Receitas',                              'RECEITA',         0, 1, NULL),
    (21, N'Não operacional',                       'NAO_OPERACIONAL', 0, 1, NULL),
    (90, N'Receitas (plano antigo)',               'RECEITA',         0, 0, 4),
    (91, N'Despesas (plano antigo)',               'DESPESA',         0, 0, 5),
    (92, N'Distribuição de lucros (plano antigo)', 'NAO_OPERACIONAL', 0, 0, 6)
) AS s (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ATIVO, PLANO1_ACCESS)
ON d.NUMERO = s.NUMERO
WHEN MATCHED THEN UPDATE SET d.DESCRICAO = s.DESCRICAO, d.TIPO = s.TIPO, d.CUSTO_OBRA = s.CUSTO_OBRA, d.ATIVO = s.ATIVO, d.PLANO1_ACCESS = s.PLANO1_ACCESS
WHEN NOT MATCHED THEN INSERT (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ATIVO, PLANO1_ACCESS)
     VALUES (s.NUMERO, s.DESCRICAO, s.TIPO, s.CUSTO_OBRA, s.ATIVO, s.PLANO1_ACCESS);
GO

-- -----------------------------------------------------------------------------
-- 6. Contas do plano que mudam de lugar (aprovado pela CMJ em 17/11/2026:
--    receitas e despesas do plano antigo usadas desde 2022 ganham de-para;
--    não operacional tirado de receita e de despesa administrativa).
--    ALVO_PLANO3_ACCESS = vai para a conta do plano novo que veio daquele
--    Plano3; senão, para a conta grupo.subgrupo.conta informada.
-- -----------------------------------------------------------------------------
MERGE MIG.DePara_Plano_Excecao AS d
USING (VALUES
    -- receitas (grupo 20)
    ( 41, NULL, 20, 1, N'Vendas',                 1, N'Venda de imóveis',                      NULL,            N'Venda Imoveis'),
    (410, NULL, 20, 1, N'Vendas',                 2, N'Permutas recebidas',                    NULL,            N'Permuta'),
    ( 43, NULL, 20, 1, N'Vendas',                 3, N'Outras vendas',                         NULL,            N'Outras Vendas'),
    (453, NULL, 20, 1, N'Vendas',                 4, N'Juros e multas recebidos',              NULL,            N'Juros e Multas'),
    ( 31, NULL, 20, 2, N'Administração',          1, N'Taxa de administração de obras',        NULL,            N'Administracao Obras'),
    ( 28, NULL, 20, 2, N'Administração',          2, N'Administração de condomínios',          NULL,            N'Administracao Condominios'),
    (669, NULL, 20, 3, N'Aluguéis',               1, N'Aluguéis recebidos',                    'IMO-GIU-12',    N'Aluguel - Giuseppina apto. 12'),
    (670, NULL, 20, 3, N'Aluguéis',               1, N'Aluguéis recebidos',                    'IMO-LS-110',    N'Aluguel Sala 110 La Sante'),
    (692, NULL, 20, 3, N'Aluguéis',               1, N'Aluguéis recebidos',                    'IMO-ALG-13',    N'Aluguel - Allegro apto. 13'),
    (127, NULL, 20, 4, N'Outras receitas',        1, N'Rendimentos de aplicações',             NULL,            N'Rendimento Autom.'),
    (679, NULL, 20, 4, N'Outras receitas',        2, N'Reembolsos recebidos',                  NULL,            N'Reembolsos'),
    ( 47, NULL, 20, 4, N'Outras receitas',        3, N'Outras receitas',                       NULL,            N'Outros Diversos'),
    -- não operacional (grupo 21)
    (705, NULL, 21, 1, N'Entradas',               1, N'Empréstimos recebidos',                 NULL,            N'Empréstimo (estava em receitas)'),
    (665, NULL, 21, 1, N'Entradas',               2, N'Lucros recebidos de participações',     NULL,            N'Distribuição de Lucros (estava em receitas)'),
    (704, NULL, 21, 2, N'Saídas',                 1, N'Amortização de empréstimos',            NULL,            N'2.1.9 - Amortizações'),
    (713, NULL, 21, 2, N'Saídas',                 2, N'Juros de empréstimos e financiamentos', NULL,            N'2.1.10 - Juros Senior'),
    (714, NULL, 21, 2, N'Saídas',                 2, N'Juros de empréstimos e financiamentos', NULL,            N'2.1.11 - Juros Subordinada'),
    (575, NULL, 21, 2, N'Saídas',                 3, N'Distribuição de lucros',                NULL,            N'2.1.4 - Distribuição Lucros'),
    ( 90, NULL, 21, 2, N'Saídas',                 4, N'Despesas particulares dos sócios',      NULL,            N'Despesas Particulares - Despesas Diversas'),
    (381, NULL, 21, 2, N'Saídas',                 4, N'Despesas particulares dos sócios',      'PART-CASA-DAN', N'Bens Imóveis - Casa Danielle'),
    (465, NULL, 21, 2, N'Saídas',                 4, N'Despesas particulares dos sócios',      'PART-CASA-66',  N'Bens Imóveis - Casa 66'),
    -- imóveis próprios (grupo 02, subgrupo novo 3)
    (460, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-LS-110',    N'Bens Imóveis - La Sante Sala 110 e Vaga 9'),
    (461, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-LS-112',    N'Bens Imóveis - La Sante Sala 112 e Vaga 10'),
    (462, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-LS-113',    N'Bens Imóveis - La Sante Sala 113 e Vaga 40'),
    (463, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-LS-VAGAS',  N'Bens Imóveis - La Sante Vagas'),
    (506, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-ALG-13',    N'Bens Imóveis - Apto. 13 Allegro'),
    (507, NULL,  2, 3, N'Imóveis próprios',       1, N'Despesas de imóveis próprios',          'IMO-ALG-52',    N'Bens Imóveis - Apto. 52 Allegro'),
    -- despesas do plano antigo para contas que já existem no plano novo
    (221, 521,  NULL, NULL, N'', NULL, N'', NULL, N'Pró-Labore -> 2.1.2 Pro Labore'),
    ( 72, 522,  NULL, NULL, N'', NULL, N'', NULL, N'Telefone -> 2.1.3 Desp. Fixas'),
    ( 75, 522,  NULL, NULL, N'', NULL, N'', NULL, N'Internet e Informatica -> 2.1.3 Desp. Fixas'),
    (498, 532,  NULL, NULL, N'', NULL, N'', NULL, N'INSS PRO LABORE -> 3.1.4 INSS Pro Labore'),
    ( 97, 613,  NULL, NULL, N'', NULL, N'', NULL, N'ISSQN de terceiros -> 12.1.2 ISSQN'),
    (362, 625,  NULL, NULL, N'', NULL, N'', NULL, N'RET (plano antigo) -> 14.1.1 RET'),
    (499, 531,  NULL, NULL, N'', NULL, N'', NULL, N'Contrib. Previdenciária - Desoneração (CPRB, plano antigo) -> 3.1.3 INSS: a CMJ confere')
) AS s (PLANO3_ACCESS, ALVO_PLANO3_ACCESS, GRUPO_NUMERO, SUBGRUPO_NUMERO, SUBGRUPO_DESCRICAO, CONTA_NUMERO, CONTA_DESCRICAO, CENTRO_CODIGO, OBSERVACAO)
ON d.PLANO3_ACCESS = s.PLANO3_ACCESS
WHEN MATCHED THEN UPDATE SET d.ALVO_PLANO3_ACCESS = s.ALVO_PLANO3_ACCESS, d.GRUPO_NUMERO = s.GRUPO_NUMERO, d.SUBGRUPO_NUMERO = s.SUBGRUPO_NUMERO,
     d.SUBGRUPO_DESCRICAO = s.SUBGRUPO_DESCRICAO, d.CONTA_NUMERO = s.CONTA_NUMERO, d.CONTA_DESCRICAO = s.CONTA_DESCRICAO,
     d.CENTRO_CODIGO = s.CENTRO_CODIGO, d.OBSERVACAO = s.OBSERVACAO
WHEN NOT MATCHED THEN INSERT (PLANO3_ACCESS, ALVO_PLANO3_ACCESS, GRUPO_NUMERO, SUBGRUPO_NUMERO, SUBGRUPO_DESCRICAO, CONTA_NUMERO, CONTA_DESCRICAO, CENTRO_CODIGO, OBSERVACAO)
     VALUES (s.PLANO3_ACCESS, s.ALVO_PLANO3_ACCESS, s.GRUPO_NUMERO, s.SUBGRUPO_NUMERO, s.SUBGRUPO_DESCRICAO, s.CONTA_NUMERO, s.CONTA_DESCRICAO, s.CENTRO_CODIGO, s.OBSERVACAO);
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.Tabelas_Transformacao.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : tabelas da transformação do movimento (schema MIG)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Etapa 03c2, parte B.
                MIG.Caso                 documentos do Access (unidades: lote,
                                         venda ou avulso) que não se encaixam em
                                         nenhuma regra, mais os que já têm
                                         correção da tela (REGRA_ATUAL mostra
                                         como ficaram; MOTIVO_ORIGINAL guarda o
                                         motivo da primeira vez). Atualizada a
                                         cada rodada.
                MIG.Caso_Correcao        decisão por documento, gravada pela
                                         tela de casos: IGNORAR (não migra),
                                         ARQUIVO_MORTO (vai para o arquivo morto)
                                         ou ABATER (o documento é um "crédito"
                                         manual que abate a parcela da venda
                                         LINK_VENDA_DESTINO: vira baixa só de
                                         abatimento, sem dinheiro).
                MIG.Caso_Correcao_Linha  correção por linha do Access (obra,
                                         pessoa, conta, plano, datas, valores,
                                         confirmado, ignorar a linha), aplicada a
                                         cada rodada antes da classificação.
                MIG.Linha_Destino        para cada linha do Access, o que ela
                                         virou no sistema novo (conferência).
                MIG.DePara_Venda         parcelas de venda: ligação com o imóvel
                                         e o contrato do Access (fase 5).
                As correções ficam guardadas pelo código do Access (origem +
                número), então valem em toda nova rodada até a virada.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
    v1.1 (18/11/2026) - Tela de casos: MIG.Caso ganha REGRA_ATUAL e
                        MOTIVO_ORIGINAL; tabelas de correção ganham chave
                        numérica (ID) e campos padrão de criação/alteração, para
                        a auditoria (SIS.Auditoria) registrar quem corrigiu o
                        quê; Caso_Correcao_Linha ganha UNIDADE. As tabelas de
                        correção vazias no formato antigo são refeitas.
    v1.2 (18/11/2026) - Aviso de mudança no Access: HASH_ACCESS nas correções
                        (impressão digital da linha ou do documento no momento
                        da correção) e MIG.Caso.REVISAR (texto do aviso quando
                        o Access mudou ou apagou o que foi corrigido).
    v1.3 (18/11/2026) - Caso_Correcao_Linha.LOTE: troca do lote da linha pela
                        tela (0 = sai do lote; NULL = mantém o do Access).
    v1.4 (20/11/2026) - Etapa 03d (instalação no servidor): teste do formato
                        antigo de Caso_Correcao/_Linha com IF aninhado; em banco
                        novo o SELECT na tabela ainda inexistente dava erro 208.
    v1.5 (23/11/2026) - Etapa 03f2: ação ABATER em Caso_Correcao (com
                        LINK_VENDA_DESTINO = venda/parcela do Access que o
                        "crédito" manual abate). Resposta da Renata de
                        23/11/2026 (nº 308074 e 308076).

*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[MIG].[Caso]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso]
    (
        UNIDADE        VARCHAR(40)    NOT NULL CONSTRAINT PK_Caso PRIMARY KEY,
        PADRAO         VARCHAR(200)   NOT NULL CONSTRAINT DF_Caso_PADRAO DEFAULT (''),
        MOTIVO         NVARCHAR(400)  NOT NULL,
        DETALHE        NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_DETALHE DEFAULT (N''),
        LINHAS         INT            NOT NULL,
        VALOR_DEBITO   DECIMAL(18,2)  NOT NULL,
        VALOR_CREDITO  DECIMAL(18,2)  NOT NULL,
        DT_DOCUMENTO   DATE           NULL,
        DT_CALCULO     DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_DT DEFAULT (SYSDATETIME())
    );
GO

IF COL_LENGTH(N'MIG.Caso', N'DETALHE') IS NULL
    ALTER TABLE [MIG].[Caso] ADD DETALHE NVARCHAR(400) NOT NULL CONSTRAINT DF_Caso_DETALHE DEFAULT (N'');
GO
IF COL_LENGTH(N'MIG.Caso', N'REGRA_ATUAL') IS NULL
    ALTER TABLE [MIG].[Caso] ADD REGRA_ATUAL VARCHAR(15) NOT NULL CONSTRAINT DF_Caso_REGRA_ATUAL DEFAULT ('CASO');
GO
IF COL_LENGTH(N'MIG.Caso', N'MOTIVO_ORIGINAL') IS NULL
    ALTER TABLE [MIG].[Caso] ADD MOTIVO_ORIGINAL NVARCHAR(400) NOT NULL CONSTRAINT DF_Caso_MOTIVO_ORIGINAL DEFAULT (N'');
GO

-- formato antigo (sem ID) e vazio: refaz (a auditoria precisa de chave numérica)
-- (IF aninhado: o SELECT só é compilado quando a tabela existe; banco novo não dá erro)
IF OBJECT_ID(N'[MIG].[Caso_Correcao]', N'U') IS NOT NULL AND COL_LENGTH(N'MIG.Caso_Correcao', N'ID_CASO_CORRECAO') IS NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao)
        DROP TABLE [MIG].[Caso_Correcao];
END;
IF OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]', N'U') IS NOT NULL AND COL_LENGTH(N'MIG.Caso_Correcao_Linha', N'ID_CASO_CORRECAO_LINHA') IS NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha)
        DROP TABLE [MIG].[Caso_Correcao_Linha];
END;
GO

IF OBJECT_ID(N'[MIG].[Caso_Correcao]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso_Correcao]
    (
        ID_CASO_CORRECAO   INT            IDENTITY(1,1) NOT NULL CONSTRAINT PK_Caso_Correcao PRIMARY KEY,
        UNIDADE            VARCHAR(40)    NOT NULL,
        ACAO               VARCHAR(15)    NOT NULL,
        MOTIVO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_Correcao_MOTIVO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_Correcao_DT_CRIACAO DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL,
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        LINK_VENDA_DESTINO INT            NULL,
        CONSTRAINT UQ_Caso_Correcao_UNIDADE UNIQUE (UNIDADE),
        CONSTRAINT CK_Caso_Correcao_ACAO CHECK (ACAO IN ('IGNORAR', 'ARQUIVO_MORTO', 'ABATER')),
        CONSTRAINT CK_Caso_Correcao_ABATER CHECK ((ACAO = 'ABATER' AND LINK_VENDA_DESTINO > 0) OR (ACAO <> 'ABATER' AND LINK_VENDA_DESTINO IS NULL))
    );
GO

IF OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]', N'U') IS NULL
    CREATE TABLE [MIG].[Caso_Correcao_Linha]
    (
        ID_CASO_CORRECAO_LINHA INT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_Caso_Correcao_Linha PRIMARY KEY,
        ORIGEM             VARCHAR(20)    NOT NULL,
        NUM                INT            NOT NULL,
        UNIDADE            VARCHAR(40)    NOT NULL,
        EMP_VINCULADA      INT            NULL,       -- NULL = mantém o valor do Access
        PARCEIRO           INT            NULL,
        CONTA              INT            NULL,
        PLANO3             INT            NULL,
        DT_MOVTO           DATE           NULL,
        DT_VENCTO          DATE           NULL,
        DT_PAGTO           DATE           NULL,
        VALOR_DEBITO       DECIMAL(18,2)  NULL,
        VALOR_CREDITO      DECIMAL(18,2)  NULL,
        CONFIRMADO         BIT            NULL,
        IGNORAR_LINHA      BIT            NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_IGN    DEFAULT (0),
        MOTIVO             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_MOTIVO DEFAULT (N''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Caso_Correcao_Linha_DT_CRIACAO DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL,
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT UQ_Caso_Correcao_Linha UNIQUE (ORIGEM, NUM),
        CONSTRAINT CK_Caso_Correcao_Linha_VALOR CHECK (ISNULL(VALOR_DEBITO, 0) >= 0 AND ISNULL(VALOR_CREDITO, 0) >= 0)
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[MIG].[Caso_Correcao_Linha]') AND name = N'IX_Caso_Correcao_Linha_UNIDADE')
    CREATE NONCLUSTERED INDEX IX_Caso_Correcao_Linha_UNIDADE ON [MIG].[Caso_Correcao_Linha] (UNIDADE);
GO

IF OBJECT_ID(N'[MIG].[Linha_Destino]', N'U') IS NULL
    CREATE TABLE [MIG].[Linha_Destino]
    (
        ORIGEM            VARCHAR(20)    NOT NULL,
        NUM               INT            NOT NULL,
        UNIDADE           VARCHAR(40)    NOT NULL,
        REGRA             VARCHAR(12)    NOT NULL,
        PAPEL             VARCHAR(15)    NOT NULL,     -- TITULO / PAGAMENTO / CONTRAPARTIDA / TRANSFERENCIA
        ID_LANCAMENTO     BIGINT         NULL,
        ID_MOVIMENTO      BIGINT         NULL,
        ID_TRANSFERENCIA  BIGINT         NULL,
        ID_CONTA          INT            NULL,
        VALOR             DECIMAL(18,2)  NOT NULL,
        CONSTRAINT PK_Linha_Destino PRIMARY KEY (ORIGEM, NUM)
    );
GO

IF OBJECT_ID(N'[MIG].[DePara_Venda]', N'U') IS NULL
    CREATE TABLE [MIG].[DePara_Venda]
    (
        ID_LANCAMENTO  BIGINT         NOT NULL CONSTRAINT PK_DePara_Venda PRIMARY KEY,
        ORIGEM         VARCHAR(20)    NOT NULL,
        NUM            INT            NOT NULL,
        LINK_VENDA     INT            NOT NULL,
        IMOVEL         INT            NULL,
        PARCEIRO       INT            NULL,
        CONTRATO       VARCHAR(40)    NOT NULL,
        NUM_DOC        NVARCHAR(100)  NOT NULL
    );
GO

IF COL_LENGTH(N'MIG.Caso', N'REVISAR') IS NULL
    ALTER TABLE [MIG].[Caso] ADD REVISAR NVARCHAR(400) NOT NULL CONSTRAINT DF_Caso_REVISAR DEFAULT (N'');
IF COL_LENGTH(N'MIG.Caso_Correcao', N'HASH_ACCESS') IS NULL
    ALTER TABLE [MIG].[Caso_Correcao] ADD HASH_ACCESS VARBINARY(32) NULL;
IF COL_LENGTH(N'MIG.Caso_Correcao_Linha', N'HASH_ACCESS') IS NULL
    ALTER TABLE [MIG].[Caso_Correcao_Linha] ADD HASH_ACCESS VARBINARY(32) NULL;
IF COL_LENGTH(N'MIG.Caso_Correcao_Linha', N'LOTE') IS NULL
    ALTER TABLE [MIG].[Caso_Correcao_Linha] ADD LOTE INT NULL CONSTRAINT CK_Caso_Correcao_Linha_LOTE CHECK (LOTE >= 0);
GO

-- v1.5: abatimento de parcela (ACAO = 'ABATER' + venda de destino)
IF COL_LENGTH(N'MIG.Caso_Correcao', N'LINK_VENDA_DESTINO') IS NULL
    ALTER TABLE [MIG].[Caso_Correcao] ADD LINK_VENDA_DESTINO INT NULL;
GO
IF EXISTS (SELECT 1 FROM sys.check_constraints k WHERE k.name = N'CK_Caso_Correcao_ACAO' AND k.parent_object_id = OBJECT_ID(N'MIG.Caso_Correcao')
           AND k.definition NOT LIKE N'%ABATER%')
    ALTER TABLE [MIG].[Caso_Correcao] DROP CONSTRAINT CK_Caso_Correcao_ACAO;
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints k WHERE k.name = N'CK_Caso_Correcao_ACAO' AND k.parent_object_id = OBJECT_ID(N'MIG.Caso_Correcao'))
    ALTER TABLE [MIG].[Caso_Correcao] ADD CONSTRAINT CK_Caso_Correcao_ACAO CHECK (ACAO IN ('IGNORAR', 'ARQUIVO_MORTO', 'ABATER'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints k WHERE k.name = N'CK_Caso_Correcao_ABATER' AND k.parent_object_id = OBJECT_ID(N'MIG.Caso_Correcao'))
    ALTER TABLE [MIG].[Caso_Correcao] ADD CONSTRAINT CK_Caso_Correcao_ABATER
        CHECK ((ACAO = 'ABATER' AND LINK_VENDA_DESTINO > 0) OR (ACAO <> 'ABATER' AND LINK_VENDA_DESTINO IS NULL));
GO

-- busca de linha do Access pelo código (tela de casos e migração); MIG_Movimento_Preparar também cria
IF OBJECT_ID(N'[MIG].[Movimento]', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[MIG].[Movimento]') AND name = N'IX_MIG_Movimento_ORIGEM_NUM')
    CREATE INDEX IX_MIG_Movimento_ORIGEM_NUM ON MIG.Movimento (ORIGEM, NUM) INCLUDE (UNIDADE, DESTINO, LINK_VENDA, LOTE);
GO

-- auditoria das correções feitas pela tela (quem, quando, antes e depois)
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'MIG.Caso_Correcao',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'MIG.Caso_Correcao_Linha', @Criar = 1;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.fn_MIG_Hash_Unidade.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[fn_MIG_Hash_Unidade]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Impressão digital de um documento do Access (unidade): SHA-256
                das impressões das linhas dele (MIG.Movimento.HASH_CONTEUDO),
                em ordem. Muda se qualquer linha do documento for alterada,
                incluída ou apagada no Access. NULL se o documento não existe.
                Usada pela tela "Casos da migração" para avisar quando o Access
                mudou depois de uma decisão (ignorar / arquivo morto).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, aviso de mudança no Access).

  Homologação (LOCAL):
    -- SELECT MIG.fn_MIG_Hash_Unidade('L:123');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [MIG].[fn_MIG_Hash_Unidade] (@Unidade VARCHAR(40))
RETURNS VARBINARY(32)
AS
BEGIN
    RETURN (SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                        ELSE HASHBYTES('SHA2_256', STRING_AGG(CAST(CONVERT(VARCHAR(64), m.HASH_CONTEUDO, 2) AS VARCHAR(MAX)), '|')
                                                   WITHIN GROUP (ORDER BY m.ORIGEM, m.NUM)) END
            FROM MIG.Movimento m
            WHERE m.UNIDADE = @Unidade AND m.DESTINO = 'SISTEMA');
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Estrutura de MIG.Movimento (criada pela MIG_Movimento_Preparar): necessaria
-- para a view e a function a seguir. Banco novo: so a estrutura, vazia.
-- -----------------------------------------------------------------------------
IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
BEGIN
    PRINT N'MIG.Movimento ainda nao existe: rodando MIG.MIG_Movimento_Preparar para criar a estrutura.';
    EXEC MIG.MIG_Movimento_Preparar;
END;
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.vw_MIG_Linha_Unidade.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[vw_MIG_Linha_Unidade]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Para cada linha do Access que vai para o sistema (MIG.Movimento,
                DESTINO = 'SISTEMA'), o documento (unidade) do Access e o
                documento em uso depois da troca de lote feita pela tela de
                casos (Caso_Correcao_Linha.LOTE): lote do Access, outro lote do
                Access, lote novo da migração (900001 em diante) ou, com 0,
                fora do lote (venda ou avulso). Mesma regra do
                MIG_Movimento_Preparar. Usada pela tela de casos e pela
                migração para achar as linhas de um documento.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (19/11/2026) - Criação (etapa 03c2, lote novo da migração).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW [MIG].[vw_MIG_Linha_Unidade]
AS
SELECT m.ORIGEM, m.NUM, m.UNIDADE AS UNIDADE_ACCESS,
       CAST(CASE WHEN o.LOTE IS NULL THEN m.UNIDADE
                 WHEN o.LOTE > 0 THEN 'L:' + CONVERT(VARCHAR(20), o.LOTE)
                 WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
                 ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END AS VARCHAR(40)) AS UNIDADE,
       CAST(CASE WHEN o.LOTE IS NULL THEN 0 ELSE 1 END AS BIT) AS MOVIDA
FROM MIG.Movimento m
LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
WHERE m.DESTINO = 'SISTEMA';
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.fn_MIG_Linhas_Documento.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[fn_MIG_Linhas_Documento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 19/11/2026
  Descrição   : Linhas (ORIGEM, NUM) de um documento da tela de casos: as do
                documento no Access e as que chegaram a ele por troca de lote
                (inclusive lote novo da migração, 900001 em diante). Função em
                linha, com busca pelo índice de MIG.Movimento (UNIDADE) e pela
                tabela pequena de correções: rápida mesmo chamada para cada
                caso da lista. Mesma regra de MIG.vw_MIG_Linha_Unidade.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (19/11/2026) - Criação (etapa 03c2, desempenho da tela de casos).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [MIG].[fn_MIG_Linhas_Documento] (@Unidade VARCHAR(40))
RETURNS TABLE
AS
RETURN
    SELECT m.ORIGEM, m.NUM
    FROM MIG.Movimento m
    WHERE m.UNIDADE = @Unidade AND m.DESTINO = 'SISTEMA'
    UNION
    SELECT o.ORIGEM, o.NUM
    FROM MIG.Caso_Correcao_Linha o
    INNER JOIN MIG.Movimento m ON m.ORIGEM = o.ORIGEM AND m.NUM = o.NUM AND m.DESTINO = 'SISTEMA'
    WHERE o.LOTE IS NOT NULL
      AND CASE WHEN o.LOTE > 0 THEN 'L:' + CONVERT(VARCHAR(20), o.LOTE)
               WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
               ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END = @Unidade;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Movimento_Transformar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Movimento_Transformar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Etapa 03c2, parte B: transforma os documentos do Access que vão
                para o sistema novo (MIG.Movimento, DESTINO = 'SISTEMA') em
                lançamento, parcela, baixa, movimento bancário e transferência,
                pelas regras aprovadas pelo Celso em 18/11/2026
                (docs/requisitos/Migracao_Movimento.md, seção 9):
                  LOTE      títulos da conta "Pagto em Lote" + uma saída (banco
                            ou caixinha) com o mesmo total: cada título vira conta
                            a pagar; a saída vira UM movimento ligado a todas as
                            baixas; o lote do Access vira um SIS.Lote;
                  VENDA     linha da conta "Débitos" (cliente) + entrada no banco
                            ou caixa: conta a receber; ligação com o contrato em
                            MIG.DePara_Venda;
                  AVULSO    pagamentos e recebimentos direto no banco ou no caixa
                            (caixinha = conta Caixa da empresa);
                  TRANSF    créditos e débitos soltos: transferência entre o banco
                            e o Caixa contábil da empresa (banco da linha, se
                            houver; senão a conta padrão da obra ou da empresa);
                  CASO      o resto: MIG.Caso, para a tela de correção.
                  ABATER    documento marcado na tela como "crédito" manual que
                            abate a parcela de uma venda (MIG.Caso_Correcao,
                            LINK_VENDA_DESTINO): vira uma baixa só de
                            abatimento na parcela (VALOR_PRINCIPAL = ABATIMENTO,
                            líquido zero, sem movimento no banco); a parcela
                            fica com o saldo real devido.
                Correções da tela (MIG.Caso_Correcao e Caso_Correcao_Linha) são
                aplicadas antes da classificação.
                Situação: linha confirmada = baixa; "efetuado" sem "confirmado"
                com data de pagamento = baixa não compensada (cheque); sem data
                = parcela em aberto. "Somente integração" = lançamento só
                contábil e baixa sem movimento no banco.
                @Unidade (tela de casos, botão "Conferir"): classifica só aquele
                documento, atualiza a linha dele em MIG.Caso e devolve uma
                linha (UNIDADE, REGRA, MOTIVO, DETALHE); nada é gravado no
                financeiro.
                MIG.Caso guarda os casos e também os documentos que já têm
                correção da tela (REGRA_ATUAL = como ficaram), para a tela
                mostrar o que foi resolvido.
                @Executar = 0 (padrão): só a prévia (classificação e números),
                nada é gravado no financeiro. @Executar = 1: apaga a carga
                anterior da migração (lotes de origem MIGRACAO) e grava de novo,
                tudo-ou-nada. Usuário "sistema", origem MIGRACAO.
                Pré-requisito: MIG_Movimento_Preparar e MIG_Cadastros_Processar.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
    v1.1 (18/11/2026) - Tela de casos: parâmetro @Unidade (conferir um
                        documento só); MIG.Caso atualizada por MERGE, mantendo
                        os documentos corrigidos (REGRA_ATUAL, MOTIVO_ORIGINAL).
    v1.2 (18/11/2026) - Aviso "Revisar" (MIG.Caso.REVISAR): linha corrigida que
                        mudou ou foi apagada no Access, documento com decisão
                        que mudou ou sumiu do Access.
    v1.3 (18/11/2026) - @Unidades (lista JSON): confere vários documentos de uma
                        vez (ações em lote da tela de casos); uma linha por
                        documento no retorno.
    v1.4 (18/11/2026) - Troca de lote pela tela (Caso_Correcao_Linha.LOTE): a
                        linha passa para o documento do lote novo (0 = sai do
                        lote: avulso ou venda); padrão de contas recalculado nos
                        documentos afetados; a conferência inclui o documento
                        de destino (depois dos pedidos).
    v1.5 (19/11/2026) - Lote novo da migração (900001 em diante); decisões da
                        tela (ignorar / arquivo morto) valem para o documento
                        como ele está depois da troca de lote.
    v1.6 (23/11/2026) - Etapa 03f2: decisão ABATER (resposta da Renata de
                        23/11/2026, nº 308074 e 308076): baixa só de abatimento
                        na parcela da venda de destino, na conta prevista da
                        parcela (ou no Caixa contábil da empresa), com o nº do
                        Access e o motivo. Destino inválido (venda que não
                        migra como conta a receber, já paga, abatimento maior
                        que a parcela) devolve o documento para a lista de
                        casos com o motivo. Conferir um documento ABATER
                        confere também a venda de destino.

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Movimento_Transformar;                 -- prévia
    -- EXEC MIG.MIG_Movimento_Transformar @Executar = 1;   -- grava
    -- EXEC MIG.MIG_Movimento_Transformar @Unidade = 'L:123'; -- confere um documento
    -- EXEC MIG.MIG_Movimento_Transformar @Unidades = N'["L:123","V:45"]'; -- confere vários
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Movimento_Transformar]
    @Executar           BIT          = 0,
    @NomeCaixa          NVARCHAR(60) = N'Caixa',
    @NomeCaixaContabil  NVARCHAR(60) = N'Caixa contábil',
    @Unidade            VARCHAR(40)  = NULL,
    @Unidades           NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[MIG].[MIG_Movimento_Transformar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @IdSistema    INT;
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @IdPrincipal  INT;
    DECLARE @IdLoteGeral  BIGINT;
    DECLARE @Agora        DATETIME2(0) = SYSDATETIME();

    BEGIN TRY
        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;

        IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
            THROW 50001, N'Rode antes o MIG.MIG_Movimento_Preparar.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.DePara_Centro) OR NOT EXISTS (SELECT 1 FROM MIG.DePara_Plano)
            THROW 50001, N'Rode antes o MIG.MIG_Cadastros_Processar.', 1;
        -- documentos escolhidos (tela de casos): um (@Unidade) ou vários (@Unidades)
        CREATE TABLE #Sel (UNIDADE VARCHAR(40) NOT NULL PRIMARY KEY, PEDIDO BIT NOT NULL DEFAULT (1));
        IF @Unidade IS NOT NULL
            INSERT INTO #Sel (UNIDADE) VALUES (@Unidade);
        IF ISJSON(ISNULL(@Unidades, N'')) = 1
            INSERT INTO #Sel (UNIDADE)
            SELECT DISTINCT LEFT(j.value, 40) FROM OPENJSON(@Unidades) j
            WHERE j.value IS NOT NULL AND NOT EXISTS (SELECT 1 FROM #Sel s WHERE s.UNIDADE = LEFT(j.value, 40));
        DECLARE @Filtrar BIT = CASE WHEN EXISTS (SELECT 1 FROM #Sel) THEN 1 ELSE 0 END;
        -- linha trocada de lote: confere também o documento para onde ela foi
        INSERT INTO #Sel (UNIDADE, PEDIDO)
        SELECT DISTINCT d.UNIDADE, 0
        FROM MIG.Caso_Correcao_Linha o
        INNER JOIN MIG.Movimento m ON m.ORIGEM = o.ORIGEM AND m.NUM = o.NUM
        CROSS APPLY (SELECT CAST(CASE WHEN o.LOTE IS NULL THEN m.UNIDADE
                                         WHEN o.LOTE > 0 THEN 'L:' + CONVERT(VARCHAR(20), o.LOTE)
                                         WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
                                         ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END AS VARCHAR(40)) AS UNIDADE) d
        WHERE @Filtrar = 1 AND o.LOTE IS NOT NULL
          AND o.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s)
          AND NOT EXISTS (SELECT 1 FROM #Sel s WHERE s.UNIDADE = d.UNIDADE);
        -- documento que abate uma parcela: confere também a venda de destino
        INSERT INTO #Sel (UNIDADE, PEDIDO)
        SELECT DISTINCT 'V:' + CONVERT(VARCHAR(20), cc.LINK_VENDA_DESTINO), 0
        FROM MIG.Caso_Correcao cc
        WHERE @Filtrar = 1 AND cc.ACAO = 'ABATER'
          AND cc.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s)
          AND NOT EXISTS (SELECT 1 FROM #Sel s WHERE s.UNIDADE = 'V:' + CONVERT(VARCHAR(20), cc.LINK_VENDA_DESTINO));
        IF (@Unidade IS NOT NULL OR @Unidades IS NOT NULL) AND @Filtrar = 0
            THROW 50001, N'Nenhum documento informado para conferir.', 1;
        IF @Filtrar = 1 AND ISNULL(@Executar, 0) = 1
            THROW 50001, N'A conferência de documentos escolhidos (@Unidade/@Unidades) não grava: rode sem @Executar.', 1;

        SELECT @IdSistema = u.ID_USUARIO FROM SIS.Usuario u WHERE u.LOGIN = 'sistema';
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdSistema);
        EXEC SIS.SIS_Contexto_Gravar @IdUsuario = @IdSistema, @Origem = N'MIGRACAO';
        SELECT @IdPrincipal = e.ID_EMPRESA
        FROM CAD.Empresa e INNER JOIN MIG.Classif_Empresa c ON c.CODIGO_MASTER = e.CODIGO_ACCESS AND c.PRINCIPAL = 1;

        /* ------------------------------------------------------------------
           1. Linhas do Access (com as correções da tela) e os de-paras
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Linhas';
        SELECT h.CodHistorico AS COD, f.ID_HISTORICO_PADRAO
        INTO #Hist
        FROM (SELECT TRY_CONVERT(INT, a.CodHistorico) AS CodHistorico, LEFT(LTRIM(RTRIM(ISNULL(a.Descricao, N''))), 80) AS DESCRICAO FROM MIG.Access_Historico a) h
        CROSS APPLY (SELECT TOP (1) x.ID_HISTORICO_PADRAO FROM FIN.Historico_Padrao x
                     WHERE x.CODIGO_ACCESS = h.CodHistorico OR x.DESCRICAO = h.DESCRICAO
                     ORDER BY CASE WHEN x.CODIGO_ACCESS = h.CodHistorico THEN 0 ELSE 1 END) f
        WHERE h.CodHistorico IS NOT NULL;

        SELECT m.ORIGEM, m.NUM, eu.UNIDADE, m.PADRAO, m.CONTRATO, m.LINK_VENDA, m.IMOVEL,
               m.UNIDADE AS UNIDADE_ACCESS, CAST(CASE WHEN o.LOTE IS NULL THEN 0 ELSE 1 END AS BIT) AS MOVIDA,
               COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS EV,
               COALESCE(o.PARCEIRO, m.PARCEIRO)           AS PAR,
               COALESCE(o.CONTA, m.CONTA)                 AS CONTA,
               COALESCE(o.PLANO3, m.PLANO3)               AS P3,
               m.HISTORICO,
               CASE WHEN COALESCE(o.DT_MOVTO,  m.DT_MOVTO)  BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_MOVTO,  m.DT_MOVTO)  END AS DM,
               CASE WHEN COALESCE(o.DT_VENCTO, m.DT_VENCTO) BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_VENCTO, m.DT_VENCTO) END AS DV,
               CASE WHEN COALESCE(o.DT_PAGTO,  m.DT_PAGTO)  BETWEEN '2000-01-01' AND '2060-12-31' THEN COALESCE(o.DT_PAGTO,  m.DT_PAGTO)  END AS DP,
               m.DT_UNIDADE,
               COALESCE(o.VALOR_DEBITO, m.VALOR_DEBITO)   AS DEB,
               COALESCE(o.VALOR_CREDITO, m.VALOR_CREDITO) AS CRE,
               COALESCE(o.CONFIRMADO, m.CONFIRMADO)       AS CONF,
               m.EFETUADO AS EFET, m.INTEGRACAO AS INTEG, m.SOMENTE_INTEGRACAO AS SOI,
               m.NUM_DOC, m.COMPLEMENTO, m.OBSERVACAO, m.NOTA_FISCAL,
               CAST('' AS VARCHAR(4)) AS TC, CAST('' AS CHAR(1)) AS LADO, CAST(0 AS DECIMAL(18,2)) AS VALOR,
               CAST(NULL AS INT) AS ID_CENTRO, CAST(NULL AS INT) AS ID_EMPRESA, CAST(NULL AS INT) AS ID_CONTA_PADRAO,
               CAST(NULL AS INT) AS ID_PESSOA, CAST(NULL AS INT) AS ID_PLANO, CAST(NULL AS INT) AS ID_CONTA_BCO,
               CAST(NULL AS INT) AS ID_EMPRESA_BCO, CAST(NULL AS INT) AS ID_HIST
        INTO #L
        FROM MIG.Movimento m
        LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
        CROSS APPLY (SELECT CAST(CASE WHEN o.LOTE IS NULL THEN m.UNIDADE
                                         WHEN o.LOTE > 0 THEN 'L:' + CONVERT(VARCHAR(20), o.LOTE)
                                         WHEN m.LINK_VENDA > 0 THEN 'V:' + CONVERT(VARCHAR(20), m.LINK_VENDA)
                                         ELSE 'A:' + CASE m.ORIGEM WHEN 'ACCESS_MOVTO' THEN 'M' ELSE 'Q' END + ':' + CONVERT(VARCHAR(20), m.NUM) END AS VARCHAR(40)) AS UNIDADE) eu
        WHERE m.DESTINO = 'SISTEMA'
          AND (@Filtrar = 0 OR m.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s) OR eu.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s))
          AND ISNULL(o.IGNORAR_LINHA, 0) = 0
          AND NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao c WHERE c.UNIDADE = eu.UNIDADE);

        CREATE UNIQUE CLUSTERED INDEX IX_L ON #L (ORIGEM, NUM);
        CREATE INDEX IX_L_U ON #L (UNIDADE);

        UPDATE l
           SET l.TC    = CASE l.CONTA WHEN 1 THEN 'CRED' WHEN 2 THEN 'DEB' WHEN 3 THEN 'LOTE' WHEN 9 THEN 'NA' ELSE 'BCO' END,
               l.LADO  = CASE WHEN l.DEB > 0 AND l.CRE > 0 THEN 'X' WHEN l.DEB > 0 THEN 'D' WHEN l.CRE > 0 THEN 'C' ELSE '0' END,
               l.VALOR = l.DEB + l.CRE
        FROM #L l;

        UPDATE l
           SET l.ID_CENTRO       = COALESCE(dp.ID_CENTRO_CUSTO, dc.ID_CENTRO_CUSTO),
               l.ID_EMPRESA      = COALESCE(cc.ID_EMPRESA, dc.ID_EMPRESA),
               l.ID_CONTA_PADRAO = dc.ID_CONTA_PADRAO,
               l.ID_PESSOA       = p.ID_PESSOA,
               l.ID_PLANO        = dp.ID_PLANO_CONTA,
               l.ID_CONTA_BCO    = CASE WHEN l.TC = 'BCO' THEN k.ID_CONTA END,
               l.ID_EMPRESA_BCO  = CASE WHEN l.TC = 'BCO' THEN k.ID_EMPRESA END,
               l.ID_HIST         = h.ID_HISTORICO_PADRAO
        FROM #L l
        LEFT JOIN MIG.DePara_Centro dc ON dc.CODIGO_VINCULADA = l.EV
        LEFT JOIN MIG.DePara_Plano dp  ON dp.PLANO3_ACCESS = l.P3
        LEFT JOIN CAD.Centro_Custo cc  ON cc.ID_CENTRO_CUSTO = dp.ID_CENTRO_CUSTO
        LEFT JOIN CAD.Pessoa p         ON p.CODIGO_ACCESS = l.PAR AND l.PAR > 1
        LEFT JOIN BANCO.Conta k        ON k.CODIGO_ACCESS = l.CONTA
        LEFT JOIN #Hist h              ON h.COD = l.HISTORICO;

        /* ------------------------------------------------------------------
           2. Classificação de cada documento (unidade)
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Classificação';
        SELECT l.UNIDADE, MIN(l.PADRAO) AS PADRAO, LEFT(l.UNIDADE, 1) AS TIPO_U,
               COUNT(*) AS N, MIN(l.DT_UNIDADE) AS DT_UNIDADE,
               SUM(l.DEB) AS S_DEB_TOTAL, SUM(l.CRE) AS S_CRE_TOTAL,
               SUM(CASE WHEN l.LADO = 'X' THEN 1 ELSE 0 END) AS N_DUPLO,
               SUM(CASE WHEN l.LADO IN ('D', 'C') THEN 1 ELSE 0 END) AS N_NZ,
               SUM(CASE WHEN l.TC = 'LOTE' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_LOTE,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_PAG,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_REC,
               SUM(CASE WHEN l.TC = 'BCO' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_PAG_BCO,
               SUM(CASE WHEN l.TC = 'BCO' AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_REC_BCO,
               SUM(CASE WHEN l.TC = 'CRED' AND l.LADO = 'C' THEN 1 ELSE 0 END) AS N_CRED,
               SUM(CASE WHEN l.TC = 'DEB' AND l.LADO = 'D' THEN 1 ELSE 0 END) AS N_DEBD,
               SUM(CASE WHEN l.LADO IN ('D', 'C') AND NOT ((l.TC = 'LOTE' AND l.LADO = 'D') OR l.TC IN ('BCO', 'NA')
                                                         OR (l.TC = 'CRED' AND l.LADO = 'C') OR (l.TC = 'DEB' AND l.LADO = 'D')) THEN 1 ELSE 0 END) AS N_OUTRO,
               SUM(CASE WHEN l.TC = 'LOTE' AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_LOTE,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_PAG,
               SUM(CASE WHEN l.TC IN ('BCO', 'NA') AND l.LADO = 'C' THEN l.VALOR ELSE 0 END) AS S_REC,
               SUM(CASE WHEN l.TC = 'CRED' AND l.LADO = 'C' THEN l.VALOR ELSE 0 END) AS S_CRED,
               SUM(CASE WHEN l.TC = 'DEB' AND l.LADO = 'D' THEN l.VALOR ELSE 0 END) AS S_DEBD,
               SUM(CASE WHEN l.TC IN ('CRED', 'DEB') AND l.LADO IN ('D', 'C') AND l.CONF = 0 THEN 1 ELSE 0 END) AS N_TR_NAO_CONF,
               CAST('' AS VARCHAR(12)) AS REGRA, CAST(N'' AS NVARCHAR(400)) AS MOTIVO, CAST(N'' AS NVARCHAR(400)) AS DETALHE
        INTO #U
        FROM #L l
        GROUP BY l.UNIDADE;

        -- documentos que ganharam ou perderam linha por troca de lote: padrão de contas refeito
        WITH Afetadas AS (
            SELECT l.UNIDADE FROM #L l WHERE l.MOVIDA = 1
            UNION SELECT l.UNIDADE_ACCESS FROM #L l WHERE l.MOVIDA = 1),
        Pares AS (
            SELECT DISTINCT l.UNIDADE, CONVERT(VARCHAR(20), l.TC + '-' + l.LADO) AS PAR
            FROM #L l INNER JOIN Afetadas a ON a.UNIDADE = l.UNIDADE)
        UPDATE u
           SET u.PADRAO = LEFT(LEFT(u.UNIDADE, 1) + '|' + p.PADRAO, 200)
        FROM #U u
        INNER JOIN (SELECT x.UNIDADE, STRING_AGG(x.PAR, '|') WITHIN GROUP (ORDER BY x.PAR) AS PADRAO FROM Pares x GROUP BY x.UNIDADE) p
                ON p.UNIDADE = u.UNIDADE;

        UPDATE u
           SET u.REGRA = CASE
                   WHEN u.N_DUPLO > 0 THEN 'CASO'
                   WHEN u.N_NZ = 0 THEN 'CASO'
                   WHEN u.N_OUTRO > 0 THEN 'CASO'
                   WHEN u.N_LOTE > 0 AND u.TIPO_U = 'L' AND u.N_PAG = 1 AND u.N_REC = 0 AND u.N_DEBD = 0 AND ABS(u.S_LOTE - u.S_PAG) <= 0.01 THEN 'LOTE'
                   WHEN u.N_LOTE > 0 THEN 'CASO'
                   WHEN u.TIPO_U = 'V' AND u.N_NZ = 2 AND u.N_DEBD = 1 AND u.N_REC = 1 AND ABS(u.S_DEBD - u.S_REC) <= 0.01 THEN 'VENDA'
                   WHEN u.TIPO_U = 'V' THEN 'CASO'
                   WHEN u.N_NZ = 2 AND u.N_PAG_BCO = 1 AND u.N_CRED = 1 AND u.S_PAG = u.S_CRED THEN 'TRANSF_PAR'
                   WHEN u.N_NZ = 2 AND u.N_REC_BCO = 1 AND u.N_DEBD = 1 AND u.S_REC = u.S_DEBD THEN 'TRANSF_PAR'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ AND u.N_TR_NAO_CONF = 0 THEN 'TRANSF'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ THEN 'CASO'
                   WHEN u.N_CRED + u.N_DEBD = 0 THEN 'AVULSO'
                   ELSE 'CASO' END,
               u.MOTIVO = CASE
                   WHEN u.N_DUPLO > 0 THEN N'Linha com débito e crédito ao mesmo tempo'
                   WHEN u.N_NZ = 0 THEN N'Documento com valor zero'
                   WHEN u.N_OUTRO > 0 THEN N'Combinação de contas não prevista (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')'
                   WHEN u.N_LOTE > 0 AND u.TIPO_U <> 'L' THEN N'Título de pagamento em lote fora de um lote'
                   WHEN u.N_LOTE > 0 AND u.N_PAG = 0 THEN N'Pagamento em lote sem a saída do banco ou do caixa'
                   WHEN u.N_LOTE > 0 AND u.N_PAG > 1 THEN N'Pagamento em lote com mais de uma saída'
                   WHEN u.N_LOTE > 0 AND (u.N_REC > 0 OR u.N_DEBD > 0) THEN N'Pagamento em lote com entrada no mesmo lote'
                   WHEN u.N_LOTE > 0 THEN N'Total dos títulos do lote diferente da saída do banco ou do caixa'
                   WHEN u.TIPO_U = 'V' THEN N'Parcela de venda fora do padrão (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')'
                   WHEN u.N_CRED + u.N_DEBD = u.N_NZ THEN N'Transferência não confirmada'
                   ELSE N'Combinação de contas não prevista (' + CONVERT(NVARCHAR(200), u.PADRAO) + N')' END
        FROM #U u;
        UPDATE #U SET DETALHE = N'Títulos ' + FORMAT(S_LOTE, 'N2', 'pt-BR') + N'; saída ' + FORMAT(S_PAG, 'N2', 'pt-BR')
        WHERE REGRA = 'CASO' AND N_LOTE > 0;
        UPDATE #U SET MOTIVO = N'', DETALHE = N'' WHERE REGRA <> 'CASO';

        /* ------------------------------------------------------------------
           3. Contas auxiliares: centro administrativo, caixa e Caixa contábil
              de cada empresa
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Contas auxiliares';
        SELECT c.ID_EMPRESA, MIN(c.ID_CENTRO_CUSTO) AS ID_CENTRO
        INTO #CentroAdm
        FROM CAD.Centro_Custo c
        WHERE c.TIPO = 'ADMINISTRATIVO' AND c.ATIVO = 1 AND c.CODIGO_ACCESS IS NOT NULL
        GROUP BY c.ID_EMPRESA;

        SELECT e.ID_EMPRESA,
               (SELECT TOP (1) k.ID_CONTA FROM BANCO.Conta k
                WHERE k.ID_EMPRESA = e.ID_EMPRESA AND k.TIPO = 'CAIXA' AND k.DESCRICAO <> @NomeCaixaContabil
                ORDER BY k.ATIVO DESC, CASE WHEN k.CODIGO_ACCESS IS NULL THEN 1 ELSE 0 END, k.ID_CONTA) AS ID_CONTA
        INTO #Caixa
        FROM CAD.Empresa e
        WHERE e.CODIGO_ACCESS IS NOT NULL;

        SELECT k.ID_EMPRESA, MIN(k.ID_CONTA) AS ID_CONTA
        INTO #CxContabil
        FROM BANCO.Conta k
        WHERE k.TIPO = 'CAIXA' AND k.DESCRICAO = @NomeCaixaContabil
        GROUP BY k.ID_EMPRESA;

        /* ------------------------------------------------------------------
           4. Títulos (lançamentos) e transferências a gerar
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Títulos';
        -- linha que paga/recebe em cada LOTE e VENDA
        ;WITH Pag AS
        (
            SELECT l.UNIDADE, l.ORIGEM, l.NUM, l.TC, l.CONF, l.EFET, l.SOI, l.DP, l.DM, l.DV, l.ID_CONTA_BCO, l.ID_EMPRESA, l.ID_CENTRO, l.ID_PLANO,
                   l.ID_PESSOA, l.EV, l.VALOR, l.COMPLEMENTO, l.NUM_DOC, l.INTEG,
                   ROW_NUMBER() OVER (PARTITION BY l.UNIDADE ORDER BY l.NUM) AS RN
            FROM #L l
            INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
            WHERE (u.REGRA = 'LOTE'  AND l.TC IN ('BCO', 'NA') AND l.LADO = 'D')
               OR (u.REGRA = 'VENDA' AND l.TC IN ('BCO', 'NA') AND l.LADO = 'C')
        )
        SELECT t.ORIGEM, t.NUM, t.UNIDADE, u.REGRA,
               CAST(CASE WHEN u.REGRA = 'VENDA' THEN 'R' WHEN u.REGRA = 'LOTE' THEN 'P' WHEN t.LADO = 'D' THEN 'P' ELSE 'R' END AS CHAR(1)) AS TIPO,
               -- obra/plano: na venda vêm da linha da entrada; nos demais, do próprio título
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_CENTRO, t.ID_CENTRO) ELSE t.ID_CENTRO END AS ID_CENTRO,
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_EMPRESA, t.ID_EMPRESA) ELSE t.ID_EMPRESA END AS ID_EMPRESA,
               CASE WHEN u.REGRA = 'VENDA' THEN COALESCE(p.ID_PLANO, t.ID_PLANO) ELSE t.ID_PLANO END AS ID_PLANO,
               COALESCE(t.ID_PESSOA, p.ID_PESSOA) AS ID_PESSOA,
               t.ID_HIST,
               CAST(LEFT(ISNULL(t.NUM_DOC, N''), 40) AS NVARCHAR(40)) AS DOCUMENTO,
               COALESCE(t.DM, t.DV, t.DT_UNIDADE) AS DT_EMISSAO,
               COALESCE(t.DV, t.DM, t.DT_UNIDADE) AS DT_VENC,
               CAST(LEFT(ISNULL(NULLIF(t.COMPLEMENTO, N''), ISNULL(p.COMPLEMENTO, N'')), 200) AS NVARCHAR(200)) AS HISTORICO,
               CAST(LEFT(CONCAT_WS(N' | ', NULLIF(t.OBSERVACAO, N''), N'NF: ' + NULLIF(t.NOTA_FISCAL, N''),
                                   N'Access: ' + t.ORIGEM + N' ' + CONVERT(NVARCHAR(12), t.NUM) + N', documento ' + t.UNIDADE), 2000) AS NVARCHAR(2000)) AS OBSERVACAO,
               t.VALOR,
               CAST(CASE WHEN t.SOI = 1 THEN 'SO_CONTABIL' WHEN t.INTEG = 1 THEN 'COMPLETA' ELSE 'NENHUMA' END AS VARCHAR(12)) AS INTEGRACAO,
               -- quem paga: a linha da saída/entrada (LOTE/VENDA) ou o próprio título (AVULSO)
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.TC ELSE t.TC END AS TC_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ID_CONTA_BCO ELSE t.ID_CONTA_BCO END AS ID_CONTA_BCO,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.CONF ELSE t.CONF END AS CONF,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.EFET ELSE t.EFET END AS EFET,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.SOI ELSE t.SOI END AS SOI_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN COALESCE(p.DP, p.DM, t.DP, t.DM) ELSE COALESCE(t.DP, t.DM, t.DV) END AS DT_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.DP ELSE t.DP END AS DP_ORIGINAL,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ORIGEM ELSE t.ORIGEM END AS PAG_ORIGEM,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.NUM ELSE t.NUM END AS PAG_NUM,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN p.ID_EMPRESA ELSE NULL END AS ID_EMPRESA_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN ISNULL(p.COMPLEMENTO, N'') ELSE ISNULL(t.COMPLEMENTO, N'') END AS HIST_PAG,
               CASE WHEN u.REGRA IN ('LOTE', 'VENDA') THEN ISNULL(p.NUM_DOC, N'') ELSE ISNULL(t.NUM_DOC, N'') END AS DOC_PAG,
               t.LINK_VENDA, t.IMOVEL, t.PAR, t.CONTRATO, t.NUM_DOC,
               CAST(NULL AS INT) AS ID_CONTA_PAG,
               CAST(0 AS BIT) AS PAGO, CAST(1 AS BIT) AS COMPENSADO, CAST(0 AS BIT) AS GERA_MOV
        INTO #T
        FROM #L t
        INNER JOIN #U u ON u.UNIDADE = t.UNIDADE
        LEFT JOIN Pag p ON p.UNIDADE = t.UNIDADE AND p.RN = 1 AND u.REGRA IN ('LOTE', 'VENDA')
        WHERE (u.REGRA = 'LOTE'   AND t.TC = 'LOTE' AND t.LADO = 'D')
           OR (u.REGRA = 'VENDA'  AND t.TC = 'DEB'  AND t.LADO = 'D')
           OR (u.REGRA = 'AVULSO' AND t.TC IN ('BCO', 'NA') AND t.LADO IN ('D', 'C'));

        -- empresa e obra: sem obra no Access ("N/A"), usa a empresa da conta que pagou e a área administrativa dela
        UPDATE t SET t.ID_EMPRESA = COALESCE(t.ID_EMPRESA, t.ID_EMPRESA_PAG, k.ID_EMPRESA, @IdPrincipal)
        FROM #T t LEFT JOIN BANCO.Conta k ON k.ID_CONTA = t.ID_CONTA_BCO;
        UPDATE t SET t.ID_CENTRO = a.ID_CENTRO
        FROM #T t INNER JOIN #CentroAdm a ON a.ID_EMPRESA = t.ID_EMPRESA
        WHERE t.ID_CENTRO IS NULL;

        -- conta que pagou: o banco da linha ou o caixa da empresa (no lote, a empresa do 1º título)
        ;WITH EmpLote AS (SELECT t.UNIDADE, MIN(t.ID_EMPRESA) AS ID_EMPRESA FROM #T t WHERE t.REGRA = 'LOTE' GROUP BY t.UNIDADE)
        UPDATE t
           SET t.ID_CONTA_PAG = CASE WHEN t.TC_PAG = 'BCO' THEN t.ID_CONTA_BCO
                                     ELSE (SELECT c.ID_CONTA FROM #Caixa c WHERE c.ID_EMPRESA = COALESCE(t.ID_EMPRESA_PAG, el.ID_EMPRESA, t.ID_EMPRESA)) END,
               t.PAGO       = CASE WHEN t.CONF = 1 OR (t.EFET = 1 AND t.DP_ORIGINAL IS NOT NULL) THEN 1 ELSE 0 END,
               t.COMPENSADO = CASE WHEN t.CONF = 1 THEN 1 ELSE 0 END
        FROM #T t LEFT JOIN EmpLote el ON el.UNIDADE = t.UNIDADE;
        UPDATE #T SET GERA_MOV = CASE WHEN PAGO = 1 AND COMPENSADO = 1 AND SOI_PAG = 0 THEN 1 ELSE 0 END;

        -- transferências (créditos e débitos soltos; pares banco + contrapartida)
        SET @EtapaAtual = 'Transferências';
        SELECT l.ORIGEM, l.NUM, l.UNIDADE, u.REGRA,
               COALESCE(l.DP, l.DM, l.DV) AS DT,
               l.VALOR,
               CAST(LEFT(CONCAT_WS(N' - ', NULLIF(l.COMPLEMENTO, N''), NULLIF(l.NUM_DOC, N''), N'Access ' + CONVERT(NVARCHAR(12), l.NUM)), 200) AS NVARCHAR(200)) AS HISTORICO,
               -- banco: o da linha do par; senão a conta padrão da obra; senão a da empresa
               COALESCE(b.ID_CONTA_BCO, l.ID_CONTA_PADRAO, e.ID_CONTA_BANCARIA_PADRAO) AS ID_BANCO,
               l.LADO, l.TC, l.ID_EMPRESA,
               b.ORIGEM AS BCO_ORIGEM, b.NUM AS BCO_NUM,
               CAST(NULL AS INT) AS ID_CX, CAST(NULL AS INT) AS ID_ORIGEM, CAST(NULL AS INT) AS ID_DESTINO
        INTO #TR
        FROM #L l
        INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
        LEFT JOIN #L b ON b.UNIDADE = l.UNIDADE AND u.REGRA = 'TRANSF_PAR' AND b.TC = 'BCO'
        LEFT JOIN CAD.Empresa e ON e.ID_EMPRESA = l.ID_EMPRESA
        WHERE u.REGRA IN ('TRANSF', 'TRANSF_PAR') AND ((l.TC = 'CRED' AND l.LADO = 'C') OR (l.TC = 'DEB' AND l.LADO = 'D'));

        UPDATE r
           SET r.ID_CX      = x.ID_CONTA,
               r.ID_ORIGEM  = CASE WHEN r.TC = 'CRED' THEN r.ID_BANCO ELSE x.ID_CONTA END,   -- crédito solto: saque do banco para o caixa contábil
               r.ID_DESTINO = CASE WHEN r.TC = 'CRED' THEN x.ID_CONTA ELSE r.ID_BANCO END    -- débito solto: do caixa contábil para o banco
        FROM #TR r
        LEFT JOIN BANCO.Conta k ON k.ID_CONTA = r.ID_BANCO
        LEFT JOIN #CxContabil x ON x.ID_EMPRESA = k.ID_EMPRESA;

        -- transferência sem banco identificável vira caso
        UPDATE u SET u.REGRA = 'CASO', u.MOTIVO = N'Transferência sem conta bancária identificável (obra sem conta padrão)'
        FROM #U u WHERE EXISTS (SELECT 1 FROM #TR r WHERE r.UNIDADE = u.UNIDADE AND (r.ID_ORIGEM IS NULL OR r.ID_DESTINO IS NULL OR r.ID_ORIGEM = r.ID_DESTINO));
        DELETE r FROM #TR r INNER JOIN #U u ON u.UNIDADE = r.UNIDADE WHERE u.REGRA = 'CASO';

        -- título pago sem conta (empresa sem caixa) vira caso
        UPDATE u SET u.REGRA = 'CASO', u.MOTIVO = N'Pagamento sem conta identificável'
        FROM #U u WHERE EXISTS (SELECT 1 FROM #T t WHERE t.UNIDADE = u.UNIDADE AND t.PAGO = 1 AND t.ID_CONTA_PAG IS NULL AND t.TC_PAG = 'BCO');
        DELETE t FROM #T t INNER JOIN #U u ON u.UNIDADE = t.UNIDADE WHERE u.REGRA = 'CASO';

        -- abatimentos: "crédito" manual do Access que abate a parcela de uma venda
        SET @EtapaAtual = 'Abatimentos';
        SELECT cc.UNIDADE, cc.LINK_VENDA_DESTINO AS LINK, cc.MOTIVO AS MOTIVO_TELA, x.NUM, x.DT, x.VALOR,
               t.ORIGEM AS T_ORIGEM, t.NUM AS T_NUM, t.VALOR AS T_VALOR, t.PAGO AS T_PAGO,
               COALESCE(t.ID_CONTA_PAG, cx.ID_CONTA) AS ID_CONTA,
               CAST(N'' AS NVARCHAR(400)) AS ERRO
        INTO #Ab
        FROM MIG.Caso_Correcao cc
        CROSS APPLY (SELECT MIN(m.NUM) AS NUM,
                            COALESCE(MIN(CASE WHEN m.DT_MOVTO BETWEEN '2000-01-01' AND '2060-12-31' THEN m.DT_MOVTO END), MIN(m.DT_UNIDADE)) AS DT,
                            SUM(ISNULL(m.VALOR_CREDITO, 0) - ISNULL(m.VALOR_DEBITO, 0)) AS VALOR
                     FROM MIG.vw_MIG_Linha_Unidade v
                     INNER JOIN MIG.Movimento m ON m.ORIGEM = v.ORIGEM AND m.NUM = v.NUM
                     WHERE v.UNIDADE = cc.UNIDADE) x
        OUTER APPLY (SELECT TOP (1) t.ORIGEM, t.NUM, t.VALOR, t.PAGO, t.ID_CONTA_PAG, t.ID_EMPRESA
                     FROM #T t
                     WHERE t.REGRA = 'VENDA' AND t.UNIDADE = 'V:' + CONVERT(VARCHAR(20), cc.LINK_VENDA_DESTINO)
                     ORDER BY t.NUM) t
        LEFT JOIN #CxContabil cx ON cx.ID_EMPRESA = t.ID_EMPRESA
        WHERE cc.ACAO = 'ABATER'
          AND (@Filtrar = 0 OR cc.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s));

        UPDATE a
           SET a.ERRO = CASE
                   WHEN ISNULL(a.VALOR, 0) <= 0 THEN N'Abatimento: o documento não tem valor de crédito'
                   WHEN a.DT IS NULL THEN N'Abatimento: o documento não tem data'
                   WHEN a.T_NUM IS NULL THEN N'Abatimento: a venda ' + CONVERT(NVARCHAR(20), a.LINK) + N' não migra como conta a receber'
                   WHEN a.T_PAGO = 1 THEN N'Abatimento: a parcela da venda ' + CONVERT(NVARCHAR(20), a.LINK) + N' já está paga'
                   WHEN a.ID_CONTA IS NULL THEN N'Abatimento: a parcela da venda ' + CONVERT(NVARCHAR(20), a.LINK) + N' não tem conta prevista'
                   WHEN s.TOTAL > a.T_VALOR THEN N'Abatimento maior que a parcela da venda ' + CONVERT(NVARCHAR(20), a.LINK)
                                                 + N' (' + FORMAT(s.TOTAL, 'N2', 'pt-BR') + N' × ' + FORMAT(a.T_VALOR, 'N2', 'pt-BR') + N')'
                   ELSE N'' END
        FROM #Ab a
        OUTER APPLY (SELECT SUM(ISNULL(b.VALOR, 0)) AS TOTAL FROM #Ab b WHERE b.LINK = a.LINK) s;

        -- casos para a tela, mais os documentos que já têm correção da tela
        SET @EtapaAtual = 'Casos';
        SELECT v.UNIDADE, MIN(m.PADRAO) AS PADRAO, COUNT(*) AS N, SUM(m.VALOR_DEBITO) AS D, SUM(m.VALOR_CREDITO) AS C,
               MIN(m.DT_UNIDADE) AS DT, MIN(cc.ACAO) AS ACAO
        INTO #Dec
        FROM MIG.vw_MIG_Linha_Unidade v
        INNER JOIN MIG.Movimento m ON m.ORIGEM = v.ORIGEM AND m.NUM = v.NUM
        INNER JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = v.UNIDADE
        WHERE @Filtrar = 0 OR v.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s)
        GROUP BY v.UNIDADE;

        SELECT u.UNIDADE, CAST(ISNULL(u.PADRAO, '') AS VARCHAR(200)) AS PADRAO, CAST(u.REGRA AS VARCHAR(15)) AS REGRA,
               u.MOTIVO, u.DETALHE, u.N, u.S_DEB_TOTAL AS D, u.S_CRE_TOTAL AS C, u.DT_UNIDADE AS DT
        INTO #CasoNovo
        FROM #U u
        WHERE u.REGRA = 'CASO' OR EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = u.UNIDADE)
        UNION ALL
        SELECT d.UNIDADE, ISNULL(d.PADRAO, ''),
               CAST(CASE WHEN ISNULL(a.ERRO, N'') <> N'' THEN 'CASO' ELSE d.ACAO END AS VARCHAR(15)),
               ISNULL(a.ERRO, N''),
               CAST(CASE WHEN a.UNIDADE IS NOT NULL AND a.ERRO = N''
                         THEN N'Abate ' + FORMAT(a.VALOR, 'N2', 'pt-BR') + N' da parcela da venda ' + CONVERT(NVARCHAR(20), a.LINK)
                              + N' (saldo ' + FORMAT(a.T_VALOR - a.VALOR, 'N2', 'pt-BR') + N')'
                         ELSE N'' END AS NVARCHAR(400)),
               d.N, d.D, d.C, d.DT
        FROM #Dec d
        LEFT JOIN #Ab a ON a.UNIDADE = d.UNIDADE
        UNION ALL   -- todas as linhas do documento marcadas "ignorar": o documento fica de fora
        SELECT m.UNIDADE, MIN(m.PADRAO), 'IGNORAR', N'', N'', COUNT(*), SUM(m.VALOR_DEBITO), SUM(m.VALOR_CREDITO), MIN(m.DT_UNIDADE)
        FROM MIG.Movimento m
        WHERE m.DESTINO = 'SISTEMA' AND (@Filtrar = 0 OR m.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s))
          AND EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = m.UNIDADE)
          AND NOT EXISTS (SELECT 1 FROM #U u WHERE u.UNIDADE = m.UNIDADE)
          AND NOT EXISTS (SELECT 1 FROM #Dec d WHERE d.UNIDADE = m.UNIDADE)
        GROUP BY m.UNIDADE;

        -- Access mudou depois da correção: avisa para revisar
        SELECT x.UNIDADE, MIN(x.MSG) AS MSG
        INTO #Rev
        FROM (
            SELECT o.UNIDADE, N'A linha ' + CONVERT(NVARCHAR(12), o.NUM) + N' mudou no Access depois da correção' AS MSG
            FROM MIG.Caso_Correcao_Linha o
            INNER JOIN MIG.Movimento m ON m.ORIGEM = o.ORIGEM AND m.NUM = o.NUM
            WHERE o.HASH_ACCESS IS NOT NULL AND o.HASH_ACCESS <> m.HASH_CONTEUDO
            UNION ALL
            SELECT o.UNIDADE, N'A linha ' + CONVERT(NVARCHAR(12), o.NUM) + N' foi apagada no Access depois da correção'
            FROM MIG.Caso_Correcao_Linha o
            WHERE NOT EXISTS (SELECT 1 FROM MIG.Movimento m WHERE m.ORIGEM = o.ORIGEM AND m.NUM = o.NUM AND m.DESTINO = 'SISTEMA')
            UNION ALL
            SELECT cc.UNIDADE, CASE WHEN h.H IS NULL THEN N'O documento não existe mais no Access'
                                    ELSE N'O documento mudou no Access depois da decisão' END
            FROM MIG.Caso_Correcao cc
            CROSS APPLY (SELECT MIG.fn_MIG_Hash_Unidade(cc.UNIDADE) AS H) h
            WHERE cc.HASH_ACCESS IS NOT NULL AND (h.H IS NULL OR h.H <> cc.HASH_ACCESS)
        ) x
        WHERE @Filtrar = 0 OR x.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s)
        GROUP BY x.UNIDADE;

        -- documento corrigido que sumiu do Access: continua na tela, para revisar
        INSERT INTO #CasoNovo (UNIDADE, PADRAO, REGRA, MOTIVO, DETALHE, N, D, C, DT)
        SELECT r.UNIDADE, '', 'APAGADO', N'Documento não existe mais no Access', N'', 0, 0, 0, NULL
        FROM #Rev r
        WHERE NOT EXISTS (SELECT 1 FROM #CasoNovo n WHERE n.UNIDADE = r.UNIDADE)
          AND NOT EXISTS (SELECT 1 FROM MIG.Movimento m WHERE m.UNIDADE = r.UNIDADE AND m.DESTINO = 'SISTEMA');

        BEGIN TRANSACTION;
        WITH Alvo AS (SELECT * FROM MIG.Caso c WHERE @Filtrar = 0 OR c.UNIDADE IN (SELECT s.UNIDADE FROM #Sel s))
        MERGE Alvo AS c
        USING (SELECT n.*, ISNULL(r.MSG, N'') AS REV FROM #CasoNovo n LEFT JOIN #Rev r ON r.UNIDADE = n.UNIDADE) AS n ON n.UNIDADE = c.UNIDADE
        WHEN MATCHED THEN UPDATE SET
             c.PADRAO = n.PADRAO, c.REGRA_ATUAL = n.REGRA, c.MOTIVO = n.MOTIVO, c.DETALHE = n.DETALHE,
             c.LINHAS = n.N, c.VALOR_DEBITO = n.D, c.VALOR_CREDITO = n.C, c.DT_DOCUMENTO = n.DT, c.DT_CALCULO = SYSDATETIME(), c.REVISAR = n.REV,
             c.MOTIVO_ORIGINAL = CASE WHEN c.MOTIVO_ORIGINAL = N'' THEN c.MOTIVO ELSE c.MOTIVO_ORIGINAL END
        WHEN NOT MATCHED BY TARGET THEN
             INSERT (UNIDADE, PADRAO, REGRA_ATUAL, MOTIVO, MOTIVO_ORIGINAL, DETALHE, LINHAS, VALOR_DEBITO, VALOR_CREDITO, DT_DOCUMENTO, REVISAR)
             VALUES (n.UNIDADE, n.PADRAO, n.REGRA, n.MOTIVO, n.MOTIVO, n.DETALHE, n.N, n.D, n.C, n.DT, n.REV)
        WHEN NOT MATCHED BY SOURCE THEN DELETE;
        COMMIT TRANSACTION;

        -- conferência de um documento só (tela de casos)
        IF @Filtrar = 1
        BEGIN
            SELECT s.UNIDADE,
                   CAST(COALESCE(n.REGRA, u.REGRA, 'SEM_LINHAS') AS VARCHAR(15)) AS REGRA,
                   COALESCE(n.MOTIVO, u.MOTIVO, N'') AS MOTIVO,
                   COALESCE(n.DETALHE, u.DETALHE, N'') AS DETALHE,
                   ISNULL(r.MSG, N'') AS REVISAR
            FROM #Sel s
            LEFT JOIN #CasoNovo n ON n.UNIDADE = s.UNIDADE
            LEFT JOIN #U u ON u.UNIDADE = s.UNIDADE
            LEFT JOIN #Rev r ON r.UNIDADE = s.UNIDADE
            ORDER BY s.PEDIDO DESC, s.UNIDADE;
            DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;
            RETURN;
        END;

        /* ------------------------------------------------------------------
           Prévia
           ------------------------------------------------------------------ */
        IF ISNULL(@Executar, 0) = 0
        BEGIN
            SELECT 'PREVIA' AS GRADE, u.REGRA, COUNT(*) AS DOCUMENTOS, SUM(u.N) AS LINHAS, SUM(u.S_DEB_TOTAL) AS DEBITOS, SUM(u.S_CRE_TOTAL) AS CREDITOS
            FROM #U u GROUP BY u.REGRA ORDER BY u.REGRA;
            SELECT 'TITULOS' AS GRADE, t.REGRA, t.TIPO, COUNT(*) AS LANCAMENTOS, SUM(t.VALOR) AS VALOR,
                   SUM(CASE WHEN t.PAGO = 1 THEN 1 ELSE 0 END) AS PAGOS, SUM(CASE WHEN t.PAGO = 0 THEN 1 ELSE 0 END) AS EM_ABERTO,
                   SUM(CASE WHEN t.PAGO = 1 AND t.COMPENSADO = 0 THEN 1 ELSE 0 END) AS NAO_COMPENSADOS,
                   SUM(CASE WHEN t.ID_PESSOA IS NULL THEN 1 ELSE 0 END) AS SEM_PESSOA, SUM(CASE WHEN t.ID_PLANO IS NULL THEN 1 ELSE 0 END) AS SEM_PLANO,
                   SUM(CASE WHEN t.ID_CENTRO IS NULL THEN 1 ELSE 0 END) AS SEM_CENTRO,
                   SUM(CASE WHEN t.PAGO = 1 AND t.ID_CONTA_PAG IS NULL THEN 1 ELSE 0 END) AS PAGO_SEM_CONTA
            FROM #T t GROUP BY t.REGRA, t.TIPO ORDER BY t.REGRA, t.TIPO;
            SELECT 'TRANSFERENCIAS' AS GRADE, r.REGRA, r.TC, COUNT(*) AS QTD, SUM(r.VALOR) AS VALOR FROM #TR r GROUP BY r.REGRA, r.TC;
            SELECT 'ABATIMENTOS' AS GRADE, a.UNIDADE, a.LINK, a.VALOR, a.T_VALOR AS VALOR_PARCELA, a.T_VALOR - a.VALOR AS SALDO, a.ERRO FROM #Ab a ORDER BY a.UNIDADE;
            SELECT 'CASOS' AS GRADE, c.MOTIVO, COUNT(*) AS DOCUMENTOS, SUM(c.LINHAS) AS LINHAS FROM MIG.Caso c WHERE c.REGRA_ATUAL = 'CASO' GROUP BY c.MOTIVO ORDER BY COUNT(*) DESC;
            DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;
            RETURN;
        END;

        /* ------------------------------------------------------------------
           5. Gravação (tudo-ou-nada)
           ------------------------------------------------------------------ */
        SET @EtapaAtual = 'Gravação: limpeza da carga anterior';
        BEGIN TRANSACTION;

        DELETE b FROM FIN.Baixa b
        INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        WHERE l.ORIGEM = 'MIGRACAO';
        DELETE m FROM BANCO.Movimento m INNER JOIN SIS.Lote x ON x.ID_LOTE = m.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO';
        DELETE t FROM FIN.Transferencia t INNER JOIN SIS.Lote x ON x.ID_LOTE = t.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO';
        DELETE p FROM FIN.Parcela p INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.ORIGEM = 'MIGRACAO';
        DELETE FROM MIG.DePara_Venda;
        DELETE FROM FIN.Lancamento WHERE ORIGEM = 'MIGRACAO';
        DELETE FROM SIS.Lote WHERE ORIGEM = 'MIGRACAO';
        DELETE FROM MIG.Linha_Destino;

        SET @EtapaAtual = 'Gravação: caixas';
        INSERT INTO BANCO.Conta (ID_EMPRESA, DESCRICAO, TIPO, CONCILIA, MOSTRA_SALDO, ATIVO, USUARIO_CRIACAO)
        SELECT DISTINCT e.ID_EMPRESA, @NomeCaixa, 'CAIXA', 0, 1, 1, @Usuario
        FROM #T t
        INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = t.ID_EMPRESA
        WHERE t.TC_PAG = 'NA' AND t.ID_CONTA_PAG IS NULL
          AND NOT EXISTS (SELECT 1 FROM BANCO.Conta k WHERE k.ID_EMPRESA = e.ID_EMPRESA AND k.DESCRICAO = @NomeCaixa);
        UPDATE t SET t.ID_CONTA_PAG = k.ID_CONTA
        FROM #T t INNER JOIN BANCO.Conta k ON k.ID_EMPRESA = t.ID_EMPRESA AND k.DESCRICAO = @NomeCaixa
        WHERE t.TC_PAG = 'NA' AND t.ID_CONTA_PAG IS NULL;

        SET @EtapaAtual = 'Gravação: lotes';
        INSERT INTO SIS.Lote (ORIGEM, DESCRICAO, TABELA_REFERENCIA, QTD_REGISTROS, USUARIO_CRIACAO)
        VALUES ('MIGRACAO', N'Migração do movimento do Access (lançamentos avulsos, vendas e transferências)', N'FIN.Lancamento', 0, @Usuario);
        SET @IdLoteGeral = SCOPE_IDENTITY();

        CREATE TABLE #MapLote (UNIDADE VARCHAR(40) PRIMARY KEY, ID_LOTE BIGINT);
        MERGE SIS.Lote AS d
        USING (SELECT t.UNIDADE, COUNT(*) AS QTD FROM #T t WHERE t.REGRA = 'LOTE' GROUP BY t.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (ORIGEM, DESCRICAO, TABELA_REFERENCIA, QTD_REGISTROS, USUARIO_CRIACAO)
             VALUES ('MIGRACAO', N'Pagamento em lote do Access nº ' + SUBSTRING(s.UNIDADE, 3, 20), N'FIN.Lancamento', s.QTD, @Usuario)
        OUTPUT s.UNIDADE, inserted.ID_LOTE INTO #MapLote (UNIDADE, ID_LOTE);

        SET @EtapaAtual = 'Gravação: lançamentos';
        CREATE TABLE #MapLanc (ORIGEM VARCHAR(20), NUM INT, ID_LANCAMENTO BIGINT, PRIMARY KEY (ORIGEM, NUM));
        MERGE FIN.Lancamento AS d
        USING (SELECT t.*, ISNULL(ml.ID_LOTE, @IdLoteGeral) AS ID_LOTE FROM #T t LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (TIPO, ID_EMPRESA, ID_CENTRO_CUSTO, ID_PESSOA, ID_PLANO_CONTA, ID_HISTORICO_PADRAO, DOCUMENTO, DT_EMISSAO, DT_COMPETENCIA,
                                      HISTORICO, OBSERVACAO, VALOR_TOTAL, ORIGEM, ID_LOTE, INTEGRACAO, CODIGO_ACCESS, ORIGEM_ACCESS, USUARIO_CRIACAO)
             VALUES (s.TIPO, s.ID_EMPRESA, s.ID_CENTRO, s.ID_PESSOA, s.ID_PLANO, s.ID_HIST, s.DOCUMENTO, s.DT_EMISSAO, DATEFROMPARTS(YEAR(s.DT_EMISSAO), MONTH(s.DT_EMISSAO), 1),
                     s.HISTORICO, s.OBSERVACAO, s.VALOR, 'MIGRACAO', s.ID_LOTE, s.INTEGRACAO, s.NUM, s.ORIGEM, @Usuario)
        OUTPUT s.ORIGEM, s.NUM, inserted.ID_LANCAMENTO INTO #MapLanc (ORIGEM, NUM, ID_LANCAMENTO);

        SET @EtapaAtual = 'Gravação: parcelas';
        INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR, ID_CONTA_PREVISTA, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT m.ID_LANCAMENTO, 1, 1, t.DT_VENC, t.VALOR, t.ID_CONTA_PAG, ISNULL(ml.ID_LOTE, @IdLoteGeral), t.NUM, @Usuario
        FROM #T t
        INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE;

        SET @EtapaAtual = 'Gravação: movimentos das baixas';
        -- um movimento por saída/entrada (no lote, um só pelo total)
        SELECT t.PAG_ORIGEM, t.PAG_NUM, MIN(t.UNIDADE) AS UNIDADE, MIN(t.ID_CONTA_PAG) AS ID_CONTA, MIN(t.DT_PAG) AS DT,
               SUM(CASE WHEN t.TIPO = 'P' THEN -t.VALOR ELSE t.VALOR END) AS VALOR,
               CAST(LEFT(MIN(t.HIST_PAG), 200) AS NVARCHAR(200)) AS HISTORICO, CAST(LEFT(MIN(t.DOC_PAG), 40) AS NVARCHAR(40)) AS DOCUMENTO
        INTO #Mov
        FROM #T t
        WHERE t.GERA_MOV = 1
        GROUP BY t.PAG_ORIGEM, t.PAG_NUM;

        CREATE TABLE #MapMov (PAG_ORIGEM VARCHAR(20), PAG_NUM INT, ID_MOVIMENTO BIGINT, PRIMARY KEY (PAG_ORIGEM, PAG_NUM));
        MERGE BANCO.Movimento AS d
        USING (SELECT v.*, ISNULL(ml.ID_LOTE, @IdLoteGeral) AS ID_LOTE FROM #Mov v LEFT JOIN #MapLote ml ON ml.UNIDADE = v.UNIDADE) AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, DOCUMENTO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
             VALUES (s.ID_CONTA, s.DT, s.VALOR, 'BAIXA', s.HISTORICO, s.DOCUMENTO, s.ID_LOTE, s.PAG_NUM, @Usuario)
        OUTPUT s.PAG_ORIGEM, s.PAG_NUM, inserted.ID_MOVIMENTO INTO #MapMov (PAG_ORIGEM, PAG_NUM, ID_MOVIMENTO);

        SET @EtapaAtual = 'Gravação: baixas';
        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, ID_MOVIMENTO, COMPENSADO, DT_COMPENSACAO, OBSERVACAO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT p.ID_PARCELA, t.DT_PAG, t.ID_CONTA_PAG, CASE WHEN t.COMPENSADO = 0 THEN 'CHEQUE' ELSE 'OUTRA' END, t.VALOR, mm.ID_MOVIMENTO,
               t.COMPENSADO, CASE WHEN t.COMPENSADO = 1 THEN t.DT_PAG END,
               CAST(CASE WHEN t.SOI_PAG = 1 THEN N'Somente integração no Access: sem movimento no banco.' ELSE N'' END AS NVARCHAR(400)),
               ISNULL(ml.ID_LOTE, @IdLoteGeral), t.PAG_NUM, @Usuario
        FROM #T t
        INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        INNER JOIN FIN.Parcela p ON p.ID_LANCAMENTO = m.ID_LANCAMENTO
        LEFT JOIN #MapMov mm ON mm.PAG_ORIGEM = t.PAG_ORIGEM AND mm.PAG_NUM = t.PAG_NUM
        LEFT JOIN #MapLote ml ON ml.UNIDADE = t.UNIDADE
        WHERE t.PAGO = 1 AND t.ID_CONTA_PAG IS NOT NULL;

        SET @EtapaAtual = 'Gravação: abatimentos';
        INSERT INTO FIN.Baixa (ID_PARCELA, DT_PAGAMENTO, ID_CONTA, FORMA, VALOR_PRINCIPAL, ABATIMENTO, ID_MOVIMENTO, COMPENSADO, DT_COMPENSACAO,
                               OBSERVACAO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT p.ID_PARCELA, a.DT, a.ID_CONTA, 'OUTRA', a.VALOR, a.VALOR, NULL, 1, a.DT,
               CAST(LEFT(N'Abatimento sem dinheiro: "crédito" do Access nº ' + CONVERT(NVARCHAR(12), a.NUM) + N' (documento ' + a.UNIDADE + N'). '
                         + ISNULL(a.MOTIVO_TELA, N''), 400) AS NVARCHAR(400)),
               @IdLoteGeral, a.NUM, @Usuario
        FROM #Ab a
        INNER JOIN #MapLanc m ON m.ORIGEM = a.T_ORIGEM AND m.NUM = a.T_NUM
        INNER JOIN FIN.Parcela p ON p.ID_LANCAMENTO = m.ID_LANCAMENTO
        WHERE a.ERRO = N'';

        SET @EtapaAtual = 'Gravação: transferências';
        CREATE TABLE #MapTr (ORIGEM VARCHAR(20), NUM INT, ID_TRANSFERENCIA BIGINT, PRIMARY KEY (ORIGEM, NUM));
        MERGE FIN.Transferencia AS d
        USING #TR AS s ON 1 = 0
        WHEN NOT MATCHED THEN INSERT (DT_TRANSFERENCIA, ID_CONTA_ORIGEM, ID_CONTA_DESTINO, VALOR, HISTORICO, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
             VALUES (s.DT, s.ID_ORIGEM, s.ID_DESTINO, s.VALOR, s.HISTORICO, @IdLoteGeral, s.NUM, @Usuario)
        OUTPUT s.ORIGEM, s.NUM, inserted.ID_TRANSFERENCIA INTO #MapTr (ORIGEM, NUM, ID_TRANSFERENCIA);

        INSERT INTO BANCO.Movimento (ID_CONTA, DT_MOVIMENTO, VALOR, TIPO, HISTORICO, ID_TRANSFERENCIA, ID_LOTE, CODIGO_ACCESS, USUARIO_CRIACAO)
        SELECT x.ID_CONTA, r.DT, x.VALOR, 'TRANSFERENCIA', r.HISTORICO, mt.ID_TRANSFERENCIA, @IdLoteGeral, r.NUM, @Usuario
        FROM #TR r
        INNER JOIN #MapTr mt ON mt.ORIGEM = r.ORIGEM AND mt.NUM = r.NUM
        CROSS APPLY (VALUES (r.ID_ORIGEM, -r.VALOR), (r.ID_DESTINO, r.VALOR)) x (ID_CONTA, VALOR);

        SET @EtapaAtual = 'Gravação: destino das linhas';
        INSERT INTO MIG.Linha_Destino (ORIGEM, NUM, UNIDADE, REGRA, PAPEL, ID_LANCAMENTO, ID_MOVIMENTO, ID_TRANSFERENCIA, ID_CONTA, VALOR)
        SELECT l.ORIGEM, l.NUM, l.UNIDADE, u.REGRA,
               CASE WHEN tt.NUM IS NOT NULL THEN 'TITULO'
                    WHEN pg.PAG_NUM IS NOT NULL THEN 'PAGAMENTO'
                    WHEN tr.NUM IS NOT NULL OR tb.NUM IS NOT NULL THEN 'TRANSFERENCIA'
                    WHEN u.REGRA = 'CASO' THEN 'CASO'
                    ELSE 'CONTRAPARTIDA' END,
               ml.ID_LANCAMENTO,
               COALESCE(mm.ID_MOVIMENTO, mm2.ID_MOVIMENTO),
               COALESCE(mt.ID_TRANSFERENCIA, mt2.ID_TRANSFERENCIA),
               COALESCE(tt.ID_CONTA_PAG, pg.ID_CONTA, tr.ID_BANCO, tb.ID_BANCO),
               l.VALOR
        FROM #L l
        INNER JOIN #U u ON u.UNIDADE = l.UNIDADE
        LEFT JOIN #T tt ON tt.ORIGEM = l.ORIGEM AND tt.NUM = l.NUM
        LEFT JOIN #MapLanc ml ON ml.ORIGEM = l.ORIGEM AND ml.NUM = l.NUM
        LEFT JOIN (SELECT PAG_ORIGEM, PAG_NUM, MIN(ID_CONTA_PAG) AS ID_CONTA FROM #T GROUP BY PAG_ORIGEM, PAG_NUM) pg ON pg.PAG_ORIGEM = l.ORIGEM AND pg.PAG_NUM = l.NUM AND tt.NUM IS NULL
        LEFT JOIN #MapMov mm ON mm.PAG_ORIGEM = l.ORIGEM AND mm.PAG_NUM = l.NUM
        LEFT JOIN #MapMov mm2 ON mm2.PAG_ORIGEM = tt.PAG_ORIGEM AND mm2.PAG_NUM = tt.PAG_NUM AND mm.ID_MOVIMENTO IS NULL
        LEFT JOIN #TR tr ON tr.ORIGEM = l.ORIGEM AND tr.NUM = l.NUM
        LEFT JOIN #TR tb ON tb.BCO_ORIGEM = l.ORIGEM AND tb.BCO_NUM = l.NUM
        LEFT JOIN #MapTr mt ON mt.ORIGEM = l.ORIGEM AND mt.NUM = l.NUM
        LEFT JOIN #MapTr mt2 ON mt2.ORIGEM = tb.ORIGEM AND mt2.NUM = tb.NUM;

        INSERT INTO MIG.Linha_Destino (ORIGEM, NUM, UNIDADE, REGRA, PAPEL, ID_LANCAMENTO, ID_MOVIMENTO, ID_TRANSFERENCIA, ID_CONTA, VALOR)
        SELECT v.ORIGEM, v.NUM, a.UNIDADE, 'ABATER', 'ABATIMENTO', m.ID_LANCAMENTO, NULL, NULL, a.ID_CONTA,
               ISNULL(mv.VALOR_DEBITO, 0) + ISNULL(mv.VALOR_CREDITO, 0)
        FROM #Ab a
        INNER JOIN #MapLanc m ON m.ORIGEM = a.T_ORIGEM AND m.NUM = a.T_NUM
        INNER JOIN MIG.vw_MIG_Linha_Unidade v ON v.UNIDADE = a.UNIDADE
        INNER JOIN MIG.Movimento mv ON mv.ORIGEM = v.ORIGEM AND mv.NUM = v.NUM
        WHERE a.ERRO = N''
          AND NOT EXISTS (SELECT 1 FROM MIG.Linha_Destino d WHERE d.ORIGEM = v.ORIGEM AND d.NUM = v.NUM);

        INSERT INTO MIG.DePara_Venda (ID_LANCAMENTO, ORIGEM, NUM, LINK_VENDA, IMOVEL, PARCEIRO, CONTRATO, NUM_DOC)
        SELECT m.ID_LANCAMENTO, t.ORIGEM, t.NUM, ISNULL(t.LINK_VENDA, 0), t.IMOVEL, t.PAR, ISNULL(t.CONTRATO, ''), CAST(LEFT(ISNULL(t.NUM_DOC, N''), 100) AS NVARCHAR(100))
        FROM #T t INNER JOIN #MapLanc m ON m.ORIGEM = t.ORIGEM AND m.NUM = t.NUM
        WHERE t.REGRA = 'VENDA';

        UPDATE SIS.Lote SET QTD_REGISTROS = (SELECT COUNT(*) FROM FIN.Lancamento l WHERE l.ID_LOTE = @IdLoteGeral) WHERE ID_LOTE = @IdLoteGeral;

        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;

        SELECT 'GRAVADO' AS GRADE, r.ORDEM, r.ITEM, r.QTD, r.VALOR
        FROM (
            SELECT 1 AS ORDEM, N'Lançamentos a pagar' AS ITEM, COUNT(*) AS QTD, SUM(l.VALOR_TOTAL) AS VALOR FROM FIN.Lancamento l WHERE l.ORIGEM = 'MIGRACAO' AND l.TIPO = 'P'
            UNION ALL SELECT 2, N'Lançamentos a receber', COUNT(*), SUM(l.VALOR_TOTAL) FROM FIN.Lancamento l WHERE l.ORIGEM = 'MIGRACAO' AND l.TIPO = 'R'
            UNION ALL SELECT 3, N'Parcelas em aberto', COUNT(*), SUM(p.SALDO) FROM FIN.Parcela p INNER JOIN FIN.Lancamento l ON l.ID_LANCAMENTO = p.ID_LANCAMENTO WHERE l.ORIGEM = 'MIGRACAO' AND p.SALDO > 0
            UNION ALL SELECT 4, N'Baixas', COUNT(*), SUM(b.VALOR_LIQUIDO) FROM FIN.Baixa b INNER JOIN SIS.Lote x ON x.ID_LOTE = b.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 5, N'Movimentos de baixa (banco/caixa)', COUNT(*), SUM(m.VALOR) FROM BANCO.Movimento m INNER JOIN SIS.Lote x ON x.ID_LOTE = m.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO' AND m.TIPO = 'BAIXA'
            UNION ALL SELECT 6, N'Transferências', COUNT(*), SUM(t.VALOR) FROM FIN.Transferencia t INNER JOIN SIS.Lote x ON x.ID_LOTE = t.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 7, N'Lotes do Access', COUNT(*) - 1, NULL FROM SIS.Lote x WHERE x.ORIGEM = 'MIGRACAO'
            UNION ALL SELECT 8, N'Abatimentos de parcela (sem dinheiro)', COUNT(*), SUM(b.ABATIMENTO) FROM FIN.Baixa b INNER JOIN SIS.Lote x ON x.ID_LOTE = b.ID_LOTE WHERE x.ORIGEM = 'MIGRACAO' AND b.ABATIMENTO > 0
            UNION ALL SELECT 9, N'Casos para a tela', COUNT(*), SUM(c.VALOR_DEBITO + c.VALOR_CREDITO) FROM MIG.Caso c WHERE c.REGRA_ATUAL = 'CASO'
        ) r ORDER BY r.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DROP TABLE IF EXISTS #L, #U, #CentroAdm, #Caixa, #CxContabil, #T, #TR, #MapLote, #MapLanc, #MapParc, #Mov, #MapMov, #MapTr, #Hist, #Dec, #CasoNovo, #Rev, #Sel, #Ab;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Movimento_Conferencia_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Movimento_Conferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Conferência da transformação do movimento (etapa 03c2, parte B),
                Access x sistema novo. Grades:
                  1. RESUMO: linhas do Access por regra e papel (título,
                     pagamento, contrapartida, transferência, caso);
                  2. TITULOS_ANO: títulos do Access x lançamentos gravados, por
                     ano e tipo (valor, pagos, em aberto) - a diferença tem de
                     ser zero;
                  3. CONTAS: por conta, o que o Access tinha nas linhas de banco e
                     caixinha x movimentos gravados (baixas e transferências);
                     a diferença é explicada pelas transferências dos lançamentos
                     soltos e pelas baixas "somente integração";
                  4. EMPRESAS: lançamentos por empresa;
                  5. CASOS: documentos para a tela de correção.
                Só leitura.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, parte B).
    v1.1 (18/11/2026) - Casos: só os que ainda não se encaixam, mais a grade
                        CASOS_SITUACAO (pendentes, corrigidos, ignorados, arquivo morto).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Movimento_Conferencia_Listar]
AS
BEGIN
    SET NOCOUNT ON;

    /* 1. Resumo */
    SELECT 'RESUMO' AS GRADE, d.REGRA, d.PAPEL, COUNT(DISTINCT d.UNIDADE) AS DOCUMENTOS, COUNT(*) AS LINHAS, SUM(d.VALOR) AS VALOR
    FROM MIG.Linha_Destino d
    GROUP BY d.REGRA, d.PAPEL
    UNION ALL
    SELECT 'RESUMO', 'IGNORADA', 'CORRECAO', COUNT(DISTINCT m.UNIDADE), COUNT(*), SUM(m.VALOR_DEBITO + m.VALOR_CREDITO)
    FROM MIG.Movimento m
    WHERE m.DESTINO = 'SISTEMA' AND NOT EXISTS (SELECT 1 FROM MIG.Linha_Destino d WHERE d.ORIGEM = m.ORIGEM AND d.NUM = m.NUM)
    ORDER BY 2, 3;

    /* 2. Títulos por ano: Access x sistema */
    SELECT 'TITULOS_ANO' AS GRADE, YEAR(l.DT_EMISSAO) AS ANO, l.TIPO,
           COUNT(*) AS LANCAMENTOS,
           SUM(m.VALOR_DEBITO + m.VALOR_CREDITO) AS VALOR_ACCESS,
           SUM(l.VALOR_TOTAL) AS VALOR_SISTEMA,
           SUM(l.VALOR_TOTAL) - SUM(m.VALOR_DEBITO + m.VALOR_CREDITO) AS DIFERENCA,
           SUM(p.VALOR_BAIXADO) AS PAGO, SUM(p.SALDO) AS EM_ABERTO
    FROM MIG.Linha_Destino d
    INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
    INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = d.ID_LANCAMENTO
    INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_LANCAMENTO = l.ID_LANCAMENTO
    WHERE d.PAPEL = 'TITULO'
    GROUP BY YEAR(l.DT_EMISSAO), l.TIPO
    ORDER BY 2, 3;

    /* 3. Contas */
    ;WITH Acc AS
    (
        SELECT d.ID_CONTA,
               SUM(CASE WHEN m.CONTA NOT IN (1, 2, 3) THEN m.VALOR_CREDITO - m.VALOR_DEBITO ELSE 0 END) AS ACCESS_BANCO_CAIXINHA,
               SUM(CASE WHEN m.CONTA NOT IN (1, 2, 3) AND m.SOMENTE_INTEGRACAO = 1 THEN m.VALOR_CREDITO - m.VALOR_DEBITO ELSE 0 END) AS ACCESS_SOMENTE_INTEGRACAO
        FROM MIG.Linha_Destino d
        INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
        WHERE d.PAPEL IN ('PAGAMENTO', 'TITULO') AND d.ID_CONTA IS NOT NULL AND m.CONTA NOT IN (1, 2, 3)
          AND (d.PAPEL = 'PAGAMENTO' OR d.REGRA = 'AVULSO')
        GROUP BY d.ID_CONTA
    ),
    Novo AS
    (
        SELECT mv.ID_CONTA,
               SUM(CASE WHEN mv.TIPO = 'BAIXA' THEN mv.VALOR ELSE 0 END) AS NOVO_BAIXAS,
               SUM(CASE WHEN mv.TIPO = 'TRANSFERENCIA' THEN mv.VALOR ELSE 0 END) AS NOVO_TRANSFERENCIAS
        FROM BANCO.Movimento mv WITH (NOLOCK)
        INNER JOIN SIS.Lote x WITH (NOLOCK) ON x.ID_LOTE = mv.ID_LOTE
        WHERE x.ORIGEM = 'MIGRACAO'
        GROUP BY mv.ID_CONTA
    )
    SELECT 'CONTAS' AS GRADE, e.NOME_FANTASIA AS EMPRESA, k.DESCRICAO AS CONTA, k.TIPO,
           ISNULL(a.ACCESS_BANCO_CAIXINHA, 0) AS ACCESS_BANCO_CAIXINHA,
           ISNULL(a.ACCESS_SOMENTE_INTEGRACAO, 0) AS ACCESS_SOMENTE_INTEGRACAO,
           ISNULL(n.NOVO_BAIXAS, 0) AS NOVO_BAIXAS,
           ISNULL(n.NOVO_TRANSFERENCIAS, 0) AS NOVO_TRANSFERENCIAS,
           ISNULL(n.NOVO_BAIXAS, 0) - (ISNULL(a.ACCESS_BANCO_CAIXINHA, 0) - ISNULL(a.ACCESS_SOMENTE_INTEGRACAO, 0)) AS DIFERENCA_BAIXAS
    FROM BANCO.Conta k WITH (NOLOCK)
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = k.ID_EMPRESA
    LEFT JOIN Acc a ON a.ID_CONTA = k.ID_CONTA
    LEFT JOIN Novo n ON n.ID_CONTA = k.ID_CONTA
    WHERE a.ID_CONTA IS NOT NULL OR n.ID_CONTA IS NOT NULL
    ORDER BY e.NOME_FANTASIA, k.DESCRICAO;

    /* 4. Empresas */
    SELECT 'EMPRESAS' AS GRADE, e.NOME_FANTASIA AS EMPRESA, l.TIPO, COUNT(*) AS LANCAMENTOS, SUM(l.VALOR_TOTAL) AS VALOR,
           SUM(p.VALOR_BAIXADO) AS PAGO, SUM(p.SALDO) AS EM_ABERTO,
           SUM(CASE WHEN l.ID_PESSOA IS NULL THEN 1 ELSE 0 END) AS SEM_PESSOA,
           SUM(CASE WHEN l.ID_PLANO_CONTA IS NULL THEN 1 ELSE 0 END) AS SEM_PLANO
    FROM FIN.Lancamento l WITH (NOLOCK)
    INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_LANCAMENTO = l.ID_LANCAMENTO
    INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
    WHERE l.ORIGEM = 'MIGRACAO'
    GROUP BY e.NOME_FANTASIA, l.TIPO
    ORDER BY e.NOME_FANTASIA, l.TIPO;

    /* 5. Casos */
    SELECT 'CASOS' AS GRADE, c.MOTIVO, COUNT(*) AS DOCUMENTOS, SUM(c.LINHAS) AS LINHAS, SUM(c.VALOR_DEBITO) AS DEBITOS, SUM(c.VALOR_CREDITO) AS CREDITOS,
           MIN(c.DT_DOCUMENTO) AS DE, MAX(c.DT_DOCUMENTO) AS ATE
    FROM MIG.Caso c
    WHERE c.REGRA_ATUAL = 'CASO'
    GROUP BY c.MOTIVO
    ORDER BY COUNT(*) DESC;

    SELECT 'CASOS_SITUACAO' AS GRADE, c.REGRA_ATUAL, COUNT(*) AS DOCUMENTOS, SUM(c.VALOR_DEBITO + c.VALOR_CREDITO) AS VALOR
    FROM MIG.Caso c
    GROUP BY c.REGRA_ATUAL
    ORDER BY c.REGRA_ATUAL;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Listar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Lista da tela "Casos da migração" (MIG_CASOS): um documento do
                Access por linha (MIG.Caso: os que não se encaixam e os que já
                têm correção), com obra, histórico, motivo, valores e
                situação: PENDENTE, EM_CORRECAO (corrigido mas ainda não se
                encaixa), RESOLVIDO (corrigido e já se encaixa), IGNORADO,
                ARQUIVO_MORTO. Filtros e totais ficam na tela (são poucos
                documentos). Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
    v1.1 (18/11/2026) - Situação REVISAR (o Access mudou depois da correção) e
                        coluna REVISAR com o aviso.
    v1.2 (19/11/2026) - Empresa e histórico também para documento formado por
                        troca de lote (lote novo da migração).
    v1.3 (19/11/2026) - EM_ABERTO: o documento tem linha sem pagamento
                        (não confirmada e sem data de pagamento, com as
                        correções da tela). Estes precisam ser resolvidos antes
                        da virada (decisão do Celso, 19/11/2026); os demais podem
                        ficar para depois da instalação.

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Listar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.UNIDADE,
               CASE LEFT(c.UNIDADE, 1) WHEN 'L' THEN N'Lote ' WHEN 'V' THEN N'Venda ' ELSE N'Documento ' END
                 + SUBSTRING(c.UNIDADE, CHARINDEX(':', c.UNIDADE) + 1, 40) AS DOCUMENTO,
               c.DT_DOCUMENTO, YEAR(c.DT_DOCUMENTO) AS ANO,
               ISNULL(nv.NOME, N'') AS EMPRESA,
               ISNULL(NULLIF(pl.COMPLEMENTO, N''), ISNULL(h.DESCRICAO, N'')) AS HISTORICO,
               CASE WHEN c.REGRA_ATUAL = 'CASO' THEN c.MOTIVO ELSE c.MOTIVO_ORIGINAL END AS MOTIVO,
               c.MOTIVO_ORIGINAL, c.DETALHE, c.REGRA_ATUAL, c.LINHAS,
               c.VALOR_DEBITO, c.VALOR_CREDITO, c.VALOR_DEBITO - c.VALOR_CREDITO AS DIFERENCA,
               CASE WHEN c.REVISAR <> N'' THEN 'REVISAR'
                    WHEN c.REGRA_ATUAL = 'IGNORAR' THEN 'IGNORADO'
                    WHEN c.REGRA_ATUAL = 'ARQUIVO_MORTO' THEN 'ARQUIVO_MORTO'
                    WHEN c.REGRA_ATUAL = 'CASO' AND k.QTD > 0 THEN 'EM_CORRECAO'
                    WHEN c.REGRA_ATUAL = 'CASO' THEN 'PENDENTE'
                    ELSE 'RESOLVIDO' END AS SITUACAO,
               ISNULL(k.QTD, 0) AS LINHAS_CORRIGIDAS,
               COALESCE(cc.USUARIO_ALTERACAO, cc.USUARIO_CRIACAO, k.USUARIO, N'') AS CORRIGIDO_POR,
               COALESCE(cc.DT_ALTERACAO, cc.DT_CRIACAO, k.DT) AS CORRIGIDO_EM,
               c.REVISAR,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM MIG.fn_MIG_Linhas_Documento(c.UNIDADE) d
                                      INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
                                      LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
                                      WHERE ISNULL(o.IGNORAR_LINHA, 0) = 0
                                        AND COALESCE(o.CONFIRMADO, m.CONFIRMADO) = 0
                                        AND NULLIF(COALESCE(o.DT_PAGTO, m.DT_PAGTO), '1900-01-01') IS NULL
                                        AND COALESCE(o.VALOR_DEBITO, m.VALOR_DEBITO) + COALESCE(o.VALOR_CREDITO, m.VALOR_CREDITO) > 0)
                         THEN 1 ELSE 0 END AS BIT) AS EM_ABERTO
        FROM MIG.Caso c
        OUTER APPLY (SELECT TOP (1) COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS EV, m.COMPLEMENTO, m.HISTORICO
                     FROM MIG.fn_MIG_Linhas_Documento(c.UNIDADE) d
                     INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
                     LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
                     ORDER BY CASE WHEN m.COMPLEMENTO <> N'' THEN 0 ELSE 1 END, m.NUM) pl
        OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(v.NomeVinculada)) AS NOME FROM MIG.Access_EmpVinculada v WHERE TRY_CONVERT(INT, v.CodigoVinculada) = pl.EV) nv
        OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS DESCRICAO FROM MIG.Access_Historico x WHERE TRY_CONVERT(INT, x.CodHistorico) = pl.HISTORICO) h
        OUTER APPLY (SELECT COUNT(*) AS QTD, MAX(COALESCE(o.USUARIO_ALTERACAO, o.USUARIO_CRIACAO)) AS USUARIO, MAX(COALESCE(o.DT_ALTERACAO, o.DT_CRIACAO)) AS DT
                     FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = c.UNIDADE) k
        LEFT JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = c.UNIDADE
        ORDER BY c.DT_DOCUMENTO, c.UNIDADE;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar os casos da migração. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Obter.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Um caso da tela "Casos da migração": cabeçalho (motivo, situação,
                decisão gravada) e as linhas do Access (LINHAS_JSON), cada uma
                com o valor original e o valor em uso (original + correção da
                tela) de obra, pessoa, conta, plano, datas, valores e
                confirmado, já com os nomes do Access. Data corrigida para
                01/01/1900 = "sem data". Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
    v1.1 (18/11/2026) - Aviso REVISAR no cabeçalho e "mudou" em cada linha
                        alterada no Access depois da correção.
    v1.2 (18/11/2026) - Lote da linha (original e em uso).
    v1.3 (19/11/2026) - Linhas do documento: as do Access e as que vieram por
                        troca de lote; PROXIMO_LOTE_NOVO (lote novo da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Obter @IdUsuario = 1, @Unidade = 'L:123';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Obter]
    @IdUsuario  INT,
    @Unidade    VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = @Unidade)
            THROW 50001, N'Caso não encontrado. Atualize a lista.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.UNIDADE, c.REGRA_ATUAL, c.REVISAR, c.MOTIVO, c.MOTIVO_ORIGINAL, c.DETALHE, c.PADRAO, c.DT_DOCUMENTO, c.DT_CALCULO,
               ISNULL(cc.ACAO, '') AS ACAO, ISNULL(cc.MOTIVO, N'') AS ACAO_MOTIVO,
               COALESCE(cc.USUARIO_ALTERACAO, cc.USUARIO_CRIACAO, N'') AS ACAO_USUARIO, COALESCE(cc.DT_ALTERACAO, cc.DT_CRIACAO) AS ACAO_DT,
               (SELECT CASE WHEN ISNULL(MAX(o.LOTE), 0) < 900000 THEN 900001 ELSE MAX(o.LOTE) + 1 END
                FROM MIG.Caso_Correcao_Linha o WHERE o.LOTE >= 900000) AS PROXIMO_LOTE_NOVO,
               ISNULL((SELECT TOP (1) o.MOTIVO FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = c.UNIDADE AND o.MOTIVO <> N''
                       ORDER BY COALESCE(o.DT_ALTERACAO, o.DT_CRIACAO) DESC), N'') AS CORRECAO_MOTIVO,
               ISNULL((
                   SELECT m.ORIGEM AS origem, m.NUM AS num, m.TIPO_CONTA AS tipoConta, m.LADO AS lado,
                          m.NUM_DOC AS numDoc, m.COMPLEMENTO AS complemento, ISNULL(h.DESCRICAO, N'') AS historico,
                          m.EMP_VINCULADA AS empOrig, COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS emp, ISNULL(nv.NOME, N'') AS empNome,
                          m.PARCEIRO AS parceiroOrig, COALESCE(o.PARCEIRO, m.PARCEIRO) AS parceiro, ISNULL(np.NOME, N'') AS parceiroNome,
                          m.CONTA AS contaOrig, COALESCE(o.CONTA, m.CONTA) AS conta, ISNULL(nc.NOME, N'') AS contaNome,
                          m.PLANO3 AS planoOrig, COALESCE(o.PLANO3, m.PLANO3) AS plano, ISNULL(npl.NOME, N'') AS planoNome,
                          m.DT_MOVTO AS dtMovtoOrig, NULLIF(COALESCE(o.DT_MOVTO, m.DT_MOVTO), '1900-01-01') AS dtMovto,
                          m.DT_VENCTO AS dtVenctoOrig, NULLIF(COALESCE(o.DT_VENCTO, m.DT_VENCTO), '1900-01-01') AS dtVencto,
                          m.DT_PAGTO AS dtPagtoOrig, NULLIF(COALESCE(o.DT_PAGTO, m.DT_PAGTO), '1900-01-01') AS dtPagto,
                          m.VALOR_DEBITO AS debitoOrig, COALESCE(o.VALOR_DEBITO, m.VALOR_DEBITO) AS debito,
                          m.VALOR_CREDITO AS creditoOrig, COALESCE(o.VALOR_CREDITO, m.VALOR_CREDITO) AS credito,
                          m.CONFIRMADO AS confirmadoOrig, COALESCE(o.CONFIRMADO, m.CONFIRMADO) AS confirmado,
                          m.LOTE AS loteOrig, COALESCE(o.LOTE, m.LOTE) AS lote,
                          m.EFETUADO AS efetuado, m.SOMENTE_INTEGRACAO AS somenteIntegracao,
                          ISNULL(o.IGNORAR_LINHA, CAST(0 AS BIT)) AS ignorar,
                          CAST(CASE WHEN o.ID_CASO_CORRECAO_LINHA IS NULL THEN 0 ELSE 1 END AS BIT) AS corrigida,
                          CAST(CASE WHEN o.HASH_ACCESS IS NOT NULL AND o.HASH_ACCESS <> m.HASH_CONTEUDO THEN 1 ELSE 0 END AS BIT) AS mudou
                   FROM MIG.Movimento m
                   LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS DESCRICAO FROM MIG.Access_Historico x WHERE TRY_CONVERT(INT, x.CodHistorico) = m.HISTORICO) h
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(v.NomeVinculada)) AS NOME FROM MIG.Access_EmpVinculada v WHERE TRY_CONVERT(INT, v.CodigoVinculada) = COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA)) nv
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.NomeParceiro)) AS NOME FROM MIG.Access_Parceiros x WHERE TRY_CONVERT(INT, x.CodigoParceiro) = COALESCE(o.PARCEIRO, m.PARCEIRO)) np
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS NOME FROM MIG.Access_Contas_Financeiras x WHERE TRY_CONVERT(INT, x.CodigoConta) = COALESCE(o.CONTA, m.CONTA)) nc
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.DescricaoPlano3)) AS NOME FROM MIG.Access_Plano3 x WHERE TRY_CONVERT(INT, x.Plano3) = COALESCE(o.PLANO3, m.PLANO3)) npl
                   WHERE EXISTS (SELECT 1 FROM MIG.fn_MIG_Linhas_Documento(c.UNIDADE) d WHERE d.ORIGEM = m.ORIGEM AND d.NUM = m.NUM)
                   ORDER BY m.DT_MOVTO, m.NUM
                   FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS LINHAS_JSON
        FROM MIG.Caso c
        LEFT JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = c.UNIDADE
        WHERE c.UNIDADE = @Unidade;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar o caso. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Opcoes.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Opcoes]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Listas de escolha da tela "Casos da migração", com os códigos e
                nomes do Access: obras (só as que têm de-para), contas, planos
                (só os que têm de-para) e pessoas. Uma linha com quatro colunas
                JSON. Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Opcoes @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Opcoes]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Opcoes]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, v.CodigoVinculada) AS c, MIN(LTRIM(RTRIM(v.NomeVinculada))) AS n
                                          FROM MIG.Access_EmpVinculada v
                                          WHERE EXISTS (SELECT 1 FROM MIG.DePara_Centro d WHERE d.CODIGO_VINCULADA = TRY_CONVERT(INT, v.CodigoVinculada))
                                          GROUP BY TRY_CONVERT(INT, v.CodigoVinculada)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS OBRAS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, k.CodigoConta) AS c, MIN(LTRIM(RTRIM(k.Descricao))) AS n
                                          FROM MIG.Access_Contas_Financeiras k
                                          WHERE TRY_CONVERT(INT, k.CodigoConta) IS NOT NULL
                                          GROUP BY TRY_CONVERT(INT, k.CodigoConta)) x
                    ORDER BY x.c FOR JSON PATH), N'[]') AS CONTAS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, p.Plano3) AS c, MIN(LTRIM(RTRIM(p.DescricaoPlano3))) AS n
                                          FROM MIG.Access_Plano3 p
                                          WHERE EXISTS (SELECT 1 FROM MIG.DePara_Plano d WHERE d.PLANO3_ACCESS = TRY_CONVERT(INT, p.Plano3))
                                          GROUP BY TRY_CONVERT(INT, p.Plano3)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS PLANOS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, p.CodigoParceiro) AS c, MIN(LTRIM(RTRIM(p.NomeParceiro))) AS n
                                          FROM MIG.Access_Parceiros p
                                          WHERE TRY_CONVERT(INT, p.CodigoParceiro) > 1
                                          GROUP BY TRY_CONVERT(INT, p.CodigoParceiro)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS PESSOAS_JSON;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar as listas da tela. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Grava a decisão da tela "Casos da migração" para um documento
                do Access (unidade). @Acao:
                  CORRIGIR       correções linha a linha (@LinhasJson: os
                                 valores em uso de cada linha; só o que for
                                 diferente do Access é guardado, em
                                 MIG.Caso_Correcao_Linha); tira a decisão
                                 IGNORAR/ARQUIVO_MORTO, se houver;
                  IGNORAR        o documento não migra (motivo obrigatório);
                  ARQUIVO_MORTO  o documento vai para o arquivo morto (motivo
                                 obrigatório);
                  ABATER         o documento é um "crédito" manual que abate a
                                 parcela da venda @LinkVenda (código da venda
                                 no Access): vira baixa só de abatimento, sem
                                 dinheiro (motivo obrigatório);
                  DESFAZER       apaga todas as correções e decisões do
                                 documento (volta ao Access).
                As correções valem em toda nova rodada da migração. Depois de
                gravar, a tela chama MIG_Caso_Conferir para mostrar se o
                documento passou a se encaixar.
                Datas: em @LinhasJson, data vazia onde o Access tinha data é
                guardada como 01/01/1900 (= "sem data" para a migração).
                Permissão: ALTERAR em MIG_CASOS (os dois administradores).
                Devolve SUCESSO, MENSAGEM, ID (padrão das gravações).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
    v1.1 (18/11/2026) - Guarda a impressão digital do Access (HASH_ACCESS) da
                        linha ou do documento; gravar de novo um caso marcado
                        "Revisar" atualiza a impressão e tira o aviso.
    v1.2 (18/11/2026) - Troca de lote ($.lote): 0 tira a linha do lote; outro
                        número precisa ser um lote que existe no Access; vazio
                        mantém o do Access.
    v1.3 (19/11/2026) - Lote novo da migração: número de 900001 em diante não
                        precisa existir no Access. Documento formado por troca
                        de lote também pode ser corrigido (linhas que vieram de
                        outro lote).
    v1.4 (23/11/2026) - Etapa 03f2: ação ABATER com @LinkVenda (venda/parcela do
                        Access que o "crédito" abate; precisa existir entre as
                        linhas que migram).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Gravar @IdUsuario = 1, @Unidade = 'L:123', @Acao = 'IGNORAR', @Motivo = N'Lançado em dobro no Access';
    -- EXEC MIG.MIG_Caso_Gravar @IdUsuario = 1, @Unidade = 'L:123', @Acao = 'DESFAZER';
    -- EXEC MIG.MIG_Caso_Gravar @IdUsuario = 1, @Unidade = 'A:M:308074', @Acao = 'ABATER', @LinkVenda = 14662, @Motivo = N'Crédito que abate a parcela 23';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Gravar]
    @IdUsuario   INT,
    @Unidade     VARCHAR(40),
    @Acao        VARCHAR(15),
    @Motivo      NVARCHAR(400) = N'',
    @LinhasJson  NVARCHAR(MAX) = NULL,
    @LinkVenda   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @SemData    DATE = '1900-01-01';
    DECLARE @Qtd        INT  = 0;
    DECLARE @HashDoc    VARBINARY(32);

    BEGIN TRY
        DROP TABLE IF EXISTS #J, #C;
        SET @Acao   = UPPER(LTRIM(RTRIM(ISNULL(@Acao, ''))));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para corrigir os casos da migração.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = @Unidade)
            SET @Recusa = N'Caso não encontrado. Atualize a lista.';
        IF @Recusa = N'' AND @Acao NOT IN ('CORRIGIR', 'IGNORAR', 'ARQUIVO_MORTO', 'ABATER', 'DESFAZER')
            SET @Recusa = N'Ação inválida.';
        IF @Recusa = N'' AND @Acao IN ('IGNORAR', 'ARQUIVO_MORTO', 'ABATER') AND LEN(@Motivo) < 5
            SET @Recusa = N'Escreva o motivo da decisão (pelo menos 5 letras).';
        IF @Recusa = N'' AND @Acao = 'CORRIGIR' AND ISJSON(ISNULL(@LinhasJson, N'')) = 0
            SET @Recusa = N'Lista de linhas inválida.';
        IF @Recusa = N'' AND @Acao = 'ABATER' AND ISNULL(@LinkVenda, 0) <= 0
            SET @Recusa = N'Informe a venda (parcela) que o crédito abate.';
        IF @Recusa = N'' AND @Acao = 'ABATER'
           AND NOT EXISTS (SELECT 1 FROM MIG.Movimento m WHERE m.LINK_VENDA = @LinkVenda AND m.DESTINO = 'SISTEMA')
            SET @Recusa = N'A venda informada não existe entre os documentos que migram.';
        IF @Recusa = N'' AND @Acao = 'ABATER' AND @Unidade = 'V:' + CONVERT(VARCHAR(20), @LinkVenda)
            SET @Recusa = N'O documento não pode abater a si mesmo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        IF @Acao <> 'ABATER' SET @LinkVenda = NULL;

        IF @Acao = 'CORRIGIR'
        BEGIN
            SET @EtapaAtual = 'Leitura das linhas';
            SELECT j.origem AS ORIGEM, j.num AS NUM, j.emp AS EMP, j.parceiro AS PARCEIRO, j.conta AS CONTA, j.plano AS PLANO,
                   j.dtMovto AS DT_MOVTO, j.dtVencto AS DT_VENCTO, j.dtPagto AS DT_PAGTO,
                   ISNULL(j.debito, 0) AS DEB, ISNULL(j.credito, 0) AS CRE, ISNULL(j.confirmado, 0) AS CONF, ISNULL(j.ignorar, 0) AS IGN,
                   j.lote AS LOTE
            INTO #J
            FROM OPENJSON(@LinhasJson) WITH (
                    origem VARCHAR(20) '$.origem', num INT '$.num', emp INT '$.emp', parceiro INT '$.parceiro', conta INT '$.conta',
                    plano INT '$.plano', dtMovto DATE '$.dtMovto', dtVencto DATE '$.dtVencto', dtPagto DATE '$.dtPagto',
                    debito DECIMAL(18,2) '$.debito', credito DECIMAL(18,2) '$.credito', confirmado BIT '$.confirmado', ignorar BIT '$.ignorar',
                    lote INT '$.lote') j;

            IF EXISTS (SELECT 1 FROM #J j WHERE NOT EXISTS (SELECT 1 FROM MIG.fn_MIG_Linhas_Documento(@Unidade) d WHERE d.ORIGEM = j.ORIGEM AND d.NUM = j.NUM))
                SET @Recusa = N'Uma das linhas não pertence a este documento. Atualize a tela.';
            -- só o que mudou em relação ao Access precisa existir no de-para (o Access pode ter código sem de-para)
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE (j.EMP IS NULL AND m.EMP_VINCULADA IS NOT NULL)
                                            OR (j.EMP <> ISNULL(m.EMP_VINCULADA, -1) AND NOT EXISTS (SELECT 1 FROM MIG.DePara_Centro d WHERE d.CODIGO_VINCULADA = j.EMP)))
                SET @Recusa = N'Escolha uma obra válida em todas as linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE (j.CONTA IS NULL AND m.CONTA IS NOT NULL)
                                            OR (j.CONTA <> ISNULL(m.CONTA, -1) AND NOT EXISTS (SELECT 1 FROM MIG.Access_Contas_Financeiras k WHERE TRY_CONVERT(INT, k.CodigoConta) = j.CONTA)))
                SET @Recusa = N'Escolha uma conta válida em todas as linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE (j.PLANO IS NULL AND m.PLANO3 IS NOT NULL)
                                            OR (j.PLANO <> ISNULL(m.PLANO3, -1) AND NOT EXISTS (SELECT 1 FROM MIG.DePara_Plano d WHERE d.PLANO3_ACCESS = j.PLANO)))
                SET @Recusa = N'Escolha um plano de contas válido nas linhas.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE j.PARCEIRO > 1 AND j.PARCEIRO <> ISNULL(m.PARCEIRO, 0) AND NOT EXISTS (SELECT 1 FROM MIG.Access_Parceiros p WHERE TRY_CONVERT(INT, p.CodigoParceiro) = j.PARCEIRO))
                SET @Recusa = N'Pessoa não encontrada no cadastro do Access.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.LOTE < 0)
                SET @Recusa = N'Lote inválido: use 0 para tirar a linha do lote.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM
                                         WHERE j.LOTE > 0 AND j.LOTE < 900000 AND j.LOTE <> m.LOTE
                                           AND NOT EXISTS (SELECT 1 FROM MIG.Movimento x WHERE x.LOTE = j.LOTE AND x.DESTINO = 'SISTEMA'))
                SET @Recusa = N'Lote não encontrado no Access. Confira o número; para separar linhas num lote novo, use um número a partir de 900001.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.DEB < 0 OR j.CRE < 0)
                SET @Recusa = N'Valor não pode ser negativo.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.DEB > 0 AND j.CRE > 0)
                SET @Recusa = N'Cada linha tem débito ou crédito, não os dois.';
            IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #J j WHERE j.DT_MOVTO NOT BETWEEN '2000-01-01' AND '2060-12-31'
                                                             OR j.DT_VENCTO NOT BETWEEN '2000-01-01' AND '2060-12-31'
                                                             OR j.DT_PAGTO NOT BETWEEN '2000-01-01' AND '2060-12-31')
                SET @Recusa = N'Data fora do intervalo aceito (2000 a 2060).';
            IF @Recusa <> N''
            BEGIN
                DROP TABLE IF EXISTS #J;
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
                RETURN;
            END;

            -- só o que difere do Access vira correção (NULL = mantém o Access)
            SELECT j.ORIGEM, j.NUM,
                   CASE WHEN j.EMP = m.EMP_VINCULADA THEN NULL ELSE j.EMP END AS EMP_VINCULADA,
                   CASE WHEN ISNULL(j.PARCEIRO, 0) = ISNULL(m.PARCEIRO, 0) THEN NULL ELSE ISNULL(j.PARCEIRO, 0) END AS PARCEIRO,
                   CASE WHEN j.CONTA = m.CONTA THEN NULL ELSE j.CONTA END AS CONTA,
                   CASE WHEN j.PLANO = m.PLANO3 OR (j.PLANO IS NULL AND m.PLANO3 IS NULL) THEN NULL ELSE j.PLANO END AS PLANO3,
                   CASE WHEN j.DT_MOVTO  = m.DT_MOVTO  OR (j.DT_MOVTO  IS NULL AND m.DT_MOVTO  IS NULL) THEN NULL ELSE ISNULL(j.DT_MOVTO,  @SemData) END AS DT_MOVTO,
                   CASE WHEN j.DT_VENCTO = m.DT_VENCTO OR (j.DT_VENCTO IS NULL AND m.DT_VENCTO IS NULL) THEN NULL ELSE ISNULL(j.DT_VENCTO, @SemData) END AS DT_VENCTO,
                   CASE WHEN j.DT_PAGTO  = m.DT_PAGTO  OR (j.DT_PAGTO  IS NULL AND m.DT_PAGTO  IS NULL) THEN NULL ELSE ISNULL(j.DT_PAGTO,  @SemData) END AS DT_PAGTO,
                   CASE WHEN j.DEB = ISNULL(m.VALOR_DEBITO, 0)  THEN NULL ELSE j.DEB END AS VALOR_DEBITO,
                   CASE WHEN j.CRE = ISNULL(m.VALOR_CREDITO, 0) THEN NULL ELSE j.CRE END AS VALOR_CREDITO,
                   CASE WHEN j.CONF = m.CONFIRMADO THEN NULL ELSE j.CONF END AS CONFIRMADO,
                   j.IGN AS IGNORAR_LINHA, m.HASH_CONTEUDO AS HASH,
                   CASE WHEN j.LOTE IS NULL OR j.LOTE = m.LOTE THEN NULL ELSE j.LOTE END AS LOTE
            INTO #C
            FROM #J j
            INNER JOIN MIG.Movimento m ON m.ORIGEM = j.ORIGEM AND m.NUM = j.NUM;

            DELETE FROM #C
            WHERE EMP_VINCULADA IS NULL AND PARCEIRO IS NULL AND CONTA IS NULL AND PLANO3 IS NULL
              AND DT_MOVTO IS NULL AND DT_VENCTO IS NULL AND DT_PAGTO IS NULL
              AND VALOR_DEBITO IS NULL AND VALOR_CREDITO IS NULL AND CONFIRMADO IS NULL AND IGNORAR_LINHA = 0 AND LOTE IS NULL;
            SELECT @Qtd = COUNT(*) FROM #C;

            IF @Qtd > 0 AND LEN(@Motivo) < 5
            BEGIN
                DROP TABLE IF EXISTS #J, #C;
                SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Escreva o motivo da correção (pelo menos 5 letras).' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
                RETURN;
            END;

            SET @EtapaAtual = 'Gravação das correções';
            BEGIN TRANSACTION;
            DELETE FROM MIG.Caso_Correcao WHERE UNIDADE = @Unidade;

            DELETE o
            FROM MIG.Caso_Correcao_Linha o
            WHERE (o.UNIDADE = @Unidade OR EXISTS (SELECT 1 FROM #J j WHERE j.ORIGEM = o.ORIGEM AND j.NUM = o.NUM))
              AND NOT EXISTS (SELECT 1 FROM #C c WHERE c.ORIGEM = o.ORIGEM AND c.NUM = o.NUM);

            UPDATE o
               SET o.EMP_VINCULADA = c.EMP_VINCULADA, o.PARCEIRO = c.PARCEIRO, o.CONTA = c.CONTA, o.PLANO3 = c.PLANO3,
                   o.DT_MOVTO = c.DT_MOVTO, o.DT_VENCTO = c.DT_VENCTO, o.DT_PAGTO = c.DT_PAGTO,
                   o.VALOR_DEBITO = c.VALOR_DEBITO, o.VALOR_CREDITO = c.VALOR_CREDITO, o.CONFIRMADO = c.CONFIRMADO,
                   o.IGNORAR_LINHA = c.IGNORAR_LINHA, o.MOTIVO = @Motivo, o.HASH_ACCESS = c.HASH, o.LOTE = c.LOTE,
                   o.DT_ALTERACAO = SYSDATETIME(), o.USUARIO_ALTERACAO = @Usuario
            FROM MIG.Caso_Correcao_Linha o
            INNER JOIN #C c ON c.ORIGEM = o.ORIGEM AND c.NUM = o.NUM
            WHERE NOT (ISNULL(o.EMP_VINCULADA, -1) = ISNULL(c.EMP_VINCULADA, -1) AND ISNULL(o.PARCEIRO, -1) = ISNULL(c.PARCEIRO, -1)
                   AND ISNULL(o.CONTA, -1) = ISNULL(c.CONTA, -1) AND ISNULL(o.PLANO3, -1) = ISNULL(c.PLANO3, -1)
                   AND ISNULL(o.DT_MOVTO, '1800-01-01') = ISNULL(c.DT_MOVTO, '1800-01-01')
                   AND ISNULL(o.DT_VENCTO, '1800-01-01') = ISNULL(c.DT_VENCTO, '1800-01-01')
                   AND ISNULL(o.DT_PAGTO, '1800-01-01') = ISNULL(c.DT_PAGTO, '1800-01-01')
                   AND ISNULL(o.VALOR_DEBITO, -1) = ISNULL(c.VALOR_DEBITO, -1) AND ISNULL(o.VALOR_CREDITO, -1) = ISNULL(c.VALOR_CREDITO, -1)
                   AND ISNULL(CONVERT(TINYINT, o.CONFIRMADO), 9) = ISNULL(CONVERT(TINYINT, c.CONFIRMADO), 9)
                   AND o.IGNORAR_LINHA = c.IGNORAR_LINHA AND o.MOTIVO = @Motivo
                   AND ISNULL(o.HASH_ACCESS, 0x) = ISNULL(c.HASH, 0x) AND ISNULL(o.LOTE, -1) = ISNULL(c.LOTE, -1));

            INSERT INTO MIG.Caso_Correcao_Linha (ORIGEM, NUM, UNIDADE, EMP_VINCULADA, PARCEIRO, CONTA, PLANO3, DT_MOVTO, DT_VENCTO, DT_PAGTO,
                                                 VALOR_DEBITO, VALOR_CREDITO, CONFIRMADO, IGNORAR_LINHA, MOTIVO, HASH_ACCESS, LOTE, USUARIO_CRIACAO)
            SELECT c.ORIGEM, c.NUM, (SELECT m.UNIDADE FROM MIG.Movimento m WHERE m.ORIGEM = c.ORIGEM AND m.NUM = c.NUM), c.EMP_VINCULADA, c.PARCEIRO, c.CONTA, c.PLANO3, c.DT_MOVTO, c.DT_VENCTO, c.DT_PAGTO,
                   c.VALOR_DEBITO, c.VALOR_CREDITO, c.CONFIRMADO, c.IGNORAR_LINHA, @Motivo, c.HASH, c.LOTE, @Usuario
            FROM #C c
            WHERE NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao_Linha o WHERE o.ORIGEM = c.ORIGEM AND o.NUM = c.NUM);
            COMMIT TRANSACTION;

            DROP TABLE IF EXISTS #J, #C;
            SELECT CAST(1 AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Qtd = 0 THEN N'Sem correções: o documento fica como está no Access.'
                             ELSE N'Correção gravada (' + CONVERT(NVARCHAR(10), @Qtd) + CASE WHEN @Qtd = 1 THEN N' linha).' ELSE N' linhas).' END END AS NVARCHAR(400)) AS MENSAGEM,
                   CAST(NULL AS BIGINT) AS ID;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação da decisão';
        SET @HashDoc = MIG.fn_MIG_Hash_Unidade(@Unidade);
        BEGIN TRANSACTION;
        IF @Acao = 'DESFAZER'
        BEGIN
            DELETE FROM MIG.Caso_Correcao WHERE UNIDADE = @Unidade;
            DELETE FROM MIG.Caso_Correcao_Linha WHERE UNIDADE = @Unidade;
        END
        ELSE
        BEGIN
            UPDATE MIG.Caso_Correcao
               SET ACAO = @Acao, MOTIVO = @Motivo, HASH_ACCESS = @HashDoc, LINK_VENDA_DESTINO = @LinkVenda, DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
            WHERE UNIDADE = @Unidade AND (ACAO <> @Acao OR MOTIVO <> @Motivo OR ISNULL(HASH_ACCESS, 0x) <> ISNULL(@HashDoc, 0x)
                                          OR ISNULL(LINK_VENDA_DESTINO, 0) <> ISNULL(@LinkVenda, 0));
            INSERT INTO MIG.Caso_Correcao (UNIDADE, ACAO, MOTIVO, HASH_ACCESS, LINK_VENDA_DESTINO, USUARIO_CRIACAO)
            SELECT @Unidade, @Acao, @Motivo, @HashDoc, @LinkVenda, @Usuario
            WHERE NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao WHERE UNIDADE = @Unidade);
        END;
        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE @Acao WHEN 'DESFAZER' THEN N'Correções desfeitas: o documento volta a ser como está no Access.'
                               WHEN 'IGNORAR' THEN N'Documento marcado para não migrar.'
                               WHEN 'ABATER' THEN N'Documento marcado como abatimento da parcela da venda ' + CONVERT(NVARCHAR(20), @LinkVenda) + N'.'
                               ELSE N'Documento marcado para o arquivo morto.' END AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #J, #C;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a correção. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS BIGINT) AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Conferir.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Botão "Conferir" da tela "Casos da migração" (e o passo final
                de cada gravação): classifica de novo só aquele documento, com
                as correções gravadas, pelas mesmas regras da migração
                (MIG_Movimento_Transformar @Unidade). Devolve UNIDADE, REGRA,
                MOTIVO e DETALHE. Nada é gravado no financeiro.
                Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
    v1.1 (18/11/2026) - @Unidades (lista JSON): confere vários documentos de uma
                        vez (ações em lote); uma linha por documento.

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Conferir @IdUsuario = 1, @Unidade = 'L:123';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Conferir]
    @IdUsuario  INT,
    @Unidade    VARCHAR(40)   = NULL,
    @Unidades   NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Conferir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;
        IF @Unidade IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = @Unidade)
            THROW 50001, N'Caso não encontrado. Atualize a lista.', 1;
        IF @Unidade IS NULL AND ISJSON(ISNULL(@Unidades, N'')) = 0
            THROW 50001, N'Escolha pelo menos um documento.', 1;

        SET @EtapaAtual = 'Classificação';
        EXEC MIG.MIG_Movimento_Transformar @Executar = 0, @Unidade = @Unidade, @Unidades = @Unidades;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível conferir o caso. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Lote_Gravar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Lote_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Ações em lote da tela "Casos da migração": a mesma decisão para
                vários documentos de uma vez (os marcados na lista, ou "Selecionar
                todos" com os filtros). @Acao:
                  IGNORAR        os documentos não migram (motivo obrigatório);
                  ARQUIVO_MORTO  vão para o arquivo morto (motivo obrigatório);
                  DESFAZER       apagam todas as correções e decisões deles.
                @UnidadesJson: lista JSON dos documentos (ex.: ["L:12","V:7"]),
                até 1.000 por vez. Cada decisão guarda a impressão digital do
                documento no Access (aviso "Revisar"). Tudo-ou-nada. Depois de
                gravar, a tela chama MIG_Caso_Conferir com a mesma lista.
                Permissão: ALTERAR em MIG_CASOS.
                Devolve SUCESSO, MENSAGEM, ID (= quantidade de documentos).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, "selecionar todos" na tela de casos).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Lote_Gravar @IdUsuario = 1, @Acao = 'IGNORAR', @Motivo = N'Estornos', @UnidadesJson = N'["L:12","A:345"]';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Lote_Gravar]
    @IdUsuario     INT,
    @Acao          VARCHAR(15),
    @Motivo        NVARCHAR(400) = N'',
    @UnidadesJson  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Lote_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Qtd        INT = 0;

    BEGIN TRY
        DROP TABLE IF EXISTS #Sel;
        SET @Acao   = UPPER(LTRIM(RTRIM(ISNULL(@Acao, ''))));
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'ALTERAR') = 0
            SET @Recusa = N'Você não tem permissão para corrigir os casos da migração.';
        IF @Recusa = N'' AND @Acao NOT IN ('IGNORAR', 'ARQUIVO_MORTO', 'DESFAZER')
            SET @Recusa = N'Ação inválida.';
        IF @Recusa = N'' AND @Acao IN ('IGNORAR', 'ARQUIVO_MORTO') AND LEN(@Motivo) < 5
            SET @Recusa = N'Escreva o motivo da decisão (pelo menos 5 letras).';
        IF @Recusa = N'' AND ISJSON(ISNULL(@UnidadesJson, N'')) = 0
            SET @Recusa = N'Lista de documentos inválida.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS BIGINT) AS ID;
            RETURN;
        END;

        SELECT DISTINCT CAST(LEFT(j.value, 40) AS VARCHAR(40)) AS UNIDADE
        INTO #Sel
        FROM OPENJSON(@UnidadesJson) j
        WHERE j.value IS NOT NULL;
        SELECT @Qtd = COUNT(*) FROM #Sel;

        IF @Qtd = 0
            SET @Recusa = N'Escolha pelo menos um documento.';
        IF @Recusa = N'' AND @Qtd > 1000
            SET @Recusa = N'No máximo 1.000 documentos por vez. Use os filtros para separar.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM #Sel s WHERE NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = s.UNIDADE))
            SET @Recusa = N'Algum documento não está mais na lista. Atualize a tela e tente de novo.';
        IF @Recusa <> N''
        BEGIN
            DROP TABLE IF EXISTS #Sel;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS BIGINT) AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;
        IF @Acao = 'DESFAZER'
        BEGIN
            DELETE cc FROM MIG.Caso_Correcao cc INNER JOIN #Sel s ON s.UNIDADE = cc.UNIDADE;
            DELETE o  FROM MIG.Caso_Correcao_Linha o INNER JOIN #Sel s ON s.UNIDADE = o.UNIDADE;
        END
        ELSE
        BEGIN
            UPDATE cc
               SET cc.ACAO = @Acao, cc.MOTIVO = @Motivo, cc.HASH_ACCESS = MIG.fn_MIG_Hash_Unidade(cc.UNIDADE),
                   cc.DT_ALTERACAO = SYSDATETIME(), cc.USUARIO_ALTERACAO = @Usuario
            FROM MIG.Caso_Correcao cc
            INNER JOIN #Sel s ON s.UNIDADE = cc.UNIDADE
            WHERE cc.ACAO <> @Acao OR cc.MOTIVO <> @Motivo OR ISNULL(cc.HASH_ACCESS, 0x) <> ISNULL(MIG.fn_MIG_Hash_Unidade(cc.UNIDADE), 0x);

            INSERT INTO MIG.Caso_Correcao (UNIDADE, ACAO, MOTIVO, HASH_ACCESS, USUARIO_CRIACAO)
            SELECT s.UNIDADE, @Acao, @Motivo, MIG.fn_MIG_Hash_Unidade(s.UNIDADE), @Usuario
            FROM #Sel s
            WHERE NOT EXISTS (SELECT 1 FROM MIG.Caso_Correcao cc WHERE cc.UNIDADE = s.UNIDADE);
        END;
        COMMIT TRANSACTION;

        DROP TABLE IF EXISTS #Sel;
        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CONVERT(NVARCHAR(10), @Qtd) + CASE WHEN @Qtd = 1 THEN N' documento ' ELSE N' documentos ' END
                    + CASE @Acao WHEN 'DESFAZER' THEN N'voltaram a ser como estão no Access.'
                                 WHEN 'IGNORAR' THEN N'marcados para não migrar.'
                                 ELSE N'marcados para o arquivo morto.' END AS NVARCHAR(400)) AS MENSAGEM,
               CAST(@Qtd AS BIGINT) AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
        BEGIN
            DROP TABLE IF EXISTS #Sel;
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END;
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a decisão em lote. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS BIGINT) AS ID;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/MIG.MIG_Caso_Correcao_Exportar.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Correcao_Exportar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Monta o script SQL que leva as correções da tela "Casos da
                migração" (MIG.Caso_Correcao e MIG.Caso_Correcao_Linha) de um
                banco para outro: do notebook (ensaio) para o servidor da CMJ
                na instalação (etapa 3d). Uma linha de texto por comando
                (coluna LINHA, em ordem); a tela junta tudo num arquivo .sql
                ("Baixar correções"). O script substitui as correções do banco
                de destino pelas do banco de origem, com usuário, datas e
                impressões digitais do Access; tudo-ou-nada.
                Permissão: ALTERAR em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, cópia das correções para a 3d).
    v1.1 (18/11/2026) - Leva também a troca de lote (LOTE).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Correcao_Exportar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Correcao_Exportar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Correcao_Exportar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'ALTERAR') = 0
            THROW 50001, N'Você não tem permissão para baixar as correções da migração.', 1;

        SET @EtapaAtual = 'Montagem';
        SELECT x.LINHA
        FROM (
            SELECT 1 AS PARTE, CAST(0 AS BIGINT) AS ORDEM, CAST(
                   N'/* SisCMJ - correções da tela "Casos da migração"' + NCHAR(13) + NCHAR(10)
                 + N'   Gerado em ' + CONVERT(NVARCHAR(19), SYSDATETIME(), 120) + N' no banco ' + DB_NAME() + N' por ' + SIS.fn_SIS_Usuario_Login(@IdUsuario) + NCHAR(13) + NCHAR(10)
                 + N'   ' + CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso_Correcao)) + N' decisões e '
                 + CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso_Correcao_Linha)) + N' linhas corrigidas.' + NCHAR(13) + NCHAR(10)
                 + N'   Como usar: no servidor de destino, SSMS > Abrir > este arquivo > F5. Substitui as correções de lá pelas deste arquivo. */' + NCHAR(13) + NCHAR(10)
                 + N'SET NOCOUNT ON;' + NCHAR(13) + NCHAR(10) + N'SET XACT_ABORT ON;' + NCHAR(13) + NCHAR(10)
                 + N'IF SCHEMA_ID(N''MIG'') IS NULL OR OBJECT_ID(N''MIG.Caso_Correcao'', N''U'') IS NULL OR COL_LENGTH(N''MIG.Caso_Correcao_Linha'', N''LOTE'') IS NULL' + NCHAR(13) + NCHAR(10)
                 + N'    THROW 50001, N''Este banco não tem as tabelas de correção da migração: rode antes o pacote 03c2b.'', 1;' + NCHAR(13) + NCHAR(10)
                 + N'BEGIN TRANSACTION;' + NCHAR(13) + NCHAR(10)
                 + N'DELETE FROM MIG.Caso_Correcao_Linha;' + NCHAR(13) + NCHAR(10)
                 + N'DELETE FROM MIG.Caso_Correcao;' AS NVARCHAR(MAX)) AS LINHA
            UNION ALL
            SELECT 2, c.ID_CASO_CORRECAO,
                   N'INSERT INTO MIG.Caso_Correcao (UNIDADE, ACAO, MOTIVO, HASH_ACCESS, DT_CRIACAO, USUARIO_CRIACAO, DT_ALTERACAO, USUARIO_ALTERACAO) VALUES ('
                 + N'''' + c.UNIDADE + N''', ''' + c.ACAO + N''', N''' + REPLACE(c.MOTIVO, N'''', N'''''') + N''', '
                 + ISNULL(CONVERT(NVARCHAR(70), c.HASH_ACCESS, 1), N'NULL') + N', '
                 + N'''' + CONVERT(NVARCHAR(19), c.DT_CRIACAO, 120) + N''', N''' + REPLACE(c.USUARIO_CRIACAO, N'''', N'''''') + N''', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(19), c.DT_ALTERACAO, 120) + N'''', N'NULL') + N', '
                 + ISNULL(N'N''' + REPLACE(c.USUARIO_ALTERACAO, N'''', N'''''') + N'''', N'NULL') + N');'
            FROM MIG.Caso_Correcao c
            UNION ALL
            SELECT 3, o.ID_CASO_CORRECAO_LINHA,
                   N'INSERT INTO MIG.Caso_Correcao_Linha (ORIGEM, NUM, UNIDADE, EMP_VINCULADA, PARCEIRO, CONTA, PLANO3, DT_MOVTO, DT_VENCTO, DT_PAGTO, '
                 + N'VALOR_DEBITO, VALOR_CREDITO, CONFIRMADO, IGNORAR_LINHA, MOTIVO, HASH_ACCESS, LOTE, DT_CRIACAO, USUARIO_CRIACAO, DT_ALTERACAO, USUARIO_ALTERACAO) VALUES ('
                 + N'''' + o.ORIGEM + N''', ' + CONVERT(NVARCHAR(12), o.NUM) + N', ''' + o.UNIDADE + N''', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.EMP_VINCULADA), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.PARCEIRO), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.CONTA), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.PLANO3), N'NULL') + N', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(10), o.DT_MOVTO, 23) + N'''', N'NULL') + N', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(10), o.DT_VENCTO, 23) + N'''', N'NULL') + N', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(10), o.DT_PAGTO, 23) + N'''', N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(30), o.VALOR_DEBITO), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(30), o.VALOR_CREDITO), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(1), o.CONFIRMADO), N'NULL') + N', '
                 + CONVERT(NVARCHAR(1), o.IGNORAR_LINHA) + N', '
                 + N'N''' + REPLACE(o.MOTIVO, N'''', N'''''') + N''', '
                 + ISNULL(CONVERT(NVARCHAR(70), o.HASH_ACCESS, 1), N'NULL') + N', '
                 + ISNULL(CONVERT(NVARCHAR(12), o.LOTE), N'NULL') + N', '
                 + N'''' + CONVERT(NVARCHAR(19), o.DT_CRIACAO, 120) + N''', N''' + REPLACE(o.USUARIO_CRIACAO, N'''', N'''''') + N''', '
                 + ISNULL(N'''' + CONVERT(NVARCHAR(19), o.DT_ALTERACAO, 120) + N'''', N'NULL') + N', '
                 + ISNULL(N'N''' + REPLACE(o.USUARIO_ALTERACAO, N'''', N'''''') + N'''', N'NULL') + N');'
            FROM MIG.Caso_Correcao_Linha o
            UNION ALL
            SELECT 4, 0, N'COMMIT TRANSACTION;' + NCHAR(13) + NCHAR(10)
                 + N'SELECT N''Correções copiadas: '' + CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso_Correcao)) + N'' decisões e '''
                 + N' + CONVERT(NVARCHAR(10), (SELECT COUNT(*) FROM MIG.Caso_Correcao_Linha)) + N'' linhas. Rode a migração para aplicar.'' AS RESULTADO;'
        ) x
        ORDER BY x.PARTE, x.ORDEM;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível montar o arquivo das correções. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
GO

-- -----------------------------------------------------------------------------
-- Arquivo: sql/objetos/MIG/Carga_MIG_Tela_Casos.sql
-- -----------------------------------------------------------------------------
/*******************************************************************************
  Objeto      : carga da tela "Casos da migração" (menu e permissões)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Menu Sistema > Migração > Casos da migração (MIG_CASOS), com as
                ações VER e ALTERAR. Para os dois administradores (geral e da
                CMJ); outro perfil só se receber a permissão. Só existe onde a
                migração roda (LOCAL e o servidor da CMJ até a virada); na
                virada, o item é desabilitado. Só insere o que falta (regra 39).
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'SIS_MIGRACAO', N'Migração', 'MENU', '', 40, 0, 1, ''
FROM SIS.Modulo m
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_MIGRACAO');
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'MIG_CASOS', N'Casos da migração', 'TELA', 'sis/migracao-casos.html', 10, 0, 1,
       'MIG.Caso_Correcao,MIG.Caso_Correcao_Linha'
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_MIGRACAO'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'MIG_CASOS');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('ALTERAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'MIG_CASOS'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO
GO

-- -----------------------------------------------------------------------------
-- Permissao da API (papel rl_sistemacmj_api, criado no MASTER) nas rotinas do
-- MIG: a tela "Casos da migracao" roda pelo servico. Sai junto com o MIG.
-- -----------------------------------------------------------------------------
IF DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NOT NULL
    GRANT EXECUTE ON SCHEMA::[MIG] TO [rl_sistemacmj_api];
GO

PRINT N'MIGRACAO v1.3 concluida sem erro.';
GO

SET NOEXEC OFF;
GO
