/*******************************************************************************
  Pacote      : 03g - ajuda exclusiva do administrador geral (procedure de acesso com registro, tela SIS_AJUDA_GERAL); banco 1.7
  Banco       : SISTEMACMJ_LOCAL (somente desenvolvimento)
  Gerado em   : 22/11/2026 pelo Claude, juntando os arquivos de sql/objetos/
                na ordem da regra 59. NÃO EDITAR ESTE ARQUIVO: corrigir o
                arquivo do objeto e gerar o pacote de novo.
  Pré-requisito: pacotes 02a a 03d já rodados.
  Como rodar  : SSMS > Arquivo > Abrir > este arquivo > F5.
                Pode rodar de novo: é idempotente.
  Depois      : rodar sql/testes/SIS/03g_Homologacao_Ajuda_Geral.sql.
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
-- Arquivo: sql/objetos/SIS/SIS.SIS_Ajuda_Geral_Obter.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : [SIS].[SIS_Ajuda_Geral_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Porta de entrada da ajuda exclusiva do administrador geral
                (pedido 3 de 16/11/2026; CLAUDE.md seção 3.8). A API chama
                antes de entregar o índice ou uma página da pasta AjudaGeral
                (embutida no executável, sem endereço direto).
                Permissão: SIS_AJUDA_GERAL / VER. A tela é EXCLUSIVO_GERAL,
                então só o nível 2 passa (vw_SIS_Permissao_Efetiva).
                Toda consulta fica registrada em SIS.Log_Passo (ROTINA desta
                procedure): STATUS OK = entregue, AVISO = recusada.
                Recusa devolve a mesma mensagem de "página não encontrada",
                para não revelar que a página existe.
                Devolve 1 linha: SUCESSO, MENSAGEM (regra 18).
                @Pagina vazia = índice.

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 03g, ajuda do administrador geral).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Ajuda_Geral_Obter @IdUsuario = 2, @Pagina = 'licenca', @Estacao = N'127.0.0.1';
    -- SELECT TOP 10 * FROM SIS.Log_Passo WHERE ROTINA = N'[SIS].[SIS_Ajuda_Geral_Obter]' ORDER BY ID_LOG_PASSO DESC;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Ajuda_Geral_Obter]
    @IdUsuario  INT,
    @Pagina     VARCHAR(60)    = NULL,
    @Estacao    NVARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Ajuda_Geral_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Login      NVARCHAR(100) = N'';
    DECLARE @Pode       BIT;
    DECLARE @Detalhe    NVARCHAR(4000);

    BEGIN TRY
        SET @Pagina  = ISNULL(LTRIM(RTRIM(@Pagina)), '');
        SET @Estacao = ISNULL(LTRIM(RTRIM(@Estacao)), N'');
        SET @Pode    = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_AJUDA_GERAL', 'VER');

        SELECT @Login = u.LOGIN FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario;
        SET @Detalhe = LEFT(N'Usuário ' + ISNULL(@Login, N'') + N' (ID ' + ISNULL(CAST(@IdUsuario AS NVARCHAR(12)), N'') + N')'
                          + CASE WHEN @Estacao <> N'' THEN N', estação ' + @Estacao ELSE N'' END, 4000);

        SET @EtapaAtual = 'Registro';
        INSERT INTO SIS.Log_Passo (RUN_ID, ROTINA, ETAPA, STATUS, DETALHE, DT_PASSO)
        VALUES (NEWID(), @NomeProc,
                LEFT(CASE WHEN @Pode = 1 THEN N'Consulta: ' ELSE N'Recusada: ' END + CASE WHEN @Pagina = '' THEN N'(índice)' ELSE CAST(@Pagina AS NVARCHAR(60)) END, 200),
                CASE WHEN @Pode = 1 THEN 'OK' ELSE 'AVISO' END,
                ISNULL(@Detalhe, N''), SYSDATETIME());

        IF @Pode = 0
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Página não encontrada.' AS NVARCHAR(400)) AS MENSAGEM;
            RETURN;
        END;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'' AS NVARCHAR(400)) AS MENSAGEM;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        SELECT CAST(0 AS BIT) AS SUCESSO,
               CAST(N'Não foi possível abrir a ajuda. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM;
    END CATCH;
END;
GO

-- =============================================================================
-- Arquivo: sql/objetos/SIS/Carga_SIS_Ajuda_Geral.sql
-- =============================================================================
/*******************************************************************************
  Objeto      : carga da ajuda do administrador geral
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Tela Sistema > Configuração > Ajuda do administrador geral
                (SIS_AJUDA_GERAL), EXCLUSIVO_GERAL: só o nível 2 vê; não pode
                ser dada a ninguém por marcação. Ação VER.
                Só insere o que falta (regra 39).

  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 03g).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

INSERT INTO SIS.Item (ID_MODULO, ID_ITEM_PAI, CODIGO, NOME, TIPO, CAMINHO, ORDEM, EXCLUSIVO_GERAL, HABILITADO, TABELAS_DA_TELA)
SELECT m.ID_MODULO, p.ID_ITEM, 'SIS_AJUDA_GERAL', N'Ajuda do administrador geral', 'TELA', 'sis/ajuda-geral.html', 60, 1, 1, ''
FROM SIS.Modulo m
INNER JOIN SIS.Item p ON p.CODIGO = 'SIS_CONFIGURACAO'
WHERE m.CODIGO = 'SIS'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item i WHERE i.CODIGO = 'SIS_AJUDA_GERAL');
GO

INSERT INTO SIS.Item_Acao (ID_ITEM, ID_ACAO)
SELECT i.ID_ITEM, a.ID_ACAO
FROM SIS.Item i
INNER JOIN SIS.Acao a ON a.CODIGO = 'VER'
WHERE i.CODIGO = 'SIS_AJUDA_GERAL'
  AND NOT EXISTS (SELECT 1 FROM SIS.Item_Acao ia WHERE ia.ID_ITEM = i.ID_ITEM AND ia.ID_ACAO = a.ID_ACAO);
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
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Versao VARCHAR(20) = '1.7';
INSERT INTO SIS.Versao_Banco (VERSAO, ORIGEM)
VALUES (@Versao, CASE WHEN DB_NAME() LIKE N'%[_]LOCAL' THEN 'PACOTE_LOCAL' ELSE 'MASTER' END);
PRINT N'Versão do banco registrada: ' + @Versao;
GO

PRINT N'Pacote 03g concluído sem erro.';
GO

SET NOEXEC OFF;
GO
