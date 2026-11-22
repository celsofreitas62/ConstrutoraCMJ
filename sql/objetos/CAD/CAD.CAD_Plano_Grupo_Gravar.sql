/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Grupo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoGrupo NULL) ou altera um grupo (nível 1) do plano de
                contas. @Numero NULL = próximo número livre. Número (0 a 99) e
                descrição não repetem. TIPO: RECEITA, DESPESA, NAO_OPERACIONAL.
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Grupo_Gravar]
    @IdUsuario     INT,
    @IdPlanoGrupo  INT          = NULL,
    @Numero        SMALLINT     = NULL,
    @Descricao     NVARCHAR(80),
    @Tipo          VARCHAR(15),
    @CustoObra     BIT          = 0,
    @Ordem         SMALLINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Grupo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Tipo      = UPPER(LTRIM(RTRIM(ISNULL(@Tipo, ''))));
        SET @CustoObra = ISNULL(@CustoObra, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoGrupo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoGrupo IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Plano_Grupo', @IdPlanoGrupo) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdPlanoGrupo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Grupo x WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND @Tipo NOT IN ('RECEITA', 'DESPESA', 'NAO_OPERACIONAL')
            SET @Recusa = N'Tipo do grupo inválido: receita, despesa ou não operacional.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Grupo g WHERE g.DESCRICAO = @Descricao AND g.ID_PLANO_GRUPO <> ISNULL(@IdPlanoGrupo, 0))
            SET @Recusa = N'Já existe um grupo com esta descrição.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Grupo x WITH (UPDLOCK, HOLDLOCK);

        IF @Numero NOT BETWEEN 0 AND 99
            SET @Recusa = N'Número do grupo fora da faixa (0 a 99).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Grupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.NUMERO = @Numero AND x.ID_PLANO_GRUPO <> ISNULL(@IdPlanoGrupo, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
            RETURN;
        END;

        IF @IdPlanoGrupo IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Grupo (NUMERO, DESCRICAO, TIPO, CUSTO_OBRA, ORDEM, USUARIO_CRIACAO)
            VALUES (@Numero, @Descricao, @Tipo, @CustoObra, ISNULL(@Ordem, @Numero), @Usuario);
            SET @IdPlanoGrupo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE g
               SET g.NUMERO = @Numero, g.DESCRICAO = @Descricao, g.TIPO = @Tipo, g.CUSTO_OBRA = @CustoObra, g.ORDEM = ISNULL(@Ordem, g.ORDEM),
                   g.DT_ALTERACAO = SYSDATETIME(), g.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Grupo g
            WHERE g.ID_PLANO_GRUPO = @IdPlanoGrupo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoGrupo AS ID;
    END CATCH;
END;
GO
