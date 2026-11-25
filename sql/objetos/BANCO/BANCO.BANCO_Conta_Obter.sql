/*******************************************************************************
  Objeto      : [BANCO].[BANCO_Conta_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha de uma conta bancária, caixa ou conta de permuta (tela
                BANCO_CONTA): todos os campos, empresa e banco, se é a conta
                padrão da empresa, TEM_MOVIMENTO (já há movimento ou baixa: a
                tela trava empresa, tipo e saldo inicial) e NA_LIXEIRA.
                Permissão: VER em BANCO_CONTA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e).

  Homologação (LOCAL):
    -- EXEC BANCO.BANCO_Conta_Obter @IdUsuario = 2, @IdConta = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [BANCO].[BANCO_Conta_Obter]
    @IdUsuario  INT,
    @IdConta    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[BANCO].[BANCO_Conta_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'BANCO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver as contas bancárias.', 1;
        IF NOT EXISTS (SELECT 1 FROM BANCO.Conta c WITH (NOLOCK) WHERE c.ID_CONTA = @IdConta)
            THROW 50001, N'Conta não encontrada.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.ID_CONTA, c.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               c.DESCRICAO, c.TIPO, c.ID_BANCO, ISNULL(b.CODIGO, '') AS BANCO_CODIGO, ISNULL(b.NOME, N'') AS BANCO_NOME,
               c.AGENCIA, c.AGENCIA_DV, c.NUMERO, c.NUMERO_DV, c.LIMITE_CREDITO, c.SALDO_INICIAL, c.DT_SALDO_INICIAL,
               c.CONCILIA, c.MOSTRA_SALDO, c.CONTA_CONTABIL_REF, c.ORDEM,
               CAST(CASE WHEN e.ID_CONTA_BANCARIA_PADRAO = c.ID_CONTA THEN 1 ELSE 0 END AS BIT) AS PADRAO_DA_EMPRESA,
               CAST(CASE WHEN EXISTS (SELECT 1 FROM BANCO.Movimento m WITH (NOLOCK) WHERE m.ID_CONTA = c.ID_CONTA)
                           OR EXISTS (SELECT 1 FROM FIN.Baixa x WITH (NOLOCK) WHERE x.ID_CONTA = c.ID_CONTA)
                         THEN 1 ELSE 0 END AS BIT) AS TEM_MOVIMENTO,
               c.ATIVO, CAST(CASE WHEN c.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT) AS NA_LIXEIRA,
               c.CODIGO_ACCESS, c.DT_CRIACAO, c.USUARIO_CRIACAO, c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM BANCO.Conta c WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = c.ID_EMPRESA
        LEFT  JOIN BANCO.Banco b WITH (NOLOCK) ON b.ID_BANCO = c.ID_BANCO
        WHERE c.ID_CONTA = @IdConta;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar a conta. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
