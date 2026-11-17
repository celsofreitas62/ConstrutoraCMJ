/*******************************************************************************
  Objeto      : [FIN].[FIN_Arquivo_Morto_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Consulta do arquivo morto (só leitura): período, conta, busca por
                parte do texto (pessoa, obra, empresa, complemento, documento, nota
                ou plano) e valor exato. Permissão: VER em FIN_ARQUIVO_MORTO.
                Devolve até @Limite linhas, mais recentes primeiro.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Arquivo_Morto_Listar @IdUsuario = 2, @Busca = N'pintor', @DtInicio = '2010-01-01', @DtFim = '2010-12-31';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Arquivo_Morto_Listar]
    @IdUsuario  INT,
    @Busca      NVARCHAR(100) = NULL,
    @DtInicio   DATE          = NULL,
    @DtFim      DATE          = NULL,
    @Conta      NVARCHAR(80)  = NULL,
    @Limite     INT           = 1000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[FIN].[FIN_Arquivo_Morto_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Like       NVARCHAR(110);
    DECLARE @Valor      DECIMAL(18,2);

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_ARQUIVO_MORTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para consultar o arquivo morto.', 1;

        SET @Busca  = LTRIM(RTRIM(ISNULL(@Busca, N'')));
        SET @Conta  = LTRIM(RTRIM(ISNULL(@Conta, N'')));
        SET @Limite = CASE WHEN ISNULL(@Limite, 0) BETWEEN 1 AND 20000 THEN @Limite ELSE 1000 END;
        SET @Like   = N'%' + REPLACE(REPLACE(REPLACE(@Busca, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';
        SET @Valor  = TRY_CONVERT(DECIMAL(18,2), REPLACE(REPLACE(@Busca, N'.', N''), N',', N'.'));

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@Limite)
               a.ID_ARQUIVO_MORTO, a.DT_MOVIMENTO, a.DT_VENCIMENTO, a.DT_PAGAMENTO,
               a.EMPRESA, a.OBRA, a.PESSOA, a.CONTA, a.PLANO1, a.PLANO2, a.PLANO3,
               a.HISTORICO, a.COMPLEMENTO, a.DOCUMENTO, a.NOTA_FISCAL, a.IMOVEL,
               a.VALOR_DEBITO, a.VALOR_CREDITO, a.CONFIRMADO, a.ORIGEM_ACCESS, a.CODIGO_ACCESS
        FROM FIN.Arquivo_Morto a WITH (NOLOCK)
        WHERE (@DtInicio IS NULL OR a.DT_MOVIMENTO >= @DtInicio)
          AND (@DtFim    IS NULL OR a.DT_MOVIMENTO <= @DtFim)
          AND (@Conta = N'' OR a.CONTA = @Conta)
          AND (   @Busca = N''
               OR a.PESSOA LIKE @Like OR a.OBRA LIKE @Like OR a.EMPRESA LIKE @Like
               OR a.COMPLEMENTO LIKE @Like OR a.DOCUMENTO LIKE @Like OR a.NOTA_FISCAL LIKE @Like
               OR a.PLANO3 LIKE @Like OR a.HISTORICO LIKE @Like
               OR (@Valor IS NOT NULL AND (a.VALOR_DEBITO = @Valor OR a.VALOR_CREDITO = @Valor)))
        ORDER BY a.DT_MOVIMENTO DESC, a.ID_ARQUIVO_MORTO DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível consultar o arquivo morto. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
