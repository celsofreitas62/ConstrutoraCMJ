/*******************************************************************************
  Pacote      : 04f - contas a pagar e a receber (banco): lancamento com parcelas, protecoes contra erro de digitacao (P17), trava de datas, parametros de uso; banco continua 2.4 ate a 04f2
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 25/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04e já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/FIN/04f_Homologacao_Lancamentos.sql, 03c, 04b e 04e.
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
-- Arquivo: sql/objetos/SIS/SIS.Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros do sistema (seção 3.4 do CLAUDE.md, PADRAO_SQL
                regra 33): nada de valor de negócio fixo no código.
                - CHAVE: maiúsculas, dígitos e "_", no formato MODULO_ASSUNTO.
                - VALOR: sempre gravado no formato canônico do TIPO
                  (INTEIRO "15", DECIMAL "2.5" com ponto, DATA "2026-11-15",
                  SN "S"/"N", EMAIL um endereço só, ARQUIVO nome do arquivo
                  sem pasta (ex.: logo.png; a pasta vem de outro parâmetro),
                  COR "#RRGGBB"; vazio = não configurado).
                - VALOR_PADRAO: valor de fábrica, para "restaurar padrão".
                - EDITAVEL_ADMIN = 0: só o instalador altera (por script).
                A auditoria (antes/depois) entra com a trigger da etapa 02c.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Tipos ARQUIVO e COR (identidade visual por cliente:
                        logomarca e cores sem mexer no sistema).
    v1.2 (25/11/2026) - Etapa 04f: NIVEL_MINIMO (1 = os dois administradores
                        alteram pela tela "Parâmetros de uso"; 2 = só o
                        administrador geral; decisão do Celso de 18/11/2026) e
                        OPCOES (valores aceitos separados por ";", ex.:
                        AVISO;BLOQUEIO;NAO; vazio = livre conforme o TIPO).
                        As duas colunas só mudam pela carga da instalação.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Parametro]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Parametro]
    (
        ID_PARAMETRO       INT            IDENTITY(1,1) NOT NULL,
        CHAVE              VARCHAR(60)    NOT NULL,
        VALOR              NVARCHAR(4000) NOT NULL CONSTRAINT DF_Parametro_VALOR           DEFAULT (N''),
        VALOR_PADRAO       NVARCHAR(4000) NOT NULL CONSTRAINT DF_Parametro_VALOR_PADRAO    DEFAULT (N''),
        TIPO               VARCHAR(10)    NOT NULL CONSTRAINT DF_Parametro_TIPO            DEFAULT ('TEXTO'),
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Parametro_DESCRICAO       DEFAULT (N''),
        ID_MODULO          INT            NOT NULL,
        EDITAVEL_ADMIN     BIT            NOT NULL CONSTRAINT DF_Parametro_EDITAVEL_ADMIN  DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Parametro_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Parametro_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Parametro        PRIMARY KEY CLUSTERED (ID_PARAMETRO),
        CONSTRAINT UQ_Parametro_CHAVE  UNIQUE (CHAVE),
        CONSTRAINT FK_Parametro_Modulo FOREIGN KEY (ID_MODULO) REFERENCES [SIS].[Modulo] (ID_MODULO),
        CONSTRAINT CK_Parametro_CHAVE  CHECK (CHAVE <> '' AND CHAVE NOT LIKE '%[^A-Z0-9_]%'),
        CONSTRAINT CK_Parametro_TIPO   CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'SN', 'EMAIL', 'ARQUIVO', 'COR'))
    );
END;
GO

-- Ajuste de banco criado com a v1.0 (CHECK sem ARQUIVO e COR)
IF EXISTS (SELECT 1 FROM sys.check_constraints c
           WHERE c.name = N'CK_Parametro_TIPO' AND c.parent_object_id = OBJECT_ID(N'[SIS].[Parametro]')
             AND c.definition NOT LIKE N'%ARQUIVO%')
BEGIN
    ALTER TABLE [SIS].[Parametro] DROP CONSTRAINT CK_Parametro_TIPO;
    ALTER TABLE [SIS].[Parametro] ADD CONSTRAINT CK_Parametro_TIPO CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'DECIMAL', 'DATA', 'SN', 'EMAIL', 'ARQUIVO', 'COR'));
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[SIS].[Parametro]') AND i.name = N'IX_Parametro_ID_MODULO')
    CREATE NONCLUSTERED INDEX IX_Parametro_ID_MODULO ON [SIS].[Parametro] (ID_MODULO);
GO

IF COL_LENGTH(N'SIS.Parametro', N'NIVEL_MINIMO') IS NULL
    ALTER TABLE [SIS].[Parametro] ADD NIVEL_MINIMO TINYINT NOT NULL CONSTRAINT DF_Parametro_NIVEL_MINIMO DEFAULT (2)
        CONSTRAINT CK_Parametro_NIVEL_MINIMO CHECK (NIVEL_MINIMO IN (1, 2));
GO
IF COL_LENGTH(N'SIS.Parametro', N'OPCOES') IS NULL
    ALTER TABLE [SIS].[Parametro] ADD OPCOES NVARCHAR(200) NOT NULL CONSTRAINT DF_Parametro_OPCOES DEFAULT (N'');
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Aviso_Confirmado.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Aviso_Confirmado]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Registro de cada aviso que o usuário confirmou ("Gravar mesmo
                assim") e de cada exceção usada com motivo (ex.: lançamento
                retroativo), P17. Uma linha por aviso: tabela e registro
                gravados, código da regra, texto mostrado ao usuário, motivo
                (quando a regra pede), quem e quando. Base também do check-up
                diário (P25). Só a procedure que grava inclui linhas; ninguém
                altera nem apaga (sem tela de manutenção).
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Aviso_Confirmado]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Aviso_Confirmado]
    (
        ID_AVISO_CONFIRMADO  BIGINT         IDENTITY(1,1) NOT NULL,
        TABELA               NVARCHAR(256)  NOT NULL,
        ID_REGISTRO          BIGINT         NOT NULL,
        CODIGO_REGRA         VARCHAR(40)    NOT NULL,
        NIVEL                VARCHAR(12)    NOT NULL,
        MENSAGEM             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Aviso_Confirmado_MENSAGEM DEFAULT (N''),
        MOTIVO               NVARCHAR(400)  NOT NULL CONSTRAINT DF_Aviso_Confirmado_MOTIVO   DEFAULT (N''),
        ID_REFERENCIA        BIGINT         NULL,
        ID_USUARIO           INT            NULL,
        DT_CRIACAO           DATETIME2(0)   NOT NULL CONSTRAINT DF_Aviso_Confirmado_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Aviso_Confirmado_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        CONSTRAINT PK_Aviso_Confirmado        PRIMARY KEY CLUSTERED (ID_AVISO_CONFIRMADO),
        CONSTRAINT FK_Aviso_Confirmado_Usuario FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT CK_Aviso_Confirmado_NIVEL  CHECK (NIVEL IN ('AVISO', 'MOTIVO'))
    );
    CREATE INDEX IX_Aviso_Confirmado_REGISTRO ON [SIS].[Aviso_Confirmado] (TABELA, ID_REGISTRO);
    CREATE INDEX IX_Aviso_Confirmado_DATA     ON [SIS].[Aviso_Confirmado] (DT_CRIACAO);
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.Lancamento.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[Lancamento]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : O documento: uma obrigação a pagar (P) ou a receber (R), lançada
                uma vez (modelo de lançamento único, seção 3.2). Parcelas em
                FIN.Parcela, pagamentos em FIN.Baixa. Empresa vem do centro de custo
                (a rotina de gravação confere). INTEGRACAO (respostas do Celso,
                17/11/2026): COMPLETA = contabilidade + custo + banco; SO_CONTABIL =
                só relatórios da contabilidade, sem banco nem custo; NENHUMA.
                PREVISAO: compromisso previsto, sem documento (fluxo projetado).
                ID_PEDIDO_COMPRA: FK ligada quando o COMP existir. CODIGO_ACCESS +
                ORIGEM_ACCESS: rastreio da migração.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
    v1.1 (25/11/2026) - Etapa 04f: ATIVO, DT_EXCLUSAO e USUARIO_EXCLUSAO
                        (lixeira, P20); DT_CANCELAMENTO, USUARIO_CANCELAMENTO e
                        MOTIVO_CANCELAMENTO (Cancelar com motivo); índices da
                        conferência de duplicidade (P17) e da lista por tipo.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[FIN].[Lancamento]', N'U') IS NULL
BEGIN
    CREATE TABLE [FIN].[Lancamento]
    (
        ID_LANCAMENTO        BIGINT         IDENTITY(1,1) NOT NULL,
        TIPO                 CHAR(1)        NOT NULL,
        ID_EMPRESA           INT            NOT NULL,
        ID_CENTRO_CUSTO      INT            NULL,
        ID_PESSOA            INT            NULL,
        ID_PLANO_CONTA       INT            NULL,
        ID_HISTORICO_PADRAO  INT            NULL,
        DOCUMENTO            NVARCHAR(40)   NOT NULL CONSTRAINT DF_Lancamento_DOCUMENTO     DEFAULT (N''),
        DT_EMISSAO           DATE           NOT NULL,
        DT_COMPETENCIA       DATE           NOT NULL,
        HISTORICO            NVARCHAR(200)  NOT NULL CONSTRAINT DF_Lancamento_HISTORICO     DEFAULT (N''),
        OBSERVACAO           NVARCHAR(2000) NOT NULL CONSTRAINT DF_Lancamento_OBSERVACAO    DEFAULT (N''),
        VALOR_TOTAL          DECIMAL(18,2)  NOT NULL,
        ORIGEM               VARCHAR(15)    NOT NULL CONSTRAINT DF_Lancamento_ORIGEM        DEFAULT ('MANUAL'),
        ID_ORIGEM            BIGINT         NULL,
        ID_LOTE              BIGINT         NULL,
        SITUACAO             VARCHAR(10)    NOT NULL CONSTRAINT DF_Lancamento_SITUACAO      DEFAULT ('ATIVO'),
        PREVISAO             BIT            NOT NULL CONSTRAINT DF_Lancamento_PREVISAO      DEFAULT (0),
        INTEGRACAO           VARCHAR(12)    NOT NULL CONSTRAINT DF_Lancamento_INTEGRACAO    DEFAULT ('COMPLETA'),
        ID_PEDIDO_COMPRA     BIGINT         NULL,
        CODIGO_ACCESS        INT            NULL,
        ORIGEM_ACCESS        VARCHAR(20)    NOT NULL CONSTRAINT DF_Lancamento_ORIGEM_ACCESS DEFAULT (''),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Lancamento_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Lancamento_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Lancamento               PRIMARY KEY CLUSTERED (ID_LANCAMENTO),
        CONSTRAINT FK_Lancamento_Empresa       FOREIGN KEY (ID_EMPRESA)          REFERENCES [CAD].[Empresa] (ID_EMPRESA),
        CONSTRAINT FK_Lancamento_Centro_Custo  FOREIGN KEY (ID_CENTRO_CUSTO)     REFERENCES [CAD].[Centro_Custo] (ID_CENTRO_CUSTO),
        CONSTRAINT FK_Lancamento_Pessoa        FOREIGN KEY (ID_PESSOA)           REFERENCES [CAD].[Pessoa] (ID_PESSOA),
        CONSTRAINT FK_Lancamento_Plano_Conta   FOREIGN KEY (ID_PLANO_CONTA)      REFERENCES [CAD].[Plano_Conta] (ID_PLANO_CONTA),
        CONSTRAINT FK_Lancamento_Historico     FOREIGN KEY (ID_HISTORICO_PADRAO) REFERENCES [FIN].[Historico_Padrao] (ID_HISTORICO_PADRAO),
        CONSTRAINT FK_Lancamento_Lote          FOREIGN KEY (ID_LOTE)             REFERENCES [SIS].[Lote] (ID_LOTE),
        CONSTRAINT CK_Lancamento_TIPO          CHECK (TIPO IN ('P', 'R')),
        CONSTRAINT CK_Lancamento_VALOR_TOTAL   CHECK (VALOR_TOTAL >= 0),
        CONSTRAINT CK_Lancamento_COMPETENCIA   CHECK (DAY(DT_COMPETENCIA) = 1),
        CONSTRAINT CK_Lancamento_ORIGEM        CHECK (ORIGEM IN ('MANUAL', 'VENDA', 'COMPRA', 'MEDICAO', 'RECORRENTE', 'CONCILIACAO', 'ACORDO', 'MIGRACAO')),
        CONSTRAINT CK_Lancamento_SITUACAO      CHECK (SITUACAO IN ('ATIVO', 'CANCELADO')),
        CONSTRAINT CK_Lancamento_INTEGRACAO    CHECK (INTEGRACAO IN ('COMPLETA', 'SO_CONTABIL', 'NENHUMA'))
    );
    CREATE INDEX IX_Lancamento_PESSOA       ON [FIN].[Lancamento] (ID_PESSOA) WHERE ID_PESSOA IS NOT NULL;
    CREATE INDEX IX_Lancamento_CENTRO_CUSTO ON [FIN].[Lancamento] (ID_CENTRO_CUSTO, DT_COMPETENCIA);
    CREATE INDEX IX_Lancamento_LOTE         ON [FIN].[Lancamento] (ID_LOTE) WHERE ID_LOTE IS NOT NULL;
    CREATE INDEX IX_Lancamento_ACCESS       ON [FIN].[Lancamento] (ORIGEM_ACCESS, CODIGO_ACCESS) WHERE CODIGO_ACCESS IS NOT NULL;
END;
GO

IF COL_LENGTH(N'FIN.Lancamento', N'ATIVO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD ATIVO BIT NOT NULL CONSTRAINT DF_Lancamento_ATIVO DEFAULT (1);
GO
IF COL_LENGTH(N'FIN.Lancamento', N'DT_EXCLUSAO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD DT_EXCLUSAO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'FIN.Lancamento', N'USUARIO_EXCLUSAO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD USUARIO_EXCLUSAO NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'FIN.Lancamento', N'DT_CANCELAMENTO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD DT_CANCELAMENTO DATETIME2(0) NULL;
GO
IF COL_LENGTH(N'FIN.Lancamento', N'USUARIO_CANCELAMENTO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD USUARIO_CANCELAMENTO NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'FIN.Lancamento', N'MOTIVO_CANCELAMENTO') IS NULL
    ALTER TABLE [FIN].[Lancamento] ADD MOTIVO_CANCELAMENTO NVARCHAR(400) NOT NULL CONSTRAINT DF_Lancamento_MOTIVO_CANCELAMENTO DEFAULT (N'');
GO
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[FIN].[Lancamento]') AND i.name = N'IX_Lancamento_DOCUMENTO')
    CREATE INDEX IX_Lancamento_DOCUMENTO ON [FIN].[Lancamento] (ID_PESSOA, TIPO, DOCUMENTO) INCLUDE (SITUACAO, DT_EXCLUSAO) WHERE DOCUMENTO <> N'';
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = OBJECT_ID(N'[FIN].[Lancamento]') AND i.name = N'IX_Lancamento_PESSOA_PLANO')
    CREATE INDEX IX_Lancamento_PESSOA_PLANO ON [FIN].[Lancamento] (ID_PESSOA, ID_PLANO_CONTA, TIPO, DT_EMISSAO) INCLUDE (VALOR_TOTAL, SITUACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.fn_FIN_Data_Recusa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Data_Recusa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Trava de datas do financeiro (aprovada em 18/11/2026). Função
                única de validação, usada por todas as gravações do FIN.
                @Campo: EMISSAO, VENCIMENTO ou BAIXA (pagamento, recebimento,
                transferência, movimento bancário). Devolve o motivo da
                recusa, ou vazio quando a data pode. Nunca devolve NULL.
                  - antes do 1º dia do mês atual: recusa, menos até o dia
                    FIN_DIAS_TOLERANCIA_MES_ANTERIOR, quando o mês anterior
                    ainda é aceito;
                  - EMISSAO / BAIXA: no máximo FIN_EMISSAO_DIAS_FUTURO /
                    FIN_BAIXA_DIAS_FUTURO dias no futuro;
                  - VENCIMENTO: até FIN_VENCIMENTO_ANOS_FUTURO anos à frente.
                FIN_TRAVA_DATAS_ATIVA = N desliga tudo. A exceção
                (LANCAR_RETROATIVO, com motivo) fica com quem chama.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

  Homologação (LOCAL):
    -- SELECT FIN.fn_FIN_Data_Recusa('EMISSAO', '2020-01-01'), FIN.fn_FIN_Data_Recusa('VENCIMENTO', '2099-01-01');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Data_Recusa] (@Campo VARCHAR(12), @Data DATE)
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @Hoje DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Piso DATE, @Teto DATE, @Tolerancia INT, @Futuro INT, @Nome NVARCHAR(30);

    IF @Data IS NULL RETURN N'';
    IF ISNULL(SIS.fn_SIS_Parametro_SN('FIN_TRAVA_DATAS_ATIVA'), 1) = 0 RETURN N'';

    SET @Nome = CASE @Campo WHEN 'EMISSAO' THEN N'de emissão' WHEN 'VENCIMENTO' THEN N'de vencimento' ELSE N'de pagamento' END;
    SET @Tolerancia = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_DIAS_TOLERANCIA_MES_ANTERIOR'), 5);
    SET @Piso = DATEFROMPARTS(YEAR(@Hoje), MONTH(@Hoje), 1);
    IF DAY(@Hoje) <= @Tolerancia SET @Piso = DATEADD(MONTH, -1, @Piso);

    IF @Data < @Piso
        RETURN N'A data ' + @Nome + N' ' + CONVERT(NVARCHAR(10), @Data, 103) + N' é anterior a '
             + CONVERT(NVARCHAR(10), @Piso, 103) + N' (limite da trava de datas).';

    IF @Campo = 'VENCIMENTO'
    BEGIN
        SET @Teto = DATEADD(YEAR, ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_VENCIMENTO_ANOS_FUTURO'), 35), @Hoje);
        IF @Data > @Teto
            RETURN N'O vencimento ' + CONVERT(NVARCHAR(10), @Data, 103) + N' passa do limite de '
                 + CONVERT(NVARCHAR(10), @Teto, 103) + N' (confira o ano).';
        RETURN N'';
    END;

    SET @Futuro = ISNULL(SIS.fn_SIS_Parametro_Inteiro(CASE WHEN @Campo = 'EMISSAO' THEN 'FIN_EMISSAO_DIAS_FUTURO' ELSE 'FIN_BAIXA_DIAS_FUTURO' END), 0);
    IF @Data > DATEADD(DAY, @Futuro, @Hoje)
        RETURN N'A data ' + @Nome + N' ' + CONVERT(NVARCHAR(10), @Data, 103)
             + CASE WHEN @Futuro = 0 THEN N' não pode ser futura.' ELSE N' passa de ' + CONVERT(NVARCHAR(10), @Futuro) + N' dias no futuro.' END;

    RETURN N'';
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.fn_FIN_Regra_Nivel.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Regra_Nivel]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Lê o nível de uma regra de proteção contra erro de digitação
                (P17) no parâmetro @Chave: AVISO, BLOQUEIO ou NAO (desligada).
                Valor vazio ou estranho vale AVISO (nunca desliga uma regra
                por engano). Nunca devolve NULL.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Regra_Nivel] (@Chave VARCHAR(60))
RETURNS VARCHAR(12)
AS
BEGIN
    DECLARE @Valor NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro(@Chave), N''))));

    RETURN CASE WHEN @Valor IN (N'AVISO', N'BLOQUEIO', N'NAO') THEN CONVERT(VARCHAR(12), @Valor) ELSE 'AVISO' END;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Parametro_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Parametro_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Lista dos parâmetros para a tela do administrador, com o módulo
                de cada um. Filtros opcionais: módulo e texto (procura na chave
                e na descrição). Os não editáveis (EDITAVEL_ADMIN = 0) também
                aparecem, só para consulta.
                Padrão "Listar": THROW 50001 com mensagem amigável em erro.
                Permissão: SIS_PARAMETRO / VER.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: recebe @IdUsuario e confere a permissão
                        SIS_PARAMETRO / VER.
    v1.2 (25/11/2026) - Etapa 04f: @SoUso = 1 (tela "Parâmetros de uso"):
                        administrador (nível 1 ou 2) com VER em
                        SIS_PARAMETRO_USO vê só os de NIVEL_MINIMO 1. Sem
                        SIS_PARAMETRO (exclusivo do geral), também só os de uso.
                        Devolve NIVEL_MINIMO e OPCOES.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Parametro_Listar @IdUsuario = 2, @Texto = N'senha';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Listar]
    @IdUsuario INT,
    @IdModulo  INT            = NULL,
    @Texto     NVARCHAR(100)  = NULL,
    @SoUso     BIT            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Parametro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @VeTodos    BIT           = 0;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'VER') = 1 AND ISNULL(@SoUso, 0) = 0
            SET @VeTodos = 1;
        IF @VeTodos = 0
           AND (SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO_USO', 'VER') = 0 OR SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) < 1)
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os parâmetros.', 1;

        SET @EtapaAtual = 'Consulta';
        SET @Texto = NULLIF(LTRIM(RTRIM(@Texto)), N'');

        SELECT p.ID_PARAMETRO,
               p.CHAVE,
               p.VALOR,
               p.VALOR_PADRAO,
               p.TIPO,
               p.DESCRICAO,
               p.ID_MODULO,
               m.CODIGO                         AS MODULO_CODIGO,
               m.NOME                           AS MODULO_NOME,
               p.EDITAVEL_ADMIN,
               p.NIVEL_MINIMO,
               p.OPCOES,
               p.DT_ALTERACAO,
               ISNULL(p.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM SIS.Parametro p WITH (NOLOCK)
        INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = p.ID_MODULO
        WHERE (@IdModulo IS NULL OR p.ID_MODULO = @IdModulo)
          AND (@VeTodos = 1 OR p.NIVEL_MINIMO = 1)
          AND (@Texto IS NULL OR p.CHAVE LIKE N'%' + @Texto + N'%' OR p.DESCRICAO LIKE N'%' + @Texto + N'%')
        ORDER BY m.ORDEM_MENU, p.CHAVE
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os parâmetros. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Parametro_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Parametro_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Altera o valor de um parâmetro pela tela do administrador.
                Não cria nem apaga parâmetro (isso é feito só pela carga do
                MASTER). Confere se o parâmetro é editável e se o valor combina
                com o TIPO, e grava no formato canônico:
                  INTEIRO  número inteiro              ("15")
                  DECIMAL  com ponto                   ("2.5"; aceita "2,5")
                  DATA     aaaa-mm-dd                  (aceita dd/mm/aaaa)
                  SN       "S" ou "N"
                  EMAIL    um endereço só, minúsculo   (vazio = não configurado)
                  ARQUIVO  só o nome, sem pasta, sem espaço e sem acento,
                           extensão png/jpg/jpeg/svg/gif (vazio = sem
                           arquivo). A API grava o arquivo na pasta antes.
                  COR      "#RRGGBB" (gravado em maiúsculas)
                  TEXTO    livre (espaços das pontas removidos)
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_PARAMETRO.
                Antes/depois vai para SIS.Auditoria pela trigger (etapa 02c).
                Permissão: SIS_PARAMETRO / ALTERAR.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: recebe @IdUsuario (no lugar do nome) e
                        confere a permissão SIS_PARAMETRO / ALTERAR.
    v1.2 (15/11/2026) - Tipos ARQUIVO e COR (identidade visual).
    v1.3 (15/11/2026) - Correção: nome de arquivo com "_" era recusado (o
                        padrão "[^...._-]" do LIKE não funciona como
                        esperado); ". _ -" agora são retirados antes de
                        conferir se o resto é só letra e número.
    v1.4 (25/11/2026) - Etapa 04f: administrador (nível 1 ou 2) com ALTERAR em
                        SIS_PARAMETRO_USO altera os de NIVEL_MINIMO 1; com
                        OPCOES preenchido, o valor tem de ser uma das opções.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Gravar @IdUsuario = 2, @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'10';
    -- EXEC SIS.SIS_Parametro_Gravar @IdUsuario = 2, @Chave = 'SENHA_TAMANHO_MINIMO', @Valor = N'8';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Gravar]
    @IdUsuario  INT,
    @Chave      VARCHAR(60),
    @Valor      NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128)  = N'[SIS].[SIS_Parametro_Gravar]';
    DECLARE @EtapaAtual   VARCHAR(100)   = 'Validação';
    DECLARE @Recusa       NVARCHAR(400)  = N'';
    DECLARE @IdParametro  INT;
    DECLARE @Tipo         VARCHAR(10)    = '';
    DECLARE @Editavel     BIT            = 0;
    DECLARE @ValorAtual   NVARCHAR(4000) = N'';
    DECLARE @ValorNovo    NVARCHAR(4000) = N'';
    DECLARE @Data         DATE;
    DECLARE @Linhas       INT            = 0;
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @NivelMinimo  TINYINT        = 2;
    DECLARE @Opcoes       NVARCHAR(200)  = N'';
    DECLARE @VeTodos      BIT            = 0;

    BEGIN TRY
        SET @VeTodos = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'ALTERAR');
        IF @VeTodos = 0
           AND (SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO_USO', 'ALTERAR') = 0 OR SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) < 1)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Você não tem permissão para alterar parâmetros.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_PARAMETRO;
            RETURN;
        END;

        SET @Usuario   = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @Chave     = UPPER(LTRIM(RTRIM(ISNULL(@Chave, ''))));
        SET @ValorNovo = LTRIM(RTRIM(ISNULL(@Valor, N'')));

        IF @Chave = ''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe o parâmetro.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_PARAMETRO;
            RETURN;
        END;

        SELECT @IdParametro = p.ID_PARAMETRO,
               @Tipo        = p.TIPO,
               @Editavel    = p.EDITAVEL_ADMIN,
               @ValorAtual  = p.VALOR,
               @NivelMinimo = p.NIVEL_MINIMO,
               @Opcoes      = p.OPCOES
        FROM SIS.Parametro p
        WHERE p.CHAVE = @Chave;

        IF @IdParametro IS NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Parâmetro não encontrado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_PARAMETRO;
            RETURN;
        END;

        IF @VeTodos = 0 AND @NivelMinimo <> 1
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Este parâmetro só pode ser alterado pelo administrador geral.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        IF @Editavel = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Este parâmetro só pode ser alterado na instalação do sistema.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        -- Validação e formato canônico por tipo (só o primeiro problema encontrado é mostrado)
        IF @Tipo = 'INTEIRO'
        BEGIN
            IF TRY_CONVERT(INT, @ValorNovo) IS NULL
                SET @Recusa = N'Informe um número inteiro (sem casas decimais).';
            ELSE
                SET @ValorNovo = CONVERT(NVARCHAR(20), TRY_CONVERT(INT, @ValorNovo));
        END;

        IF @Tipo = 'DECIMAL'
        BEGIN
            SET @ValorNovo = REPLACE(@ValorNovo, N',', N'.');
            IF TRY_CONVERT(DECIMAL(18,6), @ValorNovo) IS NULL
                SET @Recusa = N'Informe um número (use vírgula para as casas decimais, sem ponto de milhar).';
        END;

        IF @Tipo = 'DATA'
        BEGIN
            SET @Data = ISNULL(TRY_CONVERT(DATE, @ValorNovo, 103), TRY_CONVERT(DATE, @ValorNovo, 23));
            IF @Data IS NULL
                SET @Recusa = N'Informe uma data válida (dd/mm/aaaa).';
            ELSE
                SET @ValorNovo = CONVERT(NVARCHAR(10), @Data, 23);
        END;

        IF @Tipo = 'SN'
        BEGIN
            SET @ValorNovo = UPPER(@ValorNovo);
            IF @ValorNovo NOT IN (N'S', N'N')
                SET @Recusa = N'Informe S (sim) ou N (não).';
        END;

        IF @Tipo = 'EMAIL'
        BEGIN
            SET @ValorNovo = LOWER(@ValorNovo);
            IF @ValorNovo <> N''
               AND (   @ValorNovo NOT LIKE N'%_@_%._%'
                    OR @ValorNovo LIKE N'% %'
                    OR @ValorNovo LIKE N'%;%'
                    OR @ValorNovo LIKE N'%,%'
                    OR @ValorNovo LIKE N'%@%@%')
                SET @Recusa = N'Informe um único e-mail válido (para vários destinatários, use um grupo de e-mail).';
        END;

        IF @Tipo = 'ARQUIVO' AND @ValorNovo <> N''
        BEGIN
            IF LEN(@ValorNovo) > 200
               OR REPLACE(REPLACE(REPLACE(@ValorNovo, N'.', N''), N'_', N''), N'-', N'') LIKE N'%[^A-Za-z0-9]%' COLLATE Latin1_General_BIN2
               OR LOWER(@ValorNovo) NOT LIKE N'%_.png'
                  AND LOWER(@ValorNovo) NOT LIKE N'%_.jpg'
                  AND LOWER(@ValorNovo) NOT LIKE N'%_.jpeg'
                  AND LOWER(@ValorNovo) NOT LIKE N'%_.svg'
                  AND LOWER(@ValorNovo) NOT LIKE N'%_.gif'
                SET @Recusa = N'Informe só o nome do arquivo (sem pasta, sem espaço e sem acento), com extensão png, jpg, svg ou gif.';
        END;

        IF @Tipo = 'COR'
        BEGIN
            SET @ValorNovo = UPPER(@ValorNovo);
            IF LEN(@ValorNovo) <> 7 OR @ValorNovo NOT LIKE N'#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]' COLLATE Latin1_General_BIN2
                SET @Recusa = N'Informe a cor no formato #RRGGBB (ex.: #D43414).';
        END;

        IF @Recusa = N'' AND ISNULL(@Opcoes, N'') <> N''
        BEGIN
            SET @ValorNovo = UPPER(@ValorNovo);
            IF NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@Opcoes, N';') s WHERE LTRIM(RTRIM(s.value)) = @ValorNovo)
                SET @Recusa = N'Valor inválido: use ' + REPLACE(@Opcoes, N';', N', ') + N'.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        IF @ValorNovo COLLATE Latin1_General_CS_AS = ISNULL(@ValorAtual, N'')
        BEGIN
            SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Nenhuma alteração: o valor já era este.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE p
           SET p.VALOR             = @ValorNovo,
               p.DT_ALTERACAO      = SYSDATETIME(),
               p.USUARIO_ALTERACAO = @Usuario
        FROM SIS.Parametro p
        WHERE p.ID_PARAMETRO = @IdParametro
          AND p.EDITAVEL_ADMIN = 1;
        SET @Linhas = @@ROWCOUNT;

        IF @Linhas = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'O parâmetro foi alterado ou bloqueado por outra pessoa. Abra a tela de novo.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Parâmetro gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar o parâmetro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(NULL AS INT) AS ID_PARAMETRO;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/CAD/CAD.CAD_Seletor_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [CAD].[CAD_Seletor_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Fonte única das escolhas com busca (componente js/seletor.js) de
                conta do plano (@Tipo = 'PLANO'), centro de custo ('CENTRO') e
                conta bancária ('CONTA'). Só registros ativos e fora da lixeira;
                a busca olha código/número e descrição (sem acento, qualquer parte)
                e, no plano, também o grupo e o subgrupo. @IdEmpresa filtra centros
                e contas; @IdAtual sempre volta (mesmo inativo), para a ficha mostrar
                o valor já gravado. No máximo SELETOR_LIMITE linhas.
                Permissão: VER em qualquer tela que usa essas escolhas (cadastros
                de parceiro, empresa, centro, plano, conta; o FIN entra na 04f).
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e, seletor com busca aprovado pelo Celso).
    v1.1 (25/11/2026) - Etapa 04f: escolhas PESSOA (parceiro; @Filtro =
                        código do tipo, ex.: FORNECEDOR, que aparece primeiro,
                        sem esconder os demais) e HISTORICO (histórico padrão
                        do financeiro); quem vê Contas a pagar ou a receber
                        também usa as escolhas.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Seletor_Listar @IdUsuario = 2, @Tipo = 'PLANO', @Busca = N'cimento';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Seletor_Listar]
    @IdUsuario  INT,
    @Tipo       VARCHAR(10),
    @Busca      NVARCHAR(100) = NULL,
    @IdEmpresa  INT           = NULL,
    @IdAtual    INT           = NULL,
    @Filtro     VARCHAR(20)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Seletor_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Limite     INT;
    DECLARE @Termo      NVARCHAR(102);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver estas escolhas.', 1;
        SET @Tipo = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        IF @Tipo NOT IN ('PLANO', 'CENTRO', 'CONTA', 'PESSOA', 'HISTORICO')
            THROW 50001, N'Escolha inválida.', 1;

        SET @Limite = ISNULL(SIS.fn_SIS_Parametro_Inteiro('SELETOR_LIMITE'), 50);
        IF @Limite NOT BETWEEN 10 AND 500 SET @Limite = 50;
        SET @Busca = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Termo = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';

        SET @EtapaAtual = 'Consulta';
        IF @Tipo = 'PLANO'
            SELECT TOP (@Limite) v.ID, v.CODIGO, v.DESCRICAO, v.COMPLEMENTO, v.ATIVO
            FROM (SELECT v.ID_PLANO_CONTA AS ID, v.CODIGO, v.DESCRICAO, v.GRUPO_DESCRICAO + N' › ' + v.SUBGRUPO_DESCRICAO AS COMPLEMENTO,
                         v.ATIVO_EFETIVO AS ATIVO, v.ORDEM_ARVORE
                  FROM CAD.vw_CAD_Plano_Conta v WITH (NOLOCK)
                  INNER JOIN CAD.Plano_Conta pc WITH (NOLOCK) ON pc.ID_PLANO_CONTA = v.ID_PLANO_CONTA
                  WHERE pc.DT_EXCLUSAO IS NULL
                    AND (v.ID_PLANO_CONTA = @IdAtual
                         OR (v.ATIVO_EFETIVO = 1
                             AND (@Busca = N'' OR v.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo
                                  OR v.SUBGRUPO_DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR v.GRUPO_DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo
                                  OR v.CODIGO LIKE @Busca + '%')))
                 ) v
            ORDER BY CASE WHEN v.ID = @IdAtual THEN 0 ELSE 1 END, v.ORDEM_ARVORE;
        ELSE IF @Tipo = 'CENTRO'
            SELECT TOP (@Limite) cc.ID_CENTRO_CUSTO AS ID, cc.CODIGO, cc.DESCRICAO,
                   ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL)
                     + CASE WHEN cc.DT_ENCERRAMENTO <= CONVERT(DATE, SYSDATETIME()) THEN N' · encerrado em ' + CONVERT(NVARCHAR(10), cc.DT_ENCERRAMENTO, 103) ELSE N'' END AS COMPLEMENTO,
                   cc.ATIVO
            FROM CAD.Centro_Custo cc WITH (NOLOCK)
            INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
            WHERE cc.DT_EXCLUSAO IS NULL
              AND (cc.ID_CENTRO_CUSTO = @IdAtual
                   OR (cc.ATIVO = 1 AND (@IdEmpresa IS NULL OR cc.ID_EMPRESA = @IdEmpresa)
                       AND (@Busca = N'' OR cc.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR cc.CODIGO LIKE @Busca + '%')))
            ORDER BY CASE WHEN cc.ID_CENTRO_CUSTO = @IdAtual THEN 0 ELSE 1 END, cc.CODIGO;
        ELSE IF @Tipo = 'PESSOA'
            SELECT TOP (@Limite) p.ID_PESSOA AS ID,
                   CAST(CASE WHEN p.CPF_CNPJ = '' THEN '' ELSE SIS.fn_SIS_Mascarar_CPF_CNPJ(p.CPF_CNPJ, 0) END AS VARCHAR(20)) AS CODIGO,
                   p.NOME AS DESCRICAO,
                   ISNULL(STUFF((SELECT N', ' + t.DESCRICAO FROM CAD.Pessoa_Tipo x WITH (NOLOCK)
                                 INNER JOIN CAD.Parceiro_Tipo t WITH (NOLOCK) ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO
                                 WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ATIVO = 1 ORDER BY t.ORDEM FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(400)'), 1, 2, N''), N'')
                     + CASE WHEN p.NOME_FANTASIA <> N'' AND p.NOME_FANTASIA <> p.NOME THEN N' · ' + p.NOME_FANTASIA ELSE N'' END AS COMPLEMENTO,
                   p.ATIVO
            FROM CAD.Pessoa p WITH (NOLOCK)
            WHERE p.DT_EXCLUSAO IS NULL
              AND (p.ID_PESSOA = @IdAtual
                   OR (p.ATIVO = 1
                       AND (@Busca = N'' OR p.NOME COLLATE Latin1_General_CI_AI LIKE @Termo OR p.NOME_FANTASIA COLLATE Latin1_General_CI_AI LIKE @Termo
                            OR (LEN(CAD.fn_CAD_Somente_Digitos(@Busca)) >= 3 AND p.CPF_CNPJ LIKE CAD.fn_CAD_Somente_Digitos(@Busca) + '%'))))
            ORDER BY CASE WHEN p.ID_PESSOA = @IdAtual THEN 0 ELSE 1 END,
                     CASE WHEN ISNULL(@Filtro, '') <> '' AND EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo x WITH (NOLOCK)
                                                                    INNER JOIN CAD.Parceiro_Tipo t WITH (NOLOCK) ON t.ID_PARCEIRO_TIPO = x.ID_PARCEIRO_TIPO
                                                                    WHERE x.ID_PESSOA = p.ID_PESSOA AND x.ATIVO = 1 AND t.CODIGO = @Filtro) THEN 0 ELSE 1 END,
                     p.NOME;
        ELSE IF @Tipo = 'HISTORICO'
            SELECT TOP (@Limite) h.ID_HISTORICO_PADRAO AS ID, CAST(h.ID_HISTORICO_PADRAO AS VARCHAR(20)) AS CODIGO, h.DESCRICAO,
                   CAST(N'' AS NVARCHAR(200)) AS COMPLEMENTO, h.ATIVO
            FROM FIN.Historico_Padrao h WITH (NOLOCK)
            WHERE h.ID_HISTORICO_PADRAO = @IdAtual
               OR (h.ATIVO = 1 AND (@Busca = N'' OR h.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo))
            ORDER BY CASE WHEN h.ID_HISTORICO_PADRAO = @IdAtual THEN 0 ELSE 1 END, h.DESCRICAO;
        ELSE
            SELECT TOP (@Limite) c.ID_CONTA AS ID, CAST(c.ID_CONTA AS VARCHAR(20)) AS CODIGO, c.DESCRICAO,
                   ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL)
                     + CASE WHEN c.NUMERO <> '' THEN N' · ag. ' + c.AGENCIA + N' c/c ' + c.NUMERO + CASE WHEN c.NUMERO_DV <> '' THEN N'-' + c.NUMERO_DV ELSE N'' END ELSE N'' END AS COMPLEMENTO,
                   c.ATIVO
            FROM BANCO.Conta c WITH (NOLOCK)
            INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
            WHERE c.DT_EXCLUSAO IS NULL
              AND (c.ID_CONTA = @IdAtual
                   OR (c.ATIVO = 1 AND (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa)
                       AND (@Busca = N'' OR c.DESCRICAO COLLATE Latin1_General_CI_AI LIKE @Termo OR c.NUMERO LIKE @Busca + '%')))
            ORDER BY CASE WHEN c.ID_CONTA = @IdAtual THEN 0 ELSE 1 END, e.RAZAO_SOCIAL, c.ORDEM, c.DESCRICAO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a lista. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Trava_Conferir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Trava_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Trava própria de FIN.Lancamento e FIN.Parcela para a lixeira e
                o desfazer (SIS.Tabela_Config.PROC_VALIDAR, P20). Chamada por
                SIS_Tabela_Trava_Conferir. @Mensagem vazia = pode.
                  - mês fechado da empresa na competência, com conta contábil
                    (pedido 10: só conta marcada como contábil);
                  - LIXEIRA: só lançamento de origem manual, sem baixa (as
                    baixas também barram pela SIS_Lixeira_Referencias);
                  - DESFAZER: recusa se o lançamento (ou a parcela) tem baixa:
                    o que tem pagamento é acertado pela ficha.
                  - origem de outra rotina (venda, compra...): recusa;
                  - LIXEIRA com o usuário da API no contexto: confere EXCLUIR
                    na tela do tipo do lançamento (a pagar ou a receber), já
                    que as duas telas usam as mesmas tabelas.
                Uso interno (DENY para a API).
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Trava_Conferir]
    @Tabela      NVARCHAR(256),
    @IdRegistro  BIGINT,
    @Operacao    VARCHAR(20),
    @Mensagem    NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdLancamento BIGINT;
    DECLARE @Origem       VARCHAR(15);
    DECLARE @Tipo         CHAR(1);
    DECLARE @IdUsuario    INT = TRY_CONVERT(INT, SESSION_CONTEXT(N'ID_USUARIO'));

    SET @Mensagem = N'';

    IF @Tabela = N'FIN.Parcela'
        SELECT @IdLancamento = p.ID_LANCAMENTO FROM FIN.Parcela p WHERE p.ID_PARCELA = @IdRegistro;
    ELSE
        SET @IdLancamento = @IdRegistro;

    SELECT @Origem = l.ORIGEM, @Tipo = l.TIPO FROM FIN.Lancamento l WHERE l.ID_LANCAMENTO = @IdLancamento;
    IF @Origem IS NULL RETURN;

    IF EXISTS (SELECT 1 FROM FIN.Lancamento l
               INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = l.ID_EMPRESA AND m.MES = l.DT_COMPETENCIA AND m.FECHADO = 1
               INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.CONTABIL = 1
               WHERE l.ID_LANCAMENTO = @IdLancamento)
    BEGIN
        SET @Mensagem = N'O mês do lançamento está fechado (conta contábil).';
        RETURN;
    END;

    IF @Origem NOT IN ('MANUAL', 'MIGRACAO')
    BEGIN
        SET @Mensagem = N'Lançamento gerado por outra rotina (' + CONVERT(NVARCHAR(15), @Origem) + N'): use a tela de origem.';
        RETURN;
    END;

    IF @Operacao = 'LIXEIRA' AND @IdUsuario IS NOT NULL
       AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'EXCLUIR') = 0
    BEGIN
        SET @Mensagem = N'Você não tem permissão para excluir lançamentos a ' + CASE @Tipo WHEN 'P' THEN N'pagar.' ELSE N'receber.' END;
        RETURN;
    END;

    IF @Operacao = 'LIXEIRA' AND @Origem <> 'MANUAL'
    BEGIN
        SET @Mensagem = N'Só lançamento incluído pela tela vai para a lixeira; os que vieram do Access podem ser cancelados.';
        RETURN;
    END;

    IF @Operacao IN ('LIXEIRA', 'DESFAZER')
       AND EXISTS (SELECT 1 FROM FIN.Baixa b INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA
                   WHERE p.ID_LANCAMENTO = @IdLancamento AND (@Tabela <> N'FIN.Parcela' OR p.ID_PARCELA = @IdRegistro))
    BEGIN
        SET @Mensagem = N'O lançamento tem pagamento ou recebimento: acerte pela ficha (as baixas não são desfeitas por aqui).';
        RETURN;
    END;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Inclui (@IdLancamento NULL) ou altera um lançamento a pagar (P)
                ou a receber (R) com as suas parcelas (telas Contas a pagar e
                Contas a receber, etapa 04f). Tudo-ou-nada.
                @Parcelas: JSON [{"id":null|ID_PARCELA,"vencimento":"aaaa-mm-dd",
                "valor":100.00,"idContaPrevista":null}]; a numeração é refeita
                pela ordem de vencimento. Parcela existente fora da lista é
                retirada (só sem baixa). Empresa vem do centro de custo.
                Proteções contra erro de digitação (P17), conferidas aqui e na
                prévia (@SomenteConferir = 1, usada por FIN_Lancamento_Conferir):
                  BLOQUEIO  não grava (fixos: parceiro/centro/conta inativos,
                            mês fechado de conta contábil, trava de datas sem a
                            permissão LANCAR_RETROATIVO; e as regras FIN_REGRA_*
                            com BLOQUEIO, CENTRO_ENCERRADO_BLOQUEIA = S);
                  MOTIVO    trava de datas para quem tem LANCAR_RETROATIVO:
                            grava só com @MotivoRetroativo;
                  AVISO     grava só se o código vier em @AvisosConfirmados
                            (lista separada por vírgula).
                Avisos confirmados e motivos ficam em SIS.Aviso_Confirmado.
                Em alteração, cada regra só olha o que mudou. Com baixa, ficam
                travados o parceiro, o valor total e as parcelas com baixa.
                Duplicidade de documento: só documento com número (no Access o
                campo também guardava textos como "Pis, Cofins e CSLL").
                @MarcarTipoParceiro = 1: marca o tipo Fornecedor (P) ou Cliente
                (R) no parceiro (resposta ao aviso TIPO_PARCEIRO).
                Permissão: INCLUIR ou ALTERAR em FIN_PAGAR / FIN_RECEBER.
                Devolve 1 linha: SUCESSO, MENSAGEM, ID, PENDENTE (há avisos a
                confirmar ou motivo a informar) e AVISOS (JSON: codigo, nivel,
                mensagem, idReferencia, campo).
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Gravar @IdUsuario = 2, @Tipo = 'P', @IdCentroCusto = 1, @IdPessoa = 1, @IdPlanoConta = 1,
    --      @DtEmissao = '2026-11-25', @ValorTotal = 100, @Parcelas = N'[{"vencimento":"2026-12-10","valor":100}]', @SomenteConferir = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Gravar]
    @IdUsuario           INT,
    @IdLancamento        BIGINT          = NULL,
    @Tipo                CHAR(1)         = NULL,
    @IdCentroCusto       INT             = NULL,
    @IdPessoa            INT             = NULL,
    @IdPlanoConta        INT             = NULL,
    @IdHistoricoPadrao   INT             = NULL,
    @Documento           NVARCHAR(40)    = NULL,
    @DtEmissao           DATE            = NULL,
    @DtCompetencia       DATE            = NULL,
    @Historico           NVARCHAR(200)   = NULL,
    @Observacao          NVARCHAR(2000)  = NULL,
    @ValorTotal          DECIMAL(18,2)   = NULL,
    @Previsao            BIT             = 0,
    @Integracao          VARCHAR(12)     = NULL,
    @Parcelas            NVARCHAR(MAX)   = NULL,
    @AvisosConfirmados   NVARCHAR(1000)  = NULL,
    @MotivoRetroativo    NVARCHAR(400)   = NULL,
    @MarcarTipoParceiro  BIT             = 0,
    @SomenteConferir     BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Gravar]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Validação';
    DECLARE @Recusa       NVARCHAR(400) = N'';
    DECLARE @Usuario      NVARCHAR(100);
    DECLARE @Item         VARCHAR(40);
    DECLARE @Hoje         DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Novo         BIT;
    DECLARE @Avisos       NVARCHAR(MAX) = N'[]';
    DECLARE @Pendente     BIT = 0;
    DECLARE @Nivel        VARCHAR(12);
    DECLARE @N            INT;
    DECLARE @Meses        INT;
    DECLARE @V            DECIMAL(18,6);
    DECLARE @Soma         DECIMAL(18,2);
    DECLARE @IdEmpresa    INT;
    DECLARE @TemBaixa     BIT = 0;
    DECLARE @PodeRetro    BIT = 0;
    DECLARE @IdTipoMarcar INT;
    DECLARE @IdTipoNA     INT;

    -- valores atuais (alteração)
    DECLARE @aTipo CHAR(1), @aCentro INT, @aPessoa INT, @aPlano INT, @aDocumento NVARCHAR(40), @aEmissao DATE,
            @aCompetencia DATE, @aValor DECIMAL(18,2), @aOrigem VARCHAR(15), @aSituacao VARCHAR(10), @aEmpresa INT;
    DECLARE @MudouPessoa BIT = 1, @MudouPlano BIT = 1, @MudouCentro BIT = 1, @MudouEmissao BIT = 1,
            @MudouCompetencia BIT = 1, @MudouValor BIT = 1, @MudouDocumento BIT = 1;

    DROP TABLE IF EXISTS #P;
    DROP TABLE IF EXISTS #Regra;
    CREATE TABLE #P (CHAVE INT NOT NULL, ID_PARCELA BIGINT NULL, DT_VENCIMENTO DATE NULL, VALOR DECIMAL(18,2) NULL,
                     ID_CONTA_PREVISTA INT NULL, NUMERO SMALLINT NULL, MUDOU BIT NOT NULL DEFAULT (1));
    CREATE TABLE #Regra (ORDEM INT IDENTITY(1,1), CODIGO VARCHAR(40) NOT NULL, NIVEL VARCHAR(12) NOT NULL,
                         MENSAGEM NVARCHAR(400) NOT NULL, ID_REFERENCIA BIGINT NULL, CAMPO VARCHAR(40) NOT NULL DEFAULT (''));

    BEGIN TRY
        SET @Novo               = CASE WHEN @IdLancamento IS NULL THEN 1 ELSE 0 END;
        SET @Documento          = LTRIM(RTRIM(ISNULL(@Documento, N'')));
        SET @Historico          = LTRIM(RTRIM(ISNULL(@Historico, N'')));
        SET @Observacao         = LTRIM(RTRIM(ISNULL(@Observacao, N'')));
        SET @Integracao         = UPPER(LTRIM(RTRIM(ISNULL(@Integracao, 'COMPLETA'))));
        SET @Previsao           = ISNULL(@Previsao, 0);
        SET @MotivoRetroativo   = LTRIM(RTRIM(ISNULL(@MotivoRetroativo, N'')));
        SET @AvisosConfirmados  = UPPER(ISNULL(@AvisosConfirmados, N''));
        SET @MarcarTipoParceiro = ISNULL(@MarcarTipoParceiro, 0);
        SET @SomenteConferir    = ISNULL(@SomenteConferir, 0);

        ---------------------------------------------------------------------
        -- 1) Situação atual (alteração) e permissão
        ---------------------------------------------------------------------
        IF @Novo = 0
        BEGIN
            SELECT @aTipo = l.TIPO, @aCentro = l.ID_CENTRO_CUSTO, @aPessoa = l.ID_PESSOA, @aPlano = l.ID_PLANO_CONTA,
                   @aDocumento = l.DOCUMENTO, @aEmissao = l.DT_EMISSAO, @aCompetencia = l.DT_COMPETENCIA, @aValor = l.VALOR_TOTAL,
                   @aOrigem = l.ORIGEM, @aSituacao = l.SITUACAO, @aEmpresa = l.ID_EMPRESA
            FROM FIN.Lancamento l
            WHERE l.ID_LANCAMENTO = @IdLancamento;

            IF @aTipo IS NULL
                SET @Recusa = N'Lançamento não encontrado.';
            ELSE
                SET @Tipo = @aTipo;

            IF EXISTS (SELECT 1 FROM FIN.Baixa b INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA WHERE p.ID_LANCAMENTO = @IdLancamento)
                SET @TemBaixa = 1;
        END;

        SET @Tipo = UPPER(ISNULL(@Tipo, ''));
        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' WHEN 'R' THEN 'FIN_RECEBER' ELSE '' END;

        IF @Recusa = N'' AND @Item = ''
            SET @Recusa = N'Informe se o lançamento é a pagar ou a receber.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, CASE WHEN @Novo = 1 THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para ' + CASE WHEN @Novo = 1 THEN N'incluir' ELSE N'alterar' END
                        + N' contas a ' + CASE @Tipo WHEN 'P' THEN N'pagar.' ELSE N'receber.' END;
        IF @Recusa = N'' AND @Novo = 0 AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento) = 1
            SET @Recusa = N'O lançamento está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @Novo = 0 AND @aSituacao = 'CANCELADO'
            SET @Recusa = N'O lançamento está cancelado e não pode ser alterado.';
        IF @Recusa = N'' AND @Novo = 0 AND @aOrigem NOT IN ('MANUAL', 'MIGRACAO')
            SET @Recusa = N'Este lançamento foi gerado por outra rotina (' + CONVERT(NVARCHAR(15), @aOrigem) + N'): altere pela tela de origem.';

        ---------------------------------------------------------------------
        -- 2) Campos do documento
        ---------------------------------------------------------------------
        IF @Recusa = N'' AND @IdCentroCusto IS NULL AND (@Novo = 1 OR @aCentro IS NOT NULL)
            SET @Recusa = N'Escolha o centro de custo (obra ou setor).';
        IF @Recusa = N'' AND @IdPessoa IS NULL AND (@Novo = 1 OR @aPessoa IS NOT NULL)
            SET @Recusa = N'Escolha o parceiro (' + CASE @Tipo WHEN 'P' THEN N'fornecedor' ELSE N'cliente' END + N').';
        IF @Recusa = N'' AND @IdPlanoConta IS NULL AND (@Novo = 1 OR @aPlano IS NOT NULL)
            SET @Recusa = N'Escolha a conta do plano de contas.';
        IF @Recusa = N'' AND @DtEmissao IS NULL
            SET @Recusa = N'Informe a data de emissão do documento.';
        IF @Recusa = N'' AND @DtEmissao NOT BETWEEN '1990-01-01' AND '2099-12-31'
            SET @Recusa = N'Data de emissão inválida: confira o ano.';
        IF @Recusa = N'' AND ISNULL(@ValorTotal, 0) <= 0
            SET @Recusa = N'Informe o valor total (maior que zero).';
        IF @Recusa = N'' AND @Integracao NOT IN ('COMPLETA', 'SO_CONTABIL', 'NENHUMA')
            SET @Recusa = N'Integração inválida.';
        IF @Recusa = N'' AND @IdHistoricoPadrao IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM FIN.Historico_Padrao h WHERE h.ID_HISTORICO_PADRAO = @IdHistoricoPadrao AND h.ATIVO = 1)
            SET @Recusa = N'O histórico padrão escolhido não existe ou está desativado.';
        IF @Recusa = N'' AND @IdCentroCusto IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCentroCusto)
            SET @Recusa = N'Centro de custo não encontrado.';
        IF @Recusa = N'' AND @IdPessoa IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa)
            SET @Recusa = N'Parceiro não encontrado.';
        IF @Recusa = N'' AND @IdPlanoConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @IdPlanoConta)
            SET @Recusa = N'Conta do plano não encontrada.';

        IF @DtEmissao IS NOT NULL
            SET @DtCompetencia = DATEFROMPARTS(YEAR(ISNULL(@DtCompetencia, @DtEmissao)), MONTH(ISNULL(@DtCompetencia, @DtEmissao)), 1);
        SELECT @IdEmpresa = c.ID_EMPRESA FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCentroCusto;
        SET @IdEmpresa = ISNULL(@IdEmpresa, @aEmpresa);
        IF @Recusa = N'' AND @IdEmpresa IS NULL
            SET @Recusa = N'Escolha o centro de custo (a empresa vem dele).';

        IF @Novo = 0
        BEGIN
            SET @MudouPessoa      = CASE WHEN ISNULL(@IdPessoa, 0)      = ISNULL(@aPessoa, 0)  THEN 0 ELSE 1 END;
            SET @MudouPlano       = CASE WHEN ISNULL(@IdPlanoConta, 0)  = ISNULL(@aPlano, 0)   THEN 0 ELSE 1 END;
            SET @MudouCentro      = CASE WHEN ISNULL(@IdCentroCusto, 0) = ISNULL(@aCentro, 0)  THEN 0 ELSE 1 END;
            SET @MudouEmissao     = CASE WHEN @DtEmissao = @aEmissao         THEN 0 ELSE 1 END;
            SET @MudouCompetencia = CASE WHEN @DtCompetencia = @aCompetencia THEN 0 ELSE 1 END;
            SET @MudouValor       = CASE WHEN @ValorTotal = @aValor          THEN 0 ELSE 1 END;
            SET @MudouDocumento   = CASE WHEN @Documento = ISNULL(@aDocumento, N'') COLLATE Latin1_General_CI_AI THEN 0 ELSE 1 END;
        END;

        IF @Recusa = N'' AND @TemBaixa = 1 AND @MudouPessoa = 1
            SET @Recusa = N'O lançamento já tem pagamento ou recebimento: o parceiro não pode mudar.';
        IF @Recusa = N'' AND @TemBaixa = 1 AND @MudouValor = 1
            SET @Recusa = N'O lançamento já tem pagamento ou recebimento: o valor total não pode mudar (ajuste só as parcelas em aberto).';

        ---------------------------------------------------------------------
        -- 3) Parcelas
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Parcelas';
        IF @Recusa = N'' AND (ISNULL(@Parcelas, N'') = N'' OR ISJSON(@Parcelas) = 0)
            SET @Recusa = N'Informe ao menos uma parcela (use "Gerar parcelas").';

        IF @Recusa = N''
        BEGIN
            INSERT INTO #P (CHAVE, ID_PARCELA, DT_VENCIMENTO, VALOR, ID_CONTA_PREVISTA)
            SELECT CONVERT(INT, k.[key]), j.id, TRY_CONVERT(DATE, j.vencimento, 23), j.valor, j.idContaPrevista
            FROM OPENJSON(@Parcelas) k
            CROSS APPLY OPENJSON(k.value) WITH (id BIGINT '$.id', vencimento VARCHAR(10) '$.vencimento',
                                                valor DECIMAL(18,2) '$.valor', idContaPrevista INT '$.idContaPrevista') j
            WHERE k.[type] = 5;

            SET @N    = (SELECT COUNT(*) FROM #P);
            SET @Soma = (SELECT ISNULL(SUM(x.VALOR), 0) FROM #P x);

            IF @N = 0
                SET @Recusa = N'Informe ao menos uma parcela (use "Gerar parcelas").';
            ELSE IF @N > 480
                SET @Recusa = N'No máximo 480 parcelas por lançamento.';
            ELSE IF EXISTS (SELECT 1 FROM #P WHERE DT_VENCIMENTO IS NULL OR DT_VENCIMENTO NOT BETWEEN '1990-01-01' AND '2099-12-31')
                SET @Recusa = N'Parcela ' + (SELECT TOP 1 CONVERT(NVARCHAR(5), CHAVE + 1) FROM #P
                                              WHERE DT_VENCIMENTO IS NULL OR DT_VENCIMENTO NOT BETWEEN '1990-01-01' AND '2099-12-31' ORDER BY CHAVE)
                            + N': informe um vencimento válido.';
            ELSE IF EXISTS (SELECT 1 FROM #P WHERE ISNULL(VALOR, 0) <= 0)
                SET @Recusa = N'Parcela ' + (SELECT TOP 1 CONVERT(NVARCHAR(5), CHAVE + 1) FROM #P WHERE ISNULL(VALOR, 0) <= 0 ORDER BY CHAVE)
                            + N': informe um valor maior que zero.';
            ELSE IF @Soma <> @ValorTotal
                SET @Recusa = N'A soma das parcelas (' + SIS.fn_SIS_Formatar_Moeda(@Soma)
                            + N') é diferente do valor total (' + SIS.fn_SIS_Formatar_Moeda(@ValorTotal) + N').';
            ELSE IF EXISTS (SELECT 1 FROM #P x WHERE x.ID_PARCELA IS NOT NULL
                              AND NOT EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_PARCELA = x.ID_PARCELA AND p.ID_LANCAMENTO = ISNULL(@IdLancamento, 0)))
                SET @Recusa = N'Parcela de outro lançamento na lista: abra a ficha de novo.';
            ELSE IF EXISTS (SELECT x.ID_PARCELA FROM #P x WHERE x.ID_PARCELA IS NOT NULL GROUP BY x.ID_PARCELA HAVING COUNT(*) > 1)
                SET @Recusa = N'Parcela repetida na lista: abra a ficha de novo.';
            ELSE IF EXISTS (SELECT 1 FROM #P x WHERE x.ID_CONTA_PREVISTA IS NOT NULL
                              AND NOT EXISTS (SELECT 1 FROM BANCO.Conta c WHERE c.ID_CONTA = x.ID_CONTA_PREVISTA AND c.DT_EXCLUSAO IS NULL
                                                AND (c.ATIVO = 1 OR EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_PARCELA = x.ID_PARCELA AND p.ID_CONTA_PREVISTA = c.ID_CONTA))))
                SET @Recusa = N'A conta bancária prevista de uma parcela não existe ou está desativada.';
        END;

        IF @Recusa = N'' AND @Novo = 0
        BEGIN
            UPDATE x
               SET x.MUDOU = CASE WHEN p.DT_VENCIMENTO = x.DT_VENCIMENTO AND p.VALOR = x.VALOR THEN 0 ELSE 1 END
            FROM #P x
            INNER JOIN FIN.Parcela p ON p.ID_PARCELA = x.ID_PARCELA;

            -- parcelas com baixa: não mudam e não saem
            IF EXISTS (SELECT 1 FROM FIN.Parcela p
                       WHERE p.ID_LANCAMENTO = @IdLancamento
                         AND EXISTS (SELECT 1 FROM FIN.Baixa b WHERE b.ID_PARCELA = p.ID_PARCELA)
                         AND NOT EXISTS (SELECT 1 FROM #P x WHERE x.ID_PARCELA = p.ID_PARCELA AND x.MUDOU = 0))
                SET @Recusa = N'Parcela com pagamento ou recebimento não pode mudar de vencimento ou valor, nem ser retirada.';
        END;

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID,
                   CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #P;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        WITH n AS (SELECT x.NUMERO, ROW_NUMBER() OVER (ORDER BY x.DT_VENCIMENTO, x.CHAVE) AS NOVO FROM #P x)
        UPDATE n SET n.NUMERO = n.NOVO;

        ---------------------------------------------------------------------
        -- 4) Regras (P17)
        ---------------------------------------------------------------------
        SET @EtapaAtual = 'Regras';
        SET @PodeRetro = SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'LANCAR_RETROATIVO');

        -- cadastros inativos (bloqueio fixo)
        IF @MudouPessoa = 1 AND @IdPessoa IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa AND (p.ATIVO = 0 OR p.DT_EXCLUSAO IS NOT NULL))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('PARCEIRO_INATIVO', 'BLOQUEIO', N'O parceiro escolhido está desativado ou na lixeira.', 'idPessoa');
        IF @MudouCentro = 1 AND @IdCentroCusto IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.Centro_Custo c WHERE c.ID_CENTRO_CUSTO = @IdCentroCusto AND (c.ATIVO = 0 OR c.DT_EXCLUSAO IS NOT NULL))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CENTRO_INATIVO', 'BLOQUEIO', N'O centro de custo escolhido está desativado ou na lixeira.', 'idCentroCusto');
        IF @MudouPlano = 1 AND @IdPlanoConta IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.vw_CAD_Plano_Conta v INNER JOIN CAD.Plano_Conta c ON c.ID_PLANO_CONTA = v.ID_PLANO_CONTA
                       WHERE v.ID_PLANO_CONTA = @IdPlanoConta AND (v.ATIVO_EFETIVO = 0 OR c.DT_EXCLUSAO IS NOT NULL))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO) VALUES ('CONTA_INATIVA', 'BLOQUEIO', N'A conta do plano escolhida está desativada ou na lixeira.', 'idPlanoConta');

        -- centro de custo encerrado
        IF (@MudouCentro = 1 OR @MudouEmissao = 1)
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT 'CENTRO_ENCERRADO', CASE WHEN ISNULL(SIS.fn_SIS_Parametro_SN('CENTRO_ENCERRADO_BLOQUEIA'), 1) = 1 THEN 'BLOQUEIO' ELSE 'AVISO' END,
                   N'O centro de custo ' + CONVERT(NVARCHAR(20), c.CODIGO) + N' foi encerrado em ' + CONVERT(NVARCHAR(10), c.DT_ENCERRAMENTO, 103) + N'.', 'idCentroCusto'
            FROM CAD.Centro_Custo c
            WHERE c.ID_CENTRO_CUSTO = @IdCentroCusto AND c.DT_ENCERRAMENTO <= @DtEmissao;

        -- mês fechado (só conta contábil; olha o mês novo e, na alteração, o atual)
        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'MES_FECHADO', 'BLOQUEIO',
               N'O mês ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(m.MES)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(m.MES))
               + N' está fechado para a empresa ' + ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) + N' (conta contábil).', 'dtCompetencia'
        FROM (SELECT @IdEmpresa AS EMP, @DtCompetencia AS MES, @IdPlanoConta AS PLANO
              UNION ALL SELECT @aEmpresa, @aCompetencia, @aPlano WHERE @Novo = 0) x
        INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = x.EMP AND m.MES = x.MES AND m.FECHADO = 1
        INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = x.PLANO AND pc.CONTABIL = 1
        INNER JOIN CAD.Empresa e      ON e.ID_EMPRESA = x.EMP
        ORDER BY m.MES;

        -- trava de datas (bloqueio, ou motivo para quem tem LANCAR_RETROATIVO)
        IF @MudouEmissao = 1 AND FIN.fn_FIN_Data_Recusa('EMISSAO', @DtEmissao) <> N''
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_EMISSAO', CASE WHEN @PodeRetro = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END, FIN.fn_FIN_Data_Recusa('EMISSAO', @DtEmissao), 'dtEmissao');

        INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
        SELECT TOP 1 'DATA_VENCIMENTO', CASE WHEN @PodeRetro = 1 THEN 'MOTIVO' ELSE 'BLOQUEIO' END,
               N'Parcela ' + CONVERT(NVARCHAR(5), x.NUMERO) + N': ' + FIN.fn_FIN_Data_Recusa('VENCIMENTO', x.DT_VENCIMENTO), 'parcelas'
        FROM #P x
        WHERE x.MUDOU = 1 AND FIN.fn_FIN_Data_Recusa('VENCIMENTO', x.DT_VENCIMENTO) <> N''
        ORDER BY x.NUMERO;

        -- data a confirmar (dentro do permitido, mas distante de hoje)
        SET @N = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_DATA_AVISO_DIAS'), 3);
        IF @MudouEmissao = 1 AND ABS(DATEDIFF(DAY, @Hoje, @DtEmissao)) > @N AND NOT EXISTS (SELECT 1 FROM #Regra WHERE CODIGO = 'DATA_EMISSAO')
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('DATA_CONFIRMAR', 'AVISO', N'Confirma a data de emissão ' + CONVERT(NVARCHAR(10), @DtEmissao, 103) + N'?', 'dtEmissao');
        IF NOT EXISTS (SELECT 1 FROM #Regra WHERE CODIGO IN ('DATA_VENCIMENTO', 'DATA_CONFIRMAR'))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT TOP 1 'DATA_CONFIRMAR', 'AVISO',
                   N'Confirma o vencimento ' + CONVERT(NVARCHAR(10), x.DT_VENCIMENTO, 103) + N' (parcela ' + CONVERT(NVARCHAR(5), x.NUMERO) + N', já passado)?', 'parcelas'
            FROM #P x
            WHERE x.MUDOU = 1 AND x.DT_VENCIMENTO < DATEADD(DAY, -@N, @Hoje)
            ORDER BY x.NUMERO;

        -- vencimento antes da emissão
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_VENC_ANTES_EMISSAO');
        IF @Nivel <> 'NAO'
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT TOP 1 'VENC_ANTES_EMISSAO', @Nivel,
                   N'A parcela ' + CONVERT(NVARCHAR(5), x.NUMERO) + N' vence em ' + CONVERT(NVARCHAR(10), x.DT_VENCIMENTO, 103)
                   + N', antes da emissão (' + CONVERT(NVARCHAR(10), @DtEmissao, 103) + N').', 'parcelas'
            FROM #P x
            WHERE (x.MUDOU = 1 OR @MudouEmissao = 1) AND x.DT_VENCIMENTO < @DtEmissao
            ORDER BY x.NUMERO;

        -- competência distante da emissão
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_COMPETENCIA_DISTANTE');
        SET @N = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_COMPETENCIA_MESES'), 3);
        SET @Meses = ABS(DATEDIFF(MONTH, @DtEmissao, @DtCompetencia));
        IF @Nivel <> 'NAO' AND (@MudouEmissao = 1 OR @MudouCompetencia = 1) AND @Meses > @N
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('COMPETENCIA_DISTANTE', @Nivel,
                    N'A competência ' + RIGHT('0' + CONVERT(NVARCHAR(2), MONTH(@DtCompetencia)), 2) + N'/' + CONVERT(NVARCHAR(4), YEAR(@DtCompetencia))
                    + N' está a ' + CONVERT(NVARCHAR(5), @Meses) + N' meses da emissão.', 'dtCompetencia');

        -- mesmo parceiro e mesmo documento (só documento com número)
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_DUPLIC_DOCUMENTO');
        IF @Nivel <> 'NAO' AND @IdPessoa IS NOT NULL AND @Documento LIKE N'%[0-9]%' AND (@MudouDocumento = 1 OR @MudouPessoa = 1)
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
            SELECT TOP 1 'DUPLIC_DOCUMENTO', @Nivel,
                   N'O documento ' + l.DOCUMENTO + N' deste parceiro já foi lançado (nº ' + CONVERT(NVARCHAR(20), l.ID_LANCAMENTO)
                   + N', emissão ' + CONVERT(NVARCHAR(10), l.DT_EMISSAO, 103) + N', ' + SIS.fn_SIS_Formatar_Moeda(l.VALOR_TOTAL) + N').',
                   l.ID_LANCAMENTO, 'documento'
            FROM FIN.Lancamento l WITH (NOLOCK)
            WHERE l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.DOCUMENTO = @Documento
              AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL AND l.ID_LANCAMENTO <> ISNULL(@IdLancamento, 0)
            ORDER BY l.DT_EMISSAO DESC, l.ID_LANCAMENTO DESC;

        -- possível duplicidade: mesmo parceiro, mesmo valor de parcela, vencimento próximo
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_DUPLIC_VALOR');
        SET @N = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_DUPLIC_VALOR_DIAS'), 5);
        IF @Nivel <> 'NAO' AND @IdPessoa IS NOT NULL
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, ID_REFERENCIA, CAMPO)
            SELECT TOP 1 'DUPLIC_VALOR', @Nivel,
                   N'Possível duplicidade: o lançamento nº ' + CONVERT(NVARCHAR(20), l.ID_LANCAMENTO) + N' deste parceiro tem parcela de '
                   + SIS.fn_SIS_Formatar_Moeda(p.VALOR) + N' com vencimento em ' + CONVERT(NVARCHAR(10), p.DT_VENCIMENTO, 103) + N'.',
                   l.ID_LANCAMENTO, 'parcelas'
            FROM #P x
            INNER JOIN FIN.Parcela p    WITH (NOLOCK) ON p.VALOR = x.VALOR AND p.SITUACAO <> 'CANCELADA'
                                                     AND p.DT_VENCIMENTO BETWEEN DATEADD(DAY, -@N, x.DT_VENCIMENTO) AND DATEADD(DAY, @N, x.DT_VENCIMENTO)
            INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
            WHERE (x.MUDOU = 1 OR @MudouPessoa = 1)
              AND l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL
              AND l.ID_LANCAMENTO <> ISNULL(@IdLancamento, 0)
              AND NOT EXISTS (SELECT 1 FROM #Regra r WHERE r.CODIGO = 'DUPLIC_DOCUMENTO' AND r.ID_REFERENCIA = l.ID_LANCAMENTO)
            ORDER BY ABS(DATEDIFF(DAY, x.DT_VENCIMENTO, p.DT_VENCIMENTO)), l.ID_LANCAMENTO DESC;

        -- valor fora do padrão (média do mesmo parceiro e conta do plano)
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_VALOR_FORA_PADRAO');
        IF @Nivel <> 'NAO' AND @IdPessoa IS NOT NULL AND @IdPlanoConta IS NOT NULL AND (@MudouValor = 1 OR @MudouPessoa = 1 OR @MudouPlano = 1)
        BEGIN
            SET @V     = ISNULL(SIS.fn_SIS_Parametro_Decimal('FIN_VALOR_FORA_PADRAO_VEZES'), 3);
            SET @N     = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_VALOR_FORA_PADRAO_MIN_HIST'), 3);
            SET @Meses = ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_VALOR_FORA_PADRAO_MESES'), 12);
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT 'VALOR_FORA_PADRAO', @Nivel,
                   N'O valor ' + SIS.fn_SIS_Formatar_Moeda(@ValorTotal) + N' é ' + CONVERT(NVARCHAR(20), CAST(ROUND(@ValorTotal / NULLIF(h.MEDIA, 0), 1) AS DECIMAL(18,1)))
                   + N' vezes a média (' + SIS.fn_SIS_Formatar_Moeda(CAST(h.MEDIA AS DECIMAL(18,2))) + N') dos últimos ' + CONVERT(NVARCHAR(10), h.QTD)
                   + N' lançamentos deste parceiro nesta conta.', 'valorTotal'
            FROM (SELECT COUNT(*) AS QTD, AVG(l.VALOR_TOTAL) AS MEDIA
                  FROM FIN.Lancamento l WITH (NOLOCK)
                  WHERE l.ID_PESSOA = @IdPessoa AND l.ID_PLANO_CONTA = @IdPlanoConta AND l.TIPO = @Tipo
                    AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL AND l.ID_LANCAMENTO <> ISNULL(@IdLancamento, 0)
                    AND l.DT_EMISSAO >= DATEADD(MONTH, -@Meses, @DtEmissao)
                    AND l.DT_EMISSAO <= @DtEmissao) h
            WHERE h.QTD >= @N AND h.MEDIA > 0 AND @ValorTotal > h.MEDIA * @V;
        END;

        -- parceiro sem o tipo Fornecedor / Cliente
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_TIPO_PARCEIRO');
        IF @Nivel <> 'NAO' AND @MudouPessoa = 1 AND @MarcarTipoParceiro = 0
           AND EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa AND ((@Tipo = 'P' AND p.FORNECEDOR = 0) OR (@Tipo = 'R' AND p.CLIENTE = 0)))
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            VALUES ('TIPO_PARCEIRO', @Nivel, N'O parceiro não está marcado como ' + CASE @Tipo WHEN 'P' THEN N'Fornecedor' ELSE N'Cliente' END + N'.', 'idPessoa');

        -- conta de receita no a pagar, ou de despesa no a receber
        SET @Nivel = FIN.fn_FIN_Regra_Nivel('FIN_REGRA_TIPO_CONTA');
        IF @Nivel <> 'NAO' AND @MudouPlano = 1
            INSERT INTO #Regra (CODIGO, NIVEL, MENSAGEM, CAMPO)
            SELECT 'TIPO_CONTA', @Nivel,
                   N'A conta ' + CONVERT(NVARCHAR(12), v.CODIGO) + N' - ' + v.DESCRICAO + N' é de ' + CASE v.TIPO WHEN 'RECEITA' THEN N'receita' ELSE N'despesa' END
                   + N' e o lançamento é a ' + CASE @Tipo WHEN 'P' THEN N'pagar.' ELSE N'receber.' END, 'idPlanoConta'
            FROM CAD.vw_CAD_Plano_Conta v
            WHERE v.ID_PLANO_CONTA = @IdPlanoConta AND ((@Tipo = 'P' AND v.TIPO = 'RECEITA') OR (@Tipo = 'R' AND v.TIPO = 'DESPESA'));

        ---------------------------------------------------------------------
        -- 5) Resultado das regras
        ---------------------------------------------------------------------
        SET @Avisos = ISNULL((SELECT r.CODIGO AS codigo, r.NIVEL AS nivel, r.MENSAGEM AS mensagem, r.ID_REFERENCIA AS idReferencia, r.CAMPO AS campo
                              FROM #Regra r
                              ORDER BY CASE r.NIVEL WHEN 'BLOQUEIO' THEN 0 WHEN 'MOTIVO' THEN 1 ELSE 2 END, r.ORDEM
                              FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]');

        IF EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'BLOQUEIO')
        BEGIN
            SELECT TOP 1 @Recusa = r.MENSAGEM FROM #Regra r WHERE r.NIVEL = 'BLOQUEIO' ORDER BY r.ORDEM;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID,
                   CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #P;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF (EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@MotivoRetroativo) < 5)
           OR EXISTS (SELECT 1 FROM #Regra r WHERE r.NIVEL = 'AVISO'
                        AND NOT EXISTS (SELECT 1 FROM STRING_SPLIT(@AvisosConfirmados, N',') s WHERE LTRIM(RTRIM(s.value)) = r.CODIGO))
            SET @Pendente = 1;

        IF @SomenteConferir = 1 OR @Pendente = 1
        BEGIN
            SELECT CAST(CASE WHEN @SomenteConferir = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
                   CAST(CASE WHEN @Pendente = 0 THEN N'Nada a confirmar.'
                             WHEN EXISTS (SELECT 1 FROM #Regra WHERE NIVEL = 'MOTIVO') AND LEN(@MotivoRetroativo) < 5
                                  THEN N'Data fora da trava de datas: informe o motivo para gravar.'
                             ELSE N'Confira os avisos antes de gravar.' END AS NVARCHAR(400)) AS MENSAGEM,
                   @IdLancamento AS ID, @Pendente AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #P;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- 6) Gravação
        ---------------------------------------------------------------------
        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);
        SET @N = (SELECT COUNT(*) FROM #P);
        SELECT @IdTipoMarcar = t.ID_PARCEIRO_TIPO FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = CASE @Tipo WHEN 'P' THEN 'FORNECEDOR' ELSE 'CLIENTE' END;
        SELECT @IdTipoNA = t.ID_PARCEIRO_TIPO FROM CAD.Parceiro_Tipo t WHERE t.CODIGO = 'NA';

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- duplicidade de documento conferida de novo com trava (regra 22)
        IF FIN.fn_FIN_Regra_Nivel('FIN_REGRA_DUPLIC_DOCUMENTO') = 'BLOQUEIO' AND @IdPessoa IS NOT NULL AND @Documento LIKE N'%[0-9]%'
           AND (@MudouDocumento = 1 OR @MudouPessoa = 1)
           AND EXISTS (SELECT 1 FROM FIN.Lancamento l WITH (UPDLOCK, HOLDLOCK)
                       WHERE l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.DOCUMENTO = @Documento
                         AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL AND l.ID_LANCAMENTO <> ISNULL(@IdLancamento, 0))
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Este documento deste parceiro acabou de ser lançado por outra pessoa.' AS NVARCHAR(400)) AS MENSAGEM,
                   @IdLancamento AS ID, CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;
            DROP TABLE IF EXISTS #P;
            DROP TABLE IF EXISTS #Regra;
            RETURN;
        END;

        IF @Novo = 1
        BEGIN
            INSERT INTO FIN.Lancamento (TIPO, ID_EMPRESA, ID_CENTRO_CUSTO, ID_PESSOA, ID_PLANO_CONTA, ID_HISTORICO_PADRAO, DOCUMENTO,
                                        DT_EMISSAO, DT_COMPETENCIA, HISTORICO, OBSERVACAO, VALOR_TOTAL, ORIGEM, SITUACAO, PREVISAO,
                                        INTEGRACAO, USUARIO_CRIACAO)
            VALUES (@Tipo, @IdEmpresa, @IdCentroCusto, @IdPessoa, @IdPlanoConta, @IdHistoricoPadrao, ISNULL(@Documento, N''),
                    @DtEmissao, @DtCompetencia, ISNULL(@Historico, N''), ISNULL(@Observacao, N''), ISNULL(@ValorTotal, 0), 'MANUAL', 'ATIVO',
                    ISNULL(@Previsao, 0), ISNULL(@Integracao, 'COMPLETA'), ISNULL(@Usuario, N'sistema'));
            SET @IdLancamento = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE l
               SET l.ID_EMPRESA = @IdEmpresa, l.ID_CENTRO_CUSTO = @IdCentroCusto, l.ID_PESSOA = @IdPessoa, l.ID_PLANO_CONTA = @IdPlanoConta,
                   l.ID_HISTORICO_PADRAO = @IdHistoricoPadrao, l.DOCUMENTO = ISNULL(@Documento, N''), l.DT_EMISSAO = @DtEmissao,
                   l.DT_COMPETENCIA = @DtCompetencia, l.HISTORICO = ISNULL(@Historico, N''), l.OBSERVACAO = ISNULL(@Observacao, N''),
                   l.VALOR_TOTAL = ISNULL(@ValorTotal, 0), l.PREVISAO = ISNULL(@Previsao, 0), l.INTEGRACAO = ISNULL(@Integracao, 'COMPLETA'),
                   l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = @Usuario
            FROM FIN.Lancamento l
            WHERE l.ID_LANCAMENTO = @IdLancamento;

        -- parcelas: retira as que saíram (sem baixa), acerta as que ficaram, inclui as novas
        DELETE p
        FROM FIN.Parcela p
        WHERE p.ID_LANCAMENTO = @IdLancamento
          AND NOT EXISTS (SELECT 1 FROM #P x WHERE x.ID_PARCELA = p.ID_PARCELA)
          AND NOT EXISTS (SELECT 1 FROM FIN.Baixa b WHERE b.ID_PARCELA = p.ID_PARCELA);

        UPDATE p
           SET p.NUMERO = x.NUMERO, p.QTD_PARCELAS = @N, p.DT_VENCIMENTO = x.DT_VENCIMENTO, p.VALOR = x.VALOR,
               p.ID_CONTA_PREVISTA = x.ID_CONTA_PREVISTA,
               p.SITUACAO = CASE WHEN p.SITUACAO = 'CANCELADA' THEN p.SITUACAO
                                 WHEN p.VALOR_BAIXADO = 0 THEN 'ABERTA'
                                 WHEN p.VALOR_BAIXADO >= x.VALOR THEN 'PAGA' ELSE 'PARCIAL' END,
               p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = @Usuario
        FROM FIN.Parcela p
        INNER JOIN #P x ON x.ID_PARCELA = p.ID_PARCELA
        WHERE p.NUMERO <> x.NUMERO OR p.QTD_PARCELAS <> @N OR p.DT_VENCIMENTO <> x.DT_VENCIMENTO OR p.VALOR <> x.VALOR
           OR ISNULL(p.ID_CONTA_PREVISTA, 0) <> ISNULL(x.ID_CONTA_PREVISTA, 0);

        INSERT INTO FIN.Parcela (ID_LANCAMENTO, NUMERO, QTD_PARCELAS, DT_VENCIMENTO, VALOR, SITUACAO, ID_CONTA_PREVISTA, USUARIO_CRIACAO)
        SELECT @IdLancamento, ISNULL(x.NUMERO, 1), @N, x.DT_VENCIMENTO, ISNULL(x.VALOR, 0), 'ABERTA', x.ID_CONTA_PREVISTA, ISNULL(@Usuario, N'sistema')
        FROM #P x
        WHERE x.ID_PARCELA IS NULL;

        -- marcar o tipo Fornecedor / Cliente no parceiro (resposta ao aviso)
        IF @MarcarTipoParceiro = 1 AND @IdPessoa IS NOT NULL AND @IdTipoMarcar IS NOT NULL
           AND EXISTS (SELECT 1 FROM CAD.Pessoa p WHERE p.ID_PESSOA = @IdPessoa AND ((@Tipo = 'P' AND p.FORNECEDOR = 0) OR (@Tipo = 'R' AND p.CLIENTE = 0)))
        BEGIN
            UPDATE pt SET pt.ATIVO = 1, pt.DT_ALTERACAO = SYSDATETIME(), pt.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Tipo pt
            WHERE pt.ID_PESSOA = @IdPessoa AND pt.ID_PARCEIRO_TIPO = @IdTipoMarcar AND pt.ATIVO = 0;

            INSERT INTO CAD.Pessoa_Tipo (ID_PESSOA, ID_PARCEIRO_TIPO, ATIVO, USUARIO_CRIACAO)
            SELECT @IdPessoa, @IdTipoMarcar, 1, ISNULL(@Usuario, N'sistema')
            WHERE NOT EXISTS (SELECT 1 FROM CAD.Pessoa_Tipo pt WHERE pt.ID_PESSOA = @IdPessoa AND pt.ID_PARCEIRO_TIPO = @IdTipoMarcar);

            UPDATE pt SET pt.ATIVO = 0, pt.DT_ALTERACAO = SYSDATETIME(), pt.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa_Tipo pt
            WHERE pt.ID_PESSOA = @IdPessoa AND pt.ID_PARCEIRO_TIPO = @IdTipoNA AND pt.ATIVO = 1;

            UPDATE p
               SET p.FORNECEDOR = CASE WHEN @Tipo = 'P' THEN 1 ELSE p.FORNECEDOR END,
                   p.CLIENTE    = CASE WHEN @Tipo = 'R' THEN 1 ELSE p.CLIENTE END,
                   p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Pessoa p
            WHERE p.ID_PESSOA = @IdPessoa;

            INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_USUARIO, USUARIO_CRIACAO)
            VALUES (N'FIN.Lancamento', @IdLancamento, 'TIPO_PARCEIRO', 'AVISO',
                    N'Tipo ' + CASE @Tipo WHEN 'P' THEN N'Fornecedor' ELSE N'Cliente' END + N' marcado no parceiro.', N'', @IdUsuario, ISNULL(@Usuario, N'sistema'));
        END;

        -- avisos confirmados e motivo da trava de datas
        INSERT INTO SIS.Aviso_Confirmado (TABELA, ID_REGISTRO, CODIGO_REGRA, NIVEL, MENSAGEM, MOTIVO, ID_REFERENCIA, ID_USUARIO, USUARIO_CRIACAO)
        SELECT N'FIN.Lancamento', @IdLancamento, r.CODIGO, r.NIVEL, r.MENSAGEM,
               CASE WHEN r.NIVEL = 'MOTIVO' THEN ISNULL(@MotivoRetroativo, N'') ELSE N'' END, r.ID_REFERENCIA, @IdUsuario, ISNULL(@Usuario, N'sistema')
        FROM #Regra r
        WHERE r.NIVEL IN ('AVISO', 'MOTIVO');

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Lançamento gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID,
               CAST(0 AS BIT) AS PENDENTE, CAST(@Avisos AS NVARCHAR(MAX)) AS AVISOS;

        DROP TABLE IF EXISTS #P;
        DROP TABLE IF EXISTS #Regra;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        DROP TABLE IF EXISTS #P;
        DROP TABLE IF EXISTS #Regra;

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o lançamento. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamento AS ID, CAST(0 AS BIT) AS PENDENTE, CAST(N'[]' AS NVARCHAR(MAX)) AS AVISOS;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Conferir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Prévia, só leitura, das proteções contra erro de digitação
                (P17) de um lançamento antes de gravar: a tela mostra os
                bloqueios, os avisos a confirmar e o pedido de motivo (trava de
                datas). Usa a mesma conferência da gravação
                (FIN_Lancamento_Gravar com @SomenteConferir = 1), para as
                regras nunca ficarem diferentes. Não grava nada.
                Devolve 1 linha: SUCESSO (0 = há bloqueio ou dado inválido),
                MENSAGEM, ID, PENDENTE (há aviso ou motivo) e AVISOS (JSON).
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Conferir]
    @IdUsuario           INT,
    @IdLancamento        BIGINT          = NULL,
    @Tipo                CHAR(1)         = NULL,
    @IdCentroCusto       INT             = NULL,
    @IdPessoa            INT             = NULL,
    @IdPlanoConta        INT             = NULL,
    @IdHistoricoPadrao   INT             = NULL,
    @Documento           NVARCHAR(40)    = NULL,
    @DtEmissao           DATE            = NULL,
    @DtCompetencia       DATE            = NULL,
    @Historico           NVARCHAR(200)   = NULL,
    @Observacao          NVARCHAR(2000)  = NULL,
    @ValorTotal          DECIMAL(18,2)   = NULL,
    @Previsao            BIT             = 0,
    @Integracao          VARCHAR(12)     = NULL,
    @Parcelas            NVARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC FIN.FIN_Lancamento_Gravar
         @IdUsuario = @IdUsuario, @IdLancamento = @IdLancamento, @Tipo = @Tipo, @IdCentroCusto = @IdCentroCusto,
         @IdPessoa = @IdPessoa, @IdPlanoConta = @IdPlanoConta, @IdHistoricoPadrao = @IdHistoricoPadrao,
         @Documento = @Documento, @DtEmissao = @DtEmissao, @DtCompetencia = @DtCompetencia, @Historico = @Historico,
         @Observacao = @Observacao, @ValorTotal = @ValorTotal, @Previsao = @Previsao, @Integracao = @Integracao,
         @Parcelas = @Parcelas, @SomenteConferir = 1;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Lista das telas Contas a pagar (@Tipo P) e Contas a receber
                (@Tipo R) e da aba Movimentação do Parceiro (@Tipo NULL com
                @IdPessoa: os dois tipos que o usuário pode ver).
                @Visao PARCELA (padrão): uma linha por vencimento.
                @Visao LANCAMENTO: uma linha por lançamento (vencimento = o
                primeiro das parcelas filtradas; valores = todas as parcelas).
                @Situacao: EM_ABERTO (aberta + parcial), ABERTA, PARCIAL, PAGA,
                CANCELADA, VENCIDA (em aberto e vencida) ou vazio (todas).
                Filtros opcionais por período de vencimento, empresa, centro,
                parceiro, conta do plano, lote, documento, texto e valor.
                Paginação (@Pagina, @PorPagina; padrão FIN_LISTA_POR_PAGINA:
                a página é escolhida antes de buscar os detalhes) e
                totais do filtro inteiro em cada linha (TOTAL_*). Não lista o
                que está na lixeira. Permissão: VER em FIN_PAGAR / FIN_RECEBER.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'R', @Situacao = 'EM_ABERTO';
    -- EXEC FIN.FIN_Lancamento_Listar @IdUsuario = 2, @Tipo = 'P', @Visao = 'LANCAMENTO', @Texto = N'cimento';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Listar]
    @IdUsuario      INT,
    @Tipo           CHAR(1)        = NULL,
    @Visao          VARCHAR(12)    = 'PARCELA',
    @Situacao       VARCHAR(12)    = NULL,
    @VencDe         DATE           = NULL,
    @VencAte        DATE           = NULL,
    @IdEmpresa      INT            = NULL,
    @IdCentroCusto  INT            = NULL,
    @IdPessoa       INT            = NULL,
    @IdPlanoConta   INT            = NULL,
    @IdLote         BIGINT         = NULL,
    @IdLancamento   BIGINT         = NULL,
    @Documento      NVARCHAR(40)   = NULL,
    @Texto          NVARCHAR(100)  = NULL,
    @ValorDe        DECIMAL(18,2)  = NULL,
    @ValorAte       DECIMAL(18,2)  = NULL,
    @Ordem          VARCHAR(12)    = 'VENCIMENTO',
    @Pagina         INT            = 1,
    @PorPagina      INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @VeP        BIT;
    DECLARE @VeR        BIT;
    DECLARE @Hoje       DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Termo      NVARCHAR(102);
    DECLARE @Digitos    VARCHAR(100);
    DECLARE @Linhas     INT = 0;
    DECLARE @TotValor   DECIMAL(18,2) = 0;
    DECLARE @TotBaixado DECIMAL(18,2) = 0;
    DECLARE @TotSaldo   DECIMAL(18,2) = 0;

    DROP TABLE IF EXISTS #F;
    DROP TABLE IF EXISTS #G;
    DROP TABLE IF EXISTS #T;
    DROP TABLE IF EXISTS #Pg;

    BEGIN TRY
        SET @Tipo = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Tipo, '')))), '');
        SET @VeP  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VeR  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        IF (@Tipo = 'P' AND @VeP = 0) OR (@Tipo = 'R' AND @VeR = 0) OR (@Tipo IS NULL AND @VeP = 0 AND @VeR = 0)
            THROW 50001, N'Você não tem permissão para ver estes lançamentos.', 1;
        IF @Tipo IS NOT NULL AND @Tipo NOT IN ('P', 'R')
            THROW 50001, N'Tipo inválido.', 1;

        SET @Visao     = CASE WHEN UPPER(ISNULL(@Visao, '')) = 'LANCAMENTO' THEN 'LANCAMENTO' ELSE 'PARCELA' END;
        SET @Situacao  = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Situacao, '')))), '');
        SET @Ordem     = UPPER(ISNULL(@Ordem, 'VENCIMENTO'));
        SET @Pagina    = CASE WHEN ISNULL(@Pagina, 1) < 1 THEN 1 ELSE @Pagina END;
        SET @PorPagina = ISNULL(@PorPagina, ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_POR_PAGINA'), 100));
        IF @PorPagina NOT BETWEEN 10 AND 1000 SET @PorPagina = 100;
        SET @Documento = NULLIF(LTRIM(RTRIM(ISNULL(@Documento, N''))), N'');
        SET @Texto     = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @Termo     = N'%' + REPLACE(REPLACE(REPLACE(ISNULL(@Texto, N''), N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Digitos   = NULLIF(CONVERT(VARCHAR(100), CAD.fn_CAD_Somente_Digitos(ISNULL(@Texto, N''))), '');

        SET @EtapaAtual = 'Filtro';
        SELECT p.ID_PARCELA, p.ID_LANCAMENTO, p.NUMERO, p.DT_VENCIMENTO, p.VALOR, p.VALOR_BAIXADO, p.SALDO, l.DT_EMISSAO,
               ISNULL(pe.NOME, N'') AS PESSOA_NOME
        INTO #F
        FROM FIN.Parcela p WITH (NOLOCK)
        INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
        LEFT  JOIN CAD.Pessoa pe    WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        WHERE l.DT_EXCLUSAO IS NULL
          AND ((l.TIPO = 'P' AND @VeP = 1) OR (l.TIPO = 'R' AND @VeR = 1))
          AND (@Tipo IS NULL OR l.TIPO = @Tipo)
          AND (@Situacao IS NULL
               OR (@Situacao = 'EM_ABERTO' AND p.SITUACAO IN ('ABERTA', 'PARCIAL'))
               OR (@Situacao = 'VENCIDA'   AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje)
               OR p.SITUACAO = @Situacao)
          AND (@VencDe        IS NULL OR p.DT_VENCIMENTO >= @VencDe)
          AND (@VencAte       IS NULL OR p.DT_VENCIMENTO <= @VencAte)
          AND (@IdEmpresa     IS NULL OR l.ID_EMPRESA = @IdEmpresa)
          AND (@IdCentroCusto IS NULL OR l.ID_CENTRO_CUSTO = @IdCentroCusto)
          AND (@IdPessoa      IS NULL OR l.ID_PESSOA = @IdPessoa)
          AND (@IdPlanoConta  IS NULL OR l.ID_PLANO_CONTA = @IdPlanoConta)
          AND (@IdLote        IS NULL OR l.ID_LOTE = @IdLote OR p.ID_LOTE = @IdLote)
          AND (@IdLancamento  IS NULL OR l.ID_LANCAMENTO = @IdLancamento)
          AND (@Documento     IS NULL OR l.DOCUMENTO LIKE @Documento + N'%')
          AND (@ValorDe       IS NULL OR p.VALOR >= @ValorDe)
          AND (@ValorAte      IS NULL OR p.VALOR <= @ValorAte)
          AND (@Texto IS NULL
               OR l.HISTORICO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR l.DOCUMENTO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR l.OBSERVACAO COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME      COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME_FANTASIA COLLATE Latin1_General_CI_AI LIKE @Termo
               OR (@Digitos IS NOT NULL AND LEN(@Digitos) >= 5 AND pe.CPF_CNPJ LIKE @Digitos + '%')
               OR CONVERT(NVARCHAR(20), l.ID_LANCAMENTO) = @Texto)
        OPTION (RECOMPILE);

        -- linhas da página primeiro (só com o que já está em #F); detalhes depois, só para elas
        SET @EtapaAtual = 'Página';
        CREATE TABLE #Pg (ORDEM INT NOT NULL, ID_LANCAMENTO BIGINT NOT NULL, ID_PARCELA BIGINT NULL, DT_VENCIMENTO DATE NULL,
                          QTD INT NULL, VALOR DECIMAL(18,2) NULL, BAIXADO DECIMAL(18,2) NULL, SALDO DECIMAL(18,2) NULL,
                          EM_ABERTO INT NULL, CANCELADAS INT NULL, PRIMEIRA_VENCIDA DATE NULL);

        IF @Visao = 'PARCELA'
        BEGIN
            SELECT @Linhas = COUNT(*), @TotValor = ISNULL(SUM(f.VALOR), 0), @TotBaixado = ISNULL(SUM(f.VALOR_BAIXADO), 0), @TotSaldo = ISNULL(SUM(f.SALDO), 0) FROM #F f;

            INSERT INTO #Pg (ORDEM, ID_LANCAMENTO, ID_PARCELA, DT_VENCIMENTO)
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)), x.ID_LANCAMENTO, x.ID_PARCELA, x.DT_VENCIMENTO
            FROM (SELECT f.ID_LANCAMENTO, f.ID_PARCELA, f.DT_VENCIMENTO, f.VALOR, f.PESSOA_NOME, f.DT_EMISSAO, f.NUMERO
                  FROM #F f
                  ORDER BY CASE WHEN @Ordem = 'VALOR'    THEN f.VALOR END DESC,
                           CASE WHEN @Ordem = 'PARCEIRO' THEN f.PESSOA_NOME END,
                           CASE WHEN @Ordem = 'EMISSAO'  THEN f.DT_EMISSAO END DESC,
                           f.DT_VENCIMENTO, f.ID_LANCAMENTO, f.NUMERO
                  OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY) x;
        END
        ELSE
        BEGIN
            SELECT g.ID_LANCAMENTO, MIN(g.DT_VENCIMENTO) AS DT_VENCIMENTO, MAX(g.PESSOA_NOME) AS PESSOA_NOME, MAX(g.DT_EMISSAO) AS DT_EMISSAO
            INTO #G
            FROM #F g
            GROUP BY g.ID_LANCAMENTO;

            SELECT p.ID_LANCAMENTO, COUNT(*) AS QTD, SUM(p.VALOR) AS VALOR, SUM(p.VALOR_BAIXADO) AS BAIXADO, SUM(p.SALDO) AS SALDO,
                   SUM(CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') THEN 1 ELSE 0 END) AS EM_ABERTO,
                   SUM(CASE WHEN p.SITUACAO = 'CANCELADA' THEN 1 ELSE 0 END) AS CANCELADAS,
                   MIN(CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN p.DT_VENCIMENTO END) AS PRIMEIRA_VENCIDA
            INTO #T
            FROM FIN.Parcela p WITH (NOLOCK)
            INNER JOIN #G g ON g.ID_LANCAMENTO = p.ID_LANCAMENTO
            GROUP BY p.ID_LANCAMENTO;

            SELECT @Linhas = COUNT(*), @TotValor = ISNULL(SUM(t.VALOR), 0), @TotBaixado = ISNULL(SUM(t.BAIXADO), 0), @TotSaldo = ISNULL(SUM(t.SALDO), 0) FROM #T t;

            INSERT INTO #Pg (ORDEM, ID_LANCAMENTO, DT_VENCIMENTO, QTD, VALOR, BAIXADO, SALDO, EM_ABERTO, CANCELADAS, PRIMEIRA_VENCIDA)
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)), x.ID_LANCAMENTO, x.DT_VENCIMENTO, x.QTD, x.VALOR, x.BAIXADO, x.SALDO, x.EM_ABERTO, x.CANCELADAS, x.PRIMEIRA_VENCIDA
            FROM (SELECT g.ID_LANCAMENTO, g.DT_VENCIMENTO, t.QTD, t.VALOR, t.BAIXADO, t.SALDO, t.EM_ABERTO, t.CANCELADAS, t.PRIMEIRA_VENCIDA
                  FROM #G g
                  INNER JOIN #T t ON t.ID_LANCAMENTO = g.ID_LANCAMENTO
                  ORDER BY CASE WHEN @Ordem = 'VALOR'    THEN t.VALOR END DESC,
                           CASE WHEN @Ordem = 'PARCEIRO' THEN g.PESSOA_NOME END,
                           CASE WHEN @Ordem = 'EMISSAO'  THEN g.DT_EMISSAO END DESC,
                           g.DT_VENCIMENTO, g.ID_LANCAMENTO
                  OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY) x;
        END;

        SET @EtapaAtual = 'Consulta';
        SELECT l.ID_LANCAMENTO, pg.ID_PARCELA, l.TIPO,
               CAST(p.NUMERO AS SMALLINT) AS NUMERO,
               CAST(ISNULL(p.QTD_PARCELAS, pg.QTD) AS SMALLINT) AS QTD_PARCELAS,
               pg.DT_VENCIMENTO,
               CAST(ISNULL(p.VALOR, pg.VALOR) AS DECIMAL(18,2)) AS VALOR,
               CAST(ISNULL(p.VALOR_BAIXADO, pg.BAIXADO) AS DECIMAL(18,2)) AS VALOR_BAIXADO,
               CAST(ISNULL(p.SALDO, pg.SALDO) AS DECIMAL(18,2)) AS SALDO,
               CAST(CASE WHEN p.ID_PARCELA IS NOT NULL THEN p.SITUACAO
                         WHEN pg.CANCELADAS = pg.QTD THEN 'CANCELADA'
                         WHEN pg.EM_ABERTO = 0 THEN 'PAGA'
                         WHEN pg.BAIXADO > 0 THEN 'PARCIAL'
                         ELSE 'ABERTA' END AS VARCHAR(10)) AS SITUACAO,
               CAST(CASE WHEN p.ID_PARCELA IS NOT NULL AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN 1
                         WHEN p.ID_PARCELA IS NULL AND pg.PRIMEIRA_VENCIDA IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
               CASE WHEN p.ID_PARCELA IS NOT NULL AND p.SITUACAO IN ('ABERTA', 'PARCIAL') AND p.DT_VENCIMENTO < @Hoje THEN DATEDIFF(DAY, p.DT_VENCIMENTO, @Hoje)
                    WHEN p.ID_PARCELA IS NULL AND pg.PRIMEIRA_VENCIDA IS NOT NULL THEN DATEDIFF(DAY, pg.PRIMEIRA_VENCIDA, @Hoje) ELSE 0 END AS DIAS_ATRASO,
               l.DT_EMISSAO, l.DT_COMPETENCIA, l.DOCUMENTO, l.HISTORICO,
               l.ID_PESSOA, ISNULL(pe.NOME, N'') AS PESSOA_NOME,
               l.ID_EMPRESA, ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) AS EMPRESA_NOME,
               l.ID_CENTRO_CUSTO, ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'') AS CENTRO_CODIGO, ISNULL(cc.DESCRICAO, N'') AS CENTRO_DESCRICAO,
               l.ID_PLANO_CONTA, ISNULL(CONVERT(NVARCHAR(12), v.CODIGO), N'') AS PLANO_CODIGO, ISNULL(v.DESCRICAO, N'') AS PLANO_DESCRICAO,
               ISNULL(p.ID_LOTE, l.ID_LOTE) AS ID_LOTE, l.ORIGEM, l.PREVISAO, l.SITUACAO AS LANCAMENTO_SITUACAO,
               @Linhas AS TOTAL_LINHAS, @TotValor AS TOTAL_VALOR, @TotBaixado AS TOTAL_BAIXADO, @TotSaldo AS TOTAL_SALDO
        FROM #Pg pg
        INNER JOIN FIN.Lancamento l         WITH (NOLOCK) ON l.ID_LANCAMENTO = pg.ID_LANCAMENTO
        INNER JOIN CAD.Empresa e            WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
        LEFT  JOIN FIN.Parcela p            WITH (NOLOCK) ON p.ID_PARCELA = pg.ID_PARCELA
        LEFT  JOIN CAD.Pessoa pe            WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        LEFT  JOIN CAD.Centro_Custo cc      WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO
        LEFT  JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = l.ID_PLANO_CONTA
        ORDER BY pg.ORDEM;

        DROP TABLE IF EXISTS #F;
        DROP TABLE IF EXISTS #G;
        DROP TABLE IF EXISTS #T;
        DROP TABLE IF EXISTS #Pg;
    END TRY
    BEGIN CATCH
        DROP TABLE IF EXISTS #F;
        DROP TABLE IF EXISTS #G;
        DROP TABLE IF EXISTS #T;
        DROP TABLE IF EXISTS #Pg;
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os lançamentos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha do lançamento (Contas a pagar / a receber): dados do
                documento com os nomes do que foi escolhido, as parcelas
                (PARCELAS, JSON, com QTD_BAIXAS e TRAVADA), as baixas (BAIXAS,
                JSON, só consulta até a etapa 04g) e os avisos já confirmados
                (AVISOS_CONFIRMADOS, JSON). Situação para a tela: TEM_BAIXA,
                NA_LIXEIRA, MES_FECHADO, PODE_ALTERAR (permissão + situação +
                origem), PODE_CANCELAR e PODE_EXCLUIR.
                Permissão: VER em FIN_PAGAR / FIN_RECEBER (conforme o tipo).
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Obter @IdUsuario = 2, @IdLancamento = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Obter]
    @IdUsuario     INT,
    @IdLancamento  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Tipo       CHAR(1);
    DECLARE @Item       VARCHAR(40);
    DECLARE @TemBaixa   BIT = 0;
    DECLARE @NaLixeira  BIT = 0;
    DECLARE @MesFechado BIT = 0;
    DECLARE @Editavel   BIT = 0;

    BEGIN TRY
        SELECT @Tipo = l.TIPO FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_LANCAMENTO = @IdLancamento;
        IF @Tipo IS NULL
            THROW 50001, N'Lançamento não encontrado.', 1;

        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver este lançamento.', 1;

        SET @EtapaAtual = 'Situação';
        IF EXISTS (SELECT 1 FROM FIN.Baixa b WITH (NOLOCK) INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
                   WHERE p.ID_LANCAMENTO = @IdLancamento)
            SET @TemBaixa = 1;
        SET @NaLixeira = SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento);
        IF EXISTS (SELECT 1 FROM FIN.Lancamento l WITH (NOLOCK)
                   INNER JOIN FIN.Mes_Fechado m  WITH (NOLOCK) ON m.ID_EMPRESA = l.ID_EMPRESA AND m.MES = l.DT_COMPETENCIA AND m.FECHADO = 1
                   INNER JOIN CAD.Plano_Conta pc WITH (NOLOCK) ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.CONTABIL = 1
                   WHERE l.ID_LANCAMENTO = @IdLancamento)
            SET @MesFechado = 1;
        SELECT @Editavel = CASE WHEN l.SITUACAO = 'ATIVO' AND l.ORIGEM IN ('MANUAL', 'MIGRACAO') AND @NaLixeira = 0 AND @MesFechado = 0 THEN 1 ELSE 0 END
        FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_LANCAMENTO = @IdLancamento;

        SET @EtapaAtual = 'Consulta';
        SELECT l.ID_LANCAMENTO, l.TIPO, l.ID_EMPRESA, ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL) AS EMPRESA_NOME,
               l.ID_CENTRO_CUSTO, ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'') AS CENTRO_CODIGO, ISNULL(cc.DESCRICAO, N'') AS CENTRO_DESCRICAO,
               l.ID_PESSOA, ISNULL(pe.NOME, N'') AS PESSOA_NOME, ISNULL(pe.CPF_CNPJ, '') AS PESSOA_CPF_CNPJ,
               l.ID_PLANO_CONTA, ISNULL(CONVERT(NVARCHAR(12), v.CODIGO), N'') AS PLANO_CODIGO, ISNULL(v.DESCRICAO, N'') AS PLANO_DESCRICAO,
               ISNULL(CONVERT(VARCHAR(15), v.TIPO), '') AS PLANO_TIPO,
               l.ID_HISTORICO_PADRAO, ISNULL(h.DESCRICAO, N'') AS HISTORICO_PADRAO_DESCRICAO,
               l.DOCUMENTO, l.DT_EMISSAO, l.DT_COMPETENCIA, l.HISTORICO, l.OBSERVACAO, l.VALOR_TOTAL,
               l.ORIGEM, l.ID_ORIGEM, l.ID_LOTE, l.SITUACAO, l.PREVISAO, l.INTEGRACAO,
               l.DT_CANCELAMENTO, ISNULL(l.USUARIO_CANCELAMENTO, N'') AS USUARIO_CANCELAMENTO, l.MOTIVO_CANCELAMENTO,
               l.CODIGO_ACCESS, l.DT_CRIACAO, l.USUARIO_CRIACAO, l.DT_ALTERACAO, ISNULL(l.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO,
               @TemBaixa AS TEM_BAIXA, @NaLixeira AS NA_LIXEIRA, @MesFechado AS MES_FECHADO,
               CAST(CASE WHEN @Editavel = 1 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_ALTERAR,
               CAST(CASE WHEN @Editavel = 1 AND @TemBaixa = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'CANCELAR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_CANCELAR,
               CAST(CASE WHEN @Editavel = 1 AND @TemBaixa = 0 AND l.ORIGEM = 'MANUAL' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'EXCLUIR') = 1 THEN 1 ELSE 0 END AS BIT) AS PODE_EXCLUIR,
               ISNULL((SELECT p.ID_PARCELA AS id, p.NUMERO AS numero, p.QTD_PARCELAS AS qtdParcelas, p.DT_VENCIMENTO AS vencimento,
                              p.VALOR AS valor, p.VALOR_BAIXADO AS valorBaixado, p.SALDO AS saldo, p.SITUACAO AS situacao,
                              p.ID_CONTA_PREVISTA AS idContaPrevista, ISNULL(c.DESCRICAO, N'') AS contaPrevista, p.ID_LOTE AS idLote,
                              (SELECT COUNT(*) FROM FIN.Baixa b WITH (NOLOCK) WHERE b.ID_PARCELA = p.ID_PARCELA) AS qtdBaixas,
                              CAST(CASE WHEN EXISTS (SELECT 1 FROM FIN.Baixa b WITH (NOLOCK) WHERE b.ID_PARCELA = p.ID_PARCELA) THEN 1 ELSE 0 END AS BIT) AS travada
                       FROM FIN.Parcela p WITH (NOLOCK)
                       LEFT JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = p.ID_CONTA_PREVISTA
                       WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO
                       ORDER BY p.NUMERO
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS PARCELAS,
               ISNULL((SELECT b.ID_BAIXA AS id, p.NUMERO AS parcela, b.DT_PAGAMENTO AS data, b.ID_CONTA AS idConta, c.DESCRICAO AS conta,
                              b.FORMA AS forma, b.VALOR_PRINCIPAL AS principal, b.JUROS AS juros, b.MULTA AS multa, b.CORRECAO AS correcao,
                              b.DESCONTO AS desconto, b.ABATIMENTO AS abatimento, b.TARIFA AS tarifa, b.RETENCAO AS retencao,
                              b.VALOR_LIQUIDO AS liquido, b.COMPENSADO AS compensado, b.DT_COMPENSACAO AS dataCompensacao,
                              b.ID_BAIXA_ESTORNADA AS idBaixaEstornada,
                              CAST(CASE WHEN EXISTS (SELECT 1 FROM FIN.Baixa x WITH (NOLOCK) WHERE x.ID_BAIXA_ESTORNADA = b.ID_BAIXA) THEN 1 ELSE 0 END AS BIT) AS estornada,
                              b.OBSERVACAO AS observacao, b.USUARIO_CRIACAO AS usuario
                       FROM FIN.Baixa b WITH (NOLOCK)
                       INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
                       INNER JOIN BANCO.Conta c WITH (NOLOCK) ON c.ID_CONTA = b.ID_CONTA
                       WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO
                       ORDER BY b.DT_PAGAMENTO, b.ID_BAIXA
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS BAIXAS,
               ISNULL((SELECT a.CODIGO_REGRA AS codigo, a.NIVEL AS nivel, a.MENSAGEM AS mensagem, a.MOTIVO AS motivo,
                              a.ID_REFERENCIA AS idReferencia, a.USUARIO_CRIACAO AS usuario, a.DT_CRIACAO AS data
                       FROM SIS.Aviso_Confirmado a WITH (NOLOCK)
                       WHERE a.TABELA = N'FIN.Lancamento' AND a.ID_REGISTRO = l.ID_LANCAMENTO
                       ORDER BY a.DT_CRIACAO DESC, a.ID_AVISO_CONFIRMADO DESC
                       FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS AVISOS_CONFIRMADOS
        FROM FIN.Lancamento l WITH (NOLOCK)
        INNER JOIN CAD.Empresa e            WITH (NOLOCK) ON e.ID_EMPRESA = l.ID_EMPRESA
        LEFT  JOIN CAD.Centro_Custo cc      WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO
        LEFT  JOIN CAD.Pessoa pe            WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        LEFT  JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = l.ID_PLANO_CONTA
        LEFT  JOIN FIN.Historico_Padrao h   WITH (NOLOCK) ON h.ID_HISTORICO_PADRAO = l.ID_HISTORICO_PADRAO
        WHERE l.ID_LANCAMENTO = @IdLancamento;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o lançamento. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Cancelar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Cancelar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Cancela um lançamento (botão Cancelar da ficha): o lançamento
                fica CANCELADO, com data, usuário e motivo, e as parcelas em
                aberto ficam CANCELADA. Continua na lista (filtro Canceladas) e
                no histórico; volta pelo desfazer da aba Histórico. Só sem
                baixa, fora de mês fechado (conta contábil) e de origem manual
                ou migração. Motivo obrigatório. Tudo-ou-nada.
                Permissão: CANCELAR em FIN_PAGAR / FIN_RECEBER.
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Cancelar @IdUsuario = 2, @IdLancamento = 1, @Motivo = N'Lançado em dobro';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Cancelar]
    @IdUsuario     INT,
    @IdLancamento  BIGINT,
    @Motivo        NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Cancelar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Tipo       CHAR(1);
    DECLARE @Situacao   VARCHAR(10);
    DECLARE @Origem     VARCHAR(15);
    DECLARE @Linhas     INT;

    BEGIN TRY
        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));

        SELECT @Tipo = l.TIPO, @Situacao = l.SITUACAO, @Origem = l.ORIGEM
        FROM FIN.Lancamento l WHERE l.ID_LANCAMENTO = @IdLancamento;

        IF @Tipo IS NULL
            SET @Recusa = N'Lançamento não encontrado.';
        IF @Recusa = N'' AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' ELSE 'FIN_RECEBER' END, 'CANCELAR') = 0
            SET @Recusa = N'Você não tem permissão para cancelar lançamentos.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'FIN.Lancamento', @IdLancamento) = 1
            SET @Recusa = N'O lançamento está na lixeira.';
        IF @Recusa = N'' AND @Situacao = 'CANCELADO'
            SET @Recusa = N'O lançamento já está cancelado.';
        IF @Recusa = N'' AND @Origem NOT IN ('MANUAL', 'MIGRACAO')
            SET @Recusa = N'Este lançamento foi gerado por outra rotina (' + CONVERT(NVARCHAR(15), @Origem) + N'): cancele pela tela de origem.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Baixa b INNER JOIN FIN.Parcela p ON p.ID_PARCELA = b.ID_PARCELA WHERE p.ID_LANCAMENTO = @IdLancamento)
            SET @Recusa = N'O lançamento tem pagamento ou recebimento: estorne as baixas antes de cancelar.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Lancamento l
                                     INNER JOIN FIN.Mes_Fechado m  ON m.ID_EMPRESA = l.ID_EMPRESA AND m.MES = l.DT_COMPETENCIA AND m.FECHADO = 1
                                     INNER JOIN CAD.Plano_Conta pc ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.CONTABIL = 1
                                     WHERE l.ID_LANCAMENTO = @IdLancamento)
            SET @Recusa = N'O mês do lançamento está fechado (conta contábil).';
        IF @Recusa = N'' AND LEN(@Motivo) < 5
            SET @Recusa = N'Informe o motivo do cancelamento.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        UPDATE l
           SET l.SITUACAO = 'CANCELADO', l.DT_CANCELAMENTO = SYSDATETIME(), l.USUARIO_CANCELAMENTO = @Usuario,
               l.MOTIVO_CANCELAMENTO = @Motivo, l.DT_ALTERACAO = SYSDATETIME(), l.USUARIO_ALTERACAO = @Usuario
        FROM FIN.Lancamento l
        WHERE l.ID_LANCAMENTO = @IdLancamento AND l.SITUACAO = 'ATIVO';
        SET @Linhas = @@ROWCOUNT;

        UPDATE p
           SET p.SITUACAO = 'CANCELADA', p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = @Usuario
        FROM FIN.Parcela p
        WHERE p.ID_LANCAMENTO = @IdLancamento AND p.SITUACAO = 'ABERTA';

        COMMIT TRANSACTION;

        SELECT CAST(CASE WHEN @Linhas = 1 THEN 1 ELSE 0 END AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Linhas = 1 THEN N'Lançamento cancelado.' ELSE N'O lançamento foi alterado por outra pessoa. Abra a ficha de novo.' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdLancamento AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível cancelar o lançamento. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdLancamento AS ID;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Lancamento_Padroes_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Lancamento_Padroes_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Sugestão de conta do plano e centro de custo ao escolher o
                parceiro na ficha do lançamento (P17): primeiro a conta/centro
                padrão do cadastro do parceiro (04e); sem padrão, os do último
                lançamento ativo do mesmo tipo deste parceiro. Só sugere o que
                está ativo. Informa também se o parceiro tem o tipo esperado
                (Fornecedor no a pagar, Cliente no a receber).
                ORIGEM_PLANO / ORIGEM_CENTRO: PARCEIRO, ULTIMO ou vazio.
                Permissão: INCLUIR ou ALTERAR em FIN_PAGAR / FIN_RECEBER.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Lancamento_Padroes_Obter @IdUsuario = 2, @IdPessoa = 1, @Tipo = 'P';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Lancamento_Padroes_Obter]
    @IdUsuario  INT,
    @IdPessoa   INT,
    @Tipo       CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Lancamento_Padroes_Obter]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Permissão';
    DECLARE @Item         VARCHAR(40);
    DECLARE @Plano        INT;
    DECLARE @Centro       INT;
    DECLARE @OrigemPlano  VARCHAR(10) = '';
    DECLARE @OrigemCentro VARCHAR(10) = '';

    BEGIN TRY
        SET @Tipo = UPPER(ISNULL(@Tipo, ''));
        SET @Item = CASE @Tipo WHEN 'P' THEN 'FIN_PAGAR' WHEN 'R' THEN 'FIN_RECEBER' ELSE '' END;
        IF @Item = ''
            THROW 50001, N'Tipo inválido.', 1;
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'INCLUIR') = 0 AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'ALTERAR') = 0
            THROW 50001, N'Você não tem permissão para lançar.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Pessoa p WITH (NOLOCK) WHERE p.ID_PESSOA = @IdPessoa)
            THROW 50001, N'Parceiro não encontrado.', 1;

        SET @EtapaAtual = 'Padrão do parceiro';
        SELECT @Plano  = CASE WHEN v.ATIVO_EFETIVO = 1 AND pc.DT_EXCLUSAO IS NULL THEN p.ID_PLANO_CONTA_PADRAO END,
               @Centro = CASE WHEN cc.ATIVO = 1 AND cc.DT_EXCLUSAO IS NULL THEN p.ID_CENTRO_CUSTO_PADRAO END
        FROM CAD.Pessoa p WITH (NOLOCK)
        LEFT JOIN CAD.vw_CAD_Plano_Conta v  ON v.ID_PLANO_CONTA = p.ID_PLANO_CONTA_PADRAO
        LEFT JOIN CAD.Plano_Conta pc        WITH (NOLOCK) ON pc.ID_PLANO_CONTA = p.ID_PLANO_CONTA_PADRAO
        LEFT JOIN CAD.Centro_Custo cc       WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = p.ID_CENTRO_CUSTO_PADRAO
        WHERE p.ID_PESSOA = @IdPessoa;

        IF @Plano  IS NOT NULL SET @OrigemPlano  = 'PARCEIRO';
        IF @Centro IS NOT NULL SET @OrigemCentro = 'PARCEIRO';

        SET @EtapaAtual = 'Último lançamento';
        IF @Plano IS NULL
        BEGIN
            SELECT TOP 1 @Plano = l.ID_PLANO_CONTA
            FROM FIN.Lancamento l WITH (NOLOCK)
            INNER JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND v.ATIVO_EFETIVO = 1
            INNER JOIN CAD.Plano_Conta pc WITH (NOLOCK) ON pc.ID_PLANO_CONTA = l.ID_PLANO_CONTA AND pc.DT_EXCLUSAO IS NULL
            WHERE l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL
            ORDER BY l.DT_EMISSAO DESC, l.ID_LANCAMENTO DESC;
            IF @Plano IS NOT NULL SET @OrigemPlano = 'ULTIMO';
        END;

        IF @Centro IS NULL
        BEGIN
            SELECT TOP 1 @Centro = l.ID_CENTRO_CUSTO
            FROM FIN.Lancamento l WITH (NOLOCK)
            INNER JOIN CAD.Centro_Custo cc WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO AND cc.ATIVO = 1 AND cc.DT_EXCLUSAO IS NULL
                                                         AND (cc.DT_ENCERRAMENTO IS NULL OR cc.DT_ENCERRAMENTO > CONVERT(DATE, SYSDATETIME()))
            WHERE l.ID_PESSOA = @IdPessoa AND l.TIPO = @Tipo AND l.SITUACAO = 'ATIVO' AND l.DT_EXCLUSAO IS NULL
            ORDER BY l.DT_EMISSAO DESC, l.ID_LANCAMENTO DESC;
            IF @Centro IS NOT NULL SET @OrigemCentro = 'ULTIMO';
        END;

        SET @EtapaAtual = 'Consulta';
        SELECT @Plano AS ID_PLANO_CONTA, ISNULL(CONVERT(NVARCHAR(12), v.CODIGO), N'') AS PLANO_CODIGO, ISNULL(v.DESCRICAO, N'') AS PLANO_DESCRICAO,
               @OrigemPlano AS ORIGEM_PLANO,
               @Centro AS ID_CENTRO_CUSTO, ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'') AS CENTRO_CODIGO, ISNULL(cc.DESCRICAO, N'') AS CENTRO_DESCRICAO,
               @OrigemCentro AS ORIGEM_CENTRO,
               CAST(CASE WHEN (@Tipo = 'P' AND p.FORNECEDOR = 1) OR (@Tipo = 'R' AND p.CLIENTE = 1) THEN 1 ELSE 0 END AS BIT) AS TIPO_OK,
               p.ATIVO AS PARCEIRO_ATIVO
        FROM CAD.Pessoa p WITH (NOLOCK)
        LEFT JOIN CAD.vw_CAD_Plano_Conta v ON v.ID_PLANO_CONTA = @Plano
        LEFT JOIN CAD.Centro_Custo cc      WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = @Centro
        WHERE p.ID_PESSOA = @IdPessoa;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as sugestões. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.rl_sistemacmj_api.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : papel [rl_sistemacmj_api]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Papel do banco usado pelo login da API e do serviço do
                sistema (CLAUDE.md seção 2): só EXECUTA procedures e
                functions dos schemas do sistema; não lê nem grava tabela
                direto (as procedures fazem isso por encadeamento de dono).
                Proteções a mais:
                  - DENY de INSERT/UPDATE/DELETE em SIS.Auditoria (além da
                    trigger de proteção);
                  - DENY de EXECUTE no gerador de triggers (só instalação);
                  - DENY de EXECUTE no registro de atualização (só o atualizar.cmd);
                  - DENY de EXECUTE nas procedures internas da lixeira e do
                    desfazer (só chamadas por dentro, pelas procedures das
                    telas, com EXECUTE AS OWNER).
                O login e o usuário do banco (ex.: sistemacmj_api) são
                criados na instalação do servidor (instalador / MASTER), que
                também coloca o usuário neste papel: a senha nunca fica em
                arquivo do projeto.
                Idempotente: pode rodar de novo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (22/11/2026) - DENY em SIS_Atualizacao_Registrar (etapa 03h).
    v1.2 (22/11/2026) - Etapa 04b (P20): DENY nas procedures internas da
                        lixeira e do desfazer.
    v1.3 (25/11/2026) - Etapa 04f: DENY na trava própria do lançamento
                        (FIN_Lancamento_Trava_Conferir).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF DATABASE_PRINCIPAL_ID(N'rl_sistemacmj_api') IS NULL
    CREATE ROLE [rl_sistemacmj_api] AUTHORIZATION [dbo];
GO

DECLARE @Sql NVARCHAR(MAX) = N'';

SELECT @Sql = @Sql + N'GRANT EXECUTE ON SCHEMA::' + QUOTENAME(s.name) + N' TO [rl_sistemacmj_api];' + NCHAR(13) + NCHAR(10)
FROM sys.schemas s
WHERE s.name IN (N'SIS', N'CAD', N'BANCO', N'IMOB', N'VENDA', N'FIN', N'COBR', N'OBRA', N'GER', N'COMP');

EXEC sys.sp_executesql @Sql;
GO

DENY INSERT, UPDATE, DELETE ON [SIS].[Auditoria] TO [rl_sistemacmj_api];
DENY EXECUTE ON [SIS].[SIS_Auditoria_Trigger_Gerar] TO [rl_sistemacmj_api];
IF OBJECT_ID(N'[SIS].[SIS_Atualizacao_Registrar]', N'P') IS NOT NULL
    DENY EXECUTE ON [SIS].[SIS_Atualizacao_Registrar] TO [rl_sistemacmj_api];
GO

DECLARE @Internas NVARCHAR(MAX) = N'';
SELECT @Internas = @Internas + N'DENY EXECUTE ON ' + QUOTENAME(OBJECT_SCHEMA_NAME(o.object_id)) + N'.' + QUOTENAME(o.name) + N' TO [rl_sistemacmj_api];' + NCHAR(13) + NCHAR(10)
FROM sys.objects o
WHERE o.type = 'P'
  AND o.object_id IN (OBJECT_ID(N'[SIS].[SIS_Lixeira_Marcar]'), OBJECT_ID(N'[SIS].[SIS_Lixeira_Apagar]'), OBJECT_ID(N'[SIS].[SIS_Lixeira_Referencias]'),
                      OBJECT_ID(N'[SIS].[SIS_Tabela_Trava_Conferir]'), OBJECT_ID(N'[SIS].[SIS_Historico_Desfazer_Montar]'),
                      OBJECT_ID(N'[FIN].[FIN_Lancamento_Trava_Conferir]'));
EXEC sys.sp_executesql @Internas;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Acao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Ações que as telas podem ter. Só insere o que falta
                (regra 39). Ação nova de um módulo futuro entra aqui.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (16/11/2026) - Ação EXECUTAR (rotinas e comandos; etapa 02d).
    v1.2 (20/11/2026) - Ação RESTAURAR (restauração de backup pela tela; etapa 03d2).
    v1.3 (22/11/2026) - Etapa 04b (P20): DESATIVAR (o antigo "Excluir", que só
                        desativava), DESFAZER (pelo histórico), RECUPERAR e
                        ESVAZIAR (lixeira); EXCLUIR passa a mandar para a
                        lixeira (nome acertado).
    v1.4 (25/11/2026) - Etapa 04f: LANCAR_RETROATIVO (lançar fora da trava de
                        datas do financeiro, com motivo; decisão de 18/11/2026).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Acao (CODIGO, NOME, ORDEM)
SELECT v.CODIGO, v.NOME, v.ORDEM
FROM (VALUES
        (CAST('VER' AS VARCHAR(20)), CAST(N'Ver / consultar' AS NVARCHAR(60)), CAST(10 AS SMALLINT)),
        ('INCLUIR',          N'Incluir',                     20),
        ('ALTERAR',          N'Alterar',                     30),
        ('EXCLUIR',          N'Excluir / cancelar registro', 40),
        ('EXPORTAR',         N'Exportar para Excel',         50),
        ('IMPORTAR',         N'Importar arquivo',            60),
        ('BAIXAR',           N'Baixar (pagar/receber)',      70),
        ('ESTORNAR',         N'Estornar',                    80),
        ('CANCELAR',         N'Cancelar (contrato, boleto)', 90),
        ('REABRIR',          N'Reabrir (mês, contrato)',    100),
        ('APROVAR',          N'Aprovar',                    110),
        ('ENVIAR',           N'Enviar (e-mail, remessa)',   120),
        ('DESBLOQUEAR',      N'Desbloquear usuário',        130),
        ('REDEFINIR_SENHA',  N'Definir senha provisória',   140),
        ('EXECUTAR',         N'Executar (rotina, comando)', 150),
        ('RESTAURAR',        N'Restaurar backup do banco',  160),
        ('DESATIVAR',        N'Desativar / reativar',        45),
        ('DESFAZER',         N'Desfazer pelo histórico',    170),
        ('RECUPERAR',        N'Recuperar da lixeira',       180),
        ('ESVAZIAR',         N'Esvaziar a lixeira (apagar de vez)', 190),
        ('LANCAR_RETROATIVO', N'Lançar fora da trava de datas (com motivo)', 200)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
GO

UPDATE a
   SET a.NOME = N'Excluir (vai para a lixeira) / cancelar', a.DT_ALTERACAO = SYSDATETIME(), a.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Acao a
WHERE a.CODIGO = 'EXCLUIR' AND a.NOME = N'Excluir / cancelar registro';
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Item.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Item] e [SIS].[Item_Acao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Menu do módulo SIS e as ações de cada tela. Só insere o que
                falta (regra 39). Cada etapa seguinte acrescenta aqui os itens
                do seu módulo (ou cria a carga do seu bloco).
                Itens são inseridos em passadas: primeiro os de 1º nível,
                depois os filhos cujo pai já existe (até 5 níveis).
                Caminhos das telas: relativos ao wwwroot da API (fase 4).
                Acertado também em item já existente (itens só mudam por
                carga): EXCLUSIVO_GERAL e TABELAS_DA_TELA.
                HABILITADO só é gravado na inclusão (depois é escolha do
                administrador geral). Telas do SIS nascem habilitadas; telas de
                módulos novos devem nascer com HABILITADO = 0.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02b).
    v1.1 (15/11/2026) - EXCLUSIVO_GERAL: Licença e Parâmetros só para o
                        administrador geral (acertado também em item já
                        existente, porque itens só mudam por carga).
    v1.2 (16/11/2026) - Etapa 02c: HABILITADO, TABELAS_DA_TELA e as telas
                        "Módulos e telas" (exclusiva), "Auditoria" e "Lotes".
    v1.3 (16/11/2026) - Etapa 02d: "Rotinas automáticas" e "Instalação e
                        manutenção" (exclusivas); agrupador "E-mails" com
                        "Grupos de e-mail" e "E-mails enviados".
    v1.4 (22/11/2026) - Etapa 04b (P20): tela "Lixeira" (Monitoramento) e ação
                        DESFAZER em Usuários, Perfis e Auditoria (lote).
    v1.5 (23/11/2026) - Etapa 04c (P22): tela "Versões" (Monitoramento). VER
                        libera o histórico de atualizações; as notas das
                        versões são para todos (não dependem de permissão).
    v1.6 (25/11/2026) - Etapa 04f: tela "Parâmetros de uso" (SIS_PARAMETRO_USO,
                        mesma tela de Parâmetros com ?uso=1): os dois
                        administradores alteram os parâmetros de NIVEL_MINIMO 1
                        (decisão do Celso de 18/11/2026). VER, ALTERAR e EXPORTAR.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaItem;

SELECT v.MODULO, v.PAI, v.CODIGO, v.NOME, v.TIPO, v.CAMINHO, v.ORDEM, v.EXCLUSIVO_GERAL, v.HABILITADO, v.TABELAS
INTO #CargaItem
FROM (VALUES
        (CAST('SIS' AS VARCHAR(10)), CAST(NULL AS VARCHAR(40)), CAST('SIS_CONFIGURACAO' AS VARCHAR(40)), CAST(N'Configuração' AS NVARCHAR(80)),
         CAST('MENU' AS VARCHAR(10)), CAST('' AS VARCHAR(200)), CAST(10 AS SMALLINT), CAST(0 AS BIT), CAST(1 AS BIT), CAST('' AS VARCHAR(500))),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_LICENCA',       N'Licença',             'TELA', 'sis/licenca.html',     10, 1, 1, 'SIS.Licenca,SIS.Licenca_Empresa'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_PARAMETRO',     N'Parâmetros',          'TELA', 'sis/parametros.html',  20, 1, 1, 'SIS.Parametro'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_PARAMETRO_USO', N'Parâmetros de uso',   'TELA', 'sis/parametros.html?uso=1', 25, 0, 1, 'SIS.Parametro'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_MODULO',        N'Módulos e telas',     'TELA', 'sis/modulos.html',     30, 1, 1, 'SIS.Modulo,SIS.Item'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_ROTINA',        N'Rotinas automáticas', 'TELA', 'sis/rotinas.html',     40, 1, 1, 'SIS.Rotina'),
        ('SIS', 'SIS_CONFIGURACAO',  'SIS_INSTALACAO',    N'Instalação e manutenção', 'TELA', 'sis/instalacao.html', 50, 1, 1, ''),
        ('SIS', NULL,                'SIS_SEGURANCA',     N'Segurança',           'MENU', '',                     20, 0, 1, ''),
        ('SIS', 'SIS_SEGURANCA',     'SIS_USUARIO',       N'Usuários',            'TELA', 'sis/usuarios.html',    10, 0, 1, 'SIS.Usuario,SIS.Usuario_Permissao'),
        ('SIS', 'SIS_SEGURANCA',     'SIS_PERFIL',        N'Perfis e permissões', 'TELA', 'sis/perfis.html',      20, 0, 1, 'SIS.Perfil,SIS.Perfil_Permissao'),
        ('SIS', NULL,                'SIS_EMAILS',        N'E-mails',             'MENU', '',                     25, 0, 1, ''),
        ('SIS', 'SIS_EMAILS',        'SIS_GRUPO_EMAIL',   N'Grupos de e-mail',    'TELA', 'sis/grupos-email.html', 10, 0, 1, 'SIS.Grupo_Email,SIS.Grupo_Email_Destinatario'),
        ('SIS', 'SIS_EMAILS',        'SIS_EMAIL_FILA',    N'E-mails enviados',    'TELA', 'sis/emails.html',      20, 0, 1, ''),
        ('SIS', NULL,                'SIS_MONITORAMENTO', N'Monitoramento',       'MENU', '',                     30, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOG_ERRO',      N'Log de erros',        'TELA', 'sis/log-erros.html',   10, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_AUDITORIA',     N'Auditoria',           'TELA', 'sis/auditoria.html',   20, 0, 1, ''),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LOTE',          N'Lotes',               'TELA', 'sis/lotes.html',       30, 0, 1, 'SIS.Lote'),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_LIXEIRA',       N'Lixeira',             'TELA', 'sis/lixeira.html',     40, 0, 1, 'SIS.Lixeira,SIS.Tabela_Config'),
        ('SIS', 'SIS_MONITORAMENTO', 'SIS_VERSOES',       N'Versões',             'TELA', 'sis/versoes.html',     50, 0, 1, '')
     ) v (MODULO, PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS);

DECLARE @Passada INT = 1;
WHILE @Passada <= 5
BEGIN
    INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
    SELECT m.ID_MODULO, pai.ID_ITEM, c.CODIGO, c.NOME, c.TIPO, c.CAMINHO, c.ORDEM, c.EXCLUSIVO_GERAL, c.HABILITADO, c.TABELAS
    FROM #CargaItem c
    INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
    LEFT  JOIN SIS.Item pai ON pai.CODIGO = c.PAI
    WHERE (c.PAI IS NULL OR pai.ID_ITEM IS NOT NULL)
      AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = c.CODIGO);

    SET @Passada = @Passada + 1;
END;

UPDATE i
   SET i.EXCLUSIVO_GERAL   = c.EXCLUSIVO_GERAL,
       i.TABELAS_DA_TELA   = c.TABELAS,
       i.DT_ALTERACAO      = SYSDATETIME(),
       i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
INNER JOIN #CargaItem c ON c.CODIGO = i.CODIGO
WHERE i.EXCLUSIVO_GERAL <> c.EXCLUSIVO_GERAL
   OR i.TABELAS_DA_TELA <> c.TABELAS;

DROP TABLE IF EXISTS #CargaItem;
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES
        (CAST('SIS_LICENCA' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))),
        ('SIS_LICENCA',   'INCLUIR'),
        ('SIS_PARAMETRO', 'VER'),
        ('SIS_PARAMETRO', 'ALTERAR'),
        ('SIS_PARAMETRO', 'EXPORTAR'),
        ('SIS_PARAMETRO_USO', 'VER'),
        ('SIS_PARAMETRO_USO', 'ALTERAR'),
        ('SIS_PARAMETRO_USO', 'EXPORTAR'),
        ('SIS_MODULO',    'VER'),
        ('SIS_MODULO',    'ALTERAR'),
        ('SIS_USUARIO',   'VER'),
        ('SIS_USUARIO',   'INCLUIR'),
        ('SIS_USUARIO',   'ALTERAR'),
        ('SIS_USUARIO',   'DESBLOQUEAR'),
        ('SIS_USUARIO',   'REDEFINIR_SENHA'),
        ('SIS_USUARIO',   'EXPORTAR'),
        ('SIS_PERFIL',    'VER'),
        ('SIS_PERFIL',    'INCLUIR'),
        ('SIS_PERFIL',    'ALTERAR'),
        ('SIS_PERFIL',    'EXPORTAR'),
        ('SIS_LOG_ERRO',  'VER'),
        ('SIS_LOG_ERRO',  'EXPORTAR'),
        ('SIS_AUDITORIA', 'VER'),
        ('SIS_AUDITORIA', 'EXPORTAR'),
        ('SIS_LOTE',      'VER'),
        ('SIS_LOTE',      'EXPORTAR'),
        ('SIS_ROTINA',    'VER'),
        ('SIS_ROTINA',    'ALTERAR'),
        ('SIS_ROTINA',    'EXECUTAR'),
        ('SIS_INSTALACAO','VER'),
        ('SIS_INSTALACAO','EXECUTAR'),
        ('SIS_INSTALACAO','CANCELAR'),
        ('SIS_GRUPO_EMAIL','VER'),
        ('SIS_GRUPO_EMAIL','INCLUIR'),
        ('SIS_GRUPO_EMAIL','ALTERAR'),
        ('SIS_GRUPO_EMAIL','EXPORTAR'),
        ('SIS_EMAIL_FILA','VER'),
        ('SIS_EMAIL_FILA','ENVIAR'),
        ('SIS_EMAIL_FILA','CANCELAR'),
        ('SIS_EMAIL_FILA','EXPORTAR'),
        ('SIS_LIXEIRA',   'VER'),
        ('SIS_LIXEIRA',   'RECUPERAR'),
        ('SIS_LIXEIRA',   'ALTERAR'),
        ('SIS_LIXEIRA',   'ESVAZIAR'),
        ('SIS_LIXEIRA',   'EXPORTAR'),
        ('SIS_USUARIO',   'DESFAZER'),
        ('SIS_PERFIL',    'DESFAZER'),
        ('SIS_AUDITORIA', 'DESFAZER'),
        ('SIS_VERSOES',   'VER'),
        ('SIS_VERSOES',   'EXPORTAR')
     ) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Item.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Item] e [SIS].[Item_Acao] do módulo FIN
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Tela "Arquivo morto" (só consulta: VER e EXPORTAR, sem incluir,
                alterar ou excluir). Nasce DESABILITADA, como toda tela de módulo
                novo. As telas de lançamento, baixa e conciliação entram na fase 4.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
    v1.1 (25/11/2026) - Etapa 04f: telas "Contas a pagar" (FIN_PAGAR) e
                        "Contas a receber" (FIN_RECEBER), mesma tela com o tipo
                        no endereço, permissões separadas; nascem desabilitadas.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_ARQUIVO_MORTO', N'Arquivo morto', 'TELA', 'fin/arquivo-morto.html', 90, 0, 0, 'FIN.Arquivo_Morto'
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_ARQUIVO_MORTO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_ARQUIVO_MORTO' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))), ('FIN_ARQUIVO_MORTO', 'EXPORTAR')) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, v.CODIGO, v.NOME, 'TELA', v.CAMINHO, v.ORDEM, 0, 0, 'FIN.Lancamento,FIN.Parcela'
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40)), CAST(N'Contas a pagar' AS NVARCHAR(80)), CAST('fin/lancamentos.html?tipo=P' AS VARCHAR(200)), CAST(10 AS SMALLINT)),
             ('FIN_RECEBER', N'Contas a receber', 'fin/lancamentos.html?tipo=R', 20)) v (CODIGO, NOME, CAMINHO, ORDEM)
INNER JOIN SIS.Modulo m ON m.CODIGO = 'FIN'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = v.CODIGO);
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('VER' AS VARCHAR(20))), ('INCLUIR'), ('ALTERAR'), ('CANCELAR'), ('EXCLUIR'), ('EXPORTAR'), ('DESFAZER'), ('LANCAR_RETROATIVO')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga dos parâmetros do financeiro em [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Trava de datas (aprovada em 18/11/2026) e proteções contra
                erro de digitação nos lançamentos (P17, aprovado em 25/11/2026).
                Regras FIN_REGRA_*: AVISO (pede confirmação, que fica
                registrada), BLOQUEIO (não deixa gravar) ou NAO (desligada).
                Só insere o que falta (regra 39): nunca sobrescreve o valor
                que a CMJ já alterou. NIVEL_MINIMO e OPCOES são da instalação
                e são acertados sempre. Os parâmetros de uso têm NIVEL_MINIMO
                1 (os dois administradores alteram em "Parâmetros de uso").
  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04f).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaParametro;

SELECT v.CHAVE, v.VALOR, v.TIPO, v.DESCRICAO, v.NIVEL, v.OPCOES
INTO #CargaParametro
FROM (VALUES
        (CAST('FIN_TRAVA_DATAS_ATIVA' AS VARCHAR(60)), CAST(N'S' AS NVARCHAR(4000)), CAST('SN' AS VARCHAR(10)),
         CAST(N'Liga a trava de datas dos lançamentos (datas muito antigas ou futuras são recusadas; quem tem a permissão "Lançar fora da trava de datas" grava informando o motivo).' AS NVARCHAR(400)),
         CAST(1 AS TINYINT), CAST(N'' AS NVARCHAR(200))),
        ('FIN_DIAS_TOLERANCIA_MES_ANTERIOR', N'5', 'INTEIRO',
         N'Data anterior ao 1º dia do mês atual é recusada, menos até este dia do mês, quando o mês anterior ainda é aceito.', 1, N''),
        ('FIN_EMISSAO_DIAS_FUTURO', N'0', 'INTEIRO',
         N'Quantos dias no futuro a data de emissão do documento pode ter (0 = não pode ser futura).', 1, N''),
        ('FIN_BAIXA_DIAS_FUTURO', N'0', 'INTEIRO',
         N'Quantos dias no futuro a data de pagamento, recebimento, transferência ou movimento bancário pode ter (0 = não pode ser futura).', 1, N''),
        ('FIN_VENCIMENTO_ANOS_FUTURO', N'35', 'INTEIRO',
         N'Até quantos anos à frente um vencimento pode ser lançado.', 1, N''),
        ('FIN_DATA_AVISO_DIAS', N'3', 'INTEIRO',
         N'Data de emissão (ou vencimento no passado) a mais destes dias de hoje, mesmo dentro do permitido: a tela pede para confirmar a data.', 1, N''),
        ('FIN_REGRA_DUPLIC_DOCUMENTO', N'BLOQUEIO', 'TEXTO',
         N'Mesmo parceiro e mesmo número de documento já lançado (no mesmo tipo, a pagar ou a receber). Vale para documento com número.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_DUPLIC_VALOR', N'AVISO', 'TEXTO',
         N'Possível duplicidade: mesmo parceiro, mesmo valor de parcela e vencimento próximo (dias em FIN_DUPLIC_VALOR_DIAS).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_DUPLIC_VALOR_DIAS', N'5', 'INTEIRO',
         N'Diferença de dias no vencimento para considerar possível duplicidade.', 1, N''),
        ('FIN_REGRA_VALOR_FORA_PADRAO', N'AVISO', 'TEXTO',
         N'Valor fora do padrão: maior que FIN_VALOR_FORA_PADRAO_VEZES vezes a média dos lançamentos do mesmo parceiro e conta do plano.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_VALOR_FORA_PADRAO_VEZES', N'3', 'DECIMAL',
         N'Quantas vezes acima da média o valor precisa estar para o aviso de valor fora do padrão.', 1, N''),
        ('FIN_VALOR_FORA_PADRAO_MIN_HIST', N'3', 'INTEIRO',
         N'Quantos lançamentos anteriores (mesmo parceiro e conta) são necessários para calcular a média do valor fora do padrão.', 1, N''),
        ('FIN_VALOR_FORA_PADRAO_MESES', N'12', 'INTEIRO',
         N'Quantos meses para trás entram na média do valor fora do padrão.', 1, N''),
        ('FIN_REGRA_VENC_ANTES_EMISSAO', N'AVISO', 'TEXTO',
         N'Vencimento de alguma parcela antes da data de emissão do documento.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_COMPETENCIA_DISTANTE', N'AVISO', 'TEXTO',
         N'Mês de competência distante do mês de emissão (mais que FIN_COMPETENCIA_MESES meses).', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_COMPETENCIA_MESES', N'3', 'INTEIRO',
         N'Diferença máxima, em meses, entre a competência e a emissão antes do aviso.', 1, N''),
        ('FIN_REGRA_TIPO_PARCEIRO', N'AVISO', 'TEXTO',
         N'Parceiro sem o tipo Fornecedor (contas a pagar) ou Cliente (contas a receber); o aviso oferece marcar o tipo.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_REGRA_TIPO_CONTA', N'AVISO', 'TEXTO',
         N'Conta do plano de receita usada em contas a pagar, ou de despesa em contas a receber.', 1, N'AVISO;BLOQUEIO;NAO'),
        ('FIN_LISTA_POR_PAGINA', N'100', 'INTEIRO',
         N'Quantas linhas por página nas listas de contas a pagar e a receber.', 1, N'')
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, NIVEL, OPCOES);

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN, NIVEL_MINIMO, OPCOES)
SELECT c.CHAVE, c.VALOR, c.VALOR, c.TIPO, c.DESCRICAO, m.ID_MODULO, 1, c.NIVEL, c.OPCOES
FROM #CargaParametro c
INNER JOIN SIS.Modulo m ON m.CODIGO = 'FIN'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = c.CHAVE);

UPDATE p
   SET p.NIVEL_MINIMO = c.NIVEL, p.OPCOES = c.OPCOES, p.DESCRICAO = c.DESCRICAO, p.VALOR_PADRAO = c.VALOR
FROM SIS.Parametro p
INNER JOIN #CargaParametro c ON c.CHAVE = p.CHAVE
WHERE p.NIVEL_MINIMO <> c.NIVEL OR p.OPCOES <> c.OPCOES OR p.DESCRICAO <> c.DESCRICAO OR p.VALOR_PADRAO <> c.VALOR;

-- Parâmetros de uso de outras etapas que os dois administradores também alteram
UPDATE p
   SET p.NIVEL_MINIMO = 1
FROM SIS.Parametro p
WHERE p.CHAVE IN ('CENTRO_ENCERRADO_BLOQUEIA')
  AND p.NIVEL_MINIMO <> 1;

DROP TABLE IF EXISTS #CargaParametro;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Perfil_Padrao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial dos perfis comuns de [SIS].[Perfil]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Perfis de fábrica para o administrador da empresa começar
                (pendência 9 da seção 6 do CLAUDE.md; sugestão aprovada pelo
                Celso em 22/11/2026, conversa 04a). Depois de criados, quem
                manda é a tela Perfis e permissões: o administrador ajusta à
                vontade.
                  Financeiro: todas as ações nas telas de Cadastros,
                      Financeiro, Bancos e Cobrança, menos REABRIR (mês
                      fechado); só consulta em Imóveis, Vendas, Custos de obra
                      e Painel.
                  Consulta: só VER em todas as telas fora do módulo Sistema.
                As permissões são dadas SÓ quando o perfil nasce (neste mesmo
                lote). Perfil que já existe não é tocado: rodar o MASTER de novo
                (atualização) nunca devolve uma permissão que o administrador
                tirou. Telas novas de versões futuras entram desmarcadas: o
                administrador marca na tela.
                Telas exclusivas do administrador geral nunca entram.
                Depende das cargas de SIS.Item e SIS.Item_Acao de todos os
                módulos (vai depois delas).

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04a).
    v1.1 (22/11/2026) - Etapa 04b (P20): Financeiro não recebe DESFAZER
                        (liberável por perfil; decisão do Celso).
    v1.2 (25/11/2026) - Etapa 04f: Financeiro também não recebe
                        LANCAR_RETROATIVO (por padrão só os administradores).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Novos TABLE (ID_PERFIL INT NOT NULL, NOME NVARCHAR(60) NOT NULL);

INSERT INTO SIS.Perfil (NOME, DESCRICAO, NIVEL_ADMIN, ATIVO)
OUTPUT inserted.ID_PERFIL, inserted.NOME INTO @Novos (ID_PERFIL, NOME)
SELECT v.NOME, v.DESCRICAO, 0, 1
FROM (VALUES
        (CAST(N'Financeiro' AS NVARCHAR(60)),
         CAST(N'Contas a pagar e a receber, baixas, bancos e cobrança, com os cadastros. Não reabre mês fechado. Só consulta imóveis, vendas, obras e painel.' AS NVARCHAR(400))),
        (N'Consulta',
         N'Só consulta: vê as telas dos módulos liberados, sem incluir, alterar, excluir nem exportar.')
     ) v (NOME, DESCRICAO)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil p WHERE p.NOME = v.NOME);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO)
SELECT n.ID_PERFIL, ia.ID_ITEM_ACAO
FROM @Novos n
CROSS JOIN SIS.Item_Acao ia
INNER JOIN SIS.Item   i ON i.ID_ITEM   = ia.ID_ITEM AND i.TIPO = 'TELA' AND i.EXCLUSIVO_GERAL = 0
INNER JOIN SIS.Modulo m ON m.ID_MODULO = i.ID_MODULO
INNER JOIN SIS.Acao   a ON a.ID_ACAO   = ia.ID_ACAO
WHERE ia.ATIVO = 1
  AND m.CODIGO <> 'SIS'
  AND (   (n.NOME = N'Consulta'   AND a.CODIGO = 'VER')
       OR (n.NOME = N'Financeiro' AND m.CODIGO IN ('CAD', 'FIN', 'BANCO', 'COBR') AND a.CODIGO NOT IN ('REABRIR', 'DESFAZER', 'LANCAR_RETROATIVO'))
       OR (n.NOME = N'Financeiro' AND m.CODIGO NOT IN ('CAD', 'FIN', 'BANCO', 'COBR') AND a.CODIGO = 'VER'))
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao pp WHERE pp.ID_PERFIL = n.ID_PERFIL AND pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Tabela_Config.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Tabela_Config] e do grupo de e-mail da lixeira
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Configuração do desfazer e da lixeira por tabela (P20,
                docs/requisitos/Lixeira_Desfazer.md). Inclui o que falta e
                acerta a parte técnica (filhas, campos, descrição) das que já
                existem; o prazo próprio (DIAS_GUARDA) é da CMJ e nunca é
                mudado por aqui.
                Grupo de e-mail LIXEIRA_AVISO (aviso do que será apagado):
                nasce com o e-mail interno do sistema; a CMJ ajusta na tela
                Grupos de e-mail.
                Idempotente.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
    v1.1 (25/11/2026) - Etapa 04d: CAD.Pessoa_Tipo (filha da Pessoa) e CAD.Parceiro_Tipo.
    v1.2 (25/11/2026) - Etapa 04f: FIN.Lancamento (lixeira, parcelas vão junto,
                        trava própria FIN_Lancamento_Trava_Conferir: só manual,
                        sem baixa, mês fechado de conta contábil) e FIN.Parcela
                        (desfazer; inclusão de parcela não é desfeita).
                        PROC_VALIDAR entra também pela carga.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaConfig;

SELECT v.TABELA, v.DESFAZER, v.LIXEIRA, v.BLOQUEADOS, v.UNICOS, v.FILHAS, v.INCLUSAO, v.EXCLUSAO, v.DESCRICAO
INTO #CargaConfig
FROM (VALUES
        (CAST(N'CAD.Pessoa' AS NVARCHAR(256)), CAST(1 AS BIT), CAST(1 AS BIT), CAST(N'' AS NVARCHAR(1000)), CAST(N'CPF_CNPJ' AS NVARCHAR(400)),
         CAST(N'CAD.Pessoa_Contato.ID_PESSOA,CAD.Pessoa_Vinculo.ID_PESSOA,CAD.Pessoa_Dado_Bancario.ID_PESSOA,CAD.Pessoa_Tipo.ID_PESSOA' AS NVARCHAR(1000)),
         CAST('LIXEIRA' AS VARCHAR(10)), CAST('RECUSAR' AS VARCHAR(10)),
         CAST(N't.NOME + CASE WHEN t.CPF_CNPJ <> '''' THEN N'' ('' + CONVERT(NVARCHAR(20), t.CPF_CNPJ) + N'')'' ELSE N'''' END' AS NVARCHAR(1000))),
        (N'CAD.Pessoa_Contato',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(20), t.TIPO) + N'': '' + t.VALOR'),
        (N'CAD.Pessoa_Tipo',          1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Tipo '' + CAST(t.ID_PARCEIRO_TIPO AS NVARCHAR(10))'),
        (N'CAD.Parceiro_Tipo',        1, 1, N'SISTEMA', N'CODIGO', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Pessoa_Vinculo',       1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Vínculo '' + CONVERT(NVARCHAR(30), t.TIPO)'),
        (N'CAD.Pessoa_Dado_Bancario', 1, 0, N'', N'', N'', 'DESATIVAR', 'RECUSAR', N'N''Conta '' + CONVERT(NVARCHAR(20), t.AGENCIA) + N'' / '' + CONVERT(NVARCHAR(30), t.CONTA)'),
        (N'CAD.Empresa',              1, 1, N'', N'CNPJ', N'', 'LIXEIRA', 'RECUSAR', N't.RAZAO_SOCIAL'),
        (N'CAD.Centro_Custo',         1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N'CONVERT(NVARCHAR(30), t.CODIGO) + N'' - '' + t.DESCRICAO'),
        (N'CAD.Plano_Grupo',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Subgrupo',       1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'CAD.Plano_Conta',          1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Conta',              1, 1, N'', N'', N'', 'LIXEIRA', 'RECUSAR', N't.DESCRICAO'),
        (N'BANCO.Banco',              1, 0, N'', N'', N'', 'RECUSAR', 'RECUSAR', N'CONVERT(NVARCHAR(10), t.CODIGO) + N'' - '' + t.NOME'),
        (N'SIS.Usuario',              1, 0, N'SENHA_HASH,SENHA_SALT,SENHA_ITERACOES,SENHA_ALGORITMO,DT_SENHA,TROCAR_SENHA,TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN,BLOQUEADO,DT_BLOQUEIO,INTERNO',
         N'', N'SIS.Usuario_Permissao.ID_USUARIO', 'DESATIVAR', 'RECUSAR', N'CONVERT(NVARCHAR(100), t.LOGIN) + N'' - '' + t.NOME'),
        (N'SIS.Usuario_Permissao',    1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))'),
        (N'SIS.Perfil',               1, 0, N'NIVEL_ADMIN', N'', N'SIS.Perfil_Permissao.ID_PERFIL', 'DESATIVAR', 'RECUSAR', N't.NOME'),
        (N'SIS.Perfil_Permissao',     1, 0, N'', N'', N'', 'APAGAR', 'REINSERIR', N'N''Permissão '' + CAST(t.ID_ITEM_ACAO AS NVARCHAR(10))'),
        (N'FIN.Lancamento',           1, 1, N'TIPO,ORIGEM,ID_ORIGEM,ID_LOTE,CODIGO_ACCESS,ORIGEM_ACCESS,ID_PEDIDO_COMPRA', N'', N'FIN.Parcela.ID_LANCAMENTO', 'LIXEIRA', 'RECUSAR',
         N'CASE t.TIPO WHEN ''P'' THEN N''A pagar '' ELSE N''A receber '' END + CASE WHEN t.DOCUMENTO <> N'''' THEN N''doc. '' + t.DOCUMENTO + N'' - '' ELSE N'''' END + t.HISTORICO + N'' ('' + CONVERT(NVARCHAR(30), t.VALOR_TOTAL) + N'')'''),
        (N'FIN.Parcela',              1, 0, N'VALOR_BAIXADO,SITUACAO,ID_LANCAMENTO,CODIGO_ACCESS,ID_LOTE', N'', N'', 'RECUSAR', 'RECUSAR',
         N'N''Parcela '' + CONVERT(NVARCHAR(5), t.NUMERO) + N''/'' + CONVERT(NVARCHAR(5), t.QTD_PARCELAS) + N'' venc. '' + CONVERT(NVARCHAR(10), t.DT_VENCIMENTO, 103)')
     ) v (TABELA, DESFAZER, LIXEIRA, BLOQUEADOS, UNICOS, FILHAS, INCLUSAO, EXCLUSAO, DESCRICAO);

INSERT INTO SIS.Tabela_Config (TABELA, PERMITE_DESFAZER, PERMITE_LIXEIRA, CAMPOS_BLOQUEADOS, CAMPOS_UNICOS, TABELAS_FILHAS, DESFAZER_INCLUSAO, DESFAZER_EXCLUSAO, DESCRICAO_SQL, USUARIO_CRIACAO)
SELECT c.TABELA, c.DESFAZER, c.LIXEIRA, c.BLOQUEADOS, c.UNICOS, c.FILHAS, c.INCLUSAO, c.EXCLUSAO, c.DESCRICAO, N'instalacao'
FROM #CargaConfig c
WHERE OBJECT_ID(c.TABELA, N'U') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM SIS.Tabela_Config t WHERE t.TABELA = c.TABELA);

UPDATE t
   SET t.PERMITE_DESFAZER = c.DESFAZER, t.PERMITE_LIXEIRA = c.LIXEIRA, t.CAMPOS_BLOQUEADOS = c.BLOQUEADOS, t.CAMPOS_UNICOS = c.UNICOS,
       t.TABELAS_FILHAS = c.FILHAS, t.DESFAZER_INCLUSAO = c.INCLUSAO, t.DESFAZER_EXCLUSAO = c.EXCLUSAO, t.DESCRICAO_SQL = c.DESCRICAO,
       t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Tabela_Config t
INNER JOIN #CargaConfig c ON c.TABELA = t.TABELA
WHERE t.PERMITE_DESFAZER <> c.DESFAZER OR t.PERMITE_LIXEIRA <> c.LIXEIRA OR t.CAMPOS_BLOQUEADOS <> c.BLOQUEADOS OR t.CAMPOS_UNICOS <> c.UNICOS
   OR t.TABELAS_FILHAS <> c.FILHAS OR t.DESFAZER_INCLUSAO <> c.INCLUSAO OR t.DESFAZER_EXCLUSAO <> c.EXCLUSAO OR t.DESCRICAO_SQL <> c.DESCRICAO;

UPDATE t
   SET t.PROC_VALIDAR = v.PROC_VALIDAR, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Tabela_Config t
INNER JOIN (VALUES (CAST(N'FIN.Lancamento' AS NVARCHAR(256)), CAST(N'FIN.FIN_Lancamento_Trava_Conferir' AS NVARCHAR(256))),
                   (N'FIN.Parcela', N'FIN.FIN_Lancamento_Trava_Conferir')) v (TABELA, PROC_VALIDAR) ON v.TABELA = t.TABELA
WHERE t.PROC_VALIDAR <> v.PROC_VALIDAR;

DROP TABLE IF EXISTS #CargaConfig;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT 'LIXEIRA_AVISO', N'Aviso da lixeira', N'Recebem o aviso diário do que será apagado de vez da lixeira (Sistema › Lixeira).', N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = 'LIXEIRA_AVISO');

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, N'construtora.m.judice@gmail.com', N'Administração do sistema', N'instalacao'
FROM SIS.Grupo_Email g
WHERE g.CODIGO = 'LIXEIRA_AVISO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/Carga_FIN_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do FIN e do BANCO (03c)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de negócio da 03c. Não
                entram: Arquivo_Morto (só consulta, carga da migração) e as linhas
                do extrato (vêm do arquivo do banco). CAD.Empresa é regerada por
                causa da coluna nova PASTA_OFX.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'CAD.Empresa',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Historico_Padrao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Mes_Fechado',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Transferencia',    @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'BANCO.Movimento',      @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Lancamento',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Parcela',          @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'FIN.Baixa',            @Criar = 1;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Auditoria_Triggers.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : triggers de auditoria das tabelas do SIS
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Liga a auditoria (seção 3.7) nas tabelas de configuração e
                segurança do SIS, gerando cada trigger com
                SIS.SIS_Auditoria_Trigger_Gerar (@Criar = 1). Pode rodar de
                novo: recria as triggers com a estrutura atual das tabelas.
                No MASTER fica na parte 8 (triggers). Cada etapa seguinte
                acrescenta aqui (ou na carga do seu bloco) as suas tabelas.
                Não auditadas (são registros, não cadastros): Log_Erro,
                Log_Passo, Login_Log, Sessao, Lote e a própria Auditoria.
                SIS.Usuario: não registra contador de tentativas nem último
                login (mudam a cada acesso); hash e salt da senha saem "***".

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02c).
    v1.1 (16/11/2026) - Etapa 02d: grupos de e-mail, rotinas (sem as colunas
                        de execução) e comandos. Filas e logs não são
                        auditados (têm histórico próprio).
    v1.2 (22/11/2026) - Etapa 04b (P20): SIS.Lixeira e SIS.Tabela_Config.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Parametro',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Modulo',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Item',              @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Acao',              @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Item_Acao',         @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Perfil',            @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Perfil_Permissao',  @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Usuario',           @Criar = 1,
     @CamposIgnorados = N'TENTATIVAS_ERRADAS,DT_ULTIMO_LOGIN', @CamposSigilosos = N'SENHA_HASH,SENHA_SALT';
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Usuario_Permissao', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Licenca',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Licenca_Empresa',   @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Anexo_Tipo',        @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Anexo',             @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Grupo_Email',       @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Grupo_Email_Destinatario', @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Rotina',            @Criar = 1,
     @CamposIgnorados = N'PROXIMA_EXECUCAO,SOLICITADA_POR,EM_EXECUCAO,DT_INICIO_EXECUCAO,ULTIMA_EXECUCAO,ULTIMO_RESULTADO,ULTIMA_MENSAGEM';
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Comando',           @Criar = 1;
GO
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Lixeira',           @Criar = 1;
EXEC SIS.SIS_Auditoria_Trigger_Gerar @Tabela = N'SIS.Tabela_Config',     @Criar = 1;
GO

PRINT N'Pacote 04f concluído sem erro.';
GO

SET NOEXEC OFF;
GO
