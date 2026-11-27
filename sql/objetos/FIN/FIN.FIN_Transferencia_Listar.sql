/*******************************************************************************
  Objeto      : [FIN].[FIN_Transferencia_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 27/11/2026
  Descrição   : Lista das transferências (tela Bancos › Transferências,
                etapa 04g2). Filtros: período, conta (de um lado ou do outro),
                empresa, situação (ATIVA, ESTORNADA ou todas), só entre
                empresas, texto (histórico, documento, conta). Paginação
                (@Pagina, @PorPagina; padrão FIN_LISTA_POR_PAGINA).
                Cada linha traz TOTAL_LINHAS e TOTAL_VALOR (só das ativas) de
                todo o filtro e PODE_ESTORNAR.
                Permissão: VER em BANCO_TRANSFERENCIA (recusa por THROW 50001,
                como as outras listas).
  Changelog:
    v1.0 (27/11/2026) - Criação (etapa 04g2).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Transferencia_Listar @IdUsuario = 2, @DtDe = '2026-01-01', @DtAte = '2026-12-31';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Transferencia_Listar]
    @IdUsuario       INT,
    @DtDe            DATE           = NULL,
    @DtAte           DATE           = NULL,
    @IdConta         INT            = NULL,
    @IdEmpresa       INT            = NULL,
    @Situacao        VARCHAR(10)    = NULL,
    @EntreEmpresas   BIT            = 0,
    @Texto           NVARCHAR(100)  = NULL,
    @Pagina          INT            = 1,
    @PorPagina       INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[FIN].[FIN_Transferencia_Listar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Permissão';
    DECLARE @PodeEstornar BIT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_TRANSFERENCIA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as transferências.', 1;

        SET @EtapaAtual   = 'Consulta';
        SET @PodeEstornar = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_TRANSFERENCIA', 'ESTORNAR');
        SET @Situacao     = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@Situacao, '')))), '');
        SET @Texto        = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @Pagina       = CASE WHEN ISNULL(@Pagina, 0) < 1 THEN 1 ELSE @Pagina END;
        SET @PorPagina    = ISNULL(@PorPagina, ISNULL(SIS.fn_SIS_Parametro_Inteiro('FIN_LISTA_POR_PAGINA'), 100));
        IF @PorPagina NOT BETWEEN 10 AND 1000 SET @PorPagina = 100;

        ;WITH f AS
        (
            SELECT t.ID_TRANSFERENCIA, t.DT_TRANSFERENCIA, t.VALOR, t.SITUACAO, t.DT_CRIACAO,
                   COUNT(*) OVER () AS TOTAL_LINHAS,
                   SUM(CASE WHEN t.SITUACAO = 'ATIVA' THEN t.VALOR ELSE 0 END) OVER () AS TOTAL_VALOR
            FROM FIN.Transferencia t WITH (NOLOCK)
            INNER JOIN BANCO.Conta co WITH (NOLOCK) ON co.ID_CONTA = t.ID_CONTA_ORIGEM
            INNER JOIN BANCO.Conta cd WITH (NOLOCK) ON cd.ID_CONTA = t.ID_CONTA_DESTINO
            WHERE (@DtDe IS NULL OR t.DT_TRANSFERENCIA >= @DtDe)
              AND (@DtAte IS NULL OR t.DT_TRANSFERENCIA <= @DtAte)
              AND (@IdConta IS NULL OR t.ID_CONTA_ORIGEM = @IdConta OR t.ID_CONTA_DESTINO = @IdConta)
              AND (@IdEmpresa IS NULL OR co.ID_EMPRESA = @IdEmpresa OR cd.ID_EMPRESA = @IdEmpresa)
              AND (@Situacao IS NULL OR t.SITUACAO = @Situacao)
              AND (ISNULL(@EntreEmpresas, 0) = 0 OR co.ID_EMPRESA <> cd.ID_EMPRESA)
              AND (@Texto IS NULL OR t.HISTORICO LIKE N'%' + @Texto + N'%' OR t.DOCUMENTO LIKE N'%' + @Texto + N'%'
                   OR co.DESCRICAO LIKE N'%' + @Texto + N'%' OR cd.DESCRICAO LIKE N'%' + @Texto + N'%')
        ),
        pag AS
        (
            SELECT f.* FROM f
            ORDER BY f.DT_TRANSFERENCIA DESC, f.ID_TRANSFERENCIA DESC
            OFFSET (@Pagina - 1) * @PorPagina ROWS FETCH NEXT @PorPagina ROWS ONLY
        )
        SELECT t.ID_TRANSFERENCIA, t.DT_TRANSFERENCIA,
               t.ID_CONTA_ORIGEM,  co.DESCRICAO AS CONTA_ORIGEM,  co.ID_EMPRESA AS ID_EMPRESA_ORIGEM,
               ISNULL(NULLIF(eo.NOME_FANTASIA, N''), eo.RAZAO_SOCIAL) AS EMPRESA_ORIGEM,
               t.ID_CONTA_DESTINO, cd.DESCRICAO AS CONTA_DESTINO, cd.ID_EMPRESA AS ID_EMPRESA_DESTINO,
               ISNULL(NULLIF(ed.NOME_FANTASIA, N''), ed.RAZAO_SOCIAL) AS EMPRESA_DESTINO,
               CAST(CASE WHEN co.ID_EMPRESA <> cd.ID_EMPRESA THEN 1 ELSE 0 END AS BIT) AS ENTRE_EMPRESAS,
               t.VALOR, t.HISTORICO, t.DOCUMENTO, t.SITUACAO,
               ISNULL(CONVERT(VARCHAR(10), t.DT_ESTORNO, 23), '') AS DT_ESTORNO,
               ISNULL(t.MOTIVO_ESTORNO, N'') AS MOTIVO_ESTORNO, ISNULL(t.USUARIO_ESTORNO, N'') AS USUARIO_ESTORNO,
               t.USUARIO_CRIACAO, t.DT_CRIACAO, t.ID_LOTE,
               CAST(CASE WHEN t.CODIGO_ACCESS IS NULL THEN 0 ELSE 1 END AS BIT) AS MIGRADA,
               CAST(CASE WHEN @PodeEstornar = 1 AND t.SITUACAO = 'ATIVA' THEN 1 ELSE 0 END AS BIT) AS PODE_ESTORNAR,
               p.TOTAL_LINHAS, CAST(p.TOTAL_VALOR AS DECIMAL(18,2)) AS TOTAL_VALOR
        FROM pag p
        INNER JOIN FIN.Transferencia t WITH (NOLOCK) ON t.ID_TRANSFERENCIA = p.ID_TRANSFERENCIA
        INNER JOIN BANCO.Conta co WITH (NOLOCK) ON co.ID_CONTA = t.ID_CONTA_ORIGEM
        INNER JOIN BANCO.Conta cd WITH (NOLOCK) ON cd.ID_CONTA = t.ID_CONTA_DESTINO
        LEFT  JOIN CAD.Empresa eo WITH (NOLOCK) ON eo.ID_EMPRESA = co.ID_EMPRESA
        LEFT  JOIN CAD.Empresa ed WITH (NOLOCK) ON ed.ID_EMPRESA = cd.ID_EMPRESA
        ORDER BY t.DT_TRANSFERENCIA DESC, t.ID_TRANSFERENCIA DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível listar as transferências. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
