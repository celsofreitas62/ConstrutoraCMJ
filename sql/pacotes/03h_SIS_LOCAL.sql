/*******************************************************************************
  Pacote      : 03h - atualizacao em um clique (historico SIS.Atualizacao, registro pelo atualizar.cmd); banco 1.8
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 22/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 03g já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/03h_Homologacao_Atualizacao.sql.
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
-- Arquivo: sql/objetos/SIS/SIS.Atualizacao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[Atualizacao]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Histórico das atualizações de versão feitas pelo atualizar.cmd do
                pacote (atualização em um clique, conversa 03h): versões de/para
                do programa e do banco, quando, quanto tempo o sistema ficou fora,
                resultado (CONCLUIDA, DESFEITA = deu erro e voltou sozinho,
                ERRO = deu erro e não conseguiu voltar) e a nota da versão
                (NOTAS_DA_VERSAO.txt do pacote: o que foi corrigido e o que é
                novo). Base da futura tela Sistema › Versões (pedido P22).
                Gravado só por SIS.SIS_Atualizacao_Registrar. Nunca é apagado.

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 03h, banco 1.8).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[SIS].[Atualizacao]', N'U') IS NULL
    CREATE TABLE [SIS].[Atualizacao]
    (
        ID_ATUALIZACAO        INT             IDENTITY(1,1) NOT NULL,
        VERSAO_PROGRAMA_DE    VARCHAR(20)     NOT NULL CONSTRAINT DF_Atualizacao_VERSAO_PROGRAMA_DE DEFAULT (''),
        VERSAO_PROGRAMA_PARA  VARCHAR(20)     NOT NULL,
        VERSAO_BANCO_DE       VARCHAR(20)     NOT NULL CONSTRAINT DF_Atualizacao_VERSAO_BANCO_DE    DEFAULT (''),
        VERSAO_BANCO_PARA     VARCHAR(20)     NOT NULL,
        DT_INICIO             DATETIME2(0)    NOT NULL,
        DT_FIM                DATETIME2(0)    NOT NULL,
        SEGUNDOS_FORA         INT             NOT NULL CONSTRAINT DF_Atualizacao_SEGUNDOS_FORA      DEFAULT (0),
        SITUACAO              VARCHAR(10)     NOT NULL,
        MENSAGEM              NVARCHAR(2000)  NOT NULL CONSTRAINT DF_Atualizacao_MENSAGEM           DEFAULT (N''),
        NOTAS                 NVARCHAR(MAX)   NOT NULL CONSTRAINT DF_Atualizacao_NOTAS              DEFAULT (N''),
        PACOTE                NVARCHAR(260)   NOT NULL CONSTRAINT DF_Atualizacao_PACOTE             DEFAULT (N''),
        USUARIO               NVARCHAR(128)   NOT NULL CONSTRAINT DF_Atualizacao_USUARIO            DEFAULT (SUSER_SNAME()),
        ESTACAO               NVARCHAR(128)   NOT NULL CONSTRAINT DF_Atualizacao_ESTACAO            DEFAULT (ISNULL(HOST_NAME(), N'')),
        DT_REGISTRO           DATETIME2(0)    NOT NULL CONSTRAINT DF_Atualizacao_DT_REGISTRO        DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Atualizacao          PRIMARY KEY CLUSTERED (ID_ATUALIZACAO),
        CONSTRAINT CK_Atualizacao_SITUACAO CHECK (SITUACAO IN ('CONCLUIDA', 'DESFEITA', 'ERRO'))
    );
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
                Devolve 1 linha: SUCESSO, MENSAGEM, ID_GERADO.

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 03h, banco 1.8).

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
            @Chave NVARCHAR(200), @IdEmail BIGINT, @Agora DATETIME2(0) = SYSDATETIME();

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
                  - DENY de EXECUTE no registro de atualização (só o atualizar.cmd).
                O login e o usuário do banco (ex.: sistemacmj_api) são
                criados na instalação do servidor (instalador / MASTER), que
                também coloca o usuário neste papel: a senha nunca fica em
                arquivo do projeto.
                Idempotente: pode rodar de novo.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).
    v1.1 (22/11/2026) - DENY em SIS_Atualizacao_Registrar (etapa 03h).
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

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Versao.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : registro da versão do banco em [SIS].[Versao_Banco]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 20/11/2026
  Descrição   : ÚLTIMA instrução do MASTER (depois da finalização): grava a
                versão que acabou de ser instalada. É a ÚNICA fonte da versão do
                banco: o montar_master.py lê o número daqui para o cabeçalho
                do MASTER, e a API exige o mesmo número
                (Infra/VersaoBanco.cs, VersaoExigida).
                REGRA: toda mudança que vai para o MASTER sobe este número e o
                da API juntos.
                Em banco de desenvolvimento (_LOCAL) grava com ORIGEM
                PACOTE_LOCAL. Rodar de novo grava outra linha (histórico).

  Changelog:
    v1.0 (20/11/2026) - Criação (etapa 03d): versão 1.1 do banco.
    Versões do banco: 1.1 (20/11/2026) limite de login por computador e versão;
                      1.2 (20/11/2026) primeiro acesso da instalação;
                      1.3 (20/11/2026) SIS_Registro_Existe (anexos com o login da API);
                      1.4 (20/11/2026) fn_SIS_Usuario_Id (licença gravada pela API);
                      1.5 (20/11/2026) backup do servidor (SIS.Backup, avisos de atraso).
                      1.6 (20/11/2026) restauração de backup pela tela (SIS.Backup_Restauracao).
                      1.7 (22/11/2026) ajuda exclusiva do administrador geral (SIS_Ajuda_Geral_Obter, tela SIS_AJUDA_GERAL).
                      1.8 (22/11/2026) atualização em um clique (SIS.Atualizacao, SIS_Atualizacao_Registrar).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '1.8';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO

PRINT N'Pacote 03h concluído sem erro.';
GO

SET NOEXEC OFF;
GO
