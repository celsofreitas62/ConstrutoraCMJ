/*******************************************************************************
  Objeto      : [FIN].[FIN_Pendencia_Tipo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 26/11/2026
  Descrição   : P27 - inclui ou altera um tipo de pendência (@IdPendenciaTipo
                NULL = novo). Tipo do sistema (MIGRACAO): código não muda e
                não pode ser desativado; descrição, orientação, onde vale e o
                bloqueio da baixa podem. Desativar: o tipo some da escolha,
                as pendências já lançadas continuam valendo.
                Permissão: INCLUIR / ALTERAR em FIN_PENDENCIA_TIPO e DESATIVAR
                para mudar o ativo. Excluir = lixeira (SIS_Lixeira_Excluir).
                Devolve SUCESSO, MENSAGEM, ID.
  Changelog:
    v1.0 (26/11/2026) - Criação (etapa 04f2c).

  Homologação (LOCAL):
    -- EXEC FIN.FIN_Pendencia_Tipo_Gravar @IdUsuario = 2, @Codigo = 'TESTE', @Descricao = N'Teste', @AplicaA = 'A', @BloqueiaBaixa = 0;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [FIN].[FIN_Pendencia_Tipo_Gravar]
    @IdUsuario        INT,
    @IdPendenciaTipo  INT            = NULL,
    @Codigo           VARCHAR(20),
    @Descricao        NVARCHAR(60),
    @Orientacao       NVARCHAR(400)  = NULL,
    @AplicaA          CHAR(1)        = 'A',
    @BloqueiaBaixa    BIT            = 0,
    @Ordem            INT            = NULL,
    @Ativo            BIT            = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc    NVARCHAR(128) = N'[FIN].[FIN_Pendencia_Tipo_Gravar]';
    DECLARE @EtapaAtual  VARCHAR(100)  = 'Validação';
    DECLARE @Recusa      NVARCHAR(400) = N'';
    DECLARE @Usuario     NVARCHAR(100) = SIS.fn_SIS_Usuario_Login(@IdUsuario);
    DECLARE @Sistema     BIT           = 0;
    DECLARE @CodigoAtual VARCHAR(20);
    DECLARE @AtivoAtual  BIT;
    DECLARE @Abertas     INT           = 0;

    BEGIN TRY
        SET @Codigo        = UPPER(LTRIM(RTRIM(ISNULL(@Codigo, ''))));
        SET @Descricao     = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Orientacao    = LTRIM(RTRIM(ISNULL(@Orientacao, N'')));
        SET @AplicaA       = UPPER(ISNULL(@AplicaA, 'A'));
        SET @BloqueiaBaixa = ISNULL(@BloqueiaBaixa, 0);
        SET @Ativo         = ISNULL(@Ativo, 1);

        SELECT @Sistema = t.SISTEMA, @CodigoAtual = t.CODIGO, @AtivoAtual = t.ATIVO
        FROM FIN.Pendencia_Tipo t WHERE t.ID_PENDENCIA_TIPO = @IdPendenciaTipo;

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PENDENCIA_TIPO', CASE WHEN @IdPendenciaTipo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar tipos de pendência.';
        IF @Recusa = N'' AND @IdPendenciaTipo IS NOT NULL AND @CodigoAtual IS NULL
            SET @Recusa = N'Tipo de pendência não encontrado.';
        IF @Recusa = N'' AND @IdPendenciaTipo IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'FIN.Pendencia_Tipo', @IdPendenciaTipo) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @Sistema = 1 AND @Codigo <> @CodigoAtual
            SET @Recusa = N'O código de um tipo do sistema não pode ser mudado.';
        IF @Recusa = N'' AND @Sistema = 1 AND @Ativo = 0
            SET @Recusa = N'Um tipo do sistema não pode ser desativado.';
        IF @Recusa = N'' AND (@Codigo = '' OR @Codigo LIKE '%[^A-Z0-9_]%' COLLATE Latin1_General_BIN2)
            SET @Recusa = N'Código inválido: use letras sem acento, números e "_" (ex.: AGUARDA_MEDICAO).';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND @AplicaA NOT IN ('P', 'R', 'A')
            SET @Recusa = N'Escolha onde o tipo vale: contas a pagar, a receber ou ambos.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM FIN.Pendencia_Tipo t WHERE t.CODIGO = @Codigo AND t.ID_PENDENCIA_TIPO <> ISNULL(@IdPendenciaTipo, 0))
            SET @Recusa = N'Já existe um tipo de pendência com este código (confira também a lixeira).';
        IF @Recusa = N'' AND @IdPendenciaTipo IS NOT NULL AND @Ativo <> @AtivoAtual
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'FIN_PENDENCIA_TIPO', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar tipos de pendência.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPendenciaTipo AS ID;
            RETURN;
        END;

        IF @IdPendenciaTipo IS NOT NULL AND @Ativo = 0 AND @AtivoAtual = 1
            SELECT @Abertas = COUNT(*) FROM FIN.Lancamento_Pendencia x
            WHERE x.ID_PENDENCIA_TIPO = @IdPendenciaTipo AND x.SITUACAO = 'ABERTA' AND x.ATIVO = 1;

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        IF @IdPendenciaTipo IS NULL
        BEGIN
            INSERT INTO FIN.Pendencia_Tipo (CODIGO, DESCRICAO, ORIENTACAO, APLICA_A, BLOQUEIA_BAIXA, SISTEMA, ORDEM, ATIVO, USUARIO_CRIACAO)
            VALUES (@Codigo, @Descricao, @Orientacao, @AplicaA, @BloqueiaBaixa, 0, ISNULL(@Ordem, 100), @Ativo, ISNULL(@Usuario, N''));
            SET @IdPendenciaTipo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE FIN.Pendencia_Tipo
               SET CODIGO = @Codigo, DESCRICAO = @Descricao, ORIENTACAO = @Orientacao, APLICA_A = @AplicaA,
                   BLOQUEIA_BAIXA = @BloqueiaBaixa, ORDEM = ISNULL(@Ordem, ORDEM), ATIVO = @Ativo,
                   DT_ALTERACAO = SYSDATETIME(), USUARIO_ALTERACAO = @Usuario
             WHERE ID_PENDENCIA_TIPO = @IdPendenciaTipo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(N'Tipo de pendência gravado.'
                    + CASE WHEN @Abertas > 0 THEN N' Atenção: ' + CONVERT(NVARCHAR(10), @Abertas)
                                + N' pendência(s) abertas continuam com este tipo; ele só não aparece mais para novas pendências.' ELSE N'' END
                    AS NVARCHAR(400)) AS MENSAGEM,
               @IdPendenciaTipo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o tipo de pendência. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPendenciaTipo AS ID;
    END CATCH;
END;
GO
