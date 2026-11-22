/*******************************************************************************
  Objeto      : [SIS].[SIS_Lixeira_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 22/11/2026
  Descrição   : Lista da tela Sistema › Lixeira (P20), uma tela só para todos
                os módulos: filtros por módulo, tela, período da exclusão,
                quem excluiu, texto e situação (padrão LIXEIRA; '' = todas,
                para ver o histórico de recuperados e apagados). Só traz os
                registros das telas que o usuário pode ver. APAGA_LOGO = 1
                quando o registro será apagado dentro do prazo do aviso
                (LIXEIRA_AVISO_DIAS, "apaga amanhã").
                Permissão: VER em SIS_LIXEIRA.
  Changelog:
    v1.0 (22/11/2026) - Criação (etapa 04b).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Lixeira_Listar @IdUsuario = 2;
    -- EXEC SIS.SIS_Lixeira_Listar @IdUsuario = 2, @Modulo = 'CAD', @Situacao = '';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Lixeira_Listar]
    @IdUsuario  INT,
    @Modulo     VARCHAR(10)   = NULL,
    @Item       VARCHAR(40)   = NULL,
    @DtInicio   DATE          = NULL,
    @DtFim      DATE          = NULL,
    @Usuario    NVARCHAR(100) = NULL,
    @Texto      NVARCHAR(100) = NULL,
    @Situacao   VARCHAR(12)   = 'LIXEIRA'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Lixeira_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Hoje DATE = CAST(SYSDATETIME() AS DATE);
    DECLARE @Aviso INT;

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_LIXEIRA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver a lixeira.', 1;

        SET @Modulo   = NULLIF(LTRIM(RTRIM(ISNULL(@Modulo, ''))), '');
        SET @Item     = NULLIF(LTRIM(RTRIM(ISNULL(@Item, ''))), '');
        SET @Usuario  = NULLIF(LTRIM(RTRIM(ISNULL(@Usuario, N''))), N'');
        SET @Texto    = NULLIF(LTRIM(RTRIM(ISNULL(@Texto, N''))), N'');
        SET @Situacao = NULLIF(LTRIM(RTRIM(ISNULL(@Situacao, ''))), '');
        SET @Aviso    = SIS.fn_SIS_Parametro_Inteiro('LIXEIRA_AVISO_DIAS');

        SET @EtapaAtual = 'Consulta';
        SELECT l.ID_LIXEIRA,
               m.CODIGO AS MODULO_CODIGO,
               m.NOME   AS MODULO_NOME,
               l.ITEM_CODIGO,
               i.NOME   AS TELA_NOME,
               CAST(l.TABELA AS NVARCHAR(256)) AS TABELA,
               l.ID_REGISTRO,
               l.DESCRICAO,
               l.MOTIVO,
               l.DT_EXCLUSAO,
               l.USUARIO_EXCLUSAO,
               l.DT_APAGAR,
               CAST(CASE WHEN l.SITUACAO = 'LIXEIRA' THEN DATEDIFF(DAY, @Hoje, l.DT_APAGAR) ELSE 0 END AS INT) AS DIAS_RESTANTES,
               CAST(CASE WHEN l.SITUACAO = 'LIXEIRA' AND @Aviso > 0 AND l.DT_APAGAR <= DATEADD(DAY, @Aviso, @Hoje) THEN 1 ELSE 0 END AS BIT) AS APAGA_LOGO,
               l.SITUACAO,
               l.DT_SITUACAO,
               l.USUARIO_SITUACAO,
               l.MOTIVO_SITUACAO,
               l.DT_AVISO
        FROM SIS.Lixeira l WITH (NOLOCK)
        INNER JOIN SIS.Item   i WITH (NOLOCK) ON i.CODIGO    = l.ITEM_CODIGO
        INNER JOIN SIS.Modulo m WITH (NOLOCK) ON m.ID_MODULO = i.ID_MODULO
        WHERE (@Situacao IS NULL OR l.SITUACAO = @Situacao)
          AND (@Modulo   IS NULL OR m.CODIGO = @Modulo)
          AND (@Item     IS NULL OR l.ITEM_CODIGO = @Item)
          AND (@DtInicio IS NULL OR l.DT_EXCLUSAO >= @DtInicio)
          AND (@DtFim    IS NULL OR l.DT_EXCLUSAO <  DATEADD(DAY, 1, @DtFim))
          AND (@Usuario  IS NULL OR l.USUARIO_EXCLUSAO = @Usuario)
          AND (@Texto    IS NULL OR l.DESCRICAO LIKE N'%' + @Texto + N'%' OR l.MOTIVO LIKE N'%' + @Texto + N'%')
          AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, l.ITEM_CODIGO, 'VER') = 1
        ORDER BY m.ORDEM_MENU, i.ORDEM, l.DT_EXCLUSAO DESC, l.ID_LIXEIRA DESC;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar a lixeira. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
