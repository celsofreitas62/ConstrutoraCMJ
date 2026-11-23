/*******************************************************************************
  Pacote      : 04c - versoes e notas da versao (SIS.Versao_Nota, aviso O que ha de novo, e-mail da nota; P22); banco continua 2.1 ate a 04c2
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 23/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 04b2 já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/04c_Homologacao_Versoes.sql e 03h_Homologacao_Atualizacao.sql.
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
-- Arquivo: sql/objetos/SIS/SIS.fn_SIS_Versao_Numero.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[fn_SIS_Versao_Numero]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Converte um número de versão ("2.1", "2.10", "1.8.0") num
                inteiro que ordena certo (maior.menor.revisão =
                maior * 1.000.000 + menor * 1.000 + revisão), porque "2.10"
                é maior que "2.9", mas como texto não é. Vazio ou inválido
                devolve 0 (nunca NULL).
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- SELECT SIS.fn_SIS_Versao_Numero('2.10'), SIS.fn_SIS_Versao_Numero('2.9'), SIS.fn_SIS_Versao_Numero('');
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION [SIS].[fn_SIS_Versao_Numero] (@Versao VARCHAR(20))
RETURNS INT
AS
BEGIN
    DECLARE @V VARCHAR(21) = LTRIM(RTRIM(ISNULL(@Versao, ''))), @P1 INT = 0, @P2 INT = 0, @P3 INT = 0, @i INT;

    IF @V = '' OR @V LIKE '%[^0-9.]%' OR @V LIKE '.%' RETURN 0;

    SET @i = CHARINDEX('.', @V + '.');
    SET @P1 = ISNULL(TRY_CAST(LEFT(@V, @i - 1) AS INT), 0);
    SET @V = STUFF(@V, 1, @i, '');
    IF @V <> ''
    BEGIN
        SET @i = CHARINDEX('.', @V + '.');
        SET @P2 = ISNULL(TRY_CAST(LEFT(@V, @i - 1) AS INT), 0);
        SET @V = STUFF(@V, 1, @i, '');
    END;
    IF @V <> ''
    BEGIN
        SET @i = CHARINDEX('.', @V + '.');
        SET @P3 = ISNULL(TRY_CAST(LEFT(@V, @i - 1) AS INT), 0);
    END;

    IF @P1 > 2000 OR @P2 > 999 OR @P3 > 999 RETURN 0;
    RETURN @P1 * 1000000 + @P2 * 1000 + @P3;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Versao_Nota.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Versao_Nota]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Notas de cada versão do sistema, um item por linha (o que é
                novo, o que melhorou, o que foi corrigido), para a tela
                Sistema › Versões, o aviso "O que há de novo" e o e-mail da
                nota depois de cada atualização (pedido P22).
                Fonte única: docs/NOTAS_DA_VERSAO.md, convertido em
                Carga_SIS_Versao_Nota.sql por sql/ferramentas/montar_notas.py
                e carregado pelo MASTER (toda instalação já nasce com o
                histórico completo das notas). Não tem tela de manutenção.
                PUBLICO: TODOS ou GERAL (só o administrador geral vê).
                TEXTO = texto puro (busca); TEXTO_HTML = com <b> e <code>,
                gerado pelo montar_notas.py (já escapado).
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Versao_Nota]', N'U') IS NULL
    CREATE TABLE [SIS].[Versao_Nota]
    (
        ID_VERSAO_NOTA  INT             IDENTITY(1,1) NOT NULL,
        VERSAO          VARCHAR(20)     NOT NULL,
        VERSAO_NUMERO   INT             NOT NULL,
        DT_VERSAO       DATE            NULL,
        ORDEM           SMALLINT        NOT NULL,
        TIPO            VARCHAR(10)     NOT NULL,
        PUBLICO         VARCHAR(10)     NOT NULL CONSTRAINT DF_Versao_Nota_PUBLICO    DEFAULT ('TODOS'),
        TEXTO           NVARCHAR(2000)  NOT NULL,
        TEXTO_HTML      NVARCHAR(4000)  NOT NULL,
        DT_CRIACAO      DATETIME2(0)    NOT NULL CONSTRAINT DF_Versao_Nota_DT_CRIACAO DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Versao_Nota               PRIMARY KEY CLUSTERED (ID_VERSAO_NOTA),
        CONSTRAINT UQ_Versao_Nota_VERSAO_ORDEM  UNIQUE (VERSAO, ORDEM),
        CONSTRAINT CK_Versao_Nota_TIPO          CHECK (TIPO IN ('NOVO', 'MELHORIA', 'CORRECAO')),
        CONSTRAINT CK_Versao_Nota_PUBLICO       CHECK (PUBLICO IN ('TODOS', 'GERAL'))
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Versao_Nota_VERSAO_NUMERO' AND object_id = OBJECT_ID(N'[SIS].[Versao_Nota]'))
    CREATE NONCLUSTERED INDEX IX_Versao_Nota_VERSAO_NUMERO ON [SIS].[Versao_Nota] (VERSAO_NUMERO DESC, ORDEM);
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.Usuario_Novidade.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Usuario_Novidade]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Última versão cujas novidades cada usuário já viu (aviso "O que
                há de novo", pedido P22). O aviso mostra as versões instaladas
                depois desta. Usuário sem linha: na primeira consulta nasce com
                a versão atual (usuário novo não recebe o histórico inteiro).
                Na instalação da 04c, os usuários existentes nascem com a
                versão que estava instalada (Carga_SIS_Novidades.sql), para
                verem as novidades da versão nova.
                Gravada só por SIS.SIS_Novidades_Obter e
                SIS.SIS_Novidades_Marcar_Vista.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Usuario_Novidade]', N'U') IS NULL
    CREATE TABLE [SIS].[Usuario_Novidade]
    (
        ID_USUARIO    INT           NOT NULL,
        VERSAO_VISTA  VARCHAR(20)   NOT NULL CONSTRAINT DF_Usuario_Novidade_VERSAO_VISTA DEFAULT (''),
        DT_VISTA      DATETIME2(0)  NOT NULL CONSTRAINT DF_Usuario_Novidade_DT_VISTA     DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Usuario_Novidade          PRIMARY KEY CLUSTERED (ID_USUARIO),
        CONSTRAINT FK_Usuario_Novidade_Usuario  FOREIGN KEY (ID_USUARIO) REFERENCES [SIS].[Usuario] (ID_USUARIO)
    );
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Versao_Nota_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Versao_Nota_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Notas das versões já instaladas (aba "Notas das versões" da
                tela Sistema › Versões, pedido P22), da mais nova para a mais
                antiga. Qualquer usuário ativo vê (decisão do Celso,
                23/11/2026); os itens marcados para o administrador geral
                (PUBLICO = GERAL) só aparecem para o nível 2. Filtros: versão,
                tipo (NOVO, MELHORIA, CORRECAO) e parte do texto.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Versao_Nota_Listar @IdUsuario = 2, @Busca = N'lixeira';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Versao_Nota_Listar]
    @IdUsuario  INT,
    @Versao     VARCHAR(20)    = '',
    @Tipo       VARCHAR(10)    = '',
    @Busca      NVARCHAR(100)  = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Versao_Nota_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Usuário';
    DECLARE @Geral BIT, @Atual INT;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
            THROW 50001, N'Usuário não identificado. Entre no sistema de novo.', 1;

        SET @Geral  = CASE WHEN SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) = 2 THEN 1 ELSE 0 END;
        SET @Atual  = SIS.fn_SIS_Versao_Numero(SIS.fn_SIS_Versao_Banco());
        SET @Versao = LTRIM(RTRIM(ISNULL(@Versao, '')));
        SET @Tipo   = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Busca  = LTRIM(RTRIM(ISNULL(@Busca, N'')));

        SET @EtapaAtual = 'Consulta';
        SELECT n.VERSAO,
               n.VERSAO_NUMERO,
               CAST(ISNULL(CONVERT(VARCHAR(10), n.DT_VERSAO, 103), '') AS VARCHAR(10)) AS DT_VERSAO,
               n.ORDEM,
               n.TIPO,
               CAST(CASE n.TIPO WHEN 'NOVO' THEN N'Novo' WHEN 'MELHORIA' THEN N'Melhoria' ELSE N'Correção' END AS NVARCHAR(20)) AS TIPO_NOME,
               n.PUBLICO,
               n.TEXTO,
               n.TEXTO_HTML,
               CAST(CASE WHEN n.VERSAO_NUMERO = @Atual THEN 1 ELSE 0 END AS BIT) AS ATUAL
        FROM SIS.Versao_Nota n WITH (NOLOCK)
        WHERE n.VERSAO_NUMERO <= @Atual
          AND (n.PUBLICO = 'TODOS' OR @Geral = 1)
          AND (@Versao = '' OR n.VERSAO = @Versao)
          AND (@Tipo = '' OR n.TIPO = @Tipo)
          AND (@Busca = N'' OR n.TEXTO LIKE N'%' + @Busca + N'%')
        ORDER BY n.VERSAO_NUMERO DESC, n.ORDEM;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar as notas das versões. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Versao_Listar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Versao_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Histórico das versões do sistema (aba "Histórico de
                atualizações" da tela Sistema › Versões, pedido P22), do mais
                novo para o mais antigo. Junta:
                  - ATUALIZACAO: cada atualizar.cmd (SIS.Atualizacao), com
                    versões de/para do programa e do banco, tempo fora do ar,
                    resultado e mensagem;
                  - INSTALACAO: o MASTER rodado à mão (SIS.Versao_Banco com
                    ORIGEM = MASTER que não é de uma atualização);
                  - PACOTE: pacote de desenvolvimento (só no banco _LOCAL).
                De SIS.Versao_Banco entram só as mudanças de versão (rodar o
                MASTER de novo na mesma versão não aparece).
                Permissão: VER em SIS_VERSOES (só o administrador, decisão do
                Celso de 23/11/2026; as notas são para todos).
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Versao_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Versao_Listar]
    @IdUsuario  INT,
    @DtInicio   DATE = NULL,
    @DtFim      DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Versao_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_VERSOES', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver o histórico de atualizações.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT x.ORIGEM,
               CAST(CASE x.ORIGEM WHEN 'ATUALIZACAO' THEN N'Atualização' WHEN 'INSTALACAO' THEN N'Instalação' ELSE N'Pacote (desenvolvimento)' END AS NVARCHAR(30)) AS ORIGEM_NOME,
               x.ID_ATUALIZACAO,
               x.DT_INICIO,
               x.DT_FIM,
               x.VERSAO_BANCO_DE,
               x.VERSAO_BANCO_PARA,
               x.VERSAO_PROGRAMA_DE,
               x.VERSAO_PROGRAMA_PARA,
               x.SEGUNDOS_FORA,
               x.SITUACAO,
               CAST(CASE x.SITUACAO WHEN 'CONCLUIDA' THEN N'Concluída' WHEN 'DESFEITA' THEN N'Desfeita (voltou sozinha)' ELSE N'Erro' END AS NVARCHAR(30)) AS SITUACAO_NOME,
               x.MENSAGEM,
               x.USUARIO,
               x.ESTACAO,
               x.PACOTE,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM SIS.Versao_Nota n WITH (NOLOCK) WHERE n.VERSAO = x.VERSAO_BANCO_PARA) THEN 1 ELSE 0 END AS BIT) AS TEM_NOTA
        FROM (
                SELECT CAST('ATUALIZACAO' AS VARCHAR(12)) AS ORIGEM, CAST(a.ID_ATUALIZACAO AS INT) AS ID_ATUALIZACAO,
                       a.DT_INICIO, a.DT_FIM, a.VERSAO_BANCO_DE, a.VERSAO_BANCO_PARA, a.VERSAO_PROGRAMA_DE, a.VERSAO_PROGRAMA_PARA,
                       a.SEGUNDOS_FORA, a.SITUACAO, CAST(a.MENSAGEM AS NVARCHAR(2000)) AS MENSAGEM,
                       CAST(a.USUARIO AS NVARCHAR(128)) AS USUARIO, CAST(a.ESTACAO AS NVARCHAR(128)) AS ESTACAO, CAST(a.PACOTE AS NVARCHAR(260)) AS PACOTE
                FROM SIS.Atualizacao a WITH (NOLOCK)
                UNION ALL
                SELECT CAST(CASE v.ORIGEM WHEN 'MASTER' THEN 'INSTALACAO' ELSE 'PACOTE' END AS VARCHAR(12)), CAST(0 AS INT),
                       v.DT_INSTALACAO, v.DT_INSTALACAO, CAST(ISNULL(ant.VERSAO, '') AS VARCHAR(20)), v.VERSAO, CAST('' AS VARCHAR(20)), CAST('' AS VARCHAR(20)),
                       CAST(0 AS INT), CAST('CONCLUIDA' AS VARCHAR(10)), CAST(N'' AS NVARCHAR(2000)),
                       CAST(v.USUARIO AS NVARCHAR(128)), CAST(v.ESTACAO AS NVARCHAR(128)), CAST(N'' AS NVARCHAR(260))
                FROM SIS.Versao_Banco v WITH (NOLOCK)
                OUTER APPLY (SELECT TOP (1) p.VERSAO FROM SIS.Versao_Banco p WITH (NOLOCK)
                             WHERE p.ID_VERSAO_BANCO < v.ID_VERSAO_BANCO ORDER BY p.ID_VERSAO_BANCO DESC) ant
                WHERE ISNULL(ant.VERSAO, '') <> v.VERSAO
                  AND NOT EXISTS (SELECT 1 FROM SIS.Atualizacao a WITH (NOLOCK)
                                  WHERE a.VERSAO_BANCO_PARA = v.VERSAO
                                    AND v.DT_INSTALACAO BETWEEN DATEADD(MINUTE, -1, a.DT_INICIO) AND DATEADD(MINUTE, 1, a.DT_FIM))
             ) x
        WHERE (@DtInicio IS NULL OR x.DT_INICIO >= CAST(@DtInicio AS DATETIME2(0)))
          AND (@DtFim    IS NULL OR x.DT_INICIO <  DATEADD(DAY, 1, CAST(@DtFim AS DATETIME2(0))))
        ORDER BY x.DT_INICIO DESC, x.ID_ATUALIZACAO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar o histórico de atualizações. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Novidades_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Novidades_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Aviso "O que há de novo" (pedido P22): as notas das versões
                instaladas depois da última que o usuário já viu
                (SIS.Usuario_Novidade), no máximo NOVIDADES_VERSOES_MAX versões
                (as mais novas; VERSOES_OMITIDAS diz quantas ficaram de fora,
                para a tela oferecer "ver todas as versões").
                Nenhuma linha = nada a mostrar (aviso desligado pelo parâmetro
                NOVIDADES_AVISO_ATIVO, usuário já viu tudo, ou usuário sem
                registro: nasce com a versão atual vista).
                Não marca como visto: quem marca é SIS_Novidades_Marcar_Vista
                (botão "Entendi" da janela).
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Novidades_Obter @IdUsuario = 2;
    -- sql/testes/SIS/04c_Homologacao_Versoes.sql
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Novidades_Obter]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Novidades_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Usuário';
    DECLARE @VersaoAtual VARCHAR(20), @Atual INT, @Vista INT = 0, @Max INT, @Mostrar BIT = 1, @Geral BIT, @Omitidas INT = 0;
    DECLARE @Versoes TABLE (VERSAO_NUMERO INT NOT NULL PRIMARY KEY, POSICAO INT NOT NULL);

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
            THROW 50001, N'Usuário não identificado. Entre no sistema de novo.', 1;

        SET @VersaoAtual = SIS.fn_SIS_Versao_Banco();
        SET @Atual       = SIS.fn_SIS_Versao_Numero(@VersaoAtual);
        SET @Geral       = CASE WHEN SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) = 2 THEN 1 ELSE 0 END;
        SET @Max         = ISNULL(SIS.fn_SIS_Parametro_Inteiro('NOVIDADES_VERSOES_MAX'), 3);
        IF @Max < 1 SET @Max = 1;
        IF SIS.fn_SIS_Parametro_SN('NOVIDADES_AVISO_ATIVO') = 0 SET @Mostrar = 0;

        SET @EtapaAtual = 'Última versão vista';
        IF @Mostrar = 1
        BEGIN
            BEGIN TRANSACTION;
            INSERT INTO SIS.Usuario_Novidade (ID_USUARIO, VERSAO_VISTA)
            SELECT @IdUsuario, ISNULL(@VersaoAtual, '')
            WHERE NOT EXISTS (SELECT 1 FROM SIS.Usuario_Novidade n WITH (UPDLOCK, HOLDLOCK) WHERE n.ID_USUARIO = @IdUsuario);
            IF @@ROWCOUNT > 0 SET @Mostrar = 0;
            COMMIT TRANSACTION;

            SELECT @Vista = SIS.fn_SIS_Versao_Numero(n.VERSAO_VISTA)
            FROM SIS.Usuario_Novidade n WITH (NOLOCK)
            WHERE n.ID_USUARIO = @IdUsuario;
        END;

        SET @EtapaAtual = 'Versões novas';
        INSERT INTO @Versoes (VERSAO_NUMERO, POSICAO)
        SELECT v.VERSAO_NUMERO, ROW_NUMBER() OVER (ORDER BY v.VERSAO_NUMERO DESC)
        FROM (SELECT DISTINCT n.VERSAO_NUMERO
              FROM SIS.Versao_Nota n WITH (NOLOCK)
              WHERE @Mostrar = 1
                AND n.VERSAO_NUMERO > ISNULL(@Vista, 0)
                AND n.VERSAO_NUMERO <= @Atual
                AND (n.PUBLICO = 'TODOS' OR @Geral = 1)) v;

        SELECT @Omitidas = COUNT(*) FROM @Versoes WHERE POSICAO > @Max;

        SET @EtapaAtual = 'Consulta';
        SELECT n.VERSAO,
               n.VERSAO_NUMERO,
               CAST(ISNULL(CONVERT(VARCHAR(10), n.DT_VERSAO, 103), '') AS VARCHAR(10)) AS DT_VERSAO,
               n.ORDEM,
               n.TIPO,
               CAST(CASE n.TIPO WHEN 'NOVO' THEN N'Novo' WHEN 'MELHORIA' THEN N'Melhoria' ELSE N'Correção' END AS NVARCHAR(20)) AS TIPO_NOME,
               n.PUBLICO,
               n.TEXTO,
               n.TEXTO_HTML,
               CAST(ISNULL(@VersaoAtual, '') AS VARCHAR(20)) AS VERSAO_ATUAL,
               CAST(@Omitidas AS INT) AS VERSOES_OMITIDAS
        FROM SIS.Versao_Nota n WITH (NOLOCK)
        INNER JOIN @Versoes v ON v.VERSAO_NUMERO = n.VERSAO_NUMERO AND v.POSICAO <= @Max
        WHERE (n.PUBLICO = 'TODOS' OR @Geral = 1)
        ORDER BY n.VERSAO_NUMERO DESC, n.ORDEM;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar as novidades da versão. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Novidades_Marcar_Vista.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Novidades_Marcar_Vista]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Botão "Entendi" do aviso "O que há de novo" (pedido P22):
                grava que o usuário já viu as novidades até a versão instalada
                agora (SIS.Usuario_Novidade). O aviso só volta na próxima
                atualização.
                Devolve 1 linha: SUCESSO, MENSAGEM, VERSAO_VISTA.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Novidades_Marcar_Vista @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Novidades_Marcar_Vista]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[SIS].[SIS_Novidades_Marcar_Vista]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Usuário';
    DECLARE @VersaoAtual VARCHAR(20)   = ISNULL(SIS.fn_SIS_Versao_Banco(), '');

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Usuário não identificado. Entre no sistema de novo.' AS NVARCHAR(400)) AS MENSAGEM,
                   CAST('' AS VARCHAR(20)) AS VERSAO_VISTA;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;
        UPDATE n
           SET n.VERSAO_VISTA = @VersaoAtual,
               n.DT_VISTA     = SYSDATETIME()
        FROM SIS.Usuario_Novidade n WITH (UPDLOCK, HOLDLOCK)
        WHERE n.ID_USUARIO = @IdUsuario;

        IF @@ROWCOUNT = 0
            INSERT INTO SIS.Usuario_Novidade (ID_USUARIO, VERSAO_VISTA) VALUES (@IdUsuario, @VersaoAtual);
        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Novidades marcadas como vistas.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST(@VersaoAtual AS VARCHAR(20)) AS VERSAO_VISTA;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível marcar as novidades como vistas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM,
               CAST('' AS VARCHAR(20)) AS VERSAO_VISTA;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/SIS.SIS_Atualizacao_Registrar.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Atualizacao_Registrar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Registra uma atualização de versão em SIS.Atualizacao. Chamada SÓ
                pelo atualizar.ps1 do pacote (atualização em um clique, 03h),
                rodado pelo administrador do Windows; o login da API não pode
                executar (DENY no papel rl_sistemacmj_api).
                Situação DESFEITA ou ERRO: manda aviso por e-mail para o
                parâmetro EMAIL_ADMIN_ALERTA (se preenchido).
                Situação CONCLUIDA: manda a nota da versão ao grupo
                VERSAO_AVISO_GRUPO (se VERSAO_AVISO_EMAIL_ATIVO = S).
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_GERADO.

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 03h, banco 1.8).
    v1.1 (23/11/2026) - Etapa 04c (P22): atualização CONCLUIDA manda a nota das
                        versões novas (SIS.Versao_Nota, só itens para todos)
                        por e-mail ao grupo do parâmetro VERSAO_AVISO_GRUPO,
                        se VERSAO_AVISO_EMAIL_ATIVO = S. Falha no e-mail não
                        desfaz o registro (só vai para o log).

  Homologação:
    -- sql/testes/SIS/03h_Homologacao_Atualizacao.sql
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Atualizacao_Registrar]
    @VersaoProgramaDe    VARCHAR(20)    = '',
    @VersaoProgramaPara  VARCHAR(20),
    @VersaoBancoDe       VARCHAR(20)    = '',
    @VersaoBancoPara     VARCHAR(20),
    @DtInicio            DATETIME2(0),
    @DtFim               DATETIME2(0)   = NULL,
    @SegundosFora        INT            = 0,
    @Situacao            VARCHAR(10),
    @Mensagem            NVARCHAR(2000) = N'',
    @Notas               NVARCHAR(MAX)  = N'',
    @Pacote              NVARCHAR(260)  = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @EtapaAtual VARCHAR(100) = 'Conferência', @Id INT, @Para NVARCHAR(400), @Corpo NVARCHAR(MAX),
            @Chave NVARCHAR(200), @IdEmail BIGINT, @Agora DATETIME2(0) = SYSDATETIME(),
            @Grupo VARCHAR(30), @Itens NVARCHAR(MAX), @De INT, @Ate INT, @Sistema NVARCHAR(100);

    BEGIN TRY
        IF ISNULL(@Situacao, '') NOT IN ('CONCLUIDA', 'DESFEITA', 'ERRO')
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Situação inválida: use CONCLUIDA, DESFEITA ou ERRO.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS ID_GERADO;
            RETURN;
        END;
        IF LTRIM(RTRIM(ISNULL(@VersaoProgramaPara, ''))) = '' OR LTRIM(RTRIM(ISNULL(@VersaoBancoPara, ''))) = '' OR @DtInicio IS NULL
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Informe as versões novas e o início da atualização.' AS NVARCHAR(400)) AS MENSAGEM, CAST(0 AS INT) AS ID_GERADO;
            RETURN;
        END;

        SET @EtapaAtual = 'Gravação';
        INSERT INTO SIS.Atualizacao (VERSAO_PROGRAMA_DE, VERSAO_PROGRAMA_PARA, VERSAO_BANCO_DE, VERSAO_BANCO_PARA, DT_INICIO, DT_FIM,
                                     SEGUNDOS_FORA, SITUACAO, MENSAGEM, NOTAS, PACOTE)
        VALUES (ISNULL(@VersaoProgramaDe, ''), @VersaoProgramaPara, ISNULL(@VersaoBancoDe, ''), @VersaoBancoPara, @DtInicio, ISNULL(@DtFim, @Agora),
                ISNULL(@SegundosFora, 0), @Situacao, LEFT(ISNULL(@Mensagem, N''), 2000), ISNULL(@Notas, N''), LEFT(ISNULL(@Pacote, N''), 260));
        SET @Id = CAST(SCOPE_IDENTITY() AS INT);

        SET @EtapaAtual = 'Aviso por e-mail';
        IF @Situacao IN ('DESFEITA', 'ERRO')
        BEGIN
            SET @Para = LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('EMAIL_ADMIN_ALERTA'), N'')));
            IF @Para <> N''
            BEGIN
                SET @Corpo = SIS.fn_SIS_Email_HTML(N'Atualização de versão ' + CASE @Situacao WHEN 'DESFEITA' THEN N'desfeita' ELSE N'com erro' END, 'ALERTA',
                    N'<p>A atualização do sistema para a versão <b>' + SIS.fn_SIS_Texto_HTML(@VersaoBancoPara) + N'</b> (a versão era '
                    + SIS.fn_SIS_Texto_HTML(ISNULL(@VersaoBancoDe, '')) + N') no banco <b>' + SIS.fn_SIS_Texto_HTML(DB_NAME()) + N'</b> terminou como <b>'
                    + CASE @Situacao WHEN 'DESFEITA' THEN N'DESFEITA (voltou sozinha para a versão anterior)' ELSE N'ERRO (não conseguiu voltar sozinha: conferir o servidor)' END
                    + N'</b> em ' + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(ISNULL(@DtFim, @Agora)), N'') + N'.</p><p>Motivo: ' + SIS.fn_SIS_Texto_HTML(ISNULL(@Mensagem, N'')) + N'</p>',
                    N'[SIS].[SIS_Atualizacao_Registrar]', NULL, 0);
                SET @Chave = N'ATUALIZACAO_' + CONVERT(NVARCHAR(20), @Id);
                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'ALERTA: atualização do sistema não concluída', @CorpoHTML = @Corpo,
                     @Tipo = 'ALERTA', @Origem = N'[SIS].[SIS_Atualizacao_Registrar]', @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
            END;
        END;

        IF @Situacao = 'CONCLUIDA' AND SIS.fn_SIS_Parametro_SN('VERSAO_AVISO_EMAIL_ATIVO') = 1
        BEGIN
        BEGIN TRY
            SET @EtapaAtual = 'Nota da versão por e-mail';
            SET @Grupo = CONVERT(VARCHAR(30), LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('VERSAO_AVISO_GRUPO'), N''))));
            SET @Para  = CASE WHEN @Grupo = '' THEN N'' ELSE LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Emails_Do_Grupo(@Grupo), N''))) END;
            SET @De    = SIS.fn_SIS_Versao_Numero(@VersaoBancoDe);
            SET @Ate   = SIS.fn_SIS_Versao_Numero(@VersaoBancoPara);

            SELECT @Itens = STRING_AGG(CAST(N'<p style="margin:16px 0 4px 0;font-weight:bold;">Versão ' + SIS.fn_SIS_Texto_HTML(v.VERSAO)
                                            + CASE WHEN v.DT_VERSAO IS NULL THEN N'' ELSE N' (' + CONVERT(NVARCHAR(10), v.DT_VERSAO, 103) + N')' END
                                            + N'</p><ul style="margin:0;padding-left:20px;">' + v.ITENS + N'</ul>' AS NVARCHAR(MAX)), N'')
                          WITHIN GROUP (ORDER BY v.VERSAO_NUMERO DESC)
            FROM (SELECT n.VERSAO, n.VERSAO_NUMERO, MAX(n.DT_VERSAO) AS DT_VERSAO,
                         STRING_AGG(CAST(N'<li style="margin-bottom:6px;"><b>' + CASE n.TIPO WHEN 'NOVO' THEN N'Novo' WHEN 'MELHORIA' THEN N'Melhoria' ELSE N'Correção' END
                                         + N':</b> ' + ISNULL(n.TEXTO_HTML, N'') + N'</li>' AS NVARCHAR(MAX)), N'') WITHIN GROUP (ORDER BY n.ORDEM) AS ITENS
                  FROM SIS.Versao_Nota n WITH (NOLOCK)
                  WHERE n.PUBLICO = 'TODOS' AND n.VERSAO_NUMERO > @De AND n.VERSAO_NUMERO <= @Ate
                  GROUP BY n.VERSAO, n.VERSAO_NUMERO) v;

            IF @Para = N''
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (N'[SIS].[SIS_Atualizacao_Registrar]', @EtapaAtual, 0, N'Nota da versão não enviada: o grupo de e-mail do parâmetro VERSAO_AVISO_GRUPO está vazio ou sem destinatário.', 0, SYSDATETIME());

            IF @Para <> N'' AND ISNULL(@Itens, N'') <> N''
            BEGIN
                SET @Sistema = ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(SIS.fn_SIS_Parametro('SISTEMA_NOME'), N''))), N''), N'sistema');
                SET @Corpo = SIS.fn_SIS_Email_HTML(N'Nova versão do ' + @Sistema + N': ' + ISNULL(@VersaoBancoPara, ''), 'INFO',
                    N'<p>O ' + SIS.fn_SIS_Texto_HTML(@Sistema) + N' foi atualizado para a versão <b>' + SIS.fn_SIS_Texto_HTML(@VersaoBancoPara) + N'</b> em '
                    + ISNULL(SIS.fn_SIS_Formatar_Data_Hora(ISNULL(@DtFim, @Agora)), N'') + N'. O sistema ficou fora do ar por '
                    + CONVERT(NVARCHAR(10), ISNULL(@SegundosFora, 0)) + N' segundo(s).</p><p>Veja o que mudou:</p>' + @Itens
                    + N'<p style="margin-top:16px;">As notas de todas as versões ficam em Sistema › Versões.</p>',
                    N'[SIS].[SIS_Atualizacao_Registrar]', @Grupo, 0);
                SET @Chave = N'VERSAO_NOTA_' + CONVERT(NVARCHAR(20), @Id);
                EXEC SIS.SIS_Email_Enfileirar @Para = @Para, @Assunto = N'Nova versão do sistema instalada', @CorpoHTML = @Corpo,
                     @Tipo = 'NOTA_VERSAO', @Origem = N'[SIS].[SIS_Atualizacao_Registrar]', @ChaveOrigem = @Chave, @IdEmail = @IdEmail OUTPUT;
            END;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> -1
                INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
                VALUES (N'[SIS].[SIS_Atualizacao_Registrar]', @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        END CATCH;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Atualização registrada.' AS NVARCHAR(400)) AS MENSAGEM, CAST(@Id AS INT) AS ID_GERADO;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (N'[SIS].[SIS_Atualizacao_Registrar]', @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Erro ao registrar a atualização: o erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, CAST(ISNULL(@Id, 0) AS INT) AS ID_GERADO;
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
    v1.3 (16/11/2026) - Etapa 02d: e-mail (domínio interno, minutos preso),
                        pastas de backup e de atualizações.
    v1.4 (17/11/2026) - Etapa 03c: EMAIL_LOCAL_LIBERADOS (exceção controlada do
                        banco de teste, pedido do Celso) e SISTEMA_NOME
                        (nome do sistema por cliente, pedido do Celso: SisCMJ);
                        EMAIL_LOGO_MODO, EMAIL_LOGO_ENDERECO e
                        EMAIL_LOGO_NOME_ARQUIVO (como a logomarca vai no e-mail).
    v1.5 (20/11/2026) - Etapa 03d: EMAIL_RODAPE_CNPJ (CNPJ no rodapé dos e-mails
                        a clientes e terceiros; fábrica N, pedido do Celso).
    v1.6 (20/11/2026) - Etapa 03d: LOGIN_COMPUTADOR_TENTATIVAS e
                        LOGIN_COMPUTADOR_MINUTOS (limite de tentativas por computador).
    v1.7 (20/11/2026) - Etapa 03d: BACKUP_DIAS_MANTER, BACKUP_NUVEM_MANTER e os
                        avisos de atraso (BACKUP_HORAS_ALERTA_COMPLETO/_LOG,
                        BACKUP_DIAS_ALERTA_TESTE).
    v1.8 (20/11/2026) - Etapa 03d2: BACKUP_RESTAURACAO_MOTIVO_MINIMO (restauração
                        pela tela).
    v1.9 (22/11/2026) - Etapa 04a: SENHA_PROVISORIA_PADRAO e SENHA_PROVISORIA_HORAS
                        (botão Reiniciar senha da tela de Usuários; decisão do
                        Celso de 16/11/2026, PADRAO_TELAS regra 13).
    v2.0 (22/11/2026) - Etapa 04b (P20): LIXEIRA_ATIVA, LIXEIRA_DIAS_GUARDA (90),
                        LIXEIRA_AVISO_DIAS, LIXEIRA_AVISO_GRUPO e
                        LIXEIRA_LIMPEZA_ATIVA.
    v2.1 (23/11/2026) - Etapa 04c (P22): NOVIDADES_AVISO_ATIVO,
                        NOVIDADES_VERSOES_MAX (3), VERSAO_AVISO_EMAIL_ATIVO e
                        VERSAO_AVISO_GRUPO.
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
        ('LOGIN_COMPUTADOR_TENTATIVAS', N'10', 'INTEIRO',
         N'Tentativas de login erradas seguidas, de um mesmo computador (com qualquer usuário), até ele ficar em espera. Mínimo 5.', 'SIS', 1),
        ('LOGIN_COMPUTADOR_MINUTOS', N'15', 'INTEIRO',
         N'Minutos que o computador fica em espera depois de errar o login demais, e janela de contagem das tentativas.', 'SIS', 1),
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
        ('EMAIL_DOMINIO_INTERNO', N'', 'TEXTO',
         N'Domínio(s) do e-mail da empresa (ex.: cmj.com.br), separados por vírgula. Esses endereços saem pela conta interna; os demais pela externa. Vazio = todos pela interna.', 'SIS', 1),
        ('SISTEMA_NOME', N'SisCMJ', 'TEXTO',
         N'Nome do sistema mostrado nas telas, nos e-mails (rodapé e remetente) e nos relatórios. Só o administrador geral altera.', 'SIS', 0),
        ('EMAIL_LOGO_MODO', N'EMBUTIDA', 'TEXTO',
         N'Logomarca nos e-mails: EMBUTIDA (vai dentro do e-mail), ENDERECO (puxada do endereço público EMAIL_LOGO_ENDERECO, não aparece como anexo) ou SEM_IMAGEM (só a faixa colorida).', 'SIS', 0),
        ('EMAIL_LOGO_ENDERECO', N'', 'TEXTO',
         N'Endereço público (https://...) da logomarca, usado quando EMAIL_LOGO_MODO = ENDERECO.', 'SIS', 0),
        ('EMAIL_LOGO_NOME_ARQUIVO', N'CMJ.png', 'TEXTO',
         N'Nome com que a logomarca embutida aparece para quem recebe o e-mail (ex.: CMJ.png).', 'SIS', 0),
        ('EMAIL_LOCAL_LIBERADOS', N'', 'TEXTO',
         N'Só no banco de teste (_LOCAL): tipos de e-mail que saem para os destinatários reais em vez de irem para o EMAIL_TESTE, separados por vírgula (ex.: COMUNICADO). Vazio = todos desviados. Não tem efeito em produção.', 'SIS', 0),
        ('EMAIL_MINUTOS_PRESO', N'15', 'INTEIRO',
         N'Minutos que um e-mail pode ficar "processando" antes de voltar para a fila (serviço parou no meio). Mínimo 5.', 'SIS', 1),
        ('BACKUP_PASTA', N'C:\SistemaCMJ_Arquivos\Backup', 'TEXTO',
         N'Pasta do servidor onde ficam os backups do banco.', 'SIS', 0),
        ('BACKUP_PASTA_EXTERNA', N'', 'TEXTO',
         N'Pasta fora do servidor (disco externo ou pasta sincronizada com a nuvem) para onde os backups são copiados. Vazio = não copia.', 'SIS', 0),
        ('BACKUP_DIAS_MANTER', N'7', 'INTEIRO',
         N'Dias de backup guardados na pasta do servidor (completos e do log); os mais antigos são apagados.', 'SIS', 0),
        ('BACKUP_NUVEM_MANTER', N'1', 'INTEIRO',
         N'Quantos backups completos ficam na pasta da nuvem (BACKUP_PASTA_EXTERNA). 0 = não copia.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_COMPLETO', N'26', 'INTEIRO',
         N'Avisa por e-mail se o último backup completo sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_HORAS_ALERTA_LOG', N'3', 'INTEIRO',
         N'Avisa por e-mail se o último backup do log (de hora em hora) sem erro tiver mais horas que isto.', 'SIS', 0),
        ('BACKUP_DIAS_ALERTA_TESTE', N'8', 'INTEIRO',
         N'Avisa por e-mail se o último teste de restauração sem erro tiver mais dias que isto.', 'SIS', 0),
        ('BACKUP_RESTAURACAO_MOTIVO_MINIMO', N'10', 'INTEIRO',
         N'Quantidade mínima de letras do motivo obrigatório ao pedir uma restauração de backup pela tela.', 'SIS', 0),
        ('ATUALIZACAO_PASTA', N'C:\SistemaCMJ_Arquivos\Atualizacoes', 'TEXTO',
         N'Pasta do servidor onde ficam os pacotes de atualização e o certificado usados pela tela Instalação e manutenção.', 'SIS', 0),
        ('EMAIL_RODAPE_CNPJ', N'N', 'SN',
         N'Mostrar o CNPJ da empresa no rodapé dos e-mails enviados a clientes e terceiros (S/N).', 'SIS', 1),
        ('CIDADE_PADRAO', N'Poços de Caldas', 'TEXTO',
         N'Cidade sugerida nos cadastros e nos documentos.', 'CAD', 1),
        ('SENHA_PROVISORIA_PADRAO', N'@12345', 'TEXTO',
         N'Senha provisória dada pelo botão Reiniciar senha da tela de Usuários. O usuário é obrigado a trocá-la no primeiro acesso.', 'SIS', 0),
        ('SENHA_PROVISORIA_HORAS', N'24', 'INTEIRO',
         N'Horas que a senha provisória vale. Passado esse tempo sem o usuário trocar, o login recusa e é preciso reiniciar a senha de novo. 0 = não vence. Não vale para o administrador geral.', 'SIS', 1),
        ('LIXEIRA_ATIVA', N'S', 'SN',
         N'S = o botão Excluir das telas manda o registro para a lixeira (recuperável). N = a lixeira fica desligada e só é possível desativar.', 'SIS', 1),
        ('LIXEIRA_DIAS_GUARDA', N'90', 'INTEIRO',
         N'Dias que um registro excluído fica na lixeira antes de ser apagado de vez (mínimo 1). Cada tela pode ter prazo próprio na configuração das tabelas; vazio = vale este.', 'SIS', 1),
        ('LIXEIRA_AVISO_DIAS', N'1', 'INTEIRO',
         N'Com quantos dias de antecedência o e-mail avisa o que será apagado de vez da lixeira. 0 = sem aviso.', 'SIS', 1),
        ('LIXEIRA_AVISO_GRUPO', N'LIXEIRA_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe o aviso do que será apagado da lixeira (tela Grupos de e-mail).', 'SIS', 1),
        ('LIXEIRA_LIMPEZA_ATIVA', N'S', 'SN',
         N'S = a rotina diária apaga de vez o que passou do prazo da lixeira. N = nada é apagado (o aviso continua saindo).', 'SIS', 1),
        ('NOVIDADES_AVISO_ATIVO', N'S', 'SN',
         N'S = depois de cada atualização, cada usuário vê uma vez a janela "O que há de novo" com as notas da versão. N = não mostra (as notas continuam em Sistema › Versões).', 'SIS', 1),
        ('NOVIDADES_VERSOES_MAX', N'3', 'INTEIRO',
         N'Quantas versões, no máximo, a janela "O que há de novo" mostra de uma vez (as mais novas); as outras ficam em Sistema › Versões.', 'SIS', 1),
        ('VERSAO_AVISO_EMAIL_ATIVO', N'S', 'SN',
         N'S = cada atualização concluída manda a nota da versão por e-mail ao grupo do parâmetro VERSAO_AVISO_GRUPO. N = não manda.', 'SIS', 1),
        ('VERSAO_AVISO_GRUPO', N'VERSAO_AVISO', 'TEXTO',
         N'Grupo de e-mail que recebe a nota da versão depois de cada atualização (tela Grupos de e-mail).', 'SIS', 1)
     ) v (CHAVE, VALOR, TIPO, DESCRICAO, MODULO, EDITAVEL_ADMIN)
INNER JOIN SIS.Modulo m ON m.CODIGO = v.MODULO
WHERE NOT EXISTS (SELECT 1 FROM SIS.Parametro p WHERE p.CHAVE = v.CHAVE);
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
-- Arquivo: sql/objetos/SIS/Carga_SIS_Versao_Nota.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga de [SIS].[Versao_Nota] (notas de cada versão)
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : GERADO por sql/ferramentas/montar_notas.py a partir de
                docs/NOTAS_DA_VERSAO.md (fonte única). NÃO EDITAR À MÃO:
                corrigir o .md e gerar de novo.
                Sincroniza a tabela com o .md (as notas são do sistema, não da
                CMJ): inclui o que falta, acerta o texto do que mudou e tira o
                item que saiu do .md. Idempotente.
                Versões no arquivo: 2.1, 2.0, 1.9, 1.8.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DROP TABLE IF EXISTS #CargaNota;
SELECT v.VERSAO, SIS.fn_SIS_Versao_Numero(v.VERSAO) AS VERSAO_NUMERO, v.DT_VERSAO, v.ORDEM, v.TIPO, v.PUBLICO, v.TEXTO, v.TEXTO_HTML
INTO #CargaNota
FROM (VALUES
       (CAST('2.1' AS VARCHAR(20)), CAST('2026-11-23' AS DATE), CAST(1 AS SMALLINT), CAST('NOVO' AS VARCHAR(10)), CAST('TODOS' AS VARCHAR(10)),
         CAST(N'tela Lixeira (Sistema › Monitoramento). Mostra o que foi excluído em cada tela, agrupado por módulo, com Recuperar, Manter mais dias e Esvaziar agora, e a aba Prazos por tela (quanto tempo cada tela guarda na lixeira).' AS NVARCHAR(2000)), CAST(N'tela <b>Lixeira</b> (Sistema › Monitoramento). Mostra o que foi excluído em cada tela, agrupado por módulo, com <b>Recuperar</b>, <b>Manter mais dias</b> e <b>Esvaziar agora</b>, e a aba <b>Prazos por tela</b> (quanto tempo cada tela guarda na lixeira).' AS NVARCHAR(4000)))
      ,('2.1', '2026-11-23', 2, 'NOVO', 'TODOS',
         N'tela Auditoria (Sistema › Monitoramento), o histórico geral do sistema, com filtros por período, usuário, tabela, registro, operação e lote, e os botões Desfazer esta operação e Desfazer o lote.',
         N'tela <b>Auditoria</b> (Sistema › Monitoramento), o histórico geral do sistema, com filtros por período, usuário, tabela, registro, operação e lote, e os botões <b>Desfazer esta operação</b> e <b>Desfazer o lote</b>.')
      ,('2.1', '2026-11-23', 3, 'MELHORIA', 'TODOS',
         N'a aba Histórico das fichas de Pessoa, Usuário e Perfil agora agrupa o que foi gravado junto, tem filtros e os botões Voltar para como estava aqui e Desfazer esta operação, sempre com prévia e motivo. O histórico da pessoa inclui contatos, dados bancários e vínculos (inclusive os já apagados); o do perfil e do usuário, as permissões.',
         N'a aba <b>Histórico</b> das fichas de Pessoa, Usuário e Perfil agora agrupa o que foi gravado junto, tem filtros e os botões <b>Voltar para como estava aqui</b> e <b>Desfazer esta operação</b>, sempre com prévia e motivo. O histórico da pessoa inclui contatos, dados bancários e vínculos (inclusive os já apagados); o do perfil e do usuário, as permissões.')
      ,('2.1', '2026-11-23', 4, 'MELHORIA', 'TODOS',
         N'a ficha de Pessoa tem os botões Desativar (sai das listas, sem prazo) e Excluir (vai para a lixeira); a lista de Pessoas tem o atalho Lixeira de Pessoas.',
         N'a ficha de Pessoa tem os botões <b>Desativar</b> (sai das listas, sem prazo) e <b>Excluir</b> (vai para a lixeira); a lista de Pessoas tem o atalho <b>Lixeira de Pessoas</b>.')
      ,('2.0', '2026-11-22', 1, 'NOVO', 'TODOS',
         N'lixeira. O botão Excluir das telas manda o registro para a lixeira, de onde ele pode ser recuperado; depois do prazo (90 dias, ajustável por tela) ele é apagado de vez. Só vai para a lixeira o que não é usado em nenhum lugar; o resto pode ser desativado, como antes.',
         N'<b>lixeira</b>. O botão Excluir das telas manda o registro para a lixeira, de onde ele pode ser recuperado; depois do prazo (90 dias, ajustável por tela) ele é apagado de vez. Só vai para a lixeira o que não é usado em nenhum lugar; o resto pode ser desativado, como antes.')
      ,('2.0', '2026-11-22', 2, 'NOVO', 'TODOS',
         N'aviso por e-mail, um dia antes, do que vai ser apagado de vez da lixeira, com a opção de manter por mais alguns dias.',
         N'aviso por e-mail, um dia antes, do que vai ser apagado de vez da lixeira, com a opção de manter por mais alguns dias.')
      ,('2.0', '2026-11-22', 3, 'NOVO', 'TODOS',
         N'desfazer pelo histórico. Dá para voltar um cadastro para como estava num ponto do histórico, desfazer uma alteração ou desfazer tudo o que um lote fez, sempre com prévia, motivo e registro de quem fez. Nada é desfeito se alguém mexeu depois no mesmo campo.',
         N'<b>desfazer pelo histórico</b>. Dá para voltar um cadastro para como estava num ponto do histórico, desfazer uma alteração ou desfazer tudo o que um lote fez, sempre com prévia, motivo e registro de quem fez. Nada é desfeito se alguém mexeu depois no mesmo campo.')
      ,('2.0', '2026-11-22', 4, 'MELHORIA', 'TODOS',
         N'o antigo botão Excluir passa a se chamar Desativar (o registro continua no histórico e nas movimentações).',
         N'o antigo botão Excluir passa a se chamar Desativar (o registro continua no histórico e nas movimentações).')
      ,('1.9', '2026-11-22', 1, 'NOVO', 'TODOS',
         N'tela de Usuários (Sistema › Segurança). Cada pessoa tem o seu usuário; o administrador inclui, muda o perfil, desativa, reinicia a senha de quem esqueceu e desbloqueia quem errou a senha várias vezes. O histórico mostra quem mudou o quê.',
         N'tela de <b>Usuários</b> (Sistema › Segurança). Cada pessoa tem o seu usuário; o administrador inclui, muda o perfil, desativa, reinicia a senha de quem esqueceu e desbloqueia quem errou a senha várias vezes. O histórico mostra quem mudou o quê.')
      ,('1.9', '2026-11-22', 2, 'NOVO', 'TODOS',
         N'tela de Perfis e permissões. O administrador marca, tela por tela, o que cada perfil pode fazer (ver, incluir, alterar, excluir, exportar e as ações especiais). Também dá para fazer exceções só para uma pessoa.',
         N'tela de <b>Perfis e permissões</b>. O administrador marca, tela por tela, o que cada perfil pode fazer (ver, incluir, alterar, excluir, exportar e as ações especiais). Também dá para fazer exceções só para uma pessoa.')
      ,('1.9', '2026-11-22', 3, 'NOVO', 'TODOS',
         N'perfis prontos Financeiro e Consulta, para começar (podem ser ajustados).',
         N'perfis prontos <b>Financeiro</b> e <b>Consulta</b>, para começar (podem ser ajustados).')
      ,('1.9', '2026-11-22', 4, 'MELHORIA', 'TODOS',
         N'a senha provisória (dada a um usuário novo ou ao reiniciar a senha) vale por 24 horas; depois disso é preciso reiniciar de novo.',
         N'a senha provisória (dada a um usuário novo ou ao reiniciar a senha) vale por 24 horas; depois disso é preciso reiniciar de novo.')
      ,('1.8', '2026-11-22', 1, 'NOVO', 'TODOS',
         N'atualização em um clique. O administrador roda um único arquivo (atualizar.cmd), que faz um backup de segurança, atualiza o banco e o programa, confere se ficou tudo funcionando e, se algo der errado, volta sozinho para a versão anterior.',
         N'atualização em um clique. O administrador roda um único arquivo (<code>atualizar.cmd</code>), que faz um backup de segurança, atualiza o banco e o programa, confere se ficou tudo funcionando e, se algo der errado, volta sozinho para a versão anterior.')
      ,('1.8', '2026-11-22', 2, 'NOVO', 'TODOS',
         N'o sistema guarda o histórico das atualizações (quando, de qual versão para qual, quanto tempo ficou fora do ar e estas notas).',
         N'o sistema guarda o histórico das atualizações (quando, de qual versão para qual, quanto tempo ficou fora do ar e estas notas).')
      ,('1.8', '2026-11-22', 3, 'MELHORIA', 'TODOS',
         N'o menu mostra só as telas que já estão prontas.',
         N'o menu mostra só as telas que já estão prontas.')
      ,('1.8', '2026-11-22', 4, 'NOVO', 'GERAL',
         N'ajuda técnica com instalação, licença, parâmetros, backup, comandos e recuperação.',
         N'ajuda técnica com instalação, licença, parâmetros, backup, comandos e recuperação.')
     ) v (VERSAO, DT_VERSAO, ORDEM, TIPO, PUBLICO, TEXTO, TEXTO_HTML);

MERGE SIS.Versao_Nota AS d
USING #CargaNota AS o
   ON d.VERSAO = o.VERSAO AND d.ORDEM = o.ORDEM
WHEN MATCHED AND (d.TIPO <> o.TIPO OR d.PUBLICO <> o.PUBLICO OR d.TEXTO <> o.TEXTO OR d.TEXTO_HTML <> o.TEXTO_HTML
                  OR d.VERSAO_NUMERO <> o.VERSAO_NUMERO OR ISNULL(d.DT_VERSAO, '19000101') <> ISNULL(o.DT_VERSAO, '19000101')) THEN
    UPDATE SET d.VERSAO_NUMERO = o.VERSAO_NUMERO, d.DT_VERSAO = o.DT_VERSAO, d.TIPO = o.TIPO, d.PUBLICO = o.PUBLICO,
               d.TEXTO = o.TEXTO, d.TEXTO_HTML = o.TEXTO_HTML
WHEN NOT MATCHED BY TARGET THEN
    INSERT (VERSAO, VERSAO_NUMERO, DT_VERSAO, ORDEM, TIPO, PUBLICO, TEXTO, TEXTO_HTML)
    VALUES (o.VERSAO, o.VERSAO_NUMERO, o.DT_VERSAO, o.ORDEM, o.TIPO, o.PUBLICO, o.TEXTO, o.TEXTO_HTML)
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;

DROP TABLE IF EXISTS #CargaNota;
PRINT N'Notas das versões carregadas.';
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Novidades.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga do aviso de versões (grupo de e-mail VERSAO_AVISO e
                ponto de partida do "O que há de novo")
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : (1) Grupo de e-mail VERSAO_AVISO, que recebe a nota da versão
                depois de cada atualização: nasce com o e-mail interno do
                sistema; a CMJ ajusta na tela Grupos de e-mail.
                (2) Usuários ativos sem registro em SIS.Usuario_Novidade
                nascem com a versão instalada ANTES deste MASTER (este arquivo
                roda antes de Carga_SIS_Versao.sql), para verem as novidades da
                versão que está sendo instalada. Na instalação do zero a versão
                ainda é vazia: o administrador vê as últimas versões.
                Idempotente: não mexe em quem já tem registro.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Grupo_Email (CODIGO, NOME, DESCRICAO, USUARIO_CRIACAO)
SELECT 'VERSAO_AVISO', N'Nota da versão', N'Recebem a nota da versão (o que é novo e o que foi corrigido) depois de cada atualização do sistema.', N'instalacao'
WHERE NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email g WHERE g.CODIGO = 'VERSAO_AVISO');

INSERT INTO SIS.Grupo_Email_Destinatario (ID_GRUPO_EMAIL, EMAIL, NOME, USUARIO_CRIACAO)
SELECT g.ID_GRUPO_EMAIL, N'construtora.m.judice@gmail.com', N'Administração do sistema', N'instalacao'
FROM SIS.Grupo_Email g
WHERE g.CODIGO = 'VERSAO_AVISO'
  AND NOT EXISTS (SELECT 1 FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL);

INSERT INTO SIS.Usuario_Novidade (ID_USUARIO, VERSAO_VISTA)
SELECT u.ID_USUARIO, ISNULL(SIS.fn_SIS_Versao_Banco(), '')
FROM SIS.Usuario u
WHERE u.ATIVO = 1
  AND NOT EXISTS (SELECT 1 FROM SIS.Usuario_Novidade n WHERE n.ID_USUARIO = u.ID_USUARIO);
GO

PRINT N'Pacote 04c concluído sem erro.';
GO

SET NOEXEC OFF;
GO
