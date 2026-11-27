/*******************************************************************************
  Pacote      : 04h - agenda financeira e tela inicial: preferencias do usuario (P03, P06), acao VER_TOTAIS (P04), tela FIN_AGENDA, agenda (resumo, calendario, lista); banco continua 2.6 ate a publicacao
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 27/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04g5 já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/local/04h1_Habilitar_Agenda_LOCAL.sql e sql/testes/FIN/04h_Homologacao_Agenda.sql.
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
    v1.5 (26/11/2026) - Etapa 04f2c (P27): PENDENCIA (incluir, resolver e
                        reabrir pendências dos lançamentos).
    v1.6 (26/11/2026) - Etapa 04g: LIBERAR_PENDENCIA (baixar parcela com
                        pendência que bloqueia, com justificativa) e
                        DESCONTO_LIMITE (desconto na baixa acima do
                        limite do parâmetro, com motivo).
    v1.7 (27/11/2026) - Etapa 04g2: AJUSTE_CAIXA (gerar o movimento de
                        ajuste da diferença no fechamento de caixa).
    v1.8 (27/11/2026) - Etapa 04h1 (P04): VER_TOTAIS (ver os totais D/C/Saldo
                        e o saldo previsto na tela inicial).
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
        ('LANCAR_RETROATIVO', N'Lançar fora da trava de datas (com motivo)', 200),
        ('PENDENCIA',        N'Pendências (incluir, resolver, reabrir)', 210),
        ('LIBERAR_PENDENCIA', N'Baixar com pendência que bloqueia (com justificativa)', 220),
        ('DESCONTO_LIMITE', N'Desconto na baixa acima do limite (com motivo)', 230),
        ('AJUSTE_CAIXA',     N'Ajustar a diferença no fechamento de caixa', 240),
        ('VER_TOTAIS',       N'Ver totais e saldos (tela inicial)', 250)
     ) v (CODIGO, NOME, ORDEM)
WHERE NOT EXISTS (SELECT 1 FROM SIS.Acao a WHERE a.CODIGO = v.CODIGO);
GO

UPDATE a
   SET a.NOME = N'Excluir (vai para a lixeira) / cancelar', a.DT_ALTERACAO = SYSDATETIME(), a.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Acao a
WHERE a.CODIGO = 'EXCLUIR' AND a.NOME = N'Excluir / cancelar registro';
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Preferencia.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Preferencia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Catálogo das preferências que cada usuário pode escolher para
                si (tela Preferências; P03 e P06): como a tela inicial abre,
                período padrão, tema claro/escuro etc. Cada preferência tem o
                seu padrão num parâmetro (CHAVE_PARAMETRO em SIS.Parametro),
                que a administradora muda pela tela Parâmetros de uso; o
                usuário que não escolheu nada segue o padrão. TIPO e OPCOES
                seguem as mesmas regras de SIS.Parametro. Criadas só por carga
                (Carga_SIS_Preferencia.sql), nunca por tela.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Preferencia]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Preferencia]
    (
        ID_PREFERENCIA     INT            IDENTITY(1,1) NOT NULL,
        CODIGO             VARCHAR(40)    NOT NULL,
        NOME               NVARCHAR(80)   NOT NULL,
        DESCRICAO          NVARCHAR(400)  NOT NULL CONSTRAINT DF_Preferencia_DESCRICAO       DEFAULT (N''),
        GRUPO              NVARCHAR(60)   NOT NULL,
        TIPO               VARCHAR(10)    NOT NULL CONSTRAINT DF_Preferencia_TIPO            DEFAULT ('TEXTO'),
        OPCOES             NVARCHAR(400)  NOT NULL CONSTRAINT DF_Preferencia_OPCOES          DEFAULT (N''),
        VALOR_MINIMO       INT            NULL,
        VALOR_MAXIMO       INT            NULL,
        CHAVE_PARAMETRO    VARCHAR(60)    NOT NULL,
        ORDEM              SMALLINT       NOT NULL CONSTRAINT DF_Preferencia_ORDEM           DEFAULT (0),
        ATIVO              BIT            NOT NULL CONSTRAINT DF_Preferencia_ATIVO           DEFAULT (1),
        DT_CRIACAO         DATETIME2(0)   NOT NULL CONSTRAINT DF_Preferencia_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO    NVARCHAR(100)  NOT NULL CONSTRAINT DF_Preferencia_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO       DATETIME2(0)   NULL,
        USUARIO_ALTERACAO  NVARCHAR(100)  NULL,
        CONSTRAINT PK_Preferencia        PRIMARY KEY CLUSTERED (ID_PREFERENCIA),
        CONSTRAINT UQ_Preferencia_CODIGO UNIQUE (CODIGO),
        CONSTRAINT CK_Preferencia_TIPO   CHECK (TIPO IN ('TEXTO', 'INTEIRO', 'SN'))
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Usuario_Preferencia.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Usuario_Preferencia]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : O que cada usuário escolheu para si em cada preferência do
                catálogo SIS.Preferencia (P03 e P06). Sem linha = segue o
                padrão (parâmetro da preferência). VALOR no formato canônico
                do TIPO (SN = 'S'/'N'; INTEIRO sem separador; opção em
                maiúsculas). Preferência do próprio usuário, não dado do
                negócio: só ele grava (SIS_Preferencia_Gravar), sem lixeira e
                sem auditoria (como SIS.Filtro_Salvo).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Usuario_Preferencia]', N'U') IS NULL
BEGIN
    CREATE TABLE [SIS].[Usuario_Preferencia]
    (
        ID_USUARIO_PREFERENCIA INT            IDENTITY(1,1) NOT NULL,
        ID_USUARIO             INT            NOT NULL,
        ID_PREFERENCIA         INT            NOT NULL,
        VALOR                  NVARCHAR(400)  NOT NULL,
        DT_CRIACAO             DATETIME2(0)   NOT NULL CONSTRAINT DF_Usuario_Preferencia_DT_CRIACAO      DEFAULT (SYSDATETIME()),
        USUARIO_CRIACAO        NVARCHAR(100)  NOT NULL CONSTRAINT DF_Usuario_Preferencia_USUARIO_CRIACAO DEFAULT (ISNULL(CONVERT(NVARCHAR(100), SESSION_CONTEXT(N'USUARIO')), SUSER_SNAME())),
        DT_ALTERACAO           DATETIME2(0)   NULL,
        USUARIO_ALTERACAO      NVARCHAR(100)  NULL,
        CONSTRAINT PK_Usuario_Preferencia            PRIMARY KEY CLUSTERED (ID_USUARIO_PREFERENCIA),
        CONSTRAINT UQ_Usuario_Preferencia            UNIQUE (ID_USUARIO, ID_PREFERENCIA),
        CONSTRAINT FK_Usuario_Preferencia_Usuario    FOREIGN KEY (ID_USUARIO)     REFERENCES [SIS].[Usuario] (ID_USUARIO),
        CONSTRAINT FK_Usuario_Preferencia_Preferencia FOREIGN KEY (ID_PREFERENCIA) REFERENCES [SIS].[Preferencia] (ID_PREFERENCIA)
    );
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Preferencia_Valor.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Preferencia_Valor]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Valor que vale de uma preferência para o usuário: o que ele
                escolheu (SIS.Usuario_Preferencia), senão o padrão (parâmetro
                da preferência), senão ''. Nunca devolve NULL (regra 8).
                Usada uma vez por chamada (fora de consultas grandes).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Preferencia_Valor] (@IdUsuario INT, @Codigo VARCHAR(40))
RETURNS NVARCHAR(400)
AS
BEGIN
    DECLARE @Valor NVARCHAR(400);

    SELECT @Valor = ISNULL(up.VALOR, pa.VALOR)
    FROM SIS.Preferencia p WITH (NOLOCK)
    LEFT JOIN SIS.Parametro pa WITH (NOLOCK) ON pa.CHAVE = p.CHAVE_PARAMETRO
    LEFT JOIN SIS.Usuario_Preferencia up WITH (NOLOCK) ON up.ID_PREFERENCIA = p.ID_PREFERENCIA AND up.ID_USUARIO = @IdUsuario
    WHERE p.CODIGO = @Codigo;

    RETURN ISNULL(@Valor, N'');
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Preferencia_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Preferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Preferências do usuário logado (tela Preferências e abertura
                da tela inicial; P03 e P06): uma linha por preferência ativa
                do catálogo, com o padrão (valor do parâmetro da preferência),
                o que o usuário escolheu e o valor que vale (VALOR = escolha
                do usuário, senão o padrão). Qualquer usuário ativo vê as
                próprias; ninguém vê as de outro. @Grupo filtra pelo GRUPO.
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Preferencia_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Preferencia_Listar]
    @IdUsuario  INT,
    @Grupo      NVARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Preferencia_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Usuário';

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
            THROW 50001, N'Usuário não encontrado ou desativado.', 1;

        SET @Grupo = NULLIF(LTRIM(RTRIM(ISNULL(@Grupo, N''))), N'');

        SET @EtapaAtual = 'Consulta';
        SELECT p.CODIGO,
               p.NOME,
               p.DESCRICAO,
               p.GRUPO,
               p.TIPO,
               p.OPCOES,
               ISNULL(p.VALOR_MINIMO, 0)                                          AS VALOR_MINIMO,
               ISNULL(p.VALOR_MAXIMO, 0)                                          AS VALOR_MAXIMO,
               CAST(ISNULL(pa.VALOR, N'') AS NVARCHAR(400))                       AS VALOR_PADRAO,
               CAST(ISNULL(up.VALOR, N'') AS NVARCHAR(400))                       AS VALOR_USUARIO,
               CAST(ISNULL(up.VALOR, ISNULL(pa.VALOR, N'')) AS NVARCHAR(400))     AS VALOR,
               CAST(CASE WHEN up.ID_USUARIO_PREFERENCIA IS NULL THEN 0 ELSE 1 END AS BIT) AS PERSONALIZADA,
               p.ORDEM
        FROM SIS.Preferencia p WITH (NOLOCK)
        LEFT JOIN SIS.Parametro pa WITH (NOLOCK) ON pa.CHAVE = p.CHAVE_PARAMETRO
        LEFT JOIN SIS.Usuario_Preferencia up WITH (NOLOCK) ON up.ID_PREFERENCIA = p.ID_PREFERENCIA AND up.ID_USUARIO = @IdUsuario
        WHERE p.ATIVO = 1
          AND (@Grupo IS NULL OR p.GRUPO = @Grupo)
        ORDER BY p.GRUPO, p.ORDEM, p.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar as preferências. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Preferencia_Gravar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Preferencia_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Grava as preferências do usuário logado (tela Preferências;
                P03 e P06), várias de uma vez:
                  @Preferencias = '[{"codigo":"TEMA","valor":"ESCURO"},
                                    {"codigo":"INICIO_VISAO","valor":""}]'
                Valor vazio = volta ao padrão (apaga a escolha). Confere cada
                valor pelo TIPO, pelas OPCOES e pela faixa (VALOR_MINIMO /
                VALOR_MAXIMO) do catálogo; um valor inválido recusa tudo
                (tudo-ou-nada). Só o próprio usuário grava as dele.
                Resposta (regra 18): SUCESSO, MENSAGEM, QTD_GRAVADAS.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Preferencia_Gravar @IdUsuario = 2, @Preferencias = N'[{"codigo":"TEMA","valor":"ESCURO"}]';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Preferencia_Gravar]
    @IdUsuario     INT,
    @Preferencias  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Preferencia_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Recusa     NVARCHAR(400);
    DECLARE @Qtd        INT = 0;

    DECLARE @Itens TABLE
    (
        CODIGO          VARCHAR(40)   NOT NULL,
        VALOR           NVARCHAR(400) NOT NULL,
        ID_PREFERENCIA  INT           NULL,
        NOME            NVARCHAR(80)  NULL,
        TIPO            VARCHAR(10)   NULL,
        OPCOES          NVARCHAR(400) NULL,
        VALOR_MINIMO    INT           NULL,
        VALOR_MAXIMO    INT           NULL
    );

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Usuário não encontrado ou desativado.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;
        SET @Preferencias = LTRIM(RTRIM(ISNULL(@Preferencias, N'')));
        IF @Preferencias = N'' OR ISJSON(@Preferencias) = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Nenhuma preferência informada.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;

        INSERT INTO @Itens (CODIGO, VALOR)
        SELECT UPPER(LTRIM(RTRIM(ISNULL(j.codigo, '')))), LTRIM(RTRIM(ISNULL(j.valor, N'')))
        FROM OPENJSON(@Preferencias) WITH (codigo VARCHAR(40) '$.codigo', valor NVARCHAR(400) '$.valor') j;

        IF NOT EXISTS (SELECT 1 FROM @Itens)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Nenhuma preferência informada.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;
        IF EXISTS (SELECT 1 FROM @Itens GROUP BY CODIGO HAVING COUNT(*) > 1)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'A mesma preferência veio mais de uma vez.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;

        UPDATE i
           SET i.ID_PREFERENCIA = p.ID_PREFERENCIA, i.NOME = p.NOME, i.TIPO = p.TIPO, i.OPCOES = p.OPCOES,
               i.VALOR_MINIMO = p.VALOR_MINIMO, i.VALOR_MAXIMO = p.VALOR_MAXIMO,
               i.VALOR = CASE WHEN p.TIPO = 'SN' OR p.OPCOES <> N'' THEN UPPER(i.VALOR) ELSE i.VALOR END
        FROM @Itens i
        INNER JOIN SIS.Preferencia p ON p.CODIGO = i.CODIGO AND p.ATIVO = 1;

        -- Conferência de cada valor (vazio = volta ao padrão, sempre aceito)
        SELECT TOP 1 @Recusa =
               CASE WHEN i.ID_PREFERENCIA IS NULL THEN N'Preferência desconhecida: ' + CONVERT(NVARCHAR(40), i.CODIGO) + N'.'
                    WHEN i.VALOR = N'' THEN NULL
                    WHEN i.TIPO = 'SN' AND i.VALOR NOT IN (N'S', N'N') THEN N'"' + i.NOME + N'": escolha Sim ou Não.'
                    WHEN i.OPCOES <> N'' AND CHARINDEX(N';' + i.VALOR + N';', N';' + REPLACE(i.OPCOES, N' ', N'') + N';') = 0 THEN N'"' + i.NOME + N'": opção inválida.'
                    WHEN i.TIPO = 'INTEIRO' AND TRY_CONVERT(INT, i.VALOR) IS NULL THEN N'"' + i.NOME + N'": informe um número inteiro.'
                    WHEN i.TIPO = 'INTEIRO' AND i.VALOR_MINIMO IS NOT NULL AND TRY_CONVERT(INT, i.VALOR) < i.VALOR_MINIMO
                         THEN N'"' + i.NOME + N'": o menor valor aceito é ' + CONVERT(NVARCHAR(12), i.VALOR_MINIMO) + N'.'
                    WHEN i.TIPO = 'INTEIRO' AND i.VALOR_MAXIMO IS NOT NULL AND TRY_CONVERT(INT, i.VALOR) > i.VALOR_MAXIMO
                         THEN N'"' + i.NOME + N'": o maior valor aceito é ' + CONVERT(NVARCHAR(12), i.VALOR_MAXIMO) + N'.'
               END
        FROM @Itens i
        WHERE i.ID_PREFERENCIA IS NULL
           OR (i.VALOR <> N''
               AND (   (i.TIPO = 'SN' AND i.VALOR NOT IN (N'S', N'N'))
                    OR (i.OPCOES <> N'' AND CHARINDEX(N';' + i.VALOR + N';', N';' + REPLACE(i.OPCOES, N' ', N'') + N';') = 0)
                    OR (i.TIPO = 'INTEIRO' AND (TRY_CONVERT(INT, i.VALOR) IS NULL
                                                OR TRY_CONVERT(INT, i.VALOR) < ISNULL(i.VALOR_MINIMO, -2147483647)
                                                OR TRY_CONVERT(INT, i.VALOR) > ISNULL(i.VALOR_MAXIMO, 2147483647)))))
        ORDER BY i.CODIGO;

        IF @Recusa IS NOT NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS QTD_GRAVADAS;
            RETURN;
        END;

        UPDATE @Itens SET VALOR = CONVERT(NVARCHAR(400), TRY_CONVERT(INT, VALOR)) WHERE TIPO = 'INTEIRO' AND VALOR <> N'';

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        -- preferência do próprio usuário (só ele grava): sem disputa entre sessões
        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

            DELETE up
            FROM SIS.Usuario_Preferencia up
            INNER JOIN @Itens i ON i.ID_PREFERENCIA = up.ID_PREFERENCIA
            WHERE up.ID_USUARIO = @IdUsuario AND i.VALOR = N'';
            SET @Qtd = @@ROWCOUNT;

            UPDATE up
               SET up.VALOR = i.VALOR, up.DT_ALTERACAO = SYSDATETIME(), up.USUARIO_ALTERACAO = @Usuario
            FROM SIS.Usuario_Preferencia up
            INNER JOIN @Itens i ON i.ID_PREFERENCIA = up.ID_PREFERENCIA
            WHERE up.ID_USUARIO = @IdUsuario AND i.VALOR <> N'' AND up.VALOR <> i.VALOR;
            SET @Qtd = @Qtd + @@ROWCOUNT;

            INSERT INTO SIS.Usuario_Preferencia (ID_USUARIO, ID_PREFERENCIA, VALOR, USUARIO_CRIACAO)
            SELECT @IdUsuario, i.ID_PREFERENCIA, i.VALOR, ISNULL(@Usuario, N'')
            FROM @Itens i
            WHERE i.VALOR <> N''
              AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Preferencia x WHERE x.ID_USUARIO = @IdUsuario AND x.ID_PREFERENCIA = i.ID_PREFERENCIA);
            SET @Qtd = @Qtd + @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Preferências gravadas.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@Qtd AS INT) AS QTD_GRAVADAS;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível gravar as preferências. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(0 AS INT) AS QTD_GRAVADAS;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Preferencia.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Preferencia] e dos parâmetros dos padrões
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Preferências que cada usuário escolhe para si (P03 tela
                inicial e P06 tema, aprovados pelo Celso em 27/11/2026, etapa
                04h) e os parâmetros com o padrão de cada uma (nível 1: os dois
                administradores mudam pela tela Parâmetros de uso). Também o
                período máximo da agenda (AGENDA_PERIODO_MAX_DIAS) e de quanto
                em quanto tempo a tela inicial se atualiza sozinha
                (AGENDA_ATUALIZAR_MIN).
                Parâmetros: só insere o que falta (regra 39); NIVEL_MINIMO,
                OPCOES e DESCRICAO são da instalação e são acertados sempre.
                Catálogo: insere o que falta e acerta nome, descrição, grupo,
                tipo, opções, faixa e ordem (é da instalação, nunca do
                usuário); as escolhas dos usuários ficam intocadas.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
    v1.1 (27/11/2026) - AGENDA_ATUALIZAR_MIN (sugestão aprovada na 04h2).
    v1.2 (27/11/2026) - FONTE_TAMANHO e FONTE_TAMANHO_PADRAO (tamanho das letras
                        em todas as telas; pedido do Celso, 04h2e).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaParametro;
CREATE TABLE #CargaParametro
(
    CHAVE      VARCHAR(60)    NOT NULL,
    VALOR      NVARCHAR(400)  NOT NULL,
    TIPO       VARCHAR(10)    NOT NULL,
    DESCRICAO  NVARCHAR(400)  NOT NULL,
    MODULO     VARCHAR(10)    NOT NULL,
    OPCOES     NVARCHAR(400)  NOT NULL
);

INSERT INTO #CargaParametro (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, OPCOES)
VALUES
    ('INICIO_VISAO_PADRAO', N'CALENDARIO', 'TEXTO',
     N'Tela inicial: como abre para quem não escolheu nas Preferências (lista dos lançamentos ou calendário).', 'FIN', N'CALENDARIO;LISTA'),
    ('INICIO_PERIODO_PADRAO', N'MES', 'TEXTO',
     N'Tela inicial: período que abre para quem não escolheu nas Preferências.', 'FIN', N'SEMANA;QUINZENA;MES;BIMESTRE;TRIMESTRE;QUADRIMESTRE;ANO;ANOS'),
    ('INICIO_ANOS_PADRAO', N'2', 'INTEIRO',
     N'Tela inicial: quantos anos mostra quando o período é "Vários anos" (de 2 a 10).', 'FIN', N''),
    ('INICIO_INCLUI_REALIZADO_PADRAO', N'N', 'SN',
     N'Tela inicial: além do que está em aberto, mostra também o que já foi pago ou recebido (pelo vencimento).', 'FIN', N''),
    ('INICIO_SALDO_ACUMULADO_PADRAO', N'S', 'SN',
     N'Tela inicial: mostra o saldo previsto acumulado (saldo de hoje nas contas mais o que vence até cada dia). Só para quem pode ver os totais.', 'FIN', N''),
    ('AGENDA_PERIODO_MAX_DIAS', N'3700', 'INTEIRO',
     N'Tela inicial: período mais longo que a agenda aceita, em dias (3700 = cerca de 10 anos).', 'FIN', N''),
    ('AGENDA_ATUALIZAR_MIN', N'5', 'INTEIRO',
     N'Tela inicial: de quantos em quantos minutos ela se atualiza sozinha enquanto está aberta (0 = não atualiza sozinha).', 'FIN', N''),
    ('TEMA_PADRAO', N'SISTEMA', 'TEXTO',
     N'Tema das telas para quem não escolheu nas Preferências: seguir o Windows (claro ou escuro), sempre claro ou sempre escuro.', 'SIS', N'SISTEMA;CLARO;ESCURO'),
    ('FONTE_TAMANHO_PADRAO', N'NORMAL', 'TEXTO',
     N'Tamanho das letras das telas para quem não escolheu nas Preferências.', 'SIS', N'PEQUENA;NORMAL;GRANDE;MUITO_GRANDE');

INSERT INTO SIS.Parametro (CHAVE, VALOR, VALOR_PADRAO, TIPO, DESCRICAO, ID_MODULO, EDITAVEL_ADMIN, NIVEL_MINIMO, OPCOES)
SELECT c.CHAVE, c.VALOR, c.VALOR, c.TIPO, c.DESCRICAO, m.ID_MODULO, 1, 1, c.OPCOES
FROM #CargaParametro c
INNER JOIN SIS.Modulo m ON m.CODIGO = c.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = c.CHAVE);

UPDATE p
   SET p.NIVEL_MINIMO = 1, p.OPCOES = c.OPCOES, p.DESCRICAO = c.DESCRICAO, p.VALOR_PADRAO = c.VALOR
FROM SIS.Parametro p
INNER JOIN #CargaParametro c ON c.CHAVE = p.CHAVE
WHERE p.NIVEL_MINIMO <> 1 OR p.OPCOES <> c.OPCOES OR p.DESCRICAO <> c.DESCRICAO OR p.VALOR_PADRAO <> c.VALOR;

DROP TABLE IF EXISTS #CargaParametro;
GO

DROP TABLE IF EXISTS #CargaPreferencia;
CREATE TABLE #CargaPreferencia
(
    CODIGO           VARCHAR(40)    NOT NULL,
    NOME             NVARCHAR(80)   NOT NULL,
    DESCRICAO        NVARCHAR(400)  NOT NULL,
    GRUPO            NVARCHAR(60)   NOT NULL,
    TIPO             VARCHAR(10)    NOT NULL,
    OPCOES           NVARCHAR(400)  NOT NULL,
    VALOR_MINIMO     INT            NULL,
    VALOR_MAXIMO     INT            NULL,
    CHAVE_PARAMETRO  VARCHAR(60)    NOT NULL,
    ORDEM            SMALLINT       NOT NULL
);

INSERT INTO #CargaPreferencia (CODIGO, NOME, DESCRICAO, GRUPO, TIPO, OPCOES, VALOR_MINIMO, VALOR_MAXIMO, CHAVE_PARAMETRO, ORDEM)
VALUES
    ('INICIO_VISAO', N'Abrir a tela inicial em', N'Lista dos lançamentos, linha a linha, ou calendário com os totais de cada dia ou mês.',
     N'Tela inicial', 'TEXTO', N'CALENDARIO;LISTA', NULL, NULL, 'INICIO_VISAO_PADRAO', 10),
    ('INICIO_PERIODO', N'Período ao abrir', N'Período que a tela inicial mostra ao abrir. Dá para trocar na hora, na própria tela.',
     N'Tela inicial', 'TEXTO', N'SEMANA;QUINZENA;MES;BIMESTRE;TRIMESTRE;QUADRIMESTRE;ANO;ANOS', NULL, NULL, 'INICIO_PERIODO_PADRAO', 20),
    ('INICIO_ANOS', N'Quantos anos em "Vários anos"', N'Usado quando o período é "Vários anos".',
     N'Tela inicial', 'INTEIRO', N'', 2, 10, 'INICIO_ANOS_PADRAO', 30),
    ('INICIO_INCLUI_REALIZADO', N'Mostrar também o que já foi pago ou recebido', N'Sem esta opção, a agenda mostra só o que está em aberto (o saldo de cada parcela).',
     N'Tela inicial', 'SN', N'', NULL, NULL, 'INICIO_INCLUI_REALIZADO_PADRAO', 40),
    ('INICIO_SALDO_ACUMULADO', N'Mostrar o saldo previsto acumulado', N'Saldo de hoje nas contas mais o que vence até cada dia. Aparece só para quem pode ver os totais.',
     N'Tela inicial', 'SN', N'', NULL, NULL, 'INICIO_SALDO_ACUMULADO_PADRAO', 50),
    ('TEMA', N'Tema das telas', N'Seguir o Windows (claro ou escuro), sempre claro ou sempre escuro.',
     N'Aparência', 'TEXTO', N'SISTEMA;CLARO;ESCURO', NULL, NULL, 'TEMA_PADRAO', 10),
    ('FONTE_TAMANHO', N'Tamanho das letras', N'Aumenta ou diminui as letras (e o resto da tela junto) em todas as telas do sistema, só para você.',
     N'Aparência', 'TEXTO', N'PEQUENA;NORMAL;GRANDE;MUITO_GRANDE', NULL, NULL, 'FONTE_TAMANHO_PADRAO', 20);

INSERT INTO SIS.Preferencia (CODIGO, NOME, DESCRICAO, GRUPO, TIPO, OPCOES, VALOR_MINIMO, VALOR_MAXIMO, CHAVE_PARAMETRO, ORDEM, USUARIO_CRIACAO)
SELECT c.CODIGO, c.NOME, c.DESCRICAO, c.GRUPO, c.TIPO, c.OPCOES, c.VALOR_MINIMO, c.VALOR_MAXIMO, c.CHAVE_PARAMETRO, c.ORDEM, N'instalacao'
FROM #CargaPreferencia c
WHERE NOT EXISTS (SELECT 1 FROM SIS.Preferencia p WHERE p.CODIGO = c.CODIGO);

UPDATE p
   SET p.NOME = c.NOME, p.DESCRICAO = c.DESCRICAO, p.GRUPO = c.GRUPO, p.TIPO = c.TIPO, p.OPCOES = c.OPCOES,
       p.VALOR_MINIMO = c.VALOR_MINIMO, p.VALOR_MAXIMO = c.VALOR_MAXIMO, p.CHAVE_PARAMETRO = c.CHAVE_PARAMETRO, p.ORDEM = c.ORDEM,
       p.DT_ALTERACAO = SYSDATETIME(), p.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Preferencia p
INNER JOIN #CargaPreferencia c ON c.CODIGO = p.CODIGO
WHERE p.NOME <> c.NOME OR p.DESCRICAO <> c.DESCRICAO OR p.GRUPO <> c.GRUPO OR p.TIPO <> c.TIPO OR p.OPCOES <> c.OPCOES
   OR ISNULL(p.VALOR_MINIMO, -1) <> ISNULL(c.VALOR_MINIMO, -1) OR ISNULL(p.VALOR_MAXIMO, -1) <> ISNULL(c.VALOR_MAXIMO, -1)
   OR p.CHAVE_PARAMETRO <> c.CHAVE_PARAMETRO OR p.ORDEM <> c.ORDEM;

DROP TABLE IF EXISTS #CargaPreferencia;
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
    v1.2 (26/11/2026) - Etapa 04f2c (P27): tela "Tipos de pendência"
                        (FIN_PENDENCIA_TIPO, nasce desabilitada); ação PENDENCIA
                        nas telas de pagar e receber, dada (só quando nasce) a
                        quem já tinha ALTERAR; FIN.Lancamento_Pendencia nas
                        tabelas das duas telas.
    v1.3 (26/11/2026) - Etapa 04g: ações BAIXAR e ESTORNAR nas telas de
                        pagar e receber, dadas (só quando nascem) a quem já
                        tinha ALTERAR; LIBERAR_PENDENCIA e
                        DESCONTO_LIMITE nascem sem ninguém (os
                        administradores dão pela tela Perfis e permissões);
                        FIN.Baixa nas tabelas das duas telas.
    v1.4 (27/11/2026) - Etapa 04g2: telas do módulo Bancos "Transferências"
                        (BANCO_TRANSFERENCIA), "Extrato e saldos"
                        (BANCO_EXTRATO) e "Fechamento de caixa"
                        (BANCO_CAIXA), nascem desabilitadas. Ações do dia a
                        dia (ver, incluir, estornar, exportar, fechar o
                        caixa) dadas, só quando nascem, a quem já tinha
                        ALTERAR em Contas a pagar; LANCAR_RETROATIVO,
                        REABRIR e AJUSTE_CAIXA nascem sem ninguém.
    v1.5 (27/11/2026) - Etapa 04h1 (P03, P04): tela "Agenda financeira"
                        (FIN_AGENDA = a tela inicial, index.html), nasce
                        desabilitada, com VER, EXPORTAR e VER_TOTAIS. Só
                        quando nascem: VER para quem já via Contas a pagar
                        ou a receber e EXPORTAR para quem já exportava
                        numa delas (perfil e permissão individual);
                        VER_TOTAIS nasce sem ninguém (P04: dada pelos
                        administradores).
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

-- Etapa 04f2c (P27): tabelas das telas de pagar e receber
UPDATE i
   SET i.TABELAS_DA_TELA = 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia', i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
  AND i.TABELAS_DA_TELA <> 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia';
GO

-- Tela Financeiro › Tipos de pendência
INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_PENDENCIA_TIPO', N'Tipos de pendência', 'TELA', 'fin/pendencia-tipos.html', 80, 0, 0, 'FIN.Pendencia_Tipo'
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_PENDENCIA_TIPO');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('INCLUIR'), ('ALTERAR'), ('EXCLUIR'), ('DESATIVAR'), ('EXPORTAR'), ('DESFAZER')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'FIN_PENDENCIA_TIPO'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- Ação PENDENCIA nas telas de pagar e receber: quem tinha ALTERAR recebe, só quando a ação nasce
DECLARE @NovosPendencia TABLE (ID_ITEM_ACAO INT NOT NULL, ID_ITEM INT NOT NULL);
DECLARE @IdAlterar INT = (SELECT a.ID_ACAO FROM SIS.Acao a WHERE a.CODIGO = 'ALTERAR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, inserted.ID_ITEM INTO @NovosPendencia (ID_ITEM_ACAO, ID_ITEM)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) v (ITEM)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = 'PENDENCIA'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosPendencia n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosPendencia n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);
GO

-- Etapa 04g: baixa e estorno nas telas de pagar e receber
UPDATE i
   SET i.TABELAS_DA_TELA = 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia,FIN.Baixa', i.DT_ALTERACAO = SYSDATETIME(), i.USUARIO_ALTERACAO = N'instalacao'
FROM SIS.Item i
WHERE i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
  AND i.TABELAS_DA_TELA <> 'FIN.Lancamento,FIN.Parcela,FIN.Lancamento_Pendencia,FIN.Baixa';
GO

-- BAIXAR e ESTORNAR: quem tinha ALTERAR recebe, só quando a ação nasce na tela
DECLARE @NovosBaixa TABLE (ID_ITEM_ACAO INT NOT NULL, ID_ITEM INT NOT NULL, ACAO VARCHAR(20) NOT NULL);
DECLARE @IdAlterar INT = (SELECT a.ID_ACAO FROM SIS.Acao a WHERE a.CODIGO = 'ALTERAR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, inserted.ID_ITEM, '' INTO @NovosBaixa (ID_ITEM_ACAO, ID_ITEM, ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('BAIXAR' AS VARCHAR(20))), ('ESTORNAR')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT DISTINCT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosBaixa n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT DISTINCT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosBaixa n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM = n.ID_ITEM AND ia.ID_ACAO = @IdAlterar
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = ia.ID_ITEM_ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);
GO

-- LIBERAR_PENDENCIA e DESCONTO_LIMITE: nascem sem ninguém
INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('FIN_PAGAR' AS VARCHAR(40))), ('FIN_RECEBER')) t (ITEM)
CROSS JOIN (VALUES (CAST('LIBERAR_PENDENCIA' AS VARCHAR(20))), ('DESCONTO_LIMITE')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = t.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
GO

-- 04g2: telas do módulo Bancos
INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, v.CODIGO, v.NOME, 'TELA', v.CAMINHO, v.ORDEM, 0, 0, v.TABELAS
FROM (VALUES (CAST('BANCO_TRANSFERENCIA' AS VARCHAR(40)), CAST(N'Transferências' AS NVARCHAR(80)), CAST('banco/transferencias.html' AS VARCHAR(200)), CAST(30 AS SMALLINT), CAST('FIN.Transferencia,BANCO.Movimento' AS VARCHAR(400))),
             ('BANCO_EXTRATO', N'Extrato e saldos',    'banco/extrato.html', 40, 'BANCO.Movimento'),
             ('BANCO_CAIXA',   N'Fechamento de caixa', 'banco/caixa.html',   50, 'BANCO.Caixa_Fechamento')) v (CODIGO, NOME, CAMINHO, ORDEM, TABELAS)
INNER JOIN SIS.Modulo m ON m.CODIGO = 'BANCO'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = v.CODIGO);
GO

DECLARE @NovosBanco TABLE (ID_ITEM_ACAO INT NOT NULL, ITEM VARCHAR(40) NULL, ACAO VARCHAR(20) NULL);
DECLARE @IdAlterarPagar INT = (SELECT ia.ID_ITEM_ACAO FROM SIS.Item_Acao ia
                               INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM AND i.CODIGO = 'FIN_PAGAR'
                               INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO AND a.CODIGO = 'ALTERAR');

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, NULL, NULL INTO @NovosBanco (ID_ITEM_ACAO, ITEM, ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('BANCO_TRANSFERENCIA' AS VARCHAR(40)), CAST('VER' AS VARCHAR(20))), ('BANCO_TRANSFERENCIA', 'INCLUIR'),
             ('BANCO_TRANSFERENCIA', 'ESTORNAR'), ('BANCO_TRANSFERENCIA', 'EXPORTAR'), ('BANCO_TRANSFERENCIA', 'LANCAR_RETROATIVO'),
             ('BANCO_EXTRATO', 'VER'), ('BANCO_EXTRATO', 'EXPORTAR'),
             ('BANCO_CAIXA', 'VER'), ('BANCO_CAIXA', 'INCLUIR'), ('BANCO_CAIXA', 'EXPORTAR'), ('BANCO_CAIXA', 'REABRIR'),
             ('BANCO_CAIXA', 'AJUSTE_CAIXA')) v (ITEM, ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = v.ITEM
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

UPDATE n SET n.ITEM = i.CODIGO, n.ACAO = a.CODIGO
FROM @NovosBanco n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = n.ID_ITEM_ACAO
INNER JOIN SIS.Item i ON i.ID_ITEM = ia.ID_ITEM
INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO;

DELETE FROM @NovosBanco WHERE ACAO IN ('LANCAR_RETROATIVO', 'REABRIR', 'AJUSTE_CAIXA');

INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosBanco n
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = @IdAlterarPagar
WHERE NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, up.TIPO, N'instalacao'
FROM @NovosBanco n
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = @IdAlterarPagar
WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);
GO

-- 04h1: tela inicial = Agenda financeira (P03, P04)
INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, NULL, 'FIN_AGENDA', N'Agenda financeira', 'TELA', 'index.html', 5, 0, 0, ''
FROM SIS.Modulo m
WHERE m.CODIGO = 'FIN'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'FIN_AGENDA');
GO

DECLARE @NovosAgenda TABLE (ID_ITEM_ACAO INT NOT NULL, ACAO VARCHAR(20) NULL);

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
OUTPUT inserted.ID_ITEM_ACAO, NULL INTO @NovosAgenda (ID_ITEM_ACAO, ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM (VALUES (CAST('VER' AS VARCHAR(20))), ('EXPORTAR'), ('VER_TOTAIS')) v (ACAO)
INNER JOIN SIS.Item i ON i.CODIGO = 'FIN_AGENDA'
INNER JOIN SIS.Acao a ON a.CODIGO = v.ACAO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);

UPDATE n SET n.ACAO = a.CODIGO
FROM @NovosAgenda n
INNER JOIN SIS.Item_Acao ia ON ia.ID_ITEM_ACAO = n.ID_ITEM_ACAO
INNER JOIN SIS.Acao a ON a.ID_ACAO = ia.ID_ACAO;

-- VER e EXPORTAR: para quem já tinha a mesma ação em Contas a pagar ou a receber (só quando nascem)
INSERT INTO SIS.Perfil_Permissao (ID_PERFIL, ID_ITEM_ACAO, USUARIO_CRIACAO)
SELECT DISTINCT pp.ID_PERFIL, n.ID_ITEM_ACAO, N'instalacao'
FROM @NovosAgenda n
INNER JOIN SIS.Acao a ON a.CODIGO = n.ACAO
INNER JOIN SIS.Item_Acao iaf ON iaf.ID_ACAO = a.ID_ACAO
INNER JOIN SIS.Item i ON i.ID_ITEM = iaf.ID_ITEM AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
INNER JOIN SIS.Perfil_Permissao pp ON pp.ID_ITEM_ACAO = iaf.ID_ITEM_ACAO
WHERE n.ACAO IN ('VER', 'EXPORTAR')
  AND NOT EXISTS (SELECT 1 FROM SIS.Perfil_Permissao x WHERE x.ID_PERFIL = pp.ID_PERFIL AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO);

INSERT INTO SIS.Usuario_Permissao (ID_USUARIO, ID_ITEM_ACAO, TIPO, USUARIO_CRIACAO)
SELECT up.ID_USUARIO, n.ID_ITEM_ACAO, 'C', N'instalacao'
FROM @NovosAgenda n
INNER JOIN SIS.Acao a ON a.CODIGO = n.ACAO
INNER JOIN SIS.Item_Acao iaf ON iaf.ID_ACAO = a.ID_ACAO
INNER JOIN SIS.Item i ON i.ID_ITEM = iaf.ID_ITEM AND i.CODIGO IN ('FIN_PAGAR', 'FIN_RECEBER')
INNER JOIN SIS.Usuario_Permissao up ON up.ID_ITEM_ACAO = iaf.ID_ITEM_ACAO AND up.TIPO = 'C'
WHERE n.ACAO IN ('VER', 'EXPORTAR')
  AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Permissao x WHERE x.ID_USUARIO = up.ID_USUARIO AND x.ID_ITEM_ACAO = n.ID_ITEM_ACAO)
GROUP BY up.ID_USUARIO, n.ID_ITEM_ACAO;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.fn_FIN_Agenda_Base.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[fn_FIN_Agenda_Base]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Fonte única do que entra na agenda da tela inicial (P03,
                etapa 04h1): as parcelas de contas a pagar (D) e a receber (C)
                com vencimento entre @De e @Ate, de lançamentos ativos e fora
                da lixeira, só dos tipos que o usuário vê (@VerPagar /
                @VerReceber, conferidos por quem chama).
                  - em aberto (ABERTA/PARCIAL): entra o saldo da parcela;
                  - @Realizado = 1: entra também o já pago/recebido
                    (VALOR_BAIXADO, inclusive das parcelas PAGA).
                Lançamento de previsão entra e vem marcado (PREVISAO).
                Parcela cancelada nunca entra. Em linha (inline), para entrar
                no plano de quem chama (lição da 04f2c).
                VALOR_D / VALOR_C: o valor da agenda no lado certo (o outro
                fica 0). ABERTO_D / ABERTO_C: só o que está em aberto (base do
                saldo previsto acumulado).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [FIN].[fn_FIN_Agenda_Base]
(
    @De         DATE,
    @Ate        DATE,
    @VerPagar   BIT,
    @VerReceber BIT,
    @Realizado  BIT,
    @IdEmpresa  INT
)
RETURNS TABLE
AS
RETURN
    SELECT x.ID_PARCELA, x.ID_LANCAMENTO, x.TIPO, x.DT_VENCIMENTO, x.SITUACAO, x.PREVISAO, x.ID_EMPRESA,
           x.VALOR, x.ABERTO, x.REALIZADO,
           CAST(x.ABERTO + x.REALIZADO AS DECIMAL(18,2))                                     AS VALOR_AGENDA,
           CAST(CASE WHEN x.TIPO = 'P' THEN x.ABERTO + x.REALIZADO ELSE 0 END AS DECIMAL(18,2)) AS VALOR_D,
           CAST(CASE WHEN x.TIPO = 'R' THEN x.ABERTO + x.REALIZADO ELSE 0 END AS DECIMAL(18,2)) AS VALOR_C,
           CAST(CASE WHEN x.TIPO = 'P' THEN x.ABERTO ELSE 0 END AS DECIMAL(18,2))            AS ABERTO_D,
           CAST(CASE WHEN x.TIPO = 'R' THEN x.ABERTO ELSE 0 END AS DECIMAL(18,2))            AS ABERTO_C
    FROM (SELECT p.ID_PARCELA, p.ID_LANCAMENTO, l.TIPO, p.DT_VENCIMENTO, p.SITUACAO, l.PREVISAO, l.ID_EMPRESA, p.VALOR,
                 CAST(CASE WHEN p.SITUACAO IN ('ABERTA', 'PARCIAL') THEN ISNULL(p.SALDO, 0) ELSE 0 END AS DECIMAL(18,2)) AS ABERTO,
                 CAST(CASE WHEN ISNULL(@Realizado, 0) = 1 THEN ISNULL(p.VALOR_BAIXADO, 0) ELSE 0 END AS DECIMAL(18,2)) AS REALIZADO
          FROM FIN.Parcela p WITH (NOLOCK)
          INNER JOIN FIN.Lancamento l WITH (NOLOCK) ON l.ID_LANCAMENTO = p.ID_LANCAMENTO
          WHERE p.DT_VENCIMENTO >= @De
            AND p.DT_VENCIMENTO <= @Ate
            AND (p.SITUACAO IN ('ABERTA', 'PARCIAL') OR (ISNULL(@Realizado, 0) = 1 AND p.SITUACAO = 'PAGA'))
            AND l.DT_EXCLUSAO IS NULL
            AND l.SITUACAO = 'ATIVO'
            AND ((l.TIPO = 'P' AND ISNULL(@VerPagar, 0) = 1) OR (l.TIPO = 'R' AND ISNULL(@VerReceber, 0) = 1))
            AND (@IdEmpresa IS NULL OR l.ID_EMPRESA = @IdEmpresa)) x
    WHERE x.ABERTO + x.REALIZADO <> 0;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Agenda_Resumo.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Agenda_Resumo]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Barra de totais e quadros do topo da tela inicial (agenda
                financeira, P03/P04, etapa 04h1), para o período @De a @Ate:
                  - o que o usuário pode fazer (ver pagar e receber, ver
                    totais, exportar, atalhos: incluir conta a pagar e a
                    receber, extrato, fechamento de caixa, transferência);
                  - quantidade e totais D (a pagar), C (a receber) e Saldo
                    (C - D) do período, e o realizado quando a opção está
                    ligada;
                  - "Em atraso": parcelas em aberto vencidas antes de hoje
                    (fora do período escolhido), quantidade e valor;
                  - saldo de hoje nas contas (ativas e que mostram saldo) e
                    saldo previsto no fim do período (saldo de hoje + o que
                    está em aberto de hoje até @Ate; não conta o atraso).
                P04: sem VER_TOTAIS em FIN_AGENDA, todos os valores somados
                voltam NULL (as quantidades continuam). @IncluiRealizado e
                @SaldoAcumulado NULL = preferência do usuário.
                Permissão: VER em FIN_AGENDA. Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).
    v1.1 (27/11/2026) - PERIODO_MAX_DIAS e ATUALIZAR_MINUTOS (parâmetro
                        AGENDA_ATUALIZAR_MIN), para a tela (etapa 04h2).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Agenda_Resumo @IdUsuario = 2, @De = '2026-11-01', @Ate = '2026-11-30';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Agenda_Resumo]
    @IdUsuario        INT,
    @De               DATE,
    @Ate              DATE,
    @IdEmpresa        INT = NULL,
    @IncluiRealizado  BIT = NULL,
    @SaldoAcumulado   BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Agenda_Resumo]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje         DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @MaxDias      INT;
    DECLARE @VerPagar     BIT;
    DECLARE @VerReceber   BIT;
    DECLARE @VerTotais    BIT;
    DECLARE @SaldoContas  DECIMAL(18,2) = NULL;
    DECLARE @AbertoFuturo DECIMAL(18,2) = 0;
    DECLARE @AtrasoQtdP   INT = 0, @AtrasoQtdR INT = 0;
    DECLARE @AtrasoD      DECIMAL(18,2) = 0, @AtrasoC DECIMAL(18,2) = 0;
    DECLARE @Ontem        DATE;
    DECLARE @AtualizarMin INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a agenda financeira.', 1;

        SET @EtapaAtual = 'Período';
        IF @De IS NULL OR @Ate IS NULL
            THROW 50001, N'Informe o período.', 1;
        IF @Ate < @De
            THROW 50001, N'A data final não pode ser antes da inicial.', 1;
        SET @MaxDias = ISNULL(SIS.fn_SIS_Parametro_Inteiro('AGENDA_PERIODO_MAX_DIAS'), 3700);
        IF @MaxDias NOT BETWEEN 31 AND 7400 SET @MaxDias = 3700;
        IF DATEDIFF(DAY, @De, @Ate) + 1 > @MaxDias
            THROW 50001, N'Período longo demais para a agenda. Escolha um período menor.', 1;

        SET @AtualizarMin = ISNULL(SIS.fn_SIS_Parametro_Inteiro('AGENDA_ATUALIZAR_MIN'), 5);
        IF @AtualizarMin NOT BETWEEN 0 AND 240 SET @AtualizarMin = 5;

        SET @EtapaAtual = 'Permissões e preferências';
        SET @VerPagar   = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VerReceber = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        SET @VerTotais  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER_TOTAIS');
        IF @IncluiRealizado IS NULL
            SET @IncluiRealizado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_INCLUI_REALIZADO') = N'S' THEN 1 ELSE 0 END;
        IF @SaldoAcumulado IS NULL
            SET @SaldoAcumulado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_SALDO_ACUMULADO') = N'S' THEN 1 ELSE 0 END;
        IF @VerTotais = 0 SET @SaldoAcumulado = 0;

        SET @EtapaAtual = 'Em atraso';
        SET @Ontem = DATEADD(DAY, -1, @Hoje);
        SELECT @AtrasoQtdP = ISNULL(SUM(CASE WHEN b.TIPO = 'P' THEN 1 ELSE 0 END), 0),
               @AtrasoQtdR = ISNULL(SUM(CASE WHEN b.TIPO = 'R' THEN 1 ELSE 0 END), 0),
               @AtrasoD    = ISNULL(SUM(b.ABERTO_D), 0),
               @AtrasoC    = ISNULL(SUM(b.ABERTO_C), 0)
        FROM FIN.fn_FIN_Agenda_Base('19000101', @Ontem, @VerPagar, @VerReceber, 0, @IdEmpresa) b
        OPTION (RECOMPILE);

        IF @SaldoAcumulado = 1
        BEGIN
            SET @EtapaAtual = 'Saldo das contas';
            SELECT @SaldoContas = ISNULL(SUM(s.SALDO), 0)
            FROM BANCO.Conta c WITH (NOLOCK)
            CROSS APPLY BANCO.fn_BANCO_Conta_Saldo(c.ID_CONTA, @Hoje) s
            WHERE c.ATIVO = 1
              AND c.MOSTRA_SALDO = 1
              AND c.DT_EXCLUSAO IS NULL
              AND s.TEM_SALDO = 1
              AND (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa);

            -- saldo previsto no fim do período: o que está em aberto de hoje até @Ate
            IF @Ate >= @Hoje
                SELECT @AbertoFuturo = ISNULL(SUM(b.ABERTO_C - b.ABERTO_D), 0)
                FROM FIN.fn_FIN_Agenda_Base(@Hoje, @Ate, @VerPagar, @VerReceber, 0, @IdEmpresa) b
                OPTION (RECOMPILE);
        END;

        SET @EtapaAtual = 'Consulta';
        SELECT @De                                                                          AS DE,
               @Ate                                                                         AS ATE,
               @Hoje                                                                        AS HOJE,
               @MaxDias                                                                     AS PERIODO_MAX_DIAS,
               @AtualizarMin                                                                AS ATUALIZAR_MINUTOS,
               @VerPagar                                                                    AS VER_PAGAR,
               @VerReceber                                                                  AS VER_RECEBER,
               @VerTotais                                                                   AS VER_TOTAIS,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'EXPORTAR')               AS PODE_EXPORTAR,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'INCLUIR')                 AS PODE_INCLUIR_PAGAR,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'INCLUIR')               AS PODE_INCLUIR_RECEBER,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_EXTRATO', 'VER')                 AS PODE_EXTRATO,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CAIXA', 'VER')                   AS PODE_CAIXA,
               SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_TRANSFERENCIA', 'INCLUIR')       AS PODE_TRANSFERIR,
               CAST(ISNULL(@IncluiRealizado, 0) AS BIT)                                     AS INCLUI_REALIZADO,
               CAST(ISNULL(@SaldoAcumulado, 0) AS BIT)                                      AS SALDO_ACUMULADO,
               CAST(ISNULL(SUM(CASE WHEN b.TIPO = 'P' THEN 1 ELSE 0 END), 0) AS INT)        AS QTD_PAGAR,
               CAST(ISNULL(SUM(CASE WHEN b.TIPO = 'R' THEN 1 ELSE 0 END), 0) AS INT)        AS QTD_RECEBER,
               CAST(ISNULL(SUM(CASE WHEN b.PREVISAO = 1 THEN 1 ELSE 0 END), 0) AS INT)      AS QTD_PREVISAO,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(b.VALOR_D), 0) END AS DECIMAL(18,2))                 AS TOTAL_D,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(b.VALOR_C), 0) END AS DECIMAL(18,2))                 AS TOTAL_C,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(b.VALOR_C - b.VALOR_D), 0) END AS DECIMAL(18,2))     AS SALDO,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(CASE WHEN b.TIPO = 'P' THEN b.REALIZADO ELSE 0 END), 0) END AS DECIMAL(18,2)) AS REALIZADO_D,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(SUM(CASE WHEN b.TIPO = 'R' THEN b.REALIZADO ELSE 0 END), 0) END AS DECIMAL(18,2)) AS REALIZADO_C,
               CAST(ISNULL(@AtrasoQtdP, 0) AS INT)                                          AS ATRASO_QTD_PAGAR,
               CAST(ISNULL(@AtrasoQtdR, 0) AS INT)                                          AS ATRASO_QTD_RECEBER,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(@AtrasoD, 0) END AS DECIMAL(18,2)) AS ATRASO_D,
               CAST(CASE WHEN @VerTotais = 1 THEN ISNULL(@AtrasoC, 0) END AS DECIMAL(18,2)) AS ATRASO_C,
               CAST(CASE WHEN @SaldoAcumulado = 1 THEN ISNULL(@SaldoContas, 0) END AS DECIMAL(18,2))                       AS SALDO_CONTAS_HOJE,
               CAST(CASE WHEN @SaldoAcumulado = 1 AND @Ate >= @Hoje THEN ISNULL(@SaldoContas, 0) + ISNULL(@AbertoFuturo, 0) END AS DECIMAL(18,2)) AS SALDO_PREVISTO_FIM
        FROM FIN.fn_FIN_Agenda_Base(@De, @Ate, @VerPagar, @VerReceber, @IncluiRealizado, @IdEmpresa) b
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a agenda. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Agenda_Periodos.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Agenda_Periodos]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Calendário da tela inicial (agenda financeira, P03/P04, etapa
                04h1): uma linha por dia, por mês ou por grupo de meses de
                @De a @Ate, inclusive os sem nenhuma conta (para o calendário
                desenhar todos os quadros):
                  @Agrupamento = 'DIA'   : um quadro por dia (semana, quinzena,
                                           mês);
                  @Agrupamento = 'MES'   : um quadro por mês (ano, vários
                                           anos), cortado em @De e @Ate;
                  @Agrupamento = 'MESES' : quadros de @MesesGrupo meses
                                           (bimestre = 2, trimestre = 3,
                                           quadrimestre = 4...), a partir do
                                           mês de @De.
                Por quadro: quantidades a pagar e a receber, quantas estão
                vencidas e em aberto, quantas são previsão, D, C e Saldo
                (C - D) e o SALDO_PREVISTO (saldo de hoje nas contas mais o
                que está em aberto de hoje até o fim do quadro; NULL nos
                quadros que acabam antes de hoje e quando a opção está
                desligada). P04: sem VER_TOTAIS em FIN_AGENDA, todos os
                valores voltam NULL (as quantidades continuam).
                @IncluiRealizado e @SaldoAcumulado NULL = preferência do
                usuário. Permissão: VER em FIN_AGENDA. Padrão "Listar":
                THROW 50001.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Agenda_Periodos @IdUsuario = 2, @De = '2026-11-01', @Ate = '2026-11-30', @Agrupamento = 'DIA';
    -- EXEC FIN.FIN_Agenda_Periodos @IdUsuario = 2, @De = '2026-11-01', @Ate = '2027-04-30', @Agrupamento = 'MESES', @MesesGrupo = 3;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Agenda_Periodos]
    @IdUsuario        INT,
    @De               DATE,
    @Ate              DATE,
    @Agrupamento      VARCHAR(10) = 'DIA',
    @MesesGrupo       INT  = NULL,
    @IdEmpresa        INT  = NULL,
    @IncluiRealizado  BIT  = NULL,
    @SaldoAcumulado   BIT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc     NVARCHAR(128) = N'[FIN].[FIN_Agenda_Periodos]';
    DECLARE @EtapaAtual   VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje         DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @MaxDias      INT;
    DECLARE @VerPagar     BIT;
    DECLARE @VerReceber   BIT;
    DECLARE @VerTotais    BIT;
    DECLARE @SaldoContas  DECIMAL(18,2) = 0;
    DECLARE @MesDe        DATE;
    DECLARE @Qtd          INT;

    DECLARE @Quadros TABLE
    (
        ORDEM   INT  NOT NULL PRIMARY KEY,
        INICIO  DATE NOT NULL,
        FIM     DATE NOT NULL
    );

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a agenda financeira.', 1;

        SET @EtapaAtual = 'Período';
        IF @De IS NULL OR @Ate IS NULL
            THROW 50001, N'Informe o período.', 1;
        IF @Ate < @De
            THROW 50001, N'A data final não pode ser antes da inicial.', 1;
        SET @MaxDias = ISNULL(SIS.fn_SIS_Parametro_Inteiro('AGENDA_PERIODO_MAX_DIAS'), 3700);
        IF @MaxDias NOT BETWEEN 31 AND 7400 SET @MaxDias = 3700;
        IF DATEDIFF(DAY, @De, @Ate) + 1 > @MaxDias
            THROW 50001, N'Período longo demais para a agenda. Escolha um período menor.', 1;
        SET @Agrupamento = UPPER(LTRIM(RTRIM(ISNULL(@Agrupamento, 'DIA'))));
        IF @Agrupamento NOT IN ('DIA', 'MES', 'MESES')
            THROW 50001, N'Agrupamento inválido.', 1;
        IF @Agrupamento = 'MESES' AND ISNULL(@MesesGrupo, 0) NOT BETWEEN 1 AND 24
            THROW 50001, N'Informe de 1 a 24 meses por quadro.', 1;

        SET @EtapaAtual = 'Permissões e preferências';
        SET @VerPagar   = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VerReceber = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        SET @VerTotais  = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER_TOTAIS');
        IF @IncluiRealizado IS NULL
            SET @IncluiRealizado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_INCLUI_REALIZADO') = N'S' THEN 1 ELSE 0 END;
        IF @SaldoAcumulado IS NULL
            SET @SaldoAcumulado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_SALDO_ACUMULADO') = N'S' THEN 1 ELSE 0 END;
        IF @VerTotais = 0 SET @SaldoAcumulado = 0;

        SET @EtapaAtual = 'Quadros';
        SET @MesDe = DATEFROMPARTS(YEAR(@De), MONTH(@De), 1);
        SET @Qtd   = CASE @Agrupamento
                         WHEN 'DIA' THEN DATEDIFF(DAY, @De, @Ate) + 1
                         WHEN 'MES' THEN DATEDIFF(MONTH, @De, @Ate) + 1
                         ELSE DATEDIFF(MONTH, @De, @Ate) / @MesesGrupo + 1
                     END;

        ;WITH n AS (SELECT TOP (@Qtd) CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS INT) AS N
                    FROM sys.all_objects a CROSS JOIN sys.all_objects b)
        INSERT INTO @Quadros (ORDEM, INICIO, FIM)
        SELECT n.N + 1,
               CASE @Agrupamento WHEN 'DIA' THEN DATEADD(DAY, n.N, @De)
                                 WHEN 'MES' THEN CASE WHEN n.N = 0 THEN @De ELSE DATEADD(MONTH, n.N, @MesDe) END
                                 ELSE CASE WHEN n.N = 0 THEN @De ELSE DATEADD(MONTH, n.N * @MesesGrupo, @MesDe) END
               END,
               CASE @Agrupamento WHEN 'DIA' THEN DATEADD(DAY, n.N, @De)
                                 WHEN 'MES' THEN CASE WHEN EOMONTH(DATEADD(MONTH, n.N, @MesDe)) > @Ate THEN @Ate ELSE EOMONTH(DATEADD(MONTH, n.N, @MesDe)) END
                                 ELSE CASE WHEN DATEADD(DAY, -1, DATEADD(MONTH, (n.N + 1) * @MesesGrupo, @MesDe)) > @Ate THEN @Ate
                                           ELSE DATEADD(DAY, -1, DATEADD(MONTH, (n.N + 1) * @MesesGrupo, @MesDe)) END
               END
        FROM n;

        IF @SaldoAcumulado = 1
        BEGIN
            SET @EtapaAtual = 'Saldo das contas';
            SELECT @SaldoContas = ISNULL(SUM(s.SALDO), 0)
            FROM BANCO.Conta c WITH (NOLOCK)
            CROSS APPLY BANCO.fn_BANCO_Conta_Saldo(c.ID_CONTA, @Hoje) s
            WHERE c.ATIVO = 1
              AND c.MOSTRA_SALDO = 1
              AND c.DT_EXCLUSAO IS NULL
              AND s.TEM_SALDO = 1
              AND (@IdEmpresa IS NULL OR c.ID_EMPRESA = @IdEmpresa);

            -- o que está em aberto entre hoje e o início do período entra no saldo de partida
            IF @De > @Hoje
            BEGIN
                DECLARE @AteAntes DATE = DATEADD(DAY, -1, @De);
                SELECT @SaldoContas = @SaldoContas + ISNULL(SUM(b.ABERTO_C - b.ABERTO_D), 0)
                FROM FIN.fn_FIN_Agenda_Base(@Hoje, @AteAntes, @VerPagar, @VerReceber, 0, @IdEmpresa) b
                OPTION (RECOMPILE);
            END;
        END;

        SET @EtapaAtual = 'Consulta';
        ;WITH soma AS
        (
            SELECT q.ORDEM,
                   ISNULL(SUM(CASE WHEN b.TIPO = 'P' THEN 1 ELSE 0 END), 0)                                     AS QTD_PAGAR,
                   ISNULL(SUM(CASE WHEN b.TIPO = 'R' THEN 1 ELSE 0 END), 0)                                     AS QTD_RECEBER,
                   ISNULL(SUM(CASE WHEN b.ABERTO > 0 AND b.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END), 0)         AS QTD_VENCIDAS,
                   ISNULL(SUM(CASE WHEN b.PREVISAO = 1 THEN 1 ELSE 0 END), 0)                                   AS QTD_PREVISAO,
                   ISNULL(SUM(b.VALOR_D), 0)                                                    AS TOTAL_D,
                   ISNULL(SUM(b.VALOR_C), 0)                                                    AS TOTAL_C,
                   ISNULL(SUM(CASE WHEN b.DT_VENCIMENTO >= @Hoje THEN b.ABERTO_C - b.ABERTO_D ELSE 0 END), 0) AS LIQUIDO_FUTURO
            FROM @Quadros q
            LEFT JOIN (SELECT x.*,
                              CASE @Agrupamento WHEN 'DIA' THEN DATEDIFF(DAY, @De, x.DT_VENCIMENTO)
                                                WHEN 'MES' THEN DATEDIFF(MONTH, @De, x.DT_VENCIMENTO)
                                                ELSE DATEDIFF(MONTH, @De, x.DT_VENCIMENTO) / @MesesGrupo END + 1 AS ORDEM_QUADRO
                       FROM FIN.fn_FIN_Agenda_Base(@De, @Ate, @VerPagar, @VerReceber, @IncluiRealizado, @IdEmpresa) x) b
                   ON b.ORDEM_QUADRO = q.ORDEM
            GROUP BY q.ORDEM
        )
        SELECT q.ORDEM,
               q.INICIO,
               q.FIM,
               CAST(CASE WHEN @Hoje BETWEEN q.INICIO AND q.FIM THEN 1 ELSE 0 END AS BIT)  AS TEM_HOJE,
               CAST(s.QTD_PAGAR AS INT)                                                   AS QTD_PAGAR,
               CAST(s.QTD_RECEBER AS INT)                                                 AS QTD_RECEBER,
               CAST(s.QTD_VENCIDAS AS INT)                                                AS QTD_VENCIDAS,
               CAST(s.QTD_PREVISAO AS INT)                                                AS QTD_PREVISAO,
               CAST(CASE WHEN @VerTotais = 1 THEN s.TOTAL_D END AS DECIMAL(18,2))                 AS TOTAL_D,
               CAST(CASE WHEN @VerTotais = 1 THEN s.TOTAL_C END AS DECIMAL(18,2))                 AS TOTAL_C,
               CAST(CASE WHEN @VerTotais = 1 THEN s.TOTAL_C - s.TOTAL_D END AS DECIMAL(18,2))     AS SALDO,
               CAST(CASE WHEN @SaldoAcumulado = 1 AND q.FIM >= @Hoje
                         THEN @SaldoContas + SUM(s.LIQUIDO_FUTURO) OVER (ORDER BY q.ORDEM ROWS UNBOUNDED PRECEDING) END AS DECIMAL(18,2)) AS SALDO_PREVISTO
        FROM @Quadros q
        INNER JOIN soma s ON s.ORDEM = q.ORDEM
        ORDER BY q.ORDEM
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o calendário da agenda. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/FIN/FIN.FIN_Agenda_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [FIN].[FIN_Agenda_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Lista da tela inicial (agenda financeira, P03, etapa 04h1):
                as parcelas a pagar e a receber do período (@De a @Ate), linha
                a linha, pela mesma regra do calendário (fn_FIN_Agenda_Base):
                em aberto pelo saldo e, com a opção ligada, também o já pago ou
                recebido. @SoAtraso = 1: só o "Em atraso" (em aberto, vencidas
                antes de hoje, sem olhar o período). @Tipo P/R filtra o lado;
                @Texto procura no parceiro, histórico, documento e número do
                lançamento. Paginada (FIN_LISTA_POR_PAGINA); TOTAL_LINHAS em
                todas as linhas. A linha abre o lançamento (ID_LANCAMENTO).
                PROJECAO fica 0 até as ocorrências mensais (P02): as linhas
                projetadas virão marcadas, só leitura, calculadas na hora.
                Os valores de cada parcela aparecem para quem vê a tela (são
                os mesmos das listas de contas a pagar e a receber); os
                totais somados ficam no FIN_Agenda_Resumo (P04).
                @IncluiRealizado NULL = preferência do usuário.
                Permissão: VER em FIN_AGENDA. Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04h1).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Agenda_Listar @IdUsuario = 2, @De = '2026-11-27', @Ate = '2026-11-27';
    -- EXEC FIN.FIN_Agenda_Listar @IdUsuario = 2, @De = NULL, @Ate = NULL, @SoAtraso = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Agenda_Listar]
    @IdUsuario        INT,
    @De               DATE,
    @Ate              DATE,
    @SoAtraso         BIT           = 0,
    @Tipo             CHAR(1)       = NULL,
    @IdEmpresa        INT           = NULL,
    @IncluiRealizado  BIT           = NULL,
    @Texto            NVARCHAR(100) = NULL,
    @Pagina           INT           = 1,
    @PorPagina        INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Agenda_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje       DATE = CONVERT(DATE, SYSDATETIME());
    DECLARE @MaxDias    INT;
    DECLARE @VerPagar   BIT;
    DECLARE @VerReceber BIT;
    DECLARE @Termo      NVARCHAR(110);
    DECLARE @Digitos    VARCHAR(100);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_AGENDA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a agenda financeira.', 1;

        SET @EtapaAtual = 'Período';
        SET @SoAtraso = ISNULL(@SoAtraso, 0);
        IF @SoAtraso = 1
        BEGIN
            SET @De  = '19000101';
            SET @Ate = DATEADD(DAY, -1, @Hoje);
            SET @IncluiRealizado = 0;
        END
        ELSE
        BEGIN
            IF @De IS NULL OR @Ate IS NULL
                THROW 50001, N'Informe o período.', 1;
            IF @Ate < @De
                THROW 50001, N'A data final não pode ser antes da inicial.', 1;
            SET @MaxDias = ISNULL(SIS.fn_SIS_Parametro_Inteiro('AGENDA_PERIODO_MAX_DIAS'), 3700);
            IF @MaxDias NOT BETWEEN 31 AND 7400 SET @MaxDias = 3700;
            IF DATEDIFF(DAY, @De, @Ate) + 1 > @MaxDias
                THROW 50001, N'Período longo demais para a agenda. Escolha um período menor.', 1;
        END;

        SET @EtapaAtual = 'Permissões e filtros';
        SET @VerPagar   = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PAGAR', 'VER');
        SET @VerReceber = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_RECEBER', 'VER');
        SET @Tipo = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Tipo, '')))), '');
        IF @Tipo = 'P' SET @VerReceber = 0;
        IF @Tipo = 'R' SET @VerPagar = 0;
        IF @IncluiRealizado IS NULL
            SET @IncluiRealizado = CASE WHEN SIS.fn_SIS_Preferencia_Valor(@IdUsuario, 'INICIO_INCLUI_REALIZADO') = N'S' THEN 1 ELSE 0 END;
        SET @Texto     = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @Termo     = N'%' + REPLACE(REPLACE(REPLACE(ISNULL(@Texto, N''), N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Digitos   = NULLIF(CONVERT(VARCHAR(100), CAD.fn_CAD_Somente_Digitos(ISNULL(@Texto, N''))), '');
        SET @PorPagina = ISNULL(@PorPagina, ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_POR_PAGINA'), 100));
        IF @PorPagina NOT BETWEEN 10 AND 1000 SET @PorPagina = 100;
        SET @Pagina = CASE WHEN ISNULL(@Pagina, 1) < 1 THEN 1 ELSE @Pagina END;

        SET @EtapaAtual = 'Consulta';
        SELECT b.ID_PARCELA,
               b.ID_LANCAMENTO,
               b.TIPO,
               b.DT_VENCIMENTO,
               p.NUMERO,
               p.QTD_PARCELAS,
               b.SITUACAO,
               b.PREVISAO,
               CAST(0 AS BIT)                                                                 AS PROJECAO,
               CAST(CASE WHEN b.ABERTO > 0 AND b.DT_VENCIMENTO < @Hoje THEN 1 ELSE 0 END AS BIT) AS VENCIDA,
               CAST(CASE WHEN b.ABERTO > 0 AND b.DT_VENCIMENTO < @Hoje THEN DATEDIFF(DAY, b.DT_VENCIMENTO, @Hoje) ELSE 0 END AS INT) AS DIAS_ATRASO,
               b.VALOR,
               b.ABERTO                                                                       AS SALDO_ABERTO,
               b.REALIZADO                                                                    AS VALOR_REALIZADO,
               b.VALOR_AGENDA,
               b.ID_EMPRESA,
               ISNULL(NULLIF(e.NOME_FANTASIA, N''), e.RAZAO_SOCIAL)                           AS EMPRESA_NOME,
               ISNULL(l.ID_PESSOA, 0)                                                         AS ID_PESSOA,
               ISNULL(NULLIF(pe.NOME_FANTASIA, N''), ISNULL(pe.NOME, N''))                    AS PESSOA_NOME,
               l.HISTORICO,
               l.DOCUMENTO,
               ISNULL(CONVERT(NVARCHAR(20), cc.CODIGO), N'')                                  AS CENTRO_CODIGO,
               ISNULL(cc.DESCRICAO, N'')                                                      AS CENTRO_DESCRICAO,
               CAST(COUNT(*) OVER () AS INT)                                                  AS TOTAL_LINHAS,
               @Pagina                                                                        AS PAGINA,
               @PorPagina                                                                     AS POR_PAGINA
        FROM FIN.fn_FIN_Agenda_Base(@De, @Ate, @VerPagar, @VerReceber, @IncluiRealizado, @IdEmpresa) b
        INNER JOIN FIN.Parcela p           WITH (NOLOCK) ON p.ID_PARCELA = b.ID_PARCELA
        INNER JOIN FIN.Lancamento l        WITH (NOLOCK) ON l.ID_LANCAMENTO = b.ID_LANCAMENTO
        INNER JOIN CAD.Empresa e           WITH (NOLOCK) ON e.ID_EMPRESA = b.ID_EMPRESA
        LEFT  JOIN CAD.Pessoa pe           WITH (NOLOCK) ON pe.ID_PESSOA = l.ID_PESSOA
        LEFT  JOIN CAD.Centro_Custo cc     WITH (NOLOCK) ON cc.ID_CENTRO_CUSTO = l.ID_CENTRO_CUSTO
        WHERE (@Texto IS NULL
               OR l.HISTORICO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR l.DOCUMENTO  COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME      COLLATE Latin1_General_CI_AI LIKE @Termo
               OR pe.NOME_FANTASIA COLLATE Latin1_General_CI_AI LIKE @Termo
               OR (@Digitos IS NOT NULL AND LEN(@Digitos) >= 5 AND pe.CPF_CNPJ LIKE @Digitos + '%')
               OR CONVERT(NVARCHAR(20), l.ID_LANCAMENTO) = @Texto)
        ORDER BY b.DT_VENCIMENTO, b.TIPO, ISNULL(NULLIF(pe.NOME_FANTASIA, N''), ISNULL(pe.NOME, N'')), b.ID_LANCAMENTO, p.NUMERO
        OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a lista da agenda. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

PRINT N'Pacote 04h concluído sem erro.';
GO

SET NOEXEC OFF;
GO
