/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Listar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Lista da tela "Casos da migração" (MIG_CASOS): um documento do
                Access por linha (MIG.Caso: os que não se encaixam e os que já
                têm correção), com obra, histórico, motivo, valores e
                situação: PENDENTE, EM_CORRECAO (corrigido mas ainda não se
                encaixa), RESOLVIDO (corrigido e já se encaixa), IGNORADO,
                ARQUIVO_MORTO. Filtros e totais ficam na tela (são poucos
                documentos). Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).
    v1.1 (18/11/2026) - Situação REVISAR (o Access mudou depois da correção) e
                        coluna REVISAR com o aviso.
    v1.2 (19/11/2026) - Empresa e histórico também para documento formado por
                        troca de lote (lote novo da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Listar @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Listar]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Listar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT c.UNIDADE,
               CASE LEFT(c.UNIDADE, 1) WHEN 'L' THEN N'Lote ' WHEN 'V' THEN N'Venda ' ELSE N'Documento ' END
                 + SUBSTRING(c.UNIDADE, CHARINDEX(':', c.UNIDADE) + 1, 40) AS DOCUMENTO,
               c.DT_DOCUMENTO, YEAR(c.DT_DOCUMENTO) AS ANO,
               ISNULL(nv.NOME, N'') AS EMPRESA,
               ISNULL(NULLIF(pl.COMPLEMENTO, N''), ISNULL(h.DESCRICAO, N'')) AS HISTORICO,
               CASE WHEN c.REGRA_ATUAL = 'CASO' THEN c.MOTIVO ELSE c.MOTIVO_ORIGINAL END AS MOTIVO,
               c.MOTIVO_ORIGINAL, c.DETALHE, c.REGRA_ATUAL, c.LINHAS,
               c.VALOR_DEBITO, c.VALOR_CREDITO, c.VALOR_DEBITO - c.VALOR_CREDITO AS DIFERENCA,
               CASE WHEN c.REVISAR <> N'' THEN 'REVISAR'
                    WHEN c.REGRA_ATUAL = 'IGNORAR' THEN 'IGNORADO'
                    WHEN c.REGRA_ATUAL = 'ARQUIVO_MORTO' THEN 'ARQUIVO_MORTO'
                    WHEN c.REGRA_ATUAL = 'CASO' AND k.QTD > 0 THEN 'EM_CORRECAO'
                    WHEN c.REGRA_ATUAL = 'CASO' THEN 'PENDENTE'
                    ELSE 'RESOLVIDO' END AS SITUACAO,
               ISNULL(k.QTD, 0) AS LINHAS_CORRIGIDAS,
               COALESCE(cc.USUARIO_ALTERACAO, cc.USUARIO_CRIACAO, k.USUARIO, N'') AS CORRIGIDO_POR,
               COALESCE(cc.DT_ALTERACAO, cc.DT_CRIACAO, k.DT) AS CORRIGIDO_EM,
               c.REVISAR
        FROM MIG.Caso c
        OUTER APPLY (SELECT TOP (1) COALESCE(o.EMP_VINCULADA, m.EMP_VINCULADA) AS EV, m.COMPLEMENTO, m.HISTORICO
                     FROM MIG.fn_MIG_Linhas_Documento(c.UNIDADE) d
                     INNER JOIN MIG.Movimento m ON m.ORIGEM = d.ORIGEM AND m.NUM = d.NUM
                     LEFT JOIN MIG.Caso_Correcao_Linha o ON o.ORIGEM = m.ORIGEM AND o.NUM = m.NUM
                     ORDER BY CASE WHEN m.COMPLEMENTO <> N'' THEN 0 ELSE 1 END, m.NUM) pl
        OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(v.NomeVinculada)) AS NOME FROM MIG.Access_EmpVinculada v WHERE TRY_CONVERT(INT, v.CodigoVinculada) = pl.EV) nv
        OUTER APPLY (SELECT TOP (1) LTRIM(RTRIM(x.Descricao)) AS DESCRICAO FROM MIG.Access_Historico x WHERE TRY_CONVERT(INT, x.CodHistorico) = pl.HISTORICO) h
        OUTER APPLY (SELECT COUNT(*) AS QTD, MAX(COALESCE(o.USUARIO_ALTERACAO, o.USUARIO_CRIACAO)) AS USUARIO, MAX(COALESCE(o.DT_ALTERACAO, o.DT_CRIACAO)) AS DT
                     FROM MIG.Caso_Correcao_Linha o WHERE o.UNIDADE = c.UNIDADE) k
        LEFT JOIN MIG.Caso_Correcao cc ON cc.UNIDADE = c.UNIDADE
        ORDER BY c.DT_DOCUMENTO, c.UNIDADE;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar os casos da migração. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
