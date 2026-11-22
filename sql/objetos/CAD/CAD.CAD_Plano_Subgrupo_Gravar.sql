/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Subgrupo_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoSubgrupo NULL) ou altera um subgrupo (nível 2),
                sempre dentro de um grupo. @Numero NULL = próximo livre no grupo.
                Número (1 a 99) e descrição não repetem dentro do grupo. Mudar de grupo
                é permitido (fica na auditoria).
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira e escolher registro ligado que está na lixeira.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Subgrupo_Gravar]
    @IdUsuario     INT,
    @IdPlanoSubgrupo  INT          = NULL,
    @IdPlanoGrupo     INT,
    @Numero           SMALLINT     = NULL,
    @Descricao        NVARCHAR(80),
    @Ordem            SMALLINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Subgrupo_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));


        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoSubgrupo IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoSubgrupo IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Plano_Subgrupo', @IdPlanoSubgrupo) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdPlanoSubgrupo IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo x WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @IdPlanoGrupo AND g.DT_EXCLUSAO IS NULL)
            SET @Recusa = N'Escolha o grupo do subgrupo.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_GRUPO = @IdPlanoGrupo AND s.DESCRICAO = @Descricao
                                     AND s.ID_PLANO_SUBGRUPO <> ISNULL(@IdPlanoSubgrupo, 0))
            SET @Recusa = N'Já existe um subgrupo com esta descrição neste grupo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Subgrupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo;

        IF @Numero NOT BETWEEN 1 AND 99
            SET @Recusa = N'Número do subgrupo fora da faixa (1 a 99).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_GRUPO = @IdPlanoGrupo AND x.NUMERO = @Numero AND x.ID_PLANO_SUBGRUPO <> ISNULL(@IdPlanoSubgrupo, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
            RETURN;
        END;

        IF @IdPlanoSubgrupo IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Subgrupo (ID_PLANO_GRUPO, NUMERO, DESCRICAO, ORDEM, USUARIO_CRIACAO)
            VALUES (@IdPlanoGrupo, @Numero, @Descricao, ISNULL(@Ordem, @Numero), @Usuario);
            SET @IdPlanoSubgrupo = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE s
               SET s.ID_PLANO_GRUPO = @IdPlanoGrupo, s.NUMERO = @Numero, s.DESCRICAO = @Descricao, s.ORDEM = ISNULL(@Ordem, s.ORDEM),
                   s.DT_ALTERACAO = SYSDATETIME(), s.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Subgrupo s
            WHERE s.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoSubgrupo AS ID;
    END CATCH;
END;
GO
