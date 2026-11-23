/*******************************************************************************
  Pacote      : 03c2 - migração dos cadastros: CNPJ para notas de compra e DDA na empresa (CAD, vai para o MASTER) e classificação, de-paras e carga dos cadastros do Access (schema MIG, NÃO vai para o MASTER)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 23/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 03c e 03c_mig já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/CAD/03c2_Homologacao_CAD.sql e 03a_Homologacao_CAD.sql;
                depois sql/local/03c2_Migracao_Cadastros_LOCAL.sql.
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
-- Arquivo: sql/objetos/CAD/CAD.Empresa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[Empresa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Empresas do grupo (Construtora, SPEs, Holding), cadastro livre do
                administrador (decisão do Celso, 16/11/2026). O CNPJ da licença só
                registra o software; documentos de uma empresa/obra usam a razão social
                e o CNPJ daqui. CNPJ: só dígitos/letras (aceita o alfanumérico), único
                quando preenchido (a migração pode trazer empresa sem CNPJ).
                ID_CONTA_BANCARIA_PADRAO: FK para BANCO.Conta criada em
                CAD.FK_Conta_Padrao.sql (a conta é criada depois desta tabela).
                Logomarca: anexo do tipo LOGOMARCA (SIS.Anexo).
                CNPJ_COMPRAS: segundo CNPJ, opcional, para notas de compra e DDA
                (ex.: SPE no RET, em que a Receita cria um CNPJ só para isso;
                decisão da CMJ, 17/11/2026). Cobrança e relatórios usam o CNPJ.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - CNPJ_COMPRAS (CNPJ para notas de compra e DDA), etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira: preenchidas = registro na lixeira).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[CAD].[Empresa]', N'U') IS NULL
BEGIN
    CREATE TABLE [CAD].[Empresa]
    (
        ID_EMPRESA                 INT            IDENTITY(1,1) NOT NULL,
        RAZAO_SOCIAL               NVARCHAR(150)  NOT NULL,
        NOME_FANTASIA              NVARCHAR(100)  NOT NULL CONSTRAINT DF_Empresa_NOME_FANTASIA       DEFAULT (N''),
        CNPJ                       VARCHAR(14)    NOT NULL CONSTRAINT DF_Empresa_CNPJ                DEFAULT (''),
        CNPJ_COMPRAS               VARCHAR(14)    NOT NULL CONSTRAINT DF_Empresa_CNPJ_COMPRAS        DEFAULT (''),
        TIPO                       VARCHAR(12)    NOT NULL CONSTRAINT DF_Empresa_TIPO                DEFAULT ('OUTRA'),
        INSCRICAO_ESTADUAL         VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_INSCRICAO_ESTADUAL  DEFAULT (''),
        INSCRICAO_MUNICIPAL        VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_INSCRICAO_MUNICIPAL DEFAULT (''),
        REGIME_TRIBUTARIO          VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_REGIME_TRIBUTARIO   DEFAULT (''),
        CEP                        VARCHAR(8)     NOT NULL CONSTRAINT DF_Empresa_CEP                 DEFAULT (''),
        LOGRADOURO                 NVARCHAR(150)  NOT NULL CONSTRAINT DF_Empresa_LOGRADOURO          DEFAULT (N''),
        NUMERO                     NVARCHAR(20)   NOT NULL CONSTRAINT DF_Empresa_NUMERO              DEFAULT (N''),
        COMPLEMENTO                NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_COMPLEMENTO         DEFAULT (N''),
        BAIRRO                     NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_BAIRRO              DEFAULT (N''),
        CIDADE                     NVARCHAR(60)   NOT NULL CONSTRAINT DF_Empresa_CIDADE              DEFAULT (N''),
        UF                         CHAR(2)        NOT NULL CONSTRAINT DF_Empresa_UF                  DEFAULT (''),
        EMAIL                      NVARCHAR(256)  NOT NULL CONSTRAINT DF_Empresa_EMAIL               DEFAULT (N''),
        TELEFONE                   VARCHAR(20)    NOT NULL CONSTRAINT DF_Empresa_TELEFONE            DEFAULT (''),
        ID_CONTA_BANCARIA_PADRAO   INT            NULL,
        ATIVO                      BIT            NOT NULL CONSTRAINT DF_Empresa_ATIVO               DEFAULT (1),
        CODIGO_ACCESS              INT            NULL,
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Empresa_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Empresa_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Empresa                   PRIMARY KEY CLUSTERED (ID_EMPRESA),
        CONSTRAINT CK_Empresa_TIPO              CHECK (TIPO IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')),
        CONSTRAINT CK_Empresa_REGIME_TRIBUTARIO CHECK (REGIME_TRIBUTARIO IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')),
        CONSTRAINT CK_Empresa_CNPJ              CHECK (CNPJ = '' OR (LEN(CNPJ) = 14 AND CNPJ NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2)),
        CONSTRAINT CK_Empresa_CNPJ_COMPRAS      CHECK (CNPJ_COMPRAS = '' OR (LEN(CNPJ_COMPRAS) = 14 AND CNPJ_COMPRAS NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2)),
        CONSTRAINT CK_Empresa_CEP               CHECK (CEP = '' OR (LEN(CEP) = 8 AND CEP NOT LIKE '%[^0-9]%')),
        CONSTRAINT CK_Empresa_UF                CHECK (UF = '' OR UF NOT LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
    );
END;
GO

-- v1.1: coluna nova em tabela já existente (regra 59)
IF COL_LENGTH(N'CAD.Empresa', N'CNPJ_COMPRAS') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CNPJ_COMPRAS VARCHAR(14) NOT NULL CONSTRAINT DF_Empresa_CNPJ_COMPRAS DEFAULT ('');
GO
IF OBJECT_ID(N'CAD.CK_Empresa_CNPJ_COMPRAS', N'C') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD CONSTRAINT CK_Empresa_CNPJ_COMPRAS
        CHECK (CNPJ_COMPRAS = '' OR (LEN(CNPJ_COMPRAS) = 14 AND CNPJ_COMPRAS NOT LIKE '%[^0-9A-Z]%' COLLATE Latin1_General_BIN2));
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_Empresa_CNPJ' AND object_id = OBJECT_ID(N'[CAD].[Empresa]'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Empresa_CNPJ ON [CAD].[Empresa] (CNPJ) WHERE CNPJ <> '';
GO

IF COL_LENGTH(N'CAD.Empresa', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'CAD.Empresa', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [CAD].[Empresa] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Empresas" (e escolha da empresa nos outros cadastros): todas as
                colunas, CNPJ formatado e a conta padrão.
                Permissão: VER em CAD_EMPRESA, CAD_CENTRO_CUSTO ou BANCO_CONTA.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - Colunas CNPJ_COMPRAS e CNPJ_COMPRAS_FORMATADO, etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as empresas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT e.ID_EMPRESA, e.RAZAO_SOCIAL, e.NOME_FANTASIA, e.CNPJ,
               SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ, 0) AS CNPJ_FORMATADO,
               e.CNPJ_COMPRAS, SIS.fn_SIS_Mascarar_CPF_CNPJ(e.CNPJ_COMPRAS, 0) AS CNPJ_COMPRAS_FORMATADO,
               e.TIPO, e.INSCRICAO_ESTADUAL, e.INSCRICAO_MUNICIPAL, e.REGIME_TRIBUTARIO,
               e.CEP, e.LOGRADOURO, e.NUMERO, e.COMPLEMENTO, e.BAIRRO, e.CIDADE, e.UF, e.EMAIL, e.TELEFONE,
               e.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               e.ATIVO, e.CODIGO_ACCESS, e.DT_ALTERACAO, ISNULL(e.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Empresa e WITH (NOLOCK)
        LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR e.ATIVO = 1)
          AND e.DT_EXCLUSAO IS NULL
        ORDER BY e.RAZAO_SOCIAL;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as empresas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Empresa_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Empresa_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdEmpresa NULL) ou altera uma empresa do grupo. Pela tela o
                CNPJ é obrigatório e conferido (dígitos verificadores, aceita o
                alfanumérico); não pode repetir. CEP com 8 dígitos, UF com 2 letras,
                e-mail válido. Conta padrão: qualquer conta ativa (escolha no cadastro,
                decisão do Celso).
                CNPJ para notas de compra e DDA (@CnpjCompras): opcional; NULL
                mantém o que está gravado (na inclusão, fica vazio); '' apaga.
                Permissão: INCLUIR ou ALTERAR em CAD_EMPRESA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (17/11/2026) - @CnpjCompras (CNPJ para notas de compra e DDA), etapa 03c2.
    v1.2 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Empresa_Gravar @IdUsuario = 2, @RazaoSocial = N'Construtora Teste Ltda', @Cnpj = '11.222.333/0001-81', @Tipo = 'CONSTRUTORA';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Empresa_Gravar]
    @IdUsuario               INT,
    @IdEmpresa               INT           = NULL,
    @RazaoSocial             NVARCHAR(150),
    @NomeFantasia            NVARCHAR(100) = NULL,
    @Cnpj                    VARCHAR(20),
    @Tipo                    VARCHAR(12)   = 'OUTRA',
    @InscricaoEstadual       VARCHAR(20)   = NULL,
    @InscricaoMunicipal      VARCHAR(20)   = NULL,
    @RegimeTributario        VARCHAR(20)   = NULL,
    @Cep                     VARCHAR(10)   = NULL,
    @Logradouro              NVARCHAR(150) = NULL,
    @Numero                  NVARCHAR(20)  = NULL,
    @Complemento             NVARCHAR(60)  = NULL,
    @Bairro                  NVARCHAR(60)  = NULL,
    @Cidade                  NVARCHAR(60)  = NULL,
    @Uf                      CHAR(2)       = NULL,
    @Email                   NVARCHAR(256) = NULL,
    @Telefone                VARCHAR(30)   = NULL,
    @IdContaBancariaPadrao   INT           = NULL,
    @CnpjCompras             VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Empresa_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @RazaoSocial        = LTRIM(RTRIM(ISNULL(@RazaoSocial, N'')));
        SET @NomeFantasia       = LTRIM(RTRIM(ISNULL(@NomeFantasia, N'')));
        SET @Cnpj               = CAD.fn_CAD_Documento_Limpo(@Cnpj);
        SET @Tipo               = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, 'OUTRA'))));
        SET @InscricaoEstadual  = LTRIM(RTRIM(ISNULL(@InscricaoEstadual, '')));
        SET @InscricaoMunicipal = LTRIM(RTRIM(ISNULL(@InscricaoMunicipal, '')));
        SET @RegimeTributario   = UPPER(LTRIM(RTRIM(ISNULL(@RegimeTributario, ''))));
        SET @Cep                = CAD.fn_CAD_Somente_Digitos(@Cep);
        SET @Logradouro         = LTRIM(RTRIM(ISNULL(@Logradouro, N'')));
        SET @Numero             = LTRIM(RTRIM(ISNULL(@Numero, N'')));
        SET @Complemento        = LTRIM(RTRIM(ISNULL(@Complemento, N'')));
        SET @Bairro             = LTRIM(RTRIM(ISNULL(@Bairro, N'')));
        SET @Cidade             = LTRIM(RTRIM(ISNULL(@Cidade, N'')));
        SET @Uf                 = UPPER(LTRIM(RTRIM(ISNULL(@Uf, ''))));
        SET @Email              = LOWER(LTRIM(RTRIM(ISNULL(@Email, N''))));
        SET @Telefone           = CAD.fn_CAD_Somente_Digitos(@Telefone);
        IF @CnpjCompras IS NOT NULL SET @CnpjCompras = CAD.fn_CAD_Documento_Limpo(@CnpjCompras);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', CASE WHEN @IdEmpresa IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar empresas.';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Empresa', @IdEmpresa) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdEmpresa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.ID_EMPRESA = @IdEmpresa)
            SET @Recusa = N'Empresa não encontrada.';
        IF @Recusa = N'' AND @RazaoSocial = N''
            SET @Recusa = N'Informe a razão social.';
        IF @Recusa = N'' AND (LEN(@Cnpj) <> 14 OR CAD.fn_CAD_Documento_Valido(@Cnpj) = 0)
            SET @Recusa = N'CNPJ inválido. Confira os números (o CNPJ alfanumérico também é aceito).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Empresa e WHERE e.CNPJ = @Cnpj AND e.ID_EMPRESA <> ISNULL(@IdEmpresa, 0))
            SET @Recusa = N'Já existe uma empresa cadastrada com este CNPJ.';
        IF @Recusa = N'' AND ISNULL(@CnpjCompras, '') <> '' AND (LEN(@CnpjCompras) <> 14 OR CAD.fn_CAD_Documento_Valido(@CnpjCompras) = 0)
            SET @Recusa = N'CNPJ para notas de compra e DDA inválido. Confira os números.';
        IF @Recusa = N'' AND ISNULL(@CnpjCompras, '') <> '' AND @CnpjCompras = @Cnpj
            SET @Recusa = N'O CNPJ para notas de compra e DDA é igual ao CNPJ da empresa: deixe em branco.';
        IF @Recusa = N'' AND @Tipo NOT IN ('CONSTRUTORA', 'SPE', 'HOLDING', 'OUTRA')
            SET @Recusa = N'Tipo de empresa inválido.';
        IF @Recusa = N'' AND @RegimeTributario NOT IN ('', 'SIMPLES', 'LUCRO_PRESUMIDO', 'LUCRO_REAL', 'RET')
            SET @Recusa = N'Regime tributário inválido.';
        IF @Recusa = N'' AND @Cep <> '' AND LEN(@Cep) <> 8
            SET @Recusa = N'CEP inválido: são 8 dígitos.';
        IF @Recusa = N'' AND @Uf <> '' AND (LEN(@Uf) <> 2 OR @Uf LIKE '%[^A-Z]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'UF inválida: use a sigla com 2 letras (ex.: PR).';
        IF @Recusa = N'' AND @Email <> N'' AND SIS.fn_SIS_Email_Valido(@Email) = 0
            SET @Recusa = N'E-mail inválido.';
        IF @Recusa = N'' AND @IdContaBancariaPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = @IdContaBancariaPadrao AND c.ATIVO = 1)
            SET @Recusa = N'A conta padrão escolhida não existe ou está desativada.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @IdEmpresa IS NULL
        BEGIN
            INSERT INTO CAD.Empresa (RAZAO_SOCIAL, NOME_FANTASIA, CNPJ, CNPJ_COMPRAS, TIPO, INSCRICAO_ESTADUAL, INSCRICAO_MUNICIPAL, REGIME_TRIBUTARIO,
                                     CEP, LOGRADOURO, NUMERO, COMPLEMENTO, BAIRRO, CIDADE, UF, EMAIL, TELEFONE, ID_CONTA_BANCARIA_PADRAO, USUARIO_CRIACAO)
            VALUES (@RazaoSocial, @NomeFantasia, @Cnpj, ISNULL(@CnpjCompras, ''), @Tipo, @InscricaoEstadual, @InscricaoMunicipal, @RegimeTributario,
                    @Cep, @Logradouro, @Numero, @Complemento, @Bairro, @Cidade, @Uf, @Email, @Telefone, @IdContaBancariaPadrao, @Usuario);
            SET @IdEmpresa = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE e
               SET e.RAZAO_SOCIAL = @RazaoSocial, e.NOME_FANTASIA = @NomeFantasia, e.CNPJ = @Cnpj, e.CNPJ_COMPRAS = ISNULL(@CnpjCompras, e.CNPJ_COMPRAS), e.TIPO = @Tipo,
                   e.INSCRICAO_ESTADUAL = @InscricaoEstadual, e.INSCRICAO_MUNICIPAL = @InscricaoMunicipal, e.REGIME_TRIBUTARIO = @RegimeTributario,
                   e.CEP = @Cep, e.LOGRADOURO = @Logradouro, e.NUMERO = @Numero, e.COMPLEMENTO = @Complemento, e.BAIRRO = @Bairro,
                   e.CIDADE = @Cidade, e.UF = @Uf, e.EMAIL = @Email, e.TELEFONE = @Telefone, e.ID_CONTA_BANCARIA_PADRAO = @IdContaBancariaPadrao,
                   e.DT_ALTERACAO = SYSDATETIME(), e.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Empresa e
            WHERE e.ID_EMPRESA = @IdEmpresa;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Empresa gravada.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar a empresa. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdEmpresa AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/Carga_CAD_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do CAD e do BANCO
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas 11 tabelas da etapa 03a, gerando cada
                trigger com SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas. No MASTER
                fica na parte 8 (triggers).

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Banco',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Conta',               @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Centro_Custo',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa',                @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Contato',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Vinculo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Pessoa_Dado_Bancario',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Grupo',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Subgrupo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Plano_Conta',           @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.Tabelas_Cadastros.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.fn_MIG_Plano_Desmontar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Cadastros_Processar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/MIG/MIG.MIG_Cadastros_Conferencia_Listar.sql
-- =============================================================================
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

-- =============================================================================
-- Arquivo: sql/objetos/MIG/Carga_MIG_Classificacao.sql
-- =============================================================================
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

PRINT N'Pacote 03c2 concluído sem erro.';
GO

SET NOEXEC OFF;
GO
