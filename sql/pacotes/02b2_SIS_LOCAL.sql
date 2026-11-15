/*******************************************************************************
  Pacote      : 02b2 - ajuste da base SIS: identidade visual por cliente (logomarcas e cores)
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 15/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a e 02b já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/02b2_Homologacao_SIS.sql.
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Parametro_Cor.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Parametro_Cor]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Cor de um parâmetro do tipo COR, sempre no formato #RRGGBB,
                pronta para entrar no CSS inline dos e-mails e relatórios.
                Parâmetro inexistente, vazio ou com cor inválida: devolve
                #555555 (cinza neutro), para nunca quebrar o HTML. Nunca NULL.
                Uso: SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL')

  Changelog:
    v1.0 (15/11/2026) - Criação (identidade visual por cliente).

  Homologação:
    -- SELECT SIS.fn_SIS_Parametro_Cor('EMPRESA_COR_PRINCIPAL');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Parametro_Cor] (@Chave VARCHAR(60))
RETURNS VARCHAR(7)
AS
BEGIN
    DECLARE @Cor VARCHAR(7) = UPPER(LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), SIS.fn_SIS_Parametro(@Chave)))), 7));

    IF LEN(@Cor) = 7 AND @Cor LIKE '#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]' COLLATE Latin1_General_BIN2
        RETURN @Cor;

    RETURN '#555555';
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

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'ALTERAR') = 0
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
               @ValorAtual  = p.VALOR
        FROM SIS.Parametro p
        WHERE p.CHAVE = @Chave;

        IF @IdParametro IS NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Parâmetro não encontrado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(NULL AS INT) AS ID_PARAMETRO;
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
               OR @ValorNovo LIKE N'%[^A-Za-z0-9._-]%' COLLATE Latin1_General_BIN2
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
-- Arquivo: sql/objetos/SIS/Carga_SIS_Parametro.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga inicial de [SIS].[Parametro]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Parâmetros de fábrica da base SIS. Só insere o que falta
                (PADRAO_SQL regra 39): valor já alterado pelo administrador
                nunca é sobrescrito. VALOR_PADRAO recebe o mesmo valor de
                fábrica. Cada etapa seguinte acrescenta os seus parâmetros
                (multa, juros, régua de cobrança...) neste arquivo.
                EDITAVEL_ADMIN = 0: só o instalador muda, por script.
                Depende de Carga_SIS_Modulo.sql.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: SENHA_PBKDF2_ITERACOES.
    v1.2 (15/11/2026) - Identidade visual por cliente: pasta, logomarcas e
                        cores (valores de fábrica = CMJ).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN)
SELECT v.CHAVE, v.VALOR, v.VALOR, v.TIPO, v.DESCRICAO, m.ID_MODULO, v.EDITAVEL_ADMIN
FROM (VALUES
        (CAST('EMAIL_TESTE' AS VARCHAR(60)), CAST(N'celsofreitas62@gmail.com' AS NVARCHAR(4000)), CAST('EMAIL' AS VARCHAR(10)),
         CAST(N'Endereço que recebe TODOS os e-mails quando o sistema roda em modo teste (banco _LOCAL).' AS NVARCHAR(400)), CAST('SIS' AS VARCHAR(10)), CAST(0 AS BIT)),
        ('EMAIL_ADMIN_ALERTA', N'', 'EMAIL',
         N'Endereço que recebe os alertas técnicos (falha no envio de e-mail, rotina com erro). Vazio = sem alerta.', 'SIS', 1),
        ('EMAIL_TENTATIVAS_MAX', N'5', 'INTEIRO',
         N'Quantas vezes o serviço tenta reenviar um e-mail com falha temporária antes de desistir.', 'SIS', 1),
        ('SENHA_TAMANHO_MINIMO', N'8', 'INTEIRO',
         N'Quantidade mínima de caracteres da senha dos usuários.', 'SIS', 1),
        ('SENHA_TENTATIVAS_BLOQUEIO', N'5', 'INTEIRO',
         N'Tentativas de senha errada seguidas até o usuário ser bloqueado.', 'SIS', 1),
        ('SESSAO_MINUTOS_INATIVIDADE', N'30', 'INTEIRO',
         N'Minutos sem uso até a sessão expirar e pedir login de novo.', 'SIS', 1),
        ('ANEXO_PASTA_RAIZ', N'C:\SistemaCMJ_Arquivos\Anexos', 'TEXTO',
         N'Pasta do servidor onde os anexos são gravados (o banco guarda só a referência).', 'SIS', 0),
        ('ANEXO_TAMANHO_MAX_MB', N'20', 'INTEIRO',
         N'Tamanho máximo de cada anexo, em MB.', 'SIS', 1),
        ('LOG_PASSO_DIAS_RETENCAO', N'90', 'INTEIRO',
         N'Dias que o log passo a passo das rotinas é guardado (mínimo 7). O log de erros não é apagado.', 'SIS', 1),
        ('SENHA_PBKDF2_ITERACOES', N'600000', 'INTEIRO',
         N'Iterações do PBKDF2-SHA256 usadas pela API ao gravar senha (mínimo aceito: 100000).', 'SIS', 0),
        ('IDENTIDADE_PASTA', N'C:\SistemaCMJ_Arquivos\Identidade', 'TEXTO',
         N'Pasta do servidor com os arquivos de identidade visual do cliente (logomarcas).', 'SIS', 0),
        ('EMPRESA_LOGO', N'logo.png', 'ARQUIVO',
         N'Logomarca vertical completa (documentos, contratos, telas grandes). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_HORIZONTAL', N'logo_horizontal.png', 'ARQUIVO',
         N'Logomarca horizontal (cabeçalho do sistema e dos relatórios). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_EMAIL', N'logo_email.png', 'ARQUIVO',
         N'Logomarca pequena do cabeçalho dos e-mails. Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_LOGO_SIMBOLO', N'logo_simbolo.png', 'ARQUIVO',
         N'Só o símbolo da logomarca (menu recolhido, ícone). Arquivo na pasta de identidade.', 'SIS', 1),
        ('EMPRESA_COR_PRINCIPAL', N'#D43414', 'COR',
         N'Cor principal do cliente: cabeçalhos do sistema, dos relatórios e dos e-mails informativos.', 'SIS', 1),
        ('EMPRESA_COR_SECUNDARIA', N'#A8A8A8', 'COR',
         N'Cor secundária do cliente (detalhes, linhas, textos de apoio).', 'SIS', 1),
        ('EMAIL_COR_ALERTA', N'#E65100', 'COR',
         N'Cor dos avisos de alerta (vencido, falha, divergência). Diferente da cor principal.', 'SIS', 1),
        ('EMAIL_COR_SUCESSO', N'#2E7D32', 'COR',
         N'Cor das confirmações (pagamento recebido, envio concluído).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
GO

PRINT N'Pacote 02b2 concluído sem erro.';
GO

SET NOEXEC OFF;
GO
