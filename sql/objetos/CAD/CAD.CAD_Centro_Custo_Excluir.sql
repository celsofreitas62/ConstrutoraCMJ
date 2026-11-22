/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Excluir]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Desativa (ou reativa, @Reativar = 1) um centro de custo. Nada é
                apagado. Reativar exige a empresa ativa.
                Permissão: DESATIVAR em CAD_CENTRO_CUSTO.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): permissão DESATIVAR (o botão Excluir
                        passa a mandar para a lixeira) e recusa se o registro
                        estiver na lixeira.

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Excluir @IdUsuario = 2, @IdCentroCusto = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Excluir]
    @IdUsuario  INT,
    @IdCentroCusto  INT,
    @Reativar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Excluir]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';
    DECLARE @Recusa     NVARCHAR(400) = N'';
    DECLARE @Usuario    NVARCHAR(100);
    DECLARE @Ativo      BIT;

    BEGIN TRY
        SET @Reativar = ISNULL(@Reativar, 0);

        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'DESATIVAR') = 0
            SET @Recusa = N'Você não tem permissão para desativar ou reativar centros de custo.';
        IF @Recusa = N'' AND SIS.fn_SIS_Na_Lixeira(N'CAD.Centro_Custo', @IdCentroCusto) = 1
            SET @Recusa = N'O registro está na lixeira: recupere-o antes (Sistema › Lixeira).';

        IF @Recusa = N''
        BEGIN
            SELECT @Ativo = t.ATIVO FROM CAD.Centro_Custo t WHERE t.ID_CENTRO_CUSTO = @IdCentroCusto;
            IF @Ativo IS NULL SET @Recusa = N'Registro não encontrado.';
            ELSE IF @Ativo = 1 AND @Reativar = 1 SET @Recusa = N'O registro já está ativo.';
            ELSE IF @Ativo = 0 AND @Reativar = 0 SET @Recusa = N'O registro já está desativado.';
        END;

        IF @Recusa = N'' AND @Reativar = 1
           AND NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo cc INNER JOIN CAD.Empresa e ON e.ID_EMPRESA = cc.ID_EMPRESA
                           WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto AND e.ATIVO = 1)
            SET @Recusa = N'A empresa deste centro de custo está desativada. Reative a empresa antes.';

        IF @Recusa <> N''
        BEGIN
            SELECT CAST(0 AS BIT) AS SUCESSO, CAST(@Recusa AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
            RETURN;
        END;

        SET @Usuario = SIS.fn_SIS_Usuario_Login(@IdUsuario);

        SET @EtapaAtual = 'Gravação';
        UPDATE t
           SET t.ATIVO = @Reativar, t.DT_ALTERACAO = SYSDATETIME(), t.USUARIO_ALTERACAO = @Usuario
        FROM CAD.Centro_Custo t
        WHERE t.ID_CENTRO_CUSTO = @IdCentroCusto
          AND t.ATIVO <> @Reativar;

        SELECT CAST(1 AS BIT) AS SUCESSO,
               CAST(CASE WHEN @Reativar = 1 THEN N'Registro reativado.' ELSE N'Registro desativado (continua no histórico).' END AS NVARCHAR(400)) AS MENSAGEM,
               @IdCentroCusto AS ID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        SELECT CAST(0 AS BIT) AS SUCESSO, CAST(N'Não foi possível alterar a situação do registro. O erro foi registrado para análise.' AS NVARCHAR(400)) AS MENSAGEM, @IdCentroCusto AS ID;
    END CATCH;
END;
GO
