/*******************************************************************************
  Objeto      : [SIS].[SIS_Anexo_Tipo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Tipos de anexo ativos para a janela "Anexar" das telas, com as
                extensões aceitas e o tamanho máximo (ANEXO_TAMANHO_MAX_MB), para
                a tela avisar antes de enviar. A conferência que vale continua
                no SIS_Anexo_Gravar.
                Permissão: VER na tela (@Item).
                Padrão "Listar": THROW 50001 com mensagem amigável.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04d2, passo 5: aba Anexos).

  Homologação (LOCAL): ver sql/testes/CAD/04d2_Homologacao_Anexos.sql.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Anexo_Tipo_Listar]
    @IdUsuario  INT,
    @Item       VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Anexo_Tipo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, @Item, 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver estes anexos.', 1;

        SET @EtapaAtual = 'Consulta';

        SELECT t.CODIGO,
               t.NOME,
               t.EXTENSOES,
               SIS.fn_SIS_Parametro_Inteiro('ANEXO_TAMANHO_MAX_MB') AS TAMANHO_MAX_MB
        FROM SIS.Anexo_Tipo t WITH (NOLOCK)
        WHERE t.ATIVO = 1
        ORDER BY t.NOME;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os tipos de anexo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
