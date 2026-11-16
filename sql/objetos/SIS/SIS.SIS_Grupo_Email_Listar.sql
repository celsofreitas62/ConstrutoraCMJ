/*******************************************************************************
  Objeto      : [SIS].[SIS_Grupo_Email_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Grupos de e-mail": cada grupo com a quantidade e a lista
                de destinatários ativos (separados por "; ").
                Permissão: VER em SIS_GRUPO_EMAIL.
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 02d).

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Grupo_Email_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Grupo_Email_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Grupo_Email_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_GRUPO_EMAIL', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os grupos de e-mail.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT g.ID_GRUPO_EMAIL, g.CODIGO, g.NOME, g.DESCRICAO, g.ATIVO,
               (SELECT COUNT(*) FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.ATIVO = 1) AS QTD_DESTINATARIOS,
               ISNULL((SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), d.EMAIL), N'; ') WITHIN GROUP (ORDER BY d.EMAIL)
                       FROM SIS.Grupo_Email_Destinatario d WHERE d.ID_GRUPO_EMAIL = g.ID_GRUPO_EMAIL AND d.ATIVO = 1), N'') AS DESTINATARIOS,
               g.DT_ALTERACAO, g.USUARIO_ALTERACAO
        FROM SIS.Grupo_Email g
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR g.ATIVO = 1)
        ORDER BY g.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os grupos de e-mail. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
