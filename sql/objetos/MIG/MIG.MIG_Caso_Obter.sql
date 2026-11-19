/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Obter]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Um caso da tela "Casos da migração": cabeçalho (motivo, situação,
                decisão gravada) e as linhas do Access (LINHAS_JSON), cada uma
                com o valor original e o valor em uso (original + correção da
                tela) de obra, pessoa, conta, plano, datas, valores e
                confirmado, já com os nomes do Access. Data corrigida para
                01/01/1900 = "sem data". Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
    v1.1 (18/11/2026) - Aviso REVISAR no cabeçalho e "mudou" em cada linha
                        alterada no Access depois da correção.
    v1.2 (18/11/2026) - Lote da linha (original e em uso).
    v1.3 (19/11/2026) - Linhas do documento: as do Access e as que vieram por
                        troca de lote; PROXIMO_LOTE_NOVO (lote novo da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Obter @IdUsuario = 1, @Unidade = 'L:123';
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Obter]
    @IdUsuario  INT,
    @Unidade    VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Obter]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;
        IF NOT EXISTS (SELECT 1 FROM MIG.Caso c WHERE c.UNIDADE = @Unidade)
            THROW 50001, N'Caso não encontrado. Atualize a lista.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.UNIDADE, c.REGRA_ATUAL, c.REVISAR, c.MOTIVO, c.MOTIVO_ORIGINAL, c.DETALHE, c.PADRAO, c.DT_DOCUMENTO, c.DT_CALCULO,
               ISNULL(cc.ACAO, '') AS ACAO, ISNULL(cc.MOTIVO, N'') AS ACAO_MOTIVO,
               COALESCE(cc.USUARIO_ALTERACAO, cc.USUARIO_CRIACAO, N'') AS ACAO_USUARIO, COALESCE(cc.DT_ALTERACAO, cc.DT_CRIACAO) AS ACAO_DT,
               (SELECT CASE WHEN ISNULL(MAX(o.LOTE), 0) < 900000 THEN 900001 ELSE MAX(o.LOTE) + 1 END
                FROM MIG.Caso_Correcao_Linha o WHERE o.LOTE >= 900000) AS PROXIMO_LOTE_NOVO,
               ISNULL((SELECT TOP (1) o.MOTIVO FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = c.UNIDADE AND o.MOTIVO <> N''
                       ORDER BY COALESCE(o.DT_ALTERACAO, o.DT_CRIACAO) DESC), N'') AS CORRECAO_MOTIVO,
               ISNULL((
                   SELECT m.ORIGEM AS origem, m.NUM AS num, m.TIPO_CONTA AS tipoConta, m.LADO AS lado,
                          m.NUM_DOC AS numDoc, m.COMPLEMENTO AS complemento, ISNULL(h.DESCRICAO, N'') AS historico,
                          m.EMP_VINCULADA AS empOrig, COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS emp, ISNULL(nv.NOME, N'') AS empNome,
                          m.PARCEIRO AS parceiroOrig, COALESCE(o.PARCEIRO, m.PARCEIRO) AS parceiro, ISNULL(np.NOME, N'') AS parceiroNome,
                          m.CONTA AS contaOrig, COALESCE(o.CONTA, m.CONTA) AS conta, ISNULL(nc.NOME, N'') AS contaNome,
                          m.PLANO3 AS planoOrig, COALESCE(o.PLANO3, m.PLANO3) AS plano, ISNULL(npl.NOME, N'') AS planoNome,
                          m.DT_MOVTO AS dtMovtoOrig, NULLIF(COALESCE(o.DT_MOVTO, m.DT_MOVTO), '1900-01-01') AS dtMovto,
                          m.DT_VENCTO AS dtVenctoOrig, NULLIF(COALESCE(o.DT_VENCTO, m.DT_VENCTO), '1900-01-01') AS dtVencto,
                          m.DT_PAGTO AS dtPagtoOrig, NULLIF(COALESCE(o.DT_PAGTO, m.DT_PAGTO), '1900-01-01') AS dtPagto,
                          m.VALOR_DEBITO AS debitoOrig, COALESCE(o.VALOR_DEBITO, m.VALOR_DEBITO) AS debito,
                          m.VALOR_CREDITO AS creditoOrig, COALESCE(o.VALOR_CREDITO, m.VALOR_CREDITO) AS credito,
                          m.CONFIRMADO AS confirmadoOrig, COALESCE(o.CONFIRMADO, m.CONFIRMADO) AS confirmado,
                          m.LOTE AS loteOrig, COALESCE(o.LOTE, m.LOTE) AS lote,
                          m.EFETUADO AS efetuado, m.SOMENTE_INTEGRACAO AS somenteIntegracao,
                          ISNULL(o.IGNORAR_LINHA, CAST(0 AS BIT)) AS ignorar,
                          CAST(CASE WHEN o.ID_CASO_CORRECAO_LINHA IS NULL THEN 0 ELSE 1 END AS BIT) AS corrigida,
                          CAST(CASE WHEN o.HASH_ACCESS IS NOT NULL AND o.HASH_ACCESS <> m.HASH_CONTEUDO THEN 1 ELSE 0 END AS BIT) AS mudou
                   FROM MIG.Movimento m
                   LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS DESCRICAO FROM MIG.Access_Historico x WHERE TRY_CONVERT(INT, x.CodHistorico) = m.HISTORICO) h
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(v.NomeVinculada)) AS NOME FROM MIG.Access_EmpVinculada v WHERE TRY_CONVERT(INT, v.CodigoVinculada) = COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA)) nv
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.NomeParceiro)) AS NOME FROM MIG.Access_Parceiros x WHERE TRY_CONVERT(INT, x.CodigoParceiro) = COALESCE(o.PARCEIRO, m.PARCEIRO)) np
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS NOME FROM MIG.Access_Contas_Financeiras x WHERE TRY_CONVERT(INT, x.CodigoConta) = COALESCE(o.CONTA, m.CONTA)) nc
                   OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.DescricaoPlano3)) AS NOME FROM MIG.Access_Plano3 x WHERE TRY_CONVERT(INT, x.Plano3) = COALESCE(o.PLANO3, m.PLANO3)) npl
                   WHERE EXISTS (SELECT 1 FROM MIG.fn_MIG_Linhas_Documento(c.UNIDADE) d WHERE d.ORIGEM = m.ORIGEM AND d.NUM = m.NUM)
                   ORDER BY m.DT_MOVTO, m.NUM
                   FOR JSON PATH, INCLUDE_NULL_VALUES), N'[]') AS LINHAS_JSON
        FROM MIG.Caso c
        LEFT JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = c.UNIDADE
        WHERE c.UNIDADE = @Unidade;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar o caso. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
