/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 25/11/2026
  Descrição   : Ficha de um centro de custo (tela CAD_CENTRO_CUSTO): todos os
                campos, empresa, conta padrão (a própria ou, se vazia, a da
                empresa), data de encerramento, quantos lançamentos usam o centro
                (QTD_LANCAMENTOS: com lançamento, a empresa não muda) e NA_LIXEIRA.
                Permissão: VER em CAD_CENTRO_CUSTO. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (25/11/2026) - Criação (etapa 04e).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Obter @IdUsuario = 2, @IdCentroCusto = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Obter]
    @IdUsuario      INT,
    @IdCentroCusto  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os centros de custo.', 1;
        IF NOT EXISTS (SELECT 1 FROM CAD.Centro_Custo cc WITH (NOLOCK) WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto)
            THROW 50001, N'Centro de custo não encontrado.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT cc.ID_CENTRO_CUSTO, cc.CODIGO, cc.DESCRICAO, cc.TIPO, cc.CONTABIL,
               cc.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               cc.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               ISNULL(ce.DESCRICAO, N'') AS CONTA_PADRAO_EMPRESA_DESCRICAO,
               cc.DT_ENCERRAMENTO,
               CAST(CASE WHEN cc.DT_ENCERRAMENTO <= CONVERT(DATE, SYSDATETIME()) THEN 1 ELSE 0 END AS BIT) AS ENCERRADO,
               (SELECT COUNT(*) FROM FIN.Lancamento l WITH (NOLOCK) WHERE l.ID_CENTRO_CUSTO = cc.ID_CENTRO_CUSTO) AS QTD_LANCAMENTOS,
               cc.ATIVO, CAST(CASE WHEN cc.DT_EXCLUSAO IS NULL THEN 0 ELSE 1 END AS BIT) AS NA_LIXEIRA,
               cc.CODIGO_ACCESS, cc.DT_CRIACAO, cc.USUARIO_CRIACAO, cc.DT_ALTERACAO, ISNULL(cc.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Centro_Custo cc WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
        LEFT  JOIN BANCO.Conta c  WITH (NOLOCK) ON c.ID_CONTA  = cc.ID_CONTA_BANCARIA_PADRAO
        LEFT  JOIN BANCO.Conta ce WITH (NOLOCK) ON ce.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE cc.ID_CENTRO_CUSTO = @IdCentroCusto;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o centro de custo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
