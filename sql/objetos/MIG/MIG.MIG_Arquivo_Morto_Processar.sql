/*******************************************************************************
  Objeto      : [MIG].[MIG_Arquivo_Morto_Processar]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 17/11/2026
  Descrição   : Carrega o arquivo morto (FIN.Arquivo_Morto) com as linhas que o
                MIG_Movimento_Preparar marcou com destino ARQ_MORTO: movimento
                anterior a 01/01/2018 e os resumos "Sd Acum" até 01/01/2018,
                com os textos legíveis do Access (empresa, obra, pessoa, conta,
                plano, histórico, imóvel). Saldos por conta em 31/12/2017
                (FIN.Arquivo_Morto_Saldo): soma dos resumos "Sd Acum" de
                01/01/2018, como o Access mostrava (só referência: não são os
                saldos reais do banco).
                Tudo-ou-nada; repetível: apaga a carga anterior do Access e
                carrega de novo. Devolve quantidade e totais carregados.

  Changelog:
    v1.0 (17/11/2026) - Criação (etapa 03c, ensaio da migração).
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Arquivo_Morto_Processar]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Arquivo_Morto_Processar]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Validação';

    BEGIN TRY
        IF OBJECT_ID(N'MIG.Movimento', N'U') IS NULL
            THROW 50001, N'Rode antes o MIG.MIG_Movimento_Preparar.', 1;

        SET @EtapaAtual = 'Carga';
        BEGIN TRANSACTION;

        DELETE FROM FIN.Arquivo_Morto WHERE ORIGEM_ACCESS IN ('ACCESS_MOVTO', 'ACCESS_ARQMORTO');
        DELETE FROM FIN.Arquivo_Morto_Saldo;

        INSERT INTO FIN.Arquivo_Morto (ORIGEM_ACCESS, CODIGO_ACCESS, EMPRESA, OBRA, PESSOA, CONTA, PLANO1, PLANO2, PLANO3, HISTORICO,
                                       COMPLEMENTO, DOCUMENTO, NOTA_FISCAL, IMOVEL, OBSERVACAO, VALOR_DEBITO, VALOR_CREDITO,
                                       DT_MOVIMENTO, DT_VENCIMENTO, DT_PAGAMENTO, CONFIRMADO, EFETUADO)
        SELECT m.ORIGEM, m.NUM,
               LEFT(ISNULL(em.NomeMaster, N''), 150), LEFT(ISNULL(ev.NomeVinculada, N''), 150),
               LEFT(ISNULL(pa.NomeParceiro, N''), 150), LEFT(ISNULL(cf.Descricao, N''), 80),
               LEFT(ISNULL(p1.DescricaoPlano1, N''), 80), LEFT(ISNULL(p2.DescricaoPlano2, N''), 80), LEFT(ISNULL(p3.DescricaoPlano3, N''), 120),
               LEFT(ISNULL(hi.Descricao, N''), 80),
               LEFT(m.COMPLEMENTO, 255), LEFT(m.NUM_DOC, 60), LEFT(m.NOTA_FISCAL, 60), LEFT(ISNULL(im.NomeImovel, N''), 150),
               LEFT(m.OBSERVACAO, 2000), m.VALOR_DEBITO, m.VALOR_CREDITO,
               m.DT_VALIDA,
               CASE WHEN m.DT_VENCTO BETWEEN '2000-01-01' AND '2035-12-31' THEN m.DT_VENCTO END,
               CASE WHEN m.DT_PAGTO  BETWEEN '2000-01-01' AND '2035-12-31' THEN m.DT_PAGTO END,
               m.CONFIRMADO, m.EFETUADO
        FROM MIG.Movimento m
        LEFT JOIN MIG.Access_EmpVinculada ev       ON TRY_CONVERT(INT, ev.CodigoVinculada) = m.EMP_VINCULADA
        LEFT JOIN MIG.Access_EmpMaster em          ON em.CodigoMaster = ev.CodigoMaster
        LEFT JOIN MIG.Access_Parceiros pa          ON TRY_CONVERT(INT, pa.CodigoParceiro) = m.PARCEIRO
        LEFT JOIN MIG.Access_Contas_Financeiras cf ON TRY_CONVERT(INT, cf.CodigoConta) = m.CONTA
        LEFT JOIN MIG.Access_Plano1 p1             ON TRY_CONVERT(INT, p1.Plano1) = m.PLANO1
        LEFT JOIN MIG.Access_Plano2 p2             ON TRY_CONVERT(INT, p2.Plano2) = m.PLANO2
        LEFT JOIN MIG.Access_Plano3 p3             ON TRY_CONVERT(INT, p3.Plano3) = m.PLANO3
        LEFT JOIN MIG.Access_Historico hi          ON TRY_CONVERT(INT, hi.CodHistorico) = m.HISTORICO
        OUTER APPLY (SELECT TOP (1) i.NomeImovel FROM MIG.Access_Imoveis i
                     WHERE TRY_CONVERT(INT, i.CodImovel) = m.IMOVEL AND m.IMOVEL > 1 ORDER BY i.NomeImovel) im
        WHERE m.DESTINO = 'ARQ_MORTO';

        INSERT INTO FIN.Arquivo_Morto_Saldo (CONTA, DT_SALDO, SALDO)
        SELECT LEFT(ISNULL(cf.Descricao, N'Conta ' + CONVERT(NVARCHAR(10), m.CONTA)), 80), '2017-12-31', SUM(m.VALOR_CREDITO - m.VALOR_DEBITO)
        FROM MIG.Movimento m
        LEFT JOIN MIG.Access_Contas_Financeiras cf ON TRY_CONVERT(INT, cf.CodigoConta) = m.CONTA
        WHERE m.SD_ACUM = 1 AND m.DUPLICADA = 0 AND m.DT_VALIDA = '2018-01-01' AND m.CONTA NOT IN (1, 2, 3)
        GROUP BY LEFT(ISNULL(cf.Descricao, N'Conta ' + CONVERT(NVARCHAR(10), m.CONTA)), 80);

        COMMIT TRANSACTION;

        SELECT a.ORIGEM_ACCESS, COUNT(*) AS LINHAS, SUM(a.VALOR_DEBITO) AS DEBITOS, SUM(a.VALOR_CREDITO) AS CREDITOS,
               MIN(a.DT_MOVIMENTO) AS DE, MAX(a.DT_MOVIMENTO) AS ATE,
               SUM(CASE WHEN a.PESSOA = N'' THEN 1 ELSE 0 END) AS SEM_PESSOA, SUM(CASE WHEN a.CONTA = N'' THEN 1 ELSE 0 END) AS SEM_CONTA
        FROM FIN.Arquivo_Morto a
        GROUP BY a.ORIGEM_ACCESS;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW;
    END CATCH;
END;
GO
