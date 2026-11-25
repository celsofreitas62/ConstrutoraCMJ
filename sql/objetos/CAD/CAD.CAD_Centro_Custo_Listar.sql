/*******************************************************************************
  Objeto      : [CAD].[CAD_Centro_Custo_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Centros de custo" (e escolha do centro nos lançamentos).
                @IdEmpresa NULL = todas. CONTA_EFETIVA: a conta do centro ou, se vazia,
                a da empresa. Permissão: VER em CAD_CENTRO_CUSTO.
                Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).
    v1.1 (22/11/2026) - Etapa 04b (P20): não lista o que está na lixeira.
    v1.2 (25/11/2026) - Etapa 04e: DT_ENCERRAMENTO e ENCERRADO; quem vê
                        empresas também vê os centros (aba da ficha da empresa).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Centro_Custo_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Centro_Custo_Listar]
    @IdUsuario     INT,
    @IdEmpresa     INT = NULL,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Centro_Custo_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_CENTRO_CUSTO', 'VER') = 0
           AND SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_EMPRESA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os centros de custo.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT cc.ID_CENTRO_CUSTO, cc.CODIGO, cc.DESCRICAO, cc.TIPO, cc.CONTABIL,
               cc.ID_EMPRESA, e.RAZAO_SOCIAL AS EMPRESA_RAZAO_SOCIAL, e.NOME_FANTASIA AS EMPRESA_NOME_FANTASIA,
               cc.ID_CONTA_BANCARIA_PADRAO, ISNULL(c.DESCRICAO, N'') AS CONTA_PADRAO_DESCRICAO,
               ISNULL(cc.ID_CONTA_BANCARIA_PADRAO, e.ID_CONTA_BANCARIA_PADRAO) AS ID_CONTA_EFETIVA,
               ISNULL(c.DESCRICAO, ISNULL(ce.DESCRICAO, N'')) AS CONTA_EFETIVA_DESCRICAO,
               cc.DT_ENCERRAMENTO,
               CAST(CASE WHEN cc.DT_ENCERRAMENTO <= CONVERT(DATE, SYSDATETIME()) THEN 1 ELSE 0 END AS BIT) AS ENCERRADO,
               cc.ATIVO, cc.CODIGO_ACCESS, cc.DT_ALTERACAO, ISNULL(cc.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
        FROM CAD.Centro_Custo cc WITH (NOLOCK)
        INNER JOIN CAD.Empresa e WITH (NOLOCK) ON e.ID_EMPRESA = cc.ID_EMPRESA
        LEFT  JOIN BANCO.Conta c  WITH (NOLOCK) ON c.ID_CONTA  = cc.ID_CONTA_BANCARIA_PADRAO
        LEFT  JOIN BANCO.Conta ce WITH (NOLOCK) ON ce.ID_CONTA = e.ID_CONTA_BANCARIA_PADRAO
        WHERE (@IdEmpresa IS NULL OR cc.ID_EMPRESA = @IdEmpresa)
          AND (ISNULL(@SomenteAtivos, 0) = 0 OR cc.ATIVO = 1)
          AND cc.DT_EXCLUSAO IS NULL
        ORDER BY cc.CODIGO;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar os centros de custo. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
