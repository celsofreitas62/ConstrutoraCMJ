/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) um grupo (@Nivel 1), subgrupo (2)
                ou conta (3) do plano. Nada é apagado: desativar o grupo ou o subgrupo
                esconde tudo abaixo dele das listas de escolha (ATIVO_EFETIVO), sem
                mexer nos filhos. Permissão: EXCLUIR em CAD_PLANO_CONTA.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Plano_Excluir @IdUsuario = 2, @Nivel = 3, @Id = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Excluir]
    @IdUsuario  INT,
    @Nivel      TINYINT,
    @Id         INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'EXCLUIR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar o plano de contas.';
        IF @Recusa = N'' AND ISNULL(@Nivel, 0) NOT IN (1, 2, 3)
            SET @Recusa = N'Nível inválido (1 grupo, 2 subgrupo, 3 conta).';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = CASE @Nivel WHEN 1 THEN (SELECT g.ATIVO FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @Id)
                                        WHEN 2 THEN (SELECT s.ATIVO FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @Id)
                                        ELSE (SELECT c.ATIVO FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @Id) END;
            IF @Ativo IS NULL SET @Recusa = N'Registro do plano de contas não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;
        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        IF @Nivel = 1
            UPDATE g SET g.ATIVO = @Reativar, g.DT_ALTERACAO = SYSDATETIME(), g.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Grupo g WHERE g.ID_PLANO_GRUPO = @Id AND g.ATIVO <> @Reativar;
        IF @Nivel = 2
            UPDATE s SET s.ATIVO = @Reativar, s.DT_ALTERACAO = SYSDATETIME(), s.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Subgrupo s WHERE s.ID_PLANO_SUBGRUPO = @Id AND s.ATIVO <> @Reativar;
        IF @Nivel = 3
            UPDATE c SET c.ATIVO = @Reativar, c.DT_ALTERACAO = SYSDATETIME(), c.USUARIO_ALTERACAO = @Usuario
            FROM CAD.Plano_Conta c WHERE c.ID_PLANO_CONTA = @Id AND c.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @Id AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @Id AS ID;
    END CATCH;
END;
GO
