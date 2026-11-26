/*******************************************************************************
  Pacote      : 04f2d - movimentacao do Parceiro (resumo por tipo com media mensal) e parametros de uso; banco continua 2.4 ate a 04f2e
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 26/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04f2c já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/FIN/04f2d_Homologacao_Movimentacao.sql, SIS/04f2d_Homologacao_Parametros.sql, 04f2c, 04f2a e 02a.
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
    v1.3 (26/11/2026) - Etapa 04f2d: MOTIVO_ALTERACAO (por que a última
                        alteração foi feita; obrigatório quando afrouxa uma
                        regra de bloqueio ou a trava de datas, sugestão (c));
                        vai para a auditoria junto com o valor.
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
IF COL_LENGTH(N'SIS.Parametro', N'MOTIVO_ALTERACAO') IS NULL
    ALTER TABLE [SIS].[Parametro] ADD MOTIVO_ALTERACAO NVARCHAR(400) NOT NULL CONSTRAINT DF_Parametro_MOTIVO_ALTERACAO DEFAULT (N'');
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_Afrouxa.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Afrouxa]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : 1 quando a troca de valor de um parâmetro AFROUXA uma proteção
                (sugestão (c) da 04f2d): nessa hora a tela pede o motivo e o
                SIS_Parametro_Gravar recusa sem ele.
                  - parâmetro com opções AVISO/BLOQUEIO/NAO (regras FIN_REGRA_*
                    do P17): descer de nível (BLOQUEIO > AVISO > NAO);
                  - parâmetro SN que liga uma trava (FIN_TRAVA_DATAS_ATIVA):
                    passar de S para N.
                Valores comparados já no formato canônico (maiúsculas).
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2d).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Parametro_Afrouxa('FIN_REGRA_DUPLIC_VALOR', N'BLOQUEIO', N'AVISO');  -- 1
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Afrouxa] (@Chave VARCHAR(60), @Atual NVARCHAR(4000), @Novo NVARCHAR(4000))
RETURNS BIT
AS
BEGIN
    DECLARE @Opcoes NVARCHAR(200) = (SELECT OPCOES FROM SIS.Parametro WHERE CHAVE = @Chave);
    DECLARE @A NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Atual, N''))));
    DECLARE @N NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Novo, N''))));

    IF @Chave IN ('FIN_TRAVA_DATAS_ATIVA')
        RETURN CASE WHEN @A = N'S' AND @N = N'N' THEN 1 ELSE 0 END;

    IF ISNULL(@Opcoes, N'') LIKE N'%BLOQUEIO%'
        RETURN CASE WHEN (CASE @A WHEN N'BLOQUEIO' THEN 3 WHEN N'AVISO' THEN 2 WHEN N'NAO' THEN 1 ELSE 0 END)
                       > (CASE @N WHEN N'BLOQUEIO' THEN 3 WHEN N'AVISO' THEN 2 WHEN N'NAO' THEN 1 ELSE 0 END)
                    THEN 1 ELSE 0 END;

    RETURN 0;
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
    v1.5 (26/11/2026) - Etapa 04f2d: @Motivo (gravado em MOTIVO_ALTERACAO e
                        na auditoria); obrigatório quando a troca afrouxa uma
                        proteção (SIS.fn_SIS_Parametro_Afrouxa: regra de
                        bloqueio que desce de nível, trava de datas desligada).

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
    @Valor      NVARCHAR(4000),
    @Motivo     NVARCHAR(400) = NULL
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

        SET @Motivo = LTRIM(RTRIM(ISNULL(@Motivo, N'')));
        IF @Motivo = N'' AND SIS.fn_SIS_Parametro_Afrouxa(@Chave, @ValorAtual, @ValorNovo) = 1
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Esta alteração afrouxa uma proteção do sistema: informe o motivo.' AS NVARCHAR(400)) AS MENSAGEM, @IdParametro AS ID_PARAMETRO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        UPDATE p
           SET p.VALOR             = @ValorNovo,
               p.MOTIVO_ALTERACAO  = @Motivo,
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
-- Arquivo: sql/objetos/FIN/FIN.fn_FIN_Lancamento_Pendencias_Simular.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Lancamento_Pendencias_Simular]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Corpo único das pendências de um lançamento (P27), com a
                opção de simular um parâmetro FIN_PEND_* com outro valor
                (@Chave/@Valor; NULL = valores gravados). Usada:
                  - por FIN.fn_FIN_Lancamento_Pendencias (sem simulação),
                    que é a fonte das listas, contadores e ficha;
                  - por SIS.SIS_Parametro_Conferir, para mostrar o efeito de
                    um parâmetro de pendência antes de gravar (sugestão (a)
                    da 04f2d).
                Regras: ver a descrição de FIN.fn_FIN_Lancamento_Pendencias.
                @Valor no formato canônico do parâmetro (data aaaa-mm-dd,
                decimal com ponto).
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2d): corpo trazido da
                        fn_FIN_Lancamento_Pendencias v1.0, sem mudança de regra.
  Homologação (LOCAL):
    -- SELECT f.* FROM FIN.fn_FIN_Lancamento_Pendencias_Simular(1, 'FIN_PEND_VENCIDA_DIAS', N'5') f;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Lancamento_Pendencias_Simular] (@IdLancamento BIGINT, @Chave VARCHAR(60), @Valor NVARCHAR(4000))
RETURNS TABLE
AS
RETURN
(
    WITH cfg AS (   -- parâmetros lidos direto da tabela (função escalar por linha deixava a lista lenta)
        SELECT MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_CENTRO'       AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS SEM_CENTRO,
               MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_PLANO'        AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS SEM_PLANO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_SEM_DOCUMENTO' THEN CONVERT(VARCHAR(1), UPPER(LTRIM(p.VALOR))) END), 'N') AS SEM_DOCUMENTO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR' THEN TRY_CONVERT(DECIMAL(18,2), REPLACE(p.VALOR, N',', N'.')) END), 0) AS ANEXO_VALOR,
               MAX(CASE WHEN p.CHAVE = 'FIN_PEND_RECEBER_NAO_APTO' AND UPPER(LTRIM(RTRIM(p.VALOR))) = N'S' THEN 1 ELSE 0 END) AS NAO_APTO,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_VENCIDA_DIAS' THEN TRY_CONVERT(INT, p.VALOR) END), 0) AS VENCIDA_DIAS,
               ISNULL(MAX(CASE WHEN p.CHAVE = 'FIN_PEND_A_PARTIR_DE' THEN TRY_CONVERT(DATE, p.VALOR, 23) END), CAST('19000101' AS DATE)) AS A_PARTIR_DE,
               CAST(SYSDATETIME() AS DATE) AS HOJE
        FROM (SELECT x.CHAVE, CASE WHEN x.CHAVE = @Chave THEN ISNULL(@Valor, x.VALOR) ELSE x.VALOR END AS VALOR
              FROM SIS.Parametro x WITH (NOLOCK)
              WHERE x.CHAVE LIKE 'FIN[_]PEND[_]%') p
    ),
    lanc AS (
        SELECT l.ID_LANCAMENTO, l.TIPO, l.ID_PESSOA, l.ID_CENTRO_CUSTO, l.ID_PLANO_CONTA, l.DOCUMENTO, l.VALOR_TOTAL, l.DT_EMISSAO
        FROM FIN.Lancamento l
        WHERE l.ID_LANCAMENTO = @IdLancamento
          AND l.SITUACAO = 'ATIVO'
          AND l.DT_EXCLUSAO IS NULL
    ),
    aberto AS (
        SELECT l.*, c.*
        FROM lanc l
        CROSS JOIN cfg c
        WHERE l.DT_EMISSAO >= c.A_PARTIR_DE
          AND EXISTS (SELECT 1 FROM FIN.Parcela p WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO AND p.SITUACAO IN ('ABERTA', 'PARCIAL'))
    )
    SELECT a.ID_LANCAMENTO, CAST(NULL AS BIGINT) AS ID_PARCELA, CAST(NULL AS BIGINT) AS ID_LANCAMENTO_PENDENCIA,
           CAST('AUTOMATICA' AS VARCHAR(10)) AS ORIGEM, CAST('SEM_CENTRO' AS VARCHAR(20)) AS CODIGO,
           CAST(N'Sem centro de custo' AS NVARCHAR(400)) AS DESCRICAO,
           CAST(N'Informe o centro de custo (obra) na ficha do lançamento.' AS NVARCHAR(400)) AS ORIENTACAO,
           CAST(0 AS BIT) AS BLOQUEIA_BAIXA, CAST(0 AS BIT) AS ATRASADA,
           CAST(NULL AS INT) AS ID_PENDENCIA_TIPO, CAST(NULL AS INT) AS ID_USUARIO_RESPONSAVEL, CAST(NULL AS DATE) AS DT_PREVISAO
    FROM aberto a
    WHERE a.SEM_CENTRO = 1 AND a.ID_CENTRO_CUSTO IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_PLANO', N'Sem conta do plano de contas',
           N'Informe a conta do plano de contas na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.SEM_PLANO = 1 AND a.ID_PLANO_CONTA IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_DOCUMENTO', N'Sem número de documento',
           N'Informe o número do documento (nota fiscal, boleto, contrato) na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.DOCUMENTO = N'' AND (a.SEM_DOCUMENTO = 'A' OR a.SEM_DOCUMENTO = a.TIPO)

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'SEM_ANEXO',
           N'Sem anexo (valor acima de ' + SIS.fn_SIS_Formatar_Moeda(a.ANEXO_VALOR) + N')',
           N'Anexe a nota fiscal, o boleto ou o contrato na aba Anexos.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.TIPO = 'P' AND a.ANEXO_VALOR > 0 AND a.VALOR_TOTAL > a.ANEXO_VALOR
      AND NOT EXISTS (SELECT 1 FROM SIS.Anexo x
                      WHERE x.TABELA_REFERENCIA = N'FIN.Lancamento' AND x.ID_REFERENCIA = a.ID_LANCAMENTO AND x.SITUACAO = 'ATIVO')

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'NAO_APTO',
           N'Parceiro não apto para cobrança: ' + ISNULL(f.PENDENCIA, N''),
           N'Complete o cadastro do parceiro (Cadastros › Parceiros, filtro "Pendências de cadastro").', 0, 0, NULL, NULL, NULL
    FROM aberto a
    CROSS APPLY (SELECT TOP (1) c.APTO, c.PENDENCIA FROM CAD.fn_CAD_Pessoa_Pendencia_Cobranca(a.ID_PESSOA) c) f   -- TOP: busca só o parceiro do lançamento
    WHERE a.TIPO = 'R' AND a.NAO_APTO = 1 AND f.APTO = 0

    UNION ALL
    SELECT a.ID_LANCAMENTO, NULL, NULL, 'AUTOMATICA', 'NAO_APTO', N'Sem parceiro para a cobrança',
           N'Informe o parceiro (cliente) na ficha do lançamento.', 0, 0, NULL, NULL, NULL
    FROM aberto a
    WHERE a.TIPO = 'R' AND a.NAO_APTO = 1 AND a.ID_PESSOA IS NULL

    UNION ALL
    SELECT a.ID_LANCAMENTO, v.ID_PARCELA, NULL, 'AUTOMATICA', 'VENCIDA',
           CASE WHEN v.QTD = 1 THEN N'Parcela vencida há mais de ' ELSE CONVERT(NVARCHAR(10), v.QTD) + N' parcelas vencidas há mais de ' END
             + CONVERT(NVARCHAR(10), a.VENCIDA_DIAS) + N' dias (desde ' + CONVERT(NVARCHAR(10), v.DT_VENCIMENTO, 103) + N')',
           CASE a.TIPO WHEN 'P' THEN N'Pague, renegocie ou corrija o vencimento.' ELSE N'Cobre o cliente, renegocie ou corrija o vencimento.' END,
           0, 0, NULL, NULL, NULL
    FROM aberto a
    CROSS APPLY (SELECT TOP (1) p.ID_PARCELA, p.DT_VENCIMENTO, COUNT(*) OVER () AS QTD
                 FROM FIN.Parcela p
                 WHERE p.ID_LANCAMENTO = a.ID_LANCAMENTO AND p.SITUACAO IN ('ABERTA', 'PARCIAL')
                   AND p.DT_VENCIMENTO < DATEADD(DAY, -a.VENCIDA_DIAS, a.HOJE)
                 ORDER BY p.DT_VENCIMENTO, p.NUMERO) v
    WHERE a.VENCIDA_DIAS > 0

    UNION ALL
    SELECT lp.ID_LANCAMENTO, lp.ID_PARCELA, lp.ID_LANCAMENTO_PENDENCIA, 'MANUAL', t.CODIGO,
           t.DESCRICAO + CASE WHEN lp.OBSERVACAO <> N'' THEN N': ' + LEFT(lp.OBSERVACAO, 300) ELSE N'' END,
           t.ORIENTACAO, t.BLOQUEIA_BAIXA,
           CASE WHEN lp.DT_PREVISAO < c.HOJE THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END,
           lp.ID_PENDENCIA_TIPO, lp.ID_USUARIO_RESPONSAVEL, lp.DT_PREVISAO
    FROM lanc l
    CROSS JOIN cfg c
    INNER JOIN FIN.Lancamento_Pendencia lp ON lp.ID_LANCAMENTO = l.ID_LANCAMENTO AND lp.SITUACAO = 'ABERTA' AND lp.ATIVO = 1
    INNER JOIN FIN.Pendencia_Tipo t ON t.ID_PENDENCIA_TIPO = lp.ID_PENDENCIA_TIPO
);
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.fn_FIN_Lancamento_Pendencias.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Lancamento_Pendencias]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - pendências em aberto de um lançamento, uma linha por
                pendência. Fonte única da lista, dos contadores, da ficha e,
                mais adiante, do check-up diário (P25).
                AUTOMATICA: calculada na hora (nada gravado), só para
                  lançamento em aberto (ativo, fora da lixeira, com parcela
                  ABERTA ou PARCIAL) emitido a partir de FIN_PEND_A_PARTIR_DE;
                  some sozinha quando o problema é corrigido. Regras ligadas
                  por parâmetro (nível 1):
                    SEM_CENTRO      FIN_PEND_SEM_CENTRO (S/N)
                    SEM_PLANO       FIN_PEND_SEM_PLANO (S/N)
                    SEM_DOCUMENTO   FIN_PEND_SEM_DOCUMENTO (P, R, A ou N)
                    SEM_ANEXO       FIN_PEND_PAGAR_SEM_ANEXO_VALOR (a pagar
                                    com valor total acima; 0 = desligada)
                    NAO_APTO        FIN_PEND_RECEBER_NAO_APTO (a receber; P10)
                    VENCIDA         FIN_PEND_VENCIDA_DIAS (0 = desligada; uma
                                    linha por lançamento, com a parcela mais
                                    antiga)
                  Automáticas nunca bloqueiam a baixa.
                MANUAL: FIN.Lancamento_Pendencia ABERTA e ativa, de lançamento
                  ativo fora da lixeira (pago ou não). BLOQUEIA_BAIXA vem do
                  tipo; ATRASADA = previsão já passou.
                Função em linha: nas listas entra por CROSS APPLY sem custo
                por linha.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c). Parâmetros lidos direto de
                        SIS.Parametro (sem função escalar por linha).
    v1.1 (26/11/2026) - Etapa 04f2d: o corpo passou para
                        FIN.fn_FIN_Lancamento_Pendencias_Simular (que também
                        simula um parâmetro para a tela de parâmetros); esta
                        chama a outra sem simulação. Mesmas colunas e regras.

  Homologação (LOCAL):
    -- SELECT TOP 50 l.ID_LANCAMENTO, f.* FROM FIN.Lancamento l CROSS APPLY FIN.fn_FIN_Lancamento_Pendencias(l.ID_LANCAMENTO) f;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Lancamento_Pendencias] (@IdLancamento BIGINT)
RETURNS TABLE
AS
RETURN
(
    SELECT s.* FROM FIN.fn_FIN_Lancamento_Pendencias_Simular(@IdLancamento, NULL, NULL) s
);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Parametro_Conferir.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Parametro_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Prévia da tela de parâmetros, antes de gravar (etapa 04f2d):
                  PEDE_MOTIVO  1 = a troca afrouxa uma proteção
                               (SIS.fn_SIS_Parametro_Afrouxa): a tela pede o
                               motivo, que o SIS_Parametro_Gravar exige;
                  QTD_ATUAL /  só nos parâmetros de pendência (FIN_PEND_*):
                  QTD_NOVA     quantos lançamentos em aberto têm hoje a
                               pendência da regra e quantos passam a ter com
                               o valor novo (sugestão (a));
                  EFEITO       a frase pronta para a tela (vazio = nada a
                               mostrar).
                Não grava nada. O valor é conferido de leve (data dd/mm/aaaa
                ou aaaa-mm-dd, decimal com vírgula ou ponto); a conferência de
                verdade é do SIS_Parametro_Gravar.
                Permissão: a mesma da lista (VER em SIS_PARAMETRO, ou VER em
                SIS_PARAMETRO_USO para administrador nível 1 ou 2 nos de uso).
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2d).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Conferir @IdUsuario = 2, @Chave = 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR', @Valor = N'500';
    -- EXEC SIS.SIS_Parametro_Conferir @IdUsuario = 2, @Chave = 'FIN_REGRA_DUPLIC_DOCUMENTO', @Valor = N'NAO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Conferir]
    @IdUsuario INT,
    @Chave     VARCHAR(60),
    @Valor     NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Parametro_Conferir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Tipo       VARCHAR(10);
    DECLARE @Atual      NVARCHAR(4000);
    DECLARE @Nivel      TINYINT;
    DECLARE @Novo       NVARCHAR(4000);
    DECLARE @Codigo     VARCHAR(20);
    DECLARE @QtdAtual   INT;
    DECLARE @QtdNova    INT;
    DECLARE @Efeito     NVARCHAR(400) = N'';
    DECLARE @VeTodos    BIT;

    BEGIN TRY
        SET @VeTodos = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'VER');
        IF @VeTodos = 0
           AND (SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO_USO', 'VER') = 0 OR SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) < 1)
            THROW 50001, N'Você não tem permissão para ver os parâmetros.', 1;

        SET @Chave = UPPER(LTRIM(RTRIM(ISNULL(@Chave, ''))));
        SELECT @Tipo = TIPO, @Atual = VALOR, @Nivel = NIVEL_MINIMO FROM SIS.Parametro WHERE CHAVE = @Chave;
        IF @Tipo IS NULL
            THROW 50001, N'Parâmetro não encontrado.', 1;
        IF @VeTodos = 0 AND @Nivel <> 1
            THROW 50001, N'Este parâmetro só pode ser visto pelo administrador geral.', 1;

        SET @EtapaAtual = 'Valor';
        SET @Novo = LTRIM(RTRIM(ISNULL(@Valor, N'')));
        IF @Tipo IN ('SN', 'TEXTO') SET @Novo = UPPER(@Novo);
        IF @Tipo = 'DECIMAL' SET @Novo = REPLACE(@Novo, N',', N'.');
        IF @Tipo = 'DATA' SET @Novo = ISNULL(CONVERT(NVARCHAR(10), ISNULL(TRY_CONVERT(DATE, @Novo, 103), TRY_CONVERT(DATE, @Novo, 23)), 23), @Novo);

        SET @Codigo = CASE @Chave
                          WHEN 'FIN_PEND_SEM_CENTRO'            THEN 'SEM_CENTRO'
                          WHEN 'FIN_PEND_SEM_PLANO'             THEN 'SEM_PLANO'
                          WHEN 'FIN_PEND_SEM_DOCUMENTO'         THEN 'SEM_DOCUMENTO'
                          WHEN 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR' THEN 'SEM_ANEXO'
                          WHEN 'FIN_PEND_RECEBER_NAO_APTO'      THEN 'NAO_APTO'
                          WHEN 'FIN_PEND_VENCIDA_DIAS'          THEN 'VENCIDA'
                          WHEN 'FIN_PEND_A_PARTIR_DE'           THEN '*'
                      END;

        IF @Codigo IS NOT NULL AND @Novo <> ISNULL(@Atual, N'')
        BEGIN
            SET @EtapaAtual = 'Efeito';
            SELECT l.ID_LANCAMENTO
            INTO #abertos
            FROM FIN.Lancamento l WITH (NOLOCK)
            WHERE l.SITUACAO = 'ATIVO'
              AND l.DT_EXCLUSAO IS NULL
              AND EXISTS (SELECT 1 FROM FIN.Parcela p WITH (NOLOCK) WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO AND p.SITUACAO IN ('ABERTA', 'PARCIAL'));

            SELECT @QtdAtual = COUNT(*)
            FROM #abertos a
            WHERE EXISTS (SELECT 1 FROM FIN.fn_FIN_Lancamento_Pendencias_Simular(a.ID_LANCAMENTO, NULL, NULL) f
                          WHERE f.ORIGEM = 'AUTOMATICA' AND (@Codigo = '*' OR f.CODIGO = @Codigo))
            OPTION (RECOMPILE);

            SELECT @QtdNova = COUNT(*)
            FROM #abertos a
            WHERE EXISTS (SELECT 1 FROM FIN.fn_FIN_Lancamento_Pendencias_Simular(a.ID_LANCAMENTO, @Chave, @Novo) f
                          WHERE f.ORIGEM = 'AUTOMATICA' AND (@Codigo = '*' OR f.CODIGO = @Codigo))
            OPTION (RECOMPILE);

            SET @QtdAtual = ISNULL(@QtdAtual, 0);
            SET @QtdNova  = ISNULL(@QtdNova, 0);
            SET @Efeito = CASE
                              WHEN @QtdNova = @QtdAtual THEN N'Nenhuma mudança: continuam ' + CONVERT(NVARCHAR(10), @QtdNova) + N' lançamentos em aberto com '
                                   + CASE WHEN @Codigo = '*' THEN N'pendência automática.' ELSE N'esta pendência.' END
                              ELSE N'Com o valor novo, ' + CONVERT(NVARCHAR(10), @QtdNova) + N' lançamentos em aberto passam a ter '
                                   + CASE WHEN @Codigo = '*' THEN N'pendência automática' ELSE N'esta pendência' END
                                   + N' (hoje são ' + CONVERT(NVARCHAR(10), @QtdAtual) + N'; '
                                   + CASE WHEN @QtdNova > @QtdAtual THEN N'+' ELSE N'' END + CONVERT(NVARCHAR(10), @QtdNova - @QtdAtual) + N').'
                          END;
        END;

        SELECT SIS.fn_SIS_Parametro_Afrouxa(@Chave, @Atual, @Novo) AS PEDE_MOTIVO,
               @QtdAtual                                            AS QTD_ATUAL,
               @QtdNova                                             AS QTD_NOVA,
               CAST(@Efeito AS NVARCHAR(400))                       AS EFEITO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível conferir o parâmetro. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Parceiro_Movimento_Resumo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Parceiro_Movimento_Resumo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Resumo do topo da aba Movimentação da ficha do Parceiro.
                Uma linha por tipo (P = a pagar, R = a receber) que o usuário
                pode ver (VER em FIN_PAGAR / FIN_RECEBER):
                  QTD/VALOR_EM_ABERTO   parcelas abertas ou parciais (saldo)
                  QTD/VALOR_VENCIDAS    das em aberto, vencidas antes de hoje
                  QTD/VALOR_PAGO_12M    baixas dos últimos 12 meses (valor
                                        líquido; estorno entra negativo e
                                        anula a original)
                  MEDIA_MENSAL_12M      VALOR_PAGO_12M / 12 (sugestão (b) da
                                        04f2d: ajuda a perceber valor fora do
                                        padrão)
                  DT_ULTIMO_PAGAMENTO   data da baixa mais recente
                Não conta o que está na lixeira nem lançamento cancelado.
                Sem permissão em nenhum dos dois tipos: THROW 50001.
                Padrão "Listar": THROW 50001 com mensagem amigável em erro.

  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2d).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Parceiro_Movimento_Resumo @IdUsuario = 2, @IdPessoa = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Parceiro_Movimento_Resumo]
    @IdUsuario INT,
    @IdPessoa  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Parceiro_Movimento_Resumo]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje       DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @Desde      DATE;
    DECLARE @VeP        BIT;
    DECLARE @VeR        BIT;

    BEGIN TRY
        SET @VeP = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VeR = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        IF @VeP = 0 AND @VeR = 0
            THROW 50001, N'Você não tem permissão para ver a movimentação financeira.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Pessoa WITH (NOLOCK) WHERE ID_PESSOA = @IdPessoa)
            THROW 50001, N'Parceiro não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        SET @Desde = DATEADD(DAY, 1, DATEADD(MONTH, -12, @Hoje));

        ;WITH Tipos AS (
            SELECT t.TIPO
            FROM (VALUES ('P'), ('R')) t (TIPO)
            WHERE (t.TIPO = 'P' AND @VeP = 1) OR (t.TIPO = 'R' AND @VeR = 1)
        ),
        Aberto AS (
            SELECT l.TIPO,
                   COUNT(*)                                                     AS QTD_EM_ABERTO,
                   SUM(p.SALDO)                                                 AS VALOR_EM_ABERTO,
                   SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END)     AS QTD_VENCIDAS,
                   SUM(CASE WHEN p.DT_VENCIMENTO < @Hoje THEN p.SALDO ELSE 0 END) AS VALOR_VENCIDAS
            FROM FIN.Parcela p WITH (NOLOCK)
            INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
            WHERE l.ID_PESSOA = @IdPessoa
              AND l.DT_EXCLUSAO IS NULL
              AND l.SITUACAO = 'ATIVO'
              AND p.SITUACAO IN ('ABERTA', 'PARCIAL')
            GROUP BY l.TIPO
        ),
        Pago AS (
            SELECT l.TIPO,
                   SUM(CASE WHEN b.ID_BAIXA_ESTORNADA IS NULL THEN 1 ELSE -1 END) AS QTD_PAGO_12M,
                   SUM(b.VALOR_LIQUIDO)                                           AS VALOR_PAGO_12M
            FROM FIN.Baixa b WITH (NOLOCK)
            INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
            INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
            WHERE l.ID_PESSOA = @IdPessoa
              AND l.DT_EXCLUSAO IS NULL
              AND b.DT_PAGAMENTO BETWEEN @Desde AND @Hoje
            GROUP BY l.TIPO
        ),
        Ultimo AS (
            SELECT l.TIPO, MAX(b.DT_PAGAMENTO) AS DT_ULTIMO_PAGAMENTO
            FROM FIN.Baixa b WITH (NOLOCK)
            INNER JOIN FIN.Parcela p WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
            INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
            WHERE l.ID_PESSOA = @IdPessoa
              AND l.DT_EXCLUSAO IS NULL
              AND b.ID_BAIXA_ESTORNADA IS NULL
            GROUP BY l.TIPO
        )
        SELECT t.TIPO,
               CAST(ISNULL(a.QTD_EM_ABERTO, 0) AS INT)              AS QTD_EM_ABERTO,
               CAST(ISNULL(a.VALOR_EM_ABERTO, 0) AS DECIMAL(18,2))  AS VALOR_EM_ABERTO,
               CAST(ISNULL(a.QTD_VENCIDAS, 0) AS INT)               AS QTD_VENCIDAS,
               CAST(ISNULL(a.VALOR_VENCIDAS, 0) AS DECIMAL(18,2))   AS VALOR_VENCIDAS,
               CAST(ISNULL(g.QTD_PAGO_12M, 0) AS INT)               AS QTD_PAGO_12M,
               CAST(ISNULL(g.VALOR_PAGO_12M, 0) AS DECIMAL(18,2))   AS VALOR_PAGO_12M,
               CAST(ROUND(ISNULL(g.VALOR_PAGO_12M, 0) / 12.0, 2) AS DECIMAL(18,2)) AS MEDIA_MENSAL_12M,
               u.DT_ULTIMO_PAGAMENTO,
               @Desde                                               AS DT_DESDE
        FROM Tipos t
        LEFT JOIN Aberto a ON a.TIPO = t.TIPO
        LEFT JOIN Pago   g ON g.TIPO = t.TIPO
        LEFT JOIN Ultimo u ON u.TIPO = t.TIPO
        ORDER BY t.TIPO
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o resumo da movimentação. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

PRINT N'Pacote 04f2d concluído sem erro.';
GO

SET NOEXEC OFF;
GO
