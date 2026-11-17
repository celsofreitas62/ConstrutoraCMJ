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
