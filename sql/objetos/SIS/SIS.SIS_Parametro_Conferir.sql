/*******************************************************************************
  Objeto      : [SIS].[SIS_Parametro_Conferir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : Prévia da tela de parâmetros, antes de gravar (etapa 04f2d):
                  PEDE_MOTIVO  1 = a troca afrouxa uma proteção
                               (SIS.fn_SIS_Parametro_Afrouxa): a tela pede o
                               motivo, que o SIS_Parametro_Gravar exige;
                  QTD_ATUAL /  só nos parâmetros de pendência (FIN_PEND_*):
                  QTD_NOVA     quantos lançamentos em aberto têm hoje a
                               pendência da regra e quantos passam a ter com
                               o valor novo (sugestão (a));
                  EFEITO       a frase pronta para a tela (vazio = nada a
                               mostrar).
                Não grava nada. O valor é conferido de leve (data dd/mm/aaaa
                ou aaaa-mm-dd, decimal com vírgula ou ponto); a conferência de
                verdade é do SIS_Parametro_Gravar.
                Permissão: a mesma da lista (VER em SIS_PARAMETRO, ou VER em
                SIS_PARAMETRO_USO para administrador nível 1 ou 2 nos de uso).
                Padrão "Listar": THROW 50001.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2d).
  Homologação (LOCAL):
    -- EXEC SIS.SIS_Parametro_Conferir @IdUsuario = 2, @Chave = 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR', @Valor = N'500';
    -- EXEC SIS.SIS_Parametro_Conferir @IdUsuario = 2, @Chave = 'FIN_REGRA_DUPLIC_DOCUMENTO', @Valor = N'NAO';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SIS].[SIS_Parametro_Conferir]
    @IdUsuario INT,
    @Chave     VARCHAR(60),
    @Valor     NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[SIS].[SIS_Parametro_Conferir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';
    DECLARE @Tipo       VARCHAR(10);
    DECLARE @Atual      NVARCHAR(4000);
    DECLARE @Nivel      TINYINT;
    DECLARE @Novo       NVARCHAR(4000);
    DECLARE @Codigo     VARCHAR(20);
    DECLARE @QtdAtual   INT;
    DECLARE @QtdNova    INT;
    DECLARE @Efeito     NVARCHAR(400) = N'';
    DECLARE @VeTodos    BIT;

    BEGIN TRY
        SET @VeTodos = SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO', 'VER');
        IF @VeTodos = 0
           AND (SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'SIS_PARAMETRO_USO', 'VER') = 0 OR SIS.fn_SIS_Usuario_Nivel_Admin(@IdUsuario) < 1)
            THROW 50001, N'Você não tem permissão para ver os parâmetros.', 1;

        SET @Chave = UPPER(LTRIM(RTRIM(ISNULL(@Chave, ''))));
        SELECT @Tipo = TIPO, @Atual = VALOR, @Nivel = NIVEL_MINIMO FROM SIS.Parametro WHERE CHAVE = @Chave;
        IF @Tipo IS NULL
            THROW 50001, N'Parâmetro não encontrado.', 1;
        IF @VeTodos = 0 AND @Nivel <> 1
            THROW 50001, N'Este parâmetro só pode ser visto pelo administrador geral.', 1;

        SET @EtapaAtual = 'Valor';
        SET @Novo = LTRIM(RTRIM(ISNULL(@Valor, N'')));
        IF @Tipo IN ('SN', 'TEXTO') SET @Novo = UPPER(@Novo);
        IF @Tipo = 'DECIMAL' SET @Novo = REPLACE(@Novo, N',', N'.');
        IF @Tipo = 'DATA' SET @Novo = ISNULL(CONVERT(NVARCHAR(10), ISNULL(TRY_CONVERT(DATE, @Novo, 103), TRY_CONVERT(DATE, @Novo, 23)), 23), @Novo);

        SET @Codigo = CASE @Chave
                          WHEN 'FIN_PEND_SEM_CENTRO'            THEN 'SEM_CENTRO'
                          WHEN 'FIN_PEND_SEM_PLANO'             THEN 'SEM_PLANO'
                          WHEN 'FIN_PEND_SEM_DOCUMENTO'         THEN 'SEM_DOCUMENTO'
                          WHEN 'FIN_PEND_PAGAR_SEM_ANEXO_VALOR' THEN 'SEM_ANEXO'
                          WHEN 'FIN_PEND_RECEBER_NAO_APTO'      THEN 'NAO_APTO'
                          WHEN 'FIN_PEND_VENCIDA_DIAS'          THEN 'VENCIDA'
                          WHEN 'FIN_PEND_A_PARTIR_DE'           THEN '*'
                      END;

        IF @Codigo IS NOT NULL AND @Novo <> ISNULL(@Atual, N'')
        BEGIN
            SET @EtapaAtual = 'Efeito';
            SELECT l.ID_LANCAMENTO
            INTO #abertos
            FROM FIN.Lancamento l WITH (NOLOCK)
            WHERE l.SITUACAO = 'ATIVO'
              AND l.DT_EXCLUSAO IS NULL
              AND EXISTS (SELECT 1 FROM FIN.Parcela p WITH (NOLOCK) WHERE p.ID_LANCAMENTO = l.ID_LANCAMENTO AND p.SITUACAO IN ('ABERTA', 'PARCIAL'));

            SELECT @QtdAtual = COUNT(*)
            FROM #abertos a
            WHERE EXISTS (SELECT 1 FROM FIN.fn_FIN_Lancamento_Pendencias_Simular(a.ID_LANCAMENTO, NULL, NULL) f
                          WHERE f.ORIGEM = 'AUTOMATICA' AND (@Codigo = '*' OR f.CODIGO = @Codigo))
            OPTION (RECOMPILE);

            SELECT @QtdNova = COUNT(*)
            FROM #abertos a
            WHERE EXISTS (SELECT 1 FROM FIN.fn_FIN_Lancamento_Pendencias_Simular(a.ID_LANCAMENTO, @Chave, @Novo) f
                          WHERE f.ORIGEM = 'AUTOMATICA' AND (@Codigo = '*' OR f.CODIGO = @Codigo))
            OPTION (RECOMPILE);

            SET @QtdAtual = ISNULL(@QtdAtual, 0);
            SET @QtdNova  = ISNULL(@QtdNova, 0);
            SET @Efeito = CASE
                              WHEN @QtdNova = @QtdAtual THEN N'Nenhuma mudança: continuam ' + CONVERT(NVARCHAR(10), @QtdNova) + N' lançamentos em aberto com '
                                   + CASE WHEN @Codigo = '*' THEN N'pendência automática.' ELSE N'esta pendência.' END
                              ELSE N'Com o valor novo, ' + CONVERT(NVARCHAR(10), @QtdNova) + N' lançamentos em aberto passam a ter '
                                   + CASE WHEN @Codigo = '*' THEN N'pendência automática' ELSE N'esta pendência' END
                                   + N' (hoje são ' + CONVERT(NVARCHAR(10), @QtdAtual) + N'; '
                                   + CASE WHEN @QtdNova > @QtdAtual THEN N'+' ELSE N'' END + CONVERT(NVARCHAR(10), @QtdNova - @QtdAtual) + N').'
                          END;
        END;

        SELECT SIS.fn_SIS_Parametro_Afrouxa(@Chave, @Atual, @Novo) AS PEDE_MOTIVO,
               @QtdAtual                                            AS QTD_ATUAL,
               @QtdNova                                             AS QTD_NOVA,
               CAST(@Efeito AS NVARCHAR(400))                       AS EFEITO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível conferir o parâmetro. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
