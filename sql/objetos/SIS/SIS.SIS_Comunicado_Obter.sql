/*******************************************************************************
  Objeto      : [SIS].[SIS_Comunicado_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Dados da tela Comunicados: o comunicado (o primeiro, ativo antes,
                quando @IdComunicado vier vazio), os itens (ITENS_JSON), as últimas
                20 edições (EDICOES_JSON, sem o HTML), os destinatários dos dois
                grupos e a agenda da rotina. Permissão: VER em SIS_COMUNICADO.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, boletim semanal da implantação).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Comunicado_Obter]
    @IdUsuario     INT,
    @IdComunicado  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Comunicado_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_COMUNICADO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os comunicados.', 1;

        IF @IdComunicado IS NULL
            SELECT TOP (1) @IdComunicado = c.ID_COMUNICADO FROM SIS.Comunicado c ORDER BY c.ATIVO DESC, c.ID_COMUNICADO;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_COMUNICADO, c.CODIGO, c.TITULO, c.INTRODUCAO, c.EXIGE_APROVACAO, c.ATIVO,
               g.CODIGO AS GRUPO, ga.CODIGO AS GRUPO_APROVACAO,
               ISNULL(SIS.fn_SIS_Emails_Do_Grupo(g.CODIGO), N'')  AS DESTINATARIOS,
               ISNULL(SIS.fn_SIS_Emails_Do_Grupo(ga.CODIGO), N'') AS DESTINATARIOS_APROVACAO,
               ISNULL(CONVERT(VARCHAR(5), r.HORARIO, 108), '') AS ROTINA_HORARIO, ISNULL(r.DIAS_SEMANA, '') AS ROTINA_DIAS,
               r.PROXIMA_EXECUCAO AS ROTINA_PROXIMA, ISNULL(r.ATIVA, CAST(0 AS BIT)) AS ROTINA_ATIVA,
               ISNULL((SELECT i.ID_COMUNICADO_ITEM AS id, i.SECAO AS secao, i.TEXTO AS texto, i.ORDEM AS ordem, i.ATIVO AS ativo
                       FROM SIS.Comunicado_Item i
                       WHERE i.ID_COMUNICADO = c.ID_COMUNICADO AND i.ATIVO = 1
                       ORDER BY i.SECAO, i.ORDEM, i.ID_COMUNICADO_ITEM
                       FOR JSON PATH), N'[]') AS ITENS_JSON,
               ISNULL((SELECT TOP (20) e.ID_COMUNICADO_EDICAO AS id, e.DT_INICIO AS inicio, e.DT_FIM AS fim, e.ASSUNTO AS assunto,
                              e.SITUACAO AS situacao, e.DT_CRIACAO AS criada, e.DT_APROVACAO AS aprovada, e.USUARIO_APROVACAO AS aprovadaPor
                       FROM SIS.Comunicado_Edicao e
                       WHERE e.ID_COMUNICADO = c.ID_COMUNICADO
                       ORDER BY e.ID_COMUNICADO_EDICAO DESC
                       FOR JSON PATH), N'[]') AS EDICOES_JSON
        FROM SIS.Comunicado c
        INNER JOIN SIS.Grupo_Email g  ON g.ID_GRUPO_EMAIL  = c.ID_GRUPO_EMAIL
        INNER JOIN SIS.Grupo_Email ga ON ga.ID_GRUPO_EMAIL = c.ID_GRUPO_EMAIL_APROVACAO
        LEFT  JOIN SIS.Rotina r ON r.CODIGO = 'COMUNICADO_PREVIA'
        WHERE c.ID_COMUNICADO = @IdComunicado;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o comunicado. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
