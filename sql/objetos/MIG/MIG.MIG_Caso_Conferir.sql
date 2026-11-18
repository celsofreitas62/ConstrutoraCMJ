/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Botão "Conferir" da tela "Casos da migração" (e o passo final
                de cada gravação): classifica de novo só aquele documento, com
                as correções gravadas, pelas mesmas regras da migração
                (MIG_Movimento_Transformar @Unidade). Devolve UNIDADE, REGRA,
                MOTIVO e DETALHE. Nada é gravado no financeiro.
                Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
    v1.1 (18/11/2026) - @Unidades (lista JSON): confere vários documentos de uma
                        vez (ações em lote); uma linha por documento.

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Conferir @IdUsuario = 1, @Unidade = 'L:123';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Conferir]
    @IdUsuario  INT,
    @Unidade    VARCHAR(40)   = NULL,
    @Unidades   NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Conferir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;
        IF @Unidade IS NOT NULL AND NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = @Unidade)
            THROW 50001, N'Caso não encontrado. Atualize a lista.', 1;
        IF @Unidade IS NULL AND ISJSON(ISNULL(@Unidades, N'')) = 0
            THROW 50001, N'Escolha pelo menos um documento.', 1;

        SET @EtapaAtual = 'Classificação';
        EXEC MIG.MIG_Movimento_Transformar @Executar = 0, @Unidade = @Unidade, @Unidades = @Unidades;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível conferir o caso. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
