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
