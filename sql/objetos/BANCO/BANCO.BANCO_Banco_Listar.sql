/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Banco_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Lista de bancos (tela Bancos e escolha do banco nas contas e nos
                dados bancários das pessoas). Permissão: VER em BANCO_BANCO,
                BANCO_CONTA ou CAD_PESSOA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Banco_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Banco_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Banco_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_BANCO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PESSOA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a lista de bancos.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT b.ID_BANCO, b.CODIGO, b.ISPB, b.NOME, b.ATIVO, b.DT_ALTERACAO, ISNULL(b.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM BANCO.Banco b WITH (NOLOCK)
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR b.ATIVO = 1)
        ORDER BY b.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a lista de bancos. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
