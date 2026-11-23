/*******************************************************************************
  Objeto      : [SIS].[SIS_Versao_Nota_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 23/11/2026
  Descrição   : Notas das versões já instaladas (aba "Notas das versões" da
                tela Sistema › Versões, pedido P22), da mais nova para a mais
                antiga. Qualquer usuário ativo vê (decisão do Celso,
                23/11/2026); os itens marcados para o administrador geral
                (PUBLICO = GERAL) só aparecem para o nível 2. Filtros: versão,
                tipo (NOVO, MELHORIA, CORRECAO) e parte do texto.
  Changelog:
    v1.0 (23/11/2026) - Criação (etapa 04c, P22).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Versao_Nota_Listar @IdUsuario = 2, @Busca = N'lixeira';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Versao_Nota_Listar]
    @IdUsuario  INT,
    @Versao     VARCHAR(20)    = '',
    @Tipo       VARCHAR(10)    = '',
    @Busca      NVARCHAR(100)  = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Versao_Nota_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Usuário';
    DECLARE @Geral BIT, @Atual INT;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SIS.Usuario u WITH (NOLOCK) WHERE u.ID_USUARIO = @IdUsuario AND u.ATIVO = 1)
            THROW 50001, N'Usuário não identificado. Entre no sistema de novo.', 1;

        SET @Geral  = CASE WHEN SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) = 2 THEN 1 ELSE 0 END;
        SET @Atual  = SIS.fn_SIS_Versao_Numero(SIS.fn_SIS_Versao_Banco());
        SET @Versao = LTRIM(RTRIM(ISNULL(@Versao, '')));
        SET @Tipo   = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @Busca  = LTRIM(RTRIM(ISNULL(@Busca, N'')));

        SET @EtapaAtual = 'Consulta';
        SELECT n.VERSAO,
               n.VERSAO_NUMERO,
               CAST(ISNULL(CONVERT(VARCHAR(10), n.DT_VERSAO, 103), '') AS VARCHAR(10)) AS DT_VERSAO,
               n.ORDEM,
               n.TIPO,
               CAST(CASE n.TIPO WHEN 'NOVO' THEN N'Novo' WHEN 'MELHORIA' THEN N'Melhoria' ELSE N'Correção' END AS NVARCHAR(20)) AS TIPO_NOME,
               n.PUBLICO,
               n.TEXTO,
               n.TEXTO_HTML,
               CAST(CASE WHEN n.VERSAO_NUMERO = @Atual THEN 1 ELSE 0 END AS BIT) AS ATUAL
        FROM SIS.Versao_Nota n WITH (NOLOCK)
        WHERE n.VERSAO_NUMERO <= @Atual
          AND (n.PUBLICO = 'TODOS' OR @Geral = 1)
          AND (@Versao = '' OR n.VERSAO = @Versao)
          AND (@Tipo = '' OR n.TIPO = @Tipo)
          AND (@Busca = N'' OR n.TEXTO LIKE N'%' + @Busca + N'%')
        ORDER BY n.VERSAO_NUMERO DESC, n.ORDEM;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar as notas das versões. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
