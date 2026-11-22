/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Conta_Gravar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Inclui (@IdPlanoConta NULL) ou altera uma conta (nível 3, a que recebe
                lançamento), sempre dentro de um subgrupo. @Numero NULL = próximo livre
                no subgrupo. Número (1 a 999) e descrição não repetem dentro do
                subgrupo. CONTABIL e CONTA_CONTABIL_REF: pedido 10 / contabilidade.
                Permissão: INCLUIR ou ALTERAR em CAD_PLANO_CONTA. Devolve SUCESSO, MENSAGEM, ID.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): recusa alterar registro que está na lixeira e escolher registro ligado que está na lixeira.
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Conta_Gravar]
    @IdUsuario     INT,
    @IdPlanoConta      INT          = NULL,
    @IdPlanoSubgrupo   INT,
    @Numero            SMALLINT     = NULL,
    @Descricao         NVARCHAR(80),
    @Contabil          BIT          = 0,
    @ContaContabilRef  VARCHAR(30)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Conta_Gravar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);

    BEGIN TRY
        SET @Descricao = LTRIM(RTRIM(ISNULL(@Descricao, N'')));
        SET @Contabil         = ISNULL(@Contabil, 0);
        SET @ContaContabilRef = LTRIM(RTRIM(ISNULL(@ContaContabilRef, '')));

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', CASE WHEN @IdPlanoConta IS NULL THEN 'INCLUIR' ELSE 'ALTERAR' END) = 0
            SET @Recusa = N'Você não tem permissão para gravar o plano de contas.';
        IF @Recusa = N'' AND @IdPlanoConta IS NOT NULL AND SIS.fn_SIS_Na_Lixeira(N'CAD.Plano_Conta', @IdPlanoConta) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes de alterar (Sistema › Lixeira).';
        IF @Recusa = N'' AND @IdPlanoConta IS NOT NULL AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Conta x WHERE x.ID_PLANO_CONTA = @IdPlanoConta)
            SET @Recusa = N'Registro do plano de contas não encontrado.';
        IF @Recusa = N'' AND @Descricao = N''
            SET @Recusa = N'Informe a descrição.';
        IF @Recusa = N'' AND NOT EXISTS (SELECT 1 FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo AND s.DT_EXCLUSAO IS NULL)
            SET @Recusa = N'Escolha o subgrupo da conta.';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Conta c WHERE c.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo AND c.DESCRICAO = @Descricao
                                     AND c.ID_PLANO_CONTA <> ISNULL(@IdPlanoConta, 0))
            SET @Recusa = N'Já existe uma conta com esta descrição neste subgrupo.';
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        BEGIN TRANSACTION;

        -- Número: escolhido ou o próximo livre (leitura travada até o COMMIT)
        IF @Numero IS NULL
            SELECT @Numero = ISNULL(MAX(x.NUMERO), 0) + 1 FROM CAD.Plano_Conta x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo;

        IF @Numero NOT BETWEEN 1 AND 999
            SET @Recusa = N'Número do conta fora da faixa (1 a 999).';
        IF @Recusa = N'' AND EXISTS (SELECT 1 FROM CAD.Plano_Conta x WITH (UPDLOCK, HOLDLOCK) WHERE x.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo AND x.NUMERO = @Numero AND x.ID_PLANO_CONTA <> ISNULL(@IdPlanoConta, 0))
            SET @Recusa = N'Este número já está em uso. Escolha outro ou deixe em branco para usar o próximo livre.';

        IF @Recusa <> N''
        BEGIN
            COMMIT TRANSACTION;   -- nada foi gravado (COMMIT em vez de ROLLBACK: funciona dentro de INSERT ... EXEC)
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
            RETURN;
        END;

        IF @IdPlanoConta IS NULL
        BEGIN
            INSERT INTO CAD.Plano_Conta (ID_PLANO_SUBGRUPO, NUMERO, DESCRICAO, CONTABIL, CONTA_CONTABIL_REF, USUARIO_CRIACAO)
            VALUES (@IdPlanoSubgrupo, @Numero, @Descricao, @Contabil, @ContaContabilRef, @Usuario);
            SET @IdPlanoConta = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE c
               SET c.ID_PLANO_SUBGRUPO = @IdPlanoSubgrupo, c.NUMERO = @Numero, c.DESCRICAO = @Descricao, c.CONTABIL = @Contabil,
                   c.CONTA_CONTABIL_REF = @ContaContabilRef, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Conta c
            WHERE c.ID_PLANO_CONTA = @IdPlanoConta;

        COMMIT TRANSACTION;

        SELECT CAST(1 AS BIT) AS SUCESSO, CAST(N'Plano de contas gravado.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível gravar o plano de contas. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdPlanoConta AS ID;
    END CATCH;
END;
GO
