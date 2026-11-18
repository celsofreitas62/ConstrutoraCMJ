/*******************************************************************************
  Objeto      : [MIG].[MIG_Caso_Opcoes]
  Autor       : Celso de Freitas
  Refatorado  : Claude
  Criação     : 18/11/2026
  Descrição   : Listas de escolha da tela "Casos da migração", com os códigos e
                nomes do Access: obras (só as que têm de-para), contas, planos
                (só os que têm de-para) e pessoas. Uma linha com quatro colunas
                JSON. Permissão: VER em MIG_CASOS.
                Schema MIG: só migração, NÃO entra no MASTER (regra 60).

  Changelog:
    v1.0 (18/11/2026) - Criação (etapa 03c2, tela de casos da migração).

  Homologação (LOCAL):
    -- EXEC MIG.MIG_Caso_Opcoes @IdUsuario = 1;
*******************************************************************************/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [MIG].[MIG_Caso_Opcoes]
    @IdUsuario  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NomeProc   NVARCHAR(128) = N'[MIG].[MIG_Caso_Opcoes]';
    DECLARE @EtapaAtual VARCHAR(100)  = 'Permissão';

    BEGIN TRY
        IF SIS.fn_SIS_Tem_Permissao(@IdUsuario, 'MIG_CASOS', 'VER') = 0
            THROW 50001, N'Você não tem permissão para ver os casos da migração.', 1;

        SET @EtapaAtual = 'Consulta';
        SELECT
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, v.CodigoVinculada) AS c, MIN(LTRIM(RTRIM(v.NomeVinculada))) AS n
                                          FROM MIG.Access_EmpVinculada v
                                          WHERE EXISTS (SELECT 1 FROM MIG.DePara_Centro d WHERE d.CODIGO_VINCULADA = TRY_CONVERT(INT, v.CodigoVinculada))
                                          GROUP BY TRY_CONVERT(INT, v.CodigoVinculada)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS OBRAS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, k.CodigoConta) AS c, MIN(LTRIM(RTRIM(k.Descricao))) AS n
                                          FROM MIG.Access_Contas_Financeiras k
                                          WHERE TRY_CONVERT(INT, k.CodigoConta) IS NOT NULL
                                          GROUP BY TRY_CONVERT(INT, k.CodigoConta)) x
                    ORDER BY x.c FOR JSON PATH), N'[]') AS CONTAS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, p.Plano3) AS c, MIN(LTRIM(RTRIM(p.DescricaoPlano3))) AS n
                                          FROM MIG.Access_Plano3 p
                                          WHERE EXISTS (SELECT 1 FROM MIG.DePara_Plano d WHERE d.PLANO3_ACCESS = TRY_CONVERT(INT, p.Plano3))
                                          GROUP BY TRY_CONVERT(INT, p.Plano3)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS PLANOS_JSON,
            ISNULL((SELECT x.c, x.n FROM (SELECT TRY_CONVERT(INT, p.CodigoParceiro) AS c, MIN(LTRIM(RTRIM(p.NomeParceiro))) AS n
                                          FROM MIG.Access_Parceiros p
                                          WHERE TRY_CONVERT(INT, p.CodigoParceiro) > 1
                                          GROUP BY TRY_CONVERT(INT, p.CodigoParceiro)) x
                    ORDER BY x.n FOR JSON PATH), N'[]') AS PESSOAS_JSON;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 50001 THROW;
        IF XACT_STATE() <> -1
            INSERT INTO SIS.Log_Erro (ROTINA, ETAPA, NUMERO_ERRO, MENSAGEM, LINHA, DT_ERRO)
            VALUES (@NomeProc, @EtapaAtual, ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE(), SYSDATETIME());
        THROW 50001, N'Não foi possível carregar as listas da tela. O erro foi registrado para análise.', 1;
    END CATCH;
END;
GO
