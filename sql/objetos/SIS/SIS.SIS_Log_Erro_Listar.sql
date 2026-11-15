/*******************************************************************************
  Objeto      : [SIS].[SIS_Log_Erro_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 15/11/2026
  Descrição   : Lista do log de erros para a tela do administrador.
                Filtros opcionais; sem datas, mostra os últimos 30 dias.
                @MaxLinhas: padrão 500, máximo 5000.
                Padrão das procedures "Listar" (proposto, ainda não é regra
                oficial): devolvem só o conjunto de dados; em recusa de filtro
                ou erro técnico fazem THROW 50001 com mensagem amigável (o erro
                técnico real vai para SIS.Log_Erro) e a API mostra a mensagem
                de erros 50001 ao usuário.
                Permissão: SIS_LOG_ERRO / VER.

  Changelog:
    v1.0 (15/11/2026) - Criação (etapa 02a).
    v1.1 (15/11/2026) - Etapa 02b: recebe @IdUsuario e confere a permissão
                        SIS_LOG_ERRO / VER.

  Homologação (LOCAL):
    -- EXEC SIS.SIS_Log_Erro_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Log_Erro_Listar @IdUsuario = 2, @DtInicio = '2026-11-01', @DtFim = '2026-11-30', @Origem = 'API', @Texto = N'teste';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Log_Erro_Listar]
    @IdUsuario  INT,
    @DtInicio   DATE           = NULL,
    @DtFim      DATE           = NULL,
    @Rotina     NVARCHAR(256)  = NULL,
    @Origem     VARCHAR(10)    = NULL,
    @Texto      NVARCHAR(200)  = NULL,
    @MaxLinhas  INT            = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Log_Erro_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação dos filtros';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LOG_ERRO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver o log de erros.', 1;

        SET @DtFim     = ISNULL(@DtFim, CAST(SYSDATETIME() AS DATE));
        SET @DtInicio  = ISNULL(@DtInicio, DATEADD(DAY, -30, @DtFim));
        SET @Rotina    = NULLIF(LTRIM(RTRIM(@Rotina)), N'');
        SET @Origem    = NULLIF(UPPER(LTRIM(RTRIM(@Origem))), '');
        SET @Texto     = NULLIF(LTRIM(RTRIM(@Texto)), N'');
        SET @MaxLinhas = ISNULL(@MaxLinhas, 500);
        IF @MaxLinhas < 1 SET @MaxLinhas = 500;
        IF @MaxLinhas > 5000 SET @MaxLinhas = 5000;

        IF @DtInicio > @DtFim
            THROW 50001, N'A data inicial não pode ser maior que a data final.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT TOP (@MaxLinhas)
               l.ID_LOG_ERRO,
               l.DT_ERRO,
               l.ORIGEM,
               l.ROTINA,
               l.ETAPA,
               l.NUMERO_ERRO,
               l.MENSAGEM,
               l.LINHA,
               l.USUARIO,
               l.ESTACAO,
               ISNULL(CAST(l.DETALHE AS NVARCHAR(4000)), N'') AS DETALHE
        FROM SIS.Log_Erro l WITH (NOLOCK)
        WHERE l.DT_ERRO >= @DtInicio
          AND l.DT_ERRO <  DATEADD(DAY, 1, @DtFim)
          AND (@Rotina IS NULL OR l.ROTINA   LIKE N'%' + @Rotina + N'%')
          AND (@Origem IS NULL OR l.ORIGEM   = @Origem)
          AND (@Texto  IS NULL OR l.MENSAGEM LIKE N'%' + @Texto + N'%')
        ORDER BY l.ID_LOG_ERRO DESC
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;   -- recusa de filtro: a mensagem já é amigável

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o log de erros. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
