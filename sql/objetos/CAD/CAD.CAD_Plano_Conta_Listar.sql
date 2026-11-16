/*******************************************************************************
  Objeto      : [CAD].[CAD_Plano_Conta_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 16/11/2026
  Descrição   : Tela "Plano de contas": a árvore inteira, uma linha por nível
                (NIVEL 1 grupo, 2 subgrupo, 3 conta), na ordem numérica (ORDEM_ARVORE),
                com ID_PAI para montar a árvore. TIPO e CUSTO_OBRA vêm do grupo;
                CONTABIL e CONTA_CONTABIL_REF só na conta. ATIVO_EFETIVO: o registro e
                todos os de cima ativos. @SomenteAtivos = 1: só ATIVO_EFETIVO.
                Permissão: VER em CAD_PLANO_CONTA. Padrão "Listar": THROW 50001.

  Changelog:
    v1.0 (16/11/2026) - Criação (etapa 03a).

  Homologação (LOCAL):
    -- EXEC CAD.CAD_Plano_Conta_Listar @IdUsuario = 2;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [CAD].[CAD_Plano_Conta_Listar]
    @IdUsuario     INT,
    @SomenteAtivos BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[CAD].[CAD_Plano_Conta_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'CAD_PLANO_CONTA', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver o plano de contas.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT x.NIVEL, x.ID, x.ID_PAI, x.NUMERO, x.CODIGO, x.DESCRICAO, x.TIPO, x.CUSTO_OBRA, x.CONTABIL, x.CONTA_CONTABIL_REF,
               x.ORDEM, x.ATIVO, x.ATIVO_EFETIVO, x.ORDEM_ARVORE, x.DT_ALTERACAO, x.USUARIO_ALTERACAO
        FROM (
            SELECT CAST(1 AS TINYINT) AS NIVEL, g.ID_PLANO_GRUPO AS ID, CAST(NULL AS INT) AS ID_PAI, g.NUMERO,
                   CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2)) AS CODIGO,
                   g.DESCRICAO, g.TIPO, g.CUSTO_OBRA, CAST(0 AS BIT) AS CONTABIL, CONVERT(VARCHAR(30), '') AS CONTA_CONTABIL_REF,
                   g.ORDEM, g.ATIVO, g.ATIVO AS ATIVO_EFETIVO,
                   CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.00.000') AS ORDEM_ARVORE,
                   g.DT_ALTERACAO, ISNULL(g.USUARIO_ALTERACAO, N'') AS USUARIO_ALTERACAO
            FROM CAD.Plano_Grupo g WITH (NOLOCK)
            UNION ALL
            SELECT CAST(2 AS TINYINT), s.ID_PLANO_SUBGRUPO, s.ID_PLANO_GRUPO, s.NUMERO,
                   CONVERT(VARCHAR(12), RIGHT('0' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + CONVERT(VARCHAR(3), s.NUMERO)),
                   s.DESCRICAO, g.TIPO, g.CUSTO_OBRA, CAST(0 AS BIT), CONVERT(VARCHAR(30), ''),
                   s.ORDEM, s.ATIVO, CAST(CASE WHEN s.ATIVO = 1 AND g.ATIVO = 1 THEN 1 ELSE 0 END AS BIT),
                   CONVERT(VARCHAR(12), RIGHT('00' + CONVERT(VARCHAR(3), g.NUMERO), 2) + '.' + RIGHT('00' + CONVERT(VARCHAR(3), s.NUMERO), 2) + '.000'),
                   s.DT_ALTERACAO, ISNULL(s.USUARIO_ALTERACAO, N'')
            FROM CAD.Plano_Subgrupo s WITH (NOLOCK)
            INNER JOIN CAD.Plano_Grupo g WITH (NOLOCK) ON g.ID_PLANO_GRUPO = s.ID_PLANO_GRUPO
            UNION ALL
            SELECT CAST(3 AS TINYINT), v.ID_PLANO_CONTA, v.ID_PLANO_SUBGRUPO, v.NUMERO_CONTA, v.CODIGO,
                   v.DESCRICAO, v.TIPO, v.CUSTO_OBRA, v.CONTABIL, v.CONTA_CONTABIL_REF,
                   CAST(0 AS SMALLINT), v.CONTA_ATIVA, v.ATIVO_EFETIVO, v.ORDEM_ARVORE,
                   c.DT_ALTERACAO, ISNULL(c.USUARIO_ALTERACAO, N'')
            FROM CAD.vw_CAD_Plano_Conta v WITH (NOLOCK)
            INNER JOIN CAD.Plano_Conta c WITH (NOLOCK) ON c.ID_PLANO_CONTA = v.ID_PLANO_CONTA
        ) x
        WHERE (ISNULL(@SomenteAtivos, 0) = 0 OR x.ATIVO_EFETIVO = 1)
        ORDER BY x.ORDEM_ARVORE;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;

        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());

        THROW 50001, N'Não foi possível carregar o plano de contas. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
